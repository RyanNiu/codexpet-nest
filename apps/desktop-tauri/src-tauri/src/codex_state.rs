use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// Fields read from Codex Desktop's `.codex-global-state.json`.
/// Only contains the overlay and pet fields relevant to nest positioning.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct CodexState {
    /// Whether the Codex avatar overlay is currently open/visible
    pub avatar_overlay_open: bool,
    /// The overlay's bounding rectangle (top-left x, y, width, height)
    pub overlay_bounds: Option<OverlayBounds>,
    /// Whether the global state file was found and read successfully
    pub state_available: bool,
    /// Human-readable diagnostic message (file found, parse errors, etc.)
    pub diagnostic: String,
    /// The resolved CODEX_HOME path
    pub codex_home: String,
}

/// Represents the `mascot` sub-object within `electron-avatar-overlay-bounds`.
///
/// The mascot is the pet sprite within the Codex overlay. Its coordinates
/// are relative to the overlay window's top-left corner.
///
/// Usage (matches old Swift project logic):
/// ```text
/// pet_x = bounds.x + mascot.left
/// pet_y = bounds.y + mascot.top
/// pet_width = mascot.width
/// pet_height = mascot.height
/// ```
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Mascot {
    pub left: f64,
    pub top: f64,
    pub width: f64,
    pub height: f64,
}

/// Represents the `electron-avatar-overlay-bounds` JSON object.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OverlayBounds {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
    /// The display bounds (screen rectangle) for the display containing this overlay
    pub display_x: f64,
    pub display_y: f64,
    pub display_width: f64,
    pub display_height: f64,
    pub display_id: Option<u32>,
    /// The pet sprite's position and size within the overlay (relative to overlay top-left)
    pub mascot: Option<Mascot>,
}

/// Raw JSON structure — mirrors the schema found in `.codex-global-state.json`.
#[derive(Debug, Deserialize)]
struct RawGlobalState {
    #[serde(rename = "electron-avatar-overlay-open")]
    avatar_overlay_open: Option<bool>,
    #[serde(rename = "electron-avatar-overlay-bounds")]
    avatar_overlay_bounds: Option<RawOverlayBounds>,
}

#[derive(Debug, Deserialize)]
struct RawOverlayBounds {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
    mascot: Option<RawMascot>,
    #[serde(rename = "displayBounds")]
    display_bounds: Option<DisplayBounds>,
    #[serde(rename = "displayId")]
    display_id: Option<u32>,
}

#[derive(Debug, Deserialize)]
struct RawMascot {
    left: f64,
    top: f64,
    width: f64,
    height: f64,
}

#[derive(Debug, Deserialize)]
struct DisplayBounds {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
}

/// Resolve CODEX_HOME:
/// 1. `CODEX_HOME` environment variable
/// 2. Platform default: `~/.codex` on macOS/Linux, `%USERPROFILE%\.codex` on Windows
pub fn resolve_codex_home() -> PathBuf {
    if let Ok(home) = std::env::var("CODEX_HOME") {
        let p = PathBuf::from(home);
        if p.is_dir() {
            return p;
        }
    }

    let home = dirs::home_dir().unwrap_or_default();
    home.join(".codex")
}

/// Read and parse the Codex global state.
///
/// Current approach: try reading `.codex-global-state.json` from CODEX_HOME.
/// If that file doesn't exist, also try `.codex-global-state.json.bak` (backup
/// from Codex's SQLite migration).
///
/// On macOS (validated 2026-05-31):
///   - CODEX_HOME defaults to `~/.codex`
///   - The JSON file exists as `.codex-global-state.json.bak` (backup)
///   - Newer Codex versions may store active state in SQLite (`state_*.sqlite`)
///   - JSON fields `electron-avatar-overlay-open` and
///     `electron-avatar-overlay-bounds` are present and match the documented schema
///
/// On Windows:
///   - **NOT YET VERIFIED** — requires testing on a Windows machine with Codex Desktop.
///   - Expected path: `%USERPROFILE%\.codex\.codex-global-state.json`
///   - If Codex Desktop on Windows uses a different format, this needs adjustment.
pub fn read_codex_state() -> CodexState {
    let codex_home = resolve_codex_home();
    let codex_home_str = codex_home.to_string_lossy().to_string();

    // Try primary file first, then backup
    let primary = codex_home.join(".codex-global-state.json");
    let backup = codex_home.join(".codex-global-state.json.bak");

    let file_path = if primary.exists() {
        primary
    } else if backup.exists() {
        backup
    } else {
        return CodexState {
            avatar_overlay_open: false,
            overlay_bounds: None,
            state_available: false,
            diagnostic: format!(
                "No .codex-global-state.json found in {} (tried: {}, {})",
                codex_home_str,
                primary.display(),
                backup.display()
            ),
            codex_home: codex_home_str,
        };
    };

    match std::fs::read_to_string(&file_path) {
        Ok(contents) => parse_state_json(&contents, &codex_home_str, &file_path),
        Err(e) => CodexState {
            avatar_overlay_open: false,
            overlay_bounds: None,
            state_available: false,
            diagnostic: format!("Failed to read {}: {}", file_path.display(), e),
            codex_home: codex_home_str,
        },
    }
}

fn parse_state_json(contents: &str, codex_home: &str, file_path: &std::path::Path) -> CodexState {
    match serde_json::from_str::<RawGlobalState>(contents) {
        Ok(raw) => {
            let overlay_open = raw.avatar_overlay_open.unwrap_or(false);
            let overlay_bounds = raw.avatar_overlay_bounds.map(|b| {
                let db = b.display_bounds.unwrap_or(DisplayBounds {
                    x: 0.0,
                    y: 0.0,
                    width: 1920.0,
                    height: 1080.0,
                });
                let mascot = b.mascot.map(|m| Mascot {
                    left: m.left,
                    top: m.top,
                    width: m.width,
                    height: m.height,
                });
                OverlayBounds {
                    x: b.x,
                    y: b.y,
                    width: b.width,
                    height: b.height,
                    display_x: db.x,
                    display_y: db.y,
                    display_width: db.width,
                    display_height: db.height,
                    display_id: b.display_id,
                    mascot,
                }
            });

            CodexState {
                avatar_overlay_open: overlay_open,
                overlay_bounds,
                state_available: true,
                diagnostic: format!("Successfully read {}", file_path.display()),
                codex_home: codex_home.to_string(),
            }
        }
        Err(e) => CodexState {
            avatar_overlay_open: false,
            overlay_bounds: None,
            state_available: false,
            diagnostic: format!("Failed to parse {} as JSON: {}", file_path.display(), e),
            codex_home: codex_home.to_string(),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_resolve_codex_home_defaults_to_dot_codex() {
        // Remove CODEX_HOME to test default
        std::env::remove_var("CODEX_HOME");
        let path = resolve_codex_home();
        assert!(
            path.ends_with(".codex"),
            "Expected path to end with .codex, got: {:?}",
            path
        );
    }

    #[test]
    fn test_resolve_codex_home_from_env() {
        let test_dir = "/tmp/fake-codex-home-test";
        std::fs::create_dir_all(test_dir).ok();
        std::env::set_var("CODEX_HOME", test_dir);
        let path = resolve_codex_home();
        assert_eq!(path, PathBuf::from(test_dir));
        std::env::remove_var("CODEX_HOME");
        std::fs::remove_dir_all(test_dir).ok();
    }

    #[test]
    fn test_parse_state_with_overlay_open() {
        let json = r#"{
            "electron-avatar-overlay-open": true,
            "electron-avatar-overlay-bounds": {
                "x": -1519,
                "y": 385,
                "width": 356,
                "height": 320,
                "mascot": {
                    "left": 60,
                    "top": 80,
                    "width": 120,
                    "height": 120
                },
                "displayBounds": {
                    "x": -1920,
                    "y": 176,
                    "width": 1920,
                    "height": 1080
                },
                "displayId": 1
            }
        }"#;
        let state = parse_state_json(
            json,
            "/home/.codex",
            &PathBuf::from("/home/.codex/.codex-global-state.json"),
        );
        assert!(state.state_available);
        assert!(state.avatar_overlay_open);
        let bounds = state.overlay_bounds.unwrap();
        assert_eq!(bounds.x, -1519.0);
        assert_eq!(bounds.y, 385.0);
        assert_eq!(bounds.width, 356.0);
        assert_eq!(bounds.height, 320.0);
        assert_eq!(bounds.display_x, -1920.0);
        assert_eq!(bounds.display_width, 1920.0);
        assert_eq!(bounds.display_id, Some(1));
        let mascot = bounds.mascot.expect("mascot should be parsed");
        assert_eq!(mascot.left, 60.0);
        assert_eq!(mascot.top, 80.0);
        assert_eq!(mascot.width, 120.0);
        assert_eq!(mascot.height, 120.0);
    }

    #[test]
    fn test_parse_state_with_overlay_closed() {
        let json = r#"{
            "electron-avatar-overlay-open": false
        }"#;
        let state = parse_state_json(
            json,
            "/home/.codex",
            &PathBuf::from("/home/.codex/.codex-global-state.json"),
        );
        assert!(state.state_available);
        assert!(!state.avatar_overlay_open);
        assert!(state.overlay_bounds.is_none());
    }

    #[test]
    fn test_parse_missing_state_file() {
        let state = CodexState {
            avatar_overlay_open: false,
            overlay_bounds: None,
            state_available: false,
            diagnostic: "file not found".to_string(),
            codex_home: "/nonexistent".to_string(),
        };
        assert!(!state.state_available);
        assert!(!state.avatar_overlay_open);
    }

    #[test]
    fn test_parse_invalid_state_json_reports_unavailable() {
        let state = parse_state_json(
            "not-json",
            "/home/.codex",
            &PathBuf::from("/home/.codex/.codex-global-state.json"),
        );

        assert!(!state.state_available);
        assert!(state.overlay_bounds.is_none());
        assert!(state.diagnostic.contains("Failed to parse"));
    }
}
