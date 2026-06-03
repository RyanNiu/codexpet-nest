/// Windows platform helpers.
///
/// **STATUS: NOT YET VERIFIED ON WINDOWS**
///
/// All Windows-specific code is documented here as stubs with expected
/// Win32 API calls. These will be implemented and validated when a Windows
/// test machine with Codex Desktop becomes available.
///
/// ## Potential Codex State Path (Windows, unverified)
///
/// ```
/// %USERPROFILE%\.codex\.codex-global-state.json
/// ```
///
/// This is the current resolver fallback because `dirs::home_dir()` maps to the
/// Windows user profile directory. It has NOT been verified against a real
/// Codex Desktop for Windows install, so Phase 11 keeps the path/schema as a
/// manual verification item. `CODEX_HOME` environment variable is checked first.
/// Do not treat this fallback path as product parity until a Windows machine
/// confirms the file exists and contains the expected avatar keys.
///
/// ## Expected Overlay Transparency (Windows)
///
/// Tauri v2 on Windows supports transparent windows via the WebviewWindowBuilder
/// `.transparent(true)` method. For system-level click-through and layered
/// window behavior:
///
/// ```rust,ignore
/// // Expected Windows API usage:
/// use windows::Win32::UI::WindowsAndMessaging::{
///     SetWindowLongPtrW, GetWindowLongPtrW,
///     SetLayeredWindowAttributes, WS_EX_LAYERED, WS_EX_TRANSPARENT,
///     GWL_EXSTYLE, LWA_ALPHA,
/// };
/// ```
///
/// ## Expected DPI Behavior (Windows)
///
/// Windows supports per-monitor DPI scaling at 100%, 125%, 150%, 175%, 200%.
/// Tauri v2 reports logical coordinates by default. Physical-to-logical
/// conversion can use:
///
/// ```rust,ignore
/// let scale_factor = window.scale_factor().unwrap_or(1.0);
/// let logical_x = physical_x / scale_factor;
/// ```
///
/// ## Codex Desktop on Windows (unverified)
///
/// Codex Desktop was released for Windows on March 4, 2026.
/// The following need manual verification:
/// - [ ] `.codex-global-state.json` exists at `%USERPROFILE%\.codex\`
/// - [ ] `electron-avatar-overlay-open` field present
/// - [ ] `electron-avatar-overlay-bounds` field present with same schema
/// - [ ] `electron-avatar-overlay-bounds.mascot` field present
/// - [ ] `electron-persisted-atom-state` field present
///
/// ## Fallback Plan
///
/// If Codex Desktop on Windows does NOT expose pet state via the global state
/// JSON, the fallback is:
/// - Offer standalone nest positioning (manual placement)
/// - Provide a "follow Codex" mode that's macOS-only until Windows support is confirmed
/// - Document the limitation clearly in the product
///
/// ## Icon behavior
///
/// On Windows, the tray icon `.icon_as_template(true)` call is ignored.
/// A proper `.ico` file with multiple sizes is used from `src-tauri/icons/`.

// This file is intentionally documentation-only for Phase 1.
// Windows code will be implemented when a Windows test machine is available.
#[cfg(target_os = "windows")]
pub mod windows_impl {
    // Reserved for Windows-specific implementations
}
