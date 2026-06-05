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

Status: CI build verified on GitHub Actions Windows runner.

Target GitHub repository: `RyanNiu/codexpet-nest`.

Default branch: `main`.

Merge evidence:

- PR: `https://github.com/RyanNiu/codexpet-nest/pull/4`
- Merge commit: `6827dd276c3d5489f19c7642216b9deddde00bc2`
- Remote workflows on `main` after merge: `Phase 0 CI`, `Windows CI Build Spike`

Manual dispatch command:

```sh
gh workflow run windows-build.yml -R RyanNiu/codexpet-nest --ref main
```

Primary Windows CI evidence:

- Run URL: `https://github.com/RyanNiu/codexpet-nest/actions/runs/26967785630`
- Job URL: `https://github.com/RyanNiu/codexpet-nest/actions/runs/26967785630/job/79574895798`
- Event: `workflow_dispatch`
- Branch: `main`
- Head SHA: `6827dd276c3d5489f19c7642216b9deddde00bc2`
- Workflow: `Windows CI Build Spike`
- Job: `windows-build`
- Result: success
- Started: `2026-06-04T17:18:45Z`
- Completed: `2026-06-04T17:30:51Z`

Step results from the `workflow_dispatch` run:

- `Set up job`: success
- `Checkout repository`: success
- `Set up Node.js`: success
- `Set up pnpm`: success
- `Set up Rust stable`: success
- `Set up Windows bundle dependencies`: success
- `Install frontend dependencies`: success
- `Typecheck`: success
- `Lint`: success
- `Test`: success
- `Rust format check`: success
- `Rust clippy`: success
- `Rust test`: success
- `Tauri build`: success
- `Upload Windows bundle artifacts`: success

Supplemental Windows CI evidence:

- PR Windows CI run after blocker fixes: `https://github.com/RyanNiu/codexpet-nest/actions/runs/26967021872` succeeded.
- PR Phase 0 CI run after blocker fixes: `https://github.com/RyanNiu/codexpet-nest/actions/runs/26967021874` succeeded.
- Earlier PR Windows CI run `https://github.com/RyanNiu/codexpet-nest/actions/runs/26965242218` failed at `Rust clippy` due to `clippy::empty-line-after-doc-comments` in `apps/desktop-tauri/src-tauri/src/platform/windows.rs`; fixed by converting the file-level Windows notes from doc comments to ordinary comments.
- Earlier PR Phase 0 CI runs failed due to missing Linux Tauri system dependencies and an unused test variable; fixed by adding Linux Tauri dependency installation to `.github/workflows/phase0-ci.yml` and asserting `data_dir` is non-empty in `apps/desktop-tauri/src-tauri/tests/config_tests.rs`.

This verifies that the Windows CI build pipeline runs and produces bundle artifacts on GitHub Actions. It does not verify Windows GUI launch or runtime behavior.

Final CI status: CI build verified. GUI remains not verified.

## Artifact Upload Status

Configured artifact upload: CI/source verified.

Artifact configuration:

- Artifact name: `codexpet-nest-windows-bundle`
- Artifact path: `apps/desktop-tauri/src-tauri/target/release/bundle/**`
- Upload condition: after successful `pnpm tauri:build`
- Missing files behavior: `if-no-files-found: error`

Actual artifact upload: passed on `main` workflow dispatch.

Artifact evidence:

- Artifact name: `codexpet-nest-windows-bundle`
- Artifact size: `3010334` bytes
- Artifact expired: `false`
- Artifact API archive URL: `https://api.github.com/repos/RyanNiu/codexpet-nest/actions/artifacts/7418515778/zip`
- Downloaded inspection directory: `/var/folders/p4/d_0f09d52xz1ttr2s96030h00000gn/T/opencode/codexpet-windows-artifact-26967785630`
- Downloaded artifact file: `/var/folders/p4/d_0f09d52xz1ttr2s96030h00000gn/T/opencode/codexpet-windows-artifact-26967785630/nsis/CodexPet Nest_0.1.12_x64-setup.exe`
- Downloaded artifact file: `/var/folders/p4/d_0f09d52xz1ttr2s96030h00000gn/T/opencode/codexpet-windows-artifact-26967785630/msi/CodexPet Nest_0.1.12_x64_en-US.msi`

Artifact upload success would only prove that Windows bundle files were produced and uploaded by CI. It would not prove that the Windows GUI launches, tray works, overlay renders correctly, transparency works, or click-through works.

## Local macOS Validation Results

| Command | Result | Notes |
| --- | --- | --- |
| `pnpm qa:release-smoke` | Passed on macOS | 36 release/source checks passed, including Windows CI source readiness, usable Windows Tauri build command, Windows click-through explicit unsupported, shell-disabled, and shell capability absence checks. |
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

These source-level checks are now supplemented by the successful GitHub Actions Windows run documented above; GUI/runtime behavior remains unverified.

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
- Windows artifact install/launch validation on a real Windows machine.

Status: Not supported yet.

- Windows click-through.
- Windows `follow-codex` parity.

## Whether Phase 13 Can Proceed Without Windows GUI Evidence

Phase 13 can proceed only if its scope does not require Windows GUI evidence or Windows parity claims.

Allowed wording for Phase 13 planning:

- Windows support is experimental.
- Windows CI build has passed on GitHub Actions and produced Windows bundle artifacts.
- Windows GUI needs verification.
- Windows click-through is not supported yet.

Phase 13 should not claim Windows parity completed, tray parity, overlay transparency parity, click-through parity, or `follow-codex` Windows support without real Windows GUI evidence.

## Follow-Up Instructions for Future Windows Real-Device Validation

1. Download `codexpet-nest-windows-bundle` from the successful Windows CI run or trigger a fresh `.github/workflows/windows-build.yml` run on `main` if a newer artifact is needed.
2. Record exact artifact files and paths before Windows installation.
3. Install or launch the Windows artifact on a Windows 11 machine.
4. Validate settings window open/reopen, tray visibility, Show Overlay, Hide Overlay, Open Settings, and Quit.
5. Validate overlay visibility, transparency, always-on-top, skip-taskbar, release debug-boundary absence, drag, quick actions, and standalone restore.
6. Confirm click-through remains Not supported yet and that the app surfaces the explicit unsupported state rather than pretending success.
7. Install Codex Desktop on Windows and capture redacted state path/schema evidence before enabling or claiming `follow-codex` support.
8. Capture monitor data for 100%, 125% or 150%, and mixed-DPI multi-monitor setups before changing coordinate assumptions.
