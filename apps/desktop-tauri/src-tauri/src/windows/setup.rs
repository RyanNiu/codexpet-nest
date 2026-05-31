use tauri::{WebviewUrl, WebviewWindowBuilder};

/// Create the settings window — a normal, titled, resizable window.
pub fn create_settings_window<R: tauri::Runtime>(
    app: &tauri::AppHandle<R>,
) -> tauri::Result<tauri::WebviewWindow<R>> {
    let window = WebviewWindowBuilder::new(app, "main", WebviewUrl::App("index.html".into()))
        .title("CodexPet Nest Settings")
        .inner_size(400.0, 500.0)
        .min_inner_size(360.0, 400.0)
        .center()
        .visible(false) // Hidden on startup; tray menu shows it
        .resizable(true)
        .decorations(true)
        .build()?;

    Ok(window)
}

/// Create the transparent overlay window — frameless, always-on-top, skip taskbar.
pub fn create_overlay_window<R: tauri::Runtime>(
    app: &tauri::AppHandle<R>,
) -> tauri::Result<tauri::WebviewWindow<R>> {
    let window = WebviewWindowBuilder::new(app, "overlay", WebviewUrl::App("index.html".into()))
        .title("CodexPet Nest Overlay")
        .inner_size(220.0, 72.0)
        .resizable(false)
        .decorations(false)
        .always_on_top(true)
        .skip_taskbar(true)
        .visible(true) // Overlay starts visible
        .build()?;

    // Phase 1 Risk Spike: true system-level transparency is NOT verified here.
    // This window currently uses CSS `background: transparent` only.
    // Native transparency (NSWindow.backgroundColor = .clear / WS_EX_LAYERED)
    // and click-through behavior must be validated in Phase 1 before claiming
    // "transparent overlay" as done.

    Ok(window)
}
