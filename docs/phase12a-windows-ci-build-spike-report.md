# Phase 12A Windows CI Build Spike Report

Date: 2026-06-04

## Scope

Phase 12A narrows Windows work to CI/source build readiness only. There is still no Windows real machine in this environment, so this phase does not claim Windows GUI parity and does not implement complex Windows behavior.

Allowed Windows status after this phase:

- CI build verified, only after a real GitHub Actions Windows run passes.
- GUI not verified.
- Windows support still experimental.

This phase must not be read as Windows parity completed.

## Environment

| Field | Value |
| --- | --- |
| Host OS | macOS / Darwin 25.3.0 arm64 |
| Windows real machine available | No |
| GitHub Actions Windows runner available locally | No |
| Node | v22.16.0 |
| pnpm | 10.15.1 |
| Rust | rustc 1.96.0 (ac68faa20 2026-05-25) |
| Repo path | `/Users/ryanniu/Documents/Project/codexpet-nest-next` |

## What Changed

- Added `.github/workflows/windows-build.yml` for a Windows CI build spike.
- Updated `scripts/check-release-readiness.mjs` with source-level CI readiness checks for the Windows workflow.
- Added this report to document Windows CI/source status separately from Windows GUI parity.

No Win32 click-through implementation, Codex Windows state parser assumption, GUI behavior change, cloud sync, marketplace behavior, or large E2E framework was added.

## Windows CI Workflow Details

Workflow file: `.github/workflows/windows-build.yml`

Workflow runner and setup:

- `runs-on: windows-latest`
- `actions/checkout@v4`
- `actions/setup-node@v4` with Node 22, satisfying Node >= 20
- `pnpm/action-setup@v4` with pnpm 10
- `dtolnay/rust-toolchain@stable` with `rustfmt` and `clippy`
- `choco install nsis wixtoolset -y --no-progress`

The Windows bundle dependency setup is included because `tauri.conf.json` has `bundle.targets = "all"` and Windows bundles commonly require installer tooling such as NSIS and/or WiX. This is a CI dependency setup step only; it does not remove or weaken application functionality to make CI pass.

Workflow commands:

- `pnpm install --frozen-lockfile`
- `pnpm typecheck`
- `pnpm lint`
- `pnpm test`
- `cargo fmt --all --check` in `apps/desktop-tauri/src-tauri`
- `cargo clippy --all-targets -- -D warnings` in `apps/desktop-tauri/src-tauri`
- `cargo test` in `apps/desktop-tauri/src-tauri`
- `pnpm tauri:build`

## Windows CI Run Result

Status: CI dispatch blocked before execution.

Windows CI workflow exists in this local checkout, but it is not present on the GitHub default branch of the candidate remote repository inspected from this environment.

Candidate GitHub repository inspected: `RyanNiu/codexpet-nest`.

Remote workflow files on `main`:

- `release.yml`

Attempted dispatch command:

```sh
gh workflow run windows-build.yml -R RyanNiu/codexpet-nest --ref main
```

Observed result:

```text
HTTP 404: workflow windows-build.yml not found on the default branch (https://api.github.com/repos/RyanNiu/codexpet-nest/actions/workflows/windows-build.yml)
```

No GitHub Actions Windows run URL exists yet. Therefore Windows CI is not marked CI build verified.

Required unblocker before CI execution:

- Publish `.github/workflows/windows-build.yml` to the target GitHub repository default branch or provide the correct `owner/repo` that already contains it.
- Then trigger `workflow_dispatch` and record the real run URL.

Required next CI evidence:

- Workflow run URL.
- Pass/fail result for every workflow step.
- Any build failure summary and fix notes.
- Final status updated to either CI build verified or CI failed.

## Artifact Upload Status

Configured artifact upload: CI/source verified.

Artifact configuration:

- Artifact name: `codexpet-nest-windows-bundle`
- Artifact path: `apps/desktop-tauri/src-tauri/target/release/bundle/**`
- Upload condition: after successful `pnpm tauri:build`
- Missing files behavior: `if-no-files-found: error`

Actual artifact upload: CI dispatch blocked before execution.

Actual artifact files and paths: none yet, because no Windows run has executed.

Artifact upload success would only prove that Windows bundle files were produced and uploaded by CI. It would not prove that the Windows GUI launches, tray works, overlay renders correctly, transparency works, or click-through works.

## Local macOS Validation Results

| Command | Result | Notes |
| --- | --- | --- |
| `pnpm qa:release-smoke` | Passed on macOS | 32 release/source checks passed, including Windows CI source readiness, usable Windows Tauri build command, Windows click-through explicit unsupported, shell-disabled, and shell capability absence checks. |
| `pnpm typecheck` | Passed on macOS | Workspace TypeScript checks passed for core, renderer, and desktop. |
| `pnpm lint` | Passed on macOS | ESLint passed for core, renderer, and desktop. |
| `pnpm format:check` | Passed on macOS | All matched app/package TS/TSX/CSS/JSON files use Prettier style. |
| `pnpm test` | Passed on macOS | core 34, renderer 9, desktop 39; total 82 frontend/domain tests. |
| `cd apps/desktop-tauri/src-tauri && cargo fmt --all --check` | Passed on macOS | No formatting differences. |
| `cd apps/desktop-tauri/src-tauri && cargo clippy --all-targets -- -D warnings` | Passed on macOS | No warnings. |
| `cd apps/desktop-tauri/src-tauri && cargo test` | Passed on macOS | 28 lib tests, 0 main tests, 3 config integration tests, and 0 doc tests passed. |
| `pnpm tauri:build:app` | Passed on macOS | Produced `/Users/ryanniu/Documents/Project/codexpet-nest-next/apps/desktop-tauri/src-tauri/target/release/bundle/macos/CodexPet Nest.app`. This is not Windows artifact verification. |

## What Is Now CI/Source Verified

- `.github/workflows/windows-build.yml` exists.
- The workflow targets `windows-latest`.
- The workflow installs Node >= 20, pnpm 10.x, Rust stable, and Windows bundle tooling.
- The workflow includes TypeScript typecheck, lint, tests, Rust format check, Rust clippy with warnings denied, Rust tests, and `pnpm tauri:build`.
- The workflow is configured to upload `apps/desktop-tauri/src-tauri/target/release/bundle/**` as `codexpet-nest-windows-bundle` after a successful build.
- `pnpm qa:release-smoke` includes a source-level CI readiness check for the Windows workflow.
- Windows click-through remains explicit unsupported in source.
- Shell capability remains absent and shell execution remains disabled in source.

These are source-level checks. They do not prove a Windows build has passed until a real Windows CI run succeeds.

## What Remains GUI Not Verified

Status: Needs GUI verification.

- Windows app launch.
- Settings window open and reopen behavior.
- Tray icon visibility.
- Tray Show Overlay, Hide Overlay, Open Settings, and Quit behavior.
- Overlay visibility.
- Overlay transparency.
- Overlay always-on-top behavior.
- Overlay skip-taskbar behavior.
- Release overlay absence of debug red/yellow boxes.
- Active nest switching in a real Windows GUI session.
- Standalone fixed positioning and restore after relaunch.
- Overlay drag behavior.
- Quick action click behavior.
- Opener URL handoff to default browser.
- Runtime surfacing of the Windows click-through explicit unsupported error.

## What Remains Blocked

Status: Blocked.

- Windows GUI validation without a Windows real device or GUI session.
- Windows Codex Desktop state path and schema sampling.
- Windows `follow-codex` support evidence.
- Windows coordinate unit evidence for Codex bounds.
- Windows multi-monitor and mixed-DPI evidence.
- Real Windows installer launch/install/uninstall validation.
- Windows artifact path confirmation until GitHub Actions runs.
- Windows CI dispatch until `.github/workflows/windows-build.yml` exists on the target GitHub repository default branch.

Status: Not supported yet.

- Windows click-through.
- Windows `follow-codex` parity.

## Whether Phase 13 Can Proceed Without Windows GUI Evidence

Phase 13 can proceed only if its scope does not require Windows GUI evidence or Windows parity claims.

Allowed wording for Phase 13 planning:

- Windows support is experimental.
- Windows CI build status is pending until a Windows workflow run succeeds.
- Windows GUI needs verification.
- Windows click-through is not supported yet.

Phase 13 should not claim Windows parity completed, tray parity, overlay transparency parity, click-through parity, or `follow-codex` Windows support without real Windows GUI evidence.

## Follow-Up Instructions for Future Windows Real-Device Validation

1. Publish `.github/workflows/windows-build.yml` to the target GitHub repository default branch, or confirm the correct `owner/repo` where it already exists.
2. Trigger `.github/workflows/windows-build.yml` on GitHub Actions and record the workflow run URL.
3. Record pass/fail for each CI step and the final status as CI build verified or CI failed.
4. If CI passes, download `codexpet-nest-windows-bundle` and record exact artifact files and paths.
5. Install or launch the Windows artifact on a Windows 11 machine.
6. Validate settings window open/reopen, tray visibility, Show Overlay, Hide Overlay, Open Settings, and Quit.
7. Validate overlay visibility, transparency, always-on-top, skip-taskbar, release debug-boundary absence, drag, quick actions, and standalone restore.
8. Confirm click-through remains Not supported yet and that the app surfaces the explicit unsupported state rather than pretending success.
9. Install Codex Desktop on Windows and capture redacted state path/schema evidence before enabling or claiming `follow-codex` support.
10. Capture monitor data for 100%, 125% or 150%, and mixed-DPI multi-monitor setups before changing coordinate assumptions.
