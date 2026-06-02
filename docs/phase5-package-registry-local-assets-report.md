# Phase 5 Package Registry / Local Asset Management MVP Report

## Scope Implemented

- Added a local package registry domain module in `@codexpet/core`.
- Registry entries support package id, type (`pet` / `nest`), version, name, manifest path, asset root, enabled state, `createdAt`, and `updatedAt`.
- Added registry loading, validation, normalization, and migration from missing schema version / legacy `codexpet.pet` and `codexpet.nest` type names.
- Added Tauri commands for local registry persistence:
  - `load_local_registry`
  - `save_local_registry`
- Added frontend `registryStore` that loads local registry JSON, merges built-in nest entries, and persists normalized registry state.
- Registered Phase 5 built-in nests as local registry entries:
  - `default`
  - `capacity-orbit-nest`
  - `basket-pomodoro-nest`
- Updated Settings to show a `Local Packages / Nests` section from the registry with name, version, type, and status.
- Updated active nest selection to save `settings.activeNestId` from registry entries instead of directly from renderer fixtures.
- Updated Overlay to resolve `settings.activeNestId` through the registry before rendering.
- Added fallback behavior when `activeNestId` is missing from the registry: Overlay renders the default nest and displays runtime fallback state.
- Preserved Phase 4 settings save consistency and click-through transaction behavior.

## Files Changed

- `packages/core/src/package-registry/index.ts`
- `packages/core/src/package-registry/package-registry.test.ts`
- `packages/core/src/index.ts`
- `apps/desktop-tauri/src-tauri/src/commands/config.rs`
- `apps/desktop-tauri/src-tauri/src/lib.rs`
- `apps/desktop-tauri/src/store/registryStore.ts`
- `apps/desktop-tauri/src/store/registryStore.test.ts`
- `apps/desktop-tauri/src/components/shared/ConfigProvider.tsx`
- `apps/desktop-tauri/src/components/settings/SettingsApp.tsx`
- `apps/desktop-tauri/src/components/settings/SettingsApp.test.tsx`
- `apps/desktop-tauri/src/components/overlay/OverlayApp.tsx`
- `apps/desktop-tauri/src/components/overlay/OverlayApp.test.tsx`
- `apps/desktop-tauri/src/test-setup.ts`

## Tests Added / Updated

- Core registry default creation, valid loading, migration, and corrupted fallback.
- Registry store built-in nest merge and fallback resolution.
- Settings registry nest list display.
- Settings `activeNestId` save through registry selection.
- Overlay registry-driven active nest rendering.
- Overlay fallback to default nest when saved `activeNestId` is unavailable.

## Not Implemented

- Marketplace or remote package discovery.
- Sync.
- Remote downloads.
- Complex package installer or unpacking flow.
- Windows real-device-specific adaptations.
- Rendering arbitrary external package assets. Phase 5 registry entries are wired to built-in fixture-backed assets for the local MVP.

## Verification

Targeted verification during implementation:

- `pnpm typecheck` - passed
- `pnpm --filter @codexpet/core test` - passed
- `pnpm --filter @codexpet/desktop-tauri test` - passed

Full verification completed:

- `pnpm typecheck` - passed
- `pnpm lint` - passed
- `pnpm format:check` - passed after formatting modified frontend files
- `pnpm test` - passed
- `cd apps/desktop-tauri/src-tauri && cargo fmt --all --check` - passed
- `cd apps/desktop-tauri/src-tauri && cargo clippy --all-targets -- -D warnings` - passed after removing a needless borrow
- `cd apps/desktop-tauri/src-tauri && cargo test` - passed
- `pnpm tauri:build:app` - passed

Build artifact produced at `apps/desktop-tauri/src-tauri/target/release/bundle/macos/CodexPet Nest.app`.
