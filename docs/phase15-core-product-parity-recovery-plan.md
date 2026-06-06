# Phase 15 Core Product Parity Recovery Plan

Date: 2026-06-06

## Why This Phase Exists

当前 Tauri 迁移版已经完成了一批工程基础设施工作，包括 Tauri app shell、nest overlay MVP、本地 registry、local snapshot、release smoke、Windows CI artifact 产出等。

但这些工作还没有恢复原 Swift/AppKit 项目 `/Users/ryanniu/Documents/Project/codexpet-nest` 的核心产品体验。当前版本不能被视为完整迁移版，因为最基础的用户价值仍缺失或只停留在 MVP/fixture 级别：

- 宠物没有作为核心界面对象展示。
- 没有 standalone pet window。
- 没有宠物 spritesheet 动画播放。
- 没有本地宠物管理体验。
- 没有官方宠物市场体验。
- 没有 Petdex / 第三方宠物安装闭环。
- 小窝显示仍偏 fixture/MVP，不是完整 package renderer。
- 小窝市场和完整小窝管理没有恢复。
- Settings 还没有覆盖原项目的信息架构和主要入口。

因此，Phase 15 的目标是把项目从“迁移骨架 + 工程验证”拉回到“核心产品功能迁移”。在 Phase 15 完成前，不应继续把项目描述为接近最终完成，也不应优先推进 Windows parity 声明。

## Relationship To Phase 14

`docs/phase14-windows-real-device-gui-validation-checklist.md` 继续保留，但 Phase 14 的完整执行应后移。

原因：

- Windows CI 已经通过并产出 artifacts。
- 但当前产品核心功能缺失，即使 Windows artifact 能启动，也无法证明产品迁移完成。
- Windows 实机验证仍有价值，但应验证一个已经具备核心产品体验的 build。

新的顺序建议：

1. Phase 15: 恢复核心产品功能 parity。
2. Phase 16: macOS production product QA。
3. Phase 17: Windows real-device GUI validation。
4. Phase 18: Windows-specific fixes, if needed。
5. Phase 19: release signing/updater/distribution。

## Source Of Truth

实现方必须以原 Swift/AppKit 项目为功能基准：

- Original project: `/Users/ryanniu/Documents/Project/codexpet-nest`
- Tauri migration project: `/Users/ryanniu/Documents/Project/codexpet-nest-next`

核心原项目模块包括但不限于：

- `Sources/CodexPetNest/StandalonePetWindow.swift`
- `Sources/CodexPetNest/PetRuntimeCoordinator.swift`
- `Sources/CodexPetNest/PetSpriteSheetRenderer.swift`
- `Sources/CodexPetNest/PetAnimationPlayer.swift`
- `Sources/CodexPetNest/LocalPetManager.swift`
- `Sources/CodexPetNest/LocalPetManagerViewController.swift`
- `Sources/CodexPetNest/OnlinePetMarketplaceViewController.swift`
- `Sources/CodexPetNest/PetMarketplaceProvider.swift`
- `Sources/CodexPetNest/CodexPetAPI.swift`
- `Sources/CodexPetNest/PackageManager.swift`
- `Sources/CodexPetNest/SafeZipReader.swift`
- `Sources/CodexPetNest/NestOverlayWindow.swift`
- `Sources/CodexPetNest/NestRenderer.swift`
- `Sources/CodexPetNest/NestUI.swift`
- `Sources/CodexPetNest/OfficialComponentRenderer.swift`
- `Sources/CodexPetNest/LocalNestManager.swift`
- `Sources/CodexPetNest/LocalNestManagerViewController.swift`
- `Sources/CodexPetNest/OnlineNestMarketplaceWindowController.swift`
- `Sources/CodexPetNest/SettingsStore.swift`
- `Sources/CodexPetNest/I18n.swift`

每个迁移任务必须写明：

- 原 Swift 模块。
- 新 Tauri/React/Rust 模块。
- 功能差距。
- macOS 支持状态。
- Windows 支持状态。
- 自动化测试。
- 手动验证证据。

## Product Boundaries

Phase 15 不改变以下边界：

- 不修改、不注入 Codex Desktop app bundle。
- 不写入 Codex global state。
- 不自动切换 Codex 当前 active pet。
- 安装宠物后，仍提示用户去 Codex 设置中手动选择。
- 不上传 prompts、sessions、仓库代码、项目文件或 Codex 原始日志。
- 第三方 package 必须本地校验，不能执行脚本。
- Shell/terminal 类 quick action 继续默认禁用，除非未来有明确安全设计和用户确认流程。

## Platform Requirement

Phase 15 必须同时面向 macOS 和 Windows 设计，不允许只实现 macOS happy path。

最低要求：

- 所有新 TypeScript/Rust 代码必须能在 macOS 和 Windows CI 上构建。
- 文件路径必须使用跨平台路径处理，不硬编码 `/Users`, `/tmp`, `~/Library`, `%USERPROFILE%` 等路径作为唯一实现。
- 本地数据目录必须通过现有 app config / platform dirs 路径获取。
- GUI 行为必须记录 macOS 和 Windows 的状态差异。
- 如果某项功能暂时无法在 Windows 完整支持，必须明确显示 `Unsupported` 或 `Unverified`，不能假装成功。
- 新增功能不能破坏 `pnpm qa:release-smoke` 和 Windows CI build。

## Phase 15 Goals

Phase 15 的完成标准不是“文档更新”或“CI 通过”，而是恢复用户能感知的核心产品功能：

1. 用户能看到宠物。
2. 用户能看到宠物动画。
3. 用户能管理本地宠物。
4. 用户能浏览并安装官方宠物。
5. 用户能浏览并安装 Petdex / 第三方宠物，并看到第三方风险提示。
6. 用户能看到真实小窝，而不是 debug fixture。
7. 用户能管理本地小窝。
8. 用户能浏览小窝市场或看到明确 Coming Soon 状态。
9. 用户能在 Settings 中找到宠物、小窝、市场、本地包、overlay、diagnostics 的主要入口。
10. macOS 和 Windows 的支持状态都被明确记录。

## Workstream A: Product Parity Gap Audit

### Scope

先做一份差距审计，不直接写大功能。

新增文档：

- `docs/phase15-core-product-parity-gap-report.md`

### Required Audit Table

文档必须包含表格：

| Original capability | Original Swift module | Current Tauri status | macOS status | Windows status | Required next work |
| --- | --- | --- | --- | --- | --- |

至少覆盖：

- Standalone pet window。
- Pet spritesheet rendering。
- Pet animation playback。
- Local pet scan。
- Local pet ZIP install。
- App-managed pet uninstall。
- Active Codex pet read-only marker。
- Official pet marketplace browse。
- Official pet download metadata。
- Official pet SHA256 validation。
- Petdex browse。
- Petdex HTTPS / allowed host validation。
- Petdex manifest inspect before install。
- Nest renderer parity。
- Built-in four nests。
- Local nest manager。
- Online nest marketplace。
- Package install cleanup on failure。
- Package validation: missing manifest, path traversal, unsafe type, sha mismatch, id mismatch。
- Settings information architecture。
- i18n English / Simplified Chinese。

### Acceptance

- Gap report exists.
- Every core original module has a mapped Tauri target or explicit missing state.
- No item is marked complete without code location and test/manual evidence.

## Workstream B: Pet Runtime MVP

### Goal

恢复宠物显示，这是最优先的用户可见功能。

### Original Modules

- `StandalonePetWindow.swift`
- `PetRuntimeCoordinator.swift`
- `PetSpriteSheetRenderer.swift`
- `PetAnimationPlayer.swift`
- `PetBehaviorEngine.swift`
- `PetImageCache.swift`
- `SettingsStore.swift`

### Tauri Target

Suggested new areas:

- `packages/renderer/src/pet/`
- `packages/core/src/pet-package/` or extend `package-schema`
- `apps/desktop-tauri/src/components/pet/`
- `apps/desktop-tauri/src/components/overlay/PetOverlayView.tsx`
- Rust commands for local pet asset loading if direct file URLs are insufficient or unsafe.

### Requirements

- Render a pet spritesheet or static preview in the desktop app.
- Support common Codex pet atlas layout, including 8x9 atlas where applicable.
- Support manifest-driven frame width/height, rows, columns, and animations.
- Play at least idle animation.
- Provide fallback static first frame when animation metadata is missing.
- Support transparent background.
- Persist selected standalone pet id.
- Persist standalone pet position.
- Do not auto-switch Codex Desktop active pet.

### macOS Requirements

- Pet window/overlay can be shown from menu-bar or Settings.
- Window is transparent where supported.
- Window can be always-on-top.
- Dragging works in interactive mode.
- Click-through behavior follows existing macOS native path if enabled.

### Windows Requirements

- Pet window/overlay can be shown from tray or Settings.
- Window builds and launches in Windows CI artifact.
- If native click-through is not implemented, show clear unsupported state.
- Do not block pet display on unsupported click-through.
- Position persistence must use platform-independent settings.

### Tests

- Unit tests for pet manifest parsing.
- Renderer tests for frame selection.
- Renderer tests for animation step progression.
- React tests for pet visible, fallback preview, missing image fallback.
- Settings tests for selecting active standalone pet.

### Manual Verification

- macOS release app shows pet without debug labels.
- Windows artifact shows pet without debug labels.
- Pet remains visible after app restart.

## Workstream C: Local Pet Management

### Goal

恢复原项目本地宠物管理能力。

### Original Modules

- `LocalPetManager.swift`
- `LocalPetManagerViewController.swift`
- `PackageManager.swift`
- `SafeZipReader.swift`
- `PetSpriteSheetRenderer.swift`

### Requirements

- Scan Nest internal pets.
- Scan Codex pets directory.
- De-duplicate pets, preferring app-managed/internal versions where appropriate.
- Show display name, description, preview/spritesheet, current active marker, managed marker.
- Install local pet ZIP.
- Validate package before install.
- Reject path traversal.
- Reject unsafe file types.
- Reject missing manifest.
- Uninstall only app-managed pets.
- Open pet folder location.
- Refresh list.
- After install, do not auto-switch Codex active pet.
- Show instruction to choose the pet in Codex settings manually.

### macOS Requirements

- Resolve default Codex home and pet directory.
- Open folder in Finder.
- Handle spaces and non-ASCII paths.

### Windows Requirements

- Resolve default Codex home and pet directory without assuming macOS paths.
- Open folder in Explorer.
- Handle backslashes, drive letters, spaces, and non-ASCII paths.

### Tests

- Valid local pet package install.
- Missing manifest.
- Path traversal.
- Unsafe file type.
- Duplicate pet ids.
- App-managed uninstall only.

## Workstream D: Pet Marketplace

### Goal

恢复官方宠物市场和 Petdex 第三方宠物市场的基本闭环。

### Original Modules

- `CodexPetAPI.swift`
- `PetMarketplaceProvider.swift`
- `OnlinePetMarketplaceViewController.swift`
- `PackageManager.swift`
- `SafeZipReader.swift`

### Requirements

- Browse official codexpet.xyz pets.
- Browse Petdex / third-party pets.
- Show official vs third-party source clearly.
- Fetch download metadata.
- Require HTTPS downloads for remote packages.
- Validate allowed hosts.
- Validate SHA256 for official downloads.
- Inspect manifest before install.
- Prevent id mismatch between inspected metadata and downloaded content.
- Show installed state.
- Show download/install errors.
- Support offline/marketplace unavailable state.

### macOS Requirements

- Install downloaded pet into app-controlled data directory.
- Open installed package location in Finder.

### Windows Requirements

- Same install behavior under Windows app data directory.
- Open installed package location in Explorer.
- No reliance on `/tmp`, `/usr/bin`, or shell commands.

### Tests

- API client mock tests.
- Official successful install.
- Official SHA mismatch.
- Petdex non-HTTPS rejection.
- Petdex disallowed host rejection.
- Manifest id mismatch rejection.
- Offline state.

## Workstream E: Nest Runtime Parity

### Goal

让小窝显示从 fixture/MVP 变成真实 package renderer。

### Original Modules

- `NestOverlayWindow.swift`
- `NestRenderer.swift`
- `NestUI.swift`
- `NestLayout.swift`
- `NestThemeElement.swift`
- `OfficialComponentRenderer.swift`
- `MetricTextRenderer.swift`
- `MetricGaugeRenderer.swift`
- `VariantImageRenderer.swift`
- `UsageOrbitRenderer.swift`

### Requirements

- Render package-driven nest, not only hardcoded fixture.
- Support v1.0 `layers` / `widgetSlots`.
- Support v1.1 draft `elements`.
- Support `staticImage`, `variantImage`, `metricText`, `metricGauge`.
- Support bundled built-in nests:
  - Capacity Orbit.
  - Basket Pomodoro Nest.
  - Legend Status Nest.
  - Nest Terminal.
- Support missing asset fallback.
- Support metric unavailable fallback.
- Support preview image.
- Support active nest apply.

### macOS Requirements

- Release overlay displays selected nest without debug frame.
- Follow Codex pet remains available where Codex state is readable.
- Standalone fixed mode remains available.

### Windows Requirements

- Selected nest renders from Windows artifact.
- If follow-codex is unverified, standalone mode must still work.
- Unsupported follow/click-through states must be visible and honest.

### Tests

- Renderer unit tests for every supported element type.
- React overlay test for package-driven nest.
- Missing asset test.
- Metric unavailable test.
- Built-in nest registration test for all four built-ins.

## Workstream F: Local Nest Management And Nest Marketplace

### Goal

恢复小窝管理和小窝市场入口。

### Original Modules

- `LocalNestManager.swift`
- `LocalNestManagerViewController.swift`
- `OnlineNestMarketplaceWindowController.swift`
- `NestInstallService.swift`
- `PackageManager.swift`

### Requirements

- Show installed local nests.
- Show built-in nests.
- Preview nest.
- Apply now.
- Mark active nest.
- Prevent deleting built-in nests.
- Import local nest ZIP.
- Validate manifest/assets/security.
- If online nest marketplace API is available, browse/download/install.
- If API is unavailable, show explicit Coming Soon state.
- Do not fake remote nest data.

### macOS And Windows Requirements

- Same UI structure and state model.
- Platform-specific open-folder behavior.
- Same validation and install rules.

## Workstream G: Settings Information Architecture

### Goal

Settings 必须从工程诊断面板变成真实产品控制中心。

### Requirements

Settings should include:

- Overview / status.
- Pet:
  - active standalone pet.
  - current Codex active pet read-only marker.
  - local pet list.
  - install local pet.
  - open pet folder.
- Pet Marketplace.
- Nest:
  - active nest.
  - preview.
  - local nest list.
  - install local nest.
- Nest Marketplace or Coming Soon.
- Overlay:
  - show/hide.
  - follow/standalone.
  - position.
  - click-through.
  - always-on-top.
- Widgets.
- Quick actions.
- Local snapshot.
- App info.
- Development Diagnostics, collapsed and clearly secondary.

### macOS Requirements

- Menu-bar actions open the correct Settings section where applicable.

### Windows Requirements

- Tray actions open the correct Settings section where applicable.

## Workstream H: Cross-Platform Validation

### Required CI

Every implementation PR must pass:

- `pnpm qa:release-smoke`
- `pnpm typecheck`
- `pnpm lint`
- `pnpm test`
- `cd apps/desktop-tauri/src-tauri && cargo fmt --all --check`
- `cd apps/desktop-tauri/src-tauri && cargo clippy --all-targets -- -D warnings`
- `cd apps/desktop-tauri/src-tauri && cargo test`
- GitHub Actions Windows CI build.

### Required Manual QA Before Completion Claim

macOS:

- Release `.app` launches.
- Pet visible.
- Pet animation visible.
- Local pet install works.
- Pet marketplace browse/install works or documented blocker.
- Nest visible.
- Local nest install/apply works.
- Overlay follow/standalone paths verified.
- Click-through verified.
- Menu-bar actions verified.

Windows:

- Installer launches.
- App launches.
- Tray actions verified.
- Pet visible.
- Pet animation visible.
- Local pet install works.
- Marketplace browse/install works or documented blocker.
- Nest visible.
- Standalone overlay mode verified.
- Click-through unsupported state verified if still not implemented.
- Follow-codex remains unclaimed until Codex state path/schema and coordinates are proven.

## Completion Criteria

Phase 15 can be considered complete only when:

- A gap report exists and maps every original core product module.
- Pet display works in the Tauri app.
- Pet animation works in the Tauri app.
- Local pet management works.
- At least one remote pet marketplace flow is implemented or blocked with concrete API evidence.
- Nest renderer uses real package data, not only fixtures.
- Local nest management works.
- Nest marketplace has either a working implementation or explicit Coming Soon state.
- Settings exposes the core product flows.
- macOS release build has manual QA evidence for pet + nest core flows.
- Windows CI still passes.
- Windows runtime support status is honestly recorded.

Phase 15 is not complete if:

- The app still only shows a nest/debug overlay and no pet.
- Pet marketplace is absent.
- Local pet install is absent.
- Nest display is still fixture-only.
- Windows support is ignored.
- Any unsupported Windows feature silently pretends to work.

## Recommended Implementation Order

1. Product parity gap report.
2. Pet manifest parsing and pet renderer.
3. Standalone pet window/overlay.
4. Local pet scan/install/manage.
5. Official pet marketplace MVP.
6. Petdex MVP.
7. Package-driven nest renderer parity.
8. Local nest manager.
9. Nest marketplace or explicit Coming Soon.
10. Settings information architecture.
11. macOS production QA report.
12. Windows artifact GUI validation after core flows exist.

## Instructions For Future Agents

When implementing Phase 15:

- Start by reading this document and `docs/requirements-overview.md`.
- Read the listed Swift source modules from `/Users/ryanniu/Documents/Project/codexpet-nest`.
- Do not assume current Tauri MVP equals feature parity.
- Prefer incremental PRs, each with tests and a report update.
- Keep macOS and Windows status explicit in every report.
- Do not claim full completion until pet display, pet management, marketplace, nest display, and nest management all work.
- Do not remove existing release smoke or Windows CI checks.
