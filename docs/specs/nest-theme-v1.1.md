# CodexPet Nest Theme Specification (v1.1 Draft)

This document defines the planned v1.1 theme model for CodexPet Nest. It is a
draft design for implementation and official theme validation. The current
shipping v1.0 package format remains documented in `docs/specs/nest-package.md`.

## 1. Goals

Nest Theme v1.1 upgrades nest skins from fixed widget slots into safe,
metric-driven visual themes.

The goals are:

- Keep third-party nest packages static and safe.
- Support richer official themes such as game status panels, trainer cards,
  work badges, desktop monitors, and day/night rooms.
- Make all dynamic behavior come from built-in metrics and built-in renderers.
- Preserve compatibility with v1.0 `layers` and `widgetSlots`.
- Prepare the schema for a future visual editor.

The v1.1 model is:

```text
Data Source -> Metric Catalog -> Theme Elements -> Renderer Presets
```

Theme packages may choose metrics and renderer presets, but they must not define
custom code, scripts, expressions, network requests, WebViews, or executable
logic.

## 2. Backward Compatibility

The app should continue to accept v1.0 `nest.json` files:

```json
{
  "schemaVersion": "1.0.0",
  "canvas": { "width": 200, "height": 150 },
  "layers": [],
  "widgetSlots": {}
}
```

v1.1 adds optional fields:

```json
{
  "schemaVersion": "1.1.0",
  "canvas": { "width": 320, "height": 180 },
  "layers": [],
  "widgetSlots": {},
  "metricBands": {},
  "elements": []
}
```

`widgetSlots` remains supported for existing built-in widgets. New official
themes should prefer `elements`.

## 3. Metrics

A metric is a stable product-level value exposed by the app. Themes reference
metrics by ID. Themes cannot compute arbitrary formulas.

### 3.1 Metric Value Types

Runtime metric values should be represented with a small fixed type set:

```swift
enum MetricValue {
    case number(Double)
    case ratio(Double)       // 0...1
    case percent(Double)     // 0...100
    case text(String)
    case boolean(Bool)
    case enumeration(String)
    case unavailable
}
```

Renderers must tolerate `unavailable` and missing values without crashing.

### 3.2 Usage Metrics

Initial usage metrics:

```text
usage.primary.used_percent
usage.primary.remaining_percent
usage.primary.remaining_ratio
usage.primary.remaining_band
usage.primary.reset_after_seconds
usage.primary.reset_label

usage.secondary.used_percent
usage.secondary.remaining_percent
usage.secondary.remaining_ratio
usage.secondary.remaining_band
usage.secondary.reset_after_seconds
usage.secondary.reset_label

usage.allowed
usage.limit_reached
usage.source
usage.plan_type
```

`primary` represents the short usage window. It is currently observed as the
5-hour bucket.

`secondary` represents the long usage window. It is currently observed as the
7-day bucket.

The app owns fixed derived metrics such as:

```text
remaining_percent = 100 - used_percent
remaining_ratio = remaining_percent / 100
```

Themes cannot define their own formulas.

### 3.3 System Time Metrics

Initial system metrics:

```text
system.time.hour
system.time.minute
system.time.day_period
system.time.weekday
system.time.is_weekend
system.time.hhmm
system.date.short
```

Recommended enum values:

```text
system.time.day_period: day | night
system.time.weekday: mon | tue | wed | thu | fri | sat | sun
system.time.is_weekend: true | false
```

The first implementation may define `day` as 06:00-17:59 and `night` as
18:00-05:59. This can become user-configurable later.

### 3.4 Timer Metrics

Timer metrics may be added after the first v1.1 usage/time implementation:

```text
pomodoro.state
pomodoro.remaining_ratio
pomodoro.remaining_label

countdown.remaining_label
countdown.state
```

Recommended enum values:

```text
pomodoro.state: idle | focus | break | paused
countdown.state: inactive | active | expired
```

## 4. Metric Bands

Percent metrics may expose a companion enum band. For example:

```text
usage.primary.remaining_band
```

Default bands:

| Band | Range |
| --- | --- |
| `empty` | `0` |
| `low` | `1...25` |
| `medium` | `26...50` |
| `high` | `51...75` |
| `full` | `76...100` |

Themes may override simple thresholds:

```json
{
  "metricBands": {
    "usage.primary.remaining_percent": [
      { "id": "empty", "max": 0 },
      { "id": "low", "max": 20 },
      { "id": "medium", "max": 50 },
      { "id": "high", "max": 80 },
      { "id": "full", "max": 100 }
    ]
  }
}
```

Rules:

- `metricBands` may only reference percent metrics.
- `max` values must be finite, ascending, and no greater than 100.
- Band IDs must be simple slug strings.
- Bands only affect companion enum metrics; they do not change numeric metrics.

## 5. Theme Elements

`elements` are ordered visual items drawn above `layers`. The first
implementation should support:

```text
staticImage
variantImage
metricText
metricGauge
```

Each element must have:

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | Unique within the theme. |
| `type` | string | One of the allowed element types. |
| `frame` | object | `{x, y, width, height}` in canvas coordinates. |

Elements that bind data must also include `metric`.

### 5.1 Static Image

`staticImage` draws one local asset.

```json
{
  "id": "frame",
  "type": "staticImage",
  "src": "assets/frame.png",
  "frame": { "x": 0, "y": 0, "width": 320, "height": 180 }
}
```

This element is optional because v1.0 `layers` already support static images.
It is useful for editor consistency.

### 5.2 Variant Image

`variantImage` chooses one local asset based on an enum or boolean metric.

```json
{
  "id": "day-night-icon",
  "type": "variantImage",
  "metric": "system.time.day_period",
  "frame": { "x": 248, "y": 18, "width": 36, "height": 36 },
  "variants": {
    "day": "assets/sun.png",
    "night": "assets/moon.png"
  },
  "fallback": "assets/sun.png"
}
```

Use cases:

- Sun/moon switching from `system.time.day_period`.
- Low quota warning art from `usage.primary.remaining_band`.
- Pomodoro focus/break art when timer metrics are available.

### 5.3 Metric Text

`metricText` renders text derived from a metric.

```json
{
  "id": "mp-text",
  "type": "metricText",
  "metric": "usage.primary.remaining_percent",
  "frame": { "x": 214, "y": 74, "width": 72, "height": 18 },
  "style": {
    "fontSize": 12,
    "fontWeight": "bold",
    "color": "#FFFFFF",
    "suffix": "%"
  }
}
```

Allowed initial style fields:

```text
fontSize
fontWeight: regular | medium | semibold | bold
color
alignment: left | center | right
prefix
suffix
fallbackText
```

### 5.4 Metric Gauge

`metricGauge` renders a ratio or percent metric with a built-in gauge renderer.

```json
{
  "id": "mp-orb",
  "type": "metricGauge",
  "metric": "usage.primary.remaining_ratio",
  "renderer": "circleFill",
  "frame": { "x": 226, "y": 94, "width": 56, "height": 56 },
  "style": {
    "fillColor": "#2E7BFF",
    "trackColor": "#071B38",
    "direction": "bottomToTop"
  }
}
```

Initial gauge renderers:

```text
ringStroke
linearBar
circleFill
```

Recommended shared style fields:

```text
fillColor
trackColor
opacity
```

`ringStroke` style fields:

```text
lineWidth
startAngle
clockwise
lineCap: butt | round | square
```

`linearBar` style fields:

```text
cornerRadius
direction: leftToRight | rightToLeft | bottomToTop | topToBottom
```

`circleFill` style fields:

```text
direction: bottomToTop | topToBottom | leftToRight | rightToLeft
clipShape: circle
```

The first implementation can treat `clipShape` as fixed to `circle`.

## 6. Full Example

```json
{
  "schemaVersion": "1.1.0",
  "canvas": { "width": 320, "height": 180 },
  "layers": [
    {
      "id": "bg",
      "type": "image",
      "src": "assets/legend-ui.png",
      "frame": { "x": 0, "y": 0, "width": 320, "height": 180 }
    }
  ],
  "metricBands": {
    "usage.primary.remaining_percent": [
      { "id": "empty", "max": 0 },
      { "id": "low", "max": 20 },
      { "id": "medium", "max": 50 },
      { "id": "high", "max": 80 },
      { "id": "full", "max": 100 }
    ]
  },
  "elements": [
    {
      "id": "sky-icon",
      "type": "variantImage",
      "metric": "system.time.day_period",
      "frame": { "x": 250, "y": 14, "width": 32, "height": 32 },
      "variants": {
        "day": "assets/sun.png",
        "night": "assets/moon.png"
      },
      "fallback": "assets/sun.png"
    },
    {
      "id": "hp-orb",
      "type": "metricGauge",
      "metric": "usage.secondary.remaining_ratio",
      "renderer": "circleFill",
      "frame": { "x": 28, "y": 94, "width": 56, "height": 56 },
      "style": {
        "fillColor": "#D92A2A",
        "trackColor": "#301012",
        "direction": "bottomToTop"
      }
    },
    {
      "id": "mp-orb",
      "type": "metricGauge",
      "metric": "usage.primary.remaining_ratio",
      "renderer": "circleFill",
      "frame": { "x": 226, "y": 94, "width": 56, "height": 56 },
      "style": {
        "fillColor": "#2E7BFF",
        "trackColor": "#071B38",
        "direction": "bottomToTop"
      }
    },
    {
      "id": "mp-text",
      "type": "metricText",
      "metric": "usage.primary.remaining_percent",
      "frame": { "x": 214, "y": 72, "width": 72, "height": 18 },
      "style": {
        "fontSize": 12,
        "fontWeight": "bold",
        "alignment": "center",
        "color": "#FFFFFF",
        "suffix": "%"
      }
    }
  ]
}
```

## 7. Validation Rules

Package validation must reject unsafe or malformed v1.1 themes.

Required checks:

- `schemaVersion` must be `1.0.0` or `1.1.0`.
- `canvas.width` and `canvas.height` must be positive finite values.
- `element.id` values must be unique.
- `element.type` must be in the allowed element type list.
- `metric` must be in the app's Metric Catalog.
- `renderer` must be in the allowed renderer list for the element type.
- `style` may only contain fields allowed by that element/renderer.
- `frame` values must be finite.
- `frame.width` and `frame.height` must be positive.
- Element frames should fit inside the canvas.
- The first implementation may allow up to 8 logical pixels of overflow for
  visual effects such as glow or shadow.
- `src`, `variants`, and `fallback` assets must be local relative paths inside
  the package.
- Referenced assets must exist and pass the existing image type and size checks.
- `metricBands` may only reference percent metrics.
- `metricBands` thresholds must be ascending and end at or below 100.

The package must still reject scripts, binaries, WebViews, remote URLs, symlinks,
path traversal, and unsafe file types.

## 8. Runtime Architecture

Recommended Swift modules:

```text
MetricValue.swift
MetricCatalog.swift
MetricSnapshot.swift
MetricProvider.swift
UsageMetricProvider.swift
SystemMetricProvider.swift

NestThemeElement.swift
NestElementRenderer.swift
MetricTextRenderer.swift
MetricGaugeRenderer.swift
VariantImageRenderer.swift
```

`NestRenderer` should evolve toward these responsibilities:

- Load the active nest layout.
- Draw static `layers`.
- Create renderers for `elements`.
- Maintain or subscribe to a shared metric snapshot.
- Push updated snapshots into element renderers.
- Keep v1.0 `widgetSlots` working.

Usage data should be read once per refresh cycle by a shared provider. Existing
usage views should avoid each creating their own `UsageLimitReader`.

Recommended refresh intervals:

| Provider | Interval |
| --- | --- |
| Usage | 60 seconds |
| System time | 30-60 seconds |
| Pomodoro/countdown | 1 second when active |

Renderers should not know where metrics come from.

## 9. Official Theme Validation

The first v1.1 implementation should be validated with four official themes:

### Basket Pomodoro Nest

Purpose:

- Validate that a built-in widget can live inside a v1.1 nest composition.
- Place the pet inside a cozy basket instead of beside the nest.
- Keep the theme visually simple with a single Pomodoro timer surface.

### Legend Status Nest

Purpose:

- Validate `circleFill`.
- Map 7-day remaining quota to HP.
- Map 5-hour remaining quota to MP.
- Place the pet inside the center of a dark fantasy building.

### Trainer Card Nest

Purpose:

- Validate dense text layout.
- Show plan, 5-hour quota, 7-day quota, reset labels, and source.
- Validate enum-driven badges or images from `remaining_band`.
- Place the pet inside the profile portrait slot.

### Nest Terminal

Purpose:

- Validate system time text and linear quota bars.
- Place the pet inside a retro computer screen.
- Validate that larger v1.1 canvases avoid pet and background compression.

If these themes are possible without new package code execution, the v1.1
abstraction is strong enough for the next editor step.

## 10. Future Editor Mapping

The future visual editor can map directly to this schema:

```text
Add element
Choose type
Choose metric
Choose renderer preset
Move and resize frame
Adjust colors, text, direction, and variants
Export static zip package
```

The editor should never ask users to write formulas or executable logic.
