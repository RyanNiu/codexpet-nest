# Product Roadmap

## Product Direction

CodexPet Nest is evolving from a local companion overlay into the desktop client
for the CodexPet ecosystem.

The long-term product should support:

- A stable local nest beside the active Codex pet.
- Local pet management.
- Online pet browsing, download, install, and switching.
- Custom nest appearances built from safe static assets.
- Online nest browsing, download, install, and switching.
- Creator upload workflows for pets and nests.

The desktop app should remain non-invasive:

- Do not patch Codex Desktop.
- Do not modify Codex app bundles.
- Do not read prompts, sessions, repositories, or project files.
- Do not execute third-party code from downloaded pet or nest packages.

## Current Baseline

The current app already has the foundation for:

- Menu bar app.
- Transparent AppKit overlay.
- Codex pet position reading.
- Built-in clock, countdown, pomodoro, and usage indicator widgets.
- Local settings.
- Early API client.
- Early package manager.
- Keychain helper.

Known work before ecosystem features:

- Fix right-click menu feedback and localization.
- Fix multi-display coordinate conversion.
- Stabilize usage indicator rendering and parser behavior.
- Align privacy docs with actual network/file access.
- Harden package installation against unsafe zip paths and symlinks.

## Package Model

Use one package pipeline for multiple package types:

```text
codexpet.pet
codexpet.nest
future: codexpet.widget
```

All downloaded packages must be:

- Downloaded from trusted `codexpet.xyz` metadata.
- Verified with `sha256`.
- Extracted safely.
- Validated before install.
- Installed into the app-managed local library.

Local library target:

```text
~/Library/Application Support/CodexPet Nest/
  settings.json
  library.json
  pets/
  nests/
  cache/
  logs/
```

## Local Pet Manager

Goal: users can manage local Codex pets from CodexPet Nest.

Phase requirements:

- Scan:

```text
${CODEX_HOME:-$HOME/.codex}/pets/
```

- List installed pets.
- Read each pet's `pet.json`.
- Show name, description, id, and preview when available.
- Open the pet folder in Finder.
- Install a local pet ZIP.
- Uninstall a locally installed pet with confirmation.
- Keep app-managed metadata in `library.json`.

Switching pets is a separate risk area.

Research result:

```text
docs/codex-pet-switching-research.md
```

Current decision: ship guided switching first. Detect the active pet read-only,
but do not write Codex's active-pet state in Sprint 2. Manual validation showed
that external writes to the selected pet field are overwritten by Codex and do
not change the live desktop pet.

Before implementing one-click switching, verify:

- Where Codex stores the currently selected pet.
- Which local files change when the user switches pets in Codex.
- Whether Codex needs a restart or reload.
- Whether writing that state is safe and reversible.

If safe switching cannot be verified, ship guided installation first:

```text
Installed successfully. Open Codex settings and choose this pet.
```

## Online Pet Market

Goal: users can browse and install pets from `codexpet.xyz` inside CodexPet Nest.

Website API dependencies:

```text
GET /api/pets
GET /api/pets/:id
GET /api/pets/:id/download
```

Desktop requirements:

- Pet list UI.
- Search/filter.
- Pet detail with preview.
- Download progress.
- `sha256` verification.
- Safe extraction.
- Package validation.
- Install into local library.
- Install Codex runtime files into:

```text
${CODEX_HOME:-$HOME/.codex}/pets/<pet-id>/
```

- Uninstall/update support.
- Clear error states.

## Custom Nest Appearance

Goal: users can change the nest appearance with simple static packages, similar
to downloading and switching pets.

Do not allow third-party executable code in nest packages.

The first nest customization model should be:

```text
static assets + nest.json layout + built-in widget slots
```

User-created nest packages may include:

```text
nest.json
preview.png
assets/background.png
assets/frame.png
assets/badge.png
README.md
LICENSE
```

They must not include scripts, binaries, plugins, or arbitrary Swift/JS code.

### Nest Skin V1

Example:

```json
{
  "type": "codexpet.nest",
  "schemaVersion": "1.0",
  "id": "pixel-wood-nest",
  "name": "Pixel Wood Nest",
  "version": "1.0.0",
  "layout": {
    "size": { "width": 260, "height": 96 },
    "anchor": "bottom",
    "safePadding": 8,
    "slots": [
      {
        "id": "usage",
        "widget": "usage",
        "x": 16,
        "y": 12,
        "width": 64,
        "height": 64
      },
      {
        "id": "clock",
        "widget": "clock",
        "x": 92,
        "y": 18,
        "width": 120,
        "height": 28
      }
    ]
  },
  "assets": {
    "background": "assets/background.png",
    "preview": "preview.png"
  }
}
```

Built-in widgets available to slots:

```text
usage
clock
countdown
pomodoro
text
```

Start with `usage` as the first fully supported functional slot.

Renderer direction:

- Replace the current fixed horizontal widget layout with a layout-driven renderer.
- Draw static background assets first.
- Place widget views by slot rect.
- Clamp or reject slots outside the declared nest size.
- Hide unsupported widgets instead of crashing.

## Online Nest Market

Goal: users can browse, install, and switch nest skins from `codexpet.xyz`.

Website API dependencies:

```text
GET /api/nests
GET /api/nests/:id
GET /api/nests/:id/download
```

Desktop requirements:

- Nest list UI.
- Preview.
- Download progress.
- `sha256` verification.
- Safe extraction.
- Nest package validation.
- Install into:

```text
~/Library/Application Support/CodexPet Nest/nests/<nest-id>/
```

- Switch active nest from settings or market detail.
- Store active nest id in `settings.json`.

## Upload Workflows

Upload should come after local install/switch flows are stable.

Pet upload:

- Select local pet package.
- Validate package.
- Generate or select preview.
- Collect metadata.
- Login only when upload starts.
- Upload to `codexpet.xyz`.
- Show review status.

Nest upload:

- Select local nest package.
- Validate static-only contents.
- Validate `nest.json`.
- Validate slot bounds and asset references.
- Generate or select preview.
- Collect metadata.
- Login only when upload starts.
- Upload to `codexpet.xyz`.
- Show review status.

## Delivery Rhythm

### Sprint 1: Stabilize Local Nest

Acceptance criteria:

- Right-click menu actions have visible feedback.
- Menu labels are real text, not localization keys.
- Multi-display positioning is stable.
- Usage indicator can be shown/hidden and displays cached data.
- Privacy and permissions docs match actual behavior.
- Package extraction rejects unsafe paths.

### Sprint 2: Local Pet Manager MVP (Delivered)

Acceptance criteria:

- App scans `~/.codex/pets/`. (Done)
- App lists installed pets. (Done)
- App can open pet folders. (Done)
- App can install a local pet ZIP with security verification. (Done)
- App can uninstall with confirmation. (Done)
- Switching-current-pet behavior is documented as guided. (Done)
- Security: SafeZipReader used for safe extraction, rejecting symlinks/path traversal/executables. (Done)

### Sprint 3: Online Pet Install (Delivered)

Acceptance criteria:

- App lists pets from `codexpet.xyz`. (Done)
- App shows detail and preview. (Done)
- App downloads and verifies packages with SHA256. (Done)
- App installs pets locally into the Codex pet folder via SafeZipReader. (Done)
- App handles loading, empty, and error states. (Done)

### Sprint 4: Local Nest Skin V1 (Delivered)

Acceptance criteria:

- App can install a local nest ZIP. (Done)
- `nest.json` drives size, background, and widget slots. (Done)
- Usage slot renders in a custom skin. (Done)
- App can switch active nest. (Done)
- Invalid nest packages are rejected with clear errors. (Done)

### Sprint 5: Online Nest Market And Upload (In Progress)

Acceptance criteria:

- Define official nest package specification. (Done: docs/specs/nest-package.md)
- App lists nests from `codexpet.xyz`.
- App installs and switches online nest packages.
- Website supports nest upload and validation.
- App supports upload after explicit login.

## Implementation Prompt

Use this prompt for another AI implementing the next stage:

```text
CodexPet Nest should evolve into the desktop client for the CodexPet ecosystem.
Do not jump directly to upload or arbitrary plugin support.

First stabilize the local nest: fix right-click feedback, localization labels,
multi-display positioning, usage indicator visibility, privacy docs, and safe
zip extraction.

Then implement Local Pet Manager MVP:
- scan ${CODEX_HOME:-$HOME/.codex}/pets/
- list installed pets
- read pet.json
- open pet folder
- install local pet zip
- uninstall with confirmation
- investigate and document whether current-pet switching can be safely automated

Next implement Online Pet Market using codexpet.xyz APIs and sha256-verified
downloads.

After pet management is stable, implement Nest Skin V1. Nest packages must be
static-only: nest.json + images + metadata, no executable code. The renderer
should read nest.json, draw static assets, and place built-in widget slots.
Start with usage as the first fully supported slot.

Keep all package installation safe:
- verify sha256
- reject path traversal
- reject symlink escape
- reject scripts/binaries in v1 nest packages
- validate before installing

Keep the trust boundary:
- do not patch Codex
- do not read prompts, sessions, repositories, or project files
- login only when upload or future account-specific actions require it
```
