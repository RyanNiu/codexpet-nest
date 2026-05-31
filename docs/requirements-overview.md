# CodexPet Nest Requirements Overview

Date: 2026-05-31

本文是功能需求总览，用于防止 Tauri + React 迁移时功能溢出或遗漏。实现方应把每个功能映射到 issue/PR，并在迁移完成前逐项验收。

## 1. Product Boundaries

必须保持：

- CodexPet Nest 是独立应用，不声称 OpenAI/Codex 官方合作。
- 不修改、不注入 Codex Desktop app bundle。
- 不修改 Codex global state。
- 读取 Codex 位置数据只用于跟随 pet。
- 不自动切换 Codex 当前 pet。安装宠物后，用户仍需在 Codex 设置里手动选择。
- 不上传 prompts、sessions、仓库代码、项目文件或 Codex 原始日志。
- 第三方 package 必须本地校验，不能执行脚本。
- 应可完全卸载；用户数据目录可由用户手动删除。

## 2. Target Platforms

初始目标：

- macOS。
- Windows。

设计预留：

- Linux 桌面。
- 未来移动端或 Web 管理端，只同步配置和包元数据，不承诺桌面 overlay。

## 3. App Shell

必须支持：

- 托盘/menu-bar 常驻。
- 打开/隐藏主设置窗口。
- 显示/隐藏 nest overlay。
- 退出应用。
- About/version。
- 检查更新。
- 首次启动自动初始化数据目录。
- 应用重启后恢复主要设置。

平台差异：

- macOS 使用 menu-bar 体验。
- Windows 使用 system tray 体验。
- 菜单项可以平台化，但功能应等价。

## 4. Nest Overlay

必须支持：

- 透明悬浮小窝窗口。
- always-on-top。
- 跟随 Codex pet 模式。
- Codex unavailable/closed 时的 fallback 展示。
- 独立显示模式。
- 手动定位/固定位置。
- 多显示器适配。
- 窗口不应跑出可见区域。
- 可切换点击穿透/可交互，至少满足现有右键菜单或等价控制。
- 支持打开上下文菜单或托盘菜单进行主要操作。

应支持：

- 显示/隐藏宠物或小窝。
- standalone pet/window 行为，如果迁移当前 `StandalonePetWindow` 相关体验。
- roam/animation 行为，如果产品仍保留。

验收：

- Codex pet 移动时，nest 位置跟随。
- Codex pet 关闭时，nest 不崩溃，状态清楚。
- 混合 DPI 多显示器下位置大致正确。

## 5. Codex Integration

必须支持：

- 解析 `CODEX_HOME`。
- 默认读取用户 `.codex` 目录。
- 读取 `.codex-global-state.json`。
- 识别 pet overlay open/closed/unavailable。
- 读取 active pet id，只读展示。
- 打开 Codex 设置或 Codex app 的平台化入口。

不得支持：

- 写入 Codex global state。
- 修改 Codex 当前 active pet。
- 注入 Codex 进程或 app bundle。

遗留确认：

- Windows 上 Codex pet state 路径和字段是否与 macOS 一致。

## 6. Built-In Nests

必须迁移当前内置 nest：

- Capacity Orbit。
- Basket Pomodoro Nest。
- Legend Status Nest。
- Nest Terminal。

必须支持：

- 首次启动自动安装/注册 bundled nests。
- 预览。
- Apply Now。
- 当前 active nest 标记。
- 内置 nest 防误删。

## 7. Nest Package and Theme Support

必须支持 v1.0 package：

- `codexpet-package.json`。
- `nest.json`。
- `preview.png`。
- `assets/`。
- image layers。
- `widgetSlots`。

应支持 v1.1 draft theme 基础能力：

- `metricBands`。
- `elements`。
- `staticImage`。
- `variantImage`。
- `metricText`。
- `metricGauge`。
- 向后兼容 v1.0。

安全限制：

- 禁止脚本：`.js`, `.ts`, `.sh`, `.py` 等。
- 禁止二进制执行文件。
- 禁止 WebView/iframe/远程图片。
- 限制 ZIP 大小、单图大小、canvas 尺寸。
- 防路径遍历。

## 8. Widgets

必须支持：

- Clock：
  - 当前时间。
  - 日期。
  - 主题内 slot/element 渲染。
- Countdown：
  - 设置目标日期/时间。
  - 显示剩余时间。
  - 过期状态。
  - 配置持久化。
- Pomodoro：
  - focus/break/idle/paused 状态。
  - start/pause/reset。
  - 剩余时间显示。
  - 配置和状态持久化。
- Usage Indicator：
  - primary/secondary usage。
  - ring/gauge/text 展示。
  - unavailable fallback。

必须保证：

- 任一 metric 缺失时 widget 不 crash。
- 重启后恢复用户配置。

## 9. Usage Metrics

必须支持：

- 优先 live usage fetch, 如果保留现有能力。
- fallback 到本地 Codex SQLite logs, 如果平台可用。
- primary window。
- secondary window。
- remaining percent。
- reset label/time。
- source: live/cached/unavailable。

隐私要求：

- 不上传原始 logs。
- 不上传 prompts/session 内容。
- 只在 UI 中展示必要摘要。

平台遗留：

- Windows 上 SQLite 路径和 sqlite 可用性需要确认。
- 不应依赖 `/usr/bin/sqlite3` 这类 macOS 固定路径。

## 10. Local Pet Management

必须支持：

- 扫描 Nest internal pets。
- 扫描 Codex pets 目录。
- 去重，优先 app-managed/Nest internal 版本。
- 展示 pet：
  - display name。
  - description。
  - preview/spritesheet。
  - current active marker。
  - managed marker。
- 安装本地 pet ZIP。
- 卸载 app-managed pet。
- 打开 pet 文件位置。
- 刷新列表。

必须保持：

- 安装后不自动切换 Codex active pet。
- 提示用户去 Codex 设置里手动选择。

## 11. Pet Rendering and Preview

必须支持：

- pet manifest 解析。
- spritesheet 加载。
- frame width/height 或 frame size。
- columns/rows。
- animations 配置。
- preview/thumbnail cache。
- 动画预览。

应支持：

- 缺失 preview 时从 spritesheet 生成缩略图。
- 图片加载失败 fallback。

## 12. Online Pet Marketplace

必须支持：

- 浏览 codexpet.xyz 官方 pet。
- 获取官方 download metadata。
- SHA256 校验。
- 一键安装。
- installed 状态。
- 错误提示。

必须支持 Petdex：

- 浏览第三方 pet。
- 第三方来源提示。
- HTTPS download。
- allowed host validation。
- 安装前 inspect manifest。
- 防止下载内容 id 与确认内容不一致。

## 13. Nest Marketplace

当前状态：

- 在线 Nest 市场在现有 README 中为 Coming Soon。

迁移要求：

- 主 UI 预留入口。
- 如果 API 已可用，实现浏览、预览、下载、SHA256 校验、安装。
- 如果 API 未可用，显示明确 Coming Soon 或禁用态。

不得：

- 假装已有在线 nest 数据。
- 降低第三方 package 安全要求。

## 14. Package Installation and Validation

必须支持：

- 官方远程下载安装。
- 第三方远程下载安装。
- 本地 ZIP 安装。
- SHA256 校验。
- manifest 校验。
- 必需文件校验。
- package type 校验。
- 安全文件类型校验。
- path traversal 防护。
- 安装到 app-controlled data directory。
- 安装失败清理临时目录。

必须有测试：

- valid package。
- missing manifest。
- path traversal。
- unsafe file type。
- sha mismatch。
- id mismatch。

## 15. Settings

必须支持持久化：

- overlay mode。
- active nest id。
- nest placement preference。
- always-on-top。
- click-through/interactive。
- standalone position。
- widget configs。
- managed pet ids。
- managed nest ids。
- quick actions。
- sync/device metadata。
- language/locale preference, 如果保留。

必须支持：

- schema version。
- migration。
- corrupted settings fallback。
- save debounce 或原子写入。

## 16. Quick Actions

必须支持：

- action list。
- add/edit/delete。
- reorder。
- enable/disable。
- icon。
- name。
- kind。
- target。
- require confirmation。

Action kinds：

- URL。
- App launch。
- Terminal/shell command。
- macOS Shortcuts, macOS only。
- Windows PowerShell/Terminal or URI scheme, Windows only。

安全要求：

- 命令类动作默认确认。
- 平台不支持的动作应显示 disabled/incompatible。
- 不自动执行来自第三方 package 的命令。

同步要求：

- 绝对路径和平台专属动作不能无脑跨平台套用。

## 17. Updates and Distribution

必须支持：

- Windows installer。
- macOS app bundle。
- app signing。
- Tauri updater。
- check for updates。
- update available UI。
- update failure handling。
- version/build display。

应支持：

- Windows NSIS 或 MSI，二选一明确。
- macOS notarization。
- 多架构发布。
- codexpet.xyz 托管 release metadata。

## 18. Sync

必须采用 local-first：

- 本地写入立即生效。
- 后台同步。
- 失败重试。
- 离线可用。
- 用户可看 sync status。

初始同步范围：

- selected nest。
- overlay preferences。
- widget configs。
- installed package metadata。
- quick action metadata with platform overrides。

不同步：

- auth tokens。
- raw Codex logs。
- prompts。
- sessions。
- repo/project files。
- 第三方 package 二进制内容，除非未来有明确资源同步方案。

冲突策略：

- MVP: last-write-wins。
- 删除使用 tombstone。
- platform-scoped records 用于平台专属设置。

## 19. Analytics

如果保留 analytics，必须满足：

- 明确事件名称和字段。
- 不包含 prompts/session/repo 内容。
- 不包含原始 Codex logs。
- 安装成功/失败、市场来源等只记录必要摘要。
- 用户隐私文档同步更新。

## 20. Internationalization

必须支持：

- English。
- 简体中文。

应支持：

- 所有用户可见字符串进入 i18n 字典。
- 平台专属错误消息可翻译。
- fallback language。

## 21. Security and Privacy

必须保证：

- package 不可执行代码。
- 第三方来源明确标识。
- 官方下载必须校验 SHA256。
- 外部下载必须 HTTPS。
- token 使用平台安全存储。
- 不上传敏感本地内容。
- 删除只影响用户授权或 app-managed 内容。
- 文件路径处理防 traversal/symlink abuse。

## 22. Error and Fallback States

必须有明确状态：

- Codex not installed。
- Codex not running。
- pet overlay closed。
- Codex state unavailable。
- usage unavailable。
- marketplace offline。
- package invalid。
- update failed。
- sync offline。
- platform feature unsupported。

要求：

- 不 crash。
- 提示下一步。
- 保持核心 UI 可操作。

## 23. Testing Matrix

最低测试：

- macOS current supported version。
- Windows 11。
- single monitor。
- multi-monitor。
- Windows mixed DPI。
- Codex running。
- Codex closed。
- Codex absent。
- online/offline。
- valid/invalid packages。
- upgrade/migration。

自动化测试：

- package validators。
- settings migrations。
- sync conflict resolution。
- Codex state parser with fixtures。
- coordinate conversion pure functions。
- API client mock tests。

手动验证：

- overlay visual behavior。
- tray/menu behavior。
- installer/update。
- marketplace install flow。

## 24. Parity Checklist

迁移完成前必须逐项确认：

- 透明置顶 nest overlay。
- Codex pet follow。
- standalone nest mode。
- 内置四个 nest。
- Clock widget。
- Countdown widget。
- Pomodoro widget。
- Usage Indicator widget。
- 本地 pet 扫描。
- 本地 pet ZIP 安装。
- 当前 active pet 只读识别。
- 官方 pet marketplace。
- Petdex marketplace。
- 本地 nest 管理。
- nest apply/preview/uninstall。
- package SHA256/path traversal/script 禁止。
- 多显示器。
- quick actions。
- app update。
- i18n 中文/英文。
- privacy/security boundaries。
- macOS existing data migration。
- Windows installer。
- local-first sync。

## 25. Out of Scope Unless Explicitly Approved

默认不做：

- 修改 Codex active pet。
- 注入 Codex。
- 从第三方 package 执行脚本。
- 上传用户 prompts/session/repo。
- 复杂多人协作 CRDT。
- 移动端 overlay。
- Mac App Store 分发。
- 全量资源云同步。
- 未经确认的 Linux 正式支持。
