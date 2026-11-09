-- CreatureModels: cute cartoon eggs and fish built from parts (ellipsoids via
-- built-in sphere meshes, wedges for fins). Models face -Z (LookVector).
--
-- Fish models: PrimaryPart "Body"; parts with attribute Tail = true wag; a
-- "Ripple" ring sits on the water around the fish. Tags: OceanFish / OceanEgg.
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

---------------------------------------------------------------- eggs
function CreatureModels.egg(parent: Instance, eggType: string, cf: CFrame)
	local info = Config.Eggs[eggType]
	assert(info, "Unknown egg " .. tostring(eggType))
	local m = Pieces.model(parent, "Egg")
	m:SetAttribute("EggType", eggType)
	local shell = Pieces.ellipsoid(m, "Shell", Vector3.new(2.0, 2.6, 2.0), cf * CFrame.new(0, 1.3, 0), info.shell)
	shell.Reflectance = 0.05
	-- Spots: flat ellipsoids pressed onto the shell surface.
	for i, spot in {{0, 0.5, 30}, {0.7, 1.4, 150}, {-0.5, 1.9, 260}, {0.2, 0.9, 210}, {-0.3, 0.2, 100}} do
		local yaw = math.rad(spot[3])
		local height = spot[2]
		local radius = 1.0 * math.sqrt(math.max(0.05, 1 - ((height - 1.3) / 1.3) ^ 2))
		local pos = cf * CFrame.new(math.sin(yaw) * radius * 0.96, height, math.cos(yaw) * radius * 0.96)
		local look = CFrame.lookAt(pos.Position, (cf * CFrame.new(0, height, 0)).Position)
		Pieces.ellipsoid(m, "Spot", Vector3.new(0.6 - i * 0.04, 0.55 - i * 0.04, 0.16), look, info.spots)
	end
	if info.glow then
		local glow = Pieces.cylinder(m, "EggGlow", 0.1, 2.6, cf * CFrame.new(0, 0.05, 0), info.spots, Enum.Material.Neon, {Transparency = 0.35})
		local light = Instance.new("PointLight")
		light.Color = info.shell
		light.Range = 8
		light.Brightness = 1
		light.Parent = glow
		sparkles(shell, info.spots, 3)
	end
	m.PrimaryPart = shell
	m:AddTag("OceanEgg")
	return m
end

---------------------------------------------------------------- fish
function CreatureModels.fish(parent: Instance, fishType: string, cf: CFrame)
	local info = Config.Fish[fishType]
	assert(info, "Unknown fish " .. tostring(fishType))
	local m = Pieces.model(parent, fishType)
	m:SetAttribute("FishType", fishType)
	local round = info.round
	local length = round and 2.2 or 2.8
	local body = Pieces.ellipsoid(m, "Body", Vector3.new(round and 2.1 or 1.5, round and 2.0 or 1.7, length), cf, info.body)
	Pieces.ellipsoid(m, "Belly", Vector3.new(round and 1.8 or 1.2, round and 1.2 or 0.9, length * 0.82), cf * CFrame.new(0, -0.35, -0.1), info.belly)
	-- Stripes wrap the body (flattened ellipsoids slightly larger than it).
	for _, z in (round and {} or {-0.35, 0.45}) do
		Pieces.ellipsoid(m, "Stripe", Vector3.new(1.56, 1.76, 0.28), cf * CFrame.new(0, 0.02, z), info.stripe)
	end
	if round then
		for i = 0, 7 do -- puffer spikes
			local a = math.rad(i * 45)
			Pieces.wedge(m, "Spike", Vector3.new(0.12, 0.35, 0.3), cf * CFrame.new(math.cos(a) * 1.05, math.sin(a) * 1.0, 0.2) * CFrame.Angles(0, 0, a - math.pi / 2), info.stripe)
		end
	end
	-- Tail: two angled wedges behind the body (they wag on the client).
	local tailRoot = cf * CFrame.new(0, 0, length / 2 + 0.25)
	for _, side in {1, -1} do
		local tail = Pieces.wedge(m, "Tail", Vector3.new(0.18, 0.9, 1.0), tailRoot * CFrame.new(0, side * 0.32, 0.35) * CFrame.Angles(math.rad(side * 30), 0, side < 0 and math.pi or 0), info.fin)
		tail:SetAttribute("Tail", true)
	end
	-- Fins.
	Pieces.wedge(m, "DorsalFin", Vector3.new(0.16, 0.7, 1.1), cf * CFrame.new(0, (round and 1.0 or 0.85) + 0.25, 0.25), info.fin)
	for _, side in {-1, 1} do
		Pieces.ellipsoid(m, "SideFin", Vector3.new(0.12, 0.45, 0.75), cf * CFrame.new(side * (round and 1.05 or 0.78), -0.2, -0.1) * CFrame.Angles(0, math.rad(side * 25), math.rad(side * 20)), info.fin)
		-- Big cute eyes: white, black pupil, white glint.
		local eye = cf * CFrame.new(side * (round and 0.75 or 0.55), 0.3, -length / 2 + (round and 0.55 or 0.6))
		Pieces.ball(m, "EyeWhite", 0.62, eye, C.White)
		Pieces.ball(m, "Pupil", 0.36, eye * CFrame.new(side * 0.12, 0, -0.17), Color3.fromRGB(20, 20, 30))
		Pieces.ball(m, "Glint", 0.13, eye * CFrame.new(side * 0.17, 0.1, -0.3), C.White)
		Pieces.ellipsoid(m, "Cheek", Vector3.new(0.12, 0.2, 0.32), cf * CFrame.new(side * (round and 0.98 or 0.7), -0.25, -length / 2 + 0.95), Color3.fromRGB(255, 140, 160))
	end
	Pieces.part(m, "Mouth", Vector3.new(0.35, 0.12, 0.12), cf * CFrame.new(0, -0.18, -length / 2 + 0.02), Color3.fromRGB(120, 30, 40))
	if info.lure then
		local stalkBase = cf * CFrame.new(0, 0.9, -0.6)
		Pieces.rod(m, "LureStalk", stalkBase.Position, (cf * CFrame.new(0, 1.9, -1.3)).Position, 0.12, info.stripe)
		Pieces.rod(m, "LureStalk", (cf * CFrame.new(0, 1.9, -1.3)).Position, (cf * CFrame.new(0, 1.6, -2.0)).Position, 0.12, info.stripe)
		local lure = Pieces.ball(m, "Lure", 0.5, cf * CFrame.new(0, 1.5, -2.1), Color3.fromRGB(255, 240, 120), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 230, 120)
		light.Range = 7
		light.Brightness = 1.5
		light.Parent = lure
	end
	if info.crown then
		local crown = cf * CFrame.new(0, 1.0, -0.3)
		Pieces.cylinder(m, "CrownBand", 0.3, 0.95, crown, C.Gold, Enum.Material.Neon)
		for i = 0, 4 do
			local a = math.rad(i * 72)
			Pieces.wedge(m, "CrownSpike", Vector3.new(0.18, 0.45, 0.3), crown * CFrame.new(math.cos(a) * 0.38, 0.35, math.sin(a) * 0.38) * CFrame.Angles(0, -a, 0), C.Gold)
		end
		Pieces.ball(m, "CrownGem", 0.22, crown * CFrame.new(0, 0.1, -0.48), Color3.fromRGB(255, 60, 120))
	end
	if info.sparkle then
		sparkles(body, Config.RarityColors[info.rarity] or C.GlowGold, 4)
	end
	-- Ripple ring on the water surface (animated on the client).
	Pieces.cylinder(m, "Ripple", 0.06, 3.4, cf * CFrame.new(0, -0.35, 0), C.Foam, Enum.Material.Neon, {Transparency = 0.6, CastShadow = false})
	m.PrimaryPart = body
	m:AddTag("OceanFish")
	return m
end

-- Weighted random fish for an egg type.
function CreatureModels.rollFish(eggType: string, random: Random?): string
	local info = Config.Eggs[eggType]
	local rng = random or Random.new()
	local total = 0
	local keys = {}
	for fishType, weight in pairs(info.fish) do
		total += weight
		table.insert(keys, fishType)
	end
	table.sort(keys)
	local roll = rng:NextNumber() * total
	for _, fishType in keys do
		roll -= info.fish[fishType]
		if roll <= 0 then return fishType end
	end
	return keys[#keys]
end

return CreatureModels
