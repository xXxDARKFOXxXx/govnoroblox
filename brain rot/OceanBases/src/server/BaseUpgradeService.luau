-- BaseUpgradeService (server): expanding the yard. Each upgrade adds one row of
-- five cells at the front and moves the front fence, walkway and decor out a
-- little; the yard stays one open level.
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
	local rows = base:GetAttribute("Rows")
	local nextLevel = Config.Levels[rows + 1]
	local prompt = board.UpgradePoint.UpgradePrompt
	local text = board.BoardFace.UpgradeLabel.Text
	if nextLevel then
		text.Text = string.format("Расширить базу\n%d → %d мест\n%s монет", Config.Levels[rows].cells, nextLevel.cells, format(nextLevel.price))
		prompt.ActionText = "Расширить за " .. format(nextLevel.price)
		prompt:SetAttribute("Active", true)
	else
		text.Text = "Максимум\n" .. Config.Levels[rows].cells .. " мест"
		prompt:SetAttribute("Active", false)
	end
end

-- Rebuilds the yard for `rows` (fence, walkway, board, spawn, owner name).
function BaseUpgradeService.setRows(base: Model, rows: number)
	local origin = base.PrimaryPart.CFrame
	local current = base:GetAttribute("Rows")
	for row = current + 1, rows do
		for _, cell in Builder.buildRow(base, origin, row) do Pens.bindCell(cell) end
	end
	for _, cell in base.Cells:GetChildren() do
		if cell:GetAttribute("Row") > rows then cell:Destroy() end
	end
	base:SetAttribute("Rows", rows)
	Builder.buildYard(base, origin, rows)
	bindBoard(base)
	Ownership.refreshTag(base)
	BaseUpgradeService.refreshBoard(base)
end

-- Server-validated purchase of the next row. Returns true when bought.
function BaseUpgradeService.upgrade(player: Player, base: Model): boolean
	if not Ownership.isOwner(player, base) then return false end
	local rows = base:GetAttribute("Rows")
	local nextLevel = Config.Levels[rows + 1]
	if not nextLevel then return false end
	if not spend(player, nextLevel.price) then return false end
	BaseUpgradeService.setRows(base, rows + 1)
	return true
end

-- Back to the starting size when the owner leaves.
function BaseUpgradeService.reset(base: Model)
	if base:GetAttribute("Rows") ~= Config.StartRows then
		BaseUpgradeService.setRows(base, Config.StartRows)
	end
end

function BaseUpgradeService.init(bases: {Model})
	local module = ServerScriptService:FindFirstChild("OceanHUDStats")
	Stats = module and require(module) or nil
	for _, base in bases do
		local rows = 0
		for _, cell in base.Cells:GetChildren() do rows = math.max(rows, cell:GetAttribute("Row")) end
		base:SetAttribute("Rows", rows)
		bindBoard(base)
		BaseUpgradeService.refreshBoard(base)
	end
	table.insert(Ownership.onReleased, BaseUpgradeService.reset)
end

return BaseUpgradeService
