# Permissions

## File access

| Path | Read | Write | Why |
| --- | --- | --- | --- |
| `~/.codex/.codex-global-state.json` | yes | no | Detect Codex pet open state and position. |
| `~/Library/Application Support/CodexPet Nest/` | yes | yes | App settings, library, cache, logs. |
| Other paths | no | no | The app does not read or write any other files. |

## Network access

| Phase | Domain | Purpose |
| --- | --- | --- |
| Phase 1 | none | No network requests. |
| Phase 2+ | `codexpet.xyz` | Browse, download, upload. |

In Phase 2+, network access is limited to `codexpet.xyz` APIs. The app does not scrape third-party sites.

## macOS permissions

CodexPet Nest does not request:

- Screen recording
- Accessibility
- Full disk access
- Camera or microphone
- Location services

The app requires:

- Standard application sandbox for file access within `~/Library/Application Support/`.
- Keychain access for authentication tokens (Phase 4+).
