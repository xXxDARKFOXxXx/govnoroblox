"""Draws the OceanHUD icon set as transparent PNGs (cartoon 3D style).

Every shape is built from layers: dark outline, vertical gradient body, darker
lower inner edge, light upper inner edge, glossy highlight and a soft drop shadow.
Shapes are drawn at 1024 px and downsampled for clean anti-aliased edges.

Usage:  python tools/draw_icons.py [output_dir]
"""
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

N = 1024
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "assets")
os.makedirs(OUT, exist_ok=True)


# ---------- masks ----------
def blank():
    return Image.new("L", (N, N), 0)


def poly(points):
    m = blank()
    ImageDraw.Draw(m).polygon([(float(x), float(y)) for x, y in points], fill=255)
    return m


def ell(cx, cy, rx, ry, rot=0):
    m = blank()
    ImageDraw.Draw(m).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
    if rot:
        m = m.rotate(rot, center=(cx, cy), resample=Image.BICUBIC)
    return m


def rrect(x0, y0, x1, y1, r):
    m = blank()
    ImageDraw.Draw(m).rounded_rectangle((x0, y0, x1, y1), r, fill=255)
    return m


def union(*masks):
    out = masks[0]
    for m in masks[1:]:
        out = ImageChops.lighter(out, m)
    return out


def inter(a, b):
    return ImageChops.darker(a, b)


def minus(a, b):
    return ImageChops.subtract(a, b)


def ramp(lo, hi):
    return lambda v: 0 if v <= lo else 255 if v >= hi else int((v - lo) * 255 / (hi - lo))


def grow(m, px):
    """Dilate by about px pixels with rounded corners (blur + low threshold)."""
    if px <= 0:
        return m
    return m.filter(ImageFilter.GaussianBlur(px / 2)).point(ramp(2, 12))


def shrink(m, px):
    return ImageChops.invert(grow(ImageChops.invert(m), px))


def smooth(m, r):
    """Round sharp corners (blur + mid threshold)."""
    return m.filter(ImageFilter.GaussianBlur(r)).point(ramp(110, 146))


def star(cx, cy, r_out, r_in, points=5, rot=-90):
    pts = []
    for i in range(points * 2):
        a = math.radians(rot + i * 180 / points)
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(pts)


# ---------- paint ----------
def solid(c, a=255):
    return Image.new("RGBA", (N, N), tuple(c) + (a,))


def grad(c1, c2, y0, y1):
    y0, y1 = int(y0), max(int(y1), int(y0) + 1)
    g = blank()
    band = Image.linear_gradient("L").resize((N, y1 - y0))
    g.paste(band, (0, y0))
    if y1 < N:
        g.paste(255, (0, y1, N, N))
    return Image.composite(solid(c2), solid(c1), g)


def paint(canvas, mask, fill, alpha=1.0):
    layer = fill.copy()
    a = mask if alpha >= 1 else mask.point(lambda v: int(v * alpha))
    layer.putalpha(inter(a, fill.getchannel("A")))
    canvas.alpha_composite(layer)


def darker(c, k=0.72):
    return tuple(int(v * k) for v in c)


def part(cv, m, top, bottom, outline=(40, 18, 60), ow=22, gloss=True, bevel=True):
    box = m.getbbox()
    if not box:
        return
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    if ow:
        paint(cv, grow(m, ow), solid(outline))
    paint(cv, m, grad(top, bottom, y0, y1))
    if bevel:
        k = int(min(w, h) * 0.07) + 6
        low = minus(m, ImageChops.offset(m, 0, -k)).filter(ImageFilter.GaussianBlur(4))
        paint(cv, low, solid(darker(bottom, 0.7)), 0.55)
        high = minus(m, ImageChops.offset(m, 0, k)).filter(ImageFilter.GaussianBlur(4))
        paint(cv, high, solid((255, 255, 255)), 0.55)
    if gloss:
        g = inter(shrink(m, int(min(w, h) * 0.08) + 6),
                  ell(x0 + w * 0.42, y0 + h * 0.24, w * 0.36, h * 0.15))
        paint(cv, g.filter(ImageFilter.GaussianBlur(6)), solid((255, 255, 255)), 0.45)


def sparkle(cv, cx, cy, r, top=(255, 255, 200), bottom=(255, 196, 30)):
    m = smooth(star(cx, cy, r, r * 0.3, 4, -90), 3)
    paint(cv, grow(m, r * 0.5).filter(ImageFilter.GaussianBlur(r * 0.3)), solid((255, 230, 120)), 0.45)
    part(cv, m, top, bottom, outline=(190, 100, 10), ow=8, gloss=False, bevel=False)


def finish(cv, name, size=256, shadow=True, under=None):
    out = under if under is not None else Image.new("RGBA", (N, N), (0, 0, 0, 0))
    if shadow:
        a = cv.getchannel("A")
        sh = ImageChops.offset(grow(a, 8), 0, 26).filter(ImageFilter.GaussianBlur(14))
        paint(out, sh, solid((20, 8, 40)), 0.45)
    out.alpha_composite(cv)
    out.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))
    print("drew", name)


def canvas():
    return Image.new("RGBA", (N, N), (0, 0, 0, 0))


# ---------- icons ----------
def rebirth():
    cv = canvas()
    cx, cy, R, T = 512, 530, 290, 150

    def arrow(start, end):
        m = blank()
        ro = R + T / 2
        ImageDraw.Draw(m).arc((cx - ro, cy - ro, cx + ro, cy + ro), start, end, width=T, fill=255)
        th = math.radians(end - 3)
        px, py = cx + R * math.cos(th), cy + R * math.sin(th)
        tx, ty = -math.sin(th), math.cos(th)  # clockwise tangent (y down)
        nx, ny = math.cos(th), math.sin(th)
        head = poly([(px + nx * 150, py + ny * 150), (px - nx * 150, py - ny * 150),
                     (px + tx * 210, py + ty * 210)])
        return smooth(union(m, head), 6)

    part(cv, arrow(195, 325), (255, 190, 240), (232, 64, 190), outline=(78, 18, 120), ow=26)
    part(cv, arrow(15, 145), (255, 255, 255), (214, 180, 255), outline=(78, 18, 120), ow=26)
    sparkle(cv, 160, 170, 95)
    sparkle(cv, 880, 840, 75)
    sparkle(cv, 860, 190, 50)
    finish(cv, "Rebirth")


def gifts():
    cv = canvas()
    # Light rays behind the present.
    rays = blank()
    d = ImageDraw.Draw(rays)
    for i in range(12):
        a = math.radians(i * 30 + 15)
        da = math.radians(6)
        cx, cy = 512, 560
        d.polygon([(cx, cy), (cx + 490 * math.cos(a - da), cy + 490 * math.sin(a - da)),
                   (cx + 490 * math.cos(a + da), cy + 490 * math.sin(a + da))], fill=255)
    glow = canvas()  # drawn under the drop shadow so the rays stay clean and bright
    paint(glow, rays.filter(ImageFilter.GaussianBlur(6)), solid((255, 255, 225)), 0.5)
    paint(glow, ell(512, 560, 330, 330).filter(ImageFilter.GaussianBlur(80)), solid((255, 255, 210)), 0.55)
    outline = (100, 16, 30)
    part(cv, rrect(240, 480, 784, 900, 46), (255, 98, 98), (200, 20, 44), outline)
    part(cv, rrect(196, 368, 828, 512, 44), (255, 128, 128), (218, 36, 58), outline)
    gold = ((255, 244, 130), (246, 160, 16))
    part(cv, rrect(454, 380, 570, 896, 14), *gold, outline=outline, ow=14, gloss=False)
    loop_l = minus(ell(372, 276, 150, 96, 28), ell(388, 284, 66, 36, 28))
    loop_r = minus(ell(652, 276, 150, 96, -28), ell(636, 284, 66, 36, -28))
    part(cv, loop_l, *gold, outline=outline, ow=20)
    part(cv, loop_r, *gold, outline=outline, ow=20)
    part(cv, rrect(442, 250, 582, 380, 40), (255, 226, 90), (236, 140, 10), outline=outline, ow=20)
    sparkle(cv, 150, 250, 70)
    sparkle(cv, 880, 420, 55)
    finish(cv, "Gifts", under=glow)


def shop():
    cv = canvas()
    outline = (60, 18, 40)
    part(cv, rrect(220, 440, 804, 900, 34), (255, 255, 255), (214, 220, 238), outline)
    part(cv, rrect(268, 590, 486, 790, 26), (160, 230, 255), (36, 130, 236), outline, ow=16, gloss=False)
    paint(cv, poly([(300, 760), (380, 610), (420, 610), (340, 760)]), solid((255, 255, 255)), 0.55)
    part(cv, rrect(556, 600, 742, 900, 26), (110, 190, 255), (30, 86, 210), outline, ow=16, gloss=False)
    part(cv, ell(714, 760, 18, 18), (255, 240, 120), (240, 160, 10), outline, ow=6, gloss=False, bevel=False)
    # Striped awning with scalloped edge.
    x0, x1, top, bottom = 170, 854, 300, 470
    n = 6
    sw = (x1 - x0) / n
    awning = union(rrect(x0, top, x1, bottom, 30), *[ell(x0 + sw * (i + 0.5), bottom, sw / 2, sw / 2.4) for i in range(n)])
    paint(cv, grow(awning, 22), solid(outline))
    for i in range(n):
        band = inter(awning, rrect(x0 + sw * i, 0, x0 + sw * (i + 1), N, 0))
        if i % 2 == 0:
            part(cv, band, (255, 92, 92), (206, 24, 40), ow=0, gloss=False)
        else:
            part(cv, band, (255, 255, 255), (226, 226, 238), ow=0, gloss=False)
    gl = inter(awning, ell(450, 340, 300, 40))
    paint(cv, gl.filter(ImageFilter.GaussianBlur(8)), solid((255, 255, 255)), 0.35)
    part(cv, rrect(270, 140, 754, 300, 60), (255, 110, 110), (210, 30, 50), outline)
    for x in (390, 512, 634):
        part(cv, ell(x, 222, 30, 30), (255, 250, 170), (250, 180, 20), outline, ow=8, gloss=False, bevel=False)
    finish(cv, "Shop")


def index():
    cv = canvas()
    outline = (16, 30, 96)
    cover = poly([(100, 300), (512, 360), (924, 300), (924, 840), (512, 900), (100, 840)])
    part(cv, smooth(cover, 10), (80, 170, 255), (22, 78, 214), outline, ow=24, gloss=False)
    left = poly([(150, 250), (500, 310), (500, 850), (150, 790)])
    right = poly([(524, 310), (874, 250), (874, 790), (524, 850)])
    part(cv, smooth(left, 6), (255, 255, 250), (232, 226, 210), outline, ow=12, gloss=False)
    part(cv, smooth(right, 6), (255, 255, 250), (232, 226, 210), outline, ow=12, gloss=False)
    paint(cv, rrect(496, 300, 528, 860, 10).filter(ImageFilter.GaussianBlur(8)), solid((120, 120, 150)), 0.6)
    for i in range(6):
        y = 400 + i * 70
        line = poly([(210, y + 10 * 0), (440, y + 38), (440, y + 58), (210, y + 20)])
        paint(cv, smooth(line, 3), solid((150, 180, 230)), 0.9)
    egg = union(ell(700, 580, 128, 150), ell(700, 520, 104, 140))
    part(cv, egg, (255, 255, 255), (236, 228, 200), outline=(60, 40, 30), ow=16)
    spots = union(ell(650, 520, 34, 30), ell(748, 600, 40, 34), ell(680, 660, 28, 24), ell(740, 470, 24, 22))
    part(cv, inter(spots, shrink(egg, 6)), (255, 228, 80), (244, 170, 20), ow=0, gloss=False, bevel=False)
    sparkle(cv, 880, 200, 80)
    sparkle(cv, 140, 200, 50)
    finish(cv, "Index")


def coin():
    cv = canvas()
    outline = (140, 70, 6)
    part(cv, ell(512, 512, 410, 410), (255, 232, 90), (238, 140, 14), outline, ow=26)
    part(cv, ell(512, 520, 318, 318), (236, 150, 20), (255, 214, 70), outline=(206, 118, 10), ow=10, gloss=False)
    st = smooth(star(512, 530, 250, 112), 10)
    part(cv, st, (255, 252, 190), (255, 186, 30), outline=(196, 100, 6), ow=14)
    finish(cv, "Coin")


def speed():
    cv = canvas()
    wing = (28, 70, 180)
    for (cx, cy, rx, ry, rot) in ((300, 380, 230, 62, -24), (270, 510, 230, 58, -6), (290, 630, 190, 52, 12)):
        part(cv, ell(cx, cy, rx, ry, rot), (255, 255, 255), (196, 228, 255), outline=wing, ow=18)
    bolt = poly([(640, 70), (380, 560), (540, 560), (440, 960), (800, 400), (630, 400), (770, 70)])
    part(cv, smooth(bolt, 8), (255, 248, 140), (255, 150, 10), outline=(130, 50, 0), ow=24)
    finish(cv, "Speed")


def level_star():
    cv = canvas()
    st = smooth(star(512, 540, 470, 230), 26)
    paint(cv, grow(st, 50).filter(ImageFilter.GaussianBlur(30)), solid((255, 220, 90)), 0.55)
    part(cv, st, (255, 242, 120), (255, 146, 16), outline=(196, 84, 0), ow=26)
    inner = shrink(st, 70)
    paint(cv, inner, grad((255, 200, 50), (255, 236, 120), 200, 900), 0.35)
    finish(cv, "LevelStar")


def crown():
    cv = canvas()
    outline = (120, 56, 0)
    body = poly([(200, 720), (150, 330), (360, 530), (512, 250), (664, 530), (874, 330), (824, 720)])
    part(cv, smooth(body, 8), (255, 240, 110), (240, 150, 14), outline, ow=24)
    part(cv, rrect(180, 680, 844, 830, 40), (255, 220, 80), (226, 128, 10), outline, ow=24)
    for x, y in ((150, 320), (512, 236), (874, 320)):
        part(cv, ell(x, y, 58, 58), (255, 250, 190), (250, 180, 30), outline, ow=16)
    for x, c1, c2 in ((340, (255, 120, 140), (210, 20, 60)), (512, (120, 220, 255), (30, 100, 230)), (684, (140, 255, 140), (20, 170, 60))):
        part(cv, ell(x, 755, 46, 46), c1, c2, outline, ow=10)
    finish(cv, "Crown")


def sparkle_icon():
    cv = canvas()
    sparkle(cv, 512, 512, 380)
    finish(cv, "Sparkle", 128, shadow=False)


def stripes():
    """Seamless tile of light diagonal stripes for the XP fill (ScaleType Tile)."""
    size, period, band = 256, 128, 44
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    for offset in range(-size, size * 2, period):
        d.polygon([(offset, size), (offset + band, size), (offset + band + size, 0), (offset + size, 0)], fill=255)
    tile = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    tile.putalpha(m.point(lambda v: v * 80 // 255))
    tile.resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, "Stripes.png"))
    print("drew Stripes")


for fn in (rebirth, gifts, shop, index, coin, speed, level_star, crown, sparkle_icon, stripes):
    fn()
