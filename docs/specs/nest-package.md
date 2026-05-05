# CodexPet Nest Package Specification (v1.0.0)

本文档定义了 CodexPet Nest 小窝外观包（nest skin）的标准格式。

## 1. 包结构

一个标准的小窝外观包是一个 ZIP 压缩包，根目录必须包含以下文件：

```text
codexpet-package.json    # 核心包元数据
nest.json               # 布局与图层定义
preview.png             # 市场预览图 (建议 800x600 或更高)
assets/                 # 资源目录
  ├── background.png     # 背景图层 (必选)
  └── foreground.png     # 前景图层 (可选)
README.md               # (可选) 说明文档
LICENSE                 # (可选) 许可证
```

## 2. 内置动态渲染器 (Built-in Dynamic Renderers)

虽然大多数小窝是基于 `nest.json` 的静态配置，但 CodexPet Nest 支持官方内置的动态渲染器。这些渲染器直接在 Swift 代码中实现，以获得更高的性能和复杂的交互能力（如实时圆环）。

目前支持的内置 ID：
- `default`: 经典的横条式小窝。
- `capacity-orbit-nest`: 围绕宠物的动态 Usage 圆环。

> [!IMPORTANT]
> 在 v0.1 版本中，CodexPet Nest 仅支持上述官方内置的动态渲染器。出于安全性考虑，**严禁**在第三方小窝包中包含任何 JavaScript、WebView 或二进制执行文件。所有第三方小窝目前必须仅包含静态资源及 `nest.json` 布局配置。

## 3. codexpet-package.json

定义包的基本属性。

| 字段 | 类型 | 说明 | 示例 |
|---|---|---|---|
| `type` | string | 必须为 `codexpet.nest` | `codexpet.nest` |
| `schemaVersion` | string | 标准版本 | `1.0.0` |
| `id` | string | 唯一标识符 (slug) | `cozy-wood-desk` |
| `name` | string | 显示名称 | `Cozy Wood Desk` |
| `version` | string | 包版本 | `1.0.0` |
| `author` | string | 作者 | `CodexPet` |
| `description` | string | 描述 | `A warm wooden desktop nest.` |
| `preview` | string | 预览图路径 | `preview.png` |
| `layout` | string | 布局定义文件路径 | `nest.json` |
| `license` | string | 许可证 | `MIT` |
| `tags` | string[] | 标签 | `["official", "wood"]` |

## 3. nest.json

定义画布大小、图层叠加顺序以及小组件插槽（Widget Slots）。

### 3.1 Canvas

定义 nest 的总尺寸（逻辑像素）。

```json
"canvas": {
  "width": 240,
  "height": 180
}
```

### 3.2 Layers

图层数组，按数组顺序从下往上绘制。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | 唯一 ID |
| `type` | string | 目前仅支持 `image` |
| `src` | string | 相对路径 (assets/) |
| `frame` | object | `{x, y, width, height}` 坐标与大小 |

### 3.3 Widget Slots

定义内置小组件的摆放位置。

| 插槽名 | 说明 |
|---|---|
| `usage` | Codex 使用量环形图 |
| `clock` | 时钟/日期 |
| `countdown` | 倒计时 |
| `pomodoro` | 番茄钟 |

## 4. 限制与约束

为了系统性能与安全，nest package 受到以下严格限制：

- **禁止脚本**：不允许包含 `.js`, `.ts`, `.sh`, `.py` 或任何二进制执行文件。
- **静态资源**：只允许 `png`, `webp` 格式的本地图片。
- **无网络访问**：禁止使用远程图片 URL。
- **尺寸限制**：
  - `package.zip` 最大 5MB。
  - 单张图片最大 2MB。
  - Canvas 建议不超过 512x512。
- **内容限制**：禁止包含 WebView、iframe 或任何动态渲染代码。

## 5. 示例

### codexpet-package.json
```json
{
  "type": "codexpet.nest",
  "schemaVersion": "1.0.0",
  "id": "minimal-glass",
  "name": "Minimal Glass",
  "version": "1.0.0",
  "author": "CodexPet",
  "description": "A clean glass style nest.",
  "preview": "preview.png",
  "layout": "nest.json",
  "tags": ["minimal", "glass"]
}
```

### nest.json
```json
{
  "schemaVersion": "1.0.0",
  "canvas": { "width": 200, "height": 150 },
  "layers": [
    {
      "id": "bg",
      "type": "image",
      "src": "assets/bg.png",
      "frame": { "x": 0, "y": 0, "width": 200, "height": 150 }
    }
  ],
  "widgetSlots": {
    "clock": { "x": 10, "y": 10, "width": 180, "height": 40 },
    "pomodoro": { "x": 10, "y": 60, "width": 180, "height": 40 }
  }
}
```
