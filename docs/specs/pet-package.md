# Pet Package Spec

## Status

Draft v1. This spec is the contract between `codexpet.xyz` and the future `CodexPet Nest` desktop app.

The current Codex-compatible runtime package remains:

```text
pet.json
spritesheet.webp
```

The CodexPet distribution package adds metadata around those files so the website and desktop app can validate, search, install, update, and upload pets consistently.

## Package Layout

Recommended ZIP layout:

```text
<pet-id>/
  codexpet-package.json
  pet.json
  spritesheet.webp
  preview.png
  contact-sheet.png
  README.md
  LICENSE
```

Required:

```text
codexpet-package.json
pet.json
spritesheet.webp
preview.png
```

Optional:

```text
contact-sheet.png
README.md
LICENSE
```

## `codexpet-package.json`

Example:

```json
{
  "type": "codexpet.pet",
  "schemaVersion": "1.0",
  "id": "codie",
  "name": "Codie",
  "version": "1.0.0",
  "author": "CodexPet",
  "description": "A tiny coding companion.",
  "manifest": "pet.json",
  "spritesheet": "spritesheet.webp",
  "preview": "preview.png",
  "license": "MIT",
  "tags": ["robot", "developer", "pixel"]
}
```

Fields:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | string | yes | Must be `codexpet.pet`. |
| `schemaVersion` | string | yes | Spec version, starting at `1.0`. |
| `id` | string | yes | Stable lowercase id. Use `a-z`, `0-9`, and `-`. |
| `name` | string | yes | Human-readable pet name. |
| `version` | string | yes | Semver package version. |
| `author` | string | yes | Creator or publisher name. |
| `description` | string | yes | Short plain-language description. |
| `manifest` | string | yes | Relative path to `pet.json`. |
| `spritesheet` | string | yes | Relative path to the sprite image. |
| `preview` | string | yes | Relative path to preview image. |
| `license` | string | yes | SPDX-style license or custom label. |
| `tags` | string[] | no | Search/filter tags. |

## Validation

The website and desktop app should reject packages when:

- Required files are missing.
- `codexpet-package.json` is invalid JSON.
- `type` is not `codexpet.pet`.
- `id` contains unsafe path characters.
- `manifest`, `spritesheet`, or `preview` points outside the package folder.
- `pet.json` is missing required Codex fields.
- `spritesheet.webp` is unreadable or not transparent-capable.
- The package contains executable files in v1.

The desktop app should verify the package hash from the download API before installing.

## Codex Runtime Install Target

When local Codex pet installation is supported, install only the runtime files into:

```text
${CODEX_HOME:-$HOME/.codex}/pets/<pet-id>/
  pet.json
  spritesheet.webp
```

Keep the full package metadata in CodexPet Nest's own library:

```text
~/Library/Application Support/CodexPet Nest/pets/<pet-id>/
```
