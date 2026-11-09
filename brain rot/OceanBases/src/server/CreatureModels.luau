-- CreatureModels: eggs, fish and predators.
--
-- If the GLB models from StudEggs / Studfish / StudPredators are imported into
-- ReplicatedStorage.OceanModels (folders Eggs, Fish, Predators — see the
-- README and the OceanModelsOrganizer helper), clones of those are used and
-- their runtime LocalScripts animate them. Otherwise built-in models made of
-- parts are used, so the game always works.
--
-- Attributes on every creature model: ForwardYaw (degrees to turn the model so
-- it faces its direction of travel; imported GLB rigs look along +X).
-- Tags: OceanFish / OceanEgg / OceanPredator.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))
local Pieces = require(script.Parent:WaitForChild("BasePieces"))
local C = Config.Colors

local CreatureModels = {}

local function sparkles(parent: BasePart, color: Color3, rate: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparkles"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.9
	e.Size = NumberSequence.new(0.3, 0)
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Rate = rate
	e.Speed = NumberRange.new(0.4, 1.0)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = parent
	return e
end

---------------------------------------------------------------- imported models
-- Clone of ReplicatedStorage.OceanModels.<category>.<name>, made static and
-- non-colliding, wrapped in a Model with a PrimaryPart. nil if not imported.
function CreatureModels.imported(category: string, name: string): Model?
	local root = ReplicatedStorage:FindFirstChild("OceanModels")
	local folder = root and root:FindFirstChild(category)
	local source = folder and folder:FindFirstChild(name)
	if not source then return nil end
	local clone = source:Clone()
	if not clone:IsA("Model") then
		local wrapper = Instance.new("Model")
		wrapper.Name = name
		clone.Parent = wrapper
		clone = wrapper
	end
	for _, part in clone:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	if not clone.PrimaryPart then
		clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
	end
	if not clone.PrimaryPart then
		clone:Destroy()
		return nil
	end
	clone:SetAttribute("ForwardYaw", 90) -- GLB rigs look along +X
	clone:SetAttribute("Imported", true)
	return clone
end

-- Moves a model so the bottom centre of its bounding box sits on `ground`.
local function standOn(model: Model, ground: Vector3)
	local box, size = model:GetBoundingBox()
	local bottom = box.Position - Vector3.new(0, size.Y / 2, 0)
	model:PivotTo(model:GetPivot() + (ground - bottom))
end


---------------------------------------------------------------- eggs
local function builtEgg(parent: Instance, eggType: string, cf: CFrame, scale: number)
	local info = Config.Eggs[eggType]
	local m = Pieces.model(parent, "Egg")
	local s = scale
	local shell = Pieces.ellipsoid(m, "Shell", Vector3.new(2.0, 2.6, 2.0) * s, cf * CFrame.new(0, 1.3 * s, 0), info.shell)
	shell.Reflectance = 0.05
	for i, spot in {{0, 0.5, 30}, {0.7, 1.4, 150}, {-0.5, 1.9, 260}, {0.2, 0.9, 210}, {-0.3, 0.2, 100}} do
		local yaw = math.rad(spot[3])
		local height = spot[2] * s
		local radius = s * math.sqrt(math.max(0.05, 1 - ((spot[2] - 1.3) / 1.3) ^ 2))
		local pos = cf * CFrame.new(math.sin(yaw) * radius * 0.96, height, math.cos(yaw) * radius * 0.96)
		local look = CFrame.lookAt(pos.Position, (cf * CFrame.new(0, height, 0)).Position)
		Pieces.ellipsoid(m, "Spot", Vector3.new(0.6 - i * 0.04, 0.55 - i * 0.04, 0.16) * s, look, info.spots)
	end
	if info.glow then
		local glow = Pieces.cylinder(m, "EggGlow", 0.1, 2.6 * s, cf * CFrame.new(0, 0.05, 0), info.spots, Enum.Material.Neon, {Transparency = 0.35})
		local light = Instance.new("PointLight")
		light.Color = info.shell
		light.Range = 8
		light.Brightness = 1
		light.Parent = glow
		sparkles(shell, info.spots, 3)
	end
	m.PrimaryPart = shell
	return m
end

-- Egg standing on `cf` (its bottom at cf.Position). Imported models keep the
-- size they have in the StudEggs files; built ones get the same height.
function CreatureModels.egg(parent: Instance, eggType: string, cf: CFrame)
	local info = Config.Eggs[eggType]
	assert(info, "Unknown egg " .. tostring(eggType))
	local height = info.size and info.size.Y or 3.5
	local m = CreatureModels.imported("Eggs", info.model)
	if m then
		m.Name = "Egg"
		m.Parent = parent
		standOn(m, cf.Position)
	else
		m = builtEgg(parent, eggType, cf, height / 2.6)
	end
	m:SetAttribute("EggType", eggType)
	m:AddTag("OceanEgg")
	return m
end

---------------------------------------------------------------- fish (built)
local function builtFish(parent: Instance, fishType: string, cf: CFrame)
	local info = Config.Fish[fishType]
	local m = Pieces.model(parent, fishType)
	local round = info.round
	local length = round and 2.2 or 2.8
	local body = Pieces.ellipsoid(m, "Body", Vector3.new(round and 2.1 or 1.5, round and 2.0 or 1.7, length), cf, info.body)
	Pieces.ellipsoid(m, "Belly", Vector3.new(round and 1.8 or 1.2, round and 1.2 or 0.9, length * 0.82), cf * CFrame.new(0, -0.35, -0.1), info.belly)
	for _, z in (round and {} or {-0.35, 0.45}) do
		Pieces.ellipsoid(m, "Stripe", Vector3.new(1.56, 1.76, 0.28), cf * CFrame.new(0, 0.02, z), info.stripe)
	end
	if round then
		for i = 0, 7 do
			local a = math.rad(i * 45)
			Pieces.wedge(m, "Spike", Vector3.new(0.12, 0.35, 0.3), cf * CFrame.new(math.cos(a) * 1.05, math.sin(a) * 1.0, 0.2) * CFrame.Angles(0, 0, a - math.pi / 2), info.stripe)
		end
	end
	local tailRoot = cf * CFrame.new(0, 0, length / 2 + 0.25)
	for _, side in {1, -1} do
		local tail = Pieces.wedge(m, "Tail", Vector3.new(0.18, 0.9, 1.0), tailRoot * CFrame.new(0, side * 0.32, 0.35) * CFrame.Angles(math.rad(side * 30), 0, side < 0 and math.pi or 0), info.fin)
		tail:SetAttribute("Tail", true)
	end
	Pieces.wedge(m, "DorsalFin", Vector3.new(0.16, 0.7, 1.1), cf * CFrame.new(0, (round and 1.0 or 0.85) + 0.25, 0.25), info.fin)
	for _, side in {-1, 1} do
		Pieces.ellipsoid(m, "SideFin", Vector3.new(0.12, 0.45, 0.75), cf * CFrame.new(side * (round and 1.05 or 0.78), -0.2, -0.1) * CFrame.Angles(0, math.rad(side * 25), math.rad(side * 20)), info.fin)
		local eye = cf * CFrame.new(side * (round and 0.75 or 0.55), 0.3, -length / 2 + (round and 0.55 or 0.6))
		Pieces.ball(m, "EyeWhite", 0.62, eye, C.White)
		Pieces.ball(m, "Pupil", 0.36, eye * CFrame.new(side * 0.12, 0, -0.17), Color3.fromRGB(20, 20, 30))
		Pieces.ball(m, "Glint", 0.13, eye * CFrame.new(side * 0.17, 0.1, -0.3), C.White)
	end
	Pieces.part(m, "Mouth", Vector3.new(0.35, 0.12, 0.12), cf * CFrame.new(0, -0.18, -length / 2 + 0.02), Color3.fromRGB(120, 30, 40))
	if info.lure then
		local lure = Pieces.ball(m, "Lure", 0.5, cf * CFrame.new(0, 1.5, -2.1), Color3.fromRGB(255, 240, 120), Enum.Material.Neon)
		Pieces.rod(m, "LureStalk", (cf * CFrame.new(0, 0.9, -0.6)).Position, lure.CFrame.Position, 0.12, info.stripe)
	end
	if info.crown then
		local crown = cf * CFrame.new(0, 1.0, -0.3)
		Pieces.cylinder(m, "CrownBand", 0.3, 0.95, crown, C.Gold, Enum.Material.Neon)
		for i = 0, 4 do
			local a = math.rad(i * 72)
			Pieces.wedge(m, "CrownSpike", Vector3.new(0.18, 0.45, 0.3), crown * CFrame.new(math.cos(a) * 0.38, 0.35, math.sin(a) * 0.38) * CFrame.Angles(0, -a, 0), C.Gold)
		end
	end
	if info.sparkle then sparkles(body, Config.RarityColors[info.rarity] or C.GlowGold, 4) end
	m.PrimaryPart = body
	m:SetAttribute("ForwardYaw", 0)
	return m
end

-- Fish centred on cf. Imported models keep the size they have in the files.
function CreatureModels.fish(parent: Instance, fishType: string, cf: CFrame)
	assert(Config.Fish[fishType], "Unknown fish " .. tostring(fishType))
	local m = CreatureModels.imported("Fish", fishType)
	if m then
		m.Parent = parent
		local box = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + (cf.Position - box.Position))
	else
		m = builtFish(parent, fishType, cf)
		-- Same length as the fish in the Studfish files (the built one is ~3 studs).
		local info = Config.Fish[fishType]
		local builtLength = info.round and 2.9 or 3.6
		if info.length and math.abs(info.length - builtLength) > 0.1 then
			local pivot = m:GetPivot()
			m:ScaleTo(info.length / builtLength)
			m:PivotTo(pivot)
		end
	end
	m.Name = fishType
	m:SetAttribute("FishType", fishType)
	-- Glow ring on the water under the fish (animated on the client).
	Pieces.cylinder(m, "Ripple", 0.06, 3.4, cf * CFrame.new(0, -1, 0), C.Foam, Enum.Material.Neon, {Transparency = 0.6, CastShadow = false})
	m:AddTag("OceanFish")
	return m
end

---------------------------------------------------------------- predators (built)
-- Big blocky fish with a toothy jaw, glowing eyes and a forked tail, -Z forward.
local function builtPredator(parent: Instance, kind: string, cf: CFrame)
	local info = Config.Predators[kind]
	local L = info.length
	local m = Pieces.model(parent, kind)
	local color = info.color
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.35)
	local body = Pieces.part(m, "Body", Vector3.new(L * 0.22, L * 0.24, L * 0.62), cf, color)
	Pieces.part(m, "Back", Vector3.new(L * 0.18, L * 0.06, L * 0.5), cf * CFrame.new(0, L * 0.14, 0.02 * L), dark)
	Pieces.part(m, "Head", Vector3.new(L * 0.24, L * 0.2, L * 0.2), cf * CFrame.new(0, L * 0.02, -L * 0.38), color)
	Pieces.part(m, "Jaw", Vector3.new(L * 0.2, L * 0.07, L * 0.2), cf * CFrame.new(0, -L * 0.1, -L * 0.4), dark)
	for i = -2, 2 do
		for _, row in {{-0.055, 0}, {-0.13, math.pi}} do
			Pieces.wedge(m, "Tooth", Vector3.new(L * 0.025, L * 0.05, L * 0.025),
				cf * CFrame.new(i * L * 0.035, L * row[1], -L * 0.49) * CFrame.Angles(0, 0, row[2]), C.Shell)
		end
	end
	for _, side in {-1, 1} do
		Pieces.part(m, "Eye", Vector3.new(L * 0.02, L * 0.05, L * 0.05), cf * CFrame.new(side * L * 0.12, L * 0.06, -L * 0.42), Color3.fromRGB(255, 220, 60), Enum.Material.Neon)
		Pieces.wedge(m, "SideFin", Vector3.new(L * 0.02, L * 0.08, L * 0.14), cf * CFrame.new(side * L * 0.13, -L * 0.08, -L * 0.1) * CFrame.Angles(0, 0, math.rad(side * 60)), dark)
	end
	Pieces.wedge(m, "DorsalFin", Vector3.new(L * 0.03, L * 0.16, L * 0.2), cf * CFrame.new(0, L * 0.2, 0.02 * L), dark)
	for _, side in {1, -1} do
		local tail = Pieces.wedge(m, "Tail", Vector3.new(L * 0.03, L * 0.16, L * 0.16),
			cf * CFrame.new(0, side * L * 0.07, L * 0.38) * CFrame.Angles(math.rad(side * 35), 0, side < 0 and math.pi or 0), dark)
		tail:SetAttribute("Tail", true)
	end
	m.PrimaryPart = body
	m:SetAttribute("ForwardYaw", 0)
	return m
end

function CreatureModels.predator(parent: Instance, kind: string, cf: CFrame)
	assert(Config.Predators[kind], "Unknown predator " .. tostring(kind))
	local m = CreatureModels.imported("Predators", kind)
	if m then
		-- The predator runtime would patrol on its own; the server moves it instead.
		for _, part in m:GetDescendants() do
			if part:IsA("MeshPart") then part:SetAttribute("PatrolRadius", 0) end
		end
		m.Parent = parent
		local box = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + (cf.Position - box.Position))
	else
		m = builtPredator(parent, kind, cf)
	end
	m.Name = kind
	m:SetAttribute("PredatorType", kind)
	m:AddTag("OceanPredator")
	return m
end

---------------------------------------------------------------- rolls
-- Egg → tier (weighted) → random fish of that tier.
function CreatureModels.rollFish(eggType: string, random: Random?): string
	local info = Config.Eggs[eggType]
	local rng = random or Random.new()
	local tiers, total = {}, 0
	for tier, weight in pairs(info.tiers) do
		table.insert(tiers, tier)
		total += weight
	end
	table.sort(tiers)
	local roll = rng:NextNumber() * total
	local chosen = tiers[#tiers]
	for _, tier in tiers do
		roll -= info.tiers[tier]
		if roll <= 0 then
			chosen = tier
			break
		end
	end
	local list = Config.FishTiers[chosen]
	return list[math.clamp(math.floor(rng:NextNumber() * #list) + 1, 1, #list)]
end

return CreatureModels
