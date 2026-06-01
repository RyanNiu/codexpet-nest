use directories::ProjectDirs;
use serde::Serialize;

/// Unified application configuration shared with the React frontend
/// via the `get_app_config` Tauri command.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AppConfig {
    pub app_name: String,
    pub version: String,
    pub bundle_id: String,
    pub api_base_url: String,
    pub data_directory: String,
    pub is_debug: bool,
    pub platform: String,
}

impl AppConfig {
    /// Detect runtime configuration from the package info and OS environment.
    pub fn detect(package_info: &tauri::PackageInfo) -> Self {
        let version = package_info.version.to_string();
        let app_name = "CodexPet Nest".to_string();
        let bundle_id = "xyz.codexpet.nest".to_string();

        let data_directory = ProjectDirs::from("xyz", "codexpet", "CodexPet Nest")
            .map(|dirs| dirs.data_dir().to_string_lossy().to_string())
            .unwrap_or_else(get_fallback_data_dir);

        let platform = std::env::consts::OS.to_string();

        Self {
            app_name,
            version,
            bundle_id,
            api_base_url: "https://codexpet.xyz".to_string(),
            data_directory,
            is_debug: cfg!(debug_assertions),
            platform,
        }
    }
}

#[cfg(target_os = "macos")]
fn get_fallback_data_dir() -> String {
    let home = dirs::home_dir().unwrap_or_default();
    home.join("Library/Application Support/CodexPet Nest")
        .to_string_lossy()
        .to_string()
}

#[cfg(not(target_os = "macos"))]
fn get_fallback_data_dir() -> String {
    let home = dirs::home_dir().unwrap_or_default();
    home.join(".codexpet-nest").to_string_lossy().to_string()
}
