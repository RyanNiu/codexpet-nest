# Phase 2: Core Domain Port Report

Date: 2026-06-01

## Scope

Phase 2 first batch only ports reusable core/domain rules. It does not implement formal marketplace UI, widgets UI, sync backend, full overlay follow, ZIP extraction, or package installation.

## Implemented Modules

### `@codexpet/core`

Created `packages/core` as a TypeScript workspace package with:

- `src/package-schema/`: package manifest types and pure validation logic
- `src/settings/`: settings schema, defaults, normalization, and migration framework
- `src/sync/`: local-first sync record/device metadata types only
- `src/codex-home/`: pure Codex home resolver logic
- `src/index.ts`: public exports

Root workspace scripts now run all package checks via `pnpm -r --if-present` for `typecheck`, `lint`, and `test`.
Phase 0/Phase 2 app bundle validation uses the stable root script `pnpm tauri:build:app`.

## Specs Migrated

The current repository did not have `docs/specs/`, so only spec documents were copied from the old projects. No Swift source code was copied.

- `docs/specs/nest-package.md`
- `docs/specs/nest-theme-v1.1.md`
- `docs/specs/pet-package.md`

These documents are used as the source of truth for the Phase 2 validators.

## Package Validator Rules

Implemented pure logic validator for:

- `codexpet.pet`
- `codexpet.nest`
- `codexpet-package.json`
- `pet.json`
- v1.0 `nest.json`
- v1.1 draft `metricBands` and `elements`

Covered fields:

- `type`
- `schemaVersion`
- `id`
- `name` / `displayName`
- `version`
- `author`
- `description`
- `preview`
- `manifest`
- `spritesheet`
- `layout` / `theme`
- `tags`
- `widgetSlots`
- `layers`
- `metricBands`
- `elements`

Security validation implemented:

- Rejects path traversal via `../`
- Rejects absolute paths
- Rejects Windows drive paths
- Rejects remote URL resources
- Rejects scripts: `.js`, `.ts`, `.sh`, `.py`, and related extensions
- Rejects executable installers/binaries: `.exe`, `.app`, `.dmg`, `.bat`, `.cmd`, `.ps1`, and related extensions
- Allows only safe package resources: `png`, `webp`, `gif`, `json`, `md`, `txt`, and license-like files
- Rejects package size over 5MB
- Rejects image file size over 2MB
- Validates referenced package files exist for manifest preview, pet manifest, pet spritesheet, nest layout/theme, nest layers, `staticImage` sources, and `variantImage` variants/fallback
- Warns when canvas exceeds recommended 512x512
- Reports clear errors for missing manifest and package type mismatch

## Settings Schema

Implemented `CodexPetSettings` with:

- `schemaVersion`
- `activeNestId`
- `overlayMode`
- `standalonePosition`
- `alwaysOnTop`
- `clickThrough`
- `widgetConfigs`
- `managedPetIds`
- `managedNestIds`
- `quickActions`
- `sync` / device metadata
- `language`
- `locale`

Implemented behavior:

- `createDefaultSettings()`
- corrupted settings fallback
- unsupported future version fallback
- v1 to current migration path
- current settings normalization

## Codex Home Resolver

Implemented pure resolver rules:

- `CODEX_HOME` takes priority
- defaults to `.codex` under home directory
- supports tilde expansion
- handles macOS/Linux path separators
- handles Windows path separators
- rejects protected paths such as `/System`, `/usr`, `/etc`, Windows drive roots, `C:\Windows`, and `C:\Program Files`

## Tests

Added core tests covering:

- valid pet package manifest
- valid nest package manifest
- missing manifest
- invalid package type
- path traversal
- unsafe file extension
- remote URL resource
- missing preview file reference
- missing pet spritesheet file reference
- missing nest layer asset reference
- missing variantImage asset reference
- oversized package/image
- v1.0 nest layout with widget slots
- v1.1 elements and metricBands
- settings default
- settings migration
- corrupted settings fallback
- Codex home resolver with `CODEX_HOME`
- default macOS/Linux `.codex`
- default Windows `.codex`
- protected path rejection

Current core test count: 21 tests.

## Swift Behavior Mapping

The validator and schema mirror the old Swift-era product rules at the domain level:

- Nest v1.0 static package structure maps to `codexpet.nest` + `nest.json` validation.
- v1.1 draft theme concepts map to typed `metricBands` and `elements` validation.
- Pet package metadata maps to `codexpet.pet` + `pet.json` validation.
- Existing user preferences map to typed settings with schema migration and corrupted-file fallback.
- Codex directory discovery maps to pure resolver logic so platform-specific file IO can call it later.

No old Swift source code was copied.

## Not Implemented Yet

- ZIP extraction and archive entry enumeration
- SHA256 verification
- symlink detection during extraction
- actual package install/uninstall flow
- app data path abstraction for install targets
- marketplace UI or package install UI
- sync backend or sync queue
- widgets UI/runtime
- complete overlay follow runtime
- Windows real-device validation

## Windows Status

Windows items remain explicitly unverified:

- Codex Desktop global state path/schema
- transparent overlay behavior
- click-through implementation
- mixed-DPI multi-monitor placement
- tray/menu behavior

## Recommendation

Phase 2 first batch is sufficient as a domain foundation for Phase 3 overlay/rendering MVP once validation passes. Phase 3 should consume `@codexpet/core` rather than duplicating package/settings rules in UI code.
