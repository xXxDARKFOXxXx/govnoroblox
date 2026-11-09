-- BasePieces: part helpers and sea props built from plain Parts. Like the
-- court floor and walls, everything is Plastic with studs on every face, so
-- the bases look like the rest of the place (toy bricks).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))
local C = Config.Colors

local Pieces = {}
local STUDS = Enum.SurfaceType.Studs
local FACES = {"TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface"}

-- Decorative part: anchored, no collision / touch / query, studded Plastic.
function Pieces.part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props: {[string]: any}?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Plastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	for _, face in FACES do p[face] = STUDS end
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

-- Ellipsoid via the built-in sphere mesh (no uploaded assets).
function Pieces.ellipsoid(parent, name, size: Vector3, cf: CFrame, color, material, props)
	local p = Pieces.part(parent, name, size, cf, color, material or Enum.Material.SmoothPlastic, props)
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
	p.Material = material or Enum.Material.Plastic
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

-- Rod between two points.
function Pieces.rod(parent, name, a: Vector3, b: Vector3, thickness: number, color, material)
	local length = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	local p = Pieces.part(parent, name, Vector3.new(length, thickness, thickness), cf, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

---------------------------------------------------------------- sea life (blocky)
-- Kelp: two stacks of studded bricks that lean as they rise.
function Pieces.kelp(parent, cf: CFrame, height: number, seed: number)
	local m = Pieces.model(parent, "Kelp")
	for blade = 0, 1 do
		local segments = 3
		local segment = height / segments * (blade == 0 and 1 or 0.75)
		local c = cf * CFrame.Angles(0, math.rad(seed * 40 + blade * 110), 0) * CFrame.new(blade * 0.6, 0, 0)
		for i = 1, segments do
			local width = 1.0 - i * 0.15
			Pieces.part(m, "KelpBlade", Vector3.new(width, segment * 1.05, width * 0.6), c * CFrame.new(0, segment / 2, 0), C.KelpDark:Lerp(C.Kelp, i / segments))
			local bend = math.sin(i * 1.3 + seed + blade) * 16
			c = c * CFrame.new(0, segment, 0) * CFrame.Angles(0, 0, math.rad(bend))
		end
	end
	return m
end

-- Coral made of studded bricks: a trunk with branches and rounded tips.
function Pieces.coral(parent, cf: CFrame, color: Color3, scale: number?)
	local s = scale or 1
	local m = Pieces.model(parent, "Coral")
	Pieces.part(m, "CoralTrunk", Vector3.new(0.8, 1.4, 0.8) * s, cf * CFrame.new(0, 0.7 * s, 0), color)
	for i, angle in {-35, 0, 40} do
		local branch = cf * CFrame.new(0, 1.2 * s, 0) * CFrame.Angles(0, math.rad(i * 110), math.rad(angle))
		local length = (i == 2 and 1.8 or 1.3) * s
		Pieces.part(m, "CoralBranch", Vector3.new(0.6 * s, length, 0.6 * s), branch * CFrame.new(0, length / 2, 0), color)
		Pieces.ball(m, "CoralTip", 0.8 * s, branch * CFrame.new(0, length, 0), color:Lerp(C.White, 0.25))
	end
	return m
end

function Pieces.starfish(parent, cf: CFrame, scale: number?)
	local s = scale or 1
	local m = Pieces.model(parent, "Starfish")
	Pieces.part(m, "StarCentre", Vector3.new(0.7, 0.3, 0.7) * s, cf * CFrame.new(0, 0.15 * s, 0), C.Starfish)
	for i = 0, 4 do
		Pieces.part(m, "StarArm", Vector3.new(0.4, 0.25, 1.0) * s, cf * CFrame.Angles(0, math.rad(i * 72), 0) * CFrame.new(0, 0.13 * s, -0.6 * s), C.Starfish)
	end
	return m
end

function Pieces.shell(parent, cf: CFrame, scale: number?)
	local s = scale or 1
	local m = Pieces.model(parent, "Shell")
	for i = -2, 2 do
		local rib = cf * CFrame.Angles(0, math.rad(i * 19), 0) * CFrame.new(0, 0.15 * s, -0.5 * s)
		Pieces.part(m, "ShellRib", Vector3.new(0.34, 0.3, 1.0) * s, rib, i % 2 == 0 and C.Shell or C.Shell:Lerp(C.CoralPink, 0.25))
	end
	return m
end

function Pieces.pebbles(parent, cf: CFrame, count: number, seed: number)
	local m = Pieces.model(parent, "Pebbles")
	for i = 1, count do
		local a = seed * 2.1 + i * 2.4
		local size = 0.6 + (i % 3) * 0.2
		Pieces.part(m, "Pebble", Vector3.new(size * 1.2, size * 0.7, size), cf * CFrame.new(math.cos(a) * 0.9, size * 0.35, math.sin(a) * 0.9) * CFrame.Angles(0, a, 0),
			C.StoneDark:Lerp(C.Stone, (i % 2) * 0.6))
	end
	return m
end

function Pieces.crystals(parent, cf: CFrame, scale: number?)
	local s = scale or 1
	local m = Pieces.model(parent, "Crystals")
	for i, data in {{0, 0, 2.0, 0}, {0.7, 0.3, 1.4, 20}, {-0.6, 0.3, 1.1, -22}} do
		local c = cf * CFrame.new(data[1] * s, 0, data[2] * s) * CFrame.Angles(0, math.rad(i * 50), math.rad(data[4]))
		local h = data[3] * s
		Pieces.part(m, "Crystal", Vector3.new(0.6 * s, h, 0.6 * s), c * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, math.rad(45), 0), C.GlowBlue, Enum.Material.Neon, {Transparency = 0.1})
	end
	return m
end

function Pieces.barrel(parent, cf: CFrame)
	local m = Pieces.model(parent, "Barrel")
	Pieces.cylinder(m, "BarrelBody", 2.4, 2.0, cf * CFrame.new(0, 1.2, 0), C.Wood)
	for _, y in {0.4, 2.0} do
		Pieces.cylinder(m, "BarrelHoop", 0.25, 2.1, cf * CFrame.new(0, y, 0), C.Metal)
	end
	return m
end

function Pieces.crate(parent, cf: CFrame, size: number?)
	local s = size or 2
	local m = Pieces.model(parent, "Crate")
	Pieces.part(m, "CrateBox", Vector3.new(s, s, s), cf * CFrame.new(0, s / 2, 0), C.WoodLight)
	Pieces.part(m, "CrateBand", Vector3.new(s + 0.1, 0.3, s + 0.1), cf * CFrame.new(0, s * 0.5, 0), C.WoodDark)
	return m
end

function Pieces.buoy(parent, cf: CFrame)
	local m = Pieces.model(parent, "Buoy")
	Pieces.ball(m, "BuoyTop", 1.3, cf * CFrame.new(0, 0.65, 0), C.Red)
	Pieces.cylinder(m, "BuoyBand", 0.35, 1.36, cf * CFrame.new(0, 0.65, 0), C.White)
	return m
end

-- Ship anchor standing on its crown (cf faces +Z), blocky.
function Pieces.anchor(parent, cf: CFrame, scale: number?)
	local s = scale or 1
	local m = Pieces.model(parent, "Anchor")
	Pieces.part(m, "AnchorShank", Vector3.new(0.6, 3.2, 0.6) * s, cf * CFrame.new(0, 2.0 * s, 0), C.Metal)
	Pieces.part(m, "AnchorStock", Vector3.new(2.2, 0.5, 0.5) * s, cf * CFrame.new(0, 3.2 * s, 0), C.WoodDark)
	Pieces.part(m, "AnchorBase", Vector3.new(2.6, 0.6, 0.6) * s, cf * CFrame.new(0, 0.6 * s, 0), C.Metal)
	for _, side in {-1, 1} do
		Pieces.part(m, "AnchorFluke", Vector3.new(0.6, 1.2, 0.6) * s, cf * CFrame.new(side * 1.3 * s, 1.1 * s, 0), C.Metal)
	end
	return m
end

-- Lamp block on a post (neon core, optional real light).
function Pieces.lamp(parent, cf: CFrame, light: boolean?)
	local glow = Pieces.part(parent, "Lamp", Vector3.new(1.0, 1.0, 1.0), cf * CFrame.new(0, 0.5, 0), C.GlowGold, Enum.Material.Neon)
	if light then
		local l = Instance.new("PointLight")
		l.Color = C.GlowGold
		l.Range = 16
		l.Brightness = 1.3
		l.Shadows = false
		l.Parent = glow
	end
	return glow
end

return Pieces
