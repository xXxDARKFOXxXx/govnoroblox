-- FishPenController (server): the yard's cells — placing eggs on any free cell,
-- hatching, fish, and paying fish income straight into the owner's coins.
-- Every action checks on the server that the player owns the base.
--
-- Cell attributes: State ("Empty" | "Egg" | "Fish"), EggType, HatchAt (server
-- time), FishType, FishLevel, Income. Base attribute: Income (coins per second).
-- Pen actions (from the HUD menus): remove a fish to the inventory, upgrade a
-- fish (cost grows with the level), delete an egg. Fish taken to the inventory
-- can be put back on any free cell with their level.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))
local Ownership = require(script.Parent:WaitForChild("BaseOwnershipService"))
local Creatures = require(script.Parent:WaitForChild("CreatureModels"))

local FishPenController = {}
FishPenController.random = Random.new()

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
	local prompt = point.CellPrompt
	local state = cell:GetAttribute("State")
	if state == "Egg" then
		local egg = Config.Eggs[cell:GetAttribute("EggType")]
		gui.Title.Text = egg and egg.name or "Яйцо"
		gui.Title.TextColor3 = Config.Colors.White
		gui.Line.Text = "Вылупится через " .. clock((cell:GetAttribute("HatchAt") or 0) - now())
		gui.Enabled = true
		prompt:SetAttribute("Active", false)
	elseif state == "Fish" then
		local fish = Config.Fish[cell:GetAttribute("FishType")]
		gui.Title.Text = fish and fish.name or "Рыба"
		gui.Title.TextColor3 = fish and Config.RarityColors[fish.rarity] or Config.Colors.White
		gui.Line.Text = "Ур. " .. (cell:GetAttribute("FishLevel") or 1) .. " · +" .. format(cell:GetAttribute("Income") or 0) .. " / сек"
		gui.Enabled = true
		prompt:SetAttribute("Active", false)
	else
		gui.Enabled = false
		prompt:SetAttribute("Active", true)
	end
end

function FishPenController.clearCell(cell: Model)
	cell.Content:ClearAllChildren()
	cell:SetAttribute("State", "Empty")
	cell:SetAttribute("EggType", nil)
	cell:SetAttribute("HatchAt", nil)
	cell:SetAttribute("FishType", nil)
	cell:SetAttribute("FishLevel", nil)
	cell:SetAttribute("Income", nil)
	FishPenController.refreshCell(cell)
	local base = Ownership.baseFrom(cell)
	if base then FishPenController.updateIncome(base) end
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

-- Puts a fish from the inventory onto a free cell (keeps its level).
function FishPenController.placeFish(player: Player, cell: Model, itemId: string): boolean
	local base = Ownership.baseFrom(cell)
	if not Ownership.isOwner(player, base) or cell:GetAttribute("State") ~= "Empty" then return false end
	local item = fishItem(player, itemId)
	if not item or not Inventory then return false end
	local fishType, level = item:GetAttribute("FishType"), item:GetAttribute("Level") or 1
	if not Inventory.remove(player, itemId, 1) then return false end
	setFish(cell, fishType, math.clamp(math.floor(level), 1, Config.MaxFishLevel))
	return true
end

-- What the cell prompt places: the item in the hand (egg or fish), else any egg.
function FishPenController.placeHeld(player: Player, cell: Model): boolean
	local held = player:GetAttribute("HeldItem")
	if type(held) == "string" and fishItem(player, held) then
		return FishPenController.placeFish(player, cell, held)
	end
	return FishPenController.placeEgg(player, cell)
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

-- Places an egg on a free cell; returns true on success. Server-side only.
function FishPenController.placeEgg(player: Player, cell: Model, eggType: string?): boolean
	local base = Ownership.baseFrom(cell)
	if not Ownership.isOwner(player, base) then return false end
	if cell:GetAttribute("State") ~= "Empty" then return false end
	eggType = eggType or FishPenController.chooseEgg(player)
	if not eggType or not Config.Eggs[eggType] then return false end
	if Inventory and not Inventory.remove(player, eggType, 1) then return false end
	cell:SetAttribute("State", "Egg")
	cell:SetAttribute("EggType", eggType)
	cell:SetAttribute("HatchAt", now() + Config.Eggs[eggType].hatch)
	Creatures.egg(cell.Content, eggType, CFrame.new(cell.EggPlacement.CFrame.Position + Vector3.new(0, 0.1, 0)))
	FishPenController.refreshCell(cell)
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

function FishPenController.bindCell(cell: Model)
	if cell:GetAttribute("Bound") then return end
	cell:SetAttribute("Bound", true)
	cell.InteractionPoint.CellPrompt.Triggered:Connect(function(player)
		FishPenController.placeHeld(player, cell)
	end)
	FishPenController.refreshCell(cell)
end

function FishPenController.init(bases: {Model})
	Stats = optional("OceanHUDStats")
	Inventory = optional("OceanInventory")
	for _, base in bases do
		for _, cell in FishPenController.cells(base) do FishPenController.bindCell(cell) end
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
