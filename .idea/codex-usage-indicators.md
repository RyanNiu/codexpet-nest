# Codex Usage Indicators

## Goal

CodexPet Nest should support a usage indicator inspired by
[`codex-pet-limit-rings`](https://github.com/petergpt/codex-pet-limit-rings).

The indicator should show Codex usage-limit state beside or around the active
pet without patching Codex Desktop. It should be ambient, glanceable, and safe
when data is missing.

## Reference Project

Reference:

```text
https://github.com/petergpt/codex-pet-limit-rings
```

Useful ideas to study:

- Native macOS companion app.
- Transparent always-on-top overlay.
- Follows the active Codex pet from local Codex state.
- Draws short-window and weekly usage rings.
- Reads live usage first, then falls back to local Codex logs.
- Does not modify Codex Desktop.

CodexPet Nest should not reuse the `limit-rings` product name. If code is copied
or adapted, preserve the original MIT copyright notice where applicable.

## Data Sources

### Local Pet State

Read:

```text
${CODEX_HOME:-$HOME/.codex}/.codex-global-state.json
```

Useful fields:

| Field | Purpose |
| --- | --- |
| `electron-avatar-overlay-open` | Whether the Codex pet is open. |
| `electron-avatar-overlay-bounds` | Overall overlay bounds. |
| `electron-avatar-overlay-bounds.mascot.left` | Pet x offset inside overlay. |
| `electron-avatar-overlay-bounds.mascot.top` | Pet y offset inside overlay. |
| `electron-avatar-overlay-bounds.mascot.width` | Pet width. |
| `electron-avatar-overlay-bounds.mascot.height` | Pet height. |
| `electron-avatar-overlay-bounds.anchor` | Present in current state; do not rely on it for v1. |
| `electron-avatar-overlay-bounds.placement` | Present in current state; do not rely on it for v1. |
| `electron-avatar-overlay-bounds.tray` | Present in current state; do not rely on it for v1. |

Use pet state for positioning only.

### Cached Usage Logs

Read:

```text
${CODEX_HOME:-$HOME/.codex}/logs_2.sqlite
```

Fallback if `logs_2.sqlite` is unavailable:

```text
${CODEX_HOME:-$HOME/.codex}/logs_1.sqlite
```

Look for the newest log row containing:

```text
"type":"codex.rate_limits"
```

Extract the embedded JSON object and parse it defensively.

### Live Usage

Reference project uses:

```text
https://chatgpt.com/backend-api/wham/usage
```

with the local ChatGPT/Codex token from:

```text
${CODEX_HOME:-$HOME/.codex}/auth.json
```

Privacy recommendation for CodexPet Nest:

- V1 should default to cached local logs only.
- Live usage should be opt-in because it reads a local auth token and makes a
  network request.
- If live usage is added, document it clearly in `PRIVACY.md` and
  `docs/permissions.md`.

## Confirmed Usage Fields

The current local `codex.rate_limits` event shape contains:

```json
{
  "type": "codex.rate_limits",
  "plan_type": "plus",
  "rate_limits": {
    "allowed": true,
    "limit_reached": false,
    "primary": {
      "used_percent": 29,
      "window_minutes": 300,
      "reset_after_seconds": 7089,
      "reset_at": 1777998506
    },
    "secondary": {
      "used_percent": 11,
      "window_minutes": 10080,
      "reset_after_seconds": 576806,
      "reset_at": 1778568223
    }
  },
  "code_review_rate_limits": null,
  "additional_rate_limits": null,
  "credits": null,
  "promo": null
}
```

Treat this as observed behavior, not an official stable API.

## Metric Summary

| Metric | Meaning | UI Use |
| --- | --- | --- |
| `plan_type` | Current plan type, such as `plus`. | Tooltip/detail text. |
| `rate_limits.allowed` | Whether usage is currently allowed. | Green/red status. |
| `rate_limits.limit_reached` | Whether the limit is reached. | Critical warning. |
| `primary.used_percent` | Short-window used percentage. | Short-window ring. |
| `100 - primary.used_percent` | Short-window remaining percentage. | Main visible value. |
| `primary.window_minutes` | Short-window length. Current observed value: `300` minutes. | Label as `5h window`. |
| `primary.reset_after_seconds` | Seconds until short-window reset. | `Resets in 1h 58m`. |
| `primary.reset_at` | Absolute reset timestamp. | `Resets at 18:30`. |
| `secondary.used_percent` | Long-window used percentage. | Weekly ring. |
| `100 - secondary.used_percent` | Long-window remaining percentage. | Main visible value. |
| `secondary.window_minutes` | Long-window length. Current observed value: `10080` minutes. | Label as `7d window`. |
| `secondary.reset_after_seconds` | Seconds until long-window reset. | `Resets in 6d 16h`. |
| `secondary.reset_at` | Absolute reset timestamp. | `Resets on May 12`. |
| `additional_rate_limits` | Additional model/feature buckets when present. | Small dots/badges. |
| `code_review_rate_limits` | Code review-specific buckets when present. | Future indicator. |
| `credits` | Credit data when present. | Future detail only. |
| `promo` | Promo data when present. | Future detail only. |

## UI Recommendation

Default visible state:

```text
Short-window remaining percent
Long-window remaining percent
```

Hover or detail state:

```text
Plan: Plus
5h window: 71% left, resets in 1h 58m
7d window: 89% left, resets in 6d 16h
Source: Cached
```

Limit reached state:

```text
Codex limit reached
Resets at 18:30
```

Additional limits:

- If `additional_rate_limits` exists, render up to 8 small dots or badges.
- On hover/detail, show limit name and remaining percentage.
- If absent or null, hide the additional UI.

Recommended source labels:

```text
Cached
Live
Unavailable
```

The label should be visible in tooltip/detail UI so users know how fresh the
usage data is.

## Defensive Parsing Requirements

Implementation must tolerate:

- Missing log database.
- Missing `codex.rate_limits` events.
- Missing `primary` or `secondary` buckets.
- `primary_window` / `secondary_window` instead of `primary` / `secondary`.
- Missing `reset_after_seconds`.
- Missing `reset_at`.
- `additional_rate_limits` as `null`, array, or object depending on source.
- Unknown future fields.

Do not crash when data is missing. Show an unavailable or partial state.

## Implementation Brief For AI

Use this prompt for another AI implementing the indicator:

```text
Implement a Codex usage indicator for CodexPet Nest, inspired by
https://github.com/petergpt/codex-pet-limit-rings.

Do not patch Codex Desktop. Do not modify the native Codex pet context menu.
Do not request live usage or read ~/.codex/auth.json in the first version.

V1 must read cached usage only from ${CODEX_HOME:-$HOME/.codex}/logs_2.sqlite,
falling back to logs_1.sqlite if needed. Find the newest log row containing
"type":"codex.rate_limits", extract the embedded JSON object, and parse it
defensively.

Create a UsageLimitReader module that returns:
- planType
- source: cached/live/unavailable
- allowed
- limitReached
- primary bucket
- secondary bucket
- additional buckets when present
- observedAt

Each bucket should expose:
- usedPercent
- remainingPercent
- windowMinutes
- resetAfterSeconds
- resetAt
- displayName

Integrate this into the existing Nest overlay as a built-in optional widget or
indicator. The default UI should show short-window and long-window remaining
percentages. Hover/detail UI should show plan type, window labels, reset
countdowns, absolute reset times, and data source.

If limitReached is true or allowed is false, show a clear warning state.
If data is unavailable, hide the rings/indicator or show a subtle unavailable
state without blocking the rest of the nest.

Follow the existing trust boundary:
- no Codex app patching
- no prompt/session/project file reads
- no auth token reads in V1
- no network requests for usage in V1

Update README, PRIVACY.md, docs/permissions.md, and docs/architecture.md to
state that the indicator reads ~/.codex/logs_2.sqlite or logs_1.sqlite for the
latest codex.rate_limits event. Make clear that live usage is a future opt-in
feature, not enabled by default.

Add tests or a small fixture-based parser check for codex.rate_limits JSON,
including missing fields and null additional_rate_limits.
```

