# 生成 SPCL 图标与 Logo。
# 输出：
#   Plain Craft Launcher 2\Images\icon.ico        （多尺寸：16/24/32/48/64/128/256）
#   Plain Craft Launcher 2\Images\Heads\Logo.png  （256x256，用于关于页与离线皮肤资源包）
# 视觉：蓝色圆角底 + 白色 S，不使用 Minecraft 官方素材。

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
IMAGES = ROOT / "Plain Craft Launcher 2" / "Images"
SIZE = 1024
ICON_SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]


def load_font(size: int):
    for name in ("segoeuib.ttf", "arialbd.ttf", "arial.ttf"):
        path = Path("C:/Windows/Fonts") / name
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# 蓝色纵向渐变，色相保持在蓝色区间
for y in range(SIZE):
    t = y / (SIZE - 1)
    draw.line(
        [(0, y), (SIZE, y)],
        fill=(
            round(19 + (72 - 19) * t),
            round(112 + (144 - 112) * t),
            round(243 + (245 - 243) * t),
            255,
        ),
    )

# 圆角遮罩
mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, SIZE - 1, SIZE - 1), radius=220, fill=255)
img.putalpha(mask)

# 白色 S
draw = ImageDraw.Draw(img)
font = load_font(620)
text = "S"
bbox = draw.textbbox((0, 0), text, font=font)
x = (SIZE - (bbox[2] - bbox[0])) / 2 - bbox[0]
y = (SIZE - (bbox[3] - bbox[1])) / 2 - bbox[1]
draw.text((x, y), text, font=font, fill=(255, 255, 255, 255))

(IMAGES / "Heads").mkdir(parents=True, exist_ok=True)
img.resize((256, 256), Image.LANCZOS).save(IMAGES / "Heads" / "Logo.png")
img.save(IMAGES / "icon.ico", sizes=ICON_SIZES)
print("wrote", IMAGES / "icon.ico")
print("wrote", IMAGES / "Heads" / "Logo.png")