// objc 0.2.7 generates cfg(cargo-clippy) inside macros which triggers
// unexpected-cfgs warnings on Rust >= 1.96. Suppress crate-wide.
#![allow(unexpected_cfgs)]

mod app_config;
mod codex_state;
mod commands;
mod coords;
mod platform;
mod tray;
mod windows;

pub use app_config::AppConfig;
pub use codex_state::CodexState;

use tauri::Manager;

/// Run the Tauri application. Called from main.rs.
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .setup(|app| {
            let config = app_config::AppConfig::detect(app.package_info());
            app.manage(config.clone());

            // Build tray (menu bar / system tray)
            let _tray_handle = tray::build(app.handle())?;

            // Create settings window
            let _settings_window = windows::create_settings_window(app.handle())?;

            // Create overlay window (transparent, always-on-top, frameless)
            let _overlay_window = windows::create_overlay_window(app.handle())?;

            // In debug/dev mode, show settings window immediately so the user can
            // operate debug controls without relying on the tray icon.
            // Also position the overlay at the top‑right corner so it does not
            // obstruct the settings window that is centered.
            #[cfg(debug_assertions)]
            {
                let _ = windows::resize_overlay_debug_window(app.handle());
                let _ = windows::reset_overlay_position_window(app.handle());

                let _ = _settings_window.show();
                let _ = _settings_window.set_focus();
                log::info!("Debug mode: overlay resized to 480x260 and settings window shown");
            }

            log::info!(
                "CodexPet Nest v{} started on {}",
                config.version,
                std::env::consts::OS
            );

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::actions::execute_quick_action,
            commands::actions::get_action_capabilities,
            commands::actions::list_supported_actions,
            commands::config::get_app_config,
            commands::config::load_local_settings,
            commands::config::load_local_registry,
            commands::config::import_local_package,
            commands::config::load_local_nest_package,
            commands::config::export_local_snapshot,
            commands::config::import_local_snapshot,
            commands::config::save_local_registry,
            commands::config::save_local_settings,
            commands::debug::get_codex_state,
            commands::debug::get_screen_list,
            commands::debug::convert_position,
            commands::debug::set_overlay_click_through,
            commands::debug::show_overlay,
            commands::debug::hide_overlay,
            commands::debug::is_overlay_visible,
            commands::debug::reset_overlay_position,
            commands::debug::resize_overlay_debug,
            commands::debug::get_overlay_position,
            commands::debug::set_overlay_position,
            commands::debug::move_overlay_to_clamped,
            commands::debug::move_overlay_by,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
