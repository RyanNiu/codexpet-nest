# Phase 14 Windows Real-Device GUI Validation Checklist

Date: 2026-06-05

## Scope

Phase 14 should validate the existing Windows CI artifact on a real Windows 11 GUI session. This checklist does not implement new features and must not be used to claim Windows parity until the checks are executed and recorded with evidence.

## Starting Evidence

- Windows CI run: `https://github.com/RyanNiu/codexpet-nest/actions/runs/26967785630`
- Windows CI job: `https://github.com/RyanNiu/codexpet-nest/actions/runs/26967785630/job/79574895798`
- Workflow: `Windows CI Build Spike`
- Branch: `main`
- Head SHA: `6827dd276c3d5489f19c7642216b9deddde00bc2`
- Result: success
- Artifact: `codexpet-nest-windows-bundle`

## Artifact Preparation

- Download `codexpet-nest-windows-bundle` from the successful Windows CI run.
- Record the downloaded archive path.
- Extract the archive.
- Record exact NSIS installer path before launch: `nsis/CodexPet Nest_0.1.12_x64-setup.exe`.
- Record exact MSI installer path before launch: `msi/CodexPet Nest_0.1.12_x64_en-US.msi`.

## Windows 11 Install And Launch

- Record Windows version, build number, display scale, monitor count, and whether the session is local or remote.
- Install or launch the NSIS installer.
- If needed, repeat install or launch with the MSI installer.
- Record whether the app launches without crash.
- Record whether uninstall/reinstall behavior needs separate follow-up.

## Settings And Tray

- Validate Settings window opens.
- Validate Settings window can close and reopen.
- Validate tray icon is visible.
- Validate tray `Show Overlay`.
- Validate tray `Hide Overlay`.
- Validate tray `Open Settings`.
- Validate tray `Quit`.

## Overlay Runtime

- Validate overlay is visible.
- Validate overlay transparency.
- Validate overlay always-on-top behavior.
- Validate overlay skip-taskbar behavior.
- Validate release overlay does not show debug red boxes or yellow boxes.
- Validate active nest switching in a real Windows GUI session.
- Validate standalone fixed position restore after relaunch.
- Validate overlay drag behavior.
- Validate quick actions.
- Validate opener URL handoff to the default browser.

## Unsupported And Unverified Windows Areas

- Confirm Windows click-through remains Not supported yet.
- Confirm the app surfaces the Windows click-through unsupported state correctly instead of pretending success.
- Install Codex Desktop on Windows before claiming `follow-codex` support.
- Capture redacted Codex Desktop Windows state path evidence.
- Capture redacted Codex Desktop Windows state schema evidence.
- Capture Codex bounds coordinate unit evidence.
- Capture 100% display scale data.
- Capture 125% or 150% display scale data.
- Capture mixed-DPI multi-monitor data.

## Exit Criteria

- Record pass/fail evidence for every checklist item above.
- Keep Windows support marked experimental until GUI/runtime evidence supports a narrower claim.
- Do not claim Windows parity completed, tray parity, overlay transparency parity, click-through parity, or `follow-codex` Windows support without real Windows GUI evidence.
