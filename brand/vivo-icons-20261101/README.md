# vivo 合规图标（2026-11-01 生成）

按 vivo 开放平台《开放平台应用审核规范》2.7 与《开发者平台应用审核规则》2.1.1 生成，
源文件 `../app_icon_1024_flat.png`（1024×1024，直角满铺、无透明通道），用 LANCZOS 缩放。

## 取图对照

| 文件 | 尺寸 | 用在哪 |
|---|---|---|
| `vivo-icon-512.png` | 512×512，211KB | **vivo 后台上传 icon（主用）** |
| `vivo-icon-256.png` | 256×256，61KB | 后台上传备选（vivo 同时接受 256 或 512） |
| `vivo-icon-384.png` | 384×384，126KB | APK 内置 `mipmap-xxhdpi` |
| `vivo-icon-192.png` | 192×192，37KB | APK 内置 `mipmap-hdpi` |

APK 内置若全部替换，四档对应关系为：hdpi 192、xhdpi 256、xxhdpi 384、xxxhdpi 512
（即 512 那张同时兼 `mipmap-xxxhdpi`，256 那张兼 `mipmap-xhdpi`）。

## vivo 规则要点（生成时已满足）

- 尺寸 512×512（或 256×256），格式 PNG（也接受 webp）
- 大小不超过 500KB
- **直角图标**：不得有圆角切边留下的白边/黑边，本套无 alpha 通道、四角满铺
- 不得模糊、拉伸、压缩
- 不得含"官方/正版/热门/首发"等角标或诱导性红点数字
- 安装到手机显示的图标须与后台提交的 icon 一致

## 复现命令

```bash
cd brand && python3 - <<'PY'
from PIL import Image
src = Image.open("app_icon_1024_flat.png").convert("RGB")
for name, size in [("vivo-icon-512.png",512),("vivo-icon-256.png",256),
                   ("vivo-icon-384.png",384),("vivo-icon-192.png",192)]:
    src.resize((size,size), Image.LANCZOS).save(
        "vivo-icons-20261101/"+name, "PNG", optimize=True)
PY
```
