use crate::app_config::AppConfig;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fs;
use std::path::{Component, Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};
use tauri::State;

#[derive(Debug, Deserialize)]
struct PackageManifestImport {
    #[serde(rename = "type")]
    package_type: String,
    id: String,
    version: String,
    name: Option<String>,
    #[serde(rename = "displayName")]
    display_name: Option<String>,
    layout: Option<String>,
    theme: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ImportedNestPackage {
    package_manifest: Value,
    nest_layout: Value,
    missing_assets: Vec<String>,
}

const LOCAL_SNAPSHOT_SCHEMA_VERSION: u64 = 1;
const CURRENT_SETTINGS_SCHEMA_VERSION: u64 = 3;
const CURRENT_REGISTRY_SCHEMA_VERSION: u64 = 1;

#[derive(Debug)]
struct SnapshotBackup {
    target: PathBuf,
    backup: Option<PathBuf>,
}

/// Returns the unified application configuration to the frontend.
#[tauri::command]
pub fn get_app_config(config: State<'_, AppConfig>) -> Result<AppConfig, String> {
    Ok(config.inner().clone())
}

/// Returns the raw persisted settings JSON. The frontend owns schema
/// normalization through @codexpet/core so UI rules stay in one place.
#[tauri::command]
pub fn load_local_settings(config: State<'_, AppConfig>) -> Result<Option<Value>, String> {
    let path = settings_path(config.inner());
    if !path.exists() {
        return Ok(None);
    }

    let contents = fs::read_to_string(&path)
        .map_err(|error| format!("Failed to read settings file {}: {}", path.display(), error))?;
    serde_json::from_str(&contents).map(Some).map_err(|error| {
        format!(
            "Failed to parse settings file {}: {}",
            path.display(),
            error
        )
    })
}

/// Persists normalized settings JSON to the local application data directory.
#[tauri::command]
pub fn save_local_settings(config: State<'_, AppConfig>, settings: Value) -> Result<(), String> {
    let path = settings_path(config.inner());
    write_json_file(&path, &settings, "settings")
}

/// Returns the raw persisted local package registry JSON.
#[tauri::command]
pub fn load_local_registry(config: State<'_, AppConfig>) -> Result<Option<Value>, String> {
    let path = registry_path(config.inner());
    if !path.exists() {
        return Ok(None);
    }

    let contents = fs::read_to_string(&path)
        .map_err(|error| format!("Failed to read registry file {}: {}", path.display(), error))?;
    serde_json::from_str(&contents).map(Some).map_err(|error| {
        format!(
            "Failed to parse registry file {}: {}",
            path.display(),
            error
        )
    })
}

/// Persists normalized local package registry JSON to the app data directory.
#[tauri::command]
pub fn save_local_registry(config: State<'_, AppConfig>, registry: Value) -> Result<(), String> {
    let path = registry_path(config.inner());
    write_json_file(&path, &registry, "registry")
}

/// Exports local settings and registry metadata to a user-selected JSON file.
#[tauri::command]
pub fn export_local_snapshot(
    config: State<'_, AppConfig>,
    export_path: String,
    settings: Value,
    registry: Value,
) -> Result<Value, String> {
    validate_snapshot_payload(&settings, &registry)?;
    let path = PathBuf::from(export_path);
    let exported_at = timestamp_now();
    let snapshot = serde_json::json!({
        "schemaVersion": LOCAL_SNAPSHOT_SCHEMA_VERSION,
        "exportedAt": exported_at,
        "app": {
            "name": config.app_name.clone(),
            "version": config.version.clone(),
            "platform": config.platform.clone(),
        },
        "data": {
            "settings": settings,
            "registry": registry,
        },
        "notes": [
            "Local package registry paths are metadata only; package asset folders are not copied into this snapshot.",
            "Windows GUI parity is not implied by this source-level import/export feature."
        ]
    });
    write_json_file(&path, &snapshot, "local snapshot")?;
    Ok(serde_json::json!({
        "schemaVersion": LOCAL_SNAPSHOT_SCHEMA_VERSION,
        "exportPath": path.to_string_lossy().to_string(),
        "exportedAt": exported_at,
    }))
}

/// Imports a local snapshot JSON file and replaces local settings/registry files.
#[tauri::command]
pub fn import_local_snapshot(
    config: State<'_, AppConfig>,
    import_path: String,
) -> Result<Value, String> {
    let path = PathBuf::from(import_path);
    let snapshot = read_json_file(&path, "local snapshot")?;
    let (settings, registry) = parse_local_snapshot(&snapshot)?;
    let settings_contents = serialize_json_value(&settings, "settings")?;
    let registry_contents = serialize_json_value(&registry, "registry")?;
    replace_snapshot_files(
        &settings_path(config.inner()),
        &registry_path(config.inner()),
        &settings_contents,
        &registry_contents,
        false,
    )?;
    Ok(serde_json::json!({
        "settings": settings,
        "registry": registry,
        "importedAt": timestamp_now(),
    }))
}

/// Imports a local package directory and registers it in the local registry.
#[tauri::command]
pub fn import_local_package(
    config: State<'_, AppConfig>,
    import_path: String,
) -> Result<Value, String> {
    let package_dir = PathBuf::from(import_path);
    if !package_dir.is_dir() {
        return Err(format!(
            "Import path is not a directory: {}",
            package_dir.display()
        ));
    }

    let manifest_path = package_dir.join("codexpet-package.json");
    let manifest_value = read_json_file(&manifest_path, "package manifest")?;
    let manifest: PackageManifestImport =
        serde_json::from_value(manifest_value.clone()).map_err(|error| {
            format!(
                "Invalid package manifest {}: {}",
                manifest_path.display(),
                error
            )
        })?;
    if manifest.package_type != "codexpet.nest" {
        return Err(format!(
            "Only codexpet.nest imports are supported in this phase, got {}",
            manifest.package_type
        ));
    }
    let layout = manifest
        .layout
        .clone()
        .or(manifest.theme.clone())
        .ok_or_else(|| "Nest package requires layout or theme".to_string())?;
    let layout_path = safe_join(&package_dir, &layout)?;
    let layout_value = read_json_file(&layout_path, "nest layout")?;
    validate_nest_layout(&layout_value)?;

    let mut registry = load_local_registry_value(config.inner())?;
    let now = timestamp_now();
    let existing = registry
        .get("packages")
        .and_then(Value::as_array)
        .and_then(|packages| {
            packages
                .iter()
                .find(|entry| entry.get("id") == Some(&Value::String(manifest.id.clone())))
        });
    let created_at = existing
        .and_then(|entry| entry.get("createdAt"))
        .and_then(Value::as_str)
        .unwrap_or(&now)
        .to_string();
    let enabled = existing
        .and_then(|entry| entry.get("enabled"))
        .and_then(Value::as_bool)
        .unwrap_or(true);
    let entry = serde_json::json!({
        "id": manifest.id,
        "type": "nest",
        "version": manifest.version,
        "name": manifest.name.or(manifest.display_name).unwrap_or_else(|| "Imported Nest".to_string()),
        "manifestPath": manifest_path.to_string_lossy().to_string(),
        "assetRoot": package_dir.to_string_lossy().to_string(),
        "enabled": enabled,
        "createdAt": created_at,
        "updatedAt": now,
    });
    upsert_registry_entry(&mut registry, entry)?;
    save_local_registry(config, registry.clone())?;
    Ok(registry)
}

/// Loads an imported nest package layout and reports missing local assets.
#[tauri::command]
pub fn load_local_nest_package(
    asset_root: String,
    manifest_path: String,
) -> Result<ImportedNestPackage, String> {
    let asset_root_path = PathBuf::from(asset_root);
    let manifest_path = PathBuf::from(manifest_path);
    let manifest_value = read_json_file(&manifest_path, "package manifest")?;
    let manifest: PackageManifestImport =
        serde_json::from_value(manifest_value.clone()).map_err(|error| {
            format!(
                "Invalid package manifest {}: {}",
                manifest_path.display(),
                error
            )
        })?;
    if manifest.package_type != "codexpet.nest" {
        return Err(format!(
            "Expected codexpet.nest, got {}",
            manifest.package_type
        ));
    }
    let layout = manifest
        .layout
        .or(manifest.theme)
        .ok_or_else(|| "Nest package requires layout or theme".to_string())?;
    let layout_path = safe_join(&asset_root_path, &layout)?;
    let nest_layout = read_json_file(&layout_path, "nest layout")?;
    validate_nest_layout(&nest_layout)?;
    let missing_assets = collect_missing_assets(&asset_root_path, &nest_layout)?;

    Ok(ImportedNestPackage {
        package_manifest: manifest_value,
        nest_layout,
        missing_assets,
    })
}

fn write_json_file(path: &PathBuf, value: &Value, label: &str) -> Result<(), String> {
    let parent = path
        .parent()
        .ok_or_else(|| format!("{} file has no parent directory: {}", label, path.display()))?;
    fs::create_dir_all(parent).map_err(|error| {
        format!(
            "Failed to create {} directory {}: {}",
            label,
            parent.display(),
            error
        )
    })?;

    let contents = serialize_json_value(value, label)?;
    fs::write(path, contents).map_err(|error| {
        format!(
            "Failed to write {} file {}: {}",
            label,
            path.display(),
            error
        )
    })
}

fn serialize_json_value(value: &Value, label: &str) -> Result<String, String> {
    serde_json::to_string_pretty(value)
        .map_err(|error| format!("Failed to serialize {}: {}", label, error))
}

fn read_json_file(path: &Path, label: &str) -> Result<Value, String> {
    let contents = fs::read_to_string(path)
        .map_err(|error| format!("Failed to read {} {}: {}", label, path.display(), error))?;
    serde_json::from_str(&contents)
        .map_err(|error| format!("Failed to parse {} {}: {}", label, path.display(), error))
}

fn load_local_registry_value(config: &AppConfig) -> Result<Value, String> {
    let path = registry_path(config);
    if !path.exists() {
        return Ok(serde_json::json!({ "schemaVersion": 1, "packages": [] }));
    }
    read_json_file(&path, "registry")
}

fn upsert_registry_entry(registry: &mut Value, entry: Value) -> Result<(), String> {
    let packages = registry
        .get_mut("packages")
        .and_then(Value::as_array_mut)
        .ok_or_else(|| "Registry requires packages array".to_string())?;
    let id = entry
        .get("id")
        .and_then(Value::as_str)
        .ok_or_else(|| "Registry entry requires id".to_string())?
        .to_string();
    if let Some(existing) = packages
        .iter_mut()
        .find(|package| package.get("id").and_then(Value::as_str) == Some(id.as_str()))
    {
        *existing = entry;
    } else {
        packages.push(entry);
    }
    Ok(())
}

fn collect_missing_assets(asset_root: &Path, nest_layout: &Value) -> Result<Vec<String>, String> {
    let mut assets = Vec::new();
    if let Some(layers) = nest_layout.get("layers").and_then(Value::as_array) {
        for layer in layers {
            if let Some(src) = layer.get("src").and_then(Value::as_str) {
                assets.push(src.to_string());
            }
        }
    }
    if let Some(elements) = nest_layout.get("elements").and_then(Value::as_array) {
        for element in elements {
            if let Some(src) = element.get("src").and_then(Value::as_str) {
                assets.push(src.to_string());
            }
            if let Some(fallback) = element.get("fallback").and_then(Value::as_str) {
                assets.push(fallback.to_string());
            }
            if let Some(variants) = element.get("variants").and_then(Value::as_object) {
                for value in variants.values() {
                    if let Some(src) = value.as_str() {
                        assets.push(src.to_string());
                    }
                }
            }
        }
    }
    assets
        .into_iter()
        .map(|asset| {
            let path = safe_join(asset_root, &asset)?;
            Ok((asset, path))
        })
        .collect::<Result<Vec<_>, String>>()
        .map(|entries| {
            entries
                .into_iter()
                .filter_map(|(asset, path)| if path.exists() { None } else { Some(asset) })
                .collect()
        })
}

fn parse_local_snapshot(snapshot: &Value) -> Result<(Value, Value), String> {
    let object = snapshot
        .as_object()
        .ok_or_else(|| "Local snapshot must be an object".to_string())?;
    match object.get("schemaVersion").and_then(Value::as_u64) {
        Some(LOCAL_SNAPSHOT_SCHEMA_VERSION) => {}
        Some(version) => {
            return Err(format!(
                "Unsupported local snapshot schemaVersion {}",
                version
            ))
        }
        None => return Err("Local snapshot requires schemaVersion".to_string()),
    }
    let data = object
        .get("data")
        .and_then(Value::as_object)
        .ok_or_else(|| "Local snapshot requires data object".to_string())?;
    let settings = data
        .get("settings")
        .cloned()
        .ok_or_else(|| "Local snapshot requires data.settings".to_string())?;
    let registry = data
        .get("registry")
        .cloned()
        .ok_or_else(|| "Local snapshot requires data.registry".to_string())?;
    validate_snapshot_payload(&settings, &registry)?;
    Ok((settings, registry))
}

fn validate_snapshot_payload(settings: &Value, registry: &Value) -> Result<(), String> {
    validate_snapshot_settings(settings)?;
    validate_snapshot_registry(registry)?;
    Ok(())
}

fn validate_snapshot_settings(settings: &Value) -> Result<(), String> {
    let object = settings
        .as_object()
        .ok_or_else(|| "Local snapshot settings must be an object".to_string())?;
    match object.get("schemaVersion").and_then(Value::as_u64) {
        Some(1..=CURRENT_SETTINGS_SCHEMA_VERSION) => Ok(()),
        Some(version) => Err(format!(
            "Unsupported local snapshot settings schemaVersion {}",
            version
        )),
        None => Err("Local snapshot settings requires schemaVersion".to_string()),
    }
}

fn validate_snapshot_registry(registry: &Value) -> Result<(), String> {
    let registry_object = registry
        .as_object()
        .ok_or_else(|| "Local snapshot registry must be an object".to_string())?;
    match registry_object.get("schemaVersion").and_then(Value::as_u64) {
        Some(CURRENT_REGISTRY_SCHEMA_VERSION) => {}
        Some(version) => {
            return Err(format!(
                "Unsupported local snapshot registry schemaVersion {}",
                version
            ))
        }
        None => return Err("Local snapshot registry requires schemaVersion".to_string()),
    }
    let packages = registry_object
        .get("packages")
        .and_then(Value::as_array)
        .ok_or_else(|| "Local snapshot registry requires packages array".to_string())?;
    for (index, entry) in packages.iter().enumerate() {
        validate_snapshot_registry_entry(entry, index)?;
    }
    Ok(())
}

fn validate_snapshot_registry_entry(entry: &Value, index: usize) -> Result<(), String> {
    let object = entry.as_object().ok_or_else(|| {
        format!(
            "Local snapshot registry package {} must be an object",
            index
        )
    })?;
    for key in ["id", "version", "name", "manifestPath", "assetRoot"] {
        let value = object.get(key).and_then(Value::as_str).unwrap_or("");
        if value.is_empty() {
            return Err(format!(
                "Local snapshot registry package {} requires {}",
                index, key
            ));
        }
    }
    match object.get("type").and_then(Value::as_str) {
        Some("pet" | "nest" | "codexpet.pet" | "codexpet.nest") => {}
        Some(value) => {
            return Err(format!(
                "Local snapshot registry package {} has unsupported type {}",
                index, value
            ))
        }
        None => {
            return Err(format!(
                "Local snapshot registry package {} requires type",
                index
            ))
        }
    }
    if object
        .get("enabled")
        .map(|value| !value.is_boolean())
        .unwrap_or(false)
    {
        return Err(format!(
            "Local snapshot registry package {} enabled must be boolean",
            index
        ));
    }
    Ok(())
}

fn replace_snapshot_files(
    settings_path: &Path,
    registry_path: &Path,
    settings_contents: &str,
    registry_contents: &str,
    fail_after_settings_replace: bool,
) -> Result<(), String> {
    let settings_temp = temp_path_for(settings_path, "settings");
    let registry_temp = temp_path_for(registry_path, "registry");
    write_staged_file(&settings_temp, settings_contents, "settings")?;
    if let Err(error) = write_staged_file(&registry_temp, registry_contents, "registry") {
        let _ = fs::remove_file(&settings_temp);
        return Err(error);
    }

    let mut backups = Vec::new();
    let result = (|| -> Result<(), String> {
        backups.push(backup_target(settings_path, "settings")?);
        backups.push(backup_target(registry_path, "registry")?);
        replace_from_temp(&settings_temp, settings_path, "settings")?;
        if fail_after_settings_replace {
            return Err("Simulated registry replace failure".to_string());
        }
        replace_from_temp(&registry_temp, registry_path, "registry")?;
        Ok(())
    })();

    match result {
        Ok(()) => {
            cleanup_backups(&backups);
            Ok(())
        }
        Err(error) => {
            let _ = fs::remove_file(&settings_temp);
            let _ = fs::remove_file(&registry_temp);
            rollback_backups(&backups);
            Err(error)
        }
    }
}

fn write_staged_file(path: &Path, contents: &str, label: &str) -> Result<(), String> {
    let parent = path.parent().ok_or_else(|| {
        format!(
            "{} temp file has no parent directory: {}",
            label,
            path.display()
        )
    })?;
    fs::create_dir_all(parent).map_err(|error| {
        format!(
            "Failed to create {} temp directory {}: {}",
            label,
            parent.display(),
            error
        )
    })?;
    fs::write(path, contents).map_err(|error| {
        format!(
            "Failed to write {} temp file {}: {}",
            label,
            path.display(),
            error
        )
    })
}

fn backup_target(target: &Path, label: &str) -> Result<SnapshotBackup, String> {
    let backup = backup_path_for(target, label);
    if backup.exists() {
        fs::remove_file(&backup).map_err(|error| {
            format!(
                "Failed to remove stale {} backup {}: {}",
                label,
                backup.display(),
                error
            )
        })?;
    }
    if target.exists() {
        fs::rename(target, &backup).map_err(|error| {
            format!(
                "Failed to stage existing {} file {}: {}",
                label,
                target.display(),
                error
            )
        })?;
        Ok(SnapshotBackup {
            target: target.to_path_buf(),
            backup: Some(backup),
        })
    } else {
        Ok(SnapshotBackup {
            target: target.to_path_buf(),
            backup: None,
        })
    }
}

fn replace_from_temp(temp: &Path, target: &Path, label: &str) -> Result<(), String> {
    fs::rename(temp, target).map_err(|error| {
        format!(
            "Failed to replace {} file {}: {}",
            label,
            target.display(),
            error
        )
    })
}

fn rollback_backups(backups: &[SnapshotBackup]) {
    for backup in backups.iter().rev() {
        let _ = fs::remove_file(&backup.target);
        if let Some(path) = &backup.backup {
            let _ = fs::rename(path, &backup.target);
        }
    }
}

fn cleanup_backups(backups: &[SnapshotBackup]) {
    for backup in backups {
        if let Some(path) = &backup.backup {
            let _ = fs::remove_file(path);
        }
    }
}

fn temp_path_for(target: &Path, label: &str) -> PathBuf {
    sibling_path_for(target, label, "tmp")
}

fn backup_path_for(target: &Path, label: &str) -> PathBuf {
    sibling_path_for(target, label, "bak")
}

fn sibling_path_for(target: &Path, label: &str, extension: &str) -> PathBuf {
    let parent = target.parent().unwrap_or_else(|| Path::new("."));
    let file_name = target
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or(label);
    parent.join(format!(
        ".{}.codexpet-import-{}.{}.{}",
        file_name,
        std::process::id(),
        timestamp_nanos(),
        extension
    ))
}

fn timestamp_nanos() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_nanos())
        .unwrap_or(0)
}

fn safe_join(root: &Path, relative: &str) -> Result<PathBuf, String> {
    let path = Path::new(relative);
    if relative.is_empty() || path.is_absolute() {
        return Err(format!(
            "Package path must be local and relative: {}",
            relative
        ));
    }
    for component in path.components() {
        match component {
            Component::Normal(_) => {}
            _ => {
                return Err(format!(
                    "Package path contains unsafe component: {}",
                    relative
                ))
            }
        }
    }
    Ok(root.join(path))
}

fn validate_nest_layout(layout: &Value) -> Result<(), String> {
    let object = layout
        .as_object()
        .ok_or_else(|| "nest layout must be an object".to_string())?;
    match object.get("schemaVersion").and_then(Value::as_str) {
        Some("1.0.0") | Some("1.1.0") => {}
        _ => return Err("nest layout schemaVersion must be 1.0.0 or 1.1.0".to_string()),
    }
    let canvas = object
        .get("canvas")
        .and_then(Value::as_object)
        .ok_or_else(|| "nest layout requires canvas object".to_string())?;
    for key in ["width", "height"] {
        let value = canvas
            .get(key)
            .and_then(Value::as_f64)
            .ok_or_else(|| format!("nest layout canvas requires numeric {}", key))?;
        if !value.is_finite() || value <= 0.0 {
            return Err(format!("nest layout canvas {} must be positive", key));
        }
    }
    let layers = object
        .get("layers")
        .and_then(Value::as_array)
        .ok_or_else(|| "nest layout requires layers array".to_string())?;
    for layer in layers {
        let src = layer
            .get("src")
            .and_then(Value::as_str)
            .ok_or_else(|| "nest layer requires src".to_string())?;
        safe_join(Path::new("."), src)?;
    }
    if let Some(elements) = object.get("elements").and_then(Value::as_array) {
        for element in elements {
            if let Some(src) = element.get("src").and_then(Value::as_str) {
                safe_join(Path::new("."), src)?;
            }
            if let Some(fallback) = element.get("fallback").and_then(Value::as_str) {
                safe_join(Path::new("."), fallback)?;
            }
            if let Some(variants) = element.get("variants").and_then(Value::as_object) {
                for value in variants.values() {
                    if let Some(src) = value.as_str() {
                        safe_join(Path::new("."), src)?;
                    }
                }
            }
        }
    }
    Ok(())
}

fn timestamp_now() -> String {
    let seconds = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_secs())
        .unwrap_or(0);
    format!("unix:{}", seconds)
}

fn settings_path(config: &AppConfig) -> PathBuf {
    PathBuf::from(&config.data_directory).join("settings.json")
}

fn registry_path(config: &AppConfig) -> PathBuf {
    PathBuf::from(&config.data_directory).join("registry.json")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_unsafe_package_paths() {
        assert!(safe_join(Path::new("/tmp/pkg"), "assets/a.png").is_ok());
        assert!(safe_join(Path::new("/tmp/pkg"), "../outside.png").is_err());
        assert!(safe_join(Path::new("/tmp/pkg"), "/tmp/outside.png").is_err());
        assert!(safe_join(Path::new("/tmp/pkg"), "").is_err());
    }

    #[test]
    fn validates_minimal_nest_layout_shape() {
        let valid = serde_json::json!({
            "schemaVersion": "1.0.0",
            "canvas": { "width": 100, "height": 80 },
            "layers": [{ "id": "bg", "type": "image", "src": "assets/bg.png", "frame": { "x": 0, "y": 0, "width": 100, "height": 80 } }]
        });
        let invalid = serde_json::json!({
            "schemaVersion": "1.0.0",
            "canvas": { "width": 100, "height": 80 },
            "layers": [{ "id": "bg", "type": "image", "src": "../outside.png" }]
        });

        assert!(validate_nest_layout(&valid).is_ok());
        assert!(validate_nest_layout(&invalid).is_err());
    }

    #[test]
    fn rejects_unsafe_element_asset_paths() {
        let invalid_src = serde_json::json!({
            "schemaVersion": "1.0.0",
            "canvas": { "width": 100, "height": 80 },
            "layers": [{ "id": "bg", "type": "image", "src": "assets/bg.png" }],
            "elements": [{ "id": "hat", "type": "image", "src": "../outside.png" }]
        });
        let invalid_fallback = serde_json::json!({
            "schemaVersion": "1.0.0",
            "canvas": { "width": 100, "height": 80 },
            "layers": [{ "id": "bg", "type": "image", "src": "assets/bg.png" }],
            "elements": [{ "id": "hat", "type": "image", "src": "assets/hat.png", "fallback": "../outside.png" }]
        });
        let invalid_variant = serde_json::json!({
            "schemaVersion": "1.0.0",
            "canvas": { "width": 100, "height": 80 },
            "layers": [{ "id": "bg", "type": "image", "src": "assets/bg.png" }],
            "elements": [{ "id": "hat", "type": "image", "variants": { "red": "assets/red-hat.png", "blue": "../outside.png" } }]
        });

        assert!(validate_nest_layout(&invalid_src).is_err());
        assert!(validate_nest_layout(&invalid_fallback).is_err());
        assert!(validate_nest_layout(&invalid_variant).is_err());
    }

    #[test]
    fn accepts_safe_element_asset_paths() {
        let valid = serde_json::json!({
            "schemaVersion": "1.0.0",
            "canvas": { "width": 100, "height": 80 },
            "layers": [{ "id": "bg", "type": "image", "src": "assets/bg.png" }],
            "elements": [{
                "id": "hat",
                "type": "image",
                "src": "assets/hat.png",
                "fallback": "assets/fallback-hat.png",
                "variants": { "red": "assets/red-hat.png", "blue": "assets/blue-hat.png" }
            }]
        });

        assert!(validate_nest_layout(&valid).is_ok());
    }

    #[test]
    fn parses_valid_local_snapshot() {
        let snapshot = serde_json::json!({
            "schemaVersion": 1,
            "data": {
                "settings": { "schemaVersion": 3, "activeNestId": null },
                "registry": {
                    "schemaVersion": 1,
                    "packages": [{
                        "id": "default",
                        "type": "nest",
                        "version": "1.0.0",
                        "name": "Default",
                        "manifestPath": "builtin/nests/default/codexpet-package.json",
                        "assetRoot": "builtin/nests/default",
                        "enabled": true
                    }]
                }
            }
        });

        let (settings, registry) = parse_local_snapshot(&snapshot).unwrap();
        assert_eq!(
            settings.get("schemaVersion").and_then(Value::as_u64),
            Some(3)
        );
        assert_eq!(
            registry
                .get("packages")
                .and_then(Value::as_array)
                .unwrap()
                .len(),
            1
        );
    }

    #[test]
    fn rejects_invalid_local_snapshot_shape() {
        let missing_data = serde_json::json!({ "schemaVersion": 1 });
        let missing_packages = serde_json::json!({
            "schemaVersion": 1,
            "data": {
                "settings": { "schemaVersion": 3 },
                "registry": { "schemaVersion": 1 }
            }
        });

        assert!(parse_local_snapshot(&missing_data).is_err());
        assert!(parse_local_snapshot(&missing_packages).is_err());
    }

    #[test]
    fn rejects_invalid_snapshot_settings_schema_version() {
        let snapshot = serde_json::json!({
            "schemaVersion": 1,
            "data": {
                "settings": { "schemaVersion": 999 },
                "registry": { "schemaVersion": 1, "packages": [] }
            }
        });

        let error = parse_local_snapshot(&snapshot).unwrap_err();
        assert!(error.contains("settings schemaVersion"));
    }

    #[test]
    fn rejects_invalid_snapshot_registry_schema_version() {
        let snapshot = serde_json::json!({
            "schemaVersion": 1,
            "data": {
                "settings": { "schemaVersion": 3 },
                "registry": { "schemaVersion": 999, "packages": [] }
            }
        });

        let error = parse_local_snapshot(&snapshot).unwrap_err();
        assert!(error.contains("registry schemaVersion"));
    }

    #[test]
    fn rejects_invalid_snapshot_registry_package_entry() {
        let not_object = serde_json::json!({
            "schemaVersion": 1,
            "data": {
                "settings": { "schemaVersion": 3 },
                "registry": { "schemaVersion": 1, "packages": ["invalid"] }
            }
        });
        let missing_field = serde_json::json!({
            "schemaVersion": 1,
            "data": {
                "settings": { "schemaVersion": 3 },
                "registry": {
                    "schemaVersion": 1,
                    "packages": [{
                        "id": "default",
                        "type": "nest",
                        "version": "1.0.0",
                        "name": "Default",
                        "manifestPath": "builtin/nests/default/codexpet-package.json"
                    }]
                }
            }
        });

        assert!(parse_local_snapshot(&not_object)
            .unwrap_err()
            .contains("must be an object"));
        assert!(parse_local_snapshot(&missing_field)
            .unwrap_err()
            .contains("assetRoot"));
    }

    #[test]
    fn failed_snapshot_replace_rolls_back_half_import() {
        let dir = unique_test_dir("snapshot-rollback");
        fs::create_dir_all(&dir).unwrap();
        let settings_path = dir.join("settings.json");
        let registry_path = dir.join("registry.json");
        let original_settings = r#"{"schemaVersion":3,"activeNestId":"old"}"#;
        let original_registry = r#"{"schemaVersion":1,"packages":[]}"#;
        fs::write(&settings_path, original_settings).unwrap();
        fs::write(&registry_path, original_registry).unwrap();

        let result = replace_snapshot_files(
            &settings_path,
            &registry_path,
            r#"{"schemaVersion":3,"activeNestId":"new"}"#,
            r#"{"schemaVersion":1,"packages":[{"id":"new"}]}"#,
            true,
        );

        assert!(result.is_err());
        assert_eq!(
            fs::read_to_string(&settings_path).unwrap(),
            original_settings
        );
        assert_eq!(
            fs::read_to_string(&registry_path).unwrap(),
            original_registry
        );
        let _ = fs::remove_dir_all(dir);
    }

    fn unique_test_dir(label: &str) -> PathBuf {
        std::env::temp_dir().join(format!(
            "codexpet-{}-{}-{}",
            label,
            std::process::id(),
            timestamp_nanos()
        ))
    }
}
