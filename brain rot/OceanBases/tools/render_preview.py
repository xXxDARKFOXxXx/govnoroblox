"""Offline preview of exported base geometry (painter's algorithm, flat shading).

This is not a Roblox Studio screenshot: lighting, materials and transparency are
approximate. It is used to check layout, proportions and colours without Studio.

Usage: python tools/render_preview.py <parts.json> <out.png> camX camY camZ targetX targetY targetZ [fov]
"""
import json
import math
import sys

from PIL import Image, ImageDraw

parts = json.load(open(sys.argv[1], encoding="utf-8"))
out = sys.argv[2]
cam = [float(v) for v in sys.argv[3:6]]
target = [float(v) for v in sys.argv[6:9]]
fov = float(sys.argv[9]) if len(sys.argv) > 9 else 50
W, H, SS = 1600, 900, 2


def sub(a, b): return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]
def add(a, b): return [a[0] + b[0], a[1] + b[1], a[2] + b[2]]
def dot(a, b): return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def cross(a, b): return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
def norm(a):
    d = math.sqrt(dot(a, a)) or 1
    return [a[0] / d, a[1] / d, a[2] / d]


forward = norm(sub(target, cam))
right = norm(cross(forward, [0, 1, 0]))
up = cross(right, forward)
focal = (H * SS / 2) / math.tan(math.radians(fov) / 2)
LIGHT = norm([0.45, 0.85, 0.35])


def project(p):
    rel = sub(p, cam)
    z = dot(rel, forward)
    if z < 0.5:
        return None
    return (W * SS / 2 + focal * dot(rel, right) / z, H * SS / 2 - focal * dot(rel, up) / z, z)


def transform(cf, v):
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf
    return [x + r00 * v[0] + r01 * v[1] + r02 * v[2], y + r10 * v[0] + r11 * v[1] + r12 * v[2], z + r20 * v[0] + r21 * v[1] + r22 * v[2]]


def box_faces(sx, sy, sz):
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    c = [[-hx, -hy, -hz], [hx, -hy, -hz], [hx, hy, -hz], [-hx, hy, -hz], [-hx, -hy, hz], [hx, -hy, hz], [hx, hy, hz], [-hx, hy, hz]]
    return [[c[i] for i in f] for f in ([0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5])]


def wedge_faces(sx, sy, sz):
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    b = [[-hx, -hy, -hz], [hx, -hy, -hz], [hx, -hy, hz], [-hx, -hy, hz]]
    t = [[-hx, hy, hz], [hx, hy, hz]]
    return [[b[0], b[1], b[2], b[3]], [b[3], b[2], t[1], t[0]], [b[0], t[0], t[1], b[1]], [b[0], b[3], t[0]], [b[1], t[1], b[2]]]


def cylinder_faces(sx, sy, sz, n=12):
    hx, ry, rz = sx / 2, sy / 2, sz / 2
    ring = [[math.cos(2 * math.pi * i / n) * ry, math.sin(2 * math.pi * i / n) * rz] for i in range(n)]
    faces = [[[-hx, p[0], p[1]] for p in ring][::-1], [[hx, p[0], p[1]] for p in ring]]
    for i in range(n):
        a, b = ring[i], ring[(i + 1) % n]
        faces.append([[-hx, a[0], a[1]], [-hx, b[0], b[1]], [hx, b[0], b[1]], [hx, a[0], a[1]]])
    return faces


def sphere_faces(sx, sy, sz, n=10, m=6):
    faces = []
    for j in range(m):
        t0, t1 = math.pi * j / m - math.pi / 2, math.pi * (j + 1) / m - math.pi / 2
        for i in range(n):
            p0, p1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
            def pt(t, p): return [math.cos(t) * math.cos(p) * sx / 2, math.sin(t) * sy / 2, math.cos(t) * math.sin(p) * sz / 2]
            faces.append([pt(t0, p0), pt(t0, p1), pt(t1, p1), pt(t1, p0)])
    return faces


polys = []
for part in parts:
    sx, sy, sz = part["size"]
    shape = part["s"]
    if shape == "Wedge":
        faces = wedge_faces(sx, sy, sz)
    elif shape == "Cylinder":
        faces = cylinder_faces(sx, sy, sz)
    elif shape in ("Ball", "Ellipsoid"):
        d = min(sx, sy, sz) if shape == "Ball" else None
        faces = sphere_faces(d or sx, d or sy, d or sz)
    else:
        faces = box_faces(sx, sy, sz)
    for face in faces:
        world = [transform(part["cf"], v) for v in face]
        n = norm(cross(sub(world[1], world[0]), sub(world[2], world[0])))
        centre = [sum(p[i] for p in world) / len(world) for i in range(3)]
        if dot(n, sub(cam, centre)) <= 0:
            continue
        pts = [project(p) for p in world]
        if any(p is None for p in pts):
            continue
        shade = 1.0 if part["neon"] else 0.58 + 0.42 * max(0.0, dot(n, LIGHT))
        color = [min(255, int(c * shade + (40 if part["neon"] else 0))) for c in part["c"]]
        alpha = int(255 * (1 - part["t"]))
        polys.append((sum(p[2] for p in pts) / len(pts), [(p[0], p[1]) for p in pts], tuple(color) + (alpha,)))

img = Image.new("RGBA", (W * SS, H * SS))
sky = ImageDraw.Draw(img)
for y in range(H * SS):
    k = y / (H * SS)
    sky.line([(0, y), (W * SS, y)], fill=(int(150 + 60 * k), int(205 + 30 * k), 255, 255))
draw = ImageDraw.Draw(img, "RGBA")
# Court floor (sand) for context.
floor = [project(p) for p in ([-150, 4, -170], [150, 4, -170], [150, 4, 5], [-150, 4, 5])]
if all(floor):
    draw.polygon([(p[0], p[1]) for p in floor], fill=(232, 214, 162, 255))
for _, pts, color in sorted(polys, key=lambda p: -p[0]):
    draw.polygon(pts, fill=color)
img = img.resize((W, H), Image.LANCZOS).convert("RGB")
img.save(out)
print("rendered", len(polys), "faces ->", out)
