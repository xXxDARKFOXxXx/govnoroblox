-- Ambient details only: swaying wall kelp, ascending bubbles, wall shimmer.
-- No HUD, economy, NPCs, collectibles, damage, or gameplay systems.
local RunService = game:GetService("RunService")
local map = workspace:WaitForChild("OceanMap")
local decor = map:WaitForChild("WallDecor")
local seabed = map:WaitForChild("SeabedDecor")
local rng = Random.new(1827)
local kelp, glints, sources = {}, {}, {}

for _, model in map:GetDescendants() do
	if model:IsA("Model") and model.Name == "KelpBlade" then
		local origin = model:FindFirstChild("SwayOrigin")
		if origin then
			local facing = model:FindFirstChild("SwayFacing")
			local pivot = CFrame.new(origin.Value) * CFrame.Angles(0, facing and facing.Value or 0, 0)
			local parts = {}
			for _, part in model:GetChildren() do
				if part:IsA("BasePart") then
					table.insert(parts, {part = part, relative = pivot:ToObjectSpace(part.CFrame)})
				end
			end
			table.insert(kelp, {pivot = pivot, parts = parts, phase = rng:NextNumber(0, math.pi * 2), speed = rng:NextNumber(0.7, 1.15)})
		end
	end
end

for _, part in map:GetDescendants() do
	if part:IsA("BasePart") and part.Name == "CausticStroke" then
		table.insert(glints, {part = part, base = part.CFrame, phase = rng:NextNumber(0, math.pi * 2)})
	elseif part:IsA("BasePart") and part.Name == "BubbleSource" then
		table.insert(sources, {position = part.Position, height = part.RiseHeight.Value})
	end
end

local preview = map:FindFirstChild("BubblePreview")
if preview then
	for _, part in preview:GetDescendants() do
		if part:IsA("BasePart") then part.LocalTransparencyModifier = 1 end
	end
end

local localFX = Instance.new("Folder")
localFX.Name = "OceanLocalBubbles"
localFX.Parent = workspace
local bubbles = {}
for _ = 1, 112 do
	local p = Instance.new("Part")
	p.Name = "Bubble"
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.CastShadow = false
	p.Material = Enum.Material.Glass
	p.Color = Color3.fromRGB(157, 246, 255)
	p.Transparency = 1
	p.Parent = localFX
	local sparkle = p:Clone()
	sparkle.Name = "BubbleHighlight"
	sparkle.Material = Enum.Material.Neon
	sparkle.Color = Color3.fromRGB(224, 255, 255)
	sparkle.Parent = localFX
	table.insert(bubbles, {part = p, sparkle = sparkle, age = 100, duration = 0})
end

local t, accumulator, sourceAccumulator = 0, 0, 1
local nearby = {}
local function near(a, b, range)
	return (a - b).Magnitude < range
end

local connection
connection = RunService.Heartbeat:Connect(function(dt)
	if not map.Parent then
		connection:Disconnect()
		localFX:Destroy()
		return
	end
	t += dt
	accumulator += dt
	if accumulator < 1 / 30 then return end
	local step = accumulator
	accumulator = 0
	local camera = workspace.CurrentCamera
	if not camera then return end
	local eye = camera.CFrame.Position

	for _, blade in kelp do
		if near(blade.pivot.Position, eye, 220) then
			local pose = blade.pivot * CFrame.Angles(math.sin(t * blade.speed + blade.phase) * 0.02, 0, math.sin(t * blade.speed * 0.83 + blade.phase) * 0.09)
			for _, entry in blade.parts do entry.part.CFrame = pose * entry.relative end
		end
	end
	for _, glint in glints do
		if near(glint.base.Position, eye, 240) then
			glint.part.Transparency = 0.69 + math.sin(t * 0.85 + glint.phase) * 0.18
			-- Move only vertically so the light stays on its wall face.
			glint.part.CFrame = glint.base + Vector3.new(0, math.sin(t * 0.55 + glint.phase) * 0.65, 0)
		end
	end

	sourceAccumulator += step
	if sourceAccumulator > 0.7 then
		sourceAccumulator = 0
		table.clear(nearby)
		for _, source in sources do
			if near(source.position, eye, 180) then table.insert(nearby, source) end
		end
	end
	for _, bubble in bubbles do
		bubble.age += step
		if bubble.age >= bubble.duration then
			if #nearby == 0 then
				bubble.part.Transparency, bubble.sparkle.Transparency = 1, 1
				continue
			end
			local source = nearby[rng:NextInteger(1, #nearby)]
			bubble.origin = source.position + Vector3.new(rng:NextNumber(-0.55, 0.55), 0, rng:NextNumber(-0.55, 0.55))
			bubble.height = source.height
			bubble.duration = rng:NextNumber(8, 13)
			bubble.age = rng:NextNumber(0, bubble.duration * 0.85)
			bubble.phase = rng:NextNumber(0, math.pi * 2)
			bubble.size = rng:NextNumber(0.3, 0.82)
		end
		local alpha = bubble.age / bubble.duration
		local size = bubble.size * (0.65 + alpha * 0.4)
		bubble.part.Size = Vector3.one * size
		bubble.part.Position = bubble.origin + Vector3.new(math.sin(t * 1.1 + bubble.phase) * 0.45, alpha * bubble.height, math.cos(t + bubble.phase) * 0.45)
		local fade = math.min(alpha * 7, (1 - alpha) * 7, 1)
		bubble.part.Transparency = 1 - fade * 0.4
		bubble.sparkle.Size = Vector3.one * size * 0.18
		bubble.sparkle.Position = bubble.part.Position + Vector3.new(-size * 0.2, size * 0.23, -size * 0.31)
		bubble.sparkle.Transparency = 1 - fade * 0.72
	end
end)
