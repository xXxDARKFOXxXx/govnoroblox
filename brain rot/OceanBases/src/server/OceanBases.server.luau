-- OceanBases (Script in ServerScriptService.OceanBases): starts the base systems.
-- Bases are prebuilt in Workspace.OceanBases by the build (visible in Studio);
-- if they are missing (e.g. the scripts were inserted into another place),
-- they are built here at the starting size.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = script.Parent
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))
local Builder = require(folder:WaitForChild("BaseBuilder"))
local Ownership = require(folder:WaitForChild("BaseOwnershipService"))
local Pens = require(folder:WaitForChild("FishPenController"))
local Upgrades = require(folder:WaitForChild("BaseUpgradeService"))

local basesFolder = workspace:FindFirstChild("OceanBases")
if not basesFolder then
	basesFolder = Instance.new("Folder")
	basesFolder.Name = "OceanBases"
	for id = 1, Config.BaseCount do
		Builder.build(basesFolder, id, Builder.origin(id), Config.StartRows)
	end
	basesFolder.Parent = workspace
end

local bases = {}
for _, base in basesFolder:GetChildren() do
	if base:IsA("Model") and base:GetAttribute("BaseId") then table.insert(bases, base) end
end
table.sort(bases, function(a, b) return a:GetAttribute("BaseId") < b:GetAttribute("BaseId") end)

-- Remote: the client reports which inventory item is in the hand (hotbar).
local shared = ReplicatedStorage:WaitForChild("OceanBases")
local remotes = shared:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = shared
local selectItem = remotes:FindFirstChild("SelectItem") or Instance.new("RemoteEvent")
selectItem.Name = "SelectItem"
selectItem.Parent = remotes
selectItem.OnServerEvent:Connect(function(player, itemId)
	if itemId == nil then
		player:SetAttribute("HeldItem", nil)
		return
	end
	if type(itemId) ~= "string" or #itemId > 64 then return end
	local inventory = player:FindFirstChild("Inventory")
	if inventory and inventory:FindFirstChild(itemId) then
		player:SetAttribute("HeldItem", itemId)
	end
end)

Pens.init(bases)
Upgrades.init(bases)
Ownership.init(bases)
