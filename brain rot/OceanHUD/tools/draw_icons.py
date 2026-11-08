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
    """Thick gold coin: visible edge, reeded rim, recessed ring with dots,
    bevelled star, diagonal shine streak and a sparkle."""
    cv = canvas()
    outline = (120, 56, 0)
    cx, cy, R = 512, 470, 390
    face = ell(cx, cy, R, R)
    edge = ell(cx, cy + 48, R, R)
    # Coin thickness: darker band under the face.
    paint(cv, grow(union(face, edge), 26), solid(outline))
    paint(cv, edge, grad((214, 120, 10), (150, 72, 0), cy, cy + R + 48))
    for i in range(36):  # reeded edge on the visible side
        a = math.radians(i * 5)
        x = cx + R * math.cos(a)
        notch = rrect(x - 7, cy + R * math.sin(a) - 10, x + 7, cy + R * math.sin(a) + 44, 6)
        paint(cv, inter(notch, minus(edge, face)), solid((120, 56, 0)), 0.55)
    part(cv, face, (255, 236, 110), (240, 150, 16), outline=None, ow=0, gloss=False)
    # Reeded rim on the face.
    rim = minus(face, ell(cx, cy, R - 46, R - 46))
    for i in range(60):
        a = math.radians(i * 6)
        x, y = cx + (R - 23) * math.cos(a), cy + (R - 23) * math.sin(a)
        tick = rrect(x - 6, y - 16, x + 6, y + 16, 5).rotate(-math.degrees(a) + 90, center=(x, y), resample=Image.BICUBIC)
        paint(cv, inter(tick, rim), solid((200, 118, 8)), 0.6)
    # Recessed inner disc with a ring of dots.
    paint(cv, grow(ell(cx, cy, R - 70, R - 70), 8), solid((196, 112, 8)))
    part(cv, ell(cx, cy, R - 70, R - 70), (232, 144, 18), (255, 216, 80), ow=0, gloss=False)
    for i in range(16):
        a = math.radians(i * 22.5)
        part(cv, ell(cx + (R - 115) * math.cos(a), cy + (R - 115) * math.sin(a), 16, 16),
             (255, 246, 170), (240, 160, 20), outline=(190, 104, 6), ow=5, gloss=False, bevel=False)
    st = smooth(star(cx, cy + 10, 215, 98), 10)
    paint(cv, ImageChops.offset(grow(st, 10), 0, 16).filter(ImageFilter.GaussianBlur(10)), solid((150, 70, 0)), 0.5)
    part(cv, st, (255, 252, 196), (255, 182, 26), outline=(190, 96, 4), ow=14)
    # Diagonal glossy streaks across the face.
    for offset, width, alpha in ((-120, 90, 0.42), (40, 34, 0.32)):
        band = poly([(cx - R + offset, cy + R), (cx - R + offset + width, cy + R),
                     (cx + R + offset + width, cy - R), (cx + R + offset, cy - R)])
        paint(cv, inter(band, shrink(face, 20)).filter(ImageFilter.GaussianBlur(5)), solid((255, 255, 255)), alpha)
    sparkle(cv, 790, 190, 95)
    sparkle(cv, 230, 760, 50)
    finish(cv, "Coin")


def flippers():
    """Pair of swim fins: foot pocket, wide split blade, ribs, and water drops."""
    cv = canvas()
    outline = (14, 40, 110)

    def fin(angle, dx, dy, top, bottom):
        def place(m):
            return ImageChops.offset(m.rotate(angle, center=(512, 512), resample=Image.BICUBIC), dx, dy)
        blade = place(smooth(poly([(-110 + 512, 300), (110 + 512, 300), (205 + 512, 860), (100 + 512, 800),
                                    (512, 890), (-100 + 512, 800), (-205 + 512, 860)]), 10))
        pocket = place(rrect(512 - 118, 90, 512 + 118, 400, 90))
        hole = place(ell(512, 190, 70, 62))
        part(cv, union(blade, pocket), top, bottom, outline=outline, ow=24, gloss=False)
        part(cv, pocket, (70, 130, 240), (24, 56, 170), ow=0, gloss=True)
        paint(cv, grow(hole, 8), solid(outline))
        paint(cv, hole, grad((10, 24, 70), (40, 80, 170), 120, 260))
        for x in (-70, 70):  # stiff ribs along the blade
            rib = place(smooth(poly([(512 + x - 14, 420), (512 + x + 14, 420), (512 + x * 1.9 + 14, 790), (512 + x * 1.9 - 14, 790)]), 6))
            paint(cv, rib, solid((255, 255, 255)), 0.45)
        sheen = inter(blade, place(ell(512 - 50, 520, 60, 200, 8)))
        paint(cv, sheen.filter(ImageFilter.GaussianBlur(10)), solid((255, 255, 255)), 0.45)

    fin(16, -170, 20, (150, 255, 236), (0, 170, 196))
    fin(-14, 170, -10, (170, 255, 240), (0, 186, 206))
    for (x, y, r) in ((140, 800, 40), (210, 900, 26), (900, 820, 34)):
        drop = union(ell(x, y, r, r), poly([(x - r * 0.7, y - r * 0.6), (x + r * 0.7, y - r * 0.6), (x, y - r * 2.2)]))
        part(cv, smooth(drop, 3), (220, 250, 255), (90, 200, 255), outline=outline, ow=8, gloss=False)
    finish(cv, "Flippers")


def raised_squares(cv, mask, top, bottom, line, size=92, step=150, ox=0, oy=0):
    """Toy-brick texture: little bevelled squares inside the mask."""
    inner = shrink(mask, 28)
    for gx in range(-2, 10):
        for gy in range(-2, 10):
            x, y = ox + gx * step, oy + gy * step
            sq = inter(rrect(x - size / 2, y - size / 2, x + size / 2, y + size / 2, 18), inner)
            if sq.getbbox() and sum(sq.histogram()[128:]) > size * size * 0.6:
                part(cv, sq, top, bottom, outline=line, ow=6, gloss=False)


def shark_fin():
    cv = canvas()
    outline = (16, 30, 70)

    def bez(p0, p1, p2, n=24):
        return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
                 (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in (i / n for i in range(n + 1))]
    fin = poly(bez((170, 770), (300, 260), (690, 110)) + bez((690, 110), (590, 470), (850, 770)))
    fin = smooth(fin, 10)
    part(cv, fin, (176, 206, 236), (66, 98, 150), outline=outline, ow=26)
    raised_squares(cv, fin, (206, 228, 250), (110, 140, 190), (60, 86, 140), size=86, step=132, ox=420, oy=430)
    sheen = inter(fin, poly(bez((240, 740), (330, 330), (650, 160)) + [(600, 240), (380, 470), (330, 740)]))
    paint(cv, sheen.filter(ImageFilter.GaussianBlur(12)), solid((255, 255, 255)), 0.35)
    # Water with wavy foam at the fin base.
    # Water: a wave with rounded crests, not a box.
    crests = [ell(150 + i * 145, 738, 92, 52) for i in range(6)]
    water = smooth(union(ell(512, 820, 440, 104), rrect(120, 735, 904, 860, 60), *crests), 8)
    part(cv, water, (120, 226, 255), (16, 112, 222), outline=outline, ow=22, gloss=False)
    for i in range(6):
        paint(cv, ell(150 + i * 145, 718, 56, 16), solid((255, 255, 255)), 0.8)
    for (x, y, r) in ((110, 640, 26), (920, 650, 32), (860, 590, 18)):
        part(cv, ell(x, y, r, r), (230, 252, 255), (110, 210, 255), outline=outline, ow=8, gloss=False, bevel=False)
    sparkle(cv, 860, 220, 80)
    finish(cv, "SharkFin")


def egg_icon():
    cv = canvas()
    egg = union(ell(512, 580, 330, 360), ell(512, 470, 270, 360))
    part(cv, egg, (255, 252, 236), (226, 196, 140), outline=(90, 56, 20), ow=26)
    raised_squares(cv, egg, (255, 246, 214), (214, 180, 120), (150, 112, 60), size=96, step=150, ox=512, oy=560)
    sheen = inter(shrink(egg, 30), ell(400, 330, 110, 170, -20))
    paint(cv, sheen.filter(ImageFilter.GaussianBlur(14)), solid((255, 255, 255)), 0.55)
    sparkle(cv, 850, 200, 85)
    sparkle(cv, 170, 300, 50)
    finish(cv, "Egg")


def sparkle_icon():
    cv = canvas()
    sparkle(cv, 512, 512, 380)
    finish(cv, "Sparkle", 128, shadow=False)


def backpack():
    """Rounded orange-red backpack: handle, side straps, front pocket, gold buckle."""
    cv = canvas()
    outline = (70, 16, 6)
    body_top, body_bottom = (255, 116, 52), (196, 48, 18)
    handle = minus(rrect(392, 90, 632, 250, 70), rrect(452, 140, 572, 260, 40))
    part(cv, handle, (150, 70, 40), (100, 40, 20), outline, ow=18, gloss=False)
    for x in (230, 794):  # side pockets
        part(cv, rrect(x - 80, 420, x + 80, 820, 60), (236, 92, 40), (176, 40, 16), outline, ow=20, gloss=False)
    body = rrect(250, 200, 774, 930, 170)
    part(cv, body, body_top, body_bottom, outline, ow=24)
    for x in (360, 664):  # shoulder straps seen from the front
        paint(cv, rrect(x - 30, 230, x + 30, 900, 26), solid((150, 40, 14)), 0.55)
    pocket = rrect(330, 560, 694, 880, 90)
    part(cv, pocket, (240, 100, 44), (184, 44, 16), outline, ow=16, gloss=False)
    flap = rrect(330, 520, 694, 660, 70)
    part(cv, flap, (255, 132, 64), (214, 64, 24), outline, ow=16)
    ring = minus(ell(512, 380, 92, 92), ell(512, 380, 50, 50))
    part(cv, ring, (255, 236, 110), (240, 150, 14), outline=(120, 56, 0), ow=12)
    part(cv, rrect(476, 610, 548, 700, 18), (255, 236, 110), (240, 150, 14), outline=(120, 56, 0), ow=10, gloss=False)
    finish(cv, "Backpack")


for fn in (rebirth, gifts, shop, index, coin, flippers, shark_fin, egg_icon, sparkle_icon, backpack):
    fn()
