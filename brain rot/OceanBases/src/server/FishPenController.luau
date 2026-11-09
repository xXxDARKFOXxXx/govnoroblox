-- FishPenController (server): the yard's cells — placing eggs on any free cell,
-- hatching, fish, and paying fish income straight into the owner's coins.
-- Every action checks on the server that the player owns the base.
--
-- Cell attributes: State ("Empty" | "Egg" | "Fish"), EggType, HatchAt (server
-- time), FishType, Income. Base attribute: Income (coins per second, total).
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
		gui.Line.Text = "+" .. format(cell:GetAttribute("Income") or 0) .. " / сек"
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
	cell:SetAttribute("Income", nil)
	FishPenController.refreshCell(cell)
end

local function spawnFish(cell: Model, fishType: string)
	local floor = cell.EggPlacement.CFrame.Position
	local center = floor + Vector3.new(0, Config.FishHeight, 0)
	local fish = Creatures.fish(cell.Content, fishType, CFrame.new(center))
	-- Swim path for the client animation: a small circle above the cell.
	fish:SetAttribute("Center", center)
	fish:SetAttribute("FloorY", floor.Y)
	fish:SetAttribute("RadiusX", Config.FishSwimRadius)
	fish:SetAttribute("RadiusZ", Config.FishSwimRadius)
	fish:SetAttribute("Phase", FishPenController.random:NextNumber() * math.pi * 2)
	fish:SetAttribute("Speed", Config.FishSwimSpeed * (0.85 + FishPenController.random:NextNumber() * 0.3))
	return fish
end

local function updateIncome(base: Model)
	local total = 0
	for _, cell in FishPenController.cells(base) do
		if cell:GetAttribute("State") == "Fish" then total += cell:GetAttribute("Income") or 0 end
	end
	base:SetAttribute("Income", total)
	return total
end

function FishPenController.hatch(cell: Model, fishType: string?)
	fishType = fishType or Creatures.rollFish(cell:GetAttribute("EggType"), FishPenController.random)
	cell.Content:ClearAllChildren()
	cell:SetAttribute("State", "Fish")
	cell:SetAttribute("FishType", fishType)
	cell:SetAttribute("Income", Config.Fish[fishType].income)
	cell:SetAttribute("HatchAt", nil)
	spawnFish(cell, fishType)
	FishPenController.refreshCell(cell)
	local base = Ownership.baseFrom(cell)
	if base then updateIncome(base) end
end

-- The egg in the player's hand (selected hotbar slot) first, otherwise any egg.
function FishPenController.chooseEgg(player: Player): string?
	if not Inventory then return nil end
	local held = player:GetAttribute("HeldItem")
	if type(held) == "string" and Config.Eggs[held] and Inventory.count(player, held) > 0 then
		return held
	end
	for _, eggType in {"BasicEgg", "StarEgg", "OceanEgg", "GoldEgg"} do
		if Inventory.count(player, eggType) > 0 then return eggType end
	end
	return nil
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
			local income = updateIncome(base)
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
		FishPenController.placeEgg(player, cell)
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
