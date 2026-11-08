local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local V = require(script.Parent.Visuals)
local World = {}
local rgb = Color3.fromRGB

local function tree(parent, x, z, scale)
	local trunk = V.part(parent, "PalmTrunk", Vector3.new(1.3, 10, 1.3) * scale,
		CFrame.new(x, 5 * scale, z) * CFrame.Angles(0, 0, 0.12), rgb(155, 104, 65), Enum.Material.Wood)
	for i = 1, 5 do
		V.part(parent, "PalmLeaf", Vector3.new(2.5, 0.6, 9) * scale,
			CFrame.new(x + 0.6, 10 * scale, z) * CFrame.Angles(0, i * math.pi * 2 / 5, 0) * CFrame.new(0, 0, -3 * scale) * CFrame.Angles(-0.22, 0, 0), rgb(52, 164, 108))
	end
	trunk.CanCollide = false
end

function World.Build()
	local existing = workspace:FindFirstChild("LuckyTideWorld")
	if existing then existing:Destroy() end
	local root = Instance.new("Folder"); root.Name = "LuckyTideWorld"; root.Parent = workspace
	local decor = Instance.new("Folder"); decor.Name = "Scenery"; decor.Parent = root
	local plots = Instance.new("Folder"); plots.Name = "Plots"; plots.Parent = root
	local blocks = Instance.new("Folder"); blocks.Name = "Blocks"; blocks.Parent = root
	local drops = Instance.new("Folder"); drops.Name = "Drops"; drops.Parent = root
	local effects = Instance.new("Folder"); effects.Name = "Effects"; effects.Parent = root

	Lighting.ClockTime = 14.4
	Lighting.Brightness = 2.4
	Lighting.Ambient = rgb(147, 165, 194)
	Lighting.OutdoorAmbient = rgb(156, 177, 197)
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.65
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Name = "LuckyTideAtmosphere"; atmosphere.Density = 0.25; atmosphere.Offset = 0.2
	atmosphere.Color = rgb(205, 235, 255); atmosphere.Decay = rgb(151, 194, 226); atmosphere.Parent = Lighting

	local sea = V.part(decor, "Ocean", Vector3.new(1400, 2, 1400), CFrame.new(0, -8, 120), rgb(40, 168, 196), Enum.Material.Glass)
	sea.Transparency = 0.22; sea.CanCollide = false
	V.part(decor, "IslandRock", Vector3.new(232, 16, 212), CFrame.new(0, -9, -68), rgb(204, 180, 138), Enum.Material.Sandstone)
	V.part(decor, "Island", Vector3.new(226, 2, 206), CFrame.new(0, -1, -68), rgb(119, 196, 129), Enum.Material.Grass)
	V.part(decor, "Plaza", Vector3.new(53, 0.3, 185), CFrame.new(0, 0.15, -65), rgb(229, 224, 207))
	V.part(decor, "Beach", Vector3.new(142, 4, 325), CFrame.new(0, -2, 192), rgb(243, 222, 165), Enum.Material.Sand)
	V.part(decor, "SafeLine", Vector3.new(142, 0.12, 1), CFrame.new(0, 0.08, 29), rgb(83, 255, 192), Enum.Material.Neon)
	local sign = V.part(decor, "SafeSign", Vector3.new(31, 5, 0.6), CFrame.new(0, 5, 25), rgb(22, 67, 71))
	sign.CanCollide = false
	V.label(sign, "БЕЗОПАСНЫЙ БЕРЕГ\nДонеси яйцо на свою базу", rgb(172, 255, 218), 380, 66, Vector3.new(0, 1, 0))

	local title = V.part(decor, "Welcome", Vector3.new(38, 7, 1), CFrame.new(0, 10, -164), rgb(22, 48, 66))
	V.label(title, "LUCKY TIDE\nПни • спаси • вырасти", rgb(255, 226, 122), 450, 95, Vector3.new(0, 0, 0))
	for _, x in ipairs({-20, 20}) do V.part(decor, "SignPost", Vector3.new(1, 14, 1), CFrame.new(x, 6, -164), rgb(163, 121, 79), Enum.Material.Wood) end
	for _, x in ipairs({-104, 104}) do
		for z = -150, 10, 40 do tree(decor, x, z, 0.8 + (z % 3) * 0.15) end
	end

	local templates = ServerStorage:FindFirstChild("LuckyTideAssets")
	local baseTemplate = templates and templates:FindFirstChild("BaseTemplate")
	local plotList = {}
	for i = 1, 6 do
		local side = if i <= 3 then -1 else 1
		local row = (i - 1) % 3
		local x, z = side * 73, -127 + row * 59
		-- Local front is -Z; every plot faces the plaza.
		local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, if side == -1 then -math.pi / 2 else math.pi / 2, 0)
		local plot = Instance.new("Model"); plot.Name = "Plot" .. i; plot:SetAttribute("PlotId", i); plot.Parent = plots
		local floor = V.part(plot, "Floor", Vector3.new(49, 0.8, 49), cf * CFrame.new(0, 0.4, 0), rgb(244, 238, 218))
		plot.PrimaryPart = floor
		V.part(plot, "Trim", Vector3.new(51, 0.3, 51), cf * CFrame.new(0, 0, 0), rgb(60, 163, 159))
		if baseTemplate then
			local copy = baseTemplate:Clone(); copy.Name = "OriginalBase"; copy.Parent = plot
			for _, obj in ipairs(copy:GetDescendants()) do
				if obj:IsA("LuaSourceContainer") or obj:IsA("ProximityPrompt") or obj:IsA("SpawnLocation") then obj:Destroy()
				elseif obj:IsA("BasePart") then obj.Anchored = true end
			end
			if copy:IsA("Model") and copy:FindFirstChildWhichIsA("BasePart", true) then
				V.fit(copy, cf * CFrame.new(0, 2.55, 0), Vector3.new(47, 5, 47), false)
			end
		else
			V.part(plot, "BackWall", Vector3.new(49, 9, 1), cf * CFrame.new(0, 5, 24), rgb(237, 230, 213))
			for _, sx in ipairs({-24, 24}) do
				V.part(plot, "SideWall", Vector3.new(1, 9, 31), cf * CFrame.new(sx, 5, 8), rgb(237, 230, 213))
				V.part(plot, "Pillar", Vector3.new(1.5, 11, 1.5), cf * CFrame.new(sx, 6, -19), rgb(57, 123, 128))
			end
			V.part(plot, "Canopy", Vector3.new(51, 1, 11), cf * CFrame.new(0, 11.5, 19), rgb(73, 163, 160))
		end
		local name = V.part(plot, "NameBoard", Vector3.new(25, 3, 0.5), cf * CFrame.new(0, 8, -23), rgb(25, 56, 70))
		name.CanCollide = false
		local titleLabel = V.label(name, "СВОБОДНАЯ БАЗА", rgb(255, 255, 255), 260, 45, Vector3.zero)
		local spawn = Instance.new("SpawnLocation"); spawn.Name = "Spawn"; spawn.Size = Vector3.new(7, 0.2, 7)
		spawn.CFrame = cf * CFrame.new(0, 1, -15); spawn.Transparency = 1; spawn.Anchored = true
		spawn.CanCollide = false; spawn.Neutral = true; spawn.Enabled = false; spawn.Parent = plot
		local deposit = V.part(plot, "Deposit", Vector3.new(14, 0.25, 7), cf * CFrame.new(0, 0.95, -16), rgb(78, 212, 169), Enum.Material.Neon)
		V.label(deposit, "ПОЛОЖИТЬ ЯЙЦО", rgb(195, 255, 222), 180, 35, Vector3.new(0, 1, 0))
		local collect = V.part(plot, "Collect", Vector3.new(7, 0.3, 7), cf * CFrame.new(-17, 1, -16), rgb(255, 207, 73))
		local bankLabel = V.label(collect, "$0\nСОБРАТЬ", rgb(255, 232, 143), 150, 55, Vector3.new(0, 2, 0))
		local shield = V.part(plot, "ShieldButton", Vector3.new(5, 1, 5), cf * CFrame.new(18, 1.25, -16), rgb(89, 180, 241))
		V.label(shield, "ЩИТ", rgb(174, 223, 255), 130, 35, Vector3.new(0, 2, 0))
		local barrier = V.part(plot, "ShieldVisual", Vector3.new(47, 9, 0.35), cf * CFrame.new(0, 5, -23), rgb(101, 207, 255), Enum.Material.ForceField)
		barrier.Transparency = 1; barrier.CanCollide = false
		local slots = {}
		for slot = 1, 10 do
			local sx = -18 + ((slot - 1) % 5) * 9
			local sz = if slot <= 5 then 1 else 15
			local pad = V.part(plot, "Slot" .. slot, Vector3.new(6.5, 0.6, 6.5), cf * CFrame.new(sx, 1.1, sz), rgb(201, 218, 215))
			pad:SetAttribute("SlotIndex", slot)
			slots[slot] = pad
		end
		local display = Instance.new("Folder"); display.Name = "Collection"; display.Parent = plot
		plotList[i] = {Model = plot, CF = cf, Spawn = spawn, Deposit = deposit, Collect = collect,
			BankLabel = bankLabel, Shield = shield, Barrier = barrier, Title = titleLabel, Slots = slots, Display = display}
	end

	local gym = V.part(root, "Training", Vector3.new(13, 0.3, 11), CFrame.new(0, 0.4, -129), rgb(96, 133, 231))
	V.label(gym, "ТРЕНИРОВКА\n+ СИЛА УДАРА", rgb(200, 216, 255), 240, 65, Vector3.new(0, 5, 0))
	V.part(decor, "WeightBar", Vector3.new(10, 0.6, 0.6), CFrame.new(0, 2, -129), rgb(74, 84, 104), Enum.Material.Metal)
	for _, x in ipairs({-4, 4}) do V.part(decor, "Weight", Vector3.new(1.5, 3, 3), CFrame.new(x, 2, -129), rgb(48, 61, 86)) end
	local shop = V.part(root, "UpgradeShop", Vector3.new(13, 3, 7), CFrame.new(0, 1.6, -103), rgb(252, 195, 77))
	V.label(shop, "УЛУЧШЕНИЯ", rgb(255, 233, 159), 230, 45, Vector3.new(0, 3, 0))

	local config = require(game:GetService("ReplicatedStorage").LuckyTide.Config)
	local stations = {}
	for tier = 1, 5 do
		local z = 47 + (tier - 1) * 57
		local color = V.color(config.Rarities[tier].Color)
		local stripe = V.part(decor, "Zone" .. tier, Vector3.new(140, 0.07, 2), CFrame.new(0, 0.04, z - 12), color)
		stripe.CanCollide = false
		local zoneSign = V.part(decor, "ZoneSign", Vector3.new(1, 5, 1), CFrame.new(-66, 2.5, z), rgb(170, 127, 83))
		V.label(zoneSign, config.Rarities[tier].Name .. "\nСИЛА " .. config.Rarities[tier].Required, color, 230, 70, Vector3.new(0, 4, 0))
		for _, x in ipairs({-35, 0, 35}) do
			local pad = V.part(blocks, "BlockPad", Vector3.new(7, 0.5, 7), CFrame.new(x, 0.25, z), color:Lerp(rgb(250, 239, 208), 0.6))
			pad:SetAttribute("Tier", tier)
			table.insert(stations, {Position = Vector3.new(x, 2.6, z), Tier = tier, Pad = pad, Variant = #stations + 1})
		end
	end
	for _, z in ipairs({112, 226}) do
		for _, x in ipairs({-59, 59}) do
			V.part(decor, "Refuge", Vector3.new(14, 12, 16), CFrame.new(x, 6, z), rgb(159, 190, 179), Enum.Material.Slate)
			for step = 1, 6 do
				V.part(decor, "RefugeStep", Vector3.new(10, step * 2, 3), CFrame.new(x, step, z - 27 + step * 3), rgb(182, 209, 190))
			end
			local flag = V.part(decor, "RefugeFlag", Vector3.new(0.5, 6, 0.5), CFrame.new(x, 15, z), rgb(250, 246, 218))
			V.label(flag, "УКРЫТИЕ", rgb(195, 255, 221), 160, 35, Vector3.new(0, 3, 0))
		end
	end

	workspace:SetAttribute("LuckyTideSafeZ", 29)
	return {Root = root, Plots = plotList, Blocks = blocks, Drops = drops, Effects = effects, Stations = stations, Gym = gym, Shop = shop,
		Templates = templates and templates:FindFirstChild("LuckyBlocks")}
end

function World.Load()
	local root = workspace:FindFirstChild("LuckyTideWorld")
	if not root then return World.Build() end
	local plots, stations = {}, {}
	for _, model in ipairs(root.Plots:GetChildren()) do
		local slots = {}
		for i = 1, 10 do slots[i] = model:FindFirstChild("Slot" .. i) end
		plots[model:GetAttribute("PlotId")] = {Model = model, CF = model.Floor.CFrame * CFrame.new(0, -0.4, 0),
			Spawn = model.Spawn, Deposit = model.Deposit, Collect = model.Collect, BankLabel = model.Collect.Label.Text,
			Shield = model.ShieldButton, Barrier = model.ShieldVisual, Title = model.NameBoard.Label.Text, Slots = slots, Display = model.Collection}
	end
	for _, pad in ipairs(root.Blocks:GetChildren()) do
		if pad.Name == "BlockPad" then
			table.insert(stations, {Position = pad.CFrame.Position + Vector3.new(0, 2.35, 0), Tier = pad:GetAttribute("Tier"), Pad = pad, Variant = #stations + 1})
		end
	end
	for _, display in ipairs(root.Blocks:GetChildren()) do if display:IsA("Model") then display:Destroy() end end
	local assets = ServerStorage:FindFirstChild("LuckyTideAssets")
	return {Root = root, Plots = plots, Stations = stations, Blocks = root.Blocks, Drops = root.Drops, Effects = root.Effects,
		Gym = root.Training, Shop = root.UpgradeShop, Templates = assets and assets:FindFirstChild("LuckyBlocks")}
end

return World
