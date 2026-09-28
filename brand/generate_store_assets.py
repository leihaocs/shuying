#!/usr/bin/env python3
"""从 app_icon_1024.png 生成上架所需图标/特色图。"""
import os
from PIL import Image, ImageDraw, ImageFont

BASE = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(BASE, 'app_icon_1024.png')
img = Image.open(src).convert('RGBA')

# 取四角与中心颜色均值作为背景填充色，避免圆角外出现明显接缝
# 取图标四角主背景色（避开透明圆角外与中心内容），用于填底和去水印
samples = [(80, 80), (944, 80), (80, 944), (944, 944)]
r = g = b = n = 0
for x, y in samples:
    c = img.getpixel((x, y))
    if isinstance(c, tuple) and c[3] > 128:
        r += c[0]; g += c[1]; b += c[2]; n += 1
bg_color = (r // n, g // n, b // n) if n else (20, 25, 60)

# 去水印：右下角浅灰水印块填成图标主背景色（覆盖 880~1024 的右下角背景区）
for y in range(880, 1024):
    for x in range(880, 1024):
        c = img.getpixel((x, y))
        if isinstance(c, tuple):
            img.putpixel((x, y), bg_color + (c[3],))

# 1. App Store 1024×1024（无 alpha）
flat = Image.new('RGBA', (1024, 1024), bg_color)
flat = Image.alpha_composite(flat, img).convert('RGB')
flat.save(os.path.join(BASE, 'app_icon_1024_flat.png'))
print('→ app_icon_1024_flat.png')

# 2. Google Play 512×512
flat.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(BASE, 'app_icon_512.png'))
print('→ app_icon_512.png')

# 3. 鸿蒙 216×216
flat.resize((216, 216), Image.Resampling.LANCZOS).save(os.path.join(BASE, 'app_icon_216.png'))
print('→ app_icon_216.png')

# 4. Google Play 特色图 1024×500
fg = Image.new('RGB', (1024, 500), bg_color)
draw = ImageDraw.Draw(fg)
# 绘制一个更亮的圆形背景托底
icon_on_fg = flat.resize((256, 256), Image.Resampling.LANCZOS)
# 居中偏左
x, y = 120, 122
fg.paste(icon_on_fg, (x, y))
# 文字
font_path = '/System/Library/Fonts/STHeiti Light.ttc'
font_big = ImageFont.truetype(font_path, 72)
font_small = ImageFont.truetype(font_path, 38)
text_x = x + 256 + 60
draw.text((text_x, 175), '书影温故', fill=(255, 255, 255), font=font_big)
draw.text((text_x, 265), 'Reel&Read', fill=(200, 200, 210), font=font_small)
fg.save(os.path.join(BASE, 'feature_graphic_1024x500.png'))
print('→ feature_graphic_1024x500.png')
