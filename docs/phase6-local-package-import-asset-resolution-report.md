# Phase 6 Local Package Import / Asset Resolution MVP Report

## Scope Implemented

- Fixed Phase 5 registry load persistence so unchanged built-in registry data is not rewritten on every startup.
- Updated Settings to show all local nest registry entries, including disabled entries with status.
- Kept the active nest selector limited to enabled nest entries only.
- Added core pure helpers for creating/upserting local package registry entries.
- Added Tauri command `import_local_package` for local directory import.
- Added Tauri command `load_local_nest_package` for reading imported nest layout JSON and reporting missing assets.
- Local import reads `codexpet-package.json`, validates the minimum manifest shape, verifies `codexpet.nest`, verifies the referenced layout/theme JSON exists, and writes a registry entry.
- Imported registry entries use the package directory as `assetRoot` and the manifest file path as `manifestPath`.
- Settings now includes a local directory text input and `Import` button.
- Settings displays imported packages with name/version/type/status and allows selecting enabled imported nests.
- Overlay resolves built-in entries through fixtures and imported entries through `assetRoot` + `manifestPath`.
- Overlay renders imported nest layouts through the existing renderer path and resolves local image assets as `file://` URLs.
- Missing imported assets are reported in overlay UI without crashing rendering.
- Follow-up hardening: imported asset URLs now use Tauri `convertFileSrc` instead of hand-built `file://` URLs.
- Follow-up hardening: imported package layout and asset paths reject absolute paths, empty paths, and path traversal components before joining with `assetRoot`.
- Follow-up hardening: Tauri validates minimum nest layout shape before import/load, including schema version, positive canvas dimensions, layers array, safe layer asset paths, and safe element `src`/`fallback`/`variants` asset paths.

## Files Changed

- `packages/core/src/package-registry/index.ts`
- `packages/core/src/package-registry/package-registry.test.ts`
- `apps/desktop-tauri/src-tauri/src/commands/config.rs`
- `apps/desktop-tauri/src-tauri/src/lib.rs`
- `apps/desktop-tauri/src/store/registryStore.ts`
- `apps/desktop-tauri/src/store/registryStore.test.ts`
- `apps/desktop-tauri/src/components/settings/SettingsApp.tsx`
- `apps/desktop-tauri/src/components/settings/SettingsApp.test.tsx`
- `apps/desktop-tauri/src/components/overlay/OverlayApp.tsx`
- `apps/desktop-tauri/src/components/overlay/OverlayApp.test.tsx`
- `apps/desktop-tauri/src/test-setup.ts`

## Tests Added / Updated

- Core local package entry creation and upsert behavior.
- Core imported entry replacement preserves `createdAt` and disabled state.
- `registryStore.load` does not save unchanged registry data.
- Disabled nest entries remain visible but are excluded from active nest choices.
- Local package import refreshes registry store state.
- Settings displays imported packages and disabled packages.
- Settings imports a local package directory via text input.
- Overlay handles imported nest missing assets with a visible fallback issue and no crash.
- Rust unit tests cover unsafe path rejection, minimum nest layout validation, and element `src`/`fallback`/`variants` asset path hardening.

## Not Implemented

- Marketplace.
- Sync.
- Remote downloads.
- Complex package installer or unpacking flow.
- Windows real-device-specific adaptations.
- Full package sandboxing, copying, or relocation. Imported packages currently reference the selected local directory directly.
- System file picker. Phase 6 uses text input for directory paths.

## Verification

Targeted verification during implementation:

- `pnpm typecheck` - passed
- `pnpm --filter @codexpet/core test` - passed
- `pnpm --filter @codexpet/desktop-tauri test` - passed
- `cd apps/desktop-tauri/src-tauri && cargo fmt --all --check` - passed after formatting Rust source
- `cd apps/desktop-tauri/src-tauri && cargo clippy --all-targets -- -D warnings` - passed

Full verification completed:

- `pnpm typecheck` - passed
- `pnpm lint` - passed
- `pnpm format:check` - passed after formatting modified test files
- `pnpm test` - passed
- `cd apps/desktop-tauri/src-tauri && cargo fmt --all --check` - passed
- `cd apps/desktop-tauri/src-tauri && cargo clippy --all-targets -- -D warnings` - passed
- `cd apps/desktop-tauri/src-tauri && cargo test` - passed
- `pnpm tauri:build:app` - passed

Build artifact produced at `apps/desktop-tauri/src-tauri/target/release/bundle/macos/CodexPet Nest.app`.
