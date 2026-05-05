# Security

## Package Verification

When package installation is implemented (Phase 3), CodexPet Nest will:

- Verify `sha256` hashes against metadata from `codexpet.xyz` before installing.
- Validate package manifests (`codexpet-package.json`) against published JSON schemas.
- Reject packages that contain executable files.
- Reject packages with path traversal attempts.

## Authentication

When upload is implemented (Phase 4), CodexPet Nest will:

- Use device-code OAuth flow — no passwords stored.
- Store tokens exclusively in macOS Keychain.
- Never store raw credentials in plaintext files.

## Local Security

- Settings and library data are stored under `~/Library/Application Support/CodexPet Nest/` with standard file permissions.
- The app does not run with elevated privileges.
- The app uses macOS sandbox-appropriate APIs.

## Reporting

Report security issues via GitHub issues or email. See the repository for current contact information.
