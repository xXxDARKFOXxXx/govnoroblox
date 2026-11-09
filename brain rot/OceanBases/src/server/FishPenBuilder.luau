-- FishPenBuilder: one fish pen = a small raised pool with a stone base, wooden
-- rims, corner posts with glowing caps, turquoise water, a pedestal for eggs,
-- kelp, coral, pebbles, a shell and a front sign with a fish emblem.
--
-- FishPen (Model)
--   Base, Walls, Water, Decorations, Effects (Folders of parts)
--   EggPlacement  (Part, top of the pedestal: eggs sit here)
--   FishSpawn     (Attachment in EggPlacement: fish appear here)
--   FishMovementArea (invisible Part: the box fish swim in)
--   InteractionPoint (invisible Part with the ProximityPrompt)
--   IncomeDisplay (Attachment on InteractionPoint with a BillboardGui)
--   Content       (Folder: runtime egg / fish models)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))
local Pieces = require(script.Parent:WaitForChild("BasePieces"))
local C = Config.Colors

local FishPenBuilder = {}

local RIM_H, BOARD_H = 1.3, 0.9
local WATER_TOP = 1.95

function FishPenBuilder.build(parent: Instance, cf: CFrame, index: number, floor: number)
	local w, d = Config.PenSize.X, Config.PenSize.Y
	local pen = Pieces.model(parent, "FishPen" .. index)
	pen:SetAttribute("PenIndex", index)
	pen:SetAttribute("Floor", floor)
	pen:SetAttribute("State", "Empty")
	local base = Pieces.folder(pen, "Base")
	local walls = Pieces.folder(pen, "Walls")
	local water = Pieces.folder(pen, "Water")
	local deco = Pieces.folder(pen, "Decorations")
	local effects = Pieces.folder(pen, "Effects")
	Pieces.folder(pen, "Content")

	-- Stone base: chunky rim with a lighter bevel on top and a darker foot.
	local function rimSide(name, size, offset)
		Pieces.solid(base, name, size, cf * CFrame.new(offset.X, RIM_H / 2, offset.Z), C.Stone, Enum.Material.SmoothPlastic)
		Pieces.part(base, name .. "Bevel", Vector3.new(size.X - 0.3, 0.18, size.Z - 0.3), cf * CFrame.new(offset.X, RIM_H + 0.05, offset.Z), C.StoneLight)
	end
	rimSide("RimBack", Vector3.new(w, RIM_H, 1.2), Vector3.new(0, 0, -d / 2 + 0.6))
	rimSide("RimFront", Vector3.new(w, RIM_H, 1.2), Vector3.new(0, 0, d / 2 - 0.6))
	rimSide("RimLeft", Vector3.new(1.2, RIM_H, d - 2.4), Vector3.new(-w / 2 + 0.6, 0, 0))
	rimSide("RimRight", Vector3.new(1.2, RIM_H, d - 2.4), Vector3.new(w / 2 - 0.6, 0, 0))

	-- Low wooden boards on the rim, with a darker cap.
	local function board(size, offset)
		Pieces.solid(walls, "Board", size, cf * CFrame.new(offset.X, RIM_H + BOARD_H / 2 + 0.14, offset.Z), C.Wood, Enum.Material.WoodPlanks)
		Pieces.part(walls, "BoardCap", Vector3.new(size.X + 0.12, 0.16, size.Z + 0.12), cf * CFrame.new(offset.X, RIM_H + BOARD_H + 0.2, offset.Z), C.WoodDark)
	end
	board(Vector3.new(w - 2.2, BOARD_H, 0.5), Vector3.new(0, 0, -d / 2 + 0.45))
	board(Vector3.new(w - 2.2, BOARD_H, 0.5), Vector3.new(0, 0, d / 2 - 0.45))
	board(Vector3.new(0.5, BOARD_H, d - 2.2), Vector3.new(-w / 2 + 0.45, 0, 0))
	board(Vector3.new(0.5, BOARD_H, d - 2.2), Vector3.new(w / 2 - 0.45, 0, 0))

	-- Corner posts: stone foot, wooden post, collar and a glowing blue cube.
	for _, sx in {-1, 1} do
		for _, sz in {-1, 1} do
			local p = cf * CFrame.new(sx * (w / 2 - 0.6), 0, sz * (d / 2 - 0.6))
			Pieces.part(walls, "PostFoot", Vector3.new(1.7, 0.5, 1.7), p * CFrame.new(0, 0.25, 0), C.StoneDark)
			Pieces.solid(walls, "Post", Vector3.new(1.25, 3.1, 1.25), p * CFrame.new(0, 2.0, 0), C.Wood, Enum.Material.WoodPlanks)
			Pieces.part(walls, "PostCollar", Vector3.new(1.45, 0.25, 1.45), p * CFrame.new(0, 3.6, 0), C.WoodDark)
			Pieces.part(walls, "PostGlow", Vector3.new(0.85, 0.85, 0.85), p * CFrame.new(0, 4.15, 0), C.GlowBlue, Enum.Material.Neon)
		end
	end

	-- Water: sand bottom, transparent body, glossy surface and a soft glow edge.
	local iw, id = w - 2.4, d - 2.4
	Pieces.part(water, "Sand", Vector3.new(iw, 0.3, id), cf * CFrame.new(0, 0.15, 0), C.Sand, Enum.Material.Sand)
	Pieces.part(water, "WaterBody", Vector3.new(iw, WATER_TOP - 0.3, id), cf * CFrame.new(0, 0.3 + (WATER_TOP - 0.3) / 2, 0), C.Water,
		Enum.Material.SmoothPlastic, {Transparency = 0.38, Reflectance = 0.08, CastShadow = false})
	Pieces.part(water, "WaterSurface", Vector3.new(iw, 0.06, id), cf * CFrame.new(0, WATER_TOP + 0.02, 0), C.Foam,
		Enum.Material.Glass, {Transparency = 0.55, CastShadow = false})
	for i, offset in {{0, -id / 2 + 0.12, iw, 0.24}, {0, id / 2 - 0.12, iw, 0.24}} do
		Pieces.part(water, "EdgeGlow" .. i, Vector3.new(offset[3], 0.08, offset[4]), cf * CFrame.new(offset[1], WATER_TOP + 0.05, offset[2]),
			C.GlowBlue, Enum.Material.Neon, {Transparency = 0.45, CastShadow = false})
	end

	-- Pedestal in the middle of the pool (eggs stand on it).
	local pedestal = cf * CFrame.new(0, 0, 0.6)
	Pieces.cylinder(deco, "PedestalBase", 0.6, 3.0, pedestal * CFrame.new(0, 0.6, 0), C.StoneDark)
	Pieces.cylinder(deco, "PedestalColumn", 1.5, 2.3, pedestal * CFrame.new(0, 1.45, 0), C.Stone)
	Pieces.cylinder(deco, "PedestalRing", 0.16, 2.6, pedestal * CFrame.new(0, 2.25, 0), C.GlowGold, Enum.Material.Neon)
	local placement = Pieces.cylinder(pen, "EggPlacement", 0.2, 2.4, pedestal * CFrame.new(0, 2.38, 0), C.StoneLight)
	local spawn = Instance.new("Attachment")
	spawn.Name = "FishSpawn"
	spawn.Parent = placement
	-- Cylinders are rotated; keep the attachment upright above the pedestal.
	spawn.CFrame = placement.CFrame:ToObjectSpace(pedestal * CFrame.new(0, 2.5, 0))

	-- Swim volume (invisible): fish circle around the pedestal at the surface.
	Pieces.part(pen, "FishMovementArea", Vector3.new(iw - 1.6, 0.6, id - 1.4), cf * CFrame.new(0, WATER_TOP - 0.25, 0), C.Water, nil, {Transparency = 1})

	-- Plants and sea life inside the pool, grouped in the back corners.
	Pieces.kelp(deco, cf * CFrame.new(-iw / 2 + 0.9, 0.3, -id / 2 + 0.9), 3.4, index)
	Pieces.kelp(deco, cf * CFrame.new(iw / 2 - 0.9, 0.3, -id / 2 + 1.0), 3.0, index + 5)
	Pieces.coral(deco, cf * CFrame.new(iw / 2 - 1.1, 0.3, id / 2 - 1.0), index % 2 == 0 and C.CoralPink or C.CoralPurple, 0.95)
	Pieces.pebbles(deco, cf * CFrame.new(-iw / 2 + 1.2, 0.3, id / 2 - 1.0), 3, index)
	Pieces.shell(deco, cf * CFrame.new(iw / 2 - 2.4, 0.3, -id / 2 + 0.9) * CFrame.Angles(0, math.rad(30), 0), 0.8)

	-- Front sign with a gold fish emblem and a wave trim.
	local sign = cf * CFrame.new(0, 1.0, d / 2 + 0.15)
	Pieces.part(deco, "SignBoard", Vector3.new(3.4, 1.5, 0.3), sign, C.WoodLight, Enum.Material.WoodPlanks)
	Pieces.part(deco, "SignFrame", Vector3.new(3.7, 1.8, 0.22), sign * CFrame.new(0, 0, -0.08), C.WoodDark)
	Pieces.fishEmblem(deco, sign * CFrame.new(-0.1, 0.05, 0.2), 0.75, false)

	-- Bubbles rising from the sand (low rate; one emitter per pen).
	local bubbleSource = Pieces.part(effects, "BubbleSource", Vector3.new(iw - 2, 0.1, id - 2), cf * CFrame.new(0, 0.4, 0), C.Water, nil, {Transparency = 1})
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "Bubbles"
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(C.Foam)
	bubbles.LightEmission = 0.6
	bubbles.Size = NumberSequence.new(0.18, 0.3)
	bubbles.Transparency = NumberSequence.new(0.2, 1)
	bubbles.Lifetime = NumberRange.new(1.2, 1.8)
	bubbles.Rate = 2.5
	bubbles.Speed = NumberRange.new(0.8, 1.2)
	bubbles.SpreadAngle = Vector2.new(8, 8)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Parent = bubbleSource

	-- Interaction point in front of the pen with the prompt and the income display.
	local point = Pieces.part(pen, "InteractionPoint", Vector3.new(2, 2, 1), cf * CFrame.new(0, 2.6, d / 2 + 1.2), C.White, nil, {Transparency = 1})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PenPrompt"
	prompt.ActionText = "Поставить яйцо"
	prompt.ObjectText = "Загон " .. index
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = point
	local display = Instance.new("Attachment")
	display.Name = "IncomeDisplay"
	display.Parent = point
	display.CFrame = point.CFrame:ToObjectSpace(cf * CFrame.new(0, 6.6, 0))
	local gui = Instance.new("BillboardGui")
	gui.Name = "PenInfo"
	gui.Size = UDim2.fromOffset(170, 52)
	gui.LightInfluence = 0
	gui.MaxDistance = 32
	gui.AlwaysOnTop = false
	gui.Adornee = display
	gui.Parent = point
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.55, 0)
	title.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	title.TextScaled = true
	title.TextColor3 = C.White
	title.TextStrokeTransparency = 0.2
	title.Text = ""
	title.Parent = gui
	local line = Instance.new("TextLabel")
	line.Name = "Line"
	line.BackgroundTransparency = 1
	line.Position = UDim2.fromScale(0, 0.55)
	line.Size = UDim2.new(1, 0, 0.45, 0)
	line.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	line.TextScaled = true
	line.TextColor3 = C.GlowGold
	line.TextStrokeTransparency = 0.2
	line.Text = ""
	line.Parent = gui

	pen.PrimaryPart = placement
	return pen
end

return FishPenBuilder
