# macOS Release Signing and Notarization

CodexPet Nest macOS releases must be signed with a **Developer ID Application**
certificate and notarized by Apple. An ad-hoc signature (`codesign --sign -`) is
valid only for local builds. When an ad-hoc-signed app is downloaded from a
browser, macOS quarantine can prevent it from reaching application startup.

The tag-triggered workflow in `.github/workflows/macos-release.yml` builds the
Tauri app and DMG, then verifies code signing, Gatekeeper assessment, and the
stapled notarization tickets before uploading the DMG to GitHub Releases.

## Required repository secrets

Configure these GitHub Actions secrets before pushing a `v*` tag:

| Secret                       | Value                                                   |
| ---------------------------- | ------------------------------------------------------- |
| `APPLE_CERTIFICATE`          | Base64-encoded Developer ID Application `.p12` file     |
| `APPLE_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12`                 |
| `KEYCHAIN_PASSWORD`          | Random password used only for the temporary CI keychain |
| `APPLE_ID`                   | Apple ID used for notarization                          |
| `APPLE_PASSWORD`             | App-specific password for that Apple ID                 |
| `APPLE_TEAM_ID`              | Ten-character Apple Developer team ID                   |

Export the certificate and encode it without writing the encoded value to the
repository:

```bash
base64 -i developer-id-application.p12 | pbcopy
```

Create an app-specific password at `appleid.apple.com`. The workflow passes
`APPLE_ID`, `APPLE_PASSWORD`, and `APPLE_TEAM_ID` to Tauri, which submits the
bundles to Apple's notary service during the release build.

## Release verification

Push the version commit first, then push only its tag:

```bash
git push origin main
git push origin v0.1.13
```

The workflow fails before publishing unless all of the following succeed:

```bash
codesign --verify --deep --strict --verbose=2 "CodexPet Nest.app"
spctl --assess --type execute --verbose=4 "CodexPet Nest.app"
xcrun stapler validate "CodexPet Nest.app"
xcrun stapler validate "CodexPet Nest.dmg"
spctl --assess --type open --context context:primary-signature --verbose=4 "CodexPet Nest.dmg"
```

Pull-request CI continues to use an unsigned `.app` build as a compilation
smoke test. Unsigned CI artifacts must not be published to end users.
