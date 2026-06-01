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
        .plugin(tauri_plugin_shell::init())
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
                // Enlarge overlay to 320×120 logical px for easier visual verification.
                let _ = _overlay_window.set_size(tauri::PhysicalSize::new(320u32, 120u32));

                // Position overlay at top‑right of the primary monitor
                if let Ok(Some(monitor)) = app.primary_monitor() {
                    let size = monitor.size();
                    let _scale = monitor.scale_factor();
                    let monitor_w = size.width as i32;
                    // overlay is 320×120 logical px; place it top‑right below menu bar.
                    // margin=12px from right edge → x = monitor_w - 332.
                    // Using y=80 in physical px to stay clear of macOS menu bar (~48px).
                    let overlay_x = monitor_w - 332;
                    let _ = _overlay_window
                        .set_position(tauri::PhysicalPosition::new(overlay_x.max(0), 80));
                    log::info!(
                        "Debug mode: overlay 320×120 at ({}, 80) [monitor_w={}, scale={:.1}]",
                        overlay_x,
                        monitor_w,
                        _scale
                    );
                }

                let _ = _settings_window.show();
                let _ = _settings_window.set_focus();
                log::info!("Debug mode: settings window shown on startup");
            }

            log::info!(
                "CodexPet Nest v{} started on {}",
                config.version,
                std::env::consts::OS
            );

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::config::get_app_config,
            commands::debug::get_codex_state,
            commands::debug::get_screen_list,
            commands::debug::convert_position,
            commands::debug::set_overlay_click_through,
            commands::debug::show_overlay,
            commands::debug::hide_overlay,
            commands::debug::is_overlay_visible,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
