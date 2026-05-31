mod app_config;
mod commands;
mod tray;
mod windows;

pub use app_config::AppConfig;

use tauri::Manager;

/// Run the Tauri application. Called from main.rs.
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .setup(|app| {
            let config = app_config::AppConfig::detect(app.package_info());
            app.manage(config.clone());

            // Build tray (menu bar / system tray)
            let _tray_handle = tray::build(app.handle())?;

            // Create settings window (hidden on start — tray menu opens it)
            let _settings_window = windows::create_settings_window(app.handle())?;

            // Create overlay window (transparent, always-on-top, frameless)
            let _overlay_window = windows::create_overlay_window(app.handle())?;

            log::info!(
                "CodexPet Nest v{} started on {}",
                config.version,
                std::env::consts::OS
            );

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![commands::config::get_app_config,])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
