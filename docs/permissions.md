# Permissions

## File access

| Path | Read | Write | Why |
| --- | --- | --- | --- |
| `~/.codex/.codex-global-state.json` | yes | no | Detect Codex pet open state, position, and current active pet id. |
| `~/Library/Application Support/CodexPet Nest/settings.json` | yes | yes | Persist user preferences (nest position, theme, widget settings, active nest id). |
| `~/.codex/logs_2.sqlite`, `logs_1.sqlite` | yes | no | Read the latest usage rate limits from local logs. |
| `${CODEX_HOME:-$HOME/.codex}/pets/` | yes | yes | Install and remove pet packages (Phase 2+). |
| `~/Library/Application Support/CodexPet Nest/nests/` | yes | yes | Install and manage nest skin packages (Phase 4+). |
| `~/Library/Application Support/CodexPet Nest/library.json` | yes | yes | Track installed pets and nests. |
| Other paths | no | no | The app does not read or write any other files. |

## Network access

| Phase | Domain | Purpose |
| --- | --- | --- |
| Phase 1 | none | No network requests. |
| Phase 2+ | `codexpet.xyz` | Browse, download, upload. (Implemented) |

In Phase 2+, network access is limited to `codexpet.xyz` APIs. The app does not scrape third-party sites.

## Downloaded packages

Downloaded packages must be static data packages.

Allowed v1 contents:

- JSON metadata.
- Pet `pet.json`.
- Pet spritesheets.
- Nest `nest.json`.
- Static image assets.
- README/LICENSE text files.

Rejected v1 contents:

- Scripts.
- Binaries.
- Symlinks escaping the package root.
- Paths containing traversal such as `../`.
- Any package that fails `sha256` verification.

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
