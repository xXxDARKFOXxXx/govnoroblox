-- BaseBuilder: geometry of one player base (a compact sea nursery that grows
-- upwards). Everything is placed relative to the base origin CFrame, so the
-- whole base can be moved with PivotTo.
--
-- BaseN (Model, PrimaryPart = Root)
--   Root, SpawnPoint
--   Floors/FloorK  (Slab, Columns, Fence, Pens/FishPenX, Lift, Decor)
--   Entrance (arch + owner sign), Chest, UpgradeBoard, Decor
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))
local Pieces = require(script.Parent:WaitForChild("BasePieces"))
local PenBuilder = require(script.Parent:WaitForChild("FishPenBuilder"))
local C = Config.Colors

local BaseBuilder = {}

local W, D = Config.Footprint.X, Config.Footprint.Y
local HX, HZ = W / 2 - 0.4, D / 2 - 0.4 -- fence post line
local POST_TOP = 4.2

local function textGui(parent: Instance, name: string, face: Enum.NormalId, text: string, color: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.2
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.TextScaled = true
	label.TextColor3 = color or C.White
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(60, 30, 10)
	label.Text = text
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = label
	return label
end

local function prompt(parent: Instance, name: string, action: string, object: string, key: Enum.KeyCode?)
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0.25
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	if key then p.KeyboardKeyCode = key end
	p.Parent = parent
	return p
end

---------------------------------------------------------------- fence
local function fencePost(folder, cf: CFrame, decorate: number)
	Pieces.part(folder, "PostFoot", Vector3.new(2.0, 0.7, 2.0), cf * CFrame.new(0, 0.35, 0), C.StoneDark)
	Pieces.solid(folder, "FencePost", Vector3.new(1.35, 3.5, 1.35), cf * CFrame.new(0, 2.45, 0), C.Wood, Enum.Material.WoodPlanks)
	Pieces.part(folder, "PostCap", Vector3.new(1.6, 0.3, 1.6), cf * CFrame.new(0, POST_TOP + 0.15, 0), C.WoodDark)
	Pieces.part(folder, "PostLamp", Vector3.new(0.8, 0.7, 0.8), cf * CFrame.new(0, POST_TOP + 0.65, 0), C.GlowGold, Enum.Material.Neon)
	if decorate % 6 == 1 then
		Pieces.shell(folder, cf * CFrame.new(0, 2.6, 0.7) * CFrame.Angles(math.rad(90), 0, 0), 0.9)
	end
end

local function fenceSpan(folder, a: CFrame, b: CFrame, index: number, rich: boolean)
	local pa, pb = a.Position, b.Position
	local mid = (pa + pb) / 2
	local length = (pb - pa).Magnitude - 1.3
	local along = CFrame.lookAt(mid, pb)
	Pieces.solid(folder, "Rail", Vector3.new(0.4, 0.5, length), along * CFrame.new(0, 1.7, 0), C.Wood, Enum.Material.WoodPlanks)
	Pieces.rope(folder, pa + Vector3.new(0, POST_TOP - 0.2, 0), pb + Vector3.new(0, POST_TOP - 0.2, 0), 0.9, 0.3)
	if rich and index % 4 == 2 then
		Pieces.net(folder, along * CFrame.new(-0.05, 3.45, length / 2 - 0.3) * CFrame.Angles(0, math.rad(90), 0), length - 0.6, 1.55)
	elseif index % 5 == 3 then
		Pieces.buoy(folder, along * CFrame.new(0.2, 2.6, 0))
	elseif index % 5 == 0 then
		Pieces.starfish(folder, along * CFrame.new(0.25, 1.7, 0) * CFrame.Angles(0, 0, math.rad(-90)), 0.8)
	end
end

-- Fence around one floor. Ground floor leaves a gap at the front for the entrance.
local function buildFence(folder, origin: CFrame, y: number, ground: boolean)
	local corners = {}
	local function line(fromX, fromZ, toX, toZ, spans)
		local points = {}
		for i = 0, spans do
			local t = i / spans
			table.insert(points, origin * CFrame.new(fromX + (toX - fromX) * t, y, fromZ + (toZ - fromZ) * t))
		end
		return points
	end
	local sides = {
		line(-HX, -HZ, HX, -HZ, 6), -- back
		line(-HX, -HZ, -HX, HZ, 6), -- left
		line(HX, -HZ, HX, HZ, 6), -- right
	}
	local gap = Config.EntranceWidth / 2 + 1.2
	if ground then
		table.insert(sides, line(-HX, HZ, -gap, HZ, 2))
		table.insert(sides, line(gap, HZ, HX, HZ, 2))
	else
		table.insert(sides, line(-HX, HZ, HX, HZ, 6))
	end
	local postIndex, spanIndex = 0, 0
	for _, points in sides do
		for i, cf in points do
			local key = string.format("%.1f/%.1f", cf.Position.X, cf.Position.Z)
			if not corners[key] then
				corners[key] = true
				postIndex += 1
				fencePost(folder, cf, postIndex)
			end
			if i > 1 then
				spanIndex += 1
				fenceSpan(folder, points[i - 1], cf, spanIndex, ground)
			end
		end
		-- One invisible guard per side, so nobody falls off upper floors through the rope gap.
		local a, b = points[1].Position, points[#points].Position
		Pieces.solid(folder, "FenceGuard", Vector3.new(0.3, 4.4, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, 2.2, 0), C.Wood, nil, {Transparency = 1})
	end
end

---------------------------------------------------------------- props
local function liftPad(floorModel, origin: CFrame, y: number, floor: number)
	local lift = Pieces.model(floorModel, "Lift")
	local spot = origin * CFrame.new(Config.LiftSpot.X, y, Config.LiftSpot.Y)
	Pieces.cylinder(lift, "LiftPad", 0.4, 5.6, spot * CFrame.new(0, 0.2, 0), C.StoneLight)
	Pieces.cylinder(lift, "LiftRing", 0.12, 5.9, spot * CFrame.new(0, 0.42, 0), C.GlowBlue, Enum.Material.Neon)
	Pieces.cylinder(lift, "LiftCore", 0.1, 3.2, spot * CFrame.new(0, 0.45, 0), C.Water, Enum.Material.Neon, {Transparency = 0.3})
	local tubeHeight = Config.FloorHeight - 1.6
	local tube = Pieces.cylinder(lift, "LiftTube", tubeHeight, 5.4, spot * CFrame.new(0, 0.4 + tubeHeight / 2, 0), C.Foam, Enum.Material.Glass, {Transparency = 0.82, CastShadow = false})
	Pieces.cylinder(lift, "LiftTopRing", 0.3, 5.7, spot * CFrame.new(0, 0.4 + tubeHeight, 0), C.WoodDark)
	-- Arrow sign post next to the tube.
	local sign = spot * CFrame.new(3.4, 0, 1.5)
	Pieces.part(lift, "LiftSignPost", Vector3.new(0.35, 2.6, 0.35), sign * CFrame.new(0, 1.3, 0), C.WoodDark)
	local board = Pieces.part(lift, "LiftSign", Vector3.new(1.8, 1.1, 0.2), sign * CFrame.new(0, 2.7, 0), C.WoodLight, Enum.Material.WoodPlanks)
	textGui(board, "LiftLabel", Enum.NormalId.Back, "Лифт " .. floor, C.White)
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "LiftBubbles"
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(C.Foam)
	bubbles.LightEmission = 0.5
	bubbles.Size = NumberSequence.new(0.25, 0.4)
	bubbles.Transparency = NumberSequence.new(0.3, 1)
	bubbles.Lifetime = NumberRange.new(2, 3)
	bubbles.Rate = 4
	bubbles.Speed = NumberRange.new(2, 3)
	bubbles.EmissionDirection = Enum.NormalId.Right -- cylinder X axis points up
	bubbles.Parent = tube
	local point = Pieces.part(lift, "LiftPoint", Vector3.new(4, 4, 4), spot * CFrame.new(0, 2.4, 0), C.White, nil, {Transparency = 1})
	prompt(point, "LiftUp", "Наверх", "Лифт", Enum.KeyCode.E)
	prompt(point, "LiftDown", "Вниз", "Лифт", Enum.KeyCode.F)
	local arrival = Pieces.part(lift, "LiftArrival", Vector3.new(1, 1, 1), spot * CFrame.new(0, 3.2, 3.6), C.White, nil, {Transparency = 1})
	arrival:SetAttribute("Floor", floor)
	return lift
end

local function buildChest(base, origin: CFrame)
	local chest = Pieces.model(base, "Chest")
	local cf = origin * CFrame.new(Config.ChestSpot.X, Config.GroundTop, Config.ChestSpot.Y) * CFrame.Angles(0, math.rad(-20), 0)
	Pieces.part(chest, "ChestPlinth", Vector3.new(4.4, 0.4, 3.4), cf * CFrame.new(0, 0.2, 0), C.StoneDark)
	Pieces.solid(chest, "ChestBox", Vector3.new(3.6, 1.7, 2.5), cf * CFrame.new(0, 1.25, 0), C.WoodLight, Enum.Material.WoodPlanks)
	for _, x in {-1.25, 1.25} do
		Pieces.part(chest, "ChestBand", Vector3.new(0.35, 1.78, 2.6), cf * CFrame.new(x, 1.25, 0), C.Gold, Enum.Material.Metal)
	end
	Pieces.part(chest, "ChestRim", Vector3.new(3.75, 0.25, 2.65), cf * CFrame.new(0, 2.12, 0), C.Gold, Enum.Material.Metal)
	Pieces.part(chest, "ChestLock", Vector3.new(0.7, 0.8, 0.2), cf * CFrame.new(0, 1.5, 1.3), C.Gold, Enum.Material.Metal)
	-- Open lid tilted back on its hinge.
	local hinge = cf * CFrame.new(0, 2.2, -1.25) * CFrame.Angles(math.rad(-62), 0, 0)
	Pieces.part(chest, "ChestLid", Vector3.new(3.6, 0.5, 2.5), hinge * CFrame.new(0, 0.25, 1.25), C.Wood, Enum.Material.WoodPlanks)
	Pieces.part(chest, "ChestLidBand", Vector3.new(3.7, 0.56, 0.3), hinge * CFrame.new(0, 0.25, 2.35), C.Gold, Enum.Material.Metal)
	local coins = Pieces.part(chest, "ChestCoins", Vector3.new(3.2, 0.3, 2.1), cf * CFrame.new(0, 2.15, 0), C.GlowGold, Enum.Material.Neon)
	for i, spot in {{-0.9, 0.2}, {0.3, -0.4}, {1.0, 0.5}, {-0.2, 0.6}} do
		Pieces.cylinder(chest, "Coin", 0.16, 0.8, cf * CFrame.new(spot[1], 2.38 + (i % 2) * 0.1, spot[2]) * CFrame.Angles(math.rad(10 * i), 0, 0), C.Gold, Enum.Material.Metal)
	end
	local light = Instance.new("PointLight")
	light.Color = C.GlowGold
	light.Range = 10
	light.Brightness = 1.2
	light.Parent = coins
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "ChestSparkle"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(C.GlowGold)
	sparkle.LightEmission = 0.8
	sparkle.Size = NumberSequence.new(0.35, 0)
	sparkle.Lifetime = NumberRange.new(0.8, 1.2)
	sparkle.Rate = 3
	sparkle.Speed = NumberRange.new(0.5, 1)
	sparkle.Parent = coins
	local point = Pieces.part(chest, "ChestPoint", Vector3.new(4, 3, 3), cf * CFrame.new(0, 1.6, 0), C.White, nil, {Transparency = 1})
	prompt(point, "CollectPrompt", "Собрать монеты", "Сундук")
	local gui = Instance.new("BillboardGui")
	gui.Name = "ChestInfo"
	gui.Size = UDim2.fromOffset(160, 44)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 80
	gui.Parent = point
	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.TextScaled = true
	label.TextColor3 = C.GlowGold
	label.TextStrokeTransparency = 0
	label.Text = "0"
	label.Parent = gui
	return chest
end

local function buildUpgradeBoard(base, origin: CFrame)
	local board = Pieces.model(base, "UpgradeBoard")
	local cf = origin * CFrame.new(Config.UpgradeSpot.X, Config.GroundTop, Config.UpgradeSpot.Y)
	for _, x in {-1.9, 1.9} do
		Pieces.part(board, "BoardFoot", Vector3.new(0.9, 0.4, 0.9), cf * CFrame.new(x, 0.2, 0), C.StoneDark)
		Pieces.solid(board, "BoardPost", Vector3.new(0.5, 4.4, 0.5), cf * CFrame.new(x, 2.2, 0), C.WoodDark)
	end
	Pieces.part(board, "BoardFrame", Vector3.new(4.6, 2.9, 0.3), cf * CFrame.new(0, 3.0, -0.05), C.WoodDark)
	local face = Pieces.part(board, "BoardFace", Vector3.new(4.2, 2.5, 0.3), cf * CFrame.new(0, 3.0, 0.05), C.WoodLight, Enum.Material.WoodPlanks)
	textGui(face, "UpgradeLabel", Enum.NormalId.Back, "Улучшение базы", C.White)
	Pieces.part(board, "BoardRoof", Vector3.new(5.0, 0.3, 0.9), cf * CFrame.new(0, 4.55, 0), C.Red)
	Pieces.part(board, "BoardGlow", Vector3.new(4.4, 0.16, 0.16), cf * CFrame.new(0, 1.66, 0.25), C.GlowBlue, Enum.Material.Neon)
	local point = Pieces.part(board, "UpgradePoint", Vector3.new(4, 4, 2), cf * CFrame.new(0, 2.4, 1.2), C.White, nil, {Transparency = 1})
	prompt(point, "UpgradePrompt", "Улучшить", "Новый этаж", Enum.KeyCode.E)
	return board
end

local function buildEntrance(base, origin: CFrame)
	local entrance = Pieces.model(base, "Entrance")
	local gap = Config.EntranceWidth / 2 + 1.2
	for _, side in {-1, 1} do
		local p = origin * CFrame.new(side * gap, Config.GroundTop, HZ)
		Pieces.part(entrance, "ArchFoot", Vector3.new(2.8, 1.0, 2.8), p * CFrame.new(0, 0.5, 0), C.StoneDark)
		Pieces.part(entrance, "ArchFootTrim", Vector3.new(2.5, 0.25, 2.5), p * CFrame.new(0, 1.1, 0), C.StoneLight)
		Pieces.solid(entrance, "ArchPost", Vector3.new(1.9, 7.4, 1.9), p * CFrame.new(0, 4.7, 0), C.Wood, Enum.Material.WoodPlanks)
		for _, y in {2.6, 6.4} do
			Pieces.cylinder(entrance, "ArchRope", 0.45, 2.3, p * CFrame.new(0, y, 0), C.Rope)
		end
		Pieces.lantern(entrance, p * CFrame.new(side * 1.25, 5.0, 0.9), true)
	end
	-- Arched beam made of three angled blocks.
	local top = origin * CFrame.new(0, Config.GroundTop + 8.6, HZ)
	Pieces.part(entrance, "ArchBeam", Vector3.new(7.2, 1.3, 2.0), top * CFrame.new(0, 0.55, 0), C.Wood, Enum.Material.WoodPlanks)
	for _, side in {-1, 1} do
		Pieces.part(entrance, "ArchBeamSide", Vector3.new(4.2, 1.3, 2.0), top * CFrame.new(side * 4.6, 0.0, 0) * CFrame.Angles(0, 0, math.rad(side * -14)), C.Wood, Enum.Material.WoodPlanks)
	end
	Pieces.part(entrance, "ArchBeamCap", Vector3.new(7.6, 0.35, 2.3), top * CFrame.new(0, 1.3, 0), C.WoodDark)
	Pieces.part(entrance, "ArchKeystone", Vector3.new(1.6, 1.8, 2.3), top * CFrame.new(0, 0.6, 0), C.Stone)
	-- Owner sign under the beam, with a glowing fish emblem and a wave trim.
	local signCf = top * CFrame.new(0, -1.5, 1.05)
	Pieces.part(entrance, "OwnerSignFrame", Vector3.new(8.6, 2.3, 0.3), signCf * CFrame.new(0, 0, -0.1), C.WoodDark)
	local sign = Pieces.part(entrance, "OwnerSign", Vector3.new(8.2, 1.9, 0.3), signCf, C.WoodLight, Enum.Material.WoodPlanks)
	textGui(sign, "OwnerLabel", Enum.NormalId.Back, "Свободная база", C.White)
	Pieces.fishEmblem(entrance, top * CFrame.new(0, 0.6, 1.2), 1.0, true)
	Pieces.waveTrim(entrance, signCf * CFrame.new(0, -1.35, 0.1), 8.0)
	Pieces.lifeRing(entrance, origin * CFrame.new(-gap - 1.15, Config.GroundTop + 3.2, HZ + 0.4), 0.95)
	return entrance
end

---------------------------------------------------------------- floors
-- One floor: slab, columns (upper floors), fence, five pens, lift, decor.
function BaseBuilder.buildFloor(parent: Instance, origin: CFrame, floor: number)
	local floorModel = Pieces.model(parent, "Floor" .. floor)
	floorModel:SetAttribute("Floor", floor)
	local y = Config.floorTop(floor)
	-- Pivot of the floor: base origin raised to this floor's top (used by PivotTo on upgrades).
	floorModel.PrimaryPart = Pieces.part(floorModel, "FloorRoot", Vector3.new(1, 1, 1), origin * CFrame.new(0, y, 0), C.White, nil, {Transparency = 1})
	local slab = Pieces.folder(floorModel, "Slab")
	if floor == 1 then
		Pieces.solid(slab, "GroundSlab", Vector3.new(W, 1.4, D), origin * CFrame.new(0, y - 0.7, 0), C.Stone)
		Pieces.part(slab, "GroundSkirt", Vector3.new(W + 0.8, 0.6, D + 0.8), origin * CFrame.new(0, y - 1.1, 0), C.StoneDark)
		for i = 0, 9 do -- tiled path from the entrance to the back pens
			local z = D / 2 - 2 - i * 3.6
			Pieces.part(slab, "PathTile", Vector3.new(13.6, 0.1, 3.4), origin * CFrame.new(0, y + 0.05, z), i % 2 == 0 and C.Path or C.StoneLight)
		end
	else
		Pieces.solid(slab, "FloorSlab", Vector3.new(W, 1.0, D), origin * CFrame.new(0, y - 0.5, 0), C.Wood, Enum.Material.WoodPlanks)
		Pieces.part(slab, "FloorTrimFront", Vector3.new(W + 0.4, 0.7, 0.6), origin * CFrame.new(0, y - 0.65, D / 2), C.StoneDark)
		Pieces.part(slab, "FloorTrimBack", Vector3.new(W + 0.4, 0.7, 0.6), origin * CFrame.new(0, y - 0.65, -D / 2), C.StoneDark)
		Pieces.part(slab, "FloorTrimLeft", Vector3.new(0.6, 0.7, D), origin * CFrame.new(-W / 2, y - 0.65, 0), C.StoneDark)
		Pieces.part(slab, "FloorTrimRight", Vector3.new(0.6, 0.7, D), origin * CFrame.new(W / 2, y - 0.65, 0), C.StoneDark)
		for _, x in {-11, 0, 11} do
			Pieces.part(slab, "Beam", Vector3.new(0.9, 0.8, D - 1), origin * CFrame.new(x, y - 1.4, 0), C.WoodDark)
		end
		Pieces.part(slab, "WalkwayRug", Vector3.new(12, 0.08, 30), origin * CFrame.new(0, y + 0.04, 3), C.WoodLight, Enum.Material.WoodPlanks)
		-- Columns from the floor below up to this slab.
		local columns = Pieces.folder(floorModel, "Columns")
		local below = Config.floorTop(floor - 1)
		local height = y - 1 - below
		for _, spot in {{-HX, -HZ}, {HX, -HZ}, {-HX, HZ}, {HX, HZ}, {-HX, 0}, {HX, 0}, {0, -HZ}} do
			local c = origin * CFrame.new(spot[1], below, spot[2])
			Pieces.part(columns, "ColumnFoot", Vector3.new(2.4, 0.9, 2.4), c * CFrame.new(0, 0.45, 0), C.StoneDark)
			Pieces.solid(columns, "Column", Vector3.new(1.8, height, 1.8), c * CFrame.new(0, height / 2, 0), C.Wood, Enum.Material.WoodPlanks)
			Pieces.part(columns, "ColumnBracket", Vector3.new(2.3, 0.6, 2.3), c * CFrame.new(0, height - 0.3, 0), C.WoodDark)
			Pieces.cylinder(columns, "ColumnRope", 0.4, 2.15, c * CFrame.new(0, height * 0.45, 0), C.Rope)
		end
	end

	buildFence(Pieces.folder(floorModel, "Fence"), origin, y, floor == 1)

	local pens = Pieces.folder(floorModel, "Pens")
	for i, spot in Config.PenSpots do
		local index = (floor - 1) * Config.PensPerFloor + i
		PenBuilder.build(pens, origin * CFrame.new(spot.X, y, spot.Y), index, floor)
	end

	liftPad(floorModel, origin, y, floor)

	-- Decor groups: front corners, between the pens, and around the lift.
	local decor = Pieces.folder(floorModel, "Decor")
	local function at(x, z, yaw) return origin * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw or 0), 0) end
	Pieces.barrel(decor, at(-9.6, 17.6))
	Pieces.crate(decor, at(-9.2, 14.6, 12), 1.8)
	Pieces.crate(decor, at(-9.3, 14.6, 30) * CFrame.new(0, 1.8, 0), 1.2)
	Pieces.crystals(decor, at(19, 11.6), 1.1)
	for _, side in {-1, 1} do
		local pot = at(side * 7.4, 10.2)
		Pieces.cylinder(decor, "Planter", 0.9, 2.2, pot * CFrame.new(0, 0.45, 0), C.StoneDark)
		Pieces.cylinder(decor, "PlanterSand", 0.1, 1.9, pot * CFrame.new(0, 0.92, 0), C.Sand)
		Pieces.coral(decor, pot * CFrame.new(0, 0.9, 0), side < 0 and C.CoralPink or C.CoralPurple, 1.2)
		Pieces.kelp(decor, at(side * 7.4, -4.5), 3.2, floor + side)
		Pieces.starfish(decor, at(side * 7.0, -2.2, side * 20), 0.9)
	end
	if floor > 1 then
		Pieces.flag(decor, at(-HX, -HZ) * CFrame.new(0, POST_TOP + 1, 0), 4.5)
		Pieces.flag(decor, at(HX, -HZ) * CFrame.new(0, POST_TOP + 1, 0), 4.5)
	end
	return floorModel
end

---------------------------------------------------------------- base
-- Builds the base with floors 1..floors in `parent`. Extra floors (for
-- upgrades) are built separately with buildFloor and kept in storage.
function BaseBuilder.build(parent: Instance, id: number, origin: CFrame, floors: number)
	local base = Pieces.model(parent, "Base" .. id)
	base:SetAttribute("BaseId", id)
	base:SetAttribute("OwnerUserId", 0)
	base:SetAttribute("OwnerName", "")
	base:SetAttribute("Floors", floors)
	base:SetAttribute("Stored", 0)
	local root = Pieces.part(base, "Root", Vector3.new(2, 1, 2), origin, C.White, nil, {Transparency = 1})
	base.PrimaryPart = root
	local s = Config.SpawnSpot
	Pieces.part(base, "SpawnPoint", Vector3.new(2, 1, 2), origin * CFrame.new(s.X, s.Y, s.Z), C.White, nil, {Transparency = 1})

	local floorFolder = Pieces.folder(base, "Floors")
	for floor = 1, floors do
		BaseBuilder.buildFloor(floorFolder, origin, floor)
	end
	-- The top floor has nothing above it yet: no lift tube there (upgrades re-show it).
	local topLift = floorFolder["Floor" .. floors].Lift
	topLift.LiftTube.Transparency = 1
	topLift.LiftTopRing.Transparency = 1
	topLift.LiftTube.LiftBubbles.Enabled = false
	buildEntrance(base, origin)
	buildChest(base, origin)
	buildUpgradeBoard(base, origin)

	-- Outside decor next to the entrance and at the back corners.
	local decor = Pieces.folder(base, "Decor")
	local function at(x, z, yaw) return origin * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw or 0), 0) end
	for _, side in {-1, 1} do
		Pieces.coral(decor, at(side * 10.5, D / 2 + 1.8), C.CoralPink, 1.7)
		Pieces.coral(decor, at(side * 12.8, D / 2 + 1.4, 40), C.CoralPurple, 1.35)
		Pieces.starfish(decor, at(side * 9.0, D / 2 + 2.4, 15), 1.1)
		Pieces.pebbles(decor, at(side * 14.5, D / 2 + 1.6), 4, side + 3)
	end
	Pieces.anchor(decor, at(16.5, D / 2 + 2.0, -15), 0.9)
	Pieces.shell(decor, at(-15.5, D / 2 + 2.0, 25), 1.3)
	return base
end

function BaseBuilder.origin(id: number): CFrame
	return CFrame.new(Config.Centers[id]) * CFrame.Angles(0, math.rad(Config.Facing), 0)
end

return BaseBuilder
