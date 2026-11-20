"""Draws the app icon: a glowing cinema screen over rows of seats, with one red seat in the
best spot. Writes the light, dark and tinted 1024 px icons into AppIcon.appiconset.

Run: python3 scripts/gen_icon.py   (or: make icon)

Drawn at 4x and scaled down for smooth edges. iOS rounds the corners itself, so the image is
a full square with no transparency (except the tinted version, which iOS colours in).
"""
import json
import math
import pathlib

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "Screenwise" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
S = 4096  # working size; the output is 1024
K = S / 1024  # 1 design unit = 1 px of the final icon

ACCENT = (255, 74, 82)  # a brighter take on the app's red, so it glows on black


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def vertical_gradient(size, top, bottom):
    w, h = size
    col = Image.new("RGB", (1, h))
    for y in range(h):
        col.putpixel((0, y), lerp(top, bottom, y / (h - 1)))
    return col.resize((w, h))


def radial(size, centre, radius, colour, strength):
    """A soft round glow as an RGBA layer."""
    layer = Image.new("L", size, 0)
    d = ImageDraw.Draw(layer)
    cx, cy = centre
    steps = 60
    for i in range(steps, 0, -1):
        r = radius * i / steps
        a = round(255 * strength * (1 - i / steps) ** 1.6)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=a)
    out = Image.new("RGBA", size, colour + (0,))
    out.putalpha(layer)
    return out


def screen_shape(draw, box, bulge, fill):
    """The screen: a wide rectangle whose bottom edge curves down a little, like a real
    curved screen seen from the seats."""
    x0, y0, x1, y1 = box
    pts = [(x0, y0)]
    n = 80
    for i in range(n + 1):  # top edge curves up slightly at the middle
        t = i / n
        pts.append((x0 + (x1 - x0) * t, y0 - bulge * 0.35 * math.sin(math.pi * t)))
    for i in range(n + 1):  # bottom edge curves down at the middle
        t = 1 - i / n
        pts.append((x0 + (x1 - x0) * t, y1 + bulge * math.sin(math.pi * t)))
    draw.polygon(pts, fill=fill)


# Rows from the back to the front: (top y at the centre, chair width, height, gap, count,
# curve, top colour, bottom colour). Nearer rows are bigger and darker, and each row curves
# round the screen, so its ends sit higher. The front row has an even count, so the red seat
# behind it shows through the middle gap.
ROWS = [
    (548, 66, 76, 14, 9, 18, (92, 94, 110), (40, 40, 48)),
    (616, 104, 120, 20, 7, 30, (104, 106, 124), (34, 34, 42)),
    (792, 176, 250, 40, 4, 46, (58, 58, 68), (12, 12, 15)),
]
BEST = (1, 3)  # row 2, middle chair


def chairs(row):
    yc, w, h, gap, count, curve, _, _ = row
    total = count * w + (count - 1) * gap
    start = 512 - total / 2
    for i in range(count):
        x = start + i * (w + gap)
        u = (x + w / 2 - 512) / (total / 2)  # -1 at the left end, 1 at the right
        yield i, (x, yc - curve * u * u, w, h)


def chair_mask(size, x, y, w, h):
    """A chair back seen from behind: a soft round top and square bottom."""
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [x * K, y * K, (x + w) * K, (y + h) * K], w * 0.42 * K, fill=255, corners=(True, True, False, False))
    return m


def draw_icon(tinted=False):
    size = (S, S)
    if tinted:
        img = Image.new("RGBA", size, (0, 0, 0, 0))
    else:
        img = vertical_gradient(size, (24, 24, 30), (8, 8, 10)).convert("RGBA")
        # Light from the screen falling on the room.
        img = Image.alpha_composite(img, radial(size, (S / 2, 420 * K), 560 * K, (170, 190, 255), 0.30))

    # Light beam from the screen down over the seats.
    beam = Image.new("L", size, 0)
    bd = ImageDraw.Draw(beam)
    bd.polygon([(190 * K, 410 * K), (834 * K, 410 * K), (1024 * K, 1024 * K), (0, 1024 * K)], fill=90)
    fade = vertical_gradient(size, (255, 255, 255), (0, 0, 0)).convert("L")
    beam = ImageChops.multiply(beam, fade).filter(ImageFilter.GaussianBlur(40 * K))
    beam_layer = Image.new("RGBA", size, (210, 222, 255, 0))
    beam_layer.putalpha(beam)
    img = Image.alpha_composite(img, beam_layer)

    # The screen, with a soft glow round it.
    box = (176 * K, 196 * K, 848 * K, 418 * K)
    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    screen_shape(ImageDraw.Draw(glow), box, 18 * K, (190, 208, 255, 255))
    glow = glow.filter(ImageFilter.GaussianBlur(46 * K))
    glow.putalpha(glow.getchannel("A").point(lambda a: round(a * 0.85)))
    img = Image.alpha_composite(img, glow)

    scr = Image.new("RGBA", size, (0, 0, 0, 0))
    screen_shape(ImageDraw.Draw(scr), box, 18 * K, (255, 255, 255, 255))
    shade = vertical_gradient(size, (255, 255, 255), (206, 220, 255))
    scr = Image.composite(shade.convert("RGBA"), scr, scr.getchannel("A"))
    img = Image.alpha_composite(img, scr)

    # Chairs, back row first so nearer rows cover it.
    for r, row in enumerate(ROWS):
        top_c, bottom_c = row[6], row[7]
        for i, (x, y, w, h) in chairs(row):
            mask = chair_mask(size, x, y, w, h)
            if (r, i) == BEST:
                # The best seat, red with a soft glow.
                halo = Image.new("RGBA", size, (255, 255, 255, 0) if tinted else ACCENT + (0,))
                halo.putalpha(mask.filter(ImageFilter.GaussianBlur(34 * K)).point(lambda a: round(a * 0.95)))
                img = Image.alpha_composite(img, halo)
                fill = vertical_gradient(size, (255, 255, 255), (230, 230, 230)) if tinted else \
                    vertical_gradient(size, (255, 110, 116), (214, 40, 50))
            elif tinted:
                fill = vertical_gradient(size, (170, 170, 176), (70, 70, 76))
            else:
                # Lit from the screen at the top, dark lower down.
                fill = Image.new("RGB", size)
                band = vertical_gradient((S, round(h * K)), top_c, bottom_c)
                fill.paste(band, (0, round(y * K)))
            layer = fill.convert("RGBA")
            layer.putalpha(mask)
            img = Image.alpha_composite(img, layer)

    out = img.resize((1024, 1024), Image.LANCZOS)
    if tinted:
        # iOS tints a greyscale image; keep the shapes and drop colour.
        grey = out.convert("LA")
        return grey.convert("RGBA")
    return out.convert("RGB")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    light = draw_icon()
    light.save(OUT / "AppIcon.png")
    light.save(OUT / "AppIcon-dark.png")  # already dark, so the dark icon is the same picture
    draw_icon(tinted=True).save(OUT / "AppIcon-tinted.png")
    contents = {
        "images": [
            {"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
            {"appearances": [{"appearance": "luminosity", "value": "dark"}], "filename": "AppIcon-dark.png",
             "idiom": "universal", "platform": "ios", "size": "1024x1024"},
            {"appearances": [{"appearance": "luminosity", "value": "tinted"}], "filename": "AppIcon-tinted.png",
             "idiom": "universal", "platform": "ios", "size": "1024x1024"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (OUT / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    print(f"wrote the app icon to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
