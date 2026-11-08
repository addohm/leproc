"""Draws the Leproc icon into art/ (512, 400, 256 and 128 px PNGs; 400 is the CurseForge and Wago
avatar), the in-game icon Leproc/Media/Icon.tga (128 px; the game reads TGA with power-of-two
sizes; the .toc's IconTexture uses it for the AddOns list and the addon compartment), and the
listing banner art/leproc-banner.png (1600x500: the icon, the name, the tagline and a sample row
of action buttons, one of them lit).

The design: a glowing gold square (an action button lit up) with a gold lightning bolt in it (a
proc), on a dark ember-red rounded square. The same build as Leboof's icon, our own art.

Needs Pillow, and the Inter font for the banner (bold and semibold): it looks in .scratch/fonts/
(Inter-Bold.ttf, Inter-SemiBold.ttf), or point LEPROC_FONT_BOLD and LEPROC_FONT_SEMI at the files.
Run: python3 art/make_logo.py
"""
import os
import pathlib

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
ART = ROOT / "art"
GAME_ICON = ROOT / "Leproc" / "Media" / "Icon.tga"
S = 2048  # draw big, downsample for smooth edges

EMBER_TOP = (140, 44, 28)
EMBER_BOT = (36, 8, 10)
RIM = (240, 150, 110)
GOLD_TOP = (255, 226, 130)
GOLD_BOT = (214, 150, 40)
GLOW = (255, 200, 90)


def vgrad(w, h, top, bot):
    g = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return g.resize((w, h))


def rounded_mask(box, radius):
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    return mask


def draw_icon():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    pad, radius = 40, 360
    body = rounded_mask([pad, pad, S - pad, S - pad], radius)

    # Background: ember gradient, a soft light from the top, a thin bright rim.
    bg = vgrad(S, S, EMBER_TOP, EMBER_BOT).convert("RGBA")
    light = Image.new("L", (S, S), 0)
    ImageDraw.Draw(light).ellipse([-S * 0.2, -S * 0.75, S * 1.2, S * 0.55], fill=60)
    light = light.filter(ImageFilter.GaussianBlur(160))
    bg = Image.composite(Image.new("RGBA", (S, S), (255, 255, 255, 255)), bg, light)
    img.paste(bg, (0, 0), body)

    rim = ImageChops.subtract(body, rounded_mask([pad + 34, pad + 34, S - pad - 34, S - pad - 34], radius - 34))
    img.paste(Image.new("RGBA", (S, S), RIM + (255,)), (0, 0), rim.point(lambda v: v * 0.5))

    # The lit button: a gold square frame, and a lightning bolt inside it.
    shape = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(shape)
    inset = 400
    d.rounded_rectangle([inset, inset, S - inset, S - inset], radius=120, outline=255, width=110)
    cx, cy = S / 2, S / 2
    bolt = [
        (cx + 150, cy - 520), (cx - 300, cy + 60), (cx - 20, cy + 60),
        (cx - 170, cy + 520), (cx + 300, cy - 80), (cx + 20, cy - 80),
    ]
    d.polygon(bolt, fill=255)

    # A dark drop shadow, the gold glow (strong: the button is lit), then the gold fill.
    shadow = shape.filter(ImageFilter.GaussianBlur(40)).point(lambda v: v * 0.6)
    img.paste(Image.new("RGBA", (S, S), (0, 0, 0, 255)), (0, 50), shadow)
    for blur, strength in ((180, 0.7), (70, 0.6)):
        glow = shape.filter(ImageFilter.GaussianBlur(blur)).point(lambda v, k=strength: v * k)
        img.paste(Image.new("RGBA", (S, S), GLOW + (255,)), (0, 0), ImageChops.multiply(glow, body))
    gold = vgrad(S, S, GOLD_TOP, GOLD_BOT).convert("RGBA")
    img.paste(gold, (0, 0), shape)

    # Keep everything inside the rounded square.
    img.putalpha(ImageChops.multiply(img.getchannel("A"), body))
    return img


FONTS = ROOT / ".scratch" / "fonts"
BOLD = os.environ.get("LEPROC_FONT_BOLD", str(FONTS / "Inter-Bold.ttf"))
SEMI = os.environ.get("LEPROC_FONT_SEMI", str(FONTS / "Inter-SemiBold.ttf"))
TAGLINE = "Reactive abilities glow, whatever your stance."


def tile(icon, size, lit):
    """A sample action button for the banner: the icon dimmed, or bright with a gold glow."""
    pad = size // 4
    out = Image.new("RGBA", (size + 2 * pad, size + 2 * pad), (0, 0, 0, 0))
    ic = icon.resize((size, size), Image.LANCZOS)
    if lit:
        ring = Image.new("L", out.size, 0)
        ImageDraw.Draw(ring).rounded_rectangle([pad - 6, pad - 6, pad + size + 6, pad + size + 6], radius=size // 5, outline=255, width=8)
        ring = ring.filter(ImageFilter.GaussianBlur(6))
        for _ in range(2):  # twice, for a strong glow
            out.paste(Image.new("RGBA", out.size, GLOW + (255,)), (0, 0), ring)
    else:
        r, g, b, a = ic.split()
        dim = Image.merge("RGB", (r, g, b)).point(lambda v: int(v * 0.35))
        ic = Image.merge("RGBA", (*dim.split(), a))
    out.alpha_composite(ic, (pad, pad))
    return out


def banner(icon):
    from PIL import ImageFont
    W, H = 1600, 500
    img = vgrad(W, H, EMBER_TOP, EMBER_BOT).convert("RGBA")
    light = Image.new("L", (W, H), 0)
    ImageDraw.Draw(light).ellipse([-200, -500, 1100, 300], fill=50)
    light = light.filter(ImageFilter.GaussianBlur(120))
    img = Image.composite(Image.new("RGBA", (W, H), (255, 255, 255, 255)), img, light)
    img.alpha_composite(icon.resize((380, 380), Image.LANCZOS), (60, 60))
    d = ImageDraw.Draw(img)
    title = ImageFont.truetype(BOLD, 140)
    tag = ImageFont.truetype(SEMI, 46)
    d.text((500, 52), "Leproc", font=title, fill=GOLD_TOP)
    d.line([(506, 228), (1530, 228)], fill=GOLD_BOT + (255,), width=3)
    d.text((506, 244), TAGLINE, font=tag, fill=(240, 222, 210))
    # A sample bar: four buttons, the third lit.
    x = 506
    for lit in (False, False, True, False):
        img.alpha_composite(tile(icon, 104, lit), (x - 26, 318))
        x += 104 + 22
    img.convert("RGB").save(ART / "leproc-banner.png")
    # Checks without looking at it: the text fits, the tiles sit inside the canvas.
    tb = d.textbbox((500, 52), "Leproc", font=title)
    tg = d.textbbox((506, 244), TAGLINE, font=tag)
    print("title", tb, "tagline", tg, "fits:", tg[2] < W - 40 and tb[3] < 228, "tiles end at x", x, "y", 318 + 156)


def main():
    big = draw_icon()
    for px in (512, 400, 256, 128):
        big.resize((px, px), Image.LANCZOS).save(ART / f"leproc-icon-{px}.png")
    GAME_ICON.parent.mkdir(exist_ok=True)
    big.resize((128, 128), Image.LANCZOS).save(GAME_ICON)
    print(f"Wrote art/leproc-icon-{{512,400,256,128}}.png and {GAME_ICON.relative_to(ROOT)}")
    if os.path.exists(BOLD) and os.path.exists(SEMI):
        banner(big)
        print("Wrote art/leproc-banner.png")
    else:
        print("No Inter font files (.scratch/fonts, or LEPROC_FONT_BOLD and LEPROC_FONT_SEMI): skipped the banner")


if __name__ == "__main__":
    main()
