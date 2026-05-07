# Architecture

## Stack

- Swift 6 + AppKit
- macOS 14+

## Modules

```
main.swift          Entry point, sets up NSApplication with accessory policy.

AppDelegate         Application lifecycle, initializes MenuBarController and NestOverlayWindow.

PetPositionReader   Reads Codex pet open state and bounds from
                    ~/.codex/.codex-global-state.json.
                    Tolerates missing fields — hides nest if state unreadable.

UsageLimitReader    Reads Codex usage rate limits from local logs:
                    ~/.codex/logs_2.sqlite (fallback to logs_1.sqlite).
                    Extracts embedded JSON from codex.rate_limits log events.

NestOverlayWindow   NSPanel subclass.
                    - Transparent, borderless, non-activating.
                    - Always on top (floating window level).
                    - Visible across spaces (stationary + fullScreenAuxiliary).
                    - Polls pet position at ~150ms.
                    - Computes nest frame from pet bounds using multi-display-aware
                      coordinate conversion.
                    - Handles right-click menu.

NestRenderer        NSView that draws the nest background (dark translucent rounded rect)
                    and hosts widget subviews.

NestWidgets         Built-in widgets:
                    - ClockWidget: current time (HH:mm) and date (MM/dd EEE).
                    - CountdownWidget: countdown to user-selected target date/time.
                    - PomodoroWidget: focus/break timer with start/pause/reset.
                    - UsageIndicatorWidget: circular indicators for short-window and weekly usage.

MenuBarController   Owns NSStatusItem in the menu bar.
                    Builds menu: show/hide, pet/nest markets, upload, settings, quit.

SettingsStore       Reads/writes ~/Library/Application Support/CodexPet Nest/settings.json.
                    Notifies observers on change.

SettingsWindowController  Settings window with controls for nest visibility, position,
                          theme, and pomodoro durations.

LocalPetManager     Scans and manages local Codex pets under
                    ${CODEX_HOME:-$HOME/.codex}/pets/.

LocalNestManager    Scans and manages local nest skins under
                    ~/Library/Application Support/CodexPet Nest/nests/.

PackageManager      Shared package pipeline for codexpet.pet and
                    codexpet.nest packages. Verifies sha256 and extracts safely.

NestRenderer        NSView that draws the nest. Supports both default rendering
                    and custom skin rendering (layers + widget slots) driven by nest.json.
```

## Data Flow

```
~/.codex/logs_2.sqlite
        |
        v
UsageLimitReader  ──►  UsageIndicatorWidget
                               ^
                               |
~/.codex/.codex-global-state.json
        |
        v
PetPositionReader  ──►  NestOverlayWindow  ──►  NestRenderer  ──►  Widgets
        |                       |
        |                       v
        |               SettingsStore  ──►  ~/Library/Application Support/CodexPet Nest/
        |
MenuBarController
        |
        v
   NSStatusItem
```

## Multi-Display Coordinate System

Codex stores pet bounds in top-left-based screen coordinates. macOS AppKit uses bottom-left-based coordinates.

1. Compute pet rect from top-left coordinates.
2. Find the display containing the pet center.
3. Convert to AppKit coordinates using `screen.frame.maxY - tlRect.maxY`.
4. Position nest overlay relative to pet frame, clamped inside the screen's visible frame.

`auto` placement evaluates `bottom`, `right`, `left`, `top` in priority order, scoring each by visible area ratio, overflow penalty, and pet intersection penalty.

## Ecosystem Architecture

CodexPet Nest should treat pets and nests as package types:

```text
codexpet.pet
codexpet.nest
future: codexpet.widget
```

The same high-level package flow should be reused:

```text
discover -> download -> verify sha256 -> safe extract -> validate -> install -> switch/apply
```

Pets install into the Codex runtime pet folder only after validation:

```text
${CODEX_HOME:-$HOME/.codex}/pets/<pet-id>/
```

Nests install into the app-managed library:

```text
~/Library/Application Support/CodexPet Nest/nests/<nest-id>/
```

Nest skin packages are static-only in v1. They can include JSON, preview images,
and static assets. They must not execute third-party code. Functionality comes
from built-in widgets such as `usage`, `clock`, `countdown`, and `pomodoro`.

See [product-roadmap.md](product-roadmap.md) for phased delivery.
