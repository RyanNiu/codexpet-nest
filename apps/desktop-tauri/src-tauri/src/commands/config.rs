use crate::app_config::AppConfig;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fs;
use std::path::{Path, PathBuf};
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
    let layout_path = package_dir.join(&layout);
    let _layout_value = read_json_file(&layout_path, "nest layout")?;

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
    let layout_path = asset_root_path.join(layout);
    let nest_layout = read_json_file(&layout_path, "nest layout")?;
    let missing_assets = collect_missing_assets(&asset_root_path, &nest_layout);

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

    let contents = serde_json::to_string_pretty(value)
        .map_err(|error| format!("Failed to serialize {}: {}", label, error))?;
    fs::write(path, contents).map_err(|error| {
        format!(
            "Failed to write {} file {}: {}",
            label,
            path.display(),
            error
        )
    })
}

fn read_json_file(path: &PathBuf, label: &str) -> Result<Value, String> {
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

fn collect_missing_assets(asset_root: &Path, nest_layout: &Value) -> Vec<String> {
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
        .filter(|asset| !asset_root.join(asset).exists())
        .collect()
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
