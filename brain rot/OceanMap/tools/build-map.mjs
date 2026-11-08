import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = [];
const geometry = [];
let serial = 0;
const esc = s => String(s).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const tag = (type, name, value) => `<${type} name="${name}">${value}</${type}>`;
const str = (n, v) => tag('string', n, esc(v));
const bool = (n, v) => tag('bool', n, v ? 'true' : 'false');
const num = (n, v) => tag('float', n, v);
const token = (n, v) => tag('token', n, v);
const vec = (n, v) => tag('Vector3', n, `<X>${v[0]}</X><Y>${v[1]}</Y><Z>${v[2]}</Z>`);
const color = (n, c) => tag('Color3', n, `<R>${c[0] / 255}</R><G>${c[1] / 255}</G><B>${c[2] / 255}</B>`);
const partColor = c => tag('Color3uint8', 'Color3uint8', 0xff000000 + Math.round(c[0]) * 65536 + Math.round(c[1]) * 256 + Math.round(c[2]));
const identity = [1, 0, 0, 0, 1, 0, 0, 0, 1];
const rx = a => [1, 0, 0, 0, Math.cos(a), -Math.sin(a), 0, Math.sin(a), Math.cos(a)];
const rz = a => [Math.cos(a), -Math.sin(a), 0, Math.sin(a), Math.cos(a), 0, 0, 0, 1];
const ry = a => [Math.cos(a), 0, Math.sin(a), 0, 1, 0, -Math.sin(a), 0, Math.cos(a)];
const mult = (a, b) => Array.from({ length: 9 }, (_, k) => Array.from({ length: 3 }, (_, j) => a[Math.floor(k / 3) * 3 + j] * b[j * 3 + k % 3]).reduce((x, y) => x + y, 0));
const cf = (n, p, r = identity) => tag('CoordinateFrame', n, `<X>${p[0]}</X><Y>${p[1]}</Y><Z>${p[2]}</Z>${r.map((v, k) => `<R${Math.floor(k / 3)}${k % 3}>${v}</R${Math.floor(k / 3)}${k % 3}>`).join('')}`);
function item(cls, name, props = '', children = '', ref) {
  return `<Item class="${cls}" referent="${ref || `OM${++serial}`}"><Properties>${str('Name', name)}${props}</Properties>${children}</Item>`;
}
function part(name, size, position, rgb, opts = {}) {
  const r = opts.r || identity;
  const alpha = opts.alpha || 0;
  const material = opts.material || 256;
  const collide = opts.collide ?? true;
  const studs = opts.studs ?? true;
  const props = vec('size', size) + cf('CFrame', position, r) + partColor(rgb)
    + bool('Anchored', true) + bool('CanCollide', collide) + bool('CanTouch', false)
    + bool('CanQuery', collide) + bool('CastShadow', opts.shadow ?? collide)
    + token('Material', material) + token('shape', opts.ball ? 0 : 1)
    + num('Transparency', alpha) + num('Reflectance', opts.reflectance || 0)
    + ['Top', 'Bottom', 'Left', 'Right', 'Front', 'Back'].map(s => token(`${s}Surface`, studs ? 3 : 0)).join('');
  if (alpha < 1) geometry.push({ name, size, position, rotation: r, color: rgb, alpha, material, ball: opts.ball || false, studs });
  return item(opts.cls || 'Part', name, props + (opts.props || ''), opts.children || '', opts.ref);
}
const folder = (name, children) => item('Folder', name, '', children.join(''));
const model = (name, children) => item('Model', name, '', children.join(''));
const value = (type, name, v) => item(type, name, type === 'Vector3Value' ? vec('Value', v) : tag('double', 'Value', v));
const clamp = (x, lo, hi) => Math.min(hi, Math.max(lo, x));
const levels = [4, -20, -44, -76, -116, -164];
const sectionLength = 192;
const spawnWidth = 288;
const spawnHalf = spawnWidth / 2;
function floorAt(z) {
  const s = clamp(Math.floor(z / sectionLength), 0, 4);
  return levels[s] + (levels[s + 1] - levels[s]) * clamp((z - s * sectionLength) / sectionLength, 0, 1);
}
const palettes = [
  { name: '01_Lagoon', floor: [[69, 202, 199], [83, 218, 208]], wall: [[110, 208, 212], [130, 225, 224]], cap: [[28, 168, 176], [36, 185, 189]], line: [166, 255, 232] },
  { name: '02_Reef', floor: [[42, 166, 194], [54, 184, 208]], wall: [[74, 180, 200], [91, 196, 212]], cap: [[20, 130, 166], [26, 149, 183]], line: [121, 245, 246] },
  { name: '03_Bluewater', floor: [[46, 124, 183], [59, 142, 200]], wall: [[68, 146, 191], [85, 164, 207]], cap: [[37, 99, 162], [44, 118, 181]], line: [118, 214, 255] },
  { name: '04_Twilight', floor: [[65, 101, 159], [77, 115, 177]], wall: [[88, 119, 175], [104, 135, 191]], cap: [[57, 76, 137], [70, 91, 155]], line: [159, 196, 255] },
  { name: '05_Abyss', floor: [[69, 80, 132], [82, 94, 150]], wall: [[97, 107, 158], [111, 123, 176]], cap: [[63, 58, 117], [77, 71, 136]], line: [191, 185, 255] },
];
const spawnPalette = { wall: [[37, 83, 91], [47, 100, 106]], cap: [[21, 57, 70], [29, 72, 82]], line: [111, 205, 194] };
const spawn = [], sections = [], decorations = [], seabedDecor = [], bubblePreview = [];
const seabedPatches = [];

// Broad, empty court with the same tiled/studded language as the references.
for (let x = -spawnHalf; x < spawnHalf; x += 8) for (let z = -160; z < 0; z += 8) {
  const edge = x === -spawnHalf || x === spawnHalf - 8 || z === -160 || z === -8;
  const c = edge ? [[121, 101, 72], [139, 117, 83]] : [[155, 134, 100], [174, 151, 112]];
  spawn.push(part('SpawnFloorTile', [8, 4, 8], [x + 4, 2, z + 4], c[((x + spawnHalf + z + 160) / 8) % 2]));
}

function sideWall(arr, side, xInner, zStart, zEnd, lower, palette, sloping = false) {
  arr.push(part('WallCore', [8, 32 - lower, zEnd - zStart], [side * (xInner + 4), (32 + lower) / 2, (zStart + zEnd) / 2], palette.wall[0]));
  for (let z = zStart; z < zEnd; z += 8) {
    const bottom = sloping ? Math.floor((floorAt(z + 8) - 8) / 8) * 8 : lower;
    for (let y = bottom; y < 32; y += 8) {
      arr.push(part('WallCheckerTile', [0.28, Math.min(8, 32 - y), 8], [side * (xInner - 0.14), y + Math.min(8, 32 - y) / 2, z + 4], palette.wall[((z - zStart) / 8 + Math.round(y / 8) + 100) % 2]));
    }
    arr.push(part('WallCapTile', [8, 4, 8], [side * (xInner + 4), 34, z + 4], palette.cap[((z - zStart) / 8) % 2]));
  }
  arr.push(part('WaterlineInlay', [0.31, 0.26, zEnd - zStart], [side * (xInner - 0.31), 1.2, (zStart + zEnd) / 2], palette.line, { material: 288, studs: false, collide: false }));
  arr.push(part('WallTopInlay', [0.34, 0.22, zEnd - zStart], [side * (xInner - 0.31), 31.5, (zStart + zEnd) / 2], palette.line, { material: 288, studs: false, collide: false }));
}

function crossWall(arr, zCenter, xMin, xMax, bottom, palette) {
  arr.push(part('EndWall', [xMax - xMin, 32 - bottom, 8], [(xMin + xMax) / 2, (32 + bottom) / 2, zCenter], palette.wall[0]));
  const front = zCenter < 0 ? zCenter + 4.14 : zCenter - 4.14;
  for (let x = xMin; x < xMax; x += 8) for (let y = bottom; y < 32; y += 8) {
    arr.push(part('WallCheckerTile', [Math.min(8, xMax - x), Math.min(8, 32 - y), 0.28], [x + Math.min(8, xMax - x) / 2, y + Math.min(8, 32 - y) / 2, front], palette.wall[(Math.floor((x - xMin) / 8) + Math.floor((y - bottom) / 8)) % 2]));
  }
  for (let x = xMin; x < xMax; x += 8) {
    // The entrance shoulders meet the existing canal cap at these cells.
    if (zCenter === 4 && (x === -72 || x === 64)) continue;
    arr.push(part('WallCapTile', [Math.min(8, xMax - x), 4, 8], [x + Math.min(8, xMax - x) / 2, 34, zCenter], palette.cap[Math.floor((x - xMin) / 8) % 2]));
  }
}

for (const side of [-1, 1]) sideWall(spawn, side, spawnHalf, -160, 0, 0, spawnPalette);
crossWall(spawn, -164, -spawnHalf - 8, spawnHalf + 8, 0, spawnPalette);
crossWall(spawn, 4, -spawnHalf - 8, -64, 0, spawnPalette);
crossWall(spawn, 4, 64, spawnHalf + 8, 0, spawnPalette);
// Invisible spawn is flush with the ordinary floor; no spawn pad graphic.
spawn.push(part('OceanSpawn', [8, 0.2, 8], [0, 3.85, -112], [155, 134, 100], {
  cls: 'SpawnLocation', alpha: 1, studs: false,
  props: bool('Neutral', true) + tag('int', 'Duration', 0) + bool('Enabled', true), r: ry(Math.PI),
}));

for (let s = 0; s < 5; s++) {
  const a = [], palette = palettes[s], z0 = s * sectionLength;
  const angle = Math.atan((levels[s] - levels[s + 1]) / sectionLength);
  const rot = rx(angle), cosine = Math.cos(angle), sine = Math.sin(angle);
  for (let ix = 0; ix < 16; ix++) for (let iz = 0; iz < 24; iz++) {
    const x = -60 + ix * 8, z = z0 + iz * 8 + 4, y = floorAt(z);
    a.push(part('SlopedFloorTile', [8, 4, 8 / cosine], [x, y - cosine * 2, z - sine * 2], palette.floor[(ix + iz) % 2], { r: rot }));
  }
  for (const side of [-1, 1]) {
    sideWall(a, side, 64, z0, z0 + sectionLength, levels[s + 1] - 12, palette, true);
    a.push(part('SectionWallSeam', [0.38, 32 - levels[s] + 4, 0.65], [side * 63.55, (32 + levels[s] - 4) / 2, z0 + 0.5], palette.line, { studs: false, material: 288, collide: false }));
    a.push(part('SlopingEdgeInlay', [0.48, 0.1, sectionLength / cosine], [side * 61.9, floorAt(z0 + 96) + 0.09, z0 + 96], palette.line, { r: rot, studs: false, material: 288, collide: false }));
  }
  a.push(part('SectionFloorSeam', [123.3, 0.1, 0.65], [0, levels[s] + 0.1, z0 + 0.4], palette.line, { r: rot, studs: false, material: 288, collide: false }));
  sections.push(model(palette.name, a));
}
const endWall = [];
crossWall(endWall, 964, -72, 72, -176, palettes[4]);
sections.push(folder('CanalEndWall', endWall));

// Wall decoration and seabed vegetation share the same animated blade shape.
function blade(base, height, width, facing, hue, seed, target = decorations) {
  const parts = [value('Vector3Value', 'SwayOrigin', base), value('NumberValue', 'SwayFacing', facing)];
  let px = 0, py = 0;
  for (let j = 0; j < 4; j++) {
    const len = height / 4;
    const a = Math.sin(seed + j * 0.85) * 0.36;
    const dx = -Math.sin(a) * len, dy = Math.cos(a) * len;
    const u = px + dx / 2;
    // Slightly separate the front faces of successive blades to prevent
    // coplanar flicker at the overlapping joints.
    const depth = Math.sin(seed * 2.91) * 0.19 + j * 0.018;
    const pos = [base[0] + Math.cos(facing) * u + Math.sin(facing) * depth, base[1] + py + dy / 2, base[2] - Math.sin(facing) * u + Math.cos(facing) * depth];
    const col = hue.map((v, k) => clamp(v + j * (k === 1 ? 9 : 3), 0, 255));
    parts.push(part('KelpSegment', [width * (1 - j * 0.16), len + 0.12, 0.35], pos, col, { r: mult(ry(facing), rz(a)), collide: false }));
    px += dx; py += dy;
  }
  target.push(model('KelpBlade', parts));
}
function kelp(x, y, z, facing, seed, deep = 0) {
  const hue = deep > 3 ? [43, 148, 166] : deep > 1 ? [31, 159, 144] : [32, 177, 130];
  for (let b = 0; b < 3; b++) {
    const u = (b - 1) * 1.6;
    blade([x + Math.cos(facing) * u, y, z - Math.sin(facing) * u], [7.3, 11, 8.6][b] + Math.sin(seed) * 1.4, 1.55, facing, hue, seed + b * 1.9);
  }
}
function bubbleSource(x, y, z, height, seed) {
  decorations.push(part('BubbleSource', [0.2, 0.2, 0.2], [x, y, z], [175, 250, 255], { alpha: 1, collide: false, children: value('NumberValue', 'RiseHeight', height) }));
  for (let j = 0; j < 4; j++) {
    const size = 0.45 + ((j + seed) % 3) * 0.2;
    const pos = [x + Math.sin(seed + j) * 0.5, y + height * (j + 0.7) / 5, z + Math.cos(seed + j) * 0.6];
    bubblePreview.push(part('Bubble', [size, size, size], pos, [173, 246, 253], { material: 1568, alpha: 0.6, ball: true, studs: false, collide: false }));
    bubblePreview.push(part('BubbleHighlight', [size * 0.17, size * 0.17, size * 0.17], [pos[0] - size * 0.22, pos[1] + size * 0.23, pos[2] - size * 0.3], [225, 255, 255], { material: 288, alpha: 0.15, ball: true, studs: false, collide: false }));
  }
}
function caustic(side, x, y, z, seed, tint) {
  // A sparse broken wave drawn directly onto the wall, with no extra props.
  for (let j = 0; j < 5; j++) {
    const angle = Math.sin(j * 1.45 + seed) * 0.55;
    decorations.push(part('CausticStroke', [0.07, 0.16, 3.7], [side * (x - 0.42), y + Math.sin(j * 1.15 + seed) * 1.2, z + (j - 2) * 3], tint,
      { r: rx(angle), material: 288, alpha: 0.64, studs: false, collide: false }));
  }
}

// Small reliefs are attached to the wall and extend at most 1.1 studs
// into the room. They never create free-standing gameplay obstacles.
function wallElement(name, base, facing, u, v, depth, size, rgb, angle = 0, options = {}) {
  const cs = Math.cos(facing), sn = Math.sin(facing);
  return part(name, size, [base[0] + cs * u + sn * depth, base[1] + v, base[2] - sn * u + cs * depth], rgb,
    { r: mult(ry(facing), rz(angle)), collide: false, ...options });
}
function wallStar(base, facing, scale, rgb) {
  const a = [];
  for (let arm = 0; arm < 5; arm++) {
    const theta = arm * Math.PI * 2 / 5;
    for (let k = 0; k < 2; k++) {
      const radius = (0.6 + k * 0.8) * scale;
      a.push(wallElement('StarfishRelief', base, facing, -Math.sin(theta) * radius, Math.cos(theta) * radius, 0.23 + arm * 0.006 + k * 0.012,
        [(k ? 0.46 : 0.76) * scale, scale, 0.34], rgb, theta));
    }
    a.push(wallElement('StarfishDot', base, facing, -Math.sin(theta) * scale, Math.cos(theta) * scale, 0.43,
      [0.18 * scale, 0.18 * scale, 0.1], rgb.map(c => Math.min(255, c + 30)), theta, { studs: false }));
  }
  a.push(wallElement('StarfishCentre', base, facing, 0, 0, 0.29, [1.1 * scale, 1.1 * scale, 0.36], rgb, Math.PI / 4));
  decorations.push(model('WallStarfish', a));
}
function wallShell(base, facing, scale, rgb) {
  const a = [];
  for (let j = -3; j <= 3; j++) {
    const theta = j * 0.22, length = (2.8 - Math.abs(j) * 0.2) * scale;
    a.push(wallElement('ShellRib', base, facing, -Math.sin(theta) * length / 2, Math.cos(theta) * length / 2, 0.22 + (3 - Math.abs(j)) * 0.025,
      [0.43 * scale, length, 0.35], rgb.map(c => clamp(c + (j % 2 ? -12 : 4), 0, 255)), theta));
  }
  a.push(wallElement('ShellHinge', base, facing, 0, 0, 0.3, [1.1 * scale, 0.5 * scale, 0.5], rgb));
  decorations.push(model('WallShell', a));
}
function wallBubbles(base, facing, scale, tint) {
  const a = [];
  for (let ring = 0; ring < 3; ring++) {
    const radius = (1.3 - ring * 0.25) * scale, u = (ring % 2 ? 1.8 : 0) * scale, v = ring * 3.3 * scale;
    for (let j = 0; j < 12; j++) {
      const angle = j * Math.PI / 6;
      a.push(wallElement('WallBubbleInlay', base, facing, u + Math.cos(angle) * radius, v + Math.sin(angle) * radius, 0.13,
        [radius * 0.53, 0.13 * scale, 0.12], tint, angle + Math.PI / 2, { studs: false, material: 288, alpha: 0.38 }));
    }
  }
  decorations.push(model('BubbleWallRelief', a));
}
function wallWave(base, facing, length, tint) {
  const a = [];
  for (let band = 0; band < 2; band++) for (let u = -length / 2; u < length / 2; u += 3) {
    const y = Math.sin(u / 6) * 1.1 + band * 2.2;
    a.push(wallElement('CausticStroke', base, facing, u + 1.5, y, 0.12, [3.08, 0.2, 0.1], tint, Math.atan(Math.cos(u / 6) * 0.18), { studs: false, material: 288, alpha: 0.62 }));
  }
  decorations.push(model('WallWave', a));
}
function coral(base, facing, seed, deep, target = decorations) {
  const rgb = deep > 2 ? [156, 126, 191] : seed % 2 ? [216, 143, 127] : [226, 178, 124];
  const a = [];
  const height = 3.5 + (seed % 3) * 0.55;
  a.push(wallElement('CoralStem', base, facing, 0, height / 2, 0.45, [0.7, height, 0.6], rgb));
  for (const dir of [-1, 1]) {
    a.push(wallElement('CoralBranch', base, facing, dir * 1.15, height * 0.55, 0.48, [0.55, 2.4, 0.6], rgb, dir * -0.65));
    a.push(wallElement('CoralTip', base, facing, dir * 1.85, height * 0.82, 0.51, [0.52, 1.7, 0.6], rgb));
    a.push(wallElement('CoralPolyp', base, facing, dir * 1.85, height * 0.82 + 0.88, 0.54, [0.63, 0.25, 0.66], rgb.map(c => Math.min(255, c + 35)), 0, { studs: false }));
  }
  target.push(model(target === seabedDecor ? 'SeabedCoral' : 'WallBaseCoral', a));
}

for (const side of [-1, 1]) {
  for (let j = 0; j < 5; j++) {
    const z = -144 + j * 30;
    kelp(side * (spawnHalf - 2.7), 4, z, Math.PI / 2, j + side * 2);
    bubbleSource(side * (spawnHalf - 3.9), 5, z + 8, 19, j + 5);
    caustic(side, spawnHalf, 20, z + 3, j, [150, 222, 214]);
    if (j % 2 === 0) wallShell([side * (spawnHalf - 0.35), 13, z + 10], -side * Math.PI / 2, 1.2, [211, 189, 143]);
    else wallStar([side * (spawnHalf - 0.35), 15, z + 10], -side * Math.PI / 2, 1.15, [206, 142, 116]);
  }
  wallWave([side * (spawnHalf - 0.35), 25, -80], -side * Math.PI / 2, 144, [112, 198, 192]);
  for (let s = 0; s < 5; s++) {
    for (let j = 0; j < 6; j++) {
      const z = s * 192 + 22 + j * 30;
      kelp(side * 61.5, floorAt(z) + 0.15, z, Math.PI / 2, s * 3 + j + side, s);
      // Clamp shallow sources below the surface; dry entry stays clean.
      if (floorAt(z + 6) < -2) bubbleSource(side * 60.6, floorAt(z + 6) + 0.8, z + 6, Math.min(26, -floorAt(z + 6) - 1.2), s + j);
      caustic(side, 64, floorAt(z) + 14, z, s + j, palettes[s].line);
      if (s > 1) caustic(side, 64, -12, z + 10, s - j, palettes[s].line);
      if (floorAt(z + 12) < -10) {
        const base = [side * 63.55, floorAt(z + 12) + 0.1, z + 12];
        coral(base, -side * Math.PI / 2, j + s, s);
        if (j % 2 === 0) wallStar([base[0], floorAt(z) + 7, z + 9], -side * Math.PI / 2, 1.1, s > 2 ? [177, 150, 211] : [226, 151, 124]);
        else wallShell([base[0], floorAt(z) + 5, z + 12], -side * Math.PI / 2, 0.85, [194, 212, 201]);
      }
      // Mid-depth life fills the tall walls as the canal gets deeper.
      if (s > 1 && j % 2 === 0) {
        const middleY = floorAt(z) * 0.5;
        blade([side * 63.1, middleY - 5, z + 4], 12 + s, 1.4, Math.PI / 2, [53, 165, 161], s + j);
        wallBubbles([side * 63.55, middleY + 6, z + 13], -side * Math.PI / 2, 1.15, palettes[s].line);
        bubbleSource(side * 61.3, middleY, z - 4, Math.min(26, -middleY - 1), s * 2 + j);
      }
    }
    wallBubbles([side * 63.55, 9, s * 192 + 96], -side * Math.PI / 2, 1.25, palettes[s].line);
    wallWave([side * 63.55, 26, s * 192 + 96], -side * Math.PI / 2, 162, palettes[s].line);
  }
}
// Back wall kelp uses the same perimeter-only footprint.
for (const x of [-120, -80, -40, 0, 40, 80, 120]) {
  kelp(x, 4, -157.3, 0, x / 18);
  bubbleSource(x + 7, 5, -156.5, 19, Math.abs(x / 18));
  if (x % 80 === 0) wallShell([x + 15, 14, -159.6], 0, 1.4, [211, 189, 143]);
  else wallStar([x + 13, 17, -159.6], 0, 1.05, [206, 142, 116]);
}
wallWave([0, 26, -159.6], 0, spawnWidth - 16, [112, 198, 192]);
for (const side of [-1, 1]) {
  wallBubbles([side * 114, 10, -0.4], Math.PI, 1.3, [133, 214, 202]);
  wallShell([side * 84, 15, -0.4], Math.PI, 1.35, [211, 189, 143]);
}

// Scattered low, non-colliding details across the whole canal floor.
// Deterministic jitter avoids rows of identical props and keeps the slope
// and all section boundaries readable through the clear water.
let seedState = 402818;
function random() {
  seedState = (Math.imul(seedState, 1664525) + 1013904223) >>> 0;
  return seedState / 4294967296;
}
function groundPart(name, x, z, local, size, rgb, yaw = 0, options = {}) {
  const section = clamp(Math.floor(z / 192), 0, 4);
  const tilt = Math.atan((levels[section] - levels[section + 1]) / 192);
  const ground = rx(tilt);
  const orient = mult(ground, ry(yaw));
  const offset = [0, 1, 2].map(i => orient.slice(i * 3, i * 3 + 3).reduce((sum, v, j) => sum + v * local[j], 0));
  return part(name, size, [x + offset[0], floorAt(z) + offset[1], z + offset[2]], rgb, { r: orient, collide: false, ...options });
}
function floorShell(x, z, scale, yaw, rgb) {
  const a = [];
  for (let j = -3; j <= 3; j++) {
    const angle = j * 0.22;
    const length = (2.6 - Math.abs(j) * 0.18) * scale;
    a.push(groundPart('SeabedShellRib', x, z, [0, 0.22 + (3 - Math.abs(j)) * 0.025, length / 2],
      [0.42 * scale, 0.32, length], rgb.map(c => clamp(c + (j % 2 ? -10 : 5), 0, 255)), yaw + angle));
  }
  a.push(groundPart('SeabedShellHinge', x, z, [0, 0.29, 0], [1.05 * scale, 0.48, 0.6 * scale], rgb, yaw));
  seabedDecor.push(model('SeabedShell', a));
}
function floorStar(x, z, scale, yaw) {
  const rgb = random() > 0.5 ? [202, 135, 111] : [193, 164, 122];
  const a = [];
  for (let arm = 0; arm < 5; arm++) {
    const angle = yaw + arm * Math.PI * 2 / 5;
    for (let j = 0; j < 2; j++) {
      a.push(groundPart('SeabedStarArm', x, z, [0, 0.2 + arm * 0.009 + j * 0.016, (0.55 + j * 0.75) * scale],
        [(j ? 0.43 : 0.7) * scale, 0.3, 0.95 * scale], rgb, angle));
    }
  }
  a.push(groundPart('SeabedStarCentre', x, z, [0, 0.28, 0], [scale, 0.34, scale], rgb, yaw));
  seabedDecor.push(model('SeabedStarfish', a));
}
for (let row = 0, zBase = 64; zBase < 950; row++, zBase += 24) {
  for (let column = 0; column < 6; column++) {
    const x = -51 + column * 20 + (random() - 0.5) * 9;
    const z = zBase + (random() - 0.5) * 10;
    const s = clamp(Math.floor(z / 192), 0, 4);
    const yaw = random() * Math.PI * 2;
    const rgb = [[193, 188, 160], [166, 191, 184], [188, 164, 145]][Math.floor(random() * 3)];
    floorShell(x, z, 0.65 + random() * 0.75, yaw, rgb);
    if ((row + column) % 3 === 0) floorStar(x + 3.8, z + 4, 0.55 + random() * 0.5, yaw + 1);
    if ((row + column) % 4 === 1) floorShell(x - 3.6, z + 3, 0.45 + random() * 0.4, yaw + 2, rgb);
    if (random() < 0.72) {
      const groundZ = z + 6;
      const groundX = x - 2.8;
      const count = 2 + Math.floor(random() * 2);
      const maximumHeight = Math.min(7, -floorAt(groundZ) - 0.8);
      const hue = s > 2 ? [53, 130, 141] : [41, 143, 113];
      for (let b = 0; b < count; b++) {
        const bx = groundX + (b - 1) * 0.9;
        const bz = groundZ + (random() - 0.5) * 1.2;
        blade([bx, floorAt(bz) + 0.15, bz], Math.min(maximumHeight, 2.7 + random() * 4.3), 0.65 + random() * 0.4, yaw + b * 0.7, hue, row + column * 2 + b, seabedDecor);
      }
    }
    if (s > 0 && (row * 3 + column) % 5 === 0) {
      coral([x + 4, floorAt(z - 4) + 0.2, z - 4], yaw, row + column, s, seabedDecor);
    }
    const stones = [];
    for (let j = 0; j < 2; j++) {
      stones.push(groundPart('SeabedPebble', x + 4 + j, z - 2 + random() * 3,
        [0, 0.15, 0], [0.6 + random(), 0.3, 0.5 + random() * 0.7], [111, 141, 143], random() * Math.PI));
    }
    seabedDecor.push(model('SeabedPebbles', stones));
    seabedPatches.push({ x, z, section: s + 1 });
  }
}

// This editor-only surface disappears when the Terrain is baked or on Play.
const previews = [];
for (let s = 0; s < 5; s++) {
  const start = s === 0 ? 32 : s * 192;
  const end = (s + 1) * 192;
  // SmoothPlastic avoids the glass pass hiding underwater transparent FX.
  // This is only an editor guide, never a second layer over Terrain water.
  previews.push(part('WaterSurfacePreview', [128, 0.05, end - start], [0, 0, (start + end) / 2], [126, 170, 176], { material: 272, alpha: 0.94, reflectance: 0, collide: false, studs: false }));
}
const map = model('OceanMap', [model('SpawnCourt', spawn), folder('Sections', sections), folder('WallDecor', decorations), folder('SeabedDecor', seabedDecor), folder('BubblePreview', bubblePreview), folder('WaterPreview', previews)]);

function lookAt(eye, target) {
  const normal = a => { const d = Math.hypot(...a); return a.map(v => v / d); };
  const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  const back = normal(eye.map((x, i) => x - target[i]));
  const right = normal(cross([0, 1, 0], back));
  const up = cross(back, right);
  return [right[0], up[0], back[0], right[1], up[1], back[1], right[2], up[2], back[2]];
}
const cameraPos = [193, 160, -265], target = [0, 0, 62];
const camera = item('Camera', 'Camera', cf('CFrame', cameraPos, lookAt(cameraPos, target)) + cf('Focus', target) + num('FieldOfView', 64) + token('CameraType', 0), '', 'OceanCamera');
const terrain = item('Terrain', 'Terrain', color('WaterColor', [126, 170, 176]) + num('WaterTransparency', 1) + num('WaterReflectance', 0) + num('WaterWaveSize', 0.06) + num('WaterWaveSpeed', 4));
out.push(item('Workspace', 'Workspace', tag('Ref', 'CurrentCamera', 'OceanCamera') + num('Gravity', 196.2) + num('FallenPartsDestroyHeight', -500) + bool('StreamingEnabled', false), camera + terrain + map));
out.push(item('Lighting', 'Lighting',
  color('Ambient', [137, 163, 180]) + color('OutdoorAmbient', [165, 188, 200]) + num('Brightness', 2)
  + num('ClockTime', 14) + num('GeographicLatitude', 23) + bool('GlobalShadows', true)
  + num('EnvironmentDiffuseScale', 0.7) + num('EnvironmentSpecularScale', 0.45)
  + color('FogColor', [154, 218, 229]) + num('FogStart', 700) + num('FogEnd', 2600),
  item('Atmosphere', 'OceanAir', num('Density', 0.16) + num('Offset', 0.12) + color('Color', [187, 233, 244]) + color('Decay', [124, 186, 213]) + num('Glare', 0.08) + num('Haze', 0.6))
  + item('BloomEffect', 'SoftWaterGlow', num('Intensity', 0.12) + num('Size', 20) + num('Threshold', 1.5))));
const read = name => fs.readFileSync(path.join(root, 'src', name), 'utf8');
const source = text => tag('ProtectedString', 'Source', `<![CDATA[${text.replaceAll(']]>', ']]]]><![CDATA[>')}]]>`);
out.push(item('ServerStorage', 'ServerStorage', '', item('ModuleScript', 'OceanWater', source(read('OceanWater.luau')))));
out.push(item('ReplicatedStorage', 'ReplicatedStorage', '', item('ModuleScript', 'OceanEnvironment', source(read('OceanEnvironment.luau')))));
out.push(item('ServerScriptService', 'ServerScriptService', '', item('Script', 'OceanStart', source(read('OceanStart.server.luau')) + bool('Disabled', false))));
out.push(item('StarterPlayer', 'StarterPlayer', num('CameraMaxZoomDistance', 80) + num('CameraMinZoomDistance', 0.5), item('StarterPlayerScripts', 'StarterPlayerScripts', '',
  item('LocalScript', 'OceanAmbience', source(read('OceanAmbience.client.luau')) + bool('Disabled', false))
  + item('LocalScript', 'OceanPlayer', source(read('OceanPlayer.client.luau')) + bool('Disabled', false)))));
const xml = `<roblox version="4"><External>null</External><External>nil</External>${out.join('')}</roblox>`;
fs.writeFileSync(path.join(root, 'OceanMap.rbxlx'), xml);
fs.writeFileSync(path.join(root, 'OceanMap-v4.rbxlx'), xml);
fs.writeFileSync(path.join(root, 'tools', 'geometry.json'), JSON.stringify(geometry));
const summary = {
  revision: 4,
  water: { transparency: 1, reflectance: 0, color: [126, 170, 176], editorPreviewTransparency: 0.94 },
  spawn: { width: spawnWidth, previousWidth: 192, length: 160, floorY: 4, palette: 'sand floor / dark teal walls' },
  corridor: { width: 128, length: 960, waterY: 0, sectionCount: 5, floorLevels: levels },
  sections: palettes.map((p, i) => ({ name: p.name, fromZ: i * 192, toZ: (i + 1) * 192, floorStart: levels[i], floorEnd: levels[i + 1] })),
  visibleParts: geometry.length, xmlBytes: Buffer.byteLength(xml),
  seabed: { patches: seabedPatches.length, patchesPerSection: [1, 2, 3, 4, 5].map(s => seabedPatches.filter(p => p.section === s).length), ...Object.fromEntries(['SeabedShell', 'SeabedStarfish', 'KelpBlade', 'SeabedCoral', 'SeabedPebbles'].map(name => [name, seabedDecor.filter(x => x.includes(`<string name="Name">${name}</string>`)).length])) },
  decor: Object.fromEntries(['KelpBlade', 'BubbleSource', 'WallStarfish', 'WallShell', 'WallBaseCoral', 'WallWave', 'BubbleWallRelief'].map(name => [name, decorations.filter(x => x.includes(`<string name="Name">${name}</string>`)).length])),
};
fs.writeFileSync(path.join(root, 'map-manifest.json'), JSON.stringify(summary, null, 2));
console.log(JSON.stringify(summary, null, 2));
