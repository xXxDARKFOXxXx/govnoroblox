-- FishPenController (server): pen occupancy, placing eggs, hatching, fish,
-- income into the base chest and collecting it. Every action checks on the
-- server that the player owns the base.
--
-- Pen attributes: State ("Empty" | "Egg" | "Fish"), EggType, HatchAt (server
-- time), FishType, Income. Base attribute: Stored (coins waiting in the chest).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))
local Ownership = require(script.Parent:WaitForChild("BaseOwnershipService"))
local Creatures = require(script.Parent:WaitForChild("CreatureModels"))

local FishPenController = {}
FishPenController.random = Random.new()

-- Coins and inventory live in the HUD's server modules when they exist.
local function optional(name)
	local module = ServerScriptService:FindFirstChild(name)
	return module and require(module) or nil
end
local Stats, Inventory

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

---------------------------------------------------------------- pens
function FishPenController.pens(base: Model): {Model}
	local list = {}
	local floors = base:FindFirstChild("Floors")
	if floors then
		for _, floor in floors:GetChildren() do
			local pens = floor:FindFirstChild("Pens")
			if pens then
				for _, pen in pens:GetChildren() do table.insert(list, pen) end
			end
		end
	end
	return list
end

local function info(pen: Model)
	local gui = pen.InteractionPoint:FindFirstChild("PenInfo")
	return gui.Title, gui.Line
end

function FishPenController.refreshPen(pen: Model)
	local title, line = info(pen)
	local prompt = pen.InteractionPoint.PenPrompt
	local state = pen:GetAttribute("State")
	if state == "Egg" then
		local egg = Config.Eggs[pen:GetAttribute("EggType")]
		title.Text = egg and egg.name or "Яйцо"
		title.TextColor3 = Config.Colors.White
		line.Text = "Вылупится через " .. clock((pen:GetAttribute("HatchAt") or 0) - now())
		prompt:SetAttribute("Active", false)
	elseif state == "Fish" then
		local fish = Config.Fish[pen:GetAttribute("FishType")]
		title.Text = fish and fish.name or "Рыба"
		title.TextColor3 = fish and Config.RarityColors[fish.rarity] or Config.Colors.White
		line.Text = "+" .. format(pen:GetAttribute("Income") or 0) .. " / сек"
		prompt:SetAttribute("Active", false)
	else
		title.Text = "Свободный загон"
		title.TextColor3 = Config.Colors.White
		line.Text = "Поставь яйцо"
		prompt.ActionText = "Поставить яйцо"
		prompt:SetAttribute("Active", true)
	end
end

function FishPenController.clearPen(pen: Model)
	pen.Content:ClearAllChildren()
	pen:SetAttribute("State", "Empty")
	pen:SetAttribute("EggType", nil)
	pen:SetAttribute("HatchAt", nil)
	pen:SetAttribute("FishType", nil)
	pen:SetAttribute("Income", nil)
	FishPenController.refreshPen(pen)
end

local function spawnFish(pen: Model, fishType: string)
	local area = pen.FishMovementArea
	local spawn = pen.EggPlacement.FishSpawn
	local surface = area.CFrame
	local spawnPos = (pen.EggPlacement.CFrame * spawn.CFrame).Position
	local fish = Creatures.fish(pen.Content, fishType, CFrame.new(spawnPos.X, surface.Position.Y + 0.2, spawnPos.Z))
	-- Swim path for the client animation: an ellipse inside the movement area.
	fish:SetAttribute("Center", surface.Position + Vector3.new(0, 0.2, 0))
	fish:SetAttribute("RadiusX", area.Size.X / 2 - 1.2)
	fish:SetAttribute("RadiusZ", area.Size.Z / 2 - 1.0)
	fish:SetAttribute("Phase", FishPenController.random:NextNumber() * math.pi * 2)
	fish:SetAttribute("Speed", Config.FishSwimSpeed * (0.85 + FishPenController.random:NextNumber() * 0.3))
	return fish
end

function FishPenController.hatch(pen: Model, fishType: string?)
	local eggType = pen:GetAttribute("EggType")
	fishType = fishType or Creatures.rollFish(eggType, FishPenController.random)
	pen.Content:ClearAllChildren()
	pen:SetAttribute("State", "Fish")
	pen:SetAttribute("FishType", fishType)
	pen:SetAttribute("Income", Config.Fish[fishType].income)
	pen:SetAttribute("HatchAt", nil)
	spawnFish(pen, fishType)
	FishPenController.refreshPen(pen)
end

-- Places an egg; returns true on success. Server-side only.
function FishPenController.placeEgg(player: Player, pen: Model, eggType: string?): boolean
	local base = Ownership.baseFrom(pen)
	if not Ownership.isOwner(player, base) then return false end
	if pen:GetAttribute("State") ~= "Empty" then return false end
	if not pen:IsDescendantOf(workspace) then return false end -- locked floor
	eggType = eggType or FishPenController.chooseEgg(player)
	if not eggType or not Config.Eggs[eggType] then return false end
	if Inventory and not Inventory.remove(player, eggType, 1) then return false end
	pen:SetAttribute("State", "Egg")
	pen:SetAttribute("EggType", eggType)
	pen:SetAttribute("HatchAt", now() + Config.Eggs[eggType].hatch)
	Creatures.egg(pen.Content, eggType, pen.EggPlacement.CFrame * CFrame.Angles(0, 0, math.rad(-90)) * CFrame.new(0, 0.1, 0))
	FishPenController.refreshPen(pen)
	return true
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

---------------------------------------------------------------- chest
function FishPenController.refreshChest(base: Model)
	local chest = base:FindFirstChild("Chest")
	local point = chest and chest:FindFirstChild("ChestPoint")
	local gui = point and point:FindFirstChild("ChestInfo")
	if gui then gui.Amount.Text = format(base:GetAttribute("Stored") or 0) end
end

function FishPenController.collect(player: Player, base: Model): number
	if not Ownership.isOwner(player, base) then return 0 end
	local amount = math.floor(base:GetAttribute("Stored") or 0)
	if amount <= 0 then return 0 end
	base:SetAttribute("Stored", 0)
	if Stats then
		Stats.addCoins(player, amount)
	else
		player:SetAttribute("Coins", (player:GetAttribute("Coins") or 0) + amount)
	end
	FishPenController.refreshChest(base)
	return amount
end

---------------------------------------------------------------- loop
-- One tick for every base: income into chests, hatching, countdown text.
function FishPenController.tick(dt: number)
	local t = now()
	for _, base in Ownership.bases do
		if base:GetAttribute("OwnerUserId") ~= 0 then
			local income = 0
			for _, pen in FishPenController.pens(base) do
				local state = pen:GetAttribute("State")
				if state == "Egg" then
					if (pen:GetAttribute("HatchAt") or 0) <= t then
						FishPenController.hatch(pen)
					else
						FishPenController.refreshPen(pen)
					end
				elseif state == "Fish" then
					income += pen:GetAttribute("Income") or 0
				end
			end
			if income > 0 then
				base:SetAttribute("Stored", (base:GetAttribute("Stored") or 0) + income * dt)
			end
			FishPenController.refreshChest(base)
		end
	end
end

function FishPenController.resetBase(base: Model)
	for _, pen in FishPenController.pens(base) do FishPenController.clearPen(pen) end
	base:SetAttribute("Stored", 0)
	FishPenController.refreshChest(base)
end

-- Connects prompts of every pen (also pens on floors kept in storage).
function FishPenController.bindPen(pen: Model)
	if pen:GetAttribute("Bound") then return end
	pen:SetAttribute("Bound", true)
	pen.InteractionPoint.PenPrompt.Triggered:Connect(function(player)
		FishPenController.placeEgg(player, pen)
	end)
	FishPenController.refreshPen(pen)
end

function FishPenController.init(bases: {Model}, lockedFloors: Instance?)
	Stats = optional("OceanHUDStats")
	Inventory = optional("OceanInventory")
	for _, base in bases do
		for _, pen in FishPenController.pens(base) do FishPenController.bindPen(pen) end
		local chest = base:FindFirstChild("Chest")
		if chest then
			chest.ChestPoint.CollectPrompt.Triggered:Connect(function(player)
				FishPenController.collect(player, base)
			end)
		end
		base:SetAttribute("Stored", 0)
		FishPenController.refreshChest(base)
	end
	if lockedFloors then
		for _, pen in lockedFloors:GetDescendants() do
			if pen:IsA("Model") and pen:GetAttribute("PenIndex") then FishPenController.bindPen(pen) end
		end
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
