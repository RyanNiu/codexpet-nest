# Phase 10 macOS Manual QA + Bug Bash Report

Date: 2026-06-03

## Scope

Phase 10 validates the Phase 9 release-ready desktop app on macOS, records manual QA coverage, adds lightweight automated release-readiness checks, and fixes only small desktop-use bugs found during QA review.

No cloud sync, Windows adaptation, marketplace behavior, new nest package ecosystem, real shell action execution, large UI refactor, or follow-loop rewrite is included.

## Required Reading Completed

- `docs/phase1-risk-spike-report.md`
- `docs/phase2-core-domain-port-report.md`
- `docs/phase3-overlay-rendering-mvp-report.md`
- `docs/phase4-settings-local-management-report.md`
- `docs/phase5-package-registry-local-assets-report.md`
- `docs/phase6-local-package-import-asset-resolution-report.md`
- `docs/phase7-widget-runtime-actions-report.md`
- `docs/phase8-overlay-follow-position-report.md`
- `docs/phase9-production-ux-release-readiness-report.md`
- `apps/desktop-tauri/src/components/overlay/OverlayApp.tsx`
- `apps/desktop-tauri/src/components/settings/SettingsApp.tsx`
- `apps/desktop-tauri/src/components/debug/DebugPanel.tsx`
- `apps/desktop-tauri/src-tauri/src/**`

## QA Checklist

| Item | Status | Evidence / Notes |
| --- | --- | --- |
| release app can start | Needs user manual verification | Requires launching the built `.app` in a live macOS GUI session. |
| settings window can open | Needs user manual verification | Tray/menu-bar path requires live GUI verification. |
| settings can reopen from tray/menu-bar after closing | Needs user manual verification | Automated source check confirms close-to-hide handler and recreate fallback exist. |
| tray/menu-bar icon is visible | Needs user manual verification | Automated source check confirms `32x32.png` is embedded in tray builder. |
| Show Overlay works | Needs user manual verification | React tests cover Settings invoke path; tray behavior requires GUI verification. |
| Hide Overlay works | Needs user manual verification | React tests cover Settings invoke path; tray behavior requires GUI verification. |
| Open Settings works | Needs user manual verification | Automated source check confirms tray menu item and helper path. |
| Quit works | Needs user manual verification | Tauri predefined quit menu requires GUI verification. |
| overlay release mode has no debug red/yellow boxes or DEBUG text | Automated verified | React production overlay tests plus release smoke check verify debug UI is gated by `config.isDebug === true`. |
| overlay can display nest | Automated verified | React overlay tests assert renderer-backed nest model and widget slots render. |
| active nest can switch and persist | Automated verified | Settings and overlay React tests cover active nest save and render behavior. |
| standalone-fixed mode restores saved position | Automated verified | React overlay tests cover `move_overlay_to_clamped` restore path. |
| overlay is draggable | Needs user manual verification | React tests cover pointer/startDragging path; real native drag requires GUI verification. |
| dragged position saves and restores after restart | Needs user manual verification | React tests cover standalone drag persistence; restart behavior requires live app relaunch. |
| follow-codex follows when Codex state is available | Needs user manual verification | React tests cover follow movement from mocked Codex mascot bounds; real Codex state needs GUI validation. |
| Codex state unavailable does not jump or show technical error | Automated verified | React production test covers hidden technical errors; Phase 8 logic holds position. |
| click-through on lets mouse pass through overlay | Needs user manual verification | Native AppKit behavior requires live GUI verification. |
| click-through on makes overlay quick actions unavailable | Automated verified | React overlay test covers `Click-through is on` replacement and hidden quick actions. |
| click-through off makes overlay quick actions clickable | Automated verified | React overlay quick action tests cover clickable controls. |
| quick action confirm flow works | Automated verified | React overlay test covers require-confirm first-click behavior. |
| local package import basic flow works | Automated verified | Settings React tests and Rust import validation tests cover directory import path. |
| missing assets have gentle feedback | Automated verified | React overlay tests cover missing local assets without crash and production gentle copy. |
| Development Diagnostics expands and shows status | Needs user manual verification | React tests confirm section and DebugPanel render; native status values require GUI verification. |
| release app does not depend on dev server | Automated verified | Release smoke check verifies `frontendDist` and `beforeBuildCommand`; build command produces `.app`. |

## Automated Verification Added

- Added `scripts/check-release-readiness.mjs`.
- Added root script `pnpm qa:release-smoke`.
- The smoke check validates release config, bundle icons, tray/menu source wiring, settings close-to-hide, release overlay sizing, debug UI gating, click-through quick-action hiding, gentle missing-asset feedback, Development Diagnostics presence, and Follow Status refresh polling.

## Bug Bash Fixes

- Fixed Settings Follow Status staleness: `SettingsApp` now refreshes overlay follow diagnostics from localStorage every second while the settings window remains open.
- This keeps the visible Follow Status card aligned with overlay runtime changes without requiring users to close/reopen Settings.

## Tests Added / Updated

- Added a Settings React test covering live Follow Status refresh while Settings remains open.
- Existing overlay tests continue to cover release debug-boundary behavior, click-through quick-action behavior, quick-action confirmation, missing-asset feedback, standalone restore, drag persistence, and follow movement from Codex mascot bounds.
- Added a lightweight Node release-readiness smoke check instead of introducing a large E2E framework.

## Manual Verification Protocol

Use the built app at:

- `apps/desktop-tauri/src-tauri/target/release/bundle/macos/CodexPet Nest.app`

Manual tester should launch the release `.app`, then mark each `Needs user manual verification` checklist row as pass/fail with notes. Items not directly observed must remain unpassed.

## Validation Commands

Phase 10 required commands:

```bash
pnpm typecheck
pnpm lint
pnpm format:check
pnpm test
cd apps/desktop-tauri/src-tauri && cargo fmt --all --check
cd apps/desktop-tauri/src-tauri && cargo clippy --all-targets -- -D warnings
cd apps/desktop-tauri/src-tauri && cargo test
pnpm tauri:build:app
```

Additional Phase 10 smoke command:

```bash
pnpm qa:release-smoke
```

## Validation Results

| Command | Result | Notes |
| --- | --- | --- |
| `pnpm qa:release-smoke` | Passed | 24 release-readiness checks passed. |
| `pnpm typecheck` | Passed | Workspace TypeScript checks passed for core, renderer, and desktop. |
| `pnpm lint` | Passed | ESLint passed for core, renderer, and desktop. |
| `pnpm format:check` | Passed | All matched app/package TS/TSX/CSS/JSON files use Prettier style. |
| `pnpm test` | Passed | core 34, renderer 9, desktop 39; total 82 frontend/domain tests. |
| `cd apps/desktop-tauri/src-tauri && cargo fmt --all --check` | Passed | No formatting differences. |
| `cd apps/desktop-tauri/src-tauri && cargo clippy --all-targets -- -D warnings` | Passed | No warnings. |
| `cd apps/desktop-tauri/src-tauri && cargo test` | Passed | 28 lib tests and 3 config integration tests passed. |
| `pnpm tauri:build:app` | Passed | Release `.app` bundle produced. |

Release app path:

- `apps/desktop-tauri/src-tauri/target/release/bundle/macos/CodexPet Nest.app`

## Remaining Items

- macOS GUI-only checklist rows still require a human manual pass in a desktop session.
- Windows Codex state path/schema remains unverified.
- Windows transparent overlay and click-through behavior remain unverified or stubbed.
- Windows mixed-DPI and multi-monitor positioning require real-device validation.
- Windows tray/menu behavior and installer output require real-device validation.
