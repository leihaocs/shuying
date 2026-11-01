# vivo 上架截图（2026-11-01 生成）

4 个 Tab 各一张，直接取 `1080x1920/` 里的文件上传。

| 文件 | 内容 |
|---|---|
| `1080x1920/vivo-01-书架.png` | 书架（Tab 0） |
| `1080x1920/vivo-02-电影.png` | 电影（Tab 1） |
| `1080x1920/vivo-03-统计.png` | 统计（Tab 2） |
| `1080x1920/vivo-04-设置.png` | 设置（Tab 3） |

均为 1080×1920 PNG，单张 0.7–0.8MB，`raw-macos/` 是 retina 原始尺寸（984×1750）备份。

## 符合 vivo《应用审核规则》2.2.1

| 要求 | 本套 |
|---|---|
| 尺寸 320px ~ 3840px，长边 ≤ 短边 2 倍 | ✅ 1080×1920 |
| 单张不超过 5MB | ✅ 最大 0.8MB |
| 数量 4–8 张，统一横图或竖图 | ✅ 4 张，全部竖图 |
| 格式 webp / png / jpeg | ✅ PNG |
| 不得出现其他品牌外壳、水印、模糊拉伸 | ✅ 纯应用画面，无设备外框、无状态栏 |

## 生成方式

用 macOS 桌面版渲染（`flutter run -d macos --dart-define=SHUYING_SCREENSHOT=true --dart-define=SHUYING_TAB=n`），
窗口固定 492×875 逻辑像素，retina 下物理 984×1750，再放大到 1080×1920。
截图模式会自动载入示例数据并跳过隐私同意页，画面与真机一致。

窗口尺寸写在 `flutter_app/macos/Runner/MainFlutterWindow.swift`（仅桌面版，不影響安卓/iOS/鸿蒙）。

**为什么不用 iOS 模拟器**：该模拟器的 emoji 字体缺失，Tab 图标（📚🎬📊⚙️）会渲染成「？」方块；
macOS 走系统字体，emoji 与中文都正常。

**macOS 壳的两个必改点**（都在 `flutter_app/macos/Runner/MainFlutterWindow.swift`）：
1. 补 `com.bookmovie.revisit/backup` 的 `storagePath` channel——否则 `load()` 失败，
   自动同意隐私时抛「读取失败时禁止覆盖本机数据」，App 启动即崩、窗口时有时无
2. 窗口尺寸要在 `super.awakeFromNib()` 之后设，并延迟 1 秒再设一次——
   系统启动后会用 xib 默认 frame（800×600）覆盖回来

截图用 `screencapture -l<窗口ID>`（按窗口 ID，swift 从 CGWindowList 取），
只截 App 窗口本身，不受遮挡影响，也不会截到 IDE。

## 重新生成

```bash
cd flutter_app
for i in 0 1 2 3; do
  flutter run -d macos --dart-define=SHUYING_SCREENSHOT=true --dart-define=SHUYING_TAB=$i &
  # 等启动成功（日志出现 "Flutter run key commands"），窗口会自动定位到左上
  sleep 10; screencapture -x -R0,25,492,875 out/$i.png; kill %1
done
```

## 还差的材料（vivo 后台）

- 海报：1920×1080 横图，限 1 张（可选，不能用游戏截图）
- 其余（图标、备案、隐私链接等）见 `../vivo-icons-20261101/README.md`
