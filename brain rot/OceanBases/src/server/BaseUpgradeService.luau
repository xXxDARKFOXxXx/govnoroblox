-- BaseUpgradeService (server): base upgrades. A base starts with room for 10
-- fish (and eggs); each upgrade adds one more place, up to 20, and costs more
-- than the last. At upgrades 5 and 10 the yard itself grows towards the front.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))
local Ownership = require(script.Parent:WaitForChild("BaseOwnershipService"))
local Pens = require(script.Parent:WaitForChild("FishPenController"))
local Builder = require(script.Parent:WaitForChild("BaseBuilder"))

local BaseUpgradeService = {}
local Stats

local function format(value: number): string
	local text = string.format("%d", math.floor(value))
	local result = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (result:gsub("^,", ""))
end

local function spend(player: Player, amount: number): boolean
	local coins = player:GetAttribute("Coins") or 0
	if coins < amount then return false end
	if Stats then
		Stats.addCoins(player, -amount)
	else
		player:SetAttribute("Coins", coins - amount)
	end
	return true
end

local function bindBoard(base: Model)
	local board = base.Yard.UpgradeBoard
	board.UpgradePoint.UpgradePrompt.Triggered:Connect(function(player)
		BaseUpgradeService.upgrade(player, base)
	end)
end

function BaseUpgradeService.refreshBoard(base: Model)
	local board = base.Yard.UpgradeBoard
	local level = base:GetAttribute("Level") or 0
	local prompt = board.UpgradePoint.UpgradePrompt
	local text = board.BoardFace.UpgradeLabel.Text
	if level < Config.MaxBaseLevel then
		local price = Config.basePrice(level)
		local grows = Config.yardSize(level + 1) > Config.yardSize(level)
		text.Text = string.format("Улучшить базу%s\n%d → %d рыб\n%s монет", grows and " +" or "",
			Config.capacity(level), Config.capacity(level + 1), format(price))
		prompt.ActionText = "Улучшить за " .. format(price)
		prompt:SetAttribute("Active", true)
	else
		text.Text = "Максимум\n" .. Config.capacity(level) .. " рыб"
		prompt:SetAttribute("Active", false)
	end
	-- Same text on the side facing the yard.
	local back = board.BoardFace:FindFirstChild("UpgradeLabelBack")
	if back then back.Text.Text = text.Text end
end

-- Sets the base level: capacity 10 + level; the yard is rebuilt when its size
-- changes (fence, floor, pool, board, spawn, owner name).
function BaseUpgradeService.setLevel(base: Model, level: number)
	level = math.clamp(level, 0, Config.MaxBaseLevel)
	base:SetAttribute("Level", level)
	base:SetAttribute("Capacity", Config.capacity(level))
	local size = Config.yardSize(level)
	if base:GetAttribute("YardSize") ~= size then
		Builder.buildYard(base, base.PrimaryPart.CFrame, size)
		bindBoard(base)
		Ownership.refreshTag(base)
	end
	BaseUpgradeService.refreshBoard(base)
end

-- Server-validated purchase of the next level. Returns true when bought.
function BaseUpgradeService.upgrade(player: Player, base: Model): boolean
	if not Ownership.isOwner(player, base) then return false end
	local level = base:GetAttribute("Level") or 0
	if level >= Config.MaxBaseLevel then return false end
	if not spend(player, Config.basePrice(level)) then return false end
	BaseUpgradeService.setLevel(base, level + 1)
	return true
end

-- Back to the start when the owner leaves.
function BaseUpgradeService.reset(base: Model)
	BaseUpgradeService.setLevel(base, 0)
end

function BaseUpgradeService.init(bases: {Model})
	local module = ServerScriptService:FindFirstChild("OceanHUDStats")
	Stats = module and require(module) or nil
	for _, base in bases do
		bindBoard(base)
		BaseUpgradeService.setLevel(base, base:GetAttribute("Level") or 0)
	end
	table.insert(Ownership.onReleased, BaseUpgradeService.reset)
end

return BaseUpgradeService
