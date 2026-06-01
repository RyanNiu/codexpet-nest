# Phase 3: Overlay and Rendering MVP Report

Date: 2026-06-01

## Scope

Phase 3 implements the first renderer and overlay runtime MVP. It focuses on a visible nest render model inside the existing Tauri overlay and intentionally does not implement marketplace, sync, formal package install UI, real package installation, or a continuous follow loop.

## Renderer Package

Created `packages/renderer` as `@codexpet/renderer`.

Structure:

- `src/index.ts`: public exports
- `src/nest/types.ts`: render model and asset resolver types
- `src/nest/loadNestTheme.ts`: validates nest fixtures through `@codexpet/core`
- `src/nest/renderModel.ts`: pure render model builder
- `src/widgets/types.ts`: built-in widget slot types
- `src/metrics/types.ts`: metric value and snapshot types
- `src/metrics/metricSnapshot.ts`: MVP metric snapshot factory

The package depends on `@codexpet/core` and consumes core `NestLayoutManifest`, `NestPackageManifest`, `PackageFileEntry`, `ValidationIssue`, and settings `OverlayMode` types rather than duplicating schema rules.

## Supported Render Model Features

The MVP render model supports:

- v1.0 `layers` ordering
- v1.0 `widgetSlots` passthrough
- v1.1 `staticImage`
- v1.1 `variantImage`
- v1.1 `metricText`
- v1.1 `metricGauge`
- `metricBands` derived enum metrics, for example `usage.primary.remaining_percent` to `usage.primary.remaining_band`
- missing asset issues without crashing
- unavailable metric fallback without crashing

Render model output includes:

- canvas size
- ordered resolved layers
- widget slots
- resolved elements
- derived metric bands
- missing asset and metric unavailable issues

## Built-In Nest Fixtures

Created renderer fixtures under `packages/renderer/fixtures/nests/`.

Current fixtures:

- `default`
- `capacity-orbit-nest`
- `basket-pomodoro-nest`
- `legend-status-nest`
- `nest-terminal`

The fixtures use placeholder data-URI image assets for now. The structure mirrors `docs/specs/nest-package.md` and `docs/specs/nest-theme-v1.1.md`, but real artwork migration is intentionally deferred.

## Desktop Overlay Integration

`apps/desktop-tauri` now depends on `@codexpet/renderer` and `@codexpet/core`.

Overlay changes:

- `OverlayApp` no longer renders only plain `Nest v...` text.
- Added `NestOverlayView` to render the renderer output.
- Rendered output includes placeholder image layers, widget slot labels, metric text, and simple metric gauge placeholders.
- Dev `DEBUG OVERLAY` border and platform label remain visible.
- Overlay includes a small built-in fixture selector for manual Phase 3 verification.
- Renderer logic stays in `@codexpet/renderer`; React only translates the render model to DOM.

## Metric Snapshot MVP

Implemented `createMetricSnapshot()` with:

- `system.time.hhmm`
- `system.date.short`
- `system.time.day_period`
- mocked `usage.primary.remaining_percent`
- mocked `usage.primary.remaining_ratio`
- mocked/unavailable `usage.source`

Unavailable metrics produce fallback text/gauge state and render issues instead of crashing.

## Overlay Runtime MVP

The overlay now keeps a minimal runtime mode state:

- `follow-codex`
- `standalone-fixed`

Runtime behavior:

- Reads Codex state once on overlay mount.
- If mascot bounds are available, computes one nest position through existing Phase 1 `convert_position` command and reports the initial position.
- If Codex state or mascot bounds are unavailable, switches to standalone fallback.
- Continuous follow loop is not enabled in this phase.

Existing Phase 1 controls remain in Settings Debug Panel:

- Show/Hide Overlay
- Click-through toggle
- Codex state debug
- screen list and coordinate conversion debug

## Tests

Added renderer tests for:

- v1.0 layers ordering
- widgetSlots passthrough
- staticImage asset resolve
- variantImage selection by metric
- variantImage fallback
- metricText unavailable fallback
- metricGauge unavailable fallback
- metricBands band calculation
- built-in fixture loading through core validation

Updated desktop overlay tests to assert nest render model output and avoid React `act(...)` warnings.

Current automated test counts:

- `@codexpet/core`: 21 tests
- `@codexpet/renderer`: 9 tests
- `@codexpet/desktop-tauri`: 14 tests
- Total: 44 tests

## Manual Dev Smoke

`pnpm tauri:dev` initially reported port `1420` already in use because the current project Vite dev server was already running. The running process was confirmed as this repo's Vite server. Tauri was then launched against the existing dev server with:

```bash
pnpm --filter @codexpet/desktop-tauri tauri dev --config '{"build":{"beforeDevCommand":null}}' --no-dev-server-wait
```

The app compiled and launched successfully; the command ran until the tool timeout terminated the long-lived dev process. No Rust panic or startup error was observed. Visual confirmation of Settings/Overlay requires a human session, but the overlay render path and nest fixture switching are covered by React tests.

## Manual Validation Follow-Up Patch

Manual Phase 3 validation found two issues before Phase 4:

- The overlay window was too small, so the nest render MVP was visually crowded.
- The overlay could not be dragged because the drag region was not explicit enough for the interactive overlay layout.

Fixes applied:

- Dev/debug overlay window size is now `480x260` logical pixels.
- Added Rust helpers and commands:
  - `resize_overlay_debug`
  - `reset_overlay_position`
- Settings Debug Panel now exposes:
  - `Reset Overlay Position`
  - `Resize Overlay for Debug`
- Overlay DOM now has an explicit top drag pill labeled `Drag Overlay` with `data-tauri-drag-region`.
- The root overlay is no longer the drag region, so fixture buttons remain clickable.

Expected manual behavior after the patch:

- With click-through disabled, dragging the `Drag Overlay` top pill moves the overlay.
- Fixture buttons remain clickable and continue switching fixtures.
- With click-through enabled, mouse events pass through and dragging is not expected.
- Disabling click-through restores overlay interactivity and drag behavior.
- `Reset Overlay Position` returns the overlay to a visible top-right debug position.
- `Resize Overlay for Debug` reapplies the `480x260` debug size.

## Not Implemented Yet

- real asset migration
- bundled artwork installation/registration
- continuous follow loop
- real usage metrics / UsageReader
- real package install/uninstall
- widgets runtime interactions
- marketplace UI
- sync backend
- Windows real-device validation

## Windows Status

Windows remains unverified and is not marked as complete:

- Codex state path/schema
- overlay transparency/click-through behavior
- mixed DPI position accuracy
- tray/menu behavior

## Recommendation

This MVP is sufficient to proceed toward Phase 4 once manual overlay verification passes. Phase 4 should build UI and local management around the renderer/core packages instead of moving renderer or schema rules back into app components.
