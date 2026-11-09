-- OceanBasesClient (LocalScript in StarterPlayerScripts, with child modules
-- FishAnimationController and BaseVisualEffects).
-- * Animates fish, eggs and water.
-- * Shows base prompts only to the base owner (the server still checks rights).
-- * Tells the server which inventory item is selected in the HUD hotbar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FishAnimation = require(script:WaitForChild("FishAnimationController"))
local Effects = require(script:WaitForChild("BaseVisualEffects"))

local player = Players.LocalPlayer
local basesFolder = workspace:WaitForChild("OceanBases")

FishAnimation.start()
Effects.start(basesFolder)

-- Owner-only prompts: cells and the expansion board.
local OWNER_ONLY = {CellPrompt = true, UpgradePrompt = true}
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

-- Hotbar selection from the HUD → server (to know which egg is in the hand).
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
