-- OceanBases (Script in ServerScriptService.OceanBases): starts the base systems.
-- Bases are prebuilt in Workspace.OceanBases by the build (visible in Studio);
-- if they are missing (e.g. the scripts were inserted into another place),
-- they are built here. Locked upgrade floors live in ServerStorage.OceanBasesLocked.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local folder = script.Parent
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))
local Builder = require(folder:WaitForChild("BaseBuilder"))
local Ownership = require(folder:WaitForChild("BaseOwnershipService"))
local Pens = require(folder:WaitForChild("FishPenController"))
local Upgrades = require(folder:WaitForChild("BaseUpgradeService"))

local basesFolder = workspace:FindFirstChild("OceanBases")
local locked = ServerStorage:FindFirstChild("OceanBasesLocked")
if not basesFolder then
	basesFolder = Instance.new("Folder")
	basesFolder.Name = "OceanBases"
	locked = Instance.new("Folder")
	locked.Name = "OceanBasesLocked"
	locked.Parent = ServerStorage
	for id = 1, Config.BaseCount do
		local origin = Builder.origin(id)
		Builder.build(basesFolder, id, origin, Config.StartFloors)
		local store = Instance.new("Folder")
		store.Name = "Base" .. id
		store.Parent = locked
		for k = Config.StartFloors + 1, Config.MaxFloors do
			Builder.buildFloor(store, origin, k)
		end
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

Pens.init(bases, locked)
Upgrades.init(bases, locked)
Ownership.init(bases)
