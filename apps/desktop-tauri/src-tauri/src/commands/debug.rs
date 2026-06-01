use crate::codex_state::{self, CodexState};
use crate::coords::{self, ConvertedPosition, ScreenInfo};
use crate::platform;
use crate::windows;
use tauri::Manager;

/// Returns the current Codex pet state: overlay open/closed, bounds, etc.
#[tauri::command]
pub fn get_codex_state() -> CodexState {
    codex_state::read_codex_state()
}

fn is_primary_monitor(
    app: &tauri::AppHandle,
    pos: &tauri::PhysicalPosition<i32>,
    size: &tauri::PhysicalSize<u32>,
) -> bool {
    if let Ok(Some(primary)) = app.primary_monitor() {
        *pos == *primary.position() && *size == *primary.size()
    } else {
        false
    }
}

/// Returns a list of available screens with their bounds and scale factors.
///
/// Uses `available_monitors()` which returns all connected monitors including the primary.
/// The primary monitor is identified by comparing position/size with `primary_monitor()`.
#[tauri::command]
pub fn get_screen_list(app: tauri::AppHandle) -> Vec<ScreenInfo> {
    let mut screens = Vec::new();

    if let Ok(monitors) = app.available_monitors() {
        for mon in monitors {
            let size = mon.size();
            let pos = mon.position();
            screens.push(ScreenInfo {
                x: pos.x,
                y: pos.y,
                width: size.width as i32,
                height: size.height as i32,
                scale_factor: mon.scale_factor(),
                is_primary: is_primary_monitor(&app, pos, size),
            });
        }
    }

    // If no screens found, provide a fallback
    if screens.is_empty() {
        screens.push(ScreenInfo {
            x: 0,
            y: 0,
            width: 1920,
            height: 1080,
            scale_factor: 1.0,
            is_primary: true,
        });
    }

    screens
}

/// Convert Codex overlay position to a nest position.
#[tauri::command]
pub fn convert_position(
    codex_x: f64,
    codex_y: f64,
    codex_width: f64,
    codex_height: f64,
    screens: Vec<ScreenInfo>,
    scale: f64,
) -> ConvertedPosition {
    coords::convert_codex_to_nest_position(
        codex_x,
        codex_y,
        codex_width,
        codex_height,
        &screens,
        scale,
    )
}

/// Toggle click-through mode on the overlay window.
///
/// IMPORTANT: Must be a synchronous (non-async) command because
/// `setIgnoresMouseEvents:` is an AppKit API that MUST run on the
/// macOS main thread. Async Tauri commands run on a thread pool.
#[tauri::command]
pub fn set_overlay_click_through(app: tauri::AppHandle, enabled: bool) -> Result<(), String> {
    if let Some(window) = app.get_webview_window("overlay") {
        platform::macos::set_click_through(&window, enabled)
            .map_err(|e| format!("Failed to set click-through: {}", e))
    } else {
        Err("Overlay window not found".to_string())
    }
}

#[tauri::command]
pub fn show_overlay(app: tauri::AppHandle) -> Result<(), String> {
    windows::show_overlay_window(&app)
}

#[tauri::command]
pub fn hide_overlay(app: tauri::AppHandle) -> Result<(), String> {
    windows::hide_overlay_window(&app)
}

#[tauri::command]
pub fn is_overlay_visible(app: tauri::AppHandle) -> Result<bool, String> {
    windows::is_overlay_window_visible(&app)
}

#[tauri::command]
pub fn reset_overlay_position(app: tauri::AppHandle) -> Result<(), String> {
    windows::reset_overlay_position_window(&app)
}

#[tauri::command]
pub fn resize_overlay_debug(app: tauri::AppHandle) -> Result<(), String> {
    windows::resize_overlay_debug_window(&app)
}
