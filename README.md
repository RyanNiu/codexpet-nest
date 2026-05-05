# CodexPet Nest

CodexPet Nest 是 [codexpet.xyz](https://codexpet.xyz) 的 macOS 桌面伴侣应用。它在你的 Codex Desktop 宠物旁边显示一个透明悬浮小窝（nest overlay），内置时钟、倒计时、番茄钟等小组件。

## 重要声明

- CodexPet Nest 与 Codex / OpenAI 相互独立，除非将来有官方合作。
- **不会** 修改或注入 Codex Desktop 的 app bundle。
- 读取本地 Codex pet 位置数据**仅用于**让 nest 跟随 pet 移动。
- **不会** 上传你的 prompts、session、仓库代码或项目文件。
- 上传 pet 包**仅**在用户明确选择并确认之后执行。
- 可完全卸载，不留残留。

## 系统要求

- macOS 14 Sonoma 或更高版本
- Apple Silicon (arm64) — Intel 支持后续添加

## 功能

- 透明置顶悬浮巢窗口，跟随 Codex pet 移动（或独立显示）
- **时钟小组件** — 当前时间和日期
- **倒计时小组件** — 设置目标日期/时间
- **番茄钟小组件** — 专注/休息计时器
- **本地宠物管理** — 扫描、安装本地 ZIP、卸载宠物，只读识别 Codex 当前使用的宠物
- **本地小窝外观管理** — 安装、预览、切换本地小窝外观包（nest skin），支持静态贴图自定义
- 菜单栏应用，支持快捷操作
- 右键菜单：打开/隐藏 nest、番茄钟、倒计时、浏览市场、上传、设置
- 本地设置持久化（JSON）
- OAuth 设备码登录（Keychain 安全存储）
- **在线宠物市场** — 在应用内浏览并下载 [codexpet.xyz](https://codexpet.xyz) 上的宠物包，支持 SHA256 校验安全安装
- 多显示器支持

## 安装

从 [codexpet.xyz/downloads](https://codexpet.xyz/downloads) 下载 `CodexPetNest.dmg`，将 app 拖入 Applications 即可。

> 首次运行时，如果 Gatekeeper 提示"无法验证开发者"，请在 Finder 中右键 app → 打开，或在「系统设置 → 隐私与安全性」中点击"仍要打开"。

## 卸载

1. 从菜单栏退出 CodexPet Nest。
2. 从 Applications 删除 `CodexPet Nest.app`。
3. （可选）删除数据目录 `~/Library/Application Support/CodexPet Nest/`。

## 从源码构建

### 快速开始

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

### Make 目标说明

| 命令 | 说明 |
|---|---|
| `make` / `make all` | 编译 debug 版本（二进制路径 `.build/CodexPetNest`） |
| `make debug` | 等同于 `make`（debug 构建） |
| `make release` | 编译 release 版本（开启 `-O` 优化） |
| `make app` | 编译 release 并打包为 `CodexPet Nest.app` |
| `make run` | 打包 app 并启动 |
| `make clean` | 删除 `.build/` 目录 |

### 为什么不用 Swift Package Manager？

当前环境的 SPM 存在 toolchain 兼容性问题（`PackageDescription` 符号未定义），因此本项目使用 `Makefile` + 直接 `swiftc` 编译。Makefile 会自动处理源文件发现、framework 链接和 SDK 路径。

如需恢复 SPM 构建，请确保 Swift toolchain 版本 ≥ 6.0 且 CLT 完整安装。

## 开发常用指令

```bash
# ─── 构建 & 运行 ──────────────────────────────

make                      # 编译 debug 版本（开发时最常用）
make app                  # 打包为 .app（发布前验证）
make run                  # 打包并启动（完整功能验证）
make clean && make        # 清理后重新编译

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

# 查看运行日志
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

## 项目结构

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
│       ├── PackageManager.swift     # 包下载/校验/安装
│       └── Widgets/
│           ├── ClockWidget.swift     # 时钟
│           ├── CountdownWidget.swift # 倒计时
│           ├── PomodoroWidget.swift  # 番茄钟
│           └── UsageIndicatorWidget.swift # 使用量指示器
├── UsageLimitReader.swift            # 读取 Codex 使用量日志
└── docs/
    ├── architecture.md         # 架构说明
    └── permissions.md          # 权限说明
```

## 架构概览

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

## 鸣谢 / Acknowledgements

CodexPet Nest 的悬浮伴随窗口方案受 [codex-pet-limit-rings](https://github.com/petergpt/codex-pet-limit-rings) 启发——该项目由 petergpt 开发并以 MIT 协议开源，展示了一种无需修改 Codex 即可让透明置顶窗口跟随 Codex pet 移动的实现方式。

CodexPet Nest 是一个独立项目，专注于宠物小窝、小组件、市场安装与创作者上传流程。除非后续项目材料中明确声明，否则 CodexPet Nest 与 codex-pet-limit-rings、petergpt、OpenAI 或 Codex 均无关联。

---

CodexPet Nest's companion-window approach was inspired by
[codex-pet-limit-rings](https://github.com/petergpt/codex-pet-limit-rings),
an MIT-licensed macOS companion app by petergpt that demonstrates how a
transparent, always-on-top window can follow the active Codex pet without
patching Codex.

CodexPet Nest is a separate project focused on pet nests, widgets,
marketplace installation, and creator upload workflows. It is not affiliated
with codex-pet-limit-rings, petergpt, OpenAI, or Codex unless explicitly stated
in future project materials.

## 许可证

MIT — 详见 [LICENSE](LICENSE)。

## 隐私与安全

详见 [PRIVACY.md](PRIVACY.md)、[SECURITY.md](SECURITY.md) 和 [docs/permissions.md](docs/permissions.md)。
