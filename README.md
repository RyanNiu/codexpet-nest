# CodexPet Nest

[简体中文](#简体中文) | [English](#english)

---

<a name="简体中文"></a>

## 简体中文

CodexPet Nest 是 [codexpet.xyz](https://codexpet.xyz) 的 macOS 桌面伴侣应用。它在你的 Codex Desktop 宠物旁边显示一个透明悬浮小窝（nest overlay），内置时钟、倒计时、番茄钟等小组件。

### 重要声明

- CodexPet Nest 与 Codex / OpenAI 相互独立，除非将来有官方合作。
- **不会** 修改或注入 Codex Desktop 的 app bundle。
- **不会** 修改 Codex 的全局状态（global state）。读取其位置数据**仅用于**让 nest 跟随 pet 移动。
- **不支持** 自动切换 Codex 当前使用的宠物。安装宠物后，请手动在 Codex 设置中选择。
- **不会** 上传你的 prompts、session、仓库代码或项目文件。
- 可完全卸载，不留残留。

### 系统要求

- macOS 14 Sonoma 或更高版本
- Apple Silicon (arm64) — Intel 支持后续添加

### v0.1 主要功能

- **透明置顶悬浮巢窗口**：跟随 Codex pet 移动（或独立显示）。
- **内置小组件**：
  - **时钟** — 当前时间和日期。
  - **倒计时** — 设置并显示目标日期/时间。
  - **番茄钟** — 专注与休息计时器。
  - **使用量指示器** — 基于本地日志的 Codex 使用量环形图（无需 API Key）。
- **本地宠物管理**：
  - 自动扫描并列出已安装的 Codex 宠物。
  - 支持安装本地宠物 ZIP 包。
  - 支持卸载 app 管理的宠物包。
  - 只读识别当前活动宠物。
- **在线宠物市场**：
  - 在应用内浏览并一键下载 [codexpet.xyz](https://codexpet.xyz) 上的宠物。
  - 强制 SHA256 校验，确保安装包完整且安全。
- **本地 Nest Skin 管理**：
  - 安装、预览并切换小窝外观。
  - 小窝外观包是**纯静态资源包**（图片 + 布局 JSON），禁止执行代码，绝对安全。
- **在线官方 Nest 市场**：
  - 浏览并下载官方设计的小窝皮肤。
  - 支持一键应用（Apply Now）。
- **安全保障**：
  - 使用 `SafeZipReader` 解压，强制防御路径遍历和符号链接漏洞。
  - 严格限制包内容，禁止脚本和二进制执行文件。
- **多显示器支持**：自动适配多屏环境。

### 安装

1. 从 [codexpet.xyz/downloads](https://codexpet.xyz/downloads) 下载 `CodexPetNest.dmg`。
2. 将 `CodexPet Nest.app` 拖入 `Applications` 文件夹。

> 首次运行时，如果 Gatekeeper 提示"无法验证开发者"，请在 Finder 中右键 app → 打开，或在「系统设置 → 隐私与安全性」中点击"仍要打开"。

### 使用说明

#### 切换宠物

1. 在 CodexPet Nest 中点击“Install”安装新宠物。
2. **手动操作**：打开 Codex Desktop 的设置面板。
3. 在“Avatar/Pet”选项中找到新安装的宠物并选择。

#### 切换小窝外观

1. 在菜单栏点击“Nest Marketplace”或“Local Nests”。
2. 选择喜欢的外观点击“Apply Now”。

### 卸载

1. 从菜单栏退出 CodexPet Nest。
2. 从 `Applications` 删除 `CodexPet Nest.app`。
3. （可选）删除数据目录 `~/Library/Application Support/CodexPet Nest/`。

### 从源码构建

#### 快速开始

```bash
# 克隆仓库
git clone https://github.com/RyanNiu/codexpet-nest.git
cd codexpet-nest

# 安装依赖 — 需要 Xcode Command Line Tools
xcode-select --install 2>/dev/null || echo "CLT 已安装"

# 构建 debug 版本
make

# 构建 release 版本
make release

# 打包为 .app
make app

# 运行 app
make run

# 清理构建产物
make clean
```

#### Make 目标说明

| 命令                | 说明                                                |
| ------------------- | --------------------------------------------------- |
| `make` / `make all` | 编译 debug 版本（二进制路径 `.build/CodexPetNest`） |
| `make debug`        | 等同于 `make`（debug 构建）                         |
| `make release`      | 编译 release 版本（开启 `-O` 优化）                 |
| `make app`          | 编译 release 并打包为 `CodexPet Nest.app`           |
| `make run`          | 打包 app 并启动                                     |
| `make clean`        | 删除 `.build/` 目录                                 |

#### 为什么不用 Swift Package Manager？

当前环境的 SPM 存在 toolchain 兼容性问题（`PackageDescription` 符号未定义），因此本项目使用 `Makefile` + 直接 `swiftc` 编译。Makefile 会自动处理源文件发现、framework 链接和 SDK 路径。

如需恢复 SPM 构建，请确保 Swift toolchain 版本 ≥ 6.0 且 CLT 完整安装。

### 开发常用指令

```bash
# ─── 构建 & 运行 ──────────────────────────────

make                      # 编译 debug 版本（开发时最常用）
make app                  # 打包为 .app（发布前验证）
make run                  # 打包并启动（完整功能验证）
make clean && make dev    # 清理后重新编译

# ─── 测试 API（需要先启动 codexpet 网站 dev server） ───

# 版本检查
curl -s https://codexpet.xyz/api/desktop/version | jq

# 宠物列表
curl -s "https://codexpet.xyz/api/pets?page=1" -H "Accept: application/json" | jq

# 宠物详情
curl -s "https://codexpet.xyz/api/pets/codie" -H "Accept: application/json" | jq

# 宠物下载元数据
curl -s "https://codexpet.xyz/api/pets/codie/download" -H "Accept: application/json" | jq

# Nest 列表
curl -s "https://codexpet.xyz/api/nests?page=1" -H "Accept: application/json" | jq

# 设备码申请（POST）
curl -s -X POST https://codexpet.xyz/api/auth/device-code \
  -H "Content-Type: application/json" \
  -d '{"client":"codexpet-nest","platform":"macos"}' | jq

# ─── 本地开发（两个仓库联动） ──────────────────

# 1. 启动 codexpet 网站 dev server（另一个终端）
cd /path/to/codexpet
npm run dev &

# 2. 构建 nest app
cd /path/to/codexpet-nest
make run

# 3. 观察日志
# app 的控制台输出可在终端或「控制台.app」中查看
# 如果 API 不通，检查 next.config.ts 中 rewrites 的目标端口

# ─── 调试 ──────────────────────────────────────

# 查看编译详情（含 warning）
make clean && make 2>&1

# 单独编译某个文件测试语法
xcrun swiftc -sdk $(xcrun --show-sdk-path) -typecheck Sources/CodexPetNest/CodexPetAPI.swift

# 检查 app bundle 结构
ls -R ".build/CodexPet Nest.app/Contents"

# View runtime logs
log stream --predicate 'process == "CodexPetNest"' --level debug

# ─── 版本 & 信息 ───────────────────────────────

# 显示 Swift 版本
swift --version

# 显示 SDK 路径
xcrun --show-sdk-path

# 显示 Swift 运行时路径
xcrun --show-sdk-platform-path

# ─── Git ───────────────────────────────────────

git tag v0.1.0                          # 打版本 tag
git push origin v0.1.0                  # 推送 tag
# 说明：README 中的版本号 (0.1.0) 需与
# AppDelegate.swift 和 NestOverlayWindow.swift 中的保持同步
```

### 项目结构

```text
codexpet-nest/
├── Makefile                    # 构建系统
├── README.md
├── PRIVACY.md
├── SECURITY.md
├── LICENSE
├── Resources/
│   └── Info.plist              # App bundle 身份配置
├── Sources/
│   └── CodexPetNest/
│       ├── main.swift          # 入口
│       ├── AppDelegate.swift   # 生命周期 & 设置窗口
│       ├── MenuBarController.swift  # 菜单栏
│       ├── NestOverlayWindow.swift  # 悬浮巢窗 (NSPanel)
│       ├── NestRenderer.swift       # 巢渲染视图
│       ├── PetPositionReader.swift  # 读取 Codex pet 位置
│       ├── SettingsStore.swift      # 本地设置
│       ├── CodexPetAPI.swift        # API 客户端（网络层）
│       ├── KeychainManager.swift    # Keychain token 存储
│       ├── PackageManager.swift     # 下载/校验/安装
│       └── Widgets/
│           ├── ClockWidget.swift     # 时钟
│           ├── CountdownWidget.swift # 倒计时
│           ├── PomodoroWidget.swift  # 番茄钟
│           └── UsageIndicatorWidget.swift # 使用量指示器
├── UsageLimitReader.swift            # 读取 Codex 使用量日志
└── docs/
    ├── architecture.md         # 架构说明
    ├── permissions.md          # 权限说明
    └── specs/
        └── nest-package.md     # Nest 小窝包标准规范
```

### 架构概览

```
┌─────────────────────────────────┐
│         CodexPet Nest           │
│                                 │
│  MenuBarController              │  ← 菜单栏图标 & 菜单
│  NestOverlayWindow (NSPanel)    │  ← 透明悬浮巢窗
│    ├─ NestRenderer              │  ← 背景 + widget 容器
│    ├─ PetPositionReader         │  ← 读取 .codex-global-state.json
│    ├─ UsageLimitReader          │  ← 读取 logs_2.sqlite 使用量
│    └─ Widgets (Clock/Countdown/Pomodoro/Usage)
│                                 │
│  ┌─── API Layer ──────────────┐ │
│  │ CodexPetAPI                │ │  ← codexpet.xyz API 调用
│  │ PackageManager             │ │  ← 下载/校验/安装包
│  │ KeychainManager            │ │  ← token 安全存储
│  └────────────────────────────┘ │
│                                 │
│  SettingsStore                  │  ← ~/Library/.../settings.json
└─────────────────────────────────┘
```

详见 [docs/architecture.md](docs/architecture.md)。

### 鸣谢 / Acknowledgements

CodexPet Nest 的悬浮伴随窗口方案受 [codex-pet-limit-rings](https://github.com/petergpt/codex-pet-limit-rings) 启发——该项目由 petergpt 开发并以 MIT 协议开源，展示了一种无需修改 Codex 即可让透明置顶窗口跟随 Codex pet 移动的实现方式。

CodexPet Nest 是一个独立项目，专注于宠物小窝、小组件、市场安装与创作者上传流程。除非后续项目材料中明确声明，否则 CodexPet Nest 与 codex-pet-limit-rings、petergpt、OpenAI 或 Codex 均无关联。

### 许可证

FSL-1.1-MIT — CodexPet Nest 源码可见，可用于非竞争性用途，并将于 2028-05-06 自动转换为 MIT License。详见 [LICENSE](LICENSE)。

本仓库包含 CodexPet Nest bridge integrations 的再分发例外：非官方再分发、环境适配 fork 与兼容性改造是允许的，但必须清楚标明为非官方且不受官方支持，不得暗示 Ryan Niu 或 CodexPet Nest 的认可。

### 隐私与安全

详见 [PRIVACY.md](PRIVACY.md)、[SECURITY.md](SECURITY.md) 和 [docs/permissions.md](docs/permissions.md)。

---

<a name="english"></a>

## English

CodexPet Nest is a macOS desktop companion app for [codexpet.xyz](https://codexpet.xyz). It displays a transparent floating "nest overlay" next to your Codex Desktop pet, featuring built-in widgets like a clock, countdown, and Pomodoro timer.

### Important Notice

- CodexPet Nest is independent from Codex / OpenAI, unless official cooperation is announced in the future.
- **Does NOT** modify or inject into the Codex Desktop app bundle.
- **Does NOT** modify Codex global state. Reading position data is **ONLY** used to allow the nest to follow the pet.
- **Does NOT** support auto-switching of the active pet in Codex. After installing a pet, please select it manually in Codex settings.
- **Does NOT** upload your prompts, sessions, repository code, or project files.
- Fully uninstallable with no residues.

### System Requirements

- macOS 14 Sonoma or later
- Apple Silicon (arm64) — Intel support coming soon

### v0.1 Key Features

- **Transparent Floating Nest Window**: Follows the Codex pet or stays in a fixed position.
- **Built-in Widgets**:
  - **Clock** — Current time and date.
  - **Countdown** — Set and display target date/time.
  - **Pomodoro** — Focus and break timer.
  - **Usage Indicator** — Circular graph of Codex usage based on local logs (No API Key required).
- **Local Pet Management**:
  - Automatically scans and lists installed Codex pets.
  - Supports installing local pet ZIP packages.
  - Supports uninstalling app-managed pet packages.
  - Read-only identification of the current active pet.
- **Online Pet Marketplace**:
  - Browse and one-click download pets from [codexpet.xyz](https://codexpet.xyz) within the app.
  - Enforced SHA256 verification to ensure package integrity and safety.
- **Local Nest Skin Management**:
  - Install, preview, and switch nest appearances.
  - Nest skins are **purely static resource packages** (images + layout JSON), preventing any code execution.
- **Online Official Nest Marketplace**:
  - Browse and download officially designed nest skins.
  - Supports "Apply Now" for immediate application.
- **Security Assurance**:
  - Uses `SafeZipReader` for extraction, enforcing defenses against path traversal and symlink vulnerabilities.
  - Strictly limits package content; prohibits scripts and binary executables.
- **Multi-monitor Support**: Automatically adapts to multi-screen environments.

### Installation

1. Download `CodexPetNest.dmg` from [codexpet.xyz/downloads](https://codexpet.xyz/downloads).
2. Drag `CodexPet Nest.app` into your `Applications` folder.

> Upon first launch, if Gatekeeper warns "Developer cannot be verified," right-click the app in Finder → Open, or click "Open Anyway" in "System Settings → Privacy & Security."

### Usage Instructions

#### Switching Pets

1. Click "Install" in CodexPet Nest to install a new pet.
2. **Manual Step**: Open Codex Desktop's settings panel.
3. Find the newly installed pet under "Avatar/Pet" and select it.

#### Switching Nest Skins

1. Click "Nest Marketplace" or "Local Nests" in the menu bar.
2. Choose your preferred appearance and click "Apply Now."

### Uninstallation

1. Quit CodexPet Nest from the menu bar.
2. Delete `CodexPet Nest.app` from `Applications`.
3. (Optional) Delete the data directory: `~/Library/Application Support/CodexPet Nest/`.

### Build from Source

#### Quick Start

```bash
# Clone the repository
git clone https://github.com/RyanNiu/codexpet-nest.git
cd codexpet-nest

# Install dependencies — Xcode Command Line Tools required
xcode-select --install 2>/dev/null || echo "CLT already installed"

# Build debug version
make

# Build release version
make release

# Package as .app
make app

# Run the app
make run

# Clean build artifacts
make clean
```

#### Make Target Descriptions

| Command             | Description                                          |
| ------------------- | ---------------------------------------------------- |
| `make` / `make all` | Compile debug version (binary at `.build/CodexPetNest`) |
| `make debug`        | Same as `make` (debug build)                         |
| `make release`      | Compile release version (with `-O` optimization)      |
| `make app`          | Compile release and package as `CodexPet Nest.app`   |
| `make run`          | Package app and launch                               |
| `make clean`        | Remove the `.build/` directory                       |

#### Why not Swift Package Manager?

The current environment's SPM has toolchain compatibility issues (`PackageDescription` symbols undefined), so this project uses a `Makefile` + direct `swiftc` compilation. The Makefile automatically handles source file discovery, framework linking, and SDK paths.

To restore SPM builds, ensure Swift toolchain version ≥ 6.0 and CLT is fully installed.

### Development Commands

```bash
# ─── Build & Run ──────────────────────────────

make                      # Compile debug version (most common for dev)
make app                  # Package as .app (verification before release)
make run                  # Package and launch (full feature verification)
make clean && make dev    # Recompile after cleaning

# ─── Test API (Requires codexpet site dev server) ───

# Check version
curl -s https://codexpet.xyz/api/desktop/version | jq

# Pet list
curl -s "https://codexpet.xyz/api/pets?page=1" -H "Accept: application/json" | jq

# Pet details
curl -s "https://codexpet.xyz/api/pets/codie" -H "Accept: application/json" | jq

# Pet download metadata
curl -s "https://codexpet.xyz/api/pets/codie/download" -H "Accept: application/json" | jq

# Nest list
curl -s "https://codexpet.xyz/api/nests?page=1" -H "Accept: application/json" | jq

# Device code request (POST)
curl -s -X POST https://codexpet.xyz/api/auth/device-code \
  -H "Content-Type: application/json" \
  -d '{"client":"codexpet-nest","platform":"macos"}' | jq

# ─── Local Development (Two Repositories) ──────

# 1. Start codexpet site dev server (In another terminal)
cd /path/to/codexpet
npm run dev &

# 2. Build nest app
cd /path/to/codexpet-nest
make run

# 3. Observe logs
# Console output can be viewed in the terminal or "Console.app"
# If API fails, check rewrites target port in next.config.ts

# ─── Debugging ─────────────────────────────────

# View compilation details (including warnings)
make clean && make 2>&1

# Typecheck a specific file
xcrun swiftc -sdk $(xcrun --show-sdk-path) -typecheck Sources/CodexPetNest/CodexPetAPI.swift

# Check app bundle structure
ls -R ".build/CodexPet Nest.app/Contents"

# View runtime logs
log stream --predicate 'process == "CodexPetNest"' --level debug

# ─── Version & Info ────────────────────────────

# Show Swift version
swift --version

# Show SDK path
xcrun --show-sdk-path

# Show Swift runtime path
xcrun --show-sdk-platform-path

# ─── Git ───────────────────────────────────────

git tag v0.1.0                          # Create version tag
git push origin v0.1.0                  # Push tag
# Note: Version numbers in README (0.1.0) should match
# AppDelegate.swift and NestOverlayWindow.swift
```

### Project Structure

```text
codexpet-nest/
├── Makefile                    # Build system
├── README.md
├── PRIVACY.md
├── SECURITY.md
├── LICENSE
├── Resources/
│   └── Info.plist              # App bundle configuration
├── Sources/
│   └── CodexPetNest/
│       ├── main.swift          # Entry point
│       ├── AppDelegate.swift   # Lifecycle & Settings window
│       ├── MenuBarController.swift  # Menu bar
│       ├── NestOverlayWindow.swift  # Floating nest window (NSPanel)
│       ├── NestRenderer.swift       # Nest rendering view
│       ├── PetPositionReader.swift  # Reads Codex pet position
│       ├── SettingsStore.swift      # Local settings
│       ├── CodexPetAPI.swift        # API client (Networking)
│       ├── KeychainManager.swift    # Keychain token storage
│       ├── PackageManager.swift     # Download/Verify/Install
│       └── Widgets/
│           ├── ClockWidget.swift     # Clock
│           ├── CountdownWidget.swift # Countdown
│           ├── PomodoroWidget.swift  # Pomodoro
│           └── UsageIndicatorWidget.swift # Usage indicator
├── UsageLimitReader.swift            # Reads Codex usage logs
└── docs/
    ├── architecture.md         # Architecture documentation
    ├── permissions.md          # Permissions documentation
    └── specs/
        └── nest-package.md     # Nest package standard specification
```

### Architecture Overview

```
┌─────────────────────────────────┐
│         CodexPet Nest           │
│                                 │
│  MenuBarController              │  ← Menu bar icon & menu
│  NestOverlayWindow (NSPanel)    │  ← Transparent floating window
│    ├─ NestRenderer              │  ← Background + widget container
│    ├─ PetPositionReader         │  ← Reads .codex-global-state.json
│    ├─ UsageLimitReader          │  ← Reads logs_2.sqlite usage
│    └─ Widgets (Clock/Countdown/Pomodoro/Usage)
│                                 │
│  ┌─── API Layer ──────────────┐ │
│  │ CodexPetAPI                │ │  ← codexpet.xyz API calls
│  │ PackageManager             │ │  ← Download/Verify/Install
│  │ KeychainManager            │ │  ← Secure token storage
│  └────────────────────────────┘ │
│                                 │
│  SettingsStore                  │  ← ~/Library/.../settings.json
└─────────────────────────────────┘
```

See [docs/architecture.md](docs/architecture.md) for details.

### Acknowledgements

CodexPet Nest's companion-window approach was inspired by [codex-pet-limit-rings](https://github.com/petergpt/codex-pet-limit-rings)—an MIT-licensed project by petergpt that demonstrates how a transparent, always-on-top window can follow the active Codex pet without patching Codex.

CodexPet Nest is an independent project focused on pet nests, widgets, marketplace installation, and creator workflows. Unless explicitly stated in future project materials, CodexPet Nest has no affiliation with codex-pet-limit-rings, petergpt, OpenAI, or Codex.

### License

FSL-1.1-MIT — CodexPet Nest source code is visible and can be used for non-competing purposes, and will automatically convert to the MIT License on 2028-05-06. See [LICENSE](LICENSE) for details.

This repository includes a redistribution exception for CodexPet Nest bridge integrations: unofficial redistributions, environment-adapted forks, and compatibility modifications are allowed, provided they are clearly marked as unofficial and not endorsed by Ryan Niu or CodexPet Nest.

### Privacy and Security

See [PRIVACY.md](PRIVACY.md), [SECURITY.md](SECURITY.md), and [docs/permissions.md](docs/permissions.md) for more information.

