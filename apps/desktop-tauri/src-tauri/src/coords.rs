use serde::{Deserialize, Serialize};

/// Represents a physical screen/monitor.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScreenInfo {
    pub x: i32,
    pub y: i32,
    pub width: i32,
    pub height: i32,
    pub scale_factor: f64,
    pub is_primary: bool,
}

/// Result of converting Codex overlay bounds to a Tauri window position.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConvertedPosition {
    /// Logical x coordinate for the Tauri window (top-left)
    pub x: f64,
    /// Logical y coordinate for the Tauri window (top-left)
    pub y: f64,
    /// Scale factor of the target display
    pub scale_factor: f64,
    /// Target display index
    pub display_index: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ClampedPosition {
    pub x: i32,
    pub y: i32,
    pub display_index: usize,
}

/// Convert Codex overlay bounds (top-left coordinates in Codex space)
/// to Tauri window logical coordinates for the nest overlay.
///
/// # Arguments
/// * `codex_x` - Codex overlay top-left X
/// * `codex_y` - Codex overlay top-left Y
/// * `codex_width` - Codex overlay width
/// * `codex_height` - Codex overlay height
/// * `screens` - List of available screen/monitor info
/// * `target_scale` - Target DPI scale factor (e.g., 1.0, 1.25, 1.5)
///
/// # Strategy
/// 1. Find which screen contains the Codex overlay position
/// 2. Adjust for the screen's origin offset
/// 3. Adjust for DPI scale factor
/// 4. Position the nest to the right of the Codex overlay
///
/// If the Codex overlay position doesn't fall within any screen,
/// the primary screen (index 0) is used as fallback.
pub fn convert_codex_to_nest_position(
    codex_x: f64,
    codex_y: f64,
    codex_width: f64,
    _codex_height: f64,
    screens: &[ScreenInfo],
    _target_scale: f64,
) -> ConvertedPosition {
    // Find which screen contains this position
    let (display_index, screen) = find_screen_for_position(codex_x, codex_y, screens);

    // Adjust for screen origin offset
    let screen_relative_x = codex_x - screen.x as f64;
    let screen_relative_y = codex_y - screen.y as f64;

    // Adjust for DPI scale: convert physical pixels to logical pixels
    let logical_x = screen_relative_x / screen.scale_factor;
    let logical_y = screen_relative_y / screen.scale_factor;

    // Convert Codex overlay width to logical
    let logical_codex_width = codex_width / screen.scale_factor;

    // Position nest to the right of the Codex overlay
    // Add a small gap between the two windows
    let nest_x = logical_x + logical_codex_width + 8.0;
    let nest_y = logical_y;

    ConvertedPosition {
        x: nest_x,
        y: nest_y,
        scale_factor: screen.scale_factor,
        display_index,
    }
}

pub fn clamp_position_to_screens(
    x: i32,
    y: i32,
    window_width: i32,
    window_height: i32,
    screens: &[ScreenInfo],
) -> ClampedPosition {
    let (display_index, screen) = find_screen_for_physical_position(x, y, screens);
    let max_x = screen.x + screen.width - window_width.max(1);
    let max_y = screen.y + screen.height - window_height.max(1);
    ClampedPosition {
        x: x.clamp(screen.x, max_x.max(screen.x)),
        y: y.clamp(screen.y, max_y.max(screen.y)),
        display_index,
    }
}

/// Find which screen contains the given (x, y) position.
///
/// Returns (index, screen). If no screen contains the position,
/// returns (0, first screen) as fallback.
fn find_screen_for_position(x: f64, y: f64, screens: &[ScreenInfo]) -> (usize, &ScreenInfo) {
    for (i, screen) in screens.iter().enumerate() {
        let left = screen.x as f64;
        let top = screen.y as f64;
        let right = left + screen.width as f64;
        let bottom = top + screen.height as f64;

        if x >= left && x < right && y >= top && y < bottom {
            return (i, screen);
        }
    }

    // Fallback: use primary screen or first screen
    if let Some(pos) = screens.iter().position(|s| s.is_primary) {
        (pos, &screens[pos])
    } else if !screens.is_empty() {
        (0, &screens[0])
    } else {
        // No screens available — return a default
        // This shouldn't happen in practice but provides a safe fallback
        panic!("No screens available for coordinate conversion");
    }
}

fn distance_to_physical_screen(x: i32, y: i32, screen: &ScreenInfo) -> i64 {
    let closest_x = x.clamp(screen.x, screen.x + screen.width);
    let closest_y = y.clamp(screen.y, screen.y + screen.height);
    let dx = i64::from(x - closest_x);
    let dy = i64::from(y - closest_y);
    dx * dx + dy * dy
}

fn find_screen_for_physical_position(
    x: i32,
    y: i32,
    screens: &[ScreenInfo],
) -> (usize, &ScreenInfo) {
    for (i, screen) in screens.iter().enumerate() {
        let right = screen.x + screen.width;
        let bottom = screen.y + screen.height;
        if x >= screen.x && x < right && y >= screen.y && y < bottom {
            return (i, screen);
        }
    }
    if let Some(pos) = screens.iter().position(|s| s.is_primary) {
        let mut nearest = pos;
        let mut nearest_distance = distance_to_physical_screen(x, y, &screens[pos]);
        for (i, screen) in screens.iter().enumerate() {
            let distance = distance_to_physical_screen(x, y, screen);
            if distance < nearest_distance {
                nearest = i;
                nearest_distance = distance;
            }
        }
        (nearest, &screens[nearest])
    } else if !screens.is_empty() {
        (0, &screens[0])
    } else {
        panic!("No screens available for coordinate conversion");
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_screens() -> Vec<ScreenInfo> {
        vec![
            // Primary 1920x1080 at origin, 100% (1.0) DPI
            ScreenInfo {
                x: 0,
                y: 0,
                width: 1920,
                height: 1080,
                scale_factor: 1.0,
                is_primary: true,
            },
            // Secondary 1920x1080 to the left, 125% DPI
            ScreenInfo {
                x: -1920,
                y: 176,
                width: 1920,
                height: 1080,
                scale_factor: 1.25,
                is_primary: false,
            },
        ]
    }

    #[test]
    fn test_find_screen_for_position_primary() {
        let screens = make_screens();
        let (idx, screen) = find_screen_for_position(500.0, 300.0, &screens);
        assert_eq!(idx, 0);
        assert!(screen.is_primary);
    }

    #[test]
    fn test_find_screen_for_position_secondary() {
        let screens = make_screens();
        let (idx, _) = find_screen_for_position(-1500.0, 400.0, &screens);
        assert_eq!(idx, 1);
    }

    #[test]
    fn test_find_screen_for_position_retina_right_half() {
        let screens = vec![ScreenInfo {
            x: 0,
            y: 0,
            width: 3024,
            height: 1964,
            scale_factor: 2.0,
            is_primary: true,
        }];

        let (idx, screen) = find_screen_for_position(2400.0, 800.0, &screens);

        assert_eq!(idx, 0);
        assert!(screen.is_primary);
    }

    #[test]
    fn test_find_screen_for_position_secondary_high_dpi_right_half() {
        let screens = vec![
            ScreenInfo {
                x: 0,
                y: 0,
                width: 1920,
                height: 1080,
                scale_factor: 1.0,
                is_primary: true,
            },
            ScreenInfo {
                x: 1920,
                y: 0,
                width: 2560,
                height: 1440,
                scale_factor: 1.5,
                is_primary: false,
            },
        ];

        let (idx, screen) = find_screen_for_position(4100.0, 700.0, &screens);

        assert_eq!(idx, 1);
        assert!(!screen.is_primary);
    }

    #[test]
    fn test_convert_to_nest_position_primary_100dpi() {
        let screens = make_screens();
        // Codex overlay at (200, 300) on primary screen, width 356
        let result = convert_codex_to_nest_position(200.0, 300.0, 356.0, 320.0, &screens, 1.0);
        assert_eq!(result.display_index, 0);
        assert_eq!(result.scale_factor, 1.0);
        // nest_x = logic_x + logic_codex_width + 8 = 200 + 356 + 8 = 564
        assert_eq!(result.x, 564.0);
        assert_eq!(result.y, 300.0);
    }

    #[test]
    fn test_convert_to_nest_position_secondary_125dpi() {
        let screens = make_screens();
        // Codex overlay at (-1519, 385) on secondary screen (x=-1920, 125% DPI)
        let result = convert_codex_to_nest_position(-1519.0, 385.0, 356.0, 320.0, &screens, 1.25);
        assert_eq!(result.display_index, 1);
        assert_eq!(result.scale_factor, 1.25);
        // screen_relative_x = -1519 - (-1920) = 401 physical
        // logic_x = 401 / 1.25 = 320.8
        // logic_codex_width = 356 / 1.25 = 284.8
        // nest_x = 320.8 + 284.8 + 8 = 613.6
        assert!(
            (result.x - 613.6).abs() < 0.01,
            "Expected ~613.6, got {}",
            result.x
        );
        // screen_relative_y = 385 - 176 = 209 physical
        // logic_y = 209 / 1.25 = 167.2
        assert!(
            (result.y - 167.2).abs() < 0.01,
            "Expected ~167.2, got {}",
            result.y
        );
    }

    #[test]
    fn test_convert_to_nest_position_150dpi() {
        let screens = vec![ScreenInfo {
            x: 0,
            y: 0,
            width: 2880, // 4K @ 150% = 3840 logical, wait let me fix
            height: 1800,
            scale_factor: 1.5,
            is_primary: true,
        }];
        // Codex overlay at (600, 400) on 150% DPI, width 356 physical
        let result = convert_codex_to_nest_position(600.0, 400.0, 356.0, 320.0, &screens, 1.5);
        assert_eq!(result.scale_factor, 1.5);
        // logic_x = 600 / 1.5 = 400
        // logic_codex_width = 356 / 1.5 ≈ 237.33
        // nest_x = 400 + 237.33 + 8 = 645.33
        assert!(
            (result.x - 645.33).abs() < 0.5,
            "Expected ~645.3, got {}",
            result.x
        );
        // logic_y = 400 / 1.5 ≈ 266.67
        assert!(
            (result.y - 266.67).abs() < 0.5,
            "Expected ~266.7, got {}",
            result.y
        );
    }

    #[test]
    fn test_position_outside_screens_falls_back_to_primary() {
        let screens = make_screens();
        // Position far outside all screens
        let result = convert_codex_to_nest_position(10000.0, 10000.0, 356.0, 320.0, &screens, 1.0);
        assert_eq!(result.display_index, 0);
        assert!(result.scale_factor == 1.0);
    }

    #[test]
    fn test_clamp_position_on_retina_primary_screen() {
        let screens = vec![ScreenInfo {
            x: 0,
            y: 0,
            width: 3024,
            height: 1964,
            scale_factor: 2.0,
            is_primary: true,
        }];

        let result = clamp_position_to_screens(3000, 1900, 480, 260, &screens);

        assert_eq!(result.display_index, 0);
        assert_eq!(result.x, 2544);
        assert_eq!(result.y, 1704);
    }

    #[test]
    fn test_clamp_position_preserves_secondary_monitor_bounds() {
        let screens = make_screens();

        let result = clamp_position_to_screens(-2100, 1200, 480, 260, &screens);

        assert_eq!(result.display_index, 1);
        assert_eq!(result.x, -1920);
        assert_eq!(result.y, 996);
    }

    #[test]
    fn test_clamp_position_outside_monitors_uses_primary() {
        let screens = make_screens();

        let result = clamp_position_to_screens(9000, 9000, 480, 260, &screens);

        assert_eq!(result.display_index, 0);
        assert_eq!(result.x, 1440);
        assert_eq!(result.y, 820);
    }
}
