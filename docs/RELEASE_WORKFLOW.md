# CodexPet Nest 发布流程

本文档说明如何发布 CodexPet Nest 的新版本并配置 Sparkle 自动更新。

## 1. 准备工作

确保安装了 Sparkle 的命令行工具（`generate_keys` 和 `generate_appcast`）。
如果使用 Homebrew 安装：
```bash
brew install sparkle
```

## 2. 生成签名密钥 (仅第一次)

如果你还没有 EdDSA 密钥，请生成一份：
```bash
generate_keys
```
这会生成 `sparkle_priv.key` 和 `sparkle_pub.key`。
- **私钥 (`sparkle_priv.key`)**: 绝对不要提交到代码仓库！将其存储在安全的密码管理器或 CI Secret 中。
- **公钥 (`sparkle_pub.key`)**: 复制其内容并更新 `Resources/Info.plist` 中的 `SUPublicEDKey`。

## 3. 更新版本号

1. 修改 `Resources/Info.plist`:
   - `CFBundleShortVersionString`: 例如 `0.1.3` (市场版本)
   - `CFBundleVersion`: 例如 `13` (递增的 Build 号)
2. 确保版本号与计划发布的标签一致。

## 4. 构建与签名

1. 使用 Xcode 或 `swift build` 构建 Release 版本。
2. 将 `.app` 打包为 `.dmg`。
3. 为 DMG 生成 Sparkle 签名：
   ```bash
   generate_appcast --prepare-enclosure CodexPet.Nest.dmg
   ```
   或者直接使用 `sign_update` (如果手动处理):
   ```bash
   export SPARKLE_PRIVATE_KEY="你的私钥内容"
   generate_keys --export-pubkey # 验证
   # 签名命令取决于 Sparkle 版本，通常推荐使用 generate_appcast 自动化
   ```

## 5. 发布到 GitHub

1. 创建新的 Release，标签为 `v0.1.3`。
2. 上传 `CodexPet.Nest.dmg` 作为 Asset。

## 6. 更新官网元数据

修改 `codexpet` 仓库中的 `src/worker.ts`:

1. 更新 `DESKTOP_NEST_CONFIG`:
   - `latestVersion`: `0.1.3`
   - `buildVersion`: `13`
   - `githubDownloadUrl`: 指向新的 GitHub Release Asset URL。
   - `sparkleSignature`: 填入第 4 步生成的签名。
   - `pubDate`: 更新为当前时间（RFC 822 格式）。
   - `size`: 填入 DMG 的文件大小（字节）。

2. 部署 Worker:
   ```bash
   npx wrangler deploy
   ```

## 7. 验证

1. 启动旧版本的 CodexPet Nest。
2. 点击菜单“检查更新...”。
3. 验证是否检测到新版本、显示 Release Notes 并能成功下载安装。
