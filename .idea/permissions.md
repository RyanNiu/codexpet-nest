# Permissions

## File access

| Path | Read | Write | Why |
| --- | --- | --- | --- |
| `~/.codex/.codex-global-state.json` | yes | **no** | Detect Codex pet open state, position, and active pet id. |
| `~/.codex/logs_2.sqlite`, `logs_1.sqlite` | yes | no | Read local usage rate limits. |
| `${CODEX_HOME:-$HOME/.codex}/pets/` | yes | yes | Install and remove pet packages. |
| `~/Library/Application Support/CodexPet Nest/` | yes | yes | Store app settings, installed nests, and logs. |
| Other paths | no | no | The app does not read or write any other files. |

## Network access

| Feature | Domain | Purpose | Status |
| --- | --- | --- | --- |
| Marketplace | `codexpet.xyz` | Browse and download pets/nests. | Implemented |
| Authentication | `codexpet.xyz` | Device-code OAuth flow for creators. | Implemented |

Network access is strictly limited to `codexpet.xyz`. No third-party tracking or telemetry is sent.

## Package Safety

CodexPet Nest implements a rigorous validation pipeline for all downloaded content.

**Allowed Contents:**
- JSON metadata (`codexpet-package.json`, `nest.json`, `pet.json`).
- Static image assets (`png`, `webp`).
- Documentation (`README.md`, `LICENSE`).

**Rejected Contents:**
- **Scripts**: `.js`, `.ts`, `.sh`, `.py`, etc.
- **Binaries**: `.exe`, `.dylib`, `.bin`, etc.
- **Unsafe Paths**: Path traversal (`../`) or absolute paths.
- **Links**: Symbolic links or hard links.
- **Hash Mismatch**: Any file failing the `sha256` integrity check.

## macOS permissions

CodexPet Nest is designed to be low-privilege:

- **NO** screen recording.
- **NO** accessibility access.
- **NO** full disk access.
- **NO** camera/microphone access.
- **NO** location services.

The app only requires:
- File access to the specific paths listed above.
- Keychain access for secure token storage.
- User notification permission (optional, for pomodoro/timers).
