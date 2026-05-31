use tauri::{
    menu::{MenuBuilder, MenuItemBuilder, PredefinedMenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    AppHandle, Manager, Runtime,
};

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
    // Uses the app icon as the tray icon. We set icon_as_template for macOS.
    let tray = TrayIconBuilder::with_id("codexpet-tray")
        .tooltip("CodexPet Nest")
        .icon_as_template(true)
        .menu(&menu)
        .on_menu_event(|app, event| match event.id().as_ref() {
            "show_overlay" => {
                if let Some(window) = app.get_webview_window("overlay") {
                    let _ = window.show();
                }
            }
            "hide_overlay" => {
                if let Some(window) = app.get_webview_window("overlay") {
                    let _ = window.hide();
                }
            }
            "open_settings" => {
                if let Some(window) = app.get_webview_window("main") {
                    let _ = window.show();
                    let _ = window.set_focus();
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
                if let Some(window) = app.get_webview_window("overlay") {
                    if window.is_visible().unwrap_or(false) {
                        let _ = window.hide();
                    } else {
                        let _ = window.show();
                    }
                }
            }
        })
        .build(app)?;

    Ok(tray)
}
