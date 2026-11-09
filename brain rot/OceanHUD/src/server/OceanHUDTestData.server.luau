-- OceanHUDTestData (Script, ServerScriptService): Studio-only starting values
-- for checking the HUD. Does nothing on live servers.
-- In Studio, while playing, run in the Command Bar (Server) to see animations:
--   local S = require(game.ServerScriptService.OceanHUDStats)
--   local I = require(game.ServerScriptService.OceanInventory)
--   local p = game.Players:GetPlayers()[1]
--   S.addCoins(p, 5000)  S.addSpeed(p, 1)
--   I.add(p, "BasicEgg", {Name = "Обычное яйцо", Category = "Eggs", Icon = "Egg"})
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local Stats = require(script.Parent:WaitForChild("OceanHUDStats"))
local Inventory = require(script.Parent:WaitForChild("OceanInventory"))

local function seed(player: Player)
	if player:GetAttribute("Coins") ~= nil then return end
	Stats.init(player, {Coins = 125430, SpeedLevel = 18})
	-- A few sample items so the inventory grid and hotbar can be checked.
	Inventory.add(player, "BasicEgg", {Name = "Обычное яйцо", Category = "Eggs", Icon = "Egg", Count = 3})
	Inventory.add(player, "Shark", {Name = "Акула", Category = "Fish", Icon = "SharkFin"})
	Inventory.add(player, "GoldEgg", {Name = "Золотое яйцо", Category = "Eggs", Icon = "Egg"})
	Inventory.add(player, "StarEgg", {Name = "Звёздное яйцо", Category = "Eggs", Icon = "Egg", Count = 2})
	Inventory.add(player, "OceanEgg", {Name = "Морское яйцо", Category = "Eggs", Icon = "Egg"})
	Inventory.setHotbar(player, "Shark", 1)
	Inventory.setHotbar(player, "GoldEgg", 2)
end
Players.PlayerAdded:Connect(seed)
for _, player in Players:GetPlayers() do seed(player) end
