# CodexPet Nest 发布与打标签指南

本文档介绍如何利用 GitHub Actions 自动发布 CodexPet Nest 的新版本。

## 流程概览

只需简单的三步，GitHub 就会自动编译、打包并发布：

1. **修改版本号**：在 `Info.plist` 中更新版本。
2. **打标签 (Tag)**：在本地 Git 中标记版本。
3. **推送 (Push)**：将标签推送到远程仓库，触发自动化流程。

---

## 详细步骤

### 第一步：准备版本

1. 打开 `Resources/Info.plist`。
2. 找到 `CFBundleShortVersionString` 和 `CFBundleVersion`。
3. 修改为你想要发布的版本号（例如 `0.1.0`）。

### 第二步：打标签

在终端执行以下命令（以 `v0.1.0` 为例）：

```bash
# 确保代码已提交
git add .
git commit -m "release: v0.1.0"

# 打上版本标签
git tag v0.1.0
```

### 第三步：推送到 GitHub

推送标签会立即触发 GitHub Actions 自动化构建：

```bash
git push origin main --tags
```

---

## 自动化发生了什么？

当你推送标签后，GitHub 会自动执行以下操作：

1. **启动虚拟机**：开启一台 macOS 最新版服务器。
2. **编译代码**：运行 `make app` 构建应用包。
3. **制作安装包**：运行 `make dmg` 生成 `.dmg` 文件。
4. **创建 Release**：在 GitHub "Releases" 页面创建一个新版本。
5. **上传附件**：将生成的 `CodexPet Nest.dmg` 自动挂载到该版本下供用户下载。

---

## 如何本地测试？

在正式推送标签前，你可以在本地运行以下命令验证打包是否正常：

```bash
make clean
make dmg
```

成功后，你可以在 `.build/` 目录下找到生成的 `CodexPet Nest.dmg`。

## 常见问题

- **标签打错了怎么办？**
  - 本地删除：`git tag -d v0.1.0`
  - 远程删除：`git push origin :refs/tags/v0.1.0`
- **Actions 失败了怎么办？**
  - 前往 GitHub 项目页面的 **Actions** 标签查看报错日志。
