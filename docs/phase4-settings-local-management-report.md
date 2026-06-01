# Phase 4 Settings / Local Management MVP Report

## Scope Implemented

- Added a user-facing Settings window layout focused on local overlay and built-in nest management.
- Kept the existing Debug Panel available behind a collapsed `Debug Panel` section so it no longer dominates the default settings experience.
- Added local overlay controls for show/hide and click-through.
- Added local runtime controls for overlay mode selection: `follow-codex` and `standalone-fixed`.
- Added built-in nest selection using the renderer fixture registry.
- Added local settings persistence through Tauri commands backed by `<app data directory>/settings.json`.
- Reused `@codexpet/core` settings schema, defaults, normalization, and migration in the frontend store instead of redefining settings rules in UI components.
- Updated overlay startup behavior to read saved `activeNestId`, `overlayMode`, and `clickThrough` from local settings.
- Preserved the Phase 3 renderer path: overlay still renders built-in nest fixtures through `buildNestRenderModel` and `NestOverlayView`.

## Files Changed

- `apps/desktop-tauri/src-tauri/src/commands/config.rs`
- `apps/desktop-tauri/src-tauri/src/lib.rs`
- `apps/desktop-tauri/src/store/settingsStore.ts`
- `apps/desktop-tauri/src/components/shared/ConfigProvider.tsx`
- `apps/desktop-tauri/src/components/settings/SettingsApp.tsx`
- `apps/desktop-tauri/src/components/settings/SettingsApp.test.tsx`
- `apps/desktop-tauri/src/components/overlay/OverlayApp.tsx`
- `apps/desktop-tauri/src/components/overlay/OverlayApp.test.tsx`
- `apps/desktop-tauri/src/test-setup.ts`

## Tests Added / Updated

- Settings UI renders saved settings values from the local settings store.
- Changing overlay mode saves normalized settings through `save_local_settings`.
- Changing the selected built-in nest saves normalized settings through `save_local_settings`.
- Overlay renders the saved built-in nest and displays the saved overlay mode.

## Not Implemented

- Marketplace, sync, real package installation, and remote package management.
- Windows-specific behavior beyond existing cross-platform Tauri commands.
- Additional overlay modes beyond exposing the Phase 4 required `follow-codex` and `standalone-fixed` choices in the UI.
- Continuous follow-codex positioning loop; Phase 3 one-shot position computation remains unchanged.

## Verification

Targeted verification run during implementation:

- `pnpm --filter @codexpet/desktop-tauri test` - passed

Full verification completed:

- `pnpm typecheck` - passed
- `pnpm lint` - passed
- `pnpm format:check` - passed after formatting modified TSX files
- `pnpm test` - passed
- `cd apps/desktop-tauri/src-tauri && cargo fmt --all --check` - passed after running `cargo fmt --all`
- `cd apps/desktop-tauri/src-tauri && cargo clippy --all-targets -- -D warnings` - passed
- `cd apps/desktop-tauri/src-tauri && cargo test` - passed
- `pnpm tauri:build:app` - passed

Build artifact produced at `apps/desktop-tauri/src-tauri/target/release/bundle/macos/CodexPet Nest.app`.
