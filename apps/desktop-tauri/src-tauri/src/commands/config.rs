use crate::app_config::AppConfig;
use serde_json::Value;
use std::fs;
use std::path::PathBuf;
use tauri::State;

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
    let parent = path
        .parent()
        .ok_or_else(|| format!("Settings file has no parent directory: {}", path.display()))?;
    fs::create_dir_all(parent).map_err(|error| {
        format!(
            "Failed to create settings directory {}: {}",
            parent.display(),
            error
        )
    })?;

    let contents = serde_json::to_string_pretty(&settings)
        .map_err(|error| format!("Failed to serialize settings: {}", error))?;
    fs::write(&path, contents).map_err(|error| {
        format!(
            "Failed to write settings file {}: {}",
            path.display(),
            error
        )
    })
}

fn settings_path(config: &AppConfig) -> PathBuf {
    PathBuf::from(&config.data_directory).join("settings.json")
}
