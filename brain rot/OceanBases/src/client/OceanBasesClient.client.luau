-- OceanBasesClient (LocalScript in StarterPlayerScripts, with child modules
-- FishAnimationController and BaseVisualEffects).
-- * Animates fish, eggs and water.
-- * Shows the expansion prompt only to the base owner (the server checks rights).
-- * Tells the server which inventory item is picked in the HUD (held in hands).
-- * Clicking the yard floor puts the held egg / fish there (PlacementController).
-- * Arm poses: egg over the head while carrying, item in front (CarryPoseController).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FishAnimation = require(script:WaitForChild("FishAnimationController"))
local Effects = require(script:WaitForChild("BaseVisualEffects"))
local Placement = require(script:WaitForChild("PlacementController"))
local CarryPose = require(script:WaitForChild("CarryPoseController"))

local player = Players.LocalPlayer
local basesFolder = workspace:WaitForChild("OceanBases")

FishAnimation.start()
Effects.start(basesFolder)
CarryPose.start()
task.spawn(Placement.start)

-- Owner-only prompts: the upgrade board.
local OWNER_ONLY = {UpgradePrompt = true}
local function baseOf(instance: Instance): Model?
	local node = instance
	while node and not (node:IsA("Model") and node:GetAttribute("BaseId")) do node = node.Parent end
	return node
end
local function apply(prompt: ProximityPrompt)
	local active = prompt:GetAttribute("Active")
	local enabled = active ~= false
	if OWNER_ONLY[prompt.Name] then
		local base = baseOf(prompt)
		enabled = enabled and base ~= nil and base:GetAttribute("OwnerUserId") == player.UserId
	end
	prompt.Enabled = enabled
end
local function bind(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") or prompt:GetAttribute("ClientBound") then return end
	prompt:SetAttribute("ClientBound", true)
	prompt:GetAttributeChangedSignal("Active"):Connect(function() apply(prompt) end)
	apply(prompt)
end
for _, object in basesFolder:GetDescendants() do bind(object) end
basesFolder.DescendantAdded:Connect(function(object)
	if object:IsA("ProximityPrompt") then task.defer(bind, object) end
end)
for _, base in basesFolder:GetChildren() do
	base:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		for _, object in base:GetDescendants() do
			if object:IsA("ProximityPrompt") then apply(object) end
		end
	end)
end

-- Toasts from the server (egg taken / delivered / stolen back) and the push
-- a predator gives when it catches you.
local toastGui = Instance.new("ScreenGui")
toastGui.Name = "OceanToasts"
toastGui.ResetOnSpawn = false
toastGui.DisplayOrder = 40
toastGui.Parent = player:WaitForChild("PlayerGui")
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 70)
toast.Size = UDim2.fromOffset(620, 54)
toast.BackgroundColor3 = Color3.fromRGB(20, 26, 40)
toast.BackgroundTransparency = 0.2
toast.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
toast.TextScaled = true
toast.TextColor3 = Color3.new(1, 1, 1)
toast.TextStrokeTransparency = 0.3
toast.Visible = false
toast.Parent = toastGui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = toast
local stroke = Instance.new("UIStroke")
stroke.Thickness = 3
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = toast
local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 16)
padding.PaddingRight = UDim.new(0, 16)
padding.PaddingTop = UDim.new(0, 6)
padding.PaddingBottom = UDim.new(0, 6)
padding.Parent = toast
local TOAST_COLORS = {good = Color3.fromRGB(110, 230, 120), bad = Color3.fromRGB(255, 90, 90), warn = Color3.fromRGB(255, 200, 60)}
local toastToken = 0
local function showToast(text: string, kind: string?)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	stroke.Color = TOAST_COLORS[kind or ""] or Color3.fromRGB(110, 200, 255)
	toast.Visible = true
	task.delay(3.5, function()
		if toastToken == token then toast.Visible = false end
	end)
end
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("Remotes", 30)
	local notify = remotes and remotes:WaitForChild("Notify", 30)
	if not notify then return end
	notify.OnClientEvent:Connect(function(message)
		if type(message) ~= "table" then return end
		if type(message.text) == "string" then showToast(message.text, message.kind) end
		if typeof(message.knock) == "Vector3" then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then root.AssemblyLinearVelocity = message.knock end
		end
	end)
end)

-- Item picked in the HUD (hotbar slot or inventory card) → server: it goes into the hands.
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("Remotes", 30)
	local selectItem = remotes and remotes:WaitForChild("SelectItem", 30)
	local hud = player:WaitForChild("PlayerGui"):WaitForChild("OceanHUD", 30)
	local safe = hud and hud:WaitForChild("SafeArea", 10)
	local selected = safe and safe:WaitForChild("HotbarSelected", 10)
	if selectItem and selected then
		selected.Event:Connect(function(_, itemId)
			selectItem:FireServer(itemId)
		end)
	end
end)
