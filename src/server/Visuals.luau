local Shared = game:GetService("ReplicatedStorage"):WaitForChild("LuckyTide")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local V = {}

function V.bounds(model)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
				local point = p.CFrame * (p.Size * Vector3.new(x, y, z) / 2)
				low = low:Min(point); high = high:Max(point)
			end end end
		end
	end
	return (low + high) / 2, high - low
end

function V.fit(model, cf, target, uniform)
	local center, size = V.bounds(model)
	local scale = target / size
	if uniform then local n = math.min(scale.X, scale.Y, scale.Z); scale = Vector3.new(n, n, n) end
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local rotation = p.CFrame - p.CFrame.Position
			p.Size *= scale
			p.CFrame = cf * CFrame.new((p.CFrame.Position - center) * scale) * rotation
		end
	end
	return size * scale
end

function V.color(rgb) return Color3.fromRGB(rgb[1], rgb[2], rgb[3]) end

function V.part(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

function V.label(part, text, color, width, height, offset)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(width or 220, height or 60)
	gui.StudsOffset = offset or Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	label.TextSize = 18
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = Color3.fromRGB(14, 27, 46)
	label.Text = text
	label.Parent = gui
	return label
end

function V.prompt(part, action, object, hold, callback)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold or 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = part
	local began = setmetatable({}, {__mode = "k"})
	if prompt.HoldDuration > 0 then
		prompt.PromptButtonHoldBegan:Connect(function(player)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if prompt.Enabled and root and (root.CFrame.Position - part.CFrame.Position).Magnitude <= 13 then began[player] = os.clock() end
		end)
	end
	prompt.Triggered:Connect(function(player)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local held = prompt.HoldDuration == 0 or (began[player] and os.clock() - began[player] >= prompt.HoldDuration - 0.12)
		began[player] = nil
		if held and prompt.Enabled and root and hum and hum.Health > 0 and (root.CFrame.Position - part.CFrame.Position).Magnitude <= 13 then
			callback(player, prompt)
		end
	end)
	return prompt
end

function V.egg(parent, cf, tier, golden)
	local color = if golden then Color3.fromRGB(255, 216, 84) else V.color(Config.Rarities[tier].Color)
	local egg = V.part(parent, "Egg", Vector3.new(2.6, 3.3, 2.6), cf, color)
	egg.Shape = Enum.PartType.Ball
	egg.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = color; light.Range = 8; light.Brightness = 0.7; light.Parent = egg
	for i = 1, 6 do
		local a = math.pi * 2 * i / 6
		local spot = V.part(egg, "Spot", Vector3.new(0.5, 0.5, 0.15), cf * CFrame.new(math.sin(a) * 1.18, 0, math.cos(a) * 1.18) * CFrame.Angles(0, a, 0), Color3.new(1, 1, 1))
		spot.Shape = Enum.PartType.Ball; spot.CanCollide = false
		local weld = Instance.new("WeldConstraint"); weld.Part0 = egg; weld.Part1 = spot; weld.Parent = spot
		spot.Anchored = false; spot.Massless = true
	end
	return egg
end

function V.pet(parent, cf, item)
	local def = Rules.findPet(Config, item.PetId)
	local model = Instance.new("Model"); model.Name = def.Name; model.Parent = parent
	local color = if item.Mutation == "Golden" then Color3.fromRGB(255, 210, 73) else V.color(def.Color)
	local body = V.part(model, "Body", Vector3.new(2.7, 2.4, 2.5), cf, color)
	model.PrimaryPart = body
	local function part(name, size, offset, col)
		local p = V.part(model, name, size, cf * offset, col); p.CanCollide = false; return p
	end
	for _, x in ipairs({-0.65, 0.65}) do
		part("Eye", Vector3.new(0.36, 0.48, 0.16), CFrame.new(x, 0.2, -1.28), Color3.fromRGB(21, 32, 52))
		part("EyeShine", Vector3.new(0.12, 0.14, 0.05), CFrame.new(x - 0.06, 0.31, -1.38), Color3.new(1, 1, 1))
		part("Cheek", Vector3.new(0.45, 0.18, 0.1), CFrame.new(x * 1.3, -0.25, -1.28), Color3.fromRGB(255, 155, 174))
		part("Foot", Vector3.new(0.7, 0.35, 1), CFrame.new(x, -1.3, -0.35), color:Lerp(Color3.new(1, 1, 1), 0.3))
	end
	part("Nose", Vector3.new(0.25, 0.18, 0.2), CFrame.new(0, -0.08, -1.32), Color3.fromRGB(54, 53, 80))
	if def.Shape == "Bunny" then
		for _, x in ipairs({-0.7, 0.7}) do
			part("Ear", Vector3.new(0.65, 1.8, 0.65), CFrame.new(x, 1.8, 0) * CFrame.Angles(0, 0, -x * 0.2), color)
		end
	elseif def.Shape == "Bird" then
		part("Beak", Vector3.new(0.7, 0.45, 0.65), CFrame.new(0, -0.1, -1.45), Color3.fromRGB(255, 174, 59))
		for _, x in ipairs({-1.6, 1.6}) do part("Wing", Vector3.new(0.6, 1.25, 1.5), CFrame.new(x, 0, 0), color) end
	else
		for _, x in ipairs({-0.9, 0.9}) do
			part("Ear", Vector3.new(0.7, 1, 0.8), CFrame.new(x, 1.35, 0) * CFrame.Angles(0, 0, -x * 0.2), color)
		end
		if def.Shape == "Dragon" then
			for _, x in ipairs({-1.8, 1.8}) do
				part("Fin", Vector3.new(1.3, 0.25, 2), CFrame.new(x, 0.5, 0.3) * CFrame.Angles(0, 0, x * 0.3), color:Lerp(Color3.new(1, 1, 1), 0.3))
			end
		end
	end
	if item.Mutation == "Golden" then
		local sparkles = Instance.new("Sparkles"); sparkles.SparkleColor = color; sparkles.Parent = body
	end
	for _, p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
	return model, body
end

function V.block(parent, cf, tier, templates, variant)
	local candidates = {}
	if templates then
		for _, t in ipairs(templates:GetChildren()) do
			if t:GetAttribute("BlockTier") == tier then table.insert(candidates, t) end
		end
	end
	table.sort(candidates, function(a, b) return a.Name < b.Name end)
	local template = candidates[1 + ((variant or 1) - 1) % math.max(1, #candidates)]
	assert(template and template:GetAttribute("SourceFile"), "Missing new blocks template for tier " .. tostring(tier))
	if template and (template:IsA("Model") or template:IsA("BasePart")) then
		local model = Instance.new("Model"); model.Name = "LuckyBlock"; model.Parent = parent
		model:SetAttribute("SourceFile", template:GetAttribute("SourceFile"))
		local copy = template:Clone(); copy.Parent = model
		for _, obj in ipairs(copy:GetDescendants()) do
			if obj:IsA("LuaSourceContainer") then obj:Destroy() end
		end
		local root = if copy:IsA("BasePart") then copy else copy:FindFirstChildWhichIsA("BasePart", true)
		for _, p in ipairs(copy:GetDescendants()) do
			if p:IsA("BasePart") and p.Name:sub(1, 5) == "Body_" then root = p; break end
		end
		if root then
			model.PrimaryPart = root
			for _, p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end end
			V.fit(model, cf, Vector3.new(4, 4, 4), true)
			return model, root
		end
		model:Destroy()
	end
	error("Invalid new blocks template: " .. template.Name)
end

return V
