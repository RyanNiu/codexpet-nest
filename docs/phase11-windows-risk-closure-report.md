# Phase 11 Windows Risk Closure Report

Date: 2026-06-03

## Scope

Phase 11 closes Windows support risk without attempting a complete Windows parity build. The goal is to separate capabilities that are already portable from source/config, capabilities that need Windows-specific implementation, and capabilities that must remain Phase 12 parity work.

This phase intentionally does not implement Win32 click-through, Windows installer signing, Windows updater metadata, Windows credential storage, or Windows GUI parity. No Windows result is marked `Verified on Windows` because this phase was performed on macOS.

## Environment used

| Field | Value |
| --- | --- |
| Machine OS | macOS / Darwin 25.3.0 arm64 |
| Windows real machine available | No |
| Windows build attempted | No, current host is not Windows |
| Windows manual GUI validation | Not performed |
| Repo path | `/Users/ryanniu/Documents/Project/codexpet-nest-next` |

## Windows checklist table

| Item | Status | Evidence / Notes |
| --- | --- | --- |
| Windows app 能否 build | Needs Windows manual verification | Current host is macOS. Source scan found platform cfg separation and macOS-only `objc` dependency under `target_os = "macos"`, but no Windows build was run. |
| Windows bundle/installer 产物类型 | Automated/source verified | `tauri.conf.json` has `bundle.active = true`, `bundle.targets = "all"`, includes `icon.ico`, and a `bundle.windows.nsis` section set to `null`. Actual Windows artifact paths require Windows build verification. |
| Windows app 是否能启动 | Needs Windows manual verification | Requires launching the Windows bundle in a live Windows GUI session. |
| Windows settings window 是否能打开 | Needs Windows manual verification | Source confirms `create_settings_window` and tray `Open Settings...` path exist, but native Windows behavior requires GUI validation. |
| Windows tray icon 是否显示 | Needs Windows manual verification | Source embeds `32x32.png` in tray builder and bundle config includes `icon.ico`; visibility requires Windows tray validation. |
| Show Overlay 是否可用 | Needs Windows manual verification | Source path uses shared `show_overlay_window`; native Windows window behavior needs GUI validation. |
| Hide Overlay 是否可用 | Needs Windows manual verification | Source path uses shared `hide_overlay_window`; native Windows window behavior needs GUI validation. |
| Open Settings 是否可用 | Needs Windows manual verification | Source path uses shared `show_settings_window` with recreate fallback; native Windows window focus behavior needs GUI validation. |
| Quit 是否可用 | Needs Windows manual verification | Tray uses Tauri predefined quit item; actual Windows tray/menu behavior needs GUI validation. |
| overlay 是否透明 | Needs Windows manual verification | Source config uses `.transparent(true)`. `apply_native_transparency` is only native on macOS and logs an unverified warning on non-macOS. |
| overlay 是否 always-on-top | Needs Windows manual verification | Source config uses `.always_on_top(true)`, but Windows z-order behavior requires manual validation. |
| overlay 是否 skip taskbar | Needs Windows manual verification | Source config uses `.skip_taskbar(true)`, but Windows taskbar behavior requires manual validation. |
| click-through 是否可实现 | Not supported yet | Phase 11 did not implement Win32 `WS_EX_LAYERED` / `WS_EX_TRANSPARENT`; this is Phase 12 work. |
| 当前 `set_overlay_click_through` 在 Windows 上实际表现是什么 | Automated/source verified | Phase 11 changed Windows implementation to return `Err("Windows click-through is not implemented yet")` instead of false success. Actual Windows IPC display still needs GUI validation. |
| Codex Desktop Windows state 路径是否存在 | Needs Windows manual verification | Resolver defaults to `<home>/.codex` via `dirs::home_dir()`, but real Codex Desktop Windows path is unverified. |
| Windows Codex state schema 是否包含 `electron-avatar-overlay-open` | Needs Windows manual verification | Parser supports the key, but no Windows state sample was inspected. |
| Windows Codex state schema 是否包含 `electron-avatar-overlay-bounds` | Needs Windows manual verification | Parser supports the key, but no Windows state sample was inspected. |
| Windows Codex state schema 是否包含 `mascot` | Needs Windows manual verification | Parser supports `electron-avatar-overlay-bounds.mascot`, but no Windows state sample was inspected. |
| follow-codex 是否能读到真实 bounds | Needs Windows manual verification | Follow loop can consume parsed bounds, but Windows Codex source data is unverified. |
| Windows 坐标单位是物理像素还是逻辑像素 | Needs Windows manual verification | Current `coords.rs` assumes Codex bounds and Tauri monitor positions/sizes are physical coordinates, then converts to logical using monitor scale factor. Windows Codex unit semantics are unverified. |
| Windows 多屏和 mixed-DPI 下 Tauri monitor 数据是否符合当前 coords 假设 | Needs Windows manual verification | Unit tests cover synthetic mixed-DPI physical screens; real `available_monitors()` behavior on Windows needs validation. |
| local settings 路径是否合理 | Automated/source verified | `ProjectDirs::from("xyz", "codexpet", "CodexPet Nest")` is used first; non-macOS fallback is `<home>/.codexpet-nest`. Actual Windows resolved path should be inspected in app diagnostics. |
| local package import 是否可用 | Automated/source verified | Rust import path uses `PathBuf`, safe relative joins, JSON validation, and no macOS-only APIs. Actual Windows file dialog is not implemented; current text-input path requires manual Windows smoke. |
| opener URL action 是否可用 | Automated/source verified | `tauri-plugin-opener` is registered through capability `opener:default`; URL targets are allowlisted before `open_url`. Actual Windows browser handoff should be manually verified. |
| shell action 是否仍然禁用 | Automated/source verified | `shell_execution_enabled: false`, `shell-placeholder` returns an error, and default capability has no `shell:` permission. Release smoke now checks this. |
| release app 是否不依赖 dev server | Automated/source verified | `frontendDist` is `../dist`, `beforeBuildCommand` is `pnpm build`, and `devUrl` is only a dev setting. Release smoke checks this. |

## Source/automated findings

- `apps/desktop-tauri/src-tauri/src/platform/macos.rs` had a non-macOS click-through stub that logged a warning but returned `Ok(())`. That created a Windows risk where UI state could believe click-through succeeded. Phase 11 changed the Windows cfg path to return `Err("Windows click-through is not implemented yet")`.
- `apps/desktop-tauri/src-tauri/src/platform/windows.rs` previously described `%USERPROFILE%\.codex\.codex-global-state.json` too strongly as an expected path. Phase 11 changed the wording to `Potential Codex State Path (Windows, unverified)` and explicitly requires Windows Codex Desktop confirmation.
- `codex_state.rs` resolver supports `CODEX_HOME` first and then `dirs::home_dir().join(".codex")`. On Windows this should resolve under the user profile, but this only proves resolver behavior, not real Codex Desktop storage behavior.
- `codex_state.rs` parser supports `electron-avatar-overlay-open`, `electron-avatar-overlay-bounds`, and `mascot`, but only macOS samples have been validated historically. Windows schema remains unverified.
- `coords.rs` assumes screen `x/y/width/height` are physical coordinates and converts Codex physical bounds to display-relative logical coordinates via `screen.scale_factor`. Synthetic tests cover 1.0, 1.25, 1.5, Retina-like 2.0, negative-origin secondary screens, and clamping. Real Windows mixed-DPI semantics remain unverified.
- `windows/setup.rs` uses Tauri builder settings `.transparent(true)`, `.always_on_top(true)`, and `.skip_taskbar(true)` for the overlay window. Source supports intended behavior, but native Windows behavior is not verified.
- `tray/builder.rs` defines Show Overlay, Hide Overlay, Open Settings, and Quit menu paths through shared backend helpers. Source supports intended behavior, but Windows tray visibility/menu behavior is not verified.
- `commands/actions.rs` keeps shell execution disabled and uses the opener plugin only for allowlisted URL actions.
- `tauri.conf.json` uses `frontendDist` and `beforeBuildCommand` for release builds, so the release config does not depend on a dev server.

## Manual verification still needed

- Build on Windows with the normal Tauri release command and record exact artifact paths and artifact types.
- Launch the Windows app and confirm the settings window can open and reopen after close-to-hide.
- Confirm tray icon visibility and the Show Overlay / Hide Overlay / Open Settings / Quit menu items.
- Confirm transparent, frameless overlay behavior on Windows.
- Confirm `.always_on_top(true)` and `.skip_taskbar(true)` behavior across normal windows, fullscreen apps, virtual desktops if relevant, and taskbar state.
- Confirm the Windows UI surfaces the explicit click-through error instead of reporting success.
- Install/run Codex Desktop on Windows, locate the actual state path, and inspect a redacted state sample for `electron-avatar-overlay-open`, `electron-avatar-overlay-bounds`, and `mascot`.
- Confirm whether Windows Codex overlay bounds are physical pixels or logical pixels.
- Confirm Tauri `available_monitors()` positions/sizes/scale factors on Windows single monitor, multi-monitor, and mixed-DPI setups.
- Smoke test local settings persistence and local package import with Windows paths.
- Smoke test opener URL action with the default browser.

## Code changes made

- `apps/desktop-tauri/src-tauri/src/platform/macos.rs`: added a Windows-specific click-through error constant and changed the Windows `set_click_through` stub to return `Err("Windows click-through is not implemented yet")`.
- `apps/desktop-tauri/src-tauri/src/platform/macos.rs`: changed other non-macOS platforms to return an explicit unsupported error instead of false success.
- `apps/desktop-tauri/src-tauri/src/platform/windows.rs`: softened Windows Codex state path documentation from expected/assumed to unverified resolver fallback.
- `scripts/check-release-readiness.mjs`: added source-level smoke checks for Windows click-through being explicitly unimplemented, shell execution staying disabled, and shell capability absence.

## Tests added/updated

- Updated `pnpm qa:release-smoke` source-level smoke coverage. It now checks:
- Windows click-through is explicitly documented/implemented as an error path.
- `shell_execution_enabled` remains `false`.
- Tauri default capability does not grant `shell:` permissions.

No Windows-only Rust unit test was added because the Windows cfg implementation is not compiled on this macOS host. The source-level smoke check is the Phase 11 regression guard for this host.

## Validation command results

| Command | Result | Notes |
| --- | --- | --- |
| `pnpm qa:release-smoke` | Passed | 27 release/source checks passed, including Windows click-through explicit unsupported state and shell-disabled checks. |
| `pnpm typecheck` | Passed | Workspace TypeScript checks passed for core, renderer, and desktop. |
| `pnpm lint` | Passed | ESLint passed for core, renderer, and desktop. |
| `pnpm format:check` | Passed | All matched app/package TS/TSX/CSS/JSON files use Prettier style. |
| `pnpm test` | Passed | core 34, renderer 9, desktop 39; total 82 frontend/domain tests. |
| `cd apps/desktop-tauri/src-tauri && cargo fmt --all --check` | Passed after formatting | Initial check reported a line-wrap diff in `platform/macos.rs`; `cargo fmt --all` was run, then the check passed. |
| `cd apps/desktop-tauri/src-tauri && cargo clippy --all-targets -- -D warnings` | Passed | No warnings. |
| `cd apps/desktop-tauri/src-tauri && cargo test` | Passed | 28 lib tests, 0 main tests, 3 config integration tests, and 0 doc tests passed. |
| `pnpm tauri:build:app` | Passed on macOS | Produced `/Users/ryanniu/Documents/Project/codexpet-nest-next/apps/desktop-tauri/src-tauri/target/release/bundle/macos/CodexPet Nest.app`. This does not verify Windows bundle output. |

## Decision: can Phase 12 start?

Yes. Phase 12 can start as Windows parity implementation, but it should start with a Windows machine in the loop. Phase 11 found no reason to block Phase 12 from source/config review, and it closed the most misleading current behavior: Windows click-through no longer reports success from a stub.

Phase 12 must not assume Windows Codex state parity or coordinate-unit parity until manual evidence is collected.

## Phase 12 recommended implementation tasks

- Add a Windows test pass that records `pnpm tauri build` artifact types and paths.
- Implement Windows click-through with a small Win32 helper using `WS_EX_LAYERED` / `WS_EX_TRANSPARENT`, guarded by tests and manual validation.
- Add a Windows diagnostics command or Debug Panel row that prints resolved Codex home, state candidate paths, and monitor data for manual capture.
- Confirm real Windows Codex state path/schema and add parser fixtures from a redacted Windows sample if compatible.
- Confirm Windows coordinate units and adjust `coords.rs` if Codex state or Tauri monitors use logical units differently from the current physical-coordinate assumption.
- Validate overlay transparency, always-on-top, and skip-taskbar behavior on Windows 11.
- Validate Windows tray/menu behavior and polish Windows-specific tray click/menu affordances if needed.
- Validate local settings and local package import with Windows path edge cases.
- Decide Windows installer target policy: NSIS only, MSI only, or both, then document and automate artifact expectations.

## Explicit unresolved risks

- No Windows real-device validation was performed in Phase 11.
- Windows build and installer artifact output remain unverified.
- Windows app startup, settings window, tray, and overlay native behavior remain unverified.
- Windows click-through is explicitly not supported yet.
- Windows Codex Desktop state path and schema remain unverified.
- Windows follow-codex cannot be considered supported until real bounds can be read.
- Windows coordinate-unit semantics remain unverified.
- Windows multi-monitor and mixed-DPI behavior remains unverified.
- Windows opener handoff, local settings path, and local package import are source-verified only, not manually confirmed.
