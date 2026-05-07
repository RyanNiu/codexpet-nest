# Codex Pet Switching Research

Status: research complete.

Final Decision for v0.1: Keep switching guided. Do not automatically change the active Codex pet. External writes to Codex's state files are unsafe and unstable.

## What Was Observed

Codex Desktop stores the active pet choice in:

```text
~/.codex/.codex-global-state.json
```

Observed field:

```json
{
  "electron-persisted-atom-state": {
    "selected-avatar-id": "custom:bojji"
  }
}
```

The companion backup file currently mirrors the same value:

```text
~/.codex/.codex-global-state.json.bak
```

Observed local pet directory:

```text
~/.codex/pets/
  bojji/
    pet.json
    spritesheet.webp
  clippy/
    pet.json
    spritesheet.webp
  codie/
    pet.json
    spritesheet.webp
  finderguy/
    pet.json
    spritesheet.webp
```

Observed `pet.json` shape:

```json
{
  "id": "bojji",
  "displayName": "波吉",
  "description": "...",
  "spritesheetPath": "spritesheet.webp",
  "kind": "object"
}
```

For app-installed local pets, the likely selected id format is:

```text
custom:<pet-id>
```

Example:

```text
custom:bojji
```

## What This Means

CodexPet Nest can safely scan and install local pet packages under:

```text
${CODEX_HOME:-$HOME/.codex}/pets/<pet-id>/
```

CodexPet Nest can also show a useful post-install instruction:

```text
Installed successfully. Open Codex pet settings and choose this pet.
```

Codex's own UI updates:

```text
electron-persisted-atom-state.selected-avatar-id
```

Manual validation confirmed:

- Switching from Codex's own UI changed `custom:bojji` to `custom:clippy`.
- Codex updated both `.codex-global-state.json` and
  `.codex-global-state.json.bak`.

Manual validation also confirmed:

- An external backup-backed write from `custom:clippy` to `custom:bojji` did
  not change the live desktop pet.
- Restarting Codex still did not apply the externally written value.
- Codex later rewrote both files back to `custom:clippy`.

This means the JSON field is useful for read-only detection, but it is not a
safe or sufficient switching API.

Likely explanations:

- Codex keeps the active pet in memory and persists it back to disk.
- Codex may also store or validate the selected pet in another app state layer.
- Codex may only accept changes produced by its own UI actions.

Because the state file stores many unrelated Codex settings, automatic writes
must be treated as higher risk than normal package installation.

## Risk Assessment

Do not implement automatic switching in the MVP.

Main risks:

- The state file contains unrelated Codex UI and session state.
- A broad JSON rewrite could accidentally remove fields Codex expects.
- Codex may overwrite the change while running.
- Changing `.bak` without knowing its role could fight Codex's own persistence.
- If the selected pet id is invalid, Codex may fall back, hide the pet, or keep
  an inconsistent UI state.

## Recommended Sprint 2 Behavior (Implemented)

Implement Local Pet Manager with these actions:

- List installed pets from `${CODEX_HOME:-$HOME/.codex}/pets/`. (Implemented)
- Parse each `pet.json`. (Implemented)
- Show id, display name, description, and preview when available. (Implemented)
- Open pet folder in Finder. (Implemented)
- Install a local pet ZIP through the safe package installer. (Implemented)
- Uninstall app-managed pets with confirmation. (Implemented)
- Show current active pet as read-only when it can be detected. (Implemented)
- After install, guide the user to switch inside Codex. (Implemented)
- Do not expose a one-click switch button. (Implemented)

Current active pet detection:

```swift
let selected = globalState["electron-persisted-atom-state"]?
    ["selected-avatar-id"] as? String
```

For display:

- If selected id starts with `custom:`, strip the prefix and match the rest to
  a local pet folder.
- If selected id is missing, show `Unknown`.
- If selected id does not start with `custom:`, show it as a Codex-managed or
  built-in selection without trying to edit it.

## Experimental One-Click Switching Design

Do not implement this in the product yet.

The first external-write validation failed, so one-click switching should remain
blocked unless a future investigation finds a supported Codex command, URL
scheme, IPC path, or another stable integration point.

If future research finds a reliable integration point, the UI must be clearly
labeled as experimental during its first release:

```text
Switch in Codex (experimental)
```

Required safety rules:

- Mutate only `electron-persisted-atom-state.selected-avatar-id`.
- Preserve every other key in `.codex-global-state.json`.
- Use an atomic write:
  - read current JSON,
  - update the one field,
  - write to a temporary file in the same directory,
  - fsync where practical,
  - rename over the original file.
- Create a timestamped backup before writing:

```text
~/.codex/.codex-global-state.json.codexpet-backup-YYYYMMDD-HHMMSS
```

- Validate the target pet before writing:
  - directory exists,
  - `pet.json` exists,
  - `pet.json.id` matches the target id,
  - `spritesheetPath` exists and stays inside the pet directory.
- Never write `.bak` in the first implementation unless manual testing proves
  Codex requires it.
- If Codex is running, warn that a restart may be required.
- Provide a visible rollback command in the UI after a write.

Suggested internal API:

```swift
struct ActivePetSelection {
    let rawSelectedId: String?
    let customPetId: String?
}

enum PetSwitchMode {
    case guided
    case experimentalWrite
}

final class CodexPetSelectionStore {
    func readActivePet() throws -> ActivePetSelection
    func switchToCustomPet(id: String) throws
}
```

## Manual Validation Plan

Completed validation:

1. Read only `selected-avatar-id` from `.codex-global-state.json`.
2. Switched pet inside Codex Desktop's own UI.
3. Confirmed `selected-avatar-id` changed from `custom:bojji` to
   `custom:clippy`.
4. Confirmed `.bak` changed at the same time.
5. Made one controlled backup-backed external write from `custom:clippy` to
   `custom:bojji`.
6. Observed that the live desktop pet did not change.
7. Restarted Codex.
8. Observed that the live desktop pet still did not change.
9. Confirmed Codex rewrote both files back to `custom:clippy`.

Do not inspect or log the full global state file during this process. It may
contain unrelated user state.

## Implementation Prompt For Another AI

Use this prompt when assigning the Local Pet Manager work:

```text
Implement Local Pet Manager MVP for CodexPet Nest.

Important: do not implement automatic active-pet switching yet. Use
docs/codex-pet-switching-research.md as the source of truth.

Requirements:
- Scan ${CODEX_HOME:-$HOME/.codex}/pets/.
- Parse each pet.json.
- List installed pets with id, displayName, description, and preview if
  spritesheetPath exists.
- Detect the current active pet read-only from
  ~/.codex/.codex-global-state.json at
  electron-persisted-atom-state.selected-avatar-id.
- Treat custom:<pet-id> as a local custom pet reference.
- If the active id is non-custom or missing, display it as Unknown or
  Codex-managed; do not modify it.
- Add actions: Open in Finder, Install Local Pet ZIP, Uninstall app-managed pet
  with confirmation.
- After successful install, show a guided message telling the user to open Codex
  pet settings and choose the new pet.
- Do not add a Switch button.
- Do not write ~/.codex/.codex-global-state.json.
- Do not write ~/.codex/.codex-global-state.json.bak.
- Do not log the full global state file.

Acceptance:
- The app can list the local pets currently under ~/.codex/pets/.
- It highlights the current active custom pet when selected-avatar-id matches.
- Installing a valid pet package places it under ~/.codex/pets/<pet-id>/.
- A successful install does not silently switch the active Codex pet.
- Uninstall is confirmation-gated and only removes app-managed pets unless the
  user explicitly confirms a local unmanaged pet removal.
```
