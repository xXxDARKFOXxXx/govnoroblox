-- BasePieces: part helpers and reusable sea-themed props (kelp, coral, shells,
-- starfish, lanterns, ropes, nets, barrels, crates, anchors, life rings, buoys,
-- flags, crystals). Every prop is built from plain Parts relative to a CFrame,
-- so the same code runs in Studio, on the server and in the offline build.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))
local C = Config.Colors

local Pieces = {}
local SMOOTH = Enum.SurfaceType.Smooth

-- Decorative part: anchored, no collision / touch / query.
function Pieces.part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props: {[string]: any}?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	if props then
		for key, value in pairs(props) do p[key] = value end
	end
	p.Parent = parent
	return p
end

-- Walkable / blocking part.
function Pieces.solid(parent, name, size, cf, color, material, props)
	local p = Pieces.part(parent, name, size, cf, color, material, props)
	p.CanCollide = true
	return p
end

-- Cylinder standing upright (Roblox cylinders run along X, so rotate).
function Pieces.cylinder(parent, name, height: number, diameter: number, cf: CFrame, color, material, props)
	local p = Pieces.part(parent, name, Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.rad(90)), color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function Pieces.ball(parent, name, diameter: number, cf: CFrame, color, material, props)
	local p = Pieces.part(parent, name, Vector3.new(diameter, diameter, diameter), cf, color, material, props)
	p.Shape = Enum.PartType.Ball
	return p
end

-- Ellipsoid via a built-in sphere mesh (no uploaded assets).
function Pieces.ellipsoid(parent, name, size: Vector3, cf: CFrame, color, material, props)
	local p = Pieces.part(parent, name, size, cf, color, material, props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

function Pieces.wedge(parent, name, size: Vector3, cf: CFrame, color, material)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Parent = parent
	return p
end

function Pieces.model(parent: Instance, name: string)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Pieces.folder(parent: Instance, name: string)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Rod between two points (rope, chain, rail).
function Pieces.rod(parent, name, a: Vector3, b: Vector3, thickness: number, color, material)
	local length = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	local p = Pieces.part(parent, name, Vector3.new(length, thickness, thickness), cf, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

---------------------------------------------------------------- plants & sea life
-- Curved kelp: two tapering blades that bend as they rise.
function Pieces.kelp(parent, cf: CFrame, height: number, seed: number)
	local m = Pieces.model(parent, "Kelp")
	for blade = 0, 1 do
		local segments = 3
		local segment = height / segments * (blade == 0 and 1 or 0.78)
		local c = cf * CFrame.Angles(0, math.rad(seed * 40 + blade * 110), 0) * CFrame.new(blade * 0.35, 0, 0)
		for i = 1, segments do
			local width = 0.66 - i * 0.1
			local color = C.KelpDark:Lerp(C.Kelp, i / segments)
			Pieces.part(m, "KelpBlade", Vector3.new(width, segment * 1.08, 0.22), c * CFrame.new(0, segment / 2, 0), color)
			local bend = math.sin(i * 1.3 + seed + blade) * 22
			c = c * CFrame.new(0, segment, 0) * CFrame.Angles(math.rad(bend * 0.4), 0, math.rad(bend))
		end
	end
	return m
end

-- Branching coral with rounded tips.
function Pieces.coral(parent, cf: CFrame, color: Color3, scale: number?)
	local s = scale or 1
	local m = Pieces.model(parent, "Coral")
	Pieces.cylinder(m, "CoralTrunk", 1.1 * s, 0.45 * s, cf * CFrame.new(0, 0.55 * s, 0), color)
	for i, angle in {-38, 0, 42} do
		local branch = cf * CFrame.new(0, 0.9 * s, 0) * CFrame.Angles(0, math.rad(i * 95), math.rad(angle))
		local length = (i == 2 and 1.4 or 1.0) * s
		Pieces.cylinder(m, "CoralBranch", length, 0.32 * s, branch * CFrame.new(0, length / 2, 0), color)
		Pieces.ball(m, "CoralTip", 0.46 * s, branch * CFrame.new(0, length, 0), color:Lerp(C.White, 0.25))
	end
	return m
end

-- Five-armed starfish lying on the surface defined by cf (its up vector).
function Pieces.starfish(parent, cf: CFrame, scale: number?)
	local s = scale or 1
	local m = Pieces.model(parent, "Starfish")
	Pieces.cylinder(m, "StarCentre", 0.22 * s, 0.6 * s, cf * CFrame.new(0, 0.11 * s, 0), C.Starfish)
	for i = 0, 4 do
		local arm = cf * CFrame.Angles(0, math.rad(i * 72), 0) * CFrame.new(0, 0.1 * s, -0.55 * s)
		Pieces.part(m, "StarArm", Vector3.new(0.34 * s, 0.18 * s, 0.9 * s), arm, C.Starfish)
	end
	return m
end

-- Scallop shell: a fan of ribs.
function Pieces.shell(parent, cf: CFrame, scale: number?)
	local s = scale or 1
	local m = Pieces.model(parent, "Shell")
	for i = -2, 2 do
		local rib = cf * CFrame.Angles(0, math.rad(i * 19), 0) * CFrame.new(0, 0.12 * s, -0.45 * s)
		local color = i % 2 == 0 and C.Shell or C.Shell:Lerp(C.CoralPink, 0.25)
		Pieces.part(m, "ShellRib", Vector3.new(0.3 * s, 0.24 * s, 0.95 * s), rib, color)
	end
	Pieces.part(m, "ShellHinge", Vector3.new(0.5 * s, 0.22 * s, 0.24 * s), cf * CFrame.new(0, 0.11 * s, 0.05 * s), C.Shell:Lerp(C.Starfish, 0.2))
	return m
end

function Pieces.pebbles(parent, cf: CFrame, count: number, seed: number)
	local m = Pieces.model(parent, "Pebbles")
	for i = 1, count do
		local a = seed * 2.1 + i * 2.4
		local size = 0.35 + (i % 3) * 0.12
		Pieces.part(m, "Pebble", Vector3.new(size * 1.3, size * 0.7, size),
			cf * CFrame.new(math.cos(a) * 0.6, size * 0.3, math.sin(a) * 0.6) * CFrame.Angles(0, a, 0.2),
			C.StoneDark:Lerp(C.Stone, (i % 2) * 0.6))
	end
	return m
end

function Pieces.crystals(parent, cf: CFrame, scale: number?)
	local s = scale or 1
	local m = Pieces.model(parent, "Crystals")
	for i, data in {{0, 0, 1.6, 0}, {0.5, 0.2, 1.1, 22}, {-0.45, 0.25, 0.9, -25}} do
		local c = cf * CFrame.new(data[1] * s, 0, data[2] * s) * CFrame.Angles(0, math.rad(i * 50), math.rad(data[4]))
		local h = data[3] * s
		Pieces.part(m, "Crystal", Vector3.new(0.45 * s, h, 0.45 * s), c * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, math.rad(45), 0), C.GlowBlue, Enum.Material.Neon, {Transparency = 0.15})
	end
	return m
end

---------------------------------------------------------------- harbour props
-- Lantern with a warm glowing core; light = true adds a PointLight (use sparingly).
function Pieces.lantern(parent, cf: CFrame, light: boolean?)
	local m = Pieces.model(parent, "Lantern")
	Pieces.part(m, "LanternBase", Vector3.new(0.9, 0.18, 0.9), cf * CFrame.new(0, 0.09, 0), C.WoodDark)
	local glow = Pieces.part(m, "LanternGlow", Vector3.new(0.62, 0.7, 0.62), cf * CFrame.new(0, 0.53, 0), C.GlowGold, Enum.Material.Neon)
	for _, x in {-0.36, 0.36} do
		for _, z in {-0.36, 0.36} do
			Pieces.part(m, "LanternFrame", Vector3.new(0.1, 0.78, 0.1), cf * CFrame.new(x, 0.57, z), C.WoodDark)
		end
	end
	Pieces.part(m, "LanternRoof", Vector3.new(1.0, 0.16, 1.0), cf * CFrame.new(0, 1.0, 0), C.WoodDark)
	Pieces.part(m, "LanternTop", Vector3.new(0.5, 0.2, 0.5), cf * CFrame.new(0, 1.18, 0), C.WoodDark)
	if light then
		local l = Instance.new("PointLight")
		l.Color = C.GlowGold
		l.Range = 16
		l.Brightness = 1.4
		l.Shadows = false
		l.Parent = glow
	end
	return m
end

-- Sagging rope between two points (a few rod segments on a parabola).
function Pieces.rope(parent, a: Vector3, b: Vector3, sag: number, thickness: number?)
	local m = Pieces.model(parent, "Rope")
	local segments = 3
	local previous = a
	for i = 1, segments do
		local t = i / segments
		local point = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		Pieces.rod(m, "RopeSegment", previous, point, thickness or 0.32, C.Rope)
		previous = point
	end
	return m
end

-- Fishing net hanging in a rectangle (cf = top-left corner, facing +Z).
function Pieces.net(parent, cf: CFrame, width: number, height: number)
	local m = Pieces.model(parent, "Net")
	local cols, rows = math.max(2, math.floor(width / 0.9)), math.max(2, math.floor(height / 0.8))
	for i = 0, cols do
		local x = i / cols * width
		local sagTop = math.sin(i / cols * math.pi) * 0.35
		Pieces.part(m, "NetCord", Vector3.new(0.07, height - sagTop, 0.07), cf * CFrame.new(x, -(height + sagTop) / 2, 0), C.Net)
	end
	for j = 1, rows do
		local y = j / rows * height
		Pieces.part(m, "NetCord", Vector3.new(width, 0.07, 0.07), cf * CFrame.new(width / 2, -y + 0.05, 0), C.Net)
	end
	return m
end

function Pieces.barrel(parent, cf: CFrame)
	local m = Pieces.model(parent, "Barrel")
	Pieces.cylinder(m, "BarrelBody", 2.3, 1.9, cf * CFrame.new(0, 1.15, 0), C.Wood, Enum.Material.WoodPlanks)
	Pieces.cylinder(m, "BarrelBelly", 1.1, 2.06, cf * CFrame.new(0, 1.15, 0), C.WoodLight, Enum.Material.WoodPlanks)
	for _, y in {0.35, 1.95} do
		Pieces.cylinder(m, "BarrelHoop", 0.2, 2.0, cf * CFrame.new(0, y, 0), C.Metal, Enum.Material.Metal)
	end
	Pieces.cylinder(m, "BarrelLid", 0.12, 1.7, cf * CFrame.new(0, 2.32, 0), C.WoodDark)
	return m
end

function Pieces.crate(parent, cf: CFrame, size: number?)
	local s = size or 2
	local m = Pieces.model(parent, "Crate")
	Pieces.part(m, "CrateBox", Vector3.new(s, s, s), cf * CFrame.new(0, s / 2, 0), C.WoodLight, Enum.Material.WoodPlanks)
	for _, x in {-1, 1} do
		for _, z in {-1, 1} do
			Pieces.part(m, "CrateEdge", Vector3.new(0.24, s + 0.04, 0.24), cf * CFrame.new(x * (s / 2 - 0.1), s / 2, z * (s / 2 - 0.1)), C.WoodDark)
		end
	end
	Pieces.part(m, "CrateBrace", Vector3.new(0.22, s * 1.25, 0.1), cf * CFrame.new(0, s / 2, s / 2 + 0.03) * CFrame.Angles(0, 0, math.rad(45)), C.WoodDark)
	Pieces.part(m, "CrateLid", Vector3.new(s + 0.1, 0.18, s + 0.1), cf * CFrame.new(0, s + 0.05, 0), C.Wood)
	return m
end

-- Ship anchor standing on its crown (cf faces +Z).
function Pieces.anchor(parent, cf: CFrame, scale: number?)
	local s = scale or 1
	local m = Pieces.model(parent, "Anchor")
	local metal = C.Metal
	Pieces.part(m, "AnchorShank", Vector3.new(0.4 * s, 3 * s, 0.4 * s), cf * CFrame.new(0, 1.9 * s, 0), metal, Enum.Material.Metal)
	Pieces.part(m, "AnchorStock", Vector3.new(2 * s, 0.32 * s, 0.32 * s), cf * CFrame.new(0, 3.0 * s, 0), C.WoodDark)
	for i = 0, 7 do
		local a = math.rad(i * 45)
		Pieces.part(m, "AnchorRing", Vector3.new(0.22 * s, 0.32 * s, 0.22 * s),
			cf * CFrame.new(math.cos(a) * 0.38 * s, 3.65 * s + math.sin(a) * 0.38 * s, 0) * CFrame.Angles(0, 0, a), metal, Enum.Material.Metal)
	end
	for _, side in {-1, 1} do
		local arm = cf * CFrame.new(side * 0.7 * s, 0.75 * s, 0) * CFrame.Angles(0, 0, math.rad(side * -55))
		Pieces.part(m, "AnchorArm", Vector3.new(0.36 * s, 1.6 * s, 0.36 * s), arm, metal, Enum.Material.Metal)
		Pieces.wedge(m, "AnchorFluke", Vector3.new(0.3 * s, 0.7 * s, 0.6 * s),
			cf * CFrame.new(side * 1.3 * s, 1.35 * s, 0) * CFrame.Angles(0, math.rad(side * 90), 0), metal, Enum.Material.Metal)
	end
	return m
end

-- Red-and-white life ring; cf is its centre, ring faces +Z.
function Pieces.lifeRing(parent, cf: CFrame, radius: number?)
	local r = radius or 1
	local m = Pieces.model(parent, "LifeRing")
	for i = 0, 11 do
		local a = math.rad(i * 30)
		local color = math.floor(i / 3) % 2 == 0 and C.Red or C.White
		Pieces.part(m, "RingSegment", Vector3.new(0.42 * r, 0.6 * r, 0.42 * r),
			cf * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0) * CFrame.Angles(0, 0, a), color)
	end
	return m
end

function Pieces.buoy(parent, cf: CFrame)
	local m = Pieces.model(parent, "Buoy")
	Pieces.ellipsoid(m, "BuoyTop", Vector3.new(1.1, 1.0, 1.1), cf * CFrame.new(0, 0.5, 0), C.Red)
	Pieces.cylinder(m, "BuoyBand", 0.3, 1.14, cf * CFrame.new(0, 0.2, 0), C.White)
	Pieces.ellipsoid(m, "BuoyBottom", Vector3.new(1.0, 0.6, 1.0), cf * CFrame.new(0, -0.1, 0), C.Red)
	return m
end

function Pieces.flag(parent, cf: CFrame, height: number?)
	local h = height or 5
	local m = Pieces.model(parent, "Flag")
	Pieces.cylinder(m, "FlagPole", h, 0.22, cf * CFrame.new(0, h / 2, 0), C.WoodDark)
	Pieces.ball(m, "FlagTop", 0.4, cf * CFrame.new(0, h + 0.1, 0), C.Gold)
	for i = 0, 2 do
		local wave = math.sin(i * 1.4) * 0.18
		Pieces.part(m, "FlagCloth", Vector3.new(0.75, 1.3, 0.08), cf * CFrame.new(0.5 + i * 0.72, h - 0.8, wave) * CFrame.Angles(0, math.rad(i * 9), 0),
			i == 1 and C.Flag:Lerp(C.White, 0.15) or C.Flag)
	end
	return m
end

-- Small fish emblem (gold) on a plane facing +Z; used on signs and the arch.
function Pieces.fishEmblem(parent, cf: CFrame, scale: number?, glow: boolean?)
	local s = scale or 1
	local m = Pieces.model(parent, "FishEmblem")
	local material = glow and Enum.Material.Neon or Enum.Material.SmoothPlastic
	Pieces.ellipsoid(m, "EmblemBody", Vector3.new(1.4 * s, 0.85 * s, 0.14), cf, C.GlowGold, material)
	Pieces.wedge(m, "EmblemTail", Vector3.new(0.12, 0.8 * s, 0.5 * s), cf * CFrame.new(0.85 * s, 0.2 * s, 0) * CFrame.Angles(0, math.rad(90), math.rad(-25)), C.GlowGold, material)
	Pieces.wedge(m, "EmblemTail", Vector3.new(0.12, 0.8 * s, 0.5 * s), cf * CFrame.new(0.85 * s, -0.2 * s, 0) * CFrame.Angles(0, math.rad(90), math.rad(205)), C.GlowGold, material)
	Pieces.ball(m, "EmblemEye", 0.2 * s, cf * CFrame.new(-0.38 * s, 0.1 * s, 0.06), C.WoodDark)
	return m
end

-- Wave trim (blue scallops) along X, facing +Z; used under signs.
function Pieces.waveTrim(parent, cf: CFrame, width: number)
	local m = Pieces.model(parent, "WaveTrim")
	local count = math.max(2, math.floor(width / 1.1))
	for i = 0, count - 1 do
		local x = -width / 2 + (i + 0.5) * width / count
		Pieces.cylinder(m, "Wave", 0.22, width / count * 1.05, cf * CFrame.new(x, -0.1, 0) * CFrame.Angles(math.rad(90), 0, 0), C.GlowBlue:Lerp(C.Flag, 0.35))
	end
	-- The band hides the lower half of each disc, leaving a row of wave crests.
	Pieces.part(m, "WaveBand", Vector3.new(width + 0.2, 0.62, 0.3), cf * CFrame.new(0, -0.42, 0.08), C.Foam)
	return m
end

return Pieces
