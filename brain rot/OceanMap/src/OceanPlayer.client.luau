-- Neutral-depth swimming, camera immersion and mouth bubbles. R6 / R15.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Environment = require(game:GetService("ReplicatedStorage"):WaitForChild("OceanEnvironment"))
local player = Players.LocalPlayer
local map = workspace:WaitForChild("OceanMap")
local rng = Random.new(4816)
local UP, DOWN = "OceanSwimUp", "OceanSwimDown"
local keysUp, keysDown = {}, {}
local active = false
local character, humanoid, root, attachment, depthVelocity
local jumpingWasEnabled = true
local connections = {}
local alive = true

local function clearInput()
	table.clear(keysUp)
	table.clear(keysDown)
end

local function onAction(action, state, input)
	if not active then return Enum.ContextActionResult.Pass end
	local held = action == UP and keysUp or keysDown
	local key = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode or input.UserInputType
	if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		held[key] = nil
	elseif UserInputService:GetFocusedTextBox() then
		clearInput()
		return Enum.ContextActionResult.Pass
	elseif state == Enum.UserInputState.Begin then
		held[key] = true
	end
	return Enum.ContextActionResult.Sink
end

local function setActive(value)
	if value == active then return end
	active = value
	clearInput()
	if depthVelocity then depthVelocity.Enabled = value end
	if value then
		jumpingWasEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		humanoid.Jump = false
		ContextActionService:BindActionAtPriority(UP, onAction, true, 3001, Enum.KeyCode.Space, Enum.KeyCode.E, Enum.KeyCode.ButtonA)
		ContextActionService:BindActionAtPriority(DOWN, onAction, true, 3001, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
		ContextActionService:SetTitle(UP, "Вверх")
		ContextActionService:SetTitle(DOWN, "Вниз")
		ContextActionService:SetPosition(UP, UDim2.fromScale(0.73, 0.38))
		ContextActionService:SetPosition(DOWN, UDim2.fromScale(0.54, 0.61))
		if not UserInputService:GetFocusedTextBox() then
			for _, key in {Enum.KeyCode.Space, Enum.KeyCode.E} do
				if UserInputService:IsKeyDown(key) then keysUp[key] = true end
			end
			for _, key in {Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl, Enum.KeyCode.Q} do
				if UserInputService:IsKeyDown(key) then keysDown[key] = true end
			end
		end
	else
		ContextActionService:UnbindAction(UP)
		ContextActionService:UnbindAction(DOWN)
		if humanoid and humanoid.Parent then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, jumpingWasEnabled)
		end
	end
end

local function releaseCharacter()
	setActive(false)
	if depthVelocity then depthVelocity:Destroy() end
	if attachment then attachment:Destroy() end
	character, humanoid, root, attachment, depthVelocity = nil, nil, nil, nil, nil
end

local function bindCharacter(nextCharacter)
	releaseCharacter()
	character = nextCharacter
	local nextHumanoid = nextCharacter:WaitForChild("Humanoid", 10)
	local nextRoot = nextCharacter:WaitForChild("HumanoidRootPart", 10)
	if not alive or character ~= nextCharacter or not nextHumanoid or not nextRoot then return end
	humanoid, root = nextHumanoid, nextRoot
	attachment = Instance.new("Attachment")
	attachment.Name = "OceanDepthAttachment"
	attachment.Parent = root
	depthVelocity = Instance.new("LinearVelocity")
	depthVelocity.Name = "OceanDepthControl"
	depthVelocity.Enabled = false
	depthVelocity.Attachment0 = attachment
	depthVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	-- Only Y is constrained. Roblox still controls horizontal movement,
	-- character animation, camera and normal collision response.
	depthVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	depthVelocity.LineDirection = Vector3.yAxis
	depthVelocity.LineVelocity = 0
	depthVelocity.ForceLimitsEnabled = true
	depthVelocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	depthVelocity.MaxForce = root.AssemblyMass * workspace.Gravity * 4
	depthVelocity.Parent = root
end

table.insert(connections, player.CharacterAdded:Connect(bindCharacter))
table.insert(connections, player.CharacterRemoving:Connect(function(removed)
	if removed == character then releaseCharacter() end
end))
table.insert(connections, UserInputService.WindowFocusReleased:Connect(clearInput))
table.insert(connections, UserInputService.TextBoxFocused:Connect(clearInput))
table.insert(connections, GuiService.MenuOpened:Connect(clearInput))
if player.Character then task.spawn(bindCharacter, player.Character) end

table.insert(connections, RunService.PreSimulation:Connect(function()
	local canSwim = humanoid and root and root.Parent and depthVelocity
		and humanoid.Health > 0 and not humanoid.Sit and not root.Anchored
		and map:GetAttribute("WaterBaked")
		and Environment.IsSubmerged(root.Position, active and -0.35 or 0.15)
	setActive(canSwim == true)
	if active then
		if UserInputService:GetFocusedTextBox() then clearInput() end
		humanoid.Jump = false
		depthVelocity.MaxForce = root.AssemblyMass * workspace.Gravity * 4
		depthVelocity.LineVelocity = Environment.VerticalTarget(next(keysUp) ~= nil, next(keysDown) ~= nil)
	end
end))

local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "OceanImmersionTint"
tint.Parent = Lighting
local blur = Instance.new("BlurEffect")
blur.Name = "OceanImmersionSoftness"
blur.Size = 0
blur.Parent = Lighting
local veil = Instance.new("ScreenGui")
veil.Name = "OceanImmersionEdges"
veil.IgnoreGuiInset = true
veil.ResetOnSpawn = false
veil.DisplayOrder = -10
veil.Parent = player:WaitForChild("PlayerGui")
local edges = {}
for _, edge in {
	{UDim2.fromScale(0, 0), UDim2.fromScale(0.13, 1), 0},
	{UDim2.fromScale(0.87, 0), UDim2.fromScale(0.13, 1), 180},
	{UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.15), 90},
	{UDim2.fromScale(0, 0.85), UDim2.fromScale(1, 0.15), 270},
} do
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.Position, frame.Size = edge[1], edge[2]
	frame.BackgroundColor3 = Color3.fromRGB(25, 104, 131)
	frame.BackgroundTransparency = 1
	frame.Parent = veil
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = edge[3]
	gradient.Transparency = NumberSequence.new(0.1, 1)
	gradient.Parent = frame
	table.insert(edges, frame)
end

-- Local pool, also rendering nearby players' breath. No asset uploads or
-- network messages are required. Bubbles leave the mouth in world space.
local effects = Instance.new("Folder")
effects.Name = "OceanBreathBubbles"
effects.Parent = workspace
local bubbles = {}
for _ = 1, 72 do
	local sphere = Instance.new("Part")
	sphere.Name = "MouthBubble"
	sphere.Shape = Enum.PartType.Ball
	sphere.Anchored = true
	sphere.CanCollide, sphere.CanTouch, sphere.CanQuery = false, false, false
	sphere.CastShadow = false
	sphere.Material = Enum.Material.SmoothPlastic
	sphere.Color = Color3.fromRGB(174, 233, 240)
	sphere.Transparency = 1
	sphere.Parent = effects
	local shine = sphere:Clone()
	shine.Name = "MouthBubbleHighlight"
	shine.Material = Enum.Material.Neon
	shine.Color = Color3.fromRGB(224, 250, 255)
	shine.Parent = effects
	table.insert(bubbles, {part = sphere, shine = shine, age = 10, life = 0})
end
local breathTimers = {}
local poolIndex = 0
local function emitBreath(head, mouth)
	poolIndex = poolIndex % #bubbles + 1
	local bubble = bubbles[poolIndex]
	bubble.age, bubble.life = 0, rng:NextNumber(1.5, 2.4)
	bubble.origin = mouth
	bubble.velocity = head.CFrame.LookVector * rng:NextNumber(0.6, 1.2) + Vector3.new(0, rng:NextNumber(0.9, 1.5), 0)
	bubble.phase, bubble.size = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.11, 0.23)
end

local elapsed, accumulator, immersion = 0, 0, 0
table.insert(connections, Players.PlayerRemoving:Connect(function(other) breathTimers[other] = nil end))
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
	if not alive then return end
	elapsed += dt
	accumulator += dt
	if accumulator < 1 / 30 then return end
	local step = accumulator
	accumulator = 0
	local camera = workspace.CurrentCamera
	if not camera then return end
	local eye = camera.CFrame.Position
	local wet = map:GetAttribute("WaterBaked") and Environment.IsSubmerged(eye, 0.12)
	immersion += ((wet and 1 or 0) - immersion) * (1 - math.exp(-step * 7))
	if immersion < 0.001 then immersion = 0 end
	local depth = math.clamp(-eye.Y / 164, 0, 1)
	tint.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(188 - depth * 13, 229 - depth * 8, 240), immersion)
	tint.Brightness = -(0.025 + depth * 0.025) * immersion
	tint.Contrast, tint.Saturation = 0.04 * immersion, -0.09 * immersion
	blur.Size = (0.6 + depth * 0.5) * immersion
	veil.Enabled = immersion > 0
	for _, frame in edges do frame.BackgroundTransparency = 1 - immersion * (0.18 + math.sin(elapsed * 0.7) * 0.015) end

	for _, other in Players:GetPlayers() do
		local rig = other.Character
		local head = rig and rig:FindFirstChild("Head")
		local person = rig and rig:FindFirstChildOfClass("Humanoid")
		if head and person and person.Health > 0 and (head.Position - eye).Magnitude < 130 then
			local mouth = head.CFrame:PointToWorldSpace(Vector3.new(0, -head.Size.Y * 0.18, -head.Size.Z * 0.5 - 0.1))
			if map:GetAttribute("WaterBaked") and Environment.IsSubmerged(mouth, 0.08) then
				breathTimers[other] = (breathTimers[other] or 0) + step
				if breathTimers[other] >= 0.18 then
					breathTimers[other] = 0
					emitBreath(head, mouth)
				end
			else breathTimers[other] = 0 end
		else breathTimers[other] = nil end
	end
	for _, bubble in bubbles do
		bubble.age += step
		if bubble.age >= bubble.life then
			bubble.part.Transparency, bubble.shine.Transparency = 1, 1
			continue
		end
		local age = bubble.age
		local pos = bubble.origin + bubble.velocity * age + Vector3.new(math.sin(age * 3 + bubble.phase) * age * 0.08, age * age * 0.6, 0)
		if not Environment.IsSubmerged(pos, 0.025) then
			bubble.age = bubble.life
			bubble.part.Transparency, bubble.shine.Transparency = 1, 1
			continue
		end
		local ratio = age / bubble.life
		local size = bubble.size * (1 + ratio * 0.65)
		local opacity = math.min(age * 12, (1 - ratio) * 5, 1)
		bubble.part.Size, bubble.part.Position = Vector3.one * size, pos
		bubble.part.Transparency = 1 - opacity * 0.5
		bubble.shine.Size = Vector3.one * size * 0.22
		bubble.shine.Position = pos + Vector3.new(-size * 0.2, size * 0.22, -size * 0.3)
		bubble.shine.Transparency = 1 - opacity * 0.85
	end
end))

local function cleanup()
	if not alive then return end
	alive = false
	releaseCharacter()
	for _, connection in connections do connection:Disconnect() end
	effects:Destroy()
	tint:Destroy()
	blur:Destroy()
	veil:Destroy()
end
table.insert(connections, map.AncestryChanged:Connect(function()
	if not map:IsDescendantOf(workspace) then cleanup() end
end))
script.Destroying:Connect(cleanup)
