# Privacy

CodexPet Nest is designed to be transparent about what it reads and sends.

## Local files read

| File | Reason |
| --- | --- |
| `~/.codex/.codex-global-state.json` | Detect whether the Codex pet is open and its position. Used only to follow the pet with the nest overlay. |
| `~/Library/Application Support/CodexPet Nest/settings.json` | App settings. Created and managed by the app itself. |

## Local files written

| File | Reason |
| --- | --- |
| `~/Library/Application Support/CodexPet Nest/settings.json` | Persist user preferences (nest position, theme, widget settings, timer state). |
| `~/Library/Application Support/CodexPet Nest/library.json` | Track installed pets and nests (Phase 2+). |
| `~/Library/Application Support/CodexPet Nest/logs/` | Application logs (Phase 2+). |

## Network

CodexPet Nest **does not** make network requests in Phase 1. The nest, widgets, and settings all work entirely offline.

Future phases will connect to `codexpet.xyz` for:
- Browsing pets and nests (read-only)
- Downloading and verifying packages
- Uploading user-created pet packages (explicit user action only)

## What CodexPet Nest does NOT do

- Read your source code, repositories, or project files.
- Read your Codex prompts, sessions, or conversation history.
- Read any files outside the paths listed above.
- Upload any file without explicit user confirmation.
- Store or transmit your passwords.
- Modify Codex Desktop or its app bundle.
