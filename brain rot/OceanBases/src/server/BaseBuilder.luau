-- BaseBuilder: geometry of one player base — an open fenced yard with a pool
-- at the back and studded 8x8 cells (like the court floor) in front of it.
-- Expanding adds a row of cells at the front and moves the front fence;
-- nothing is stacked and there is no roof.
--
-- BaseN (Model, PrimaryPart = Root at the centre of the yard's back edge)
--   Root
--   Cells/CellN           (see CellBuilder)
--   Pool                  (deck, rim, water, plants; FishZone = where fish fly)
--   Yard                  (rebuilt on expansion: floor border, fence, entrance,
--                          upgrade board outside the fence, spawn point,
--                          floating owner name, front decor)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))
local Pieces = require(script.Parent:WaitForChild("BasePieces"))
local CellBuilder = require(script.Parent:WaitForChild("CellBuilder"))
local C = Config.Colors

local BaseBuilder = {}

local W = Config.width()
local HX = W / 2 - 0.6 -- fence post line (sides)
local POST_H = 4.2

local function at(origin: CFrame, x: number, y: number, z: number, yaw: number?)
	return origin * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
end

---------------------------------------------------------------- fence
local function post(folder, cf: CFrame, lamp: boolean)
	Pieces.solid(folder, "FencePost", Vector3.new(1.2, POST_H, 1.2), cf * CFrame.new(0, POST_H / 2, 0), C.Wood)
	Pieces.part(folder, "PostCap", Vector3.new(1.5, 0.5, 1.5), cf * CFrame.new(0, POST_H + 0.25, 0), C.WoodDark)
	if lamp then Pieces.lamp(folder, cf * CFrame.new(0, POST_H + 0.5, 0), false) end
end

local function span(folder, a: CFrame, b: CFrame)
	local pa, pb = a.Position, b.Position
	local length = (pb - pa).Magnitude - 1.2
	local along = CFrame.lookAt((pa + pb) / 2, pb)
	for _, y in {1.5, 3.1} do
		Pieces.solid(folder, "Rail", Vector3.new(0.5, 0.7, length), along * CFrame.new(0, y, 0), C.WoodLight)
	end
end

-- Straight fence from (x1, z1) to (x2, z2) in local space, posts ~8 studs apart.
local function fenceLine(folder, origin, x1, z1, x2, z2, lampEnds)
	local length = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
	local spans = math.max(1, math.round(length / 8))
	local previous
	for i = 0, spans do
		local t = i / spans
		local cf = at(origin, x1 + (x2 - x1) * t, Config.FloorTop, z1 + (z2 - z1) * t)
		post(folder, cf, lampEnds and (i == 0 or i == spans))
		if previous then span(folder, previous, cf) end
		previous = cf
	end
end

---------------------------------------------------------------- yard
local function ownerTag(yard, origin: CFrame, depth: number)
	local anchor = Pieces.part(yard, "OwnerTag", Vector3.new(1, 1, 1), at(origin, 0, Config.FloorTop + 13, depth / 2), C.White, nil, {Transparency = 1})
	local gui = Instance.new("BillboardGui")
	gui.Name = "OwnerGui"
	gui.Size = UDim2.fromOffset(420, 70)
	gui.LightInfluence = 0
	gui.MaxDistance = 200
	gui.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Name = "OwnerName"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	text.TextScaled = true
	text.TextColor3 = C.White
	text.TextStrokeColor3 = Color3.fromRGB(20, 40, 60)
	text.TextStrokeTransparency = 0
	text.Text = "Свободная база"
	text.Parent = gui
	return text
end

local function upgradeBoard(yard, origin: CFrame, depth: number)
	local board = Pieces.model(yard, "UpgradeBoard")
	local cf = at(origin, 16, 0, depth + 3.4) -- outside the fence, right of the entrance
	for _, x in {-1.8, 1.8} do
		Pieces.solid(board, "BoardPost", Vector3.new(0.8, 4.2, 0.8), cf * CFrame.new(x, 2.1, 0), C.WoodDark)
	end
	local face = Pieces.part(board, "BoardFace", Vector3.new(5, 2.8, 0.6), cf * CFrame.new(0, 3.3, 0), C.WoodLight)
	Pieces.part(board, "BoardTop", Vector3.new(5.6, 0.6, 1.0), cf * CFrame.new(0, 5.0, 0), C.Red)
	-- Text on both faces: readable from the court and from inside the yard.
	-- The server writes to UpgradeLabel; UpgradeLabelBack mirrors it.
	for _, data in {{"UpgradeLabel", Enum.NormalId.Back}, {"UpgradeLabelBack", Enum.NormalId.Front}} do
		local gui = Instance.new("SurfaceGui")
		gui.Name = data[1]
		gui.Face = data[2]
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.2
		gui.Parent = face
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		text.TextScaled = true
		text.TextColor3 = C.White
		text.TextStrokeTransparency = 0
		text.Text = "Расширить базу"
		text.Parent = gui
	end
	local point = Pieces.part(board, "UpgradePoint", Vector3.new(4, 4, 2), cf * CFrame.new(0, 2.5, 1.6), C.White, nil, {Transparency = 1})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UpgradePrompt"
	prompt.ActionText = "Расширить"
	prompt.ObjectText = "База"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = point
	return board
end

-- Everything whose position depends on the number of rows.
function BaseBuilder.buildYard(base: Model, origin: CFrame, rows: number)
	local old = base:FindFirstChild("Yard")
	if old then old:Destroy() end
	local yard = Pieces.folder(base, "Yard")
	local depth = Config.depth(rows)
	local cellsEnd = Config.Margin + Config.PoolZone + rows * Config.CellSize
	local top = Config.FloorTop

	-- Floor around the cells: back strip, side strips, front walkway, and a darker skirt.
	local floor = Pieces.folder(yard, "Floor")
	Pieces.solid(floor, "BackStrip", Vector3.new(W, 1, Config.Margin), at(origin, 0, top - 0.5, Config.Margin / 2), C.Border)
	for _, side in {-1, 1} do
		Pieces.solid(floor, "SideStrip", Vector3.new(Config.Margin, 1, depth), at(origin, side * (W / 2 - Config.Margin / 2), top - 0.5, depth / 2), C.Border)
	end
	Pieces.solid(floor, "Walkway", Vector3.new(W - Config.Margin * 2, 1, depth - cellsEnd), at(origin, 0, top - 0.5, (cellsEnd + depth) / 2), C.BorderLight)
	Pieces.part(floor, "Skirt", Vector3.new(W + 0.4, 0.6, depth + 0.4), at(origin, 0, 0.3 - 0.01, depth / 2), C.Border)
	Pieces.solid(floor, "EntranceStep", Vector3.new(Config.EntranceWidth, 0.5, 2), at(origin, 0, 0.25, depth + 1), C.BorderLight)

	-- Fence: back, sides and the front with an entrance gap.
	local fence = Pieces.folder(yard, "Fence")
	local fz = depth - 0.6
	fenceLine(fence, origin, -HX, 0.6, HX, 0.6, true)
	fenceLine(fence, origin, -HX, 0.6, -HX, fz, false)
	fenceLine(fence, origin, HX, 0.6, HX, fz, false)
	local gap = Config.EntranceWidth / 2 + 0.9
	fenceLine(fence, origin, -HX, fz, -gap, fz, true)
	fenceLine(fence, origin, gap, fz, HX, fz, true)

	-- Entrance posts: taller, with the only real lights of the base.
	for _, side in {-1, 1} do
		local cf = at(origin, side * gap, top, fz)
		Pieces.solid(yard, "EntrancePost", Vector3.new(1.8, 6, 1.8), cf * CFrame.new(0, 3, 0), C.WoodDark)
		Pieces.part(yard, "EntranceCap", Vector3.new(2.2, 0.6, 2.2), cf * CFrame.new(0, 6.3, 0), C.Wood)
		Pieces.lamp(yard, cf * CFrame.new(0, 6.6, 0), true)
	end

	-- Front decor beside the entrance (moves with the fence).
	local decor = Pieces.folder(yard, "FrontDecor")
	for _, side in {-1, 1} do
		Pieces.coral(decor, at(origin, side * 9.5, 0, depth + 1.8), C.CoralPink, 1.3)
		Pieces.coral(decor, at(origin, side * 12, 0, depth + 1.4, 40), C.CoralPurple, 1.0)
		Pieces.starfish(decor, at(origin, side * 7.6, 0, depth + 2.6, side * 20), 1.1)
	end
	Pieces.anchor(decor, at(origin, 22.5, 0, depth + 2.2), 0.9)
	Pieces.barrel(decor, at(origin, -17.5, 0, depth + 2.0))
	Pieces.crate(decor, at(origin, -15, 0, depth + 2.4, 20), 1.6)

	upgradeBoard(yard, origin, depth)
	local spawn = Pieces.part(yard, "SpawnPoint", Vector3.new(2, 1, 2), at(origin, 0, top + 0.5, depth - 3.5), C.White, nil, {Transparency = 1})
	spawn.CanCollide = false
	ownerTag(yard, origin, depth)
	return yard
end

function BaseBuilder.buildRow(base: Model, origin: CFrame, row: number)
	local cells = base:FindFirstChild("Cells") or Pieces.folder(base, "Cells")
	local built = {}
	for column = 1, Config.Columns do
		local index = (row - 1) * Config.Columns + column
		table.insert(built, CellBuilder.build(cells, origin, row, column, index))
	end
	return built
end

-- Pool at the back of the yard: a deck, a studded rim about a third of a
-- character tall, transparent water, plants and bubbles. Fish fly above it.
local function buildPool(base: Model, origin: CFrame)
	local pool = Pieces.model(base, "Pool")
	local pc = Config.poolCenter()
	local size = Config.PoolSize
	local top = Config.FloorTop
	local rimH = Config.PoolDepth + 0.2
	local r = Config.PoolRim
	local center = at(origin, pc.X, top, pc.Y)
	-- Deck: the floor of the whole pool strip.
	Pieces.solid(pool, "Deck", Vector3.new(W - Config.Margin * 2, 1, Config.PoolZone), center * CFrame.new(0, -0.5, 0), C.BorderLight)
	-- Rim (walkable top), with a light cap.
	local hx, hz = size.X / 2 + r / 2, size.Y / 2 + r / 2
	for _, data in {
		{Vector3.new(size.X + r * 2, rimH, r), Vector3.new(0, 0, -hz)}, {Vector3.new(size.X + r * 2, rimH, r), Vector3.new(0, 0, hz)},
		{Vector3.new(r, rimH, size.Y), Vector3.new(-hx, 0, 0)}, {Vector3.new(r, rimH, size.Y), Vector3.new(hx, 0, 0)},
	} do
		Pieces.solid(pool, "Rim", data[1], center * CFrame.new(data[2].X, rimH / 2, data[2].Z), C.PoolRim)
		Pieces.part(pool, "RimCap", Vector3.new(data[1].X + 0.2, 0.3, data[1].Z + 0.2), center * CFrame.new(data[2].X, rimH + 0.15, data[2].Z), C.PoolRimTop)
	end
	-- Water: sandy bottom, transparent body, glowing surface.
	Pieces.part(pool, "PoolBottom", Vector3.new(size.X, 0.2, size.Y), center * CFrame.new(0, 0.1, 0), C.PoolBottom)
	-- Saturated blue water; the sand bottom shows through it.
	Pieces.part(pool, "Water", Vector3.new(size.X, Config.PoolDepth - 0.2, size.Y), center * CFrame.new(0, 0.2 + (Config.PoolDepth - 0.2) / 2, 0), C.Water,
		Enum.Material.SmoothPlastic, {Transparency = 0.25, Reflectance = 0.04, CastShadow = false})
	-- Thin glowing edge along the rim instead of a pale surface sheet.
	for i, data in {{Vector3.new(size.X, 0.08, 0.3), Vector3.new(0, 0, -size.Y / 2 + 0.15)}, {Vector3.new(size.X, 0.08, 0.3), Vector3.new(0, 0, size.Y / 2 - 0.15)}} do
		Pieces.part(pool, "WaterEdge" .. i, data[1], center * CFrame.new(data[2].X, Config.PoolDepth + 0.02, data[2].Z), C.Foam, Enum.Material.Neon, {Transparency = 0.5, CastShadow = false})
	end
	-- Plants and sea life in the water.
	for i, spot in {{-12, -3.5}, {-9, 3.2}, {11, -3.2}, {13, 2.8}, {2, -4}} do
		Pieces.kelp(pool, center * CFrame.new(spot[1], 0.2, spot[2]), 2.6 + (i % 3) * 0.6, i)
	end
	Pieces.coral(pool, center * CFrame.new(-4, 0.2, 3.5), C.CoralPink, 0.9)
	Pieces.coral(pool, center * CFrame.new(6, 0.2, 3.2) * CFrame.Angles(0, math.rad(40), 0), C.CoralPurple, 0.8)
	Pieces.pebbles(pool, center * CFrame.new(8, 0.2, -3.6), 3, 2)
	Pieces.shell(pool, center * CFrame.new(-6.5, 0.2, -3.8), 1.0)
	Pieces.starfish(pool, center * CFrame.new(-hx, rimH + 0.3, 0), 1.0)
	local source = Pieces.part(pool, "BubbleSource", Vector3.new(size.X - 4, 0.2, size.Y - 4), center * CFrame.new(0, 0.4, 0), C.Water, nil, {Transparency = 1})
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "Bubbles"
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(C.Foam)
	bubbles.LightEmission = 0.6
	bubbles.Size = NumberSequence.new(0.2, 0.35)
	bubbles.Transparency = NumberSequence.new(0.2, 1)
	bubbles.Lifetime = NumberRange.new(1.0, 1.6)
	bubbles.Rate = 6
	bubbles.Speed = NumberRange.new(1, 1.5)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Parent = source
	-- Corner decor on the deck, beside the pool.
	for _, side in {-1, 1} do
		local x = side * (hx + r / 2 + 3.2)
		Pieces.coral(pool, center * CFrame.new(x, 0, -3.5), side < 0 and C.CoralPurple or C.CoralPink, 1.3)
		Pieces.crystals(pool, center * CFrame.new(x, 0, 3.0), 1.1)
	end
	-- Where fish fly: the air above the water (invisible).
	Pieces.part(pool, "FishZone", Vector3.new(size.X - 2, 1, size.Y - 2), center * CFrame.new(0, Config.PoolDepth, 0), C.White, nil, {Transparency = 1})
	return pool
end

function BaseBuilder.build(parent: Instance, id: number, origin: CFrame, rows: number)
	local base = Pieces.model(parent, "Base" .. id)
	base:SetAttribute("BaseId", id)
	base:SetAttribute("OwnerUserId", 0)
	base:SetAttribute("OwnerName", "")
	base:SetAttribute("Rows", rows)
	local root = Pieces.part(base, "Root", Vector3.new(2, 1, 2), origin, C.White, nil, {Transparency = 1})
	base.PrimaryPart = root
	Pieces.folder(base, "Cells")
	for row = 1, rows do BaseBuilder.buildRow(base, origin, row) end
	BaseBuilder.buildYard(base, origin, rows)
	buildPool(base, origin)
	return base
end

function BaseBuilder.origin(id: number): CFrame
	return CFrame.new(Config.Origins[id]) * CFrame.Angles(0, math.rad(Config.Facing), 0)
end

return BaseBuilder
