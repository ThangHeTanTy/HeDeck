"""Vẽ bộ icon cho HeDeck.

Chủ thể là đầu chú hề — chữ "He" trong HeDeck chính là "hề" — đội mũ chóp,
mũi đỏ, tóc xù ba màu lấy từ bảng màu của app. Chữ "Deck" dựng khối 3D
đặt phía dưới.

Xuất ra:
  icon.png             1024px, nền đầy đủ, dùng cho icon truyền thống
  icon_foreground.png  1024px, nền trong suốt, dùng cho adaptive icon Android
  preview.png          bản xem thử trên nền sáng và nền tối
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

S = 1024                      # cạnh ảnh gốc
SS = 4                        # vẽ lớn gấp 4 rồi thu nhỏ cho mượt viền
FONT = "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf"
OUT = os.path.dirname(os.path.abspath(__file__))

# Bảng màu dùng chung với giao diện app
BG_DEEP = (15, 18, 24)
BG_LIFT = (37, 32, 66)
SKIN = (247, 231, 216)
SKIN_SHADE = (226, 200, 181)
NOSE = (226, 75, 74)
NOSE_HI = (255, 150, 145)
HAIR_A = (127, 119, 221)      # tím
HAIR_B = (93, 202, 165)       # ngọc
HAIR_C = (240, 153, 123)      # san hô
HAT = (127, 119, 221)
HAT_DARK = (86, 79, 168)
EYE = (28, 31, 40)
TEXT_FACE = (255, 255, 255)
TEXT_SIDE = (149, 141, 236)
TEXT_SIDE_DARK = (58, 52, 108)


def px(v):
    """Đổi toạ độ ảnh gốc sang canvas vẽ lớn."""
    return v * SS


def circle(d, cx, cy, r, fill):
    d.ellipse([px(cx - r), px(cy - r), px(cx + r), px(cy + r)], fill=fill)


def radial_background(size, inner, outer, cx, cy, radius):
    """Nền toả sáng từ tâm, làm chú hề nổi lên khỏi nền tối."""
    img = Image.new("RGB", (size, size), outer)
    d = ImageDraw.Draw(img)
    steps = 90
    for i in range(steps, 0, -1):
        t = i / steps
        r = radius * t
        col = tuple(
            round(outer[c] + (inner[c] - outer[c]) * (1 - t) ** 1.5)
            for c in range(3)
        )
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)
    return img.filter(ImageFilter.GaussianBlur(size / 60))


def draw_hair_tuft(d, cx, cy, r, color, shade):
    """Một búi tóc xù: cụm ba vòng tròn lệch nhau."""
    circle(d, cx, cy, r, shade)
    circle(d, cx - r * 0.45, cy - r * 0.35, r * 0.72, color)
    circle(d, cx + r * 0.40, cy + r * 0.20, r * 0.62, color)
    circle(d, cx, cy - r * 0.55, r * 0.55, color)


def darker(c, k=0.72):
    return tuple(round(v * k) for v in c)


def draw_clown(d, cx, cy, scale=1.0):
    """Đầu chú hề. cx, cy là tâm khuôn mặt, tính theo toạ độ ảnh gốc."""
    f = 150 * scale                      # bán kính khuôn mặt

    # Tóc: ba búi hai bên, búi giữa nhỏ nhô lên dưới vành mũ
    draw_hair_tuft(d, cx - f * 1.02, cy - f * 0.12, f * 0.52, HAIR_A, darker(HAIR_A))
    draw_hair_tuft(d, cx + f * 1.02, cy - f * 0.12, f * 0.52, HAIR_C, darker(HAIR_C))
    draw_hair_tuft(d, cx - f * 0.88, cy + f * 0.42, f * 0.40, HAIR_B, darker(HAIR_B))
    draw_hair_tuft(d, cx + f * 0.88, cy + f * 0.42, f * 0.40, HAIR_B, darker(HAIR_B))

    # Khuôn mặt
    circle(d, cx, cy + f * 0.02, f, SKIN_SHADE)
    circle(d, cx, cy - f * 0.02, f * 0.985, SKIN)

    # Mũ chóp nghiêng
    hat_y = cy - f * 0.92
    d.polygon(
        [
            (px(cx - f * 0.62), px(hat_y)),
            (px(cx + f * 0.62), px(hat_y)),
            (px(cx + f * 0.30), px(hat_y - f * 0.92)),
        ],
        fill=HAT,
    )
    d.polygon(
        [
            (px(cx + f * 0.02), px(hat_y)),
            (px(cx + f * 0.62), px(hat_y)),
            (px(cx + f * 0.30), px(hat_y - f * 0.92)),
        ],
        fill=HAT_DARK,
    )
    # Vành mũ
    d.rounded_rectangle(
        [px(cx - f * 0.72), px(hat_y - f * 0.06),
         px(cx + f * 0.72), px(hat_y + f * 0.13)],
        radius=px(f * 0.10),
        fill=HAT_DARK,
    )
    # Quả bông trên chóp
    circle(d, cx + f * 0.30, hat_y - f * 0.97, f * 0.15, HAIR_B)

    # Mắt: hình bầu dục, kèm chấm sáng cho có hồn
    for sx in (-1, 1):
        ex = cx + sx * f * 0.36
        ey = cy - f * 0.12
        d.ellipse(
            [px(ex - f * 0.115), px(ey - f * 0.155),
             px(ex + f * 0.115), px(ey + f * 0.155)],
            fill=EYE,
        )
        circle(d, ex + f * 0.045, ey - f * 0.06, f * 0.045, (255, 255, 255))

    # Má hồng
    for sx in (-1, 1):
        circle(d, cx + sx * f * 0.62, cy + f * 0.28, f * 0.17,
               (243, 186, 178))

    # Miệng cười
    mouth = [px(cx - f * 0.50), px(cy + f * 0.02),
             px(cx + f * 0.50), px(cy + f * 0.78)]
    d.arc(mouth, start=20, end=160, fill=(196, 74, 82), width=int(px(f * 0.09)))

    # Mũi đỏ, đặt cuối để nằm trên miệng
    circle(d, cx, cy + f * 0.24, f * 0.20, darker(NOSE, 0.8))
    circle(d, cx, cy + f * 0.22, f * 0.185, NOSE)
    circle(d, cx - f * 0.06, cy + f * 0.16, f * 0.055, NOSE_HI)


def draw_3d_text(d, text, cx, baseline_y, size, depth=22, angle=32):
    """Chữ khối: xếp chồng nhiều bản sao lệch dần để tạo mặt bên."""
    font = ImageFont.truetype(FONT, int(px(size)))
    bbox = d.textbbox((0, 0), text, font=font)
    w = bbox[2] - bbox[0]
    h = bbox[3] - bbox[1]
    x = px(cx) - w / 2 - bbox[0]
    y = px(baseline_y) - h - bbox[1]

    dx = math.cos(math.radians(angle))
    dy = math.sin(math.radians(angle))
    layers = int(px(depth))

    for i in range(layers, 0, -1):
        t = i / layers
        col = tuple(
            round(TEXT_SIDE_DARK[c] + (TEXT_SIDE[c] - TEXT_SIDE_DARK[c]) * (1 - t))
            for c in range(3)
        )
        d.text((x + dx * i, y + dy * i), text, font=font, fill=col)

    # Viền tối mảnh giúp mặt chữ tách khỏi khối bên
    d.text((x + px(2.5), y + px(2.5)), text, font=font, fill=(45, 40, 84))
    d.text((x, y), text, font=font, fill=TEXT_FACE)


def compose(with_background=True, inset=1.0):
    """Dựng một ảnh icon. inset < 1 thu nhỏ nội dung cho adaptive icon."""
    canvas = S * SS

    if with_background:
        base = radial_background(canvas, BG_LIFT, BG_DEEP,
                                 canvas * 0.5, canvas * 0.42, canvas * 0.78)
        base = base.convert("RGBA")
    else:
        base = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))

    layer = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    draw_clown(d, S * 0.5, S * 0.375, scale=1.16)
    draw_3d_text(d, "Deck", S * 0.5, S * 0.875, size=225, depth=40, angle=34)

    if inset < 1.0:
        small = int(canvas * inset)
        layer = layer.resize((small, small), Image.LANCZOS)
        holder = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        off = (canvas - small) // 2
        holder.paste(layer, (off, off), layer)
        layer = holder

    base = Image.alpha_composite(base, layer)
    return base.resize((S, S), Image.LANCZOS)


def rounded(img, radius_ratio=0.22):
    """Bo góc cho bản xem thử, giống cách Android hiển thị."""
    mask = Image.new("L", (S * SS, S * SS), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, S * SS, S * SS], radius=int(S * SS * radius_ratio), fill=255
    )
    mask = mask.resize((S, S), Image.LANCZOS)
    out = img.copy()
    out.putalpha(mask)
    return out


if __name__ == "__main__":
    full = compose(with_background=True)
    full.convert("RGB").save(os.path.join(OUT, "icon.png"))

    fg = compose(with_background=False, inset=0.66)
    fg.save(os.path.join(OUT, "icon_foreground.png"))

    # Bản xem thử: nền sáng ở trên, nền tối ở dưới
    W, H, SPLIT = 1200, 600, 380
    prev = Image.new("RGB", (W, H), (233, 233, 236))
    prev.paste(Image.new("RGB", (W, H - SPLIT), (18, 21, 28)), (0, SPLIT))

    big = rounded(full).resize((300, 300), Image.LANCZOS)
    prev.paste(big, (60, 40), big)

    x = 430
    for size in (192, 132, 88):
        small = rounded(full).resize((size, size), Image.LANCZOS)
        prev.paste(small, (x, 40 + (192 - size) // 2), small)
        x += size + 46

    x = 60
    for size in (150, 108, 76):
        small = rounded(full).resize((size, size), Image.LANCZOS)
        prev.paste(small, (x, SPLIT + 35 + (150 - size) // 2), small)
        x += size + 46

    fg_prev = fg.resize((150, 150), Image.LANCZOS)
    holder = Image.new("RGB", (150, 150), (18, 21, 28))
    holder.paste(fg_prev, (0, 0), fg_prev)
    prev.paste(holder, (W - 210, SPLIT + 35))

    prev.save(os.path.join(OUT, "preview.png"))
    print("Đã xuất icon.png, icon_foreground.png, preview.png")
