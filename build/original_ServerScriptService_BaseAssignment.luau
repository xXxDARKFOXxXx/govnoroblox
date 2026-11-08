local Players = game:GetService("Players")

local map = workspace:FindFirstChild("StealAnEggMap")
if not map then
	warn("StealAnEggMap not found in workspace!")
	return
end

-- Collect the 5 bases and track ownership
local bases = {}
local baseOwners = {} -- [player] = baseModel

for i = 1, 5 do
	local base = map:FindFirstChild("Base" .. i)
	if base then
		table.insert(bases, base)
	end
end

if #bases == 0 then
	warn("No bases found in StealAnEggMap!")
	return
end

-- Creates (or updates) a floating label above a base: round avatar + player name
local function setNameLabel(base, player)
	local existing = base:FindFirstChild("NameLabel")
	if existing then
		existing:Destroy()
	end
	if not player then return end

	local label = Instance.new("Part")
	label.Name = "NameLabel"
	label.Size = Vector3.new(8, 2, 0.5)
	label.Anchored = true
	label.CanCollide = false
	label.Transparency = 1
	label.CFrame = CFrame.new(base:GetPivot().Position.X, 25, base:GetPivot().Position.Z)
	label.Parent = base

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 200, 0, 160)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.MaxDistance = 200
	gui.AlwaysOnTop = false
	gui.Parent = label

	-- Round avatar circle above the name
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.Size = UDim2.new(0, 80, 0, 80)
	avatar.Position = UDim2.new(0.5, 0, 0, 0)
	avatar.AnchorPoint = Vector2.new(0.5, 0)
	avatar.BackgroundTransparency = 1
	avatar.ScaleType = Enum.ScaleType.Crop
	avatar.Parent = gui

	-- White ring around the avatar
	local ring = Instance.new("UICorner")
	ring.CornerRadius = UDim.new(1, 0)
	ring.Parent = avatar

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Thickness = 4
	uiStroke.Color = Color3.fromRGB(255, 255, 255)
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	uiStroke.Parent = avatar

	-- Player name below the avatar
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 0, 60)
	text.Position = UDim2.new(0, 0, 0, 90)
	text.BackgroundTransparency = 1
	text.Text = player.Name
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.TextStrokeTransparency = 0.5
	text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	text.Parent = gui

	-- Fetch the player's avatar headshot thumbnail
	task.spawn(function()
		local ok, thumb = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100
			)
		end)
		if ok and thumb and label.Parent then
			avatar.Image = thumb
		end
	end)
end

-- Find the first base that is not owned by anyone
local function getFreeBase()
	for _, base in ipairs(bases) do
		local taken = false
		for _, ownerBase in pairs(baseOwners) do
			if ownerBase == base then
				taken = true
				break
			end
		end
		if not taken then
			return base
		end
	end
	return nil
end

local function assignBase(player)
	-- Skip if this player already has a base
	if baseOwners[player] then return end

	local base = getFreeBase()
	if base then
		baseOwners[player] = base
		setNameLabel(base, player)
		print(player.Name .. " got " .. base.Name)
	else
		print("No free bases left for " .. player.Name)
	end
end

local function releaseBase(player)
	local base = baseOwners[player]
	if base then
		setNameLabel(base, nil) -- remove the name label
		baseOwners[player] = nil
	end
end

Players.PlayerAdded:Connect(assignBase)
Players.PlayerRemoving:Connect(releaseBase)

-- Handle players already in the game (e.g. when script starts late)
for _, player in ipairs(Players:GetPlayers()) do
	assignBase(player)
end