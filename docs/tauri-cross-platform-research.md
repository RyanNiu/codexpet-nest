# Tauri Cross-Platform Research

Date: 2026-05-31

This note evaluates a Tauri + React + local-first sync direction for a future
cross-platform CodexPet Nest client. It separates confirmed facts from
implementation-time spikes so the migration can start with the riskiest unknowns.

## Summary

Tauri + React is viable for a cross-platform rewrite, but it is not a direct
port of the current Swift/AppKit app. The product model can be carried forward;
most UI and platform integration code must be rebuilt.

The largest unknown is not Tauri itself. It is whether Codex Desktop on Windows
exposes the same pet overlay state that the current macOS app reads from
`.codex-global-state.json`.

Recommended first milestone: build a small Tauri spike that only proves tray,
transparent always-on-top overlay, Codex pet state discovery, and coordinate
conversion on Windows and macOS.

## Current Project Findings

Confirmed from this repository:

- The current Swift package is macOS-only via `platforms: [.macOS(.v14)]`.
- The app depends on Sparkle for updates.
- The Makefile builds against AppKit, Security, Foundation, and Sparkle.
- The release flow creates a macOS `.app` and `.dmg`, signs with `codesign`, and
  uses macOS-only tools such as `xcrun`, `PlistBuddy`, and `hdiutil`.
- Pet following currently reads Codex state from
  `CodexHomeResolver.resolve()/.codex-global-state.json`.
- Pet bounds depend on these JSON keys:
  - `electron-avatar-overlay-open`
  - `electron-avatar-overlay-bounds`
  - `electron-avatar-overlay-bounds.mascot`
- Screen mapping is implemented with AppKit types such as `NSScreen`, `NSRect`,
  and `NSPoint`.
- Quick actions depend on macOS-specific mechanisms:
  - `NSWorkspace`
  - `/Applications/*.app`
  - `/usr/bin/shortcuts`
  - AppleScript / Terminal
- Settings and package data currently live under
  `~/Library/Application Support/CodexPet Nest`.

The practical result is that a cross-platform version should be treated as a new
desktop client sharing product behavior, package specs, API contracts, and sync
models, not as a line-by-line Swift port.

## External Research

Confirmed from official docs and product pages:

- OpenAI lists Codex as available on macOS and Windows.
- OpenAI's Codex app announcement states that the Codex app became available on
  Windows in the March 4, 2026 update.
- Tauri supports window customization, including transparent windows.
- Tauri window configuration includes options relevant to this product:
  `transparent`, `skipTaskbar`, `shadow`, theme options, and Windows-specific
  `windowClassname`.
- Tauri notes that transparent windows on macOS require the
  `macos-private-api` feature and are not App Store compatible.
- Tauri's updater supports platform-specific artifacts for Linux, macOS, and
  Windows, including MSI and NSIS update artifacts on Windows.
- Tauri's updater endpoint variables include `{{target}}` and `{{arch}}`, which
  fit multi-platform release metadata.
- Tauri has documented Windows signing support, including custom sign commands.

Useful references:

- OpenAI Codex product page: https://openai.com/codex/
- OpenAI Codex app announcement:
  https://openai.com/index/introducing-the-codex-app/
- Tauri window customization:
  https://v2.tauri.app/fr/learn/window-customization/
- Tauri configuration reference:
  https://v2.tauri.app/ko/reference/config/
- Tauri updater:
  https://v2.tauri.app/plugin/updater/
- Tauri Windows signing:
  https://v2.tauri.app/distribute/sign/windows/

## Feature Feasibility

| Feature | Status | Notes |
| --- | --- | --- |
| React settings UI | Confirmed feasible | Rewrite required. Existing AppKit UI is not reusable. |
| Tray / menu-bar app shell | Feasible | Tauri supports tray patterns, but macOS menu-bar and Windows tray UX should be designed separately. |
| Transparent overlay window | Feasible with risk | Tauri supports transparent windows. Click-through, hit testing, shadows, fullscreen behavior, and DPI need platform testing. |
| Always-on-top nest window | Feasible with risk | Needs validation across Windows virtual desktops, fullscreen apps, and multi-monitor setups. |
| Follow Codex pet position | Unconfirmed | Depends on Codex Desktop Windows writing compatible pet overlay state. This is the top spike. |
| Multi-monitor coordinate mapping | Feasible with risk | Current AppKit coordinate conversion must be replaced. Windows mixed-DPI is the critical case. |
| Local pet/nest package install | Feasible | Manifest, ZIP validation, hash checks, and file layout can be ported to Rust/TypeScript. |
| Built-in widgets | Feasible | Logic can be redesigned in React. Rendering must be rebuilt. |
| Marketplace browsing/install | Feasible | API client and package install flow can be ported. |
| Secure token storage | Feasible | Replace Keychain with platform credential storage. |
| Auto-update | Feasible | Replace Sparkle with Tauri updater. Release metadata and signing pipeline must be redesigned. |
| Quick actions | Partially portable | URL and app launch are portable. Shortcuts, AppleScript, and Terminal actions need platform-specific alternatives. |
| App Store distribution | Risky | Tauri transparent windows on macOS may require private API, which blocks Mac App Store acceptance. Direct download remains viable. |

## Implementation Spikes / Legacy Items

These should be tracked as implementation tasks because they cannot be fully
confirmed from public docs or the current macOS-only codebase.

1. Codex Windows pet state compatibility
   - Install Codex Desktop on Windows.
   - Locate `CODEX_HOME` and `.codex-global-state.json`, if present.
   - Verify whether avatar overlay keys match macOS.
   - Record sample JSON with private data removed.
   - Move forward only after pet bounds can be read reliably.

2. Tauri overlay proof
   - Create a frameless transparent window.
   - Set always-on-top and skip-taskbar behavior.
   - Toggle click-through vs interactive mode.
   - Test on Windows 11, macOS, and at least one mixed-DPI multi-monitor setup.

3. Coordinate conversion proof
   - Map Codex top-left overlay coordinates to Tauri physical/logical window
     coordinates.
   - Test 100%, 125%, 150%, and mixed monitor scale factors on Windows.
   - Test macOS Retina and non-primary monitor placement.

4. Platform credential storage
   - Pick the abstraction:
     - macOS Keychain
     - Windows Credential Manager
     - Linux Secret Service, if Linux is in scope
   - Verify install/update flows preserve tokens.

5. Auto-update and signing pipeline
   - Decide between NSIS and MSI for Windows.
   - Define Tauri updater metadata hosted by codexpet.xyz.
   - Add Windows signing and macOS notarization to CI.
   - Verify update from one signed version to the next.

6. Quick action portability
   - Split action kinds by platform.
   - Keep URL and app launch cross-platform.
   - Replace macOS Shortcuts/AppleScript with Windows-specific actions:
     PowerShell, ShellExecute, Windows Terminal, or URI schemes.
   - Avoid syncing absolute app paths across platforms.

7. Local-first sync conflict model
   - Define device IDs, record IDs, versions, and updated timestamps.
   - Start with last-write-wins for settings and widget config.
   - Add per-platform overrides for quick actions and local paths.
   - Avoid syncing raw Codex logs or sensitive prompt/session data.

## Suggested Target Architecture

```text
apps/
  desktop-tauri/
    src/                 React UI
    src-tauri/           Rust commands and platform integration
packages/
  core/                  package schemas, settings schemas, sync types
  renderer/              nest/widget rendering logic
  sync-client/           local-first sync queue and API client
crates/
  platform-macos/        Keychain, Codex state, screen/window helpers
  platform-windows/      Credential Manager, Codex state, Win32 helpers
server/
  sync-api/              user/device/settings/package metadata sync
```

## Recommended Roadmap

1. Proof phase, 3-5 days
   - Tauri tray.
   - Transparent overlay.
   - Codex state read on Windows.
   - Coordinate conversion sample.

2. MVP phase, 4-6 weeks
   - React settings window.
   - Nest overlay follows Codex pet when state is available.
   - Standalone fallback mode when state is unavailable.
   - Local package install and built-in widgets.
   - Basic marketplace install.

3. Sync phase, 2-4 weeks
   - Account/device model.
   - Local-first sync queue.
   - Settings, widget config, installed package metadata.
   - Platform-specific quick-action overrides.

4. Release phase, 1-2 weeks
   - Windows installer.
   - macOS bundle/notarization.
   - Tauri updater.
   - Migration from existing macOS app support directory.

## Decision

Proceed with Tauri + React only after the proof phase confirms Codex Windows pet
state and overlay behavior. If Codex Windows pet state is not accessible, keep
Tauri as the desktop framework but adjust the Windows product definition to
standalone nest/pet mode with optional manual positioning.
