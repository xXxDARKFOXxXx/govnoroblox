-- BaseUpgradeService (server): vertical upgrades and the bubble lift.
-- Upgrading adds the next floor (5 more pens) on top of the base. Locked floors
-- are prebuilt and kept in ServerStorage.OceanBasesLocked.BaseN until bought.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))
local Ownership = require(script.Parent:WaitForChild("BaseOwnershipService"))
local Pens = require(script.Parent:WaitForChild("FishPenController"))

local BaseUpgradeService = {}
local locked: Instance? = nil
local Stats

local function format(value: number): string
	local text = string.format("%d", math.floor(value))
	local result = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (result:gsub("^,", ""))
end

local function coins(player: Player): number
	return player:GetAttribute("Coins") or 0
end

local function spend(player: Player, amount: number): boolean
	if coins(player) < amount then return false end
	if Stats then
		Stats.addCoins(player, -amount)
	else
		player:SetAttribute("Coins", coins(player) - amount)
	end
	return true
end

local function storageFor(base: Model): Instance?
	return locked and locked:FindFirstChild(base.Name)
end

---------------------------------------------------------------- lift
function BaseUpgradeService.refreshLifts(base: Model)
	local floors = base:GetAttribute("Floors")
	for _, floor in base.Floors:GetChildren() do
		local k = floor:GetAttribute("Floor")
		local point = floor.Lift.LiftPoint
		point.LiftUp:SetAttribute("Active", k < floors)
		point.LiftDown:SetAttribute("Active", k > 1)
		-- The glass tube leads up to the next floor; hide it on the top floor.
		local hasAbove = k < floors
		floor.Lift.LiftTube.Transparency = hasAbove and 0.82 or 1
		floor.Lift.LiftTopRing.Transparency = hasAbove and 0 or 1
		floor.Lift.LiftTube.LiftBubbles.Enabled = hasAbove
	end
end

function BaseUpgradeService.ride(player: Player, base: Model, fromFloor: number, direction: number)
	local target = fromFloor + direction
	if target < 1 or target > base:GetAttribute("Floors") then return end
	local floor = base.Floors:FindFirstChild("Floor" .. target)
	local character = player.Character
	if floor and character and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(floor.Lift.LiftArrival.CFrame + Vector3.new(0, 1, 0))
	end
end

local function bindLift(base: Model, floor: Model)
	if floor:GetAttribute("LiftBound") then return end
	floor:SetAttribute("LiftBound", true)
	local point = floor.Lift.LiftPoint
	local k = floor:GetAttribute("Floor")
	point.LiftUp.Triggered:Connect(function(player) BaseUpgradeService.ride(player, base, k, 1) end)
	point.LiftDown.Triggered:Connect(function(player) BaseUpgradeService.ride(player, base, k, -1) end)
end

---------------------------------------------------------------- upgrades
function BaseUpgradeService.refreshBoard(base: Model)
	local board = base:FindFirstChild("UpgradeBoard")
	if not board then return end
	local gui = board.BoardFace:FindFirstChild("UpgradeLabel")
	local floors = base:GetAttribute("Floors")
	local nextLevel = Config.Levels[floors + 1]
	local prompt = board.UpgradePoint.UpgradePrompt
	if nextLevel then
		gui.Text.Text = string.format("Этаж %d\n%s монет\n%d → %d загонов", floors + 1, format(nextLevel.price), Config.Levels[floors].pens, nextLevel.pens)
		prompt.ActionText = "Улучшить за " .. format(nextLevel.price)
		prompt:SetAttribute("Active", true)
	else
		gui.Text.Text = "Максимум\n" .. Config.Levels[floors].pens .. " загонов"
		prompt:SetAttribute("Active", false)
	end
end

function BaseUpgradeService.unlockFloor(base: Model, k: number)
	local storage = storageFor(base)
	local floor = storage and storage:FindFirstChild("Floor" .. k)
	if not floor then return false end
	floor.Parent = base.Floors
	floor:PivotTo(base.PrimaryPart.CFrame * CFrame.new(0, Config.floorTop(k), 0))
	bindLift(base, floor)
	base:SetAttribute("Floors", k)
	BaseUpgradeService.refreshLifts(base)
	BaseUpgradeService.refreshBoard(base)
	return true
end

-- Server-validated purchase of the next floor. Returns true when bought.
function BaseUpgradeService.upgrade(player: Player, base: Model): boolean
	if not Ownership.isOwner(player, base) then return false end
	local floors = base:GetAttribute("Floors")
	local nextLevel = Config.Levels[floors + 1]
	if not nextLevel then return false end
	if not storageFor(base) or not storageFor(base):FindFirstChild("Floor" .. (floors + 1)) then return false end
	if not spend(player, nextLevel.price) then return false end
	return BaseUpgradeService.unlockFloor(base, floors + 1)
end

-- Back to the starting floors when the owner leaves.
function BaseUpgradeService.reset(base: Model)
	local storage = storageFor(base)
	for k = Config.MaxFloors, Config.StartFloors + 1, -1 do
		local floor = base.Floors:FindFirstChild("Floor" .. k)
		if floor and storage then
			for _, pen in floor.Pens:GetChildren() do Pens.clearPen(pen) end
			floor.Parent = storage
		end
	end
	base:SetAttribute("Floors", Config.StartFloors)
	BaseUpgradeService.refreshLifts(base)
	BaseUpgradeService.refreshBoard(base)
end

function BaseUpgradeService.init(bases: {Model}, lockedFloors: Instance?)
	locked = lockedFloors
	local module = ServerScriptService:FindFirstChild("OceanHUDStats")
	Stats = module and require(module) or nil
	for _, base in bases do
		for _, floor in base.Floors:GetChildren() do bindLift(base, floor) end
		local storage = storageFor(base)
		if storage then
			for _, floor in storage:GetChildren() do bindLift(base, floor) end
		end
		base.UpgradeBoard.UpgradePoint.UpgradePrompt.Triggered:Connect(function(player)
			BaseUpgradeService.upgrade(player, base)
		end)
		base:SetAttribute("Floors", #base.Floors:GetChildren())
		BaseUpgradeService.refreshLifts(base)
		BaseUpgradeService.refreshBoard(base)
	end
	table.insert(Ownership.onReleased, BaseUpgradeService.reset)
end

return BaseUpgradeService
