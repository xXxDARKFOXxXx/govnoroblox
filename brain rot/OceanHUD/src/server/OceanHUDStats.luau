-- OceanHUDStats (ModuleScript, ServerScriptService): the server-side source of
-- truth for the values the HUD shows. Only server code should call these; the
-- client HUD just reads the player attributes they write.
--
--   local Stats = require(game.ServerScriptService.OceanHUDStats)
--   Stats.addCoins(player, 250)
--   Stats.addXP(player, 1200)       -- carries leftover XP into the next level(s)
--   Stats.setSpeedLevel(player, 19)
local OceanHUDStats = {}

OceanHUDStats.Defaults = {Coins = 0, SpeedLevel = 1, Level = 1, XP = 0}
OceanHUDStats.MaxLevel = 999

-- XP needed to go from `level` to `level + 1` (level 24 -> 10,000 XP).
function OceanHUDStats.required(level: number): number
	if level >= OceanHUDStats.MaxLevel then return 0 end
	return 1000 + level * 375
end

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
	player:SetAttribute("XPRequired", OceanHUDStats.required(number(player, "Level")))
end

function OceanHUDStats.setCoins(player: Player, amount: number)
	player:SetAttribute("Coins", math.max(0, math.floor(amount)))
end

function OceanHUDStats.addCoins(player: Player, amount: number)
	OceanHUDStats.setCoins(player, number(player, "Coins") + amount)
end

function OceanHUDStats.setSpeedLevel(player: Player, level: number)
	player:SetAttribute("SpeedLevel", math.max(1, math.floor(level)))
end

function OceanHUDStats.setLevel(player: Player, level: number, xp: number?)
	level = math.clamp(math.floor(level), 1, OceanHUDStats.MaxLevel)
	player:SetAttribute("Level", level)
	player:SetAttribute("XPRequired", OceanHUDStats.required(level))
	player:SetAttribute("XP", math.max(0, math.floor(xp or 0)))
end

function OceanHUDStats.addXP(player: Player, amount: number)
	local level = number(player, "Level")
	local xp = number(player, "XP") + math.max(0, amount)
	local required = OceanHUDStats.required(level)
	while required > 0 and xp >= required do
		xp -= required
		level += 1
		required = OceanHUDStats.required(level)
	end
	if required == 0 then xp = 0 end
	-- Level is written before XP so the HUD plays the level-up and carries progress over.
	player:SetAttribute("Level", level)
	player:SetAttribute("XPRequired", required)
	player:SetAttribute("XP", math.floor(xp))
end

return OceanHUDStats
