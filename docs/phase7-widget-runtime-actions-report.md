# Phase 7 Widget Runtime / Local Tool Actions MVP

## Scope

Phase 7 adds the first interactive widget runtime and safe local quick action path for the Tauri desktop overlay.

Implemented areas:

- Core widget/action configuration model in `@codexpet/core`.
- Default built-in widgets for clock, usage, and quick actions.
- Default built-in quick actions for docs URL, docs copy placeholder, Codex path placeholder, and disabled shell placeholder.
- Tauri safe action commands: `execute_quick_action`, `get_action_capabilities`, and `list_supported_actions`.
- Settings UI section for Widgets / Actions, including status, platform, confirmation requirement, and action enable toggles.
- Overlay runtime data display for clock, usage mock, action count, clickable quick actions, visible action result/error, and confirmation state.
- Tauri shell plugin/capability removal so Phase 7 grants no shell permission.

## Core Model

The settings schema is upgraded to version 3 and includes:

- Widget id.
- Widget type: `metric`, `action-list`, `status`.
- Enabled state.
- Slot binding.
- Optional metric binding.
- Optional action id binding.
- Platform compatibility.
- Quick action type: `url`, `app`, `shortcut`, `shell-placeholder`.
- Quick action target.
- `requireConfirm`.

The core validator normalizes widgets/actions, merges built-in entries, validates action references, disables unsupported-platform actions, and validates action targets against a small allowlist.

## Safe Action Commands

Tauri exposes:

- `get_action_capabilities`.
- `list_supported_actions`.
- `execute_quick_action`.

Allowed action behavior:

- `url`: opens only allowlisted URL prefixes through the opener plugin.
- `shortcut`: returns a safe placeholder result for allowlisted docs actions.
- `app`: returns a safe placeholder result for `codex-home` only.

Core and Rust use the same URL allowlist:

- `https://codexpet.xyz/`
- `http://localhost:`

Rejected behavior:

- `shell-placeholder` always returns an error.
- Disabled actions return an error.
- Unsupported platform actions return an error.
- Unknown action types return an error.
- Non-allowlisted URL, shortcut, or app/path targets return an error.

## Security Boundaries

Phase 7 intentionally does not implement arbitrary local execution.

- No arbitrary shell execution.
- No Tauri shell capability or shell plugin registration.
- No package script discovery or execution.
- Imported packages do not register dangerous actions into runtime execution.
- Action targets are validated before execution.
- Shell placeholder is visible only as disabled/mock state.
- Unsupported actions fail with explicit errors rather than panics.

## UI Runtime

Settings now shows:

- Current widgets and slots.
- Current actions.
- Action type.
- Platform compatibility.
- `requireConfirm`.
- Runtime support status through capabilities.
- Enable/disable toggles for supported built-in quick actions.

Overlay now shows:

- Runtime clock slot data.
- Mock usage data.
- Quick action count.
- Quick action buttons.
- Action result/error status.
- Confirmation state for actions with `requireConfirm`.

## Tests

Added or extended coverage for:

- Core widget/action validation.
- Unsupported platform action disabled behavior.
- Tauri validation for unsupported platform, shell placeholder, and non-allowlisted URL.
- Settings action display and toggle persistence.
- Overlay action click result display.
- Overlay require-confirm first-click behavior.

## Validation

Required validation commands for Phase 7:

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
