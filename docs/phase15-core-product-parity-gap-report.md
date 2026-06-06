# Phase 15 Core Product Parity Gap Report

Date: 2026-06-06

## Scope

This report is Workstream A for `docs/phase15-core-product-parity-recovery-plan.md`. It is a source audit only. It does not implement new product functionality and does not claim core product parity is complete.

Source baseline:

- Original Swift/AppKit project: `/Users/ryanniu/Documents/Project/codexpet-nest`
- Current Tauri migration project: `/Users/ryanniu/Documents/Project/codexpet-nest-next`
- Product requirements: `docs/requirements-overview.md`

Status vocabulary used below:

- `Implemented`: source and product flow exist for the current scope, with test or manual evidence.
- `Partial`: some source exists, but the original product capability is not fully migrated.
- `Missing`: no current product flow or source implementation was found.
- `Stub / fixture-only`: code exists mainly as fixtures, debug scaffolding, or placeholders.
- `Source-verified only`: source was found, but no manual product verification evidence was found in this audit.
- `macOS manual verification needed`: macOS source path may exist, but release GUI behavior still needs real app verification.
- `Windows unverified / unsupported`: Windows behavior is not validated, incomplete, or explicitly unsupported.

## Original Source Evidence

The original Swift project has complete product references for the audited areas:

- Pet runtime/window/animation: `StandalonePetWindow.swift`, `PetRuntimeCoordinator.swift`, `PetSpriteSheetRenderer.swift`, `PetAnimationPlayer.swift`, `PetBehaviorEngine.swift`, `PetImageCache.swift`.
- Local pet management: `LocalPetManager.swift`, `LocalPetManagerViewController.swift`.
- Pet marketplaces: `OnlinePetMarketplaceViewController.swift`, `PetMarketplaceProvider.swift`, `CodexPetAPI.swift`.
- Package validation/install security: `PackageManager.swift`, `SafeZipReader.swift`.
- Nest runtime/renderer: `NestOverlayWindow.swift`, `NestRenderer.swift`, `NestUI.swift`, `OfficialComponentRenderer.swift`.
- Local/online nest management: `LocalNestManager.swift`, `LocalNestManagerViewController.swift`, `OnlineNestMarketplaceWindowController.swift`.
- Settings/i18n: `SettingsStore.swift`, `I18n.swift`.

## Current Tauri Evidence

Current Tauri source evidence used for this report:

- App/window routing: `apps/desktop-tauri/src/App.tsx`.
- Overlay UI: `apps/desktop-tauri/src/components/overlay/OverlayApp.tsx`, `apps/desktop-tauri/src/components/overlay/NestOverlayView.tsx`.
- Settings UI: `apps/desktop-tauri/src/components/settings/SettingsApp.tsx`.
- Registry store: `apps/desktop-tauri/src/store/registryStore.ts`.
- Built-in nest fixtures: `packages/renderer/fixtures/nests/index.ts`.
- Nest render model: `packages/renderer/src/nest/renderModel.ts`, `packages/renderer/src/nest/loadNestTheme.ts`.
- Package schema validation: `packages/core/src/package-schema/validator.ts`.
- Registry/settings schemas: `packages/core/src/package-registry/index.ts`, `packages/core/src/settings/index.ts`.
- Local import/config commands: `apps/desktop-tauri/src-tauri/src/commands/config.rs`.
- Overlay platform paths: `apps/desktop-tauri/src-tauri/src/windows/setup.rs`, `apps/desktop-tauri/src-tauri/src/platform/macos.rs`, `apps/desktop-tauri/src-tauri/src/platform/windows.rs`.

## Gap Table

| Original capability | Original Swift module | Current Tauri status | macOS status | Windows status | Required next work |
| --- | --- | --- | --- | --- | --- |
| Standalone pet window | `StandalonePetWindow.swift`, `PetRuntimeCoordinator.swift`, `SettingsStore.swift` | Missing. Current app routes only main/settings and nest overlay paths; no pet window label, no `PetOverlayView`, no `packages/renderer/src/pet/`. | Missing. No macOS pet window source path to verify. | Missing / Windows unverified / unsupported. No Windows pet window path exists. | Implement standalone pet window or overlay target, transparent background, always-on-top, drag/position persistence, honest unsupported states for platform gaps. |
| Pet spritesheet rendering | `PetSpriteSheetRenderer.swift`, `PetImageCache.swift` | Missing. Package schema can reference pet manifest/spritesheet, but no frame extraction, atlas descriptor, cache, or renderer exists. | Missing. | Missing / Windows unverified / unsupported. | Add manifest parser and cross-platform spritesheet frame renderer, including 8x9 atlas and fallback first-frame extraction. |
| Pet animation playback | `PetAnimationPlayer.swift`, `PetBehaviorEngine.swift` | Missing. No animation player, action resolver, timer/frame step logic, idle/hover/walk playback, or random behavior engine. | Missing. | Missing / Windows unverified / unsupported. | Implement idle playback first, then action aliases and behavior engine after renderer foundation. |
| Local pet scan | `LocalPetManager.swift`, `LocalPetManagerViewController.swift` | Missing. Registry schema allows `pet`, but UI filters nests only via `getNestEntries`; no Codex pet directory scan or Nest internal pet scan. | Missing. | Missing / Windows unverified / unsupported; Codex Windows pet paths are not verified. | Build local pet manager service that scans app-managed pets and Codex pets using platform dirs and `CODEX_HOME`. |
| Local pet ZIP install | `PackageManager.swift`, `SafeZipReader.swift`, `LocalPetManagerViewController.swift` | Missing. Rust `import_local_package` accepts directories only and rejects non-`codexpet.nest`; no ZIP reader/install path for pets. | Missing. | Missing / Windows unverified / unsupported. | Add safe ZIP install pipeline for `codexpet.pet`, with validation before registry update. |
| App-managed pet uninstall | `LocalPetManager.swift`, `SettingsStore.swift` | Missing. Settings schema has `managedPetIds`, but there is no uninstall command or pet manager UI. | Missing. | Missing / Windows unverified / unsupported. | Add app-managed-only uninstall command and UI; never delete Codex-managed pets. |
| Active Codex pet read-only marker | `LocalPetManager.swift`, `SettingsStore.swift` | Missing. `codex_state` supports overlay follow data, but Settings/local package UI does not display active Codex pet id as read-only product state. | Missing / macOS manual verification needed for active pet source fields. | Windows unverified / unsupported; `platform/windows.rs` documents Codex state path/schema as unverified. | Read active pet id without writing Codex state and expose it in Settings and local pet list. |
| Official pet marketplace browse | `OnlinePetMarketplaceViewController.swift`, `PetMarketplaceProvider.swift`, `CodexPetAPI.swift` | Missing. No pet marketplace provider/component/API client exists in the Tauri migration. | Missing. | Missing / Windows unverified / unsupported. | Implement official pet marketplace MVP list/detail UI and offline/error states. |
| Official pet download metadata | `CodexPetAPI.swift`, `PetMarketplaceProvider.swift` | Missing. No current HTTP client or official pet download metadata flow was found. | Missing. | Missing / Windows unverified / unsupported. | Add metadata fetch contract, typed response validation, installed-state mapping. |
| Official pet SHA256 validation | `PackageManager.swift` | Missing. Current package validator is structural; no remote SHA256 verification exists. | Missing. | Missing / Windows unverified / unsupported. | Add download SHA256 validation before install and tests for mismatch. |
| Petdex browse | `PetMarketplaceProvider.swift`, `OnlinePetMarketplaceViewController.swift` | Missing. No Petdex source, third-party trust level, manifest cache, or UI exists. | Missing. | Missing / Windows unverified / unsupported. | Add Petdex source behind explicit third-party labeling and risk prompts. |
| Petdex HTTPS / allowed host validation | `PetMarketplaceProvider.swift`, `PackageManager.swift` | Missing. Current validator rejects remote package-internal resources but does not validate Petdex download URLs or allowed hosts. | Missing. | Missing / Windows unverified / unsupported. | Add HTTPS-only and host allowlist policy before any third-party download. |
| Petdex manifest inspect before install | `PackageManager.swift`, `PetMarketplaceProvider.swift`, `OnlinePetMarketplaceViewController.swift` | Missing. No remote inspect-before-install flow or user confirmation exists. | Missing. | Missing / Windows unverified / unsupported. | Download/inspect manifest before install, show id/source, and reject id mismatch after download. |
| Nest renderer parity | `NestRenderer.swift`, `NestUI.swift`, `OfficialComponentRenderer.swift`, `NestOverlayWindow.swift` | Partial / Stub / fixture-only. `renderModel.ts` supports layers, widget slots, `staticImage`, `variantImage`, `metricText`, `metricGauge`; `NestOverlayView.tsx` renders simple HTML/CSS. It is not full Swift renderer parity and remains fixture/MVP-first. | Partial / Source-verified only; macOS manual verification needed for release overlay appearance. | Partial / Windows unverified / unsupported for GUI parity and click-through. | Move from fixture-first model to package-driven renderer parity, including real assets, official components, fallback states, and release visual QA. |
| Built-in four nests | `LocalNestManager.swift`, `NestRenderer.swift`, `OfficialComponentRenderer.swift` | Partial / Stub / fixture-only. Fixtures define `capacity-orbit-nest`, `basket-pomodoro-nest`, `legend-status-nest`, `nest-terminal`, plus `default`, but registry currently exposes only `default`, `capacity-orbit-nest`, and `basket-pomodoro-nest`. | Source-verified only; macOS manual verification needed. | Source-verified only / Windows unverified. | Register all required built-ins consistently and verify preview/apply/render behavior. |
| Local nest manager | `LocalNestManager.swift`, `LocalNestManagerViewController.swift`, `PackageManager.swift` | Partial. Settings can list/select nest entries and import a local nest directory, but there is no ZIP install, uninstall, built-in delete protection UI, or full app-managed lifecycle. | Partial / Source-verified only; macOS manual verification needed. | Partial / Windows unverified / unsupported for GUI behavior. | Add full local nest manager UI/service: scan, preview, apply, ZIP import, uninstall app-managed only, open folder. |
| Online nest marketplace | `OnlineNestMarketplaceWindowController.swift`, `CodexPetAPI.swift`, `PackageManager.swift` | Missing. No online nest marketplace API/component exists; no explicit Coming Soon product entry was found in Settings. | Missing. | Missing / Windows unverified / unsupported. | Either implement API-backed nest marketplace or add honest Coming Soon entry without fake remote data. |
| Package install cleanup on failure | `PackageManager.swift`, `SafeZipReader.swift` | Missing for package install. Snapshot import has staged rollback, but local package import registers directories and does not have ZIP extraction/install cleanup. | Missing / Source-verified only for unrelated snapshot rollback. | Missing / Source-verified only for unrelated snapshot rollback. | Add staged extraction directory, atomic move, registry update after validation, and cleanup on any failure. |
| Package validation: missing manifest, path traversal, unsafe type, sha mismatch, id mismatch | `PackageManager.swift`, `SafeZipReader.swift` | Partial / Source-verified only. TS validator covers missing `codexpet-package.json`, unsafe paths, unsafe extensions, package type, and some nest layout checks. SHA mismatch and id mismatch are Missing. Rust local import does not call the TS validator and only supports nest directories. | Partial / Source-verified only; no macOS install-flow verification. | Partial / Windows unverified / unsupported; no Windows ZIP/install validation evidence. | Unify validation in the actual install path; add SHA256, metadata/package id matching, ZIP traversal/symlink cleanup, and tests across pet/nest. |
| Settings information architecture | `SettingsStore.swift`, `LocalPetManagerViewController.swift`, `OnlinePetMarketplaceViewController.swift`, `LocalNestManagerViewController.swift` | Partial. `SettingsApp.tsx` covers Overlay, Follow Status, Widgets/Actions, Local Packages/Nests, Local Snapshot, App Info, Development Diagnostics. It lacks Pet, Pet Marketplace, Petdex, local pet management, and nest marketplace IA. | Partial / Source-verified only; macOS manual verification needed for menu-bar entry routing. | Partial / Windows unverified / unsupported for tray entry routing. | Redesign Settings into product control center with Pet, Pet Marketplace, Nest, Nest Marketplace/Coming Soon, Overlay, Widgets, Snapshot, App Info, Diagnostics. |
| i18n English / Simplified Chinese | `I18n.swift` | Missing / field-only. Settings schema has `language`/`locale`, but React UI strings are hardcoded English and no i18n dictionary/hook was found. | Missing. | Missing. | Add i18n dictionaries and runtime language selection/fallback for English and Simplified Chinese. |

## Additional Platform Findings

- macOS overlay transparency and click-through have source paths in `platform/macos.rs`, but this report found no fresh manual QA evidence for release GUI behavior. These remain `macOS manual verification needed`.
- Windows support is not product parity. `platform/windows.rs` explicitly states Windows helpers are `NOT YET VERIFIED ON WINDOWS`, Codex state path/schema are unverified, and `platform/macos.rs` returns `Windows click-through is not implemented yet` for click-through. Windows should remain `Windows unverified / unsupported` for GUI parity-sensitive paths until real-device verification happens after core flows exist.
- Current Windows CI/artifact evidence is useful for build confidence, but it does not prove pet, marketplace, package install, or renderer parity.

## Highest-Risk Gaps

1. Pet display is entirely absent from the Tauri product surface.
2. Pet animation and spritesheet rendering are absent despite being core original product behavior.
3. Local pet management and pet install/uninstall are absent.
4. Official pet marketplace and Petdex are absent, including download metadata, SHA256, host allowlist, and inspect-before-install security.
5. Nest display exists only as a partial MVP/fixture-first renderer and does not yet match original `NestRenderer` / `OfficialComponentRenderer` behavior.
6. Package validation exists partly in TypeScript tests but is not yet a complete install pipeline with ZIP extraction, cleanup, SHA256, and id mismatch checks.
7. Settings remains closer to an engineering control panel than the original product control center.
8. i18n is not implemented beyond settings fields.
9. Windows GUI/product parity remains unverified and unsupported for click-through.

## Recommended Implementation Order

1. Pet manifest parsing and renderer.
2. Standalone pet window/overlay.
3. Local pet scan/install/manage.
4. Official pet marketplace MVP.
5. Petdex MVP.
6. Package-driven nest renderer parity.
7. Local nest manager.
8. Nest marketplace / Coming Soon.
9. Settings information architecture.
10. macOS production QA.
11. Windows GUI validation after core flows exist.

## Current Completion Statement

The project has not completed core product parity. The current Tauri migration has useful app shell, overlay MVP, registry, snapshot, release smoke, and Windows CI artifact groundwork, but the original product's pet runtime, pet animation, local pet management, official pet marketplace, Petdex install flow, full package install security, local nest management, nest marketplace, Settings IA, i18n, and Windows GUI parity remain incomplete.
