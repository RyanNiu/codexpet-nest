use tauri::{Manager, Runtime, WebviewUrl, WebviewWindowBuilder, WindowEvent};

use crate::platform;

pub const DEBUG_OVERLAY_WIDTH: f64 = 480.0;
pub const DEBUG_OVERLAY_HEIGHT: f64 = 260.0;

/// Create the settings window — a normal, titled, resizable window.
pub fn create_settings_window<R: Runtime>(
    app: &tauri::AppHandle<R>,
) -> tauri::Result<tauri::WebviewWindow<R>> {
    let window =
        WebviewWindowBuilder::new(app, "main", WebviewUrl::App("index.html?label=main".into()))
            .title("CodexPet Nest Settings")
            .inner_size(400.0, 500.0)
            .min_inner_size(360.0, 400.0)
            .center()
            .visible(false) // Hidden on startup; tray menu shows it
            .resizable(true)
            .decorations(true)
            .build()?;

    register_settings_close_to_hide(&window);

    Ok(window)
}

fn register_settings_close_to_hide<R: Runtime>(window: &tauri::WebviewWindow<R>) {
    let window_to_hide = window.clone();
    window.on_window_event(move |event| {
        if let WindowEvent::CloseRequested { api, .. } = event {
            api.prevent_close();
            if let Err(error) = window_to_hide.hide() {
                log::error!("Failed to hide settings window on close: {}", error);
            }
        }
    });
}

/// Create the transparent overlay window — frameless, always-on-top, skip taskbar.
///
/// Uses `.transparent(true)` from Tauri v2's WebviewWindowBuilder.
/// On macOS, additionally applies native NSWindow transparency via
/// `platform::macos::apply_native_transparency()` after build.
///
/// Click-through mode starts OFF (window captures mouse events normally).
/// Use `set_overlay_click_through` Tauri command to toggle.
pub fn create_overlay_window<R: Runtime>(
    app: &tauri::AppHandle<R>,
) -> tauri::Result<tauri::WebviewWindow<R>> {
    let window = WebviewWindowBuilder::new(
        app,
        "overlay",
        WebviewUrl::App("index.html?label=overlay".into()),
    )
    .title("CodexPet Nest Overlay")
    .inner_size(
        if cfg!(debug_assertions) {
            DEBUG_OVERLAY_WIDTH
        } else {
            220.0
        },
        if cfg!(debug_assertions) {
            DEBUG_OVERLAY_HEIGHT
        } else {
            72.0
        },
    )
    .resizable(false)
    .decorations(false)
    .always_on_top(true)
    .skip_taskbar(true)
    .visible(true)
    .transparent(true)
    .build()?;

    // Apply native system-level transparency (macOS: NSWindow.backgroundColor = .clear, etc.)
    platform::macos::apply_native_transparency(&window);

    log::info!("Overlay window created with native transparency");

    Ok(window)
}

pub fn show_overlay_window<R: Runtime>(app: &tauri::AppHandle<R>) -> Result<(), String> {
    let window = app
        .get_webview_window("overlay")
        .ok_or_else(|| "Overlay window not found".to_string())?;

    window
        .show()
        .map_err(|error| format!("Failed to show overlay window: {}", error))
}

pub fn hide_overlay_window<R: Runtime>(app: &tauri::AppHandle<R>) -> Result<(), String> {
    let window = app
        .get_webview_window("overlay")
        .ok_or_else(|| "Overlay window not found".to_string())?;

    window
        .hide()
        .map_err(|error| format!("Failed to hide overlay window: {}", error))
}

pub fn is_overlay_window_visible<R: Runtime>(app: &tauri::AppHandle<R>) -> Result<bool, String> {
    let window = app
        .get_webview_window("overlay")
        .ok_or_else(|| "Overlay window not found".to_string())?;

    window
        .is_visible()
        .map_err(|error| format!("Failed to read overlay window visibility: {}", error))
}

pub fn resize_overlay_debug_window<R: Runtime>(app: &tauri::AppHandle<R>) -> Result<(), String> {
    let window = app
        .get_webview_window("overlay")
        .ok_or_else(|| "Overlay window not found".to_string())?;

    window
        .set_size(tauri::LogicalSize::new(
            DEBUG_OVERLAY_WIDTH,
            DEBUG_OVERLAY_HEIGHT,
        ))
        .map_err(|error| format!("Failed to resize overlay window: {}", error))
}

pub fn reset_overlay_position_window<R: Runtime>(app: &tauri::AppHandle<R>) -> Result<(), String> {
    let window = app
        .get_webview_window("overlay")
        .ok_or_else(|| "Overlay window not found".to_string())?;

    let monitor = app
        .primary_monitor()
        .map_err(|error| format!("Failed to read primary monitor: {}", error))?
        .ok_or_else(|| "Primary monitor not found".to_string())?;
    let monitor_position = monitor.position();
    let monitor_size = monitor.size();
    let window_size = window
        .outer_size()
        .map_err(|error| format!("Failed to read overlay window size: {}", error))?;

    let x = monitor_position.x + monitor_size.width as i32 - window_size.width as i32 - 24;
    let y = monitor_position.y + 80;

    window
        .set_position(tauri::PhysicalPosition::new(x.max(monitor_position.x), y))
        .map_err(|error| format!("Failed to reset overlay position: {}", error))
}

pub fn show_settings_window<R: Runtime>(app: &tauri::AppHandle<R>) -> Result<(), String> {
    let window = match app.get_webview_window("main") {
        Some(window) => window,
        None => create_settings_window(app)
            .map_err(|error| format!("Failed to create settings window: {}", error))?,
    };

    window
        .show()
        .map_err(|error| format!("Failed to show settings window: {}", error))?;
    window
        .unminimize()
        .map_err(|error| format!("Failed to unminimize settings window: {}", error))?;
    window
        .set_focus()
        .map_err(|error| format!("Failed to focus settings window: {}", error))
}
