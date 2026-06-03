# Phase 12 Windows Parity Implementation Spike Report

Date: 2026-06-03

## Scope

Phase 12 was intended to move Windows support from source-level risk closure to real Windows evidence plus minimal parity fixes. The phase explicitly requires a Windows machine for build, launch, GUI, Codex state, click-through, and DPI validation.

This execution was performed on macOS, not Windows. Per the Phase 12 constraint, no complex Windows functionality was implemented. The phase is documented as blocked until a Windows real machine is available.

## Environment

| Field | Value |
| --- | --- |
| Host OS | macOS / Darwin 25.3.0 arm64 |
| Windows real machine available | No |
| Node | v22.16.0 |
| pnpm | 10.15.1 |
| Rust | rustc 1.96.0 (ac68faa20 2026-05-25) |
| Repo path | `/Users/ryanniu/Documents/Project/codexpet-nest-next` |

## Windows build result

Blocked. No Windows build was run because the current host is macOS. Running `pnpm tauri build` here would produce macOS artifacts, not Windows installer evidence.

Windows-required commands not run on this host:

- `pnpm install` on Windows
- `pnpm typecheck` on Windows
- `pnpm lint` on Windows
- `pnpm test` on Windows
- `cd apps/desktop-tauri/src-tauri && cargo fmt --all --check` on Windows
- `cd apps/desktop-tauri/src-tauri && cargo clippy --all-targets -- -D warnings` on Windows
- `cd apps/desktop-tauri/src-tauri && cargo test` on Windows
- `pnpm tauri build` on Windows

## Windows artifact paths

Blocked. No NSIS, MSI, `.exe`, `.msi`, or Windows bundle path was produced in this execution.

Source/config note only: `apps/desktop-tauri/src-tauri/tauri.conf.json` has `bundle.targets = "all"`, `bundle.windows.nsis = null`, and includes `icons/icon.ico`, but this is not Windows artifact verification.

## Windows GUI checklist

| Item | Status | Evidence / Notes |
| --- | --- | --- |
| app 能启动 | Blocked | Requires Windows release app launch. No Windows machine available. |
| settings window 能打开 | Blocked | Requires Windows GUI session. |
| settings close 后能 reopen | Blocked | Requires Windows GUI session and tray path. |
| tray icon 显示 | Blocked | Requires Windows system tray. |
| tray Show Overlay 可用 | Blocked | Requires Windows system tray and overlay window. |
| tray Hide Overlay 可用 | Blocked | Requires Windows system tray and overlay window. |
| tray Open Settings 可用 | Blocked | Requires Windows system tray and settings window. |
| tray Quit 可用 | Blocked | Requires Windows system tray. |
| overlay 可见 | Blocked | Requires Windows app launch. |
| overlay 透明 | Blocked | Requires Windows compositor/window validation. |
| overlay always-on-top | Blocked | Requires Windows z-order validation. |
| overlay skip taskbar | Blocked | Requires Windows taskbar validation. |
| overlay release 模式没有 debug 红框/黄框 | Blocked | Requires Windows release app launch. Source remains covered by release smoke on macOS. |
| active nest 能切换 | Blocked | Requires Windows GUI session. |
| standalone-fixed 能显示并恢复位置 | Blocked | Requires Windows GUI session and relaunch. |
| overlay 拖动是否可用 | Blocked | Requires native Windows drag validation. |
| quick actions 是否可点击 | Blocked | Requires Windows overlay interaction. |
| opener URL action 是否能打开默认浏览器 | Blocked | Requires Windows default browser handoff. |
| shell action 仍然禁用 | Blocked | Runtime Windows behavior not tested. Source remains covered by release smoke on macOS. |

## Click-through implementation result

Not supported yet.

No Win32 click-through helper was implemented because there is no Windows real machine to compile, run, and validate the behavior. The current code remains the Phase 11 safe failure path: on `target_os = "windows"`, `set_click_through` returns `Err("Windows click-through is not implemented yet")` instead of reporting false success.

Implementation remains blocked until a Windows machine can validate:

- HWND acquisition path from Tauri/WebView2.
- `GetWindowLongPtrW` / `SetWindowLongPtrW` behavior for extended styles.
- `WS_EX_LAYERED` and `WS_EX_TRANSPARENT` toggling.
- Whether disabling click-through should remove only `WS_EX_TRANSPARENT` or also adjust `WS_EX_LAYERED`.
- Settings transaction behavior in a live Windows app.

## Codex state sampling result

Blocked. No Windows Codex Desktop install was available, so no Windows state sample was collected.

Unverified items:

- `CODEX_HOME` on Windows.
- `%USERPROFILE%\.codex` existence.
- `.codex-global-state.json` existence.
- `.codex-global-state.json.bak` existence.
- SQLite state file existence.
- `electron-avatar-overlay-open` field.
- `electron-avatar-overlay-bounds` field.
- `electron-avatar-overlay-bounds.mascot` field.
- `electron-persisted-atom-state` field.

`follow-codex` on Windows remains blocked and must not be treated as supported. `standalone-fixed` remains the intended Windows fallback until Windows Codex state is proven.

## Monitor / DPI sampling result

Blocked. No Windows monitor or DPI data was collected.

Unverified scenarios:

- Single monitor 100%.
- Single monitor 125% or 150%.
- Multi-monitor mixed-DPI.
- Tauri `available_monitors()` values for `x`, `y`, `width`, `height`, `scale_factor`, and `is_primary` on Windows.
- `get_overlay_position` on Windows.
- Codex bounds units on Windows if Codex state is available.

No `coords.rs` changes were made because there is no Windows evidence that the current physical-coordinate assumption is wrong.

## Code changes made

No application code changes were made in Phase 12. This is intentional: Phase 12 requires Windows real-device evidence before implementing Win32 parity behavior.

## Tests added/updated

No tests were added or updated in Phase 12. Without Windows implementation or Windows samples, adding Windows parity tests would either be source-only duplication of Phase 11 or would risk encoding unverified assumptions.

## Validation command results

| Command | Result | Notes |
| --- | --- | --- |
| `pnpm qa:release-smoke` | Passed on macOS | 27 release/source checks passed. |
| `pnpm typecheck` | Passed on macOS | Workspace TypeScript checks passed for core, renderer, and desktop. |
| `pnpm lint` | Passed on macOS | ESLint passed for core, renderer, and desktop. |
| `pnpm format:check` | Passed on macOS | All matched app/package TS/TSX/CSS/JSON files use Prettier style. |
| `pnpm test` | Passed on macOS | core 34, renderer 9, desktop 39; total 82 frontend/domain tests. |
| `cd apps/desktop-tauri/src-tauri && cargo fmt --all --check` | Passed on macOS | No formatting differences. |
| `cd apps/desktop-tauri/src-tauri && cargo clippy --all-targets -- -D warnings` | Passed on macOS | No warnings. |
| `cd apps/desktop-tauri/src-tauri && cargo test` | Passed on macOS | 28 lib tests, 0 main tests, 3 config integration tests, and 0 doc tests passed. |
| `pnpm tauri build` on Windows | Blocked | Requires Windows machine. |
| `pnpm tauri:build:app` | Passed on macOS | Produced `/Users/ryanniu/Documents/Project/codexpet-nest-next/apps/desktop-tauri/src-tauri/target/release/bundle/macos/CodexPet Nest.app`. This is not Windows artifact verification. |

## What is now Verified on Windows

Nothing. No Windows machine was available, so no item is marked `Verified on Windows`.

## What failed on Windows

Nothing failed on Windows because no Windows command or GUI validation was run.

## What remains Not supported yet

- Windows click-through.
- Windows `follow-codex` parity until Codex state path/schema and coordinate units are proven.

## What remains Blocked

- Windows build and installer artifact verification.
- Windows app launch.
- Windows GUI checklist.
- Windows click-through implementation validation.
- Windows Codex state sampling.
- Windows monitor / DPI sampling.
- Windows opener default-browser handoff validation.

## Decision: can Windows parity continue?

Yes, but only on a Windows machine. This macOS-only execution cannot advance Windows parity beyond documenting the block. The next attempt should start directly on Windows and should not spend time on additional source-only speculation unless a Windows build failure requires a minimal source fix.

## Next phase recommendation

Repeat Phase 12 on Windows before moving to any Phase 13 work. The Windows run should prioritize:

- `pnpm install` and `pnpm tauri build` artifact capture.
- Release app launch and full GUI checklist.
- Win32 click-through helper implementation and validation.
- Codex Desktop state path/schema sampling with redacted evidence.
- Monitor/DPI diagnostics capture for 100%, 125% or 150%, and mixed-DPI if available.
