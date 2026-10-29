# 鸿蒙分层图标制作记录

2026-10-29。用于修复云测试“应用图标资源需分层，尺寸需满足规范要求”。仅修改鸿蒙图标资源及引用。

- 原图：`brand/app_icon_1024_flat.png`。现有书本与胶片品牌图案；不再沿用低清的 114×114 桌面图标。
- 模式：内置 imagegen 编辑，透明输出；最终选用第二次生成的前景。首轮未采用。
- 原始选中输出：`/Users/leihao/.codex/generated_images/01a17d43-e7f9-7ae0-93ff-3eda1045198a/exec-f669e623-3278-4839-966a-6f3bc4d584b4.png`。
- 生产前景：`flutter_app/ohos/AppScope/resources/base/media/icon_foreground.png`。使用 macOS `sips` 规范化为 1024×1024，保留 alpha。
- 生产背景：同目录 `icon_background.png`，1024×1024、不透明纯色 `#101026`，无圆角裁切。简单纯色背景由本地代码生成。
- 配置：同目录 `layered_image.json`；`AppScope/app.json5` 和入口 Ability 的 `icon` 统一引用 `$media:layered_image`。启动窗口的独立图片配置保留。
- 已检查实际 alpha 合成效果，书本、胶片完整，透明孔洞显示背景色；图层尺寸与背景四角不透明检查通过。

## 最终采用的提示词

```text
Create a clean production foreground layer for this existing app icon. Use case: logo-brand / background-extraction. Keep the recognizable white/lavender open book at the bottom and gold filmstrip rising behind it, with the same arrangement, silhouette, tilt and palette as the reference. Render ONLY these two objects on genuine transparent background. Smooth crisp polished vector-like graphic with large solid opaque shapes and gentle clean shading. ALL object interiors must be opaque, no random translucency, no noise, no speckles, no fuzzy halos, no yellow or red fragments, no remaining background. Book pages: ivory and muted lavender, book cover dark indigo. Filmstrip: gold ribbon with neat square holes that are fully transparent; large central film frame should be a clean smooth dark muted gold/amber opaque shape. Preserve visual identity without adding new elements. Remove navy icon tile, all rounded-square corners, white corner areas and stray bottom-right patch. Important: transparency only OUTSIDE the objects and INSIDE the small sprocket holes; NO transparency/noise in the large central frame. Center complete artwork in an exact 1024x1024 square canvas with generous transparent space around the subject (subject fits within x=128..896 and y=160..848). No text, no watermark, no border, no diagram, no checkerboard.
```

资源与构建检查只能确认本地配置及成品，华为 UX 云测试结果仍需上传修复包后复核。
