# Tauri + React Cross-Platform Migration Plan

Date: 2026-05-31

目标：从当前 macOS Swift/AppKit 版本迁移到 Tauri + React + local-first sync
架构，最终覆盖现有 CodexPet Nest 功能，并为 Windows、后续 Linux/移动端和多端同步打基础。

本文面向实现代理/开发者。每个阶段都应提交可运行产物、测试记录和风险更新，方便 review。

## 0. 总原则

- 先验证高风险能力，再迁移大 UI。
- 当前 Swift 版作为行为参考和回归基准，不在迁移初期删除。
- Tauri 版优先做到功能等价，再考虑体验增强。
- 所有平台相关能力通过明确接口隔离。
- 所有用户数据默认本地优先；同步只同步必要配置和元数据。
- 不修改、不注入 Codex Desktop，仅只读读取公开/本地状态。
- 不上传 prompts、session、仓库代码、Codex 原始日志或未授权敏感数据。

## 1. 推荐仓库布局

```text
apps/
  desktop-tauri/
    src/                         # React UI
    src-tauri/                   # Tauri app, Rust commands, plugins
packages/
  core/
    src/package-schema/          # pet/nest manifest, validators
    src/settings/                # settings schema and migrations
    src/sync/                    # sync record types
  renderer/
    src/nest/                    # nest layout/theme renderer
    src/widgets/                 # clock/countdown/pomodoro/usage components
  ui/
    src/                         # shared React components
crates/
  codexpet_platform/
    src/macos.rs                 # macOS Codex state, keychain, window helpers
    src/windows.rs               # Windows Codex state, credentials, window helpers
    src/common.rs
server/
  sync-api/                      # future sync backend, optional during MVP
docs/
  tauri-cross-platform-research.md
  tauri-migration-plan.md
  requirements-overview.md
```

如果实现方希望先在独立分支/独立目录里做 spike，可以只创建
`apps/desktop-tauri`，但最终应收敛到以上结构或等价结构。

## 2. Phase 0: Project Bootstrap

目标：创建 Tauri + React 项目，建立工程质量底座。

任务：

- 初始化 `apps/desktop-tauri`。
- 使用 TypeScript + React。
- 使用 Rust stable toolchain。
- 配置 package manager，建议 pnpm workspace。
- 添加 lint、format、typecheck、unit test 命令。
- 配置基础 CI：
  - TypeScript typecheck
  - React unit tests
  - Rust fmt/clippy/test
  - Tauri build smoke test
- 创建基础窗口：
  - settings window
  - transparent overlay window
  - tray/menu entry
- 创建统一 app config：
  - app name
  - version
  - API base URL
  - data directory
  - debug flags

验收标准：

- `pnpm install` 后能启动 Tauri dev app。
- settings window 和 overlay window 能同时存在。
- overlay window 可透明显示。
- CI 或本地等价命令全部通过。

Review 重点：

- 项目结构是否可扩展。
- 平台代码是否已经和 React UI 解耦。
- 是否引入了不必要的大型依赖。

## 3. Phase 1: Risk Spike

目标：先确认最可能决定成败的能力。

任务：

- Windows Codex state spike：
  - 发现 Windows 上的 `CODEX_HOME`。
  - 查找 `.codex-global-state.json` 是否存在。
  - 验证是否有 `electron-avatar-overlay-open`、
    `electron-avatar-overlay-bounds`、`mascot` 等字段。
  - 记录脱敏样例。
- Overlay spike：
  - frameless transparent window。
  - always-on-top。
  - skip taskbar。
  - 可切换 click-through / interactive。
- 坐标 spike：
  - 将 Codex top-left 坐标转换成 Tauri window 坐标。
  - Windows 100%、125%、150%、混合 DPI 测试。
  - macOS Retina、多显示器测试。
- 托盘 spike：
  - 显示/隐藏 overlay。
  - 打开 settings。
  - quit。

验收标准：

- 有 Windows 和 macOS 的测试记录。
- 若 Windows Codex state 不可用，必须提出 fallback 产品定义：
  standalone nest + manual positioning。
- overlay 在至少一个 Windows 设备和一个 macOS 设备上可运行。

Review 重点：

- 是否把未知项如实标记，避免伪确认。
- 坐标计算是否有单元测试或可复现实验记录。
- overlay 是否能在失败时优雅降级。

## 4. Phase 2: Core Domain Port

目标：把可复用的产品规则迁移到跨端 core，不急着完成全部 UI。

任务：

- 定义并实现 package schemas：
  - `codexpet.pet`
  - `codexpet.nest`
  - v1.0 `nest.json`
  - v1.1 draft theme fields
- 实现 ZIP 安全校验：
  - 禁止路径遍历。
  - 禁止脚本和可执行文件。
  - 限制文件类型。
  - 限制 package/image 大小。
  - SHA256 校验。
- 实现 settings schema：
  - current nest id
  - overlay mode
  - standalone position
  - widget configs
  - managed pet/nest ids
  - quick actions
  - sync/device metadata
- 实现 app data path abstraction：
  - macOS: Application Support
  - Windows: AppData/LocalAppData
  - Linux: XDG directories, if in scope
- 实现 Codex home resolver：
  - `CODEX_HOME`
  - default `.codex`
  - protected path rejection

验收标准：

- core validators 有测试覆盖。
- 使用当前 docs/test-fixtures 可验证成功/失败样例。
- settings 支持版本字段和 migration。

Review 重点：

- 安全校验是否默认拒绝未知危险内容。
- 路径处理是否使用结构化 API。
- 是否避免把平台路径硬编码到 React UI。

## 5. Phase 3: Overlay and Rendering MVP

目标：完成最核心体验：小窝能显示、能跟随、能独立运行。

任务：

- 实现 overlay runtime：
  - follow Codex mode。
  - standalone fixed mode。
  - standalone roam/interactive mode, 如果当前行为需要。
  - show/hide pet/nest controls。
  - always-on-top toggle。
  - click-through toggle。
- 实现 nest renderer：
  - v1.0 layers。
  - widget slots。
  - built-in dynamic renderer: `default`。
  - built-in dynamic renderer: `capacity-orbit-nest`。
  - v1.1 elements 基础支持：
    - staticImage
    - variantImage
    - metricText
    - metricGauge
- 实现内置 widgets：
  - Clock
  - Countdown
  - Pomodoro
  - Usage Indicator
- 实现 metric providers：
  - system time metrics。
  - usage metrics。
  - timer metrics。

验收标准：

- 内置四个 nest 示例可显示并基本等价。
- overlay 能跟随 Codex pet；不可用时进入 standalone fallback。
- 多显示器下不跑出可见区域。
- Widget 状态重启后保留。

Review 重点：

- 渲染逻辑是否和业务状态分离。
- 动画是否造成明显 CPU 占用。
- metric unavailable 是否不会 crash。

## 6. Phase 4: Settings and Local Management UI

目标：迁移用户能操作的管理界面。

任务：

- Settings/Main window：
  - sidebar navigation。
  - Nest controls。
  - Pet controls。
  - marketplace entries。
  - quick actions。
  - about/update。
- Local pet management：
  - 扫描 Codex pets。
  - 扫描 Nest internal pets。
  - 识别当前 active pet，只读展示。
  - 安装本地 pet ZIP。
  - 卸载 app-managed pet。
  - 打开文件位置。
  - 打开 Codex settings route/app, 平台适配。
- Local nest management：
  - 自动安装 bundled nests。
  - 预览。
  - Apply Now。
  - 卸载非内置 nest。
  - 打开文件位置。
- Package install UI：
  - 本地文件选择。
  - 安装进度。
  - 错误展示。

验收标准：

- 用户无需命令行即可完成现有主要流程。
- 错误信息清楚，不暴露敏感路径以外的信息。
- macOS 和 Windows 的路径/打开方式各自正确。

Review 重点：

- UI 是否承担了过多平台逻辑。
- 是否保留“不会自动切换 Codex 当前 pet”的产品边界。
- 删除/卸载是否只作用于 app-managed 内容或明确授权内容。

## 7. Phase 5: Marketplace and Network

目标：恢复在线宠物市场和未来 nest 市场能力。

任务：

- Port CodexPet API client：
  - list pets。
  - pet download metadata。
  - nest metadata/download, 如果 API 已就绪。
  - analytics, 如果保留。
- Petdex integration：
  - list/search。
  - external download validation。
  - third-party source warning。
- Marketplace UI：
  - list/grid。
  - preview。
  - install。
  - installed state。
  - view website。
- Network safety：
  - HTTPS only for external downloads。
  - allowed host list for known third-party sources。
  - SHA256 required for official downloads。

验收标准：

- codexpet.xyz 官方 pet 可安装。
- Petdex pet 可安装并有第三方提醒。
- 下载失败、校验失败、manifest 不匹配均有清楚错误。

Review 重点：

- 是否绕过了 SHA256 或 host validation。
- 是否把第三方内容标成官方。
- 是否有超时、取消、重试策略。

## 8. Phase 6: Quick Actions

目标：保留快捷动作能力，同时做平台化约束。

任务：

- 定义 cross-platform quick action schema：
  - id
  - name
  - icon
  - kind
  - platform
  - target
  - enabled
  - requireConfirm
- 支持通用动作：
  - URL
  - app launch
- macOS 支持：
  - app bundle path/bundle id。
  - Shortcuts。
  - Terminal command via safer replacement for AppleScript where possible。
- Windows 支持：
  - executable/app URI launch。
  - PowerShell/Windows Terminal command with confirmation。
  - URL scheme。
- UI：
  - add/edit/delete/reorder。
  - platform-specific warning。
  - command confirmation。

验收标准：

- URL/app launch 双平台可用。
- shell/terminal 类动作默认要求确认。
- 绝对路径动作不跨平台盲目同步。

Review 重点：

- 命令执行边界是否明确。
- 是否防止未确认执行危险命令。
- sync 是否支持 per-platform overrides。

## 9. Phase 7: Local-First Sync

目标：建立未来多端同步，不阻塞本地功能。

任务：

- 定义 device model：
  - device id。
  - platform。
  - app version。
  - last seen。
- 定义 sync record：
  - record id。
  - collection。
  - value。
  - updatedAt。
  - version。
  - deleted tombstone。
  - device id。
- 同步集合：
  - settings。
  - widget configs。
  - installed package metadata。
  - selected nest。
  - quick action metadata with platform overrides。
- 不同步内容：
  - raw prompts。
  - sessions。
  - repository content。
  - raw Codex logs。
  - auth tokens。
- Conflict policy：
  - MVP 使用 last-write-wins。
  - quick actions 按 platform scoped records 合并。
- Offline behavior：
  - 本地写入立即生效。
  - 后台队列重试。
  - 用户可看到 sync status。

验收标准：

- 断网时功能不受影响。
- 同一账号两台设备能同步 selected nest 和 widget config。
- 平台不兼容配置不会破坏另一端。

Review 重点：

- 同步是否泄露敏感数据。
- 冲突是否可解释。
- 删除 tombstone 是否避免数据复活。

## 10. Phase 8: Migration From Existing macOS App

目标：让现有 macOS 用户升级到 Tauri 版时尽量无感。

任务：

- 读取旧目录：
  - `~/Library/Application Support/CodexPet Nest/settings.json`
  - old pets/nests/tmp directories。
- 迁移：
  - settings schema。
  - installed internal pets。
  - installed nests。
  - widget states。
  - managed ids。
- 保留：
  - 原目录备份。
  - migration log。
  - rollback safe behavior。
- 不迁移：
  - Sparkle metadata。
  - transient cache。
  - invalid packages。

验收标准：

- 旧版安装过的 nest/pet 在新版可见。
- active nest 和 widget config 能恢复。
- 迁移失败不会删除旧数据。

Review 重点：

- 是否有幂等 migration。
- 是否有备份。
- 是否避免破坏 Swift 版数据。

## 11. Phase 9: Release and Distribution

目标：替换 Sparkle/DMG 单平台发布，建立跨平台发布流。

任务：

- Windows：
  - choose NSIS or MSI。
  - signing。
  - installer icon/assets。
  - install/uninstall validation。
- macOS：
  - app bundle。
  - signing。
  - notarization。
  - Apple Silicon and Intel, if required。
- Updater：
  - Tauri updater endpoint。
  - platform/arch metadata。
  - update signature。
  - staged rollout, optional。
- CI/CD：
  - build matrix。
  - artifact upload。
  - release metadata publish to codexpet.xyz。
- Docs：
  - install docs。
  - uninstall docs。
  - privacy/security docs update。

验收标准：

- 从 vA 更新到 vB 在 Windows/macOS 均成功。
- 安装包能全新安装、覆盖安装、卸载。
- 发布文档可由人类或 AI 按步骤执行。

Review 重点：

- 签名密钥是否不入库。
- updater metadata 是否不可被普通包伪造。
- release artifacts 是否和版本号一致。

## 12. Phase 10: Parity Hardening

目标：迁移完成前的功能对齐和稳定性打磨。

任务：

- 逐项对照 `docs/requirements-overview.md`。
- 视觉回归：
  - built-in nests。
  - widgets。
  - settings UI。
  - marketplace UI。
- 行为回归：
  - Codex open/closed。
  - Codex unavailable。
  - multi-monitor。
  - restart persistence。
  - package validation failures。
- 性能：
  - idle CPU。
  - memory。
  - animation smoothness。
  - startup time。
- Security/privacy：
  - no script execution from packages。
  - no prompt/session upload。
  - third-party warnings。
  - token storage。

验收标准：

- 当前 Swift 版功能全部有 Tauri 等价实现或明确弃用说明。
- 未确认项全部关闭或转成已接受限制。
- 可以发布 Tauri 版作为新主线客户端。

## 13. Review Handoff Checklist

每个实现 PR/阶段交付都应包含：

- 变更范围。
- 已实现需求编号。
- 本地运行命令。
- 测试命令和结果。
- 手动验证截图/录屏，尤其是 overlay 和多屏行为。
- 新增风险或未完成项。
- 是否影响隐私/安全边界。

我后续 review 时会优先检查：

- 是否破坏“不修改 Codex”的边界。
- 是否遗漏 package 安全校验。
- 是否把平台差异泄漏到 UI 层。
- 是否同步了不该同步的数据。
- 是否让 Windows fallback 行为清楚可用。
- 是否有足够的测试覆盖高风险逻辑。
