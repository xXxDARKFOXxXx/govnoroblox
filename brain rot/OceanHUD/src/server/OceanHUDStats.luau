-- OceanHUDStats (ModuleScript, ServerScriptService): the server-side source of
-- truth for the values the HUD shows. Only server code should call these; the
-- client HUD just reads the player attributes they write.
--
--   local Stats = require(game.ServerScriptService.OceanHUDStats)
--   Stats.addCoins(player, 250)
--   Stats.addSpeed(player, 1)      -- one more upgrade bought
local OceanHUDStats = {}

OceanHUDStats.Defaults = {Coins = 0, SpeedLevel = 0}

local function number(player: Player, name: string): number
	local value = player:GetAttribute(name)
	if type(value) == "number" and value == value then return value end
	return OceanHUDStats.Defaults[name] or 0
end

function OceanHUDStats.init(player: Player, saved: {[string]: number}?)
	saved = saved or {}
	for name, default in OceanHUDStats.Defaults do
		local value = saved[name]
		player:SetAttribute(name, if type(value) == "number" then value else default)
	end
end

function OceanHUDStats.setCoins(player: Player, amount: number)
	player:SetAttribute("Coins", math.max(0, math.floor(amount)))
end

function OceanHUDStats.addCoins(player: Player, amount: number)
	OceanHUDStats.setCoins(player, number(player, "Coins") + amount)
end

-- Upgraded speed amount (shown as a plain number in the HUD).
function OceanHUDStats.setSpeed(player: Player, amount: number)
	player:SetAttribute("SpeedLevel", math.max(0, math.floor(amount)))
end

function OceanHUDStats.addSpeed(player: Player, amount: number)
	OceanHUDStats.setSpeed(player, number(player, "SpeedLevel") + amount)
end

return OceanHUDStats
