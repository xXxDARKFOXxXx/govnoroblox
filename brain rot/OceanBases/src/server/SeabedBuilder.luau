-- SeabedBuilder: makes the ocean corridor look alive — a stepped, studded sand
-- relief (dunes higher near the walls, a lower channel in the middle), rocky
-- outcrops and ledges with stalactites on the walls, stalagmites, boulders,
-- sea grass, and the nests that hold the eggs of each section.
--
-- Workspace.OceanSeabed
--   Sand, Walls, Rocks, Grass   (static decor)
--   Nests/Nest_S_I              (Model, attributes Section, NestIndex, EggType;
--                                EggSpot part with the TakePrompt; Guards spot)
-- All geometry is studded Plastic, like the court. Everything is deterministic.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))
local Pieces = require(script.Parent:WaitForChild("BasePieces"))
local C = Config.Colors

local SeabedBuilder = {}

local FLOOR_LEVELS = {4, -20, -44, -76, -116, -164}
local SECTION_LENGTH = 192
local HALF_WIDTH = 64
local TILE = 8

-- Original sloped floor height (top surface) at a corridor position.
function SeabedBuilder.baseFloor(z: number): number
	local section = math.clamp(math.floor(z / SECTION_LENGTH) + 1, 1, 5)
	local alpha = math.clamp((z - (section - 1) * SECTION_LENGTH) / SECTION_LENGTH, 0, 1)
	return FLOOR_LEVELS[section] + (FLOOR_LEVELS[section + 1] - FLOOR_LEVELS[section]) * alpha
end

function SeabedBuilder.sectionAt(z: number): number
	return math.clamp(math.floor(z / SECTION_LENGTH) + 1, 1, 5)
end

---------------------------------------------------------------- noise
local function hash(x: number, y: number): number
	local n = math.sin(x * 127.1 + y * 311.7) * 43758.5453
	return n - math.floor(n)
end
local function smooth(t: number) return t * t * (3 - 2 * t) end
local function noise(x: number, y: number): number
	local ix, iy = math.floor(x), math.floor(y)
	local fx, fy = smooth(x - ix), smooth(y - iy)
	local a, b = hash(ix, iy), hash(ix + 1, iy)
	local c, d = hash(ix, iy + 1), hash(ix + 1, iy + 1)
	return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy
end

-- Sand relief height above the original floor (whole studs, 1..9).
function SeabedBuilder.relief(x: number, z: number): number
	local dunes = noise(x / 34 + 3.1, z / 34) * 3.2 + noise(x / 13, z / 13 + 7.7) * 1.4
	local edge = math.clamp((math.abs(x) - 30) / 30, 0, 1)
	local channel = math.clamp(1 - math.abs(x) / 18, 0, 1)
	local h = 1 + dunes + edge * edge * 5 - channel * 1.5
	-- Smooth start right after the court so the entry stays open.
	if z < 24 then h = math.min(h, 1 + z / 12) end
	return math.clamp(math.floor(h + 0.5), 1, 9)
end

-- Top of the sand at (x, z) — on the tile grid.
function SeabedBuilder.sandTop(x: number, z: number): number
	local tx = (math.floor((x + HALF_WIDTH) / TILE) + 0.5) * TILE - HALF_WIDTH
	local tz = (math.floor(z / TILE) + 0.5) * TILE
	return SeabedBuilder.baseFloor(tz) + SeabedBuilder.relief(tx, tz)
end

---------------------------------------------------------------- sand
local function buildSand(root)
	local folder = Pieces.folder(root, "Sand")
	for col = 0, (HALF_WIDTH * 2) / TILE - 1 do
		local x = -HALF_WIDTH + (col + 0.5) * TILE
		for row = 0, 960 / TILE - 1 do
			local z = (row + 0.5) * TILE
			local section = Config.Sections[SeabedBuilder.sectionAt(z)]
			local h = SeabedBuilder.relief(x, z)
			local top = SeabedBuilder.baseFloor(z) + h
			local depth = h + 3
			local shade = noise(x / 9, z / 9 + 40)
			local color = section.sand[(col + row) % 2 + 1]:Lerp(section.sand[2]:Lerp(Color3.new(0, 0, 0), 0.25), shade * 0.35)
			Pieces.solid(folder, "SandBlock", Vector3.new(TILE, depth, TILE), CFrame.new(x, top - depth / 2, z), color)
		end
	end
end

---------------------------------------------------------------- walls
local function rockColor(section, seed)
	return section.rock:Lerp(Color3.new(1, 1, 1), hash(seed, 3.3) * 0.18):Lerp(Color3.new(0, 0, 0), hash(seed, 9.1) * 0.25)
end

-- A hanging stack of shrinking blocks (or a rising one for stalagmites).
local function spire(folder, name, base: Vector3, direction: number, size: number, color: Color3, seed: number)
	local width, y = size, base.Y
	for i = 1, 4 do
		local h = size * (1.1 - i * 0.12) * (0.8 + hash(seed, i) * 0.5)
		local cy = y + direction * h / 2
		Pieces.solid(folder, name, Vector3.new(width, h, width), CFrame.new(base.X, cy, base.Z) * CFrame.Angles(0, hash(seed, i + 9) * 1.2, 0), color)
		y += direction * h
		width *= 0.68
		if width < 0.5 then break end
	end
end

local function buildWalls(root)
	local folder = Pieces.folder(root, "Walls")
	for s, section in Config.Sections do
		local deep = s / 5
		for _, side in {-1, 1} do
			-- Cliffs: rock columns growing from the sand along the wall, in 2-3
			-- receding tiers, so the wall gets a rugged, layered silhouette.
			local count = 11
			for i = 1, count do
				local seed = s * 100 + i * 7 + (side + 1) * 1000
				local z = section.fromZ + (i - 0.5) / count * (section.toZ - section.fromZ) + (hash(seed, 1) - 0.5) * 8
				local length = 8 + hash(seed, 5) * 12
				local depth = 2.5 + hash(seed, 4) * 4
				local y = SeabedBuilder.sandTop(side * (HALF_WIDTH - 2), z) - 1
				local maxTop = math.min(-2, y + 10 + hash(seed, 2) * 22)
				for tier = 1, 3 do
					local h = (maxTop - y) / (4 - tier) * (0.75 + hash(seed, tier + 30) * 0.4)
					if h < 1.5 then break end
					local d = depth * (1.15 - tier * 0.25)
					local l = length * (1.1 - tier * 0.2)
					local dz = (hash(seed, tier + 40) - 0.5) * length * 0.3
					Pieces.solid(folder, "Cliff", Vector3.new(d, h, l), CFrame.new(side * (HALF_WIDTH - d / 2), y + h / 2, z + dz), rockColor(section, seed + tier))
					y += h
					if y >= maxTop then break end
				end
			end
			-- Ledges with stalactites; deeper sections get more of them.
			local ledges = 2 + math.floor(deep * 3)
			for i = 1, ledges do
				local seed = s * 300 + i * 13 + (side + 1) * 2000
				local z = section.fromZ + (i - 0.5) / ledges * (section.toZ - section.fromZ)
				local floor = SeabedBuilder.baseFloor(z)
				local y = math.min(-3, floor + 14 + hash(seed, 1) * 8)
				local length = 14 + hash(seed, 2) * 10
				local ledgeDepth = 5 + hash(seed, 3) * 3
				local color = rockColor(section, seed)
				Pieces.solid(folder, "Ledge", Vector3.new(ledgeDepth, 2.4, length), CFrame.new(side * (HALF_WIDTH - ledgeDepth / 2), y, z), color)
				for k = 1, 3 + math.floor(deep * 2) do
					local sx = side * (HALF_WIDTH - 1 - hash(seed, k + 4) * (ledgeDepth - 1.5))
					local sz = z + (hash(seed, k + 20) - 0.5) * (length - 2)
					spire(folder, "Stalactite", Vector3.new(sx, y - 1.2, sz), -1, 1.6 + hash(seed, k) * 1.6, color, seed + k)
				end
			end
			-- Stalagmites rising from the sand by the wall.
			for i = 1, 3 + math.floor(deep * 3) do
				local seed = s * 500 + i * 17 + (side + 1) * 3000
				local z = section.fromZ + hash(seed, 1) * (section.toZ - section.fromZ)
				local x = side * (HALF_WIDTH - 3 - hash(seed, 2) * 6)
				spire(folder, "Stalagmite", Vector3.new(x, SeabedBuilder.sandTop(x, z), z), 1, 1.8 + hash(seed, 3) * 1.8, rockColor(section, seed), seed)
			end
		end
	end
end

---------------------------------------------------------------- rocks & grass
local function buildRocks(root)
	local rocks = Pieces.folder(root, "Rocks")
	local grass = Pieces.folder(root, "Grass")
	for s, section in Config.Sections do
		for i = 1, 8 do
			local seed = s * 700 + i * 31
			local side = hash(seed, 1) < 0.5 and -1 or 1
			local x = side * (24 + hash(seed, 2) * 30)
			local z = section.fromZ + 10 + hash(seed, 3) * (section.toZ - section.fromZ - 20)
			local top = SeabedBuilder.sandTop(x, z)
			for k = 1, 3 do
				local size = 2.5 + hash(seed, k + 4) * 4
				Pieces.solid(rocks, "Boulder", Vector3.new(size, size * 0.8, size * 1.1),
					CFrame.new(x + (hash(seed, k + 7) - 0.5) * 5, top + size * 0.3, z + (hash(seed, k + 11) - 0.5) * 5) * CFrame.Angles(0, hash(seed, k) * 3, 0),
					rockColor(section, seed + k))
			end
		end
		for i = 1, 22 do
			local seed = s * 900 + i * 19
			local x = (hash(seed, 1) - 0.5) * 2 * 56
			local z = section.fromZ + hash(seed, 2) * (section.toZ - section.fromZ)
			local top = SeabedBuilder.sandTop(x, z)
			local tuft = Pieces.model(grass, "SeaGrass")
			for k = 1, 3 do
				local h = 1.5 + hash(seed, k + 3) * 2.5
				Pieces.part(tuft, "GrassBlade", Vector3.new(0.5, h, 0.5),
					CFrame.new(x + (k - 2) * 0.7, top + h / 2, z + (hash(seed, k) - 0.5)) * CFrame.Angles(0, 0, math.rad((k - 2) * 12)),
					C.KelpDark:Lerp(C.Kelp, hash(seed, k + 6)))
			end
		end
	end
end

---------------------------------------------------------------- nests
-- Nest spots: spread along each section, alternating sides of the channel.
function SeabedBuilder.nestSpots(s: number)
	local section = Config.Sections[s]
	local spots = {}
	for i = 1, section.nests do
		local z = section.fromZ + (i - 0.5) / section.nests * (section.toZ - section.fromZ)
		local x = (i % 2 == 0 and 1 or -1) * (22 + hash(s, i) * 14)
		table.insert(spots, Vector3.new(x, SeabedBuilder.sandTop(x, z), z))
	end
	return spots
end

local function buildNests(root)
	local folder = Pieces.folder(root, "Nests")
	for s, section in Config.Sections do
		for i, spot in SeabedBuilder.nestSpots(s) do
			local nest = Pieces.model(folder, string.format("Nest_%d_%d", s, i))
			nest:SetAttribute("Section", s)
			nest:SetAttribute("NestIndex", i)
			nest:SetAttribute("EggType", section.eggs[(i - 1) % #section.eggs + 1])
			local cf = CFrame.new(spot)
			-- Sized to the egg it holds (original StudEggs size): the egg sits in a
			-- bowl of sand ringed by rocks and sticks, like a big bird nest.
			local eggInfo = Config.Eggs[nest:GetAttribute("EggType")]
			local eggSize = eggInfo.size or Vector3.new(2.6, 3.5, 2.6)
			local inner = math.max(eggSize.X, eggSize.Z) / 2 + 0.6 -- bowl radius
			local ring = inner + 0.9 -- ring of sticks
			local rimH = math.max(1.4, eggSize.Y * 0.38)
			local moundH = 1.2
			Pieces.solid(nest, "Mound", Vector3.new(ring * 2 + 2, moundH, ring * 2 + 2), cf * CFrame.new(0, moundH / 2, 0), section.sand[1]:Lerp(Color3.new(1, 1, 1), 0.15))
			local sticks = math.max(10, math.floor(ring * 2 * math.pi / 1.7))
			for k = 0, sticks - 1 do
				local a = k / sticks * math.pi * 2
				local stick = (k % 2 == 0) and C.WoodDark or rockColor(section, s * 50 + k)
				local h = rimH * (0.8 + (k % 3) * 0.15)
				Pieces.solid(nest, "NestRim", Vector3.new(1.4, h, 2.2 + ring * 0.25),
					cf * CFrame.Angles(0, -a, 0) * CFrame.new(0, moundH + h / 2 - 0.3, -ring) * CFrame.Angles(math.rad(-14), 0, 0), stick)
			end
			Pieces.kelp(nest, cf * CFrame.new(ring + 1.5, 0, ring * 0.8), 4 + eggSize.Y * 0.4, s + i)
			Pieces.coral(nest, cf * CFrame.new(-ring - 1.4, 0, ring * 0.7), (i % 2 == 0) and C.CoralPink or C.CoralPurple, 1.0 + eggSize.Y * 0.08)
			local glow = Pieces.cylinder(nest, "NestGlow", 0.15, inner * 2, cf * CFrame.new(0, moundH + 0.05, 0), eggInfo.spots, Enum.Material.Neon, {Transparency = 0.45})
			glow.CastShadow = false
			-- EggSpot: bottom of the egg on the mound, prompt at the egg's middle.
			local eggSpot = Pieces.part(nest, "EggSpot", Vector3.new(inner * 2, eggSize.Y, inner * 2), cf * CFrame.new(0, moundH + 0.3, 0), C.White, nil, {Transparency = 1})
			eggSpot.CanCollide = false
			nest:SetAttribute("EggBottom", spot.Y + moundH)
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "TakePrompt"
			prompt.ActionText = "Взять яйцо"
			prompt.ObjectText = Config.Eggs[nest:GetAttribute("EggType")].name
			prompt.HoldDuration = 0.6
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Parent = eggSpot
			nest.PrimaryPart = eggSpot
		end
	end
end

function SeabedBuilder.build(parent: Instance)
	local root = Instance.new("Folder")
	root.Name = "OceanSeabed"
	buildSand(root)
	buildWalls(root)
	buildRocks(root)
	buildNests(root)
	root.Parent = parent
	return root
end

return SeabedBuilder
