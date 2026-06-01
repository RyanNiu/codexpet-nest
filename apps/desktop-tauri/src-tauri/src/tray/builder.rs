use tauri::{
    menu::{MenuBuilder, MenuItemBuilder, PredefinedMenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    AppHandle, Runtime,
};

use crate::windows;

/// Build the system tray (menu bar on macOS, system tray on Windows/Linux).
pub fn build<R: Runtime>(app: &AppHandle<R>) -> tauri::Result<tauri::tray::TrayIcon<R>> {
    // --- Menu Items ---
    let show_overlay = MenuItemBuilder::with_id("show_overlay", "Show Overlay").build(app)?;
    let hide_overlay = MenuItemBuilder::with_id("hide_overlay", "Hide Overlay").build(app)?;
    let settings = MenuItemBuilder::with_id("open_settings", "Open Settings...")
        .accelerator("CmdOrCtrl+,")
        .build(app)?;
    let quit = PredefinedMenuItem::quit(app, Some("Quit CodexPet Nest"))?;

    let menu = MenuBuilder::new(app)
        .item(&show_overlay)
        .item(&hide_overlay)
        .item(&PredefinedMenuItem::separator(app)?)
        .item(&settings)
        .item(&PredefinedMenuItem::separator(app)?)
        .item(&quit)
        .build()?;

    // --- Tray Icon ---
    // Embed the 32×32 PNG icon so it is available at runtime even in dev mode.
    // On macOS, icon_as_template treats the icon as a monochrome template that
    // adapts to light/dark menu bar appearance.
    let tray = TrayIconBuilder::with_id("codexpet-tray")
        .tooltip("CodexPet Nest")
        .icon_as_template(true)
        .icon(
            tauri::image::Image::from_bytes(include_bytes!("../../icons/32x32.png"))
                .expect("failed to load tray icon from embedded 32x32.png"),
        )
        .menu(&menu)
        .on_menu_event(|app, event| match event.id().as_ref() {
            "show_overlay" => {
                if let Err(error) = windows::show_overlay_window(app) {
                    log::error!("{}", error);
                }
            }
            "hide_overlay" => {
                if let Err(error) = windows::hide_overlay_window(app) {
                    log::error!("{}", error);
                }
            }
            "open_settings" => {
                if let Err(error) = windows::show_settings_window(app) {
                    log::error!("{}", error);
                }
            }
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            // On Windows/Linux: left-click toggles overlay visibility
            if let TrayIconEvent::Click {
                button: MouseButton::Left,
                button_state: MouseButtonState::Up,
                ..
            } = event
            {
                let app = tray.app_handle();
                match windows::is_overlay_window_visible(app) {
                    Ok(true) => {
                        if let Err(error) = windows::hide_overlay_window(app) {
                            log::error!("{}", error);
                        }
                    }
                    Ok(false) => {
                        if let Err(error) = windows::show_overlay_window(app) {
                            log::error!("{}", error);
                        }
                    }
                    Err(error) => {
                        log::error!("{}", error);
                    }
                }
            }
        })
        .build(app)?;

    Ok(tray)
}
