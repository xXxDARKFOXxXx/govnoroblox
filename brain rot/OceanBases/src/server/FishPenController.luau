-- FishPenController (server): what lives in a yard — eggs put anywhere on the
-- floor, hatching, fish, and fish income paid straight into the owner's coins.
-- There is no grid: the owner holds an egg (or a fish) from the inventory and
-- clicks a spot of the yard floor (remote PlaceItem). The server checks the
-- owner, the spot (inside the pool, not too close to another egg) and the
-- base capacity (10 + base level). Each egg / fish gets a "place" (CellN).
--
-- Place attributes: Index, State ("Egg" | "Fish"), EggType, HatchAt (server
-- time), FishType, FishLevel, Income. Base attributes: Income (coins per
-- second), Capacity. Pen actions (HUD menus): remove a fish to the inventory,
-- upgrade a fish (cost grows with the level), delete an egg.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))
local Ownership = require(script.Parent:WaitForChild("BaseOwnershipService"))
local Creatures = require(script.Parent:WaitForChild("CreatureModels"))
local CellBuilder = require(script.Parent:WaitForChild("CellBuilder"))

local FishPenController = {}
FishPenController.random = Random.new()
FishPenController.notify = nil -- function(player, text, kind)

local Stats, Inventory
local remainder = {} -- [base] = fractional coins not paid yet

local function optional(name)
	local module = ServerScriptService:FindFirstChild(name)
	return module and require(module) or nil
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function format(value: number): string
	local text = string.format("%d", math.floor(value))
	local result = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (result:gsub("^,", ""))
end

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

---------------------------------------------------------------- cells
function FishPenController.cells(base: Model): {Model}
	local list = {}
	local folder = base:FindFirstChild("Cells")
	if folder then
		for _, cell in folder:GetChildren() do table.insert(list, cell) end
	end
	table.sort(list, function(a, b) return a:GetAttribute("Index") < b:GetAttribute("Index") end)
	return list
end

function FishPenController.refreshCell(cell: Model)
	local point = cell.InteractionPoint
	local gui = point.CellInfo
	local state = cell:GetAttribute("State")
	if state == "Egg" then
		local egg = Config.Eggs[cell:GetAttribute("EggType")]
		gui.Title.Text = egg and egg.name or "Яйцо"
		gui.Title.TextColor3 = Config.Colors.White
		gui.Line.Text = "Вылупится через " .. clock((cell:GetAttribute("HatchAt") or 0) - now())
		gui.Enabled = true
	elseif state == "Fish" then
		local fish = Config.Fish[cell:GetAttribute("FishType")]
		gui.Title.Text = fish and fish.name or "Рыба"
		gui.Title.TextColor3 = fish and Config.RarityColors[fish.rarity] or Config.Colors.White
		gui.Line.Text = "Ур. " .. (cell:GetAttribute("FishLevel") or 1) .. " · +" .. format(cell:GetAttribute("Income") or 0) .. " / сек"
		gui.Enabled = true
	else
		gui.Enabled = false
	end
end

-- Removes a place (its egg or fish goes away with it).
function FishPenController.clearCell(cell: Model)
	local base = Ownership.baseFrom(cell)
	cell:Destroy()
	if base then FishPenController.updateIncome(base) end
end

---------------------------------------------------------------- places
function FishPenController.capacity(base: Model): number
	return base:GetAttribute("Capacity") or Config.StartCapacity
end

local function nextIndex(base: Model): number
	local used = {}
	for _, cell in FishPenController.cells(base) do used[cell:GetAttribute("Index")] = true end
	local i = 1
	while used[i] do i += 1 end
	return i
end

-- World point on the yard floor under `position`, or nil + reason when an
-- egg cannot go there: base full, outside the pool, too close to an egg.
function FishPenController.spotFor(base: Model, position: Vector3): (Vector3?, string?)
	if #FishPenController.cells(base) >= FishPenController.capacity(base) then return nil, "full" end
	local origin = base.PrimaryPart.CFrame
	local lp = origin:PointToObjectSpace(position)
	local depth = base:GetAttribute("YardDepth") or Config.depth(1)
	if not Config.insideYard(lp.X, lp.Z, depth) then return nil, "outside" end
	local spot = origin:PointToWorldSpace(Vector3.new(lp.X, Config.FloorTop, lp.Z))
	for _, cell in FishPenController.cells(base) do
		if cell:GetAttribute("State") == "Egg" then
			local other = cell.EggPlacement.CFrame.Position
			if Vector2.new(other.X - spot.X, other.Z - spot.Z).Magnitude < Config.PlaceSpacing then return nil, "busy" end
		end
	end
	return spot, nil
end

-- A new empty place at a floor point (no checks: see spotFor / placeAt).
function FishPenController.createCell(base: Model, spot: Vector3): Model
	local cells = base:FindFirstChild("Cells")
	if not cells then
		cells = Instance.new("Folder")
		cells.Name = "Cells"
		cells.Parent = base
	end
	return CellBuilder.build(cells, spot, nextIndex(base))
end

-- Fish fly in the air above the pool water, each on its own oval and height,
-- so a full yard of fish spreads over the whole pool instead of piling up.
local function spawnFish(cell: Model, fishType: string)
	local base = Ownership.baseFrom(cell)
	local zone = base and base:FindFirstChild("Pool") and base.Pool:FindFirstChild("FishZone")
	local rng = FishPenController.random
	local waterY, center, rx, rz
	if zone then
		waterY = zone.CFrame.Position.Y
		local low, high = Config.FishFlyHeight[1], Config.FishFlyHeight[2]
		center = zone.CFrame.Position + Vector3.new(0, low + rng:NextNumber() * (high - low), 0)
		rx = 3 + rng:NextNumber() * (zone.Size.X / 2 - 4)
		rz = 1.5 + rng:NextNumber() * (zone.Size.Z / 2 - 2)
	else
		-- No pool (custom place): hover over the cell instead.
		waterY = cell.EggPlacement.CFrame.Position.Y
		center = cell.EggPlacement.CFrame.Position + Vector3.new(0, 3.2, 0)
		rx, rz = 1.8, 1.8
	end
	local phase = rng:NextNumber() * math.pi * 2
	local start = center + Vector3.new(math.cos(phase) * rx, 0, math.sin(phase) * rz)
	local fish = Creatures.fish(cell.Content, fishType, CFrame.new(start))
	-- Flight path for the client animation.
	fish:SetAttribute("Center", center)
	fish:SetAttribute("FloorY", waterY)
	fish:SetAttribute("RadiusX", rx)
	fish:SetAttribute("RadiusZ", rz)
	fish:SetAttribute("Phase", phase)
	fish:SetAttribute("Speed", Config.FishSwimSpeed * (0.8 + rng:NextNumber() * 0.4) * (rng:NextNumber() < 0.5 and -1 or 1))
	-- The name / level / income label flies with the fish.
	local gui = cell.InteractionPoint.CellInfo
	gui.Adornee = fish.PrimaryPart
	local info = Config.Fish[fishType]
	gui.StudsOffset = Vector3.new(0, (info and info.length or 4) * 0.35 + 1.5, 0)
	return fish
end

function FishPenController.updateIncome(base: Model)
	local total = 0
	for _, cell in FishPenController.cells(base) do
		if cell:GetAttribute("State") == "Fish" then total += cell:GetAttribute("Income") or 0 end
	end
	base:SetAttribute("Income", total)
	return total
end

local function setFish(cell: Model, fishType: string, level: number)
	cell.Content:ClearAllChildren()
	cell:SetAttribute("State", "Fish")
	cell:SetAttribute("FishType", fishType)
	cell:SetAttribute("FishLevel", level)
	cell:SetAttribute("Income", Config.fishIncome(fishType, level))
	cell:SetAttribute("EggType", nil)
	cell:SetAttribute("HatchAt", nil)
	spawnFish(cell, fishType)
	FishPenController.refreshCell(cell)
	local base = Ownership.baseFrom(cell)
	if base then FishPenController.updateIncome(base) end
end

function FishPenController.hatch(cell: Model, fishType: string?)
	fishType = fishType or Creatures.rollFish(cell:GetAttribute("EggType"), FishPenController.random)
	setFish(cell, fishType, 1)
end

-- The egg in the player's hand (selected hotbar slot) first, otherwise any egg.
function FishPenController.chooseEgg(player: Player): string?
	if not Inventory then return nil end
	local held = player:GetAttribute("HeldItem")
	if type(held) == "string" and Config.Eggs[held] and Inventory.count(player, held) > 0 then
		return held
	end
	for _, eggType in Config.EggOrder do
		if Inventory.count(player, eggType) > 0 then return eggType end
	end
	return nil
end

-- Inventory id of a fish with a level ("Fish_Clown_L3").
function FishPenController.fishItemId(fishType: string, level: number): string
	return string.format("Fish_%s_L%d", fishType, level)
end

local function fishItem(player: Player, itemId: string)
	local folder = player:FindFirstChild("Inventory")
	local item = folder and folder:FindFirstChild(itemId)
	if item and item:GetAttribute("Category") == "Fish" and Config.Fish[item:GetAttribute("FishType")] then return item end
	return nil
end

-- After the last one of the held item is used, the hand is empty.
local function releaseHand(player: Player, itemId: string)
	if Inventory and Inventory.count(player, itemId) <= 0 and player:GetAttribute("HeldItem") == itemId then
		player:SetAttribute("HeldItem", nil)
	end
end

-- Puts a fish from the inventory into the yard (keeps its level).
function FishPenController.placeFish(player: Player, cell: Model, itemId: string): boolean
	local base = Ownership.baseFrom(cell)
	if not Ownership.isOwner(player, base) or cell:GetAttribute("State") ~= "Empty" then return false end
	local item = fishItem(player, itemId)
	if not item or not Inventory then return false end
	local fishType, level = item:GetAttribute("FishType"), item:GetAttribute("Level") or 1
	if not Inventory.remove(player, itemId, 1) then return false end
	setFish(cell, fishType, math.clamp(math.floor(level), 1, Config.MaxFishLevel))
	releaseHand(player, itemId)
	return true
end

-- Server-validated: put the held item (egg or fish; else any egg) on the yard
-- floor at `position` (from the client's click). Returns true when placed.
function FishPenController.placeAt(player: Player, position: any): boolean
	if typeof(position) ~= "Vector3" or position.X ~= position.X or position.Z ~= position.Z then return false end
	local base = Ownership.baseOf(player)
	if not base then return false end
	local held = player:GetAttribute("HeldItem")
	local isFish = type(held) == "string" and fishItem(player, held) ~= nil
	if not isFish and not FishPenController.chooseEgg(player) then return false end
	local spot, reason = FishPenController.spotFor(base, position)
	if not spot then
		if FishPenController.notify then
			local text = reason == "full" and "База заполнена! Улучши её, чтобы ставить больше рыб."
				or reason == "busy" and "Слишком близко к другому яйцу."
				or "Ставь внутри своего вольера."
			FishPenController.notify(player, text, "bad")
		end
		return false
	end
	local cell = FishPenController.createCell(base, spot)
	local ok
	if isFish then
		ok = FishPenController.placeFish(player, cell, held)
	else
		ok = FishPenController.placeEgg(player, cell)
	end
	if not ok then cell:Destroy() end
	return ok
end

---------------------------------------------------------------- pen actions (HUD menus)
local function ownCell(player: Player, index: any): Model?
	if type(index) ~= "number" then return nil end
	local base = Ownership.baseOf(player)
	if not base then return nil end
	for _, cell in FishPenController.cells(base) do
		if cell:GetAttribute("Index") == index then return cell end
	end
	return nil
end

function FishPenController.removeFish(player: Player, index: number): boolean
	local cell = ownCell(player, index)
	if not cell or cell:GetAttribute("State") ~= "Fish" or not Inventory then return false end
	local fishType, level = cell:GetAttribute("FishType"), cell:GetAttribute("FishLevel") or 1
	local info = Config.Fish[fishType]
	Inventory.add(player, FishPenController.fishItemId(fishType, level), {
		Name = info.name .. " · ур. " .. level, Category = "Fish", Icon = "SharkFin",
		Data = {FishType = fishType, Level = level},
	})
	FishPenController.clearCell(cell)
	return true
end

function FishPenController.upgradeFish(player: Player, index: number): boolean
	local cell = ownCell(player, index)
	if not cell or cell:GetAttribute("State") ~= "Fish" then return false end
	local fishType, level = cell:GetAttribute("FishType"), cell:GetAttribute("FishLevel") or 1
	if level >= Config.MaxFishLevel then return false end
	local cost = Config.upgradeCost(fishType, level)
	local coins = player:GetAttribute("Coins") or 0
	if coins < cost then return false end
	if Stats then Stats.addCoins(player, -cost) else player:SetAttribute("Coins", coins - cost) end
	cell:SetAttribute("FishLevel", level + 1)
	cell:SetAttribute("Income", Config.fishIncome(fishType, level + 1))
	FishPenController.refreshCell(cell)
	FishPenController.updateIncome(Ownership.baseOf(player))
	return true
end

function FishPenController.deleteEgg(player: Player, index: number): boolean
	local cell = ownCell(player, index)
	if not cell or cell:GetAttribute("State") ~= "Egg" then return false end
	FishPenController.clearCell(cell)
	return true
end

function FishPenController.action(player: Player, action: any, index: any): boolean
	if action == "RemoveFish" then return FishPenController.removeFish(player, index) end
	if action == "UpgradeFish" then return FishPenController.upgradeFish(player, index) end
	if action == "DeleteEgg" then return FishPenController.deleteEgg(player, index) end
	return false
end

-- An egg as tall as a character on a place, with its hatch timer.
function FishPenController.setEgg(cell: Model, eggType: string)
	cell.Content:ClearAllChildren()
	cell:SetAttribute("State", "Egg")
	cell:SetAttribute("EggType", eggType)
	cell:SetAttribute("HatchAt", now() + Config.Eggs[eggType].hatch)
	Creatures.egg(cell.Content, eggType, CFrame.new(cell.EggPlacement.CFrame.Position + Vector3.new(0, 0.1, 0)), Config.BaseEggHeight)
	FishPenController.refreshCell(cell)
end

-- Places an egg on an empty place; returns true on success. Server-side only.
function FishPenController.placeEgg(player: Player, cell: Model, eggType: string?): boolean
	local base = Ownership.baseFrom(cell)
	if not Ownership.isOwner(player, base) then return false end
	if cell:GetAttribute("State") ~= "Empty" then return false end
	eggType = eggType or FishPenController.chooseEgg(player)
	if not eggType or not Config.Eggs[eggType] then return false end
	if Inventory and not Inventory.remove(player, eggType, 1) then return false end
	FishPenController.setEgg(cell, eggType)
	releaseHand(player, eggType)
	return true
end

---------------------------------------------------------------- income
local function pay(base: Model, amount: number)
	local owner = Players:GetPlayerByUserId(base:GetAttribute("OwnerUserId"))
	if not owner then return end
	local total = (remainder[base] or 0) + amount
	local whole = math.floor(total)
	remainder[base] = total - whole
	if whole <= 0 then return end
	if Stats then
		Stats.addCoins(owner, whole)
	else
		owner:SetAttribute("Coins", (owner:GetAttribute("Coins") or 0) + whole)
	end
end

-- One tick for every owned base: hatching, countdowns, income to the owner.
function FishPenController.tick(dt: number)
	local t = now()
	for _, base in Ownership.bases do
		if base:GetAttribute("OwnerUserId") ~= 0 then
			for _, cell in FishPenController.cells(base) do
				if cell:GetAttribute("State") == "Egg" then
					if (cell:GetAttribute("HatchAt") or 0) <= t then
						FishPenController.hatch(cell)
					else
						FishPenController.refreshCell(cell)
					end
				end
			end
			local income = FishPenController.updateIncome(base)
			if income > 0 then pay(base, income * dt) end
		end
	end
end

function FishPenController.resetBase(base: Model)
	for _, cell in FishPenController.cells(base) do FishPenController.clearCell(cell) end
	base:SetAttribute("Income", 0)
	remainder[base] = nil
end

function FishPenController.init(bases: {Model})
	Stats = optional("OceanHUDStats")
	Inventory = optional("OceanInventory")
	for _, base in bases do
		for _, cell in FishPenController.cells(base) do cell:Destroy() end
		base:SetAttribute("Income", 0)
	end
	table.insert(Ownership.onReleased, FishPenController.resetBase)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Config.IncomeTick)
			local current = os.clock()
			FishPenController.tick(current - last)
			last = current
		end
	end)
end

return FishPenController
