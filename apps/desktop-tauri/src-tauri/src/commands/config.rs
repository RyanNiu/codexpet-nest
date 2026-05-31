use crate::app_config::AppConfig;
use tauri::State;

/// Returns the unified application configuration to the frontend.
#[tauri::command]
pub fn get_app_config(config: State<'_, AppConfig>) -> Result<AppConfig, String> {
    Ok(config.inner().clone())
}
