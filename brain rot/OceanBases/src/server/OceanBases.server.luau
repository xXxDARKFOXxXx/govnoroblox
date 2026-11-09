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
local Seabed = require(folder:WaitForChild("SeabedBuilder"))
local Nests = require(folder:WaitForChild("NestService"))
local Predators = require(folder:WaitForChild("PredatorService"))
local SwimSpeed = require(folder:WaitForChild("SwimSpeedService"))
local Held = require(folder:WaitForChild("HeldItemService"))

local basesFolder = workspace:FindFirstChild("OceanBases")
if not basesFolder then
	basesFolder = Instance.new("Folder")
	basesFolder.Name = "OceanBases"
	for id = 1, Config.BaseCount do
		Builder.build(basesFolder, id, Builder.origin(id), 0)
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

-- Click on the yard floor while holding an egg or a fish: put it there.
local placeItem = remotes:FindFirstChild("PlaceItem") or Instance.new("RemoteEvent")
placeItem.Name = "PlaceItem"
placeItem.Parent = remotes
local lastPlace = {}
placeItem.OnServerEvent:Connect(function(player, position)
	local t = os.clock()
	if lastPlace[player] and t - lastPlace[player] < 0.25 then return end -- rate limit
	lastPlace[player] = t
	Pens.placeAt(player, position)
end)
game:GetService("Players").PlayerRemoving:Connect(function(player) lastPlace[player] = nil end)

-- Pen actions from the HUD menus (validated on the server).
local penAction = remotes:FindFirstChild("PenAction") or Instance.new("RemoteEvent")
penAction.Name = "PenAction"
penAction.Parent = remotes
penAction.OnServerEvent:Connect(function(player, action, index)
	Pens.action(player, action, index)
end)

-- Messages to one player (toasts) and the knock-back push when caught.
local notifyRemote = remotes:FindFirstChild("Notify") or Instance.new("RemoteEvent")
notifyRemote.Name = "Notify"
notifyRemote.Parent = remotes
Nests.notify = function(player, text, kind)
	notifyRemote:FireClient(player, {text = text, kind = kind})
end
Pens.notify = Nests.notify
Predators.knock = function(player, velocity)
	notifyRemote:FireClient(player, {knock = velocity})
end

-- Seabed (relief, rocks, nests) is baked by the build; build it if missing.
local seabed = workspace:FindFirstChild("OceanSeabed") or Seabed.build(workspace)

Pens.init(bases)
Upgrades.init(bases)

-- Studio only: a ready-made pen (5 fish of different levels and 2 eggs) so the
-- models and the Рыбы / Яйца menus can be seen right away in a play test.
if game:GetService("RunService"):IsStudio() then
	table.insert(Ownership.onAssigned, function(_, base)
		if #Pens.cells(base) > 0 then return end
		local origin = base.PrimaryPart.CFrame
		for _, data in {{"RegalTang", 1}, {"Salmon", 3}, {"SeaTurtle", 2}, {"Lobster", 5}, {"Butterflyfish", 1}} do
			local cell = Pens.createCell(base, origin:PointToWorldSpace(Vector3.new(0, Config.FloorTop, 20)))
			cell:SetAttribute("EggType", "TideEgg")
			Pens.hatch(cell, data[1])
			cell:SetAttribute("FishLevel", data[2])
			cell:SetAttribute("Income", Config.fishIncome(data[1], data[2]))
			Pens.refreshCell(cell)
		end
		for i, eggType in {"CoralEgg", "OceanCrownEgg"} do
			local spot = Pens.spotFor(base, origin:PointToWorldSpace(Vector3.new(-12 + (i - 1) * 24, Config.FloorTop, 26)))
			if spot then Pens.setEgg(Pens.createCell(base, spot), eggType) end
		end
		Pens.updateIncome(base)
	end)
end

Ownership.init(bases)
Nests.init(seabed)
Predators.init(seabed)
SwimSpeed.init()
Held.init()
