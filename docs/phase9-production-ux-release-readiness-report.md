# Phase 9 Production UX Cleanup / Release Readiness MVP Report

## Scope Implemented

- Separated development overlay visuals from production overlay visuals.
- Kept debug tools available inside Settings as a clearly labeled Development Diagnostics area.
- Cleaned the production overlay so it renders the actual nest UI without debug borders, labels, runtime mode text, drag diagnostics, or internal state strings.
- Added a low-profile production drag affordance that does not cover the nest body.
- Changed click-through overlay UX so quick actions are not presented as clickable controls when the overlay cannot receive mouse events.
- Added gentle fallback behavior for unavailable Codex state: the overlay holds its current/saved position while Settings surfaces diagnostics.
- Reworked Settings into a desktop-app settings layout focused on overlay controls, follow status, widgets/actions, local packages/nests, app info, and development diagnostics.
- Enlarged the default Settings window and release overlay window so the real nest UI is usable outside debug mode.

## Required Reading Notes

The requested Phase 3, Phase 5, and Phase 6 report filenames differed from the files present in this repository. The actual files read were:

- `docs/phase3-overlay-rendering-mvp-report.md`
- `docs/phase5-package-registry-local-assets-report.md`
- `docs/phase6-local-package-import-asset-resolution-report.md`

All Phase 1-8 reports present in the repository were reviewed before implementation.

## Files Changed

- `apps/desktop-tauri/src/components/overlay/OverlayApp.tsx`
- `apps/desktop-tauri/src/components/overlay/OverlayApp.test.tsx`
- `apps/desktop-tauri/src/components/settings/SettingsApp.tsx`
- `apps/desktop-tauri/src/components/settings/SettingsApp.test.tsx`
- `apps/desktop-tauri/src/components/debug/DebugPanel.tsx`
- `apps/desktop-tauri/src-tauri/src/windows/setup.rs`
- `docs/phase9-production-ux-release-readiness-report.md`

## Debug / Production Boundary

- `OverlayApp` now treats debug overlay visuals as backend-controlled: `config.isDebug === true`.
- Release builds no longer fall back to `import.meta.env.DEV` or the overlay URL label to show debug UI.
- The red border, yellow outline, `DEBUG OVERLAY` label, platform debug label, internal fixture selector, runtime mode text, and drag diagnostics are only rendered in debug mode.
- Production mode keeps the localStorage diagnostics writes so Settings can inspect runtime/follow state without exposing those details inside the overlay.
- Debug Panel remains available, but it is labeled as Development Diagnostics and grouped under the Settings page rather than presented as a normal user workflow.

## Overlay Production Visual

- Production overlay uses the renderer-backed `NestOverlayView` as the primary UI instead of a debug/test frame.
- Production overlay no longer displays `Runtime: ...`, `mode: ...`, `Action: ...`, registry fallback internals, missing asset lists, or drag diagnostics.
- User-facing feedback is limited to short status text, such as action results or a generic fallback message.
- The drag region is a small, low-opacity pill labeled `Drag` in interactive mode.
- In click-through mode, quick action buttons are hidden and replaced with `Click-through is on`, making it clear that overlay interactions are paused.
- Quick action confirmation and results remain available when click-through is off.

## First Launch / Empty State Behavior

- When Codex state cannot be read, the follow loop records diagnostics and holds the current overlay position instead of displaying technical errors in the overlay.
- When Codex mascot bounds are missing, the overlay waits/holds rather than jumping or showing raw diagnostic text.
- Settings includes a Follow Status card showing mode, follow-loop state, and last Codex read timestamp when available.
- If follow movement has a recorded failure, Settings explains that the overlay will keep its current or saved position and directs technical inspection to Development Diagnostics.

## Settings UX Cleanup

- Settings window default size increased to `860x760` with `680x560` minimum size.
- The main Settings page now prioritizes:
  - overlay show/hide
  - overlay mode selection: Follow Codex and Standalone fixed/manual
  - click-through toggle
  - follow status
  - widgets/actions controls
  - local package import and active nest selection
  - basic app info
  - collapsed Development Diagnostics
- `API URL` was removed from the ordinary App Info section and remains available through raw diagnostics if needed.
- Existing package registry/import, widgets/actions, active nest selection, click-through transaction behavior, and debug controls were preserved.

## Release Readiness Check

- App product name: `CodexPet Nest` in `tauri.conf.json`.
- Version: `0.1.12` in `tauri.conf.json`, `apps/desktop-tauri/package.json`, and `Cargo.toml`.
- Identifier: `xyz.codexpet.nest` in `tauri.conf.json` and backend `AppConfig`.
- Bundle icons are configured: `32x32.png`, `128x128.png`, `128x128@2x.png`, `icon.icns`, `icon.ico`.
- Tray/menu-bar icon is embedded from `src-tauri/icons/32x32.png` and applied via `TrayIconBuilder.icon(...)`.
- Release build uses `frontendDist: ../dist` and `beforeBuildCommand: pnpm build`; it does not depend on the Vite dev server.
- `devUrl: http://localhost:1420` is only for dev mode.
- `pnpm tauri:build:app` is the expected release-app build command and produces a macOS `.app` bundle.

## Tests Added / Updated

- React overlay test for debug overlay visibility in debug mode.
- React overlay test for debug overlay absence in production mode.
- React overlay test for click-through mode replacing interactive quick actions with a non-interactive status.
- React overlay test for unavailable Codex state not surfacing technical errors in production UI.
- Settings test for overlay mode, show/hide, and click-through controls remaining usable.
- Settings test confirming Development Diagnostics does not block ordinary settings rendering.
- Existing overlay tests were updated to match production/user-facing text and debug-only runtime diagnostics.

## Rust / Tauri Notes

- Rust changes were limited to default window sizing in `windows/setup.rs`.
- No Rust command behavior, coordinate math, follow loop backend helper, platform click-through code, or Tauri config was changed.
- Existing Rust tests remain the regression coverage for coordinate conversion, Codex state parsing, clamped movement helpers, and debug command serialization.

## Verification

- `pnpm typecheck` - passed.
- `pnpm lint` - passed.
- `pnpm format:check` - passed.
- `pnpm test` - passed. Workspace totals include `@codexpet/core` 34 tests, `@codexpet/renderer` 9 tests, and `@codexpet/desktop-tauri` 38 tests.
- `cd apps/desktop-tauri/src-tauri && cargo fmt --all --check` - passed.
- `cd apps/desktop-tauri/src-tauri && cargo clippy --all-targets -- -D warnings` - passed.
- `cd apps/desktop-tauri/src-tauri && cargo test` - passed. Rust totals include 28 lib tests and 3 config integration tests.
- `pnpm tauri:build:app` - passed.

Build artifact produced at:

- `apps/desktop-tauri/src-tauri/target/release/bundle/macos/CodexPet Nest.app`

## macOS Manual Verification Recommendations

- Build with `pnpm tauri:build:app` and launch `apps/desktop-tauri/src-tauri/target/release/bundle/macos/CodexPet Nest.app`.
- Confirm release overlay has no red border, yellow outline, `DEBUG OVERLAY`, runtime mode text, or drag diagnostics.
- Confirm the nest renders inside the production overlay at the larger release size.
- Toggle Settings > Click-through and confirm overlay quick actions disappear or reappear with the expected status.
- Toggle Settings > Overlay mode between Follow Codex and Standalone fixed/manual.
- With Codex unavailable or hidden, confirm overlay stays in place and Settings Follow Status / Development Diagnostics contain the details.
- Confirm tray/menu-bar icon is visible and Show Overlay, Hide Overlay, Open Settings, and Quit work.
- Confirm closing Settings hides the window and tray Open Settings reopens it.

## Windows Remaining Items

- Windows Codex Desktop state path and schema remain unverified.
- Windows transparent overlay behavior remains unverified.
- Windows click-through behavior remains unimplemented beyond documented stubs and unverified.
- Windows mixed-DPI and multi-monitor positioning require real-device validation.
- Windows tray icon/menu behavior requires real-device validation.
- Windows installer/bundle output was not validated in this phase.

## Not Implemented

- No cloud sync.
- No Windows real-device adaptation.
- No marketplace.
- No real shell action execution.
- No overlay renderer rewrite.
- No removal of Phase 8 follow loop or position persistence.
