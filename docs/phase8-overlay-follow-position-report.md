# Phase 8 Overlay Follow Loop / Position Persistence MVP Report

## Scope Implemented

- Added a continuous overlay follow loop for `follow-codex` runtime mode.
- The overlay periodically reads Codex pet state, uses mascot bounds when available, reuses the existing `convert_position` coordinate conversion command, and moves the Tauri overlay through a clamped backend command.
- Added throttling and minimum-movement guards so repeated Codex state reads do not trigger unnecessary window moves.
- When Codex state or mascot bounds are unavailable, the overlay keeps its current position and reports a waiting/holding runtime status instead of jumping to fallback coordinates.
- Added standalone/manual position restoration from local settings for non-follow modes.
- Added manual drag persistence: after a manual fallback drag in standalone/manual modes, the current overlay position is saved to `settings.standalonePosition`.
- Preserved mode boundaries: `follow-codex` is driven by Codex bounds and does not overwrite the saved manual position; standalone/manual modes are driven by the saved local position.
- Added backend screen clamp logic for overlay moves, including Retina and multi-monitor test coverage.
- Added debug diagnostics surfaced only inside the existing Settings Debug Panel.

## Files Changed

- `packages/core/src/overlay-runtime/index.ts`
- `packages/core/src/overlay-runtime/overlay-runtime.test.ts`
- `packages/core/src/index.ts`
- `packages/core/src/settings/settings.test.ts`
- `apps/desktop-tauri/src/components/overlay/OverlayApp.tsx`
- `apps/desktop-tauri/src/components/overlay/OverlayApp.test.tsx`
- `apps/desktop-tauri/src/components/debug/DebugPanel.tsx`
- `apps/desktop-tauri/src/components/debug/DebugPanel.test.tsx`
- `apps/desktop-tauri/src/test-setup.ts`
- `apps/desktop-tauri/src-tauri/src/coords.rs`
- `apps/desktop-tauri/src-tauri/src/codex_state.rs`
- `apps/desktop-tauri/src-tauri/src/commands/debug.rs`
- `apps/desktop-tauri/src-tauri/src/lib.rs`
- `apps/desktop-tauri/src-tauri/src/windows/mod.rs`
- `apps/desktop-tauri/src-tauri/src/windows/setup.rs`

## Runtime Behavior

### `follow-codex`

- Runs a 500ms follow loop from the overlay window.
- Reads `get_codex_state` each tick.
- Uses `overlay_bounds + mascot` to derive the Codex pet rectangle.
- Calls `get_screen_list` and `convert_position` to reuse the existing DPI/multi-monitor coordinate conversion path.
- Converts the returned logical display-relative position back to a physical global Tauri window position.
- Calls `move_overlay_to_clamped`, which clamps the final physical position to the nearest available monitor before moving the overlay.
- Skips redundant moves when the target changed by less than 2 physical pixels and the last move was under 250ms ago.
- If Codex state, bounds, screens, or move commands fail, the loop records diagnostics and holds the current overlay position.

### Standalone / Manual

- On startup or mode switch to `standalone-fixed`, the overlay reads `settings.standalonePosition` and restores that position through `move_overlay_to_clamped`.
- Manual fallback dragging still moves the overlay through Tauri, but now uses the clamped move command.
- On drag end, standalone/manual mode saves the current overlay position back to `settings.standalonePosition`.
- Manual position is not overwritten while `follow-codex` is active, so switching modes does not lose the user’s saved standalone position.

## Debug Diagnostics

The Settings Debug Panel now displays overlay follow diagnostics from local debug state:

- Current runtime mode.
- Last Codex state read timestamp.
- Last overlay target position.
- Whether the follow loop is active.
- Last move failure reason.

These diagnostics remain inside the collapsed Debug Panel and are intended for development/manual verification only.

## Tests Added / Updated

- Core tests for follow/manual mode boundary decisions.
- Core tests for manual position persistence rules and invalid coordinate normalization.
- Core settings test confirming saved standalone position survives overlay mode changes.
- React overlay test for follow-mode movement from Codex mascot bounds.
- React overlay test for standalone manual drag position persistence.
- React debug panel test for follow diagnostics rendering.
- Rust coordinate tests for Retina clamp, multi-monitor clamp, and offscreen fallback clamp.
- Rust Codex state test for malformed state JSON error handling.
- Rust debug command tests for coordinate conversion command behavior and command response serialization.

## Security / Boundary Notes

- No shell action execution was added.
- No cloud sync or marketplace behavior was added.
- Existing local package path hardening and safe action boundaries remain unchanged.
- No new state management library was introduced.

## Manual Verification

### Follow Mode

1. Run `pnpm tauri:dev`.
2. In Settings, set Overlay mode to `follow-codex`.
3. Ensure Codex pet / mascot overlay is visible.
4. Move Codex pet and observe the Nest overlay following with a small delay.
5. Open Debug Panel and verify runtime mode, last Codex read timestamp, last target position, follow loop active state, and move failure field update.
6. Temporarily close/hide Codex pet state source and confirm the Nest overlay holds its current position instead of jumping.

### Standalone / Manual Mode

1. In Settings, set Overlay mode to `standalone-fixed`.
2. Disable click-through if necessary.
3. Drag the `Drag Overlay` pill in the overlay.
4. Quit and relaunch the app.
5. Confirm the overlay restores the saved standalone position.
6. Switch to `follow-codex`, then back to `standalone-fixed`, and confirm the saved manual position is retained.

## Not Confirmed

- Windows real-device Codex state schema and mixed-DPI positioning remain unverified.
- Visual precision of the follow offset may still need macOS/Windows real-device tuning with real Codex Desktop builds.
- The follow loop currently lives in the overlay renderer process; this is sufficient for the MVP but could move deeper into backend runtime code if later phases require more centralized scheduling.
