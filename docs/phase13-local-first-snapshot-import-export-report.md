# Phase 13 Local-First Snapshot Import/Export Report

Date: 2026-06-04

## Scope

Phase 13 adds local-first settings and registry snapshot import/export. This phase intentionally avoids Windows GUI work and does not claim Windows parity.

Included:

- Export current local settings and local package registry metadata to a JSON snapshot file.
- Import a JSON snapshot file back into local settings and registry storage.
- Surface the feature in Settings under Local Snapshot.
- Add source-level checks and tests for the snapshot path.

Not included:

- Cloud sync.
- Multi-device conflict resolution.
- Account/device identity.
- Copying local package asset folders into the snapshot.
- Windows GUI verification.
- Windows `follow-codex` support.
- Win32 click-through implementation.
- Windows parity claims.

## Environment

| Field | Value |
| --- | --- |
| Host OS | macOS / Darwin 25.3.0 arm64 |
| Windows real machine available | No |
| GitHub Actions Windows run result | CI run not executed |
| Node | v22.16.0 |
| pnpm | 10.15.1 |
| Rust | rustc 1.96.0 (ac68faa20 2026-05-25) |
| Repo path | `/Users/ryanniu/Documents/Project/codexpet-nest-next` |

## What Changed

- Added Rust Tauri commands:
  - `export_local_snapshot`
  - `import_local_snapshot`
- Registered both commands in the Tauri invoke handler.
- Added a Settings `Local Snapshot` section with explicit export/import paths.
- Added frontend tests for exporting a local snapshot and importing then reloading local stores.
- Added Rust tests for local snapshot envelope validation.
- Hardened snapshot import after review so settings/registry replacement is staged with backup rollback instead of sequential overwrite.
- Hardened snapshot payload validation so obviously invalid settings/registry payloads are rejected before disk writes.
- Updated release smoke checks so the snapshot UI and Tauri command registrations are source-checked.

## Snapshot Format

The exported snapshot is a local JSON envelope with `schemaVersion: 1`.

Top-level fields:

- `schemaVersion`
- `exportedAt`
- `app`
- `data.settings`
- `data.registry`
- `notes`

The snapshot contains current normalized settings and local registry metadata. It does not copy local package asset folders. Imported local package paths must still exist on the destination device for those packages to render correctly.

## Local-First Behavior

- Export writes a JSON file to the path typed by the user.
- Import reads a JSON file from the path typed by the user.
- Import replaces local `settings.json` and `registry.json` contents through the existing app data directory using staged writes and backup rollback.
- Import first parses and validates the full snapshot, then serializes both settings and registry before touching existing files.
- Import writes same-directory temporary files before replacing either target file.
- Import backs up both existing target files before replacement and rolls back if the replacement sequence fails, avoiding a settings-imported / registry-not-imported mixed state.
- After import, the frontend reloads settings and registry through the existing store loaders.
- Existing `@codexpet/core` normalization/migration remains the authority for frontend state shape after reload.

## Safety Boundaries

- Snapshot import validates that the envelope is an object with supported `schemaVersion`.
- Snapshot import requires `data.settings` and `data.registry`.
- Snapshot import requires settings to include a compatible `schemaVersion`.
- Snapshot import requires registry metadata to include compatible `schemaVersion` and a `packages` array.
- Snapshot import validates each package entry is an object with the minimum fields needed by later registry consumption: `id`, `type`, `version`, `name`, `manifestPath`, and `assetRoot`.
- Snapshot import rejects invalid settings/registry payloads before writing to disk; it does not rely on frontend fallback after writing invalid data.
- Snapshot import uses staged writes and backup rollback so replacement failures do not leave a half-imported local state.
- Snapshot export/import does not enable shell actions.
- Snapshot export/import does not change click-through behavior.
- Snapshot export/import does not assume Windows Codex state schema.
- Snapshot export/import does not claim local package assets are portable across machines.

## Tests Added/Updated

- `apps/desktop-tauri/src/components/settings/SettingsApp.test.tsx`
  - Exports local settings and registry snapshot.
  - Imports local snapshot and reloads local stores.
- `apps/desktop-tauri/src/test-setup.ts`
  - Adds mocked `export_local_snapshot` and `import_local_snapshot` commands.
- `apps/desktop-tauri/src-tauri/src/commands/config.rs`
  - Adds Rust tests for valid and invalid local snapshot shapes.
  - Adds Rust tests rejecting invalid settings schema versions.
  - Adds Rust tests rejecting invalid registry schema versions and package entries.
  - Adds Rust test proving a simulated replacement failure rolls back instead of leaving half-imported files.
- `scripts/check-release-readiness.mjs`
  - Checks Local Snapshot UI presence.
  - Checks Tauri command registration.
  - Checks source note that package asset folders are not copied.

## Validation Results

| Command | Result | Notes |
| --- | --- | --- |
| `pnpm qa:release-smoke` | Passed | 36 release/source checks passed, including Local Snapshot checks and Phase 12A Windows CI/source readiness checks. |
| `pnpm typecheck` | Passed | Workspace TypeScript checks passed for core, renderer, and desktop. |
| `pnpm lint` | Passed | ESLint passed for core, renderer, and desktop. |
| `pnpm format:check` | Passed after formatting | Initial check found formatting diffs in `SettingsApp.tsx`; Prettier was run for that file, then the check passed. |
| `pnpm test` | Passed | core 34, renderer 9, desktop 41; total 84 frontend/domain tests. |
| `pnpm --filter @codexpet/desktop-tauri test` | Passed | Targeted desktop tests passed before the full workspace run: 41 tests. |
| `cd apps/desktop-tauri/src-tauri && cargo fmt --all --check` | Passed after formatting | Initial check found formatting diffs in new snapshot code; `cargo fmt --all` was run, then the check passed. |
| `cd apps/desktop-tauri/src-tauri && cargo clippy --all-targets -- -D warnings` | Passed | No warnings. |
| `cd apps/desktop-tauri/src-tauri && cargo test` | Passed | 34 lib tests, 0 main tests, 3 config integration tests, and 0 doc tests passed. |
| `pnpm tauri:build:app` | Passed on macOS | Produced `/Users/ryanniu/Documents/Project/codexpet-nest-next/apps/desktop-tauri/src-tauri/target/release/bundle/macos/CodexPet Nest.app`. This is not Windows artifact verification. |

Full local macOS validation passed. Windows CI and Windows GUI validation remain separate pending work.

## Windows Status

Windows status remains unchanged from Phase 12A:

- CI/source readiness only.
- CI run not executed.
- Needs CI execution.
- Needs GUI verification.
- Windows support still experimental.
- Windows click-through is Not supported yet.
- Windows `follow-codex` parity is Not supported yet.

This phase does not provide Windows GUI evidence and must not be used to claim Windows parity completed.

## Remaining Work

- Add a file picker if/when the product wants native path selection instead of typed paths.
- Decide whether future snapshots should optionally bundle local package assets.
- Define cloud sync and conflict resolution separately from local snapshot import/export.
- Run the final full local validation set before release readiness claims.
- Run Windows CI and real Windows GUI validation in a future Windows-specific phase before any Windows parity claim.
