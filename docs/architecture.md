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

MenuBarController   Owns NSStatusItem in the menu bar.
                    Builds menu: show/hide, pet/nest markets, upload, settings, quit.

SettingsStore       Reads/writes ~/Library/Application Support/CodexPet Nest/settings.json.
                    Notifies observers on change.

SettingsWindowController  Settings window with controls for nest visibility, position,
                          theme, and pomodoro durations.
```

## Data Flow

```
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
