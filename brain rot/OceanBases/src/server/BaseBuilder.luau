-- BaseBuilder: geometry of one player base — an open fenced yard of studded
-- 8x8 cells (like the court floor). Expanding adds a row of cells at the front
-- and moves the front fence; nothing is stacked and there is no roof.
--
-- BaseN (Model, PrimaryPart = Root at the centre of the yard's back edge)
--   Root
--   Cells/CellN           (see CellBuilder)
--   Yard                  (rebuilt on expansion: floor border, fence, entrance,
--                          upgrade board, spawn point, floating owner name, front decor)
--   Decor                 (side and back decor that never moves)
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
	local cf = at(origin, 15, Config.FloorTop, depth - 3)
	for _, x in {-1.8, 1.8} do
		Pieces.solid(board, "BoardPost", Vector3.new(0.8, 4.2, 0.8), cf * CFrame.new(x, 2.1, 0), C.WoodDark)
	end
	local face = Pieces.part(board, "BoardFace", Vector3.new(5, 2.8, 0.6), cf * CFrame.new(0, 3.3, 0), C.WoodLight)
	Pieces.part(board, "BoardTop", Vector3.new(5.6, 0.6, 1.0), cf * CFrame.new(0, 5.0, 0), C.Red)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "UpgradeLabel"
	gui.Face = Enum.NormalId.Front -- faces the yard (-Z)
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
	local point = Pieces.part(board, "UpgradePoint", Vector3.new(4, 4, 2), cf * CFrame.new(0, 2.5, -1.5), C.White, nil, {Transparency = 1})
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
	local cellsEnd = Config.Margin + rows * Config.CellSize
	local top = Config.FloorTop

	-- Floor around the cells: back strip, side strips, front walkway, and a darker skirt.
	local floor = Pieces.folder(yard, "Floor")
	Pieces.solid(floor, "BackStrip", Vector3.new(W, 1, Config.Margin), at(origin, 0, top - 0.5, Config.Margin / 2), C.Border)
	for _, side in {-1, 1} do
		Pieces.solid(floor, "SideStrip", Vector3.new(Config.Margin, 1, depth), at(origin, side * (W / 2 - Config.Margin / 2), top - 0.5, depth / 2), C.Border)
	end
	Pieces.solid(floor, "Walkway", Vector3.new(W - Config.Margin * 2, 1, depth - cellsEnd), at(origin, 0, top - 0.5, (cellsEnd + depth) / 2), C.BorderLight)
	Pieces.part(floor, "Skirt", Vector3.new(W + 1, 0.6, depth + 1), at(origin, 0, 0.3 - 0.01, depth / 2), C.Border)
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
	Pieces.anchor(decor, at(origin, 17, 0, depth + 2.2), 0.9)
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

-- Static decor along the sides and the back (outside the fence).
local function sideDecor(base: Model, origin: CFrame)
	local decor = Pieces.folder(base, "Decor")
	for _, side in {-1, 1} do
		local x = side * (W / 2 + 2.2)
		Pieces.kelp(decor, at(origin, x, 0, 1.5), 4.5, side + 2)
		Pieces.kelp(decor, at(origin, x + side * 0.8, 0, 4.5), 3.2, side + 5)
		Pieces.coral(decor, at(origin, x, 0, 9, side * 30), side < 0 and C.CoralPurple or C.CoralPink, 1.2)
		Pieces.pebbles(decor, at(origin, x, 0, 14), 3, side + 4)
		Pieces.shell(decor, at(origin, x, 0, 18.5, side * 50), 1.4)
		Pieces.crystals(decor, at(origin, x * 0.5, 0, -1.6), 1.0)
	end
	return decor
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
	sideDecor(base, origin)
	return base
end

function BaseBuilder.origin(id: number): CFrame
	return CFrame.new(Config.Origins[id]) * CFrame.Angles(0, math.rad(Config.Facing), 0)
end

return BaseBuilder
