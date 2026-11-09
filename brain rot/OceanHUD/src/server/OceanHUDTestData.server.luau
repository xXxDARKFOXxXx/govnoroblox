-- OceanHUDTestData (Script, ServerScriptService): Studio-only starting values
-- for checking the HUD. Does nothing on live servers.
-- In Studio, while playing, run in the Command Bar (Server) to see animations:
--   local S = require(game.ServerScriptService.OceanHUDStats)
--   local I = require(game.ServerScriptService.OceanInventory)
--   local p = game.Players:GetPlayers()[1]
--   S.addCoins(p, 5000)  S.addSpeed(p, 1)
--   I.add(p, "TideEgg", {Name = "Яйцо прилива", Category = "Eggs", Icon = "Egg"})
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local Stats = require(script.Parent:WaitForChild("OceanHUDStats"))
local Inventory = require(script.Parent:WaitForChild("OceanInventory"))

local function seed(player: Player)
	if player:GetAttribute("Coins") ~= nil then return end
	Stats.init(player, {Coins = 125430, SpeedLevel = 18})
	-- Sample eggs of several sections and one fish, to try the pen and its menus.
	Inventory.add(player, "TideEgg", {Name = "Яйцо прилива", Category = "Eggs", Icon = "Egg", Count = 3})
	Inventory.add(player, "CoralEgg", {Name = "Коралловое яйцо", Category = "Eggs", Icon = "Egg", Count = 2})
	Inventory.add(player, "GlacierEgg", {Name = "Ледниковое яйцо", Category = "Eggs", Icon = "Egg"})
	Inventory.add(player, "OceanCrownEgg", {Name = "Яйцо Короны океана", Category = "Eggs", Icon = "Egg"})
	Inventory.add(player, "Fish_Clown_L3", {Name = "Рыба-клоун · ур. 3", Category = "Fish", Icon = "SharkFin",
		Data = {FishType = "Clown", Level = 3}})
	Inventory.setHotbar(player, "TideEgg", 1)
	Inventory.setHotbar(player, "Fish_Clown_L3", 2)
end
Players.PlayerAdded:Connect(seed)
for _, player in Players:GetPlayers() do seed(player) end
