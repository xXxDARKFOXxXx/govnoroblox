local Rules = require("../src/shared/Rules")
local Config = require("../src/shared/Config")
local count = 0
local function check(condition, name) assert(condition, name); count += 1; print("PASS " .. name) end
check(Rules.rollTier(1, 0.01) == 3, "rare roll promotes by two tiers")
check(Rules.rollTier(5, 0) == 5, "mythic tier is capped")
check(Rules.rollTier(3, 0.3) == 3, "block rarity is guaranteed")
check(Rules.income(Config.Pets[1], "Golden", 2) == 15, "golden and rebirth income stack")
check(Rules.upgradeCost("NotAnUpgrade", 0) == nil, "unknown upgrade rejected")
check(Rules.upgradeCost("Weight", 1) > Rules.upgradeCost("Weight", 0), "upgrades grow in cost")
check(Rules.speed(0, true) < Rules.speed(0, false), "carrying slows player")
check(Rules.speed(100, false) == Rules.speed(12, false), "speed upgrade cap")
check(Rules.rebirthCost(2) == 225000, "rebirth exponential cost")
local clean = Rules.cleanProfile({Cash = 0/0, Strength = math.huge, Slots = 999, Weight = -100, Discovered = "bad", Inventory = false}, Config, 1000)
check(clean.Cash == Config.StartingCash and clean.Strength == 0, "NaN/infinity cannot poison saves")
check(clean.Slots == 10 and clean.Weight == 0, "stored upgrade values are bounded")
local raw = {Inventory = {
	{Id = "one", PetId = "mint_cat", Hatched = true, ReadyAt = 1, ReservedBy = "thief"},
	{Id = "one", PetId = "mint_cat", Hatched = true},
	{Id = "bad", PetId = "fake_pet", Hatched = true},
	{Id = "two", PetId = "phoenix", Mutation = "cheater", ReadyAt = 1e12},
}, Discovered = {mint_cat = true, fake_pet = true}}
clean = Rules.cleanProfile(raw, Config, 1000)
check(#clean.Inventory == 2, "duplicate and unknown saved pets are removed")
check(clean.Inventory[1].ReservedBy == nil, "runtime theft lock never persists")
check(clean.Inventory[2].Mutation == "Normal" and clean.Inventory[2].ReadyAt == 1060, "mutation and hatch timer validated")
check(clean.Discovered.mint_cat and not clean.Discovered.fake_pet, "discovery IDs validated")
check(Rules.cleanProfile({}, Config, 1000).Cash == 150, "new player starts with usable currency")
check(Rules.format(1534) == "1.5K", "compact currency formatting")
print("PASSED " .. count .. " rule tests")
