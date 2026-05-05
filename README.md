# CodexPet Nest

CodexPet Nest is a macOS desktop companion app for [codexpet.xyz](https://codexpet.xyz). It shows a small nest overlay beside your active Codex Desktop pet, with built-in widgets for time, countdowns, and focus sessions.

## Important

- CodexPet Nest is independent from Codex / OpenAI unless an official partnership exists later.
- It **does not** patch Codex Desktop or modify its app bundle.
- It reads local Codex pet state **only** to follow the pet position.
- It **does not** upload prompts, sessions, repositories, or project files.
- It uploads a pet **only** after the user explicitly selects and confirms the package.
- It can be uninstalled completely.

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon (arm64) — Intel support coming later

## Features

- Transparent always-on-top nest overlay beside the Codex pet
- Clock widget — current time and date
- Countdown widget — set a target date/time
- Pomodoro widget — focus/break timer
- Menu bar app with quick actions
- Right-click menu on the nest
- Local settings persistence

## Install

Download the latest `CodexPetNest.dmg` from [codexpet.xyz/downloads](https://codexpet.xyz/downloads).

## Uninstall

1. Quit CodexPet Nest from the menu bar.
2. Delete `CodexPet Nest.app` from Applications.
3. Optionally remove `~/Library/Application Support/CodexPet Nest/`.

## Build from source

```bash
git clone https://github.com/RyanNiu/codexpet-nest.git
cd codexpet-nest
swift build -c release
```

## License

MIT — see [LICENSE](LICENSE).

## Privacy & Security

See [PRIVACY.md](PRIVACY.md), [SECURITY.md](SECURITY.md), and [docs/permissions.md](docs/permissions.md).
