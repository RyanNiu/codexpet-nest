// objc 0.2.7 crate's `msg_send!` macro internally uses cfg(cargo-clippy) which
// triggers unexpected-cfgs warnings on Rust >= 1.96. Suppress until objc updates.
#![allow(unexpected_cfgs)]

use tauri::Runtime;

/// Apply true system-level transparency to a Tauri window on macOS.
///
/// Uses objc to set NSWindow properties:
/// - `backgroundColor = NSColor.clearColor`
/// - `isOpaque = false`
/// - `hasShadow = false`
///
/// Requires the `macos-private-api` feature flag on Tauri.
///
/// # Platform
/// This function is only compiled on macOS. On other platforms it is a no-op.
#[cfg(target_os = "macos")]
pub fn apply_native_transparency<R: Runtime>(window: &tauri::WebviewWindow<R>) {
    use objc::rc::autoreleasepool;
    use objc::{class, msg_send, sel, sel_impl};

    // Get NSWindow handle — log error but don't panic if it fails
    let ns_window = match window.ns_window() {
        Ok(nsw) => nsw,
        Err(e) => {
            log::error!("apply_native_transparency: failed to get NSWindow: {}", e);
            return;
        }
    };

    #[allow(unsafe_code)]
    unsafe {
        autoreleasepool(|| {
            // Debug: barely-visible tint so overlay boundaries are visible.
            // Release: full transparency.
            #[cfg(debug_assertions)]
            let bg_color: *mut objc::runtime::Object = {
                msg_send![class!(NSColor), colorWithRed:0.0f64 green:0.0f64 blue:0.0f64 alpha:0.08f64]
            };
            #[cfg(not(debug_assertions))]
            let bg_color: *mut objc::runtime::Object = msg_send![class!(NSColor), clearColor];

            let _: () =
                msg_send![ns_window as *mut objc::runtime::Object, setBackgroundColor: bg_color];

            // Make non-opaque
            let _: () = msg_send![ns_window as *mut objc::runtime::Object, setOpaque: false as objc::runtime::BOOL];

            // Remove window shadow for cleaner overlay appearance
            let _: () = msg_send![ns_window as *mut objc::runtime::Object, setHasShadow: false as objc::runtime::BOOL];

            // Set window level to floating (always on top)
            let floating_level: isize = 5; // NSFloatingWindowLevel
            let _: () =
                msg_send![ns_window as *mut objc::runtime::Object, setLevel: floating_level];
        });
    }

    log::info!("Applied native transparency to overlay window");
}

/// Toggle click-through mode on macOS.
///
/// When `enabled` is true, mouse events pass through the window to
/// applications below it. When false, the window receives mouse events normally.
///
/// # Safety
/// This function calls NSWindow APIs via objc. It MUST be called from the
/// macOS main thread. Callers should invoke it from a synchronous Tauri
/// command (not async, which runs on a thread pool).
///
/// # Platform
/// This function is only compiled on macOS. On other platforms it is a no-op.
#[cfg(target_os = "macos")]
pub fn set_click_through<R: Runtime>(
    window: &tauri::WebviewWindow<R>,
    enabled: bool,
) -> Result<(), String> {
    #[allow(unsafe_code)]
    unsafe {
        let ns_window = window
            .ns_window()
            .map_err(|e| format!("failed to get NSWindow: {}", e))?;

        use objc::{msg_send, sel, sel_impl};
        let _: () = msg_send![ns_window as *mut objc::runtime::Object, setIgnoresMouseEvents: enabled as objc::runtime::BOOL];
        log::info!("Overlay click-through set to: {}", enabled);
    }
    Ok(())
}

/// Platforms other than macOS: stub implementations that log warnings.
#[cfg(not(target_os = "macos"))]
pub fn apply_native_transparency<R: Runtime>(_window: &tauri::WebviewWindow<R>) {
    log::warn!(
        "Native transparency not yet verified on {}. \
         Expected Windows approach: SetWindowLongPtrW with WS_EX_LAYERED \
         and WS_EX_TRANSPARENT, then SetLayeredWindowAttributes.",
        std::env::consts::OS
    );
}

#[cfg(target_os = "windows")]
pub const WINDOWS_CLICK_THROUGH_NOT_IMPLEMENTED: &str =
    "Windows click-through is not implemented yet";

/// Stub for Windows until Phase 12 implements the Win32 hit-test/layered-window path.
#[cfg(target_os = "windows")]
pub fn set_click_through<R: Runtime>(
    _window: &tauri::WebviewWindow<R>,
    enabled: bool,
) -> Result<(), String> {
    log::warn!(
        "{}. Requested enabled={}. Expected Phase 12 Win32 implementation: WS_EX_LAYERED + WS_EX_TRANSPARENT.",
        WINDOWS_CLICK_THROUGH_NOT_IMPLEMENTED,
        enabled
    );
    Err(WINDOWS_CLICK_THROUGH_NOT_IMPLEMENTED.to_string())
}

/// Stub for other non-macOS platforms.
#[cfg(all(not(target_os = "macos"), not(target_os = "windows")))]
pub fn set_click_through<R: Runtime>(
    _window: &tauri::WebviewWindow<R>,
    enabled: bool,
) -> Result<(), String> {
    log::warn!(
        "Click-through is not implemented on {}. Requested enabled={}",
        std::env::consts::OS,
        enabled
    );
    Err(format!(
        "Click-through is not implemented on {}",
        std::env::consts::OS
    ))
}
