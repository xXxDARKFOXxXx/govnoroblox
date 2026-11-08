-- Pure rules, also executed by the command-line test suite.
local Rules = {}

function Rules.finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function Rules.clampNumber(value, fallback, low, high)
	if not Rules.finite(value) then return fallback end
	return math.clamp(value, low, high)
end

function Rules.upgradeCost(kind, level)
	local prices = {Weight = {100, 1.75}, Speed = {180, 1.85}, Slots = {500, 2.4}}
	local entry = prices[kind]
	if not entry then return nil end
	return math.floor(entry[1] * entry[2] ^ level)
end

function Rules.rebirthCost(count)
	return math.floor(25000 * 3 ^ count)
end

function Rules.multiplier(rebirths)
	return 1 + rebirths * 0.5
end

function Rules.speed(level, carrying)
	return (carrying and 17 or 23) + math.min(level, 12) * 1.5
end

function Rules.rollTier(blockTier, roll)
	-- Better blocks guarantee their rarity; 16% chance of +1, 2% chance of +2.
	local bonus = if roll < 0.02 then 2 elseif roll < 0.18 then 1 else 0
	return math.min(5, blockTier + bonus)
end

function Rules.income(pet, mutation, rebirths)
	return math.floor(pet.Income * (if mutation == "Golden" then 2.5 else 1) * Rules.multiplier(rebirths))
end

function Rules.findPet(config, id)
	for _, pet in ipairs(config.Pets) do
		if pet.Id == id then return pet end
	end
	return nil
end

function Rules.cleanProfile(raw, config, now)
	raw = if type(raw) == "table" then raw else {}
	local data = {
		Version = config.Version,
		Cash = Rules.clampNumber(raw.Cash, config.StartingCash, 0, config.MaxCash),
		Strength = math.floor(Rules.clampNumber(raw.Strength, 0, 0, config.MaxStrength)),
		Weight = math.floor(Rules.clampNumber(raw.Weight, 0, 0, 12)),
		Speed = math.floor(Rules.clampNumber(raw.Speed, 0, 0, 12)),
		Slots = math.floor(Rules.clampNumber(raw.Slots, config.BaseSlots, config.BaseSlots, config.MaxSlots)),
		Rebirths = math.floor(Rules.clampNumber(raw.Rebirths, 0, 0, 15)),
		Bank = Rules.clampNumber(raw.Bank, 0, 0, config.MaxCash),
		LastSeen = Rules.clampNumber(raw.LastSeen, now, 0, now),
		Hatched = math.floor(Rules.clampNumber(raw.Hatched, 0, 0, 1e9)),
		Tutorial = math.floor(Rules.clampNumber(raw.Tutorial, 0, 0, 4)),
		Inventory = {},
		Discovered = {},
	}
	if type(raw.Inventory) == "table" then
		local seen = {}
		for _, item in ipairs(raw.Inventory) do
			if #data.Inventory >= data.Slots then break end
			if type(item) == "table" and type(item.Id) == "string" and #item.Id <= 80 and not seen[item.Id] then
				local pet = Rules.findPet(config, item.PetId)
				if pet then
					seen[item.Id] = true
					table.insert(data.Inventory, {
						Id = item.Id, PetId = pet.Id, Tier = pet.Tier,
						Mutation = if item.Mutation == "Golden" then "Golden" else "Normal",
						ReadyAt = Rules.clampNumber(item.ReadyAt, now, 0, now + 60),
						Hatched = item.Hatched == true,
					})
				end
			end
		end
	end
	if type(raw.Discovered) == "table" then
		for _, pet in ipairs(config.Pets) do
			if raw.Discovered[pet.Id] == true then data.Discovered[pet.Id] = true end
		end
	end
	return data
end

function Rules.format(number)
	if number >= 1e9 then return string.format("%.1fB", number / 1e9) end
	if number >= 1e6 then return string.format("%.1fM", number / 1e6) end
	if number >= 1e3 then return string.format("%.1fK", number / 1e3) end
	return tostring(math.floor(number))
end

return Rules
