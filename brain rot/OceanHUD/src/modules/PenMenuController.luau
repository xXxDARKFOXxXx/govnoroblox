-- PenMenuController: the context menus of the "Рыбы" and "Яйца" buttons.
--   Рыбы — every fish in your pen: name (rarity colour), level, income, and the
--          buttons "Убрать" (to the inventory) and "Улучшить" (price grows each level).
--   Яйца — every egg waiting to hatch: name, time left, and "Удалить"
--          (press twice to confirm).
-- Data is read from your base in Workspace.OceanBases (cell attributes); the
-- actions go to the server through ReplicatedStorage.OceanBases.Remotes.PenAction,
-- which checks everything again. Works only when the bases are in the place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.UITheme)
local Assets = require(script.Parent.UIAssets)
local C = require(script.Parent.UIComponents)
local Anim = require(script.Parent.UIAnimations)

local PenMenuController = {}
PenMenuController.__index = PenMenuController

local W, H = 470, 420
local ROW = 74
local DARK = Color3.fromRGB(20, 24, 26)
local BLACK = Color3.fromRGB(0, 0, 0)
local GREEN = {Color3.fromRGB(130, 230, 90), Color3.fromRGB(40, 160, 50)}
local BLUE = {Color3.fromRGB(110, 200, 255), Color3.fromRGB(30, 110, 210)}
local RED = {Color3.fromRGB(255, 110, 100), Color3.fromRGB(200, 30, 40)}
local GRAY = {Color3.fromRGB(150, 150, 160), Color3.fromRGB(90, 90, 100)}

local function format(value: number): string
	local text = string.format("%d", math.floor(value))
	local result = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (result:gsub("^,", ""))
end

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function text(parent, name, value, props)
	local label = C.label(parent, name, value, props)
	label.Font = Enum.Font.GothamBold
	return label
end

local function button(parent, name, caption, colors, position, size)
	local b = C.new("TextButton", parent, {
		Name = name, Text = "", AutoButtonColor = false, Position = position, Size = size,
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 8,
	})
	C.corner(b, 0, 10)
	local gradient = C.gradient(b, colors[1], colors[2])
	C.stroke(b, BLACK, 2.5)
	local label = text(b, "Caption", caption, {Size = UDim2.fromScale(1, 1), TextSize = 17, ZIndex = 9})
	return b, label, gradient
end

function PenMenuController.new(root: GuiObject, player: Player, sound: Sound?)
	local self = setmetatable({
		root = root, player = player, sound = sound, mode = nil, connections = {},
		cellConnections = {}, rows = {}, confirm = {}, anchor = nil,
	}, PenMenuController)
	local panel = C.new("CanvasGroup", root, {
		Name = "PenMenu", Size = UDim2.fromOffset(W + 12, H + 12), AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, ZIndex = 20,
	})
	self.panel = panel
	self.scale = C.new("UIScale", panel, {Scale = 1})
	local body = C.frame(panel, "Body", {
		Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(W, H), BackgroundColor3 = DARK,
		BackgroundTransparency = 0.18, ZIndex = 20,
	})
	C.corner(body, 0, 16)
	C.stroke(body, BLACK, 3)
	self.icon = C.image(body, "Icon", "SharkFin", UDim2.fromOffset(14, 8), UDim2.fromOffset(48, 48), 22)
	self.title = text(body, "Title", "", {
		Position = UDim2.fromOffset(70, 10), Size = UDim2.new(1, -130, 0, 30), TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
	})
	self.subtitle = text(body, "Subtitle", "", {
		Position = UDim2.fromOffset(70, 38), Size = UDim2.new(1, -130, 0, 18), TextSize = 15,
		TextColor3 = Color3.fromRGB(200, 205, 210), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
	})
	local close = button(body, "Close", "X", RED, UDim2.new(1, -52, 0, 12), UDim2.fromOffset(40, 40))
	table.insert(self.connections, close.Activated:Connect(function() self:close() end))
	local list = C.new("ScrollingFrame", body, {
		Name = "List", Position = UDim2.fromOffset(10, 66), Size = UDim2.new(1, -20, 1, -76),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		CanvasSize = UDim2.fromScale(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 21,
	})
	C.new("UIListLayout", list, {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})
	C.new("UIPadding", list, {PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 4)})
	self.list = list
	self.empty = text(body, "Empty", "", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.new(1, -40, 0, 60),
		TextSize = 24, TextWrapped = true, TextColor3 = Color3.fromRGB(170, 176, 182), ZIndex = 22,
	})
	-- Countdown and live updates while open.
	table.insert(self.connections, player:GetAttributeChangedSignal("Coins"):Connect(function() self:refresh() end))
	task.spawn(function()
		while self.connections do
			task.wait(1)
			if self.mode == "Eggs" then self:refresh() end
		end
	end)
	return self
end

---------------------------------------------------------------- data
function PenMenuController:base(): Model?
	local folder = workspace:FindFirstChild("OceanBases")
	if not folder then return nil end
	for _, base in folder:GetChildren() do
		if base:GetAttribute("OwnerUserId") == self.player.UserId then return base end
	end
	return nil
end

function PenMenuController:config()
	local shared = ReplicatedStorage:FindFirstChild("OceanBases")
	local module = shared and shared:FindFirstChild("BaseConfig")
	return module and require(module) or nil
end

function PenMenuController:entries(state: string)
	local base = self:base()
	local list = {}
	if not base or not base:FindFirstChild("Cells") then return list, base end
	for _, cell in base.Cells:GetChildren() do
		if cell:GetAttribute("State") == state then table.insert(list, cell) end
	end
	table.sort(list, function(a, b) return a:GetAttribute("Index") < b:GetAttribute("Index") end)
	return list, base
end

function PenMenuController:watchCells(base: Model?)
	for _, connection in self.cellConnections do connection:Disconnect() end
	table.clear(self.cellConnections)
	if not base or not base:FindFirstChild("Cells") then return end
	local function changed() self:refresh() end
	table.insert(self.cellConnections, base.Cells.ChildAdded:Connect(changed))
	table.insert(self.cellConnections, base.Cells.ChildRemoved:Connect(changed))
	for _, cell in base.Cells:GetChildren() do
		table.insert(self.cellConnections, cell.AttributeChanged:Connect(changed))
	end
end

local function send(action: string, index: number)
	local shared = ReplicatedStorage:FindFirstChild("OceanBases")
	local remotes = shared and shared:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("PenAction")
	if remote then remote:FireServer(action, index) end
end

---------------------------------------------------------------- view
function PenMenuController:row(order: number, cell: Model)
	local r = C.frame(self.list, "Row" .. cell:GetAttribute("Index"), {
		Size = UDim2.new(1, 0, 0, ROW), BackgroundColor3 = Color3.fromRGB(40, 46, 52), BackgroundTransparency = 0.15, ZIndex = 21,
	})
	r.LayoutOrder = order
	C.corner(r, 0, 12)
	C.stroke(r, BLACK, 2)
	return r
end

function PenMenuController:refresh()
	if not self.mode then return end
	for _, child in self.list:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end
	self.rowConnections = {}
	local Config = self:config()
	local state = self.mode == "Fish" and "Fish" or "Egg"
	local cells, base = self:entries(state)
	if base ~= self.watched then
		self.watched = base
		self:watchCells(base)
	end
	local coins = self.player:GetAttribute("Coins") or 0
	if self.mode == "Fish" then
		local total = 0
		for _, cell in cells do total += cell:GetAttribute("Income") or 0 end
		self.title.Text = "Мои рыбы · " .. #cells
		self.subtitle.Text = "Доход: +" .. format(total) .. " монет в секунду"
		self.empty.Text = base and "В загоне пока нет рыб.\nВылупи их из яиц!" or "У тебя пока нет базы"
	else
		self.title.Text = "Мои яйца · " .. #cells
		self.subtitle.Text = "Ждут вылупления в загоне"
		self.empty.Text = base and "В загоне нет яиц.\nНайди их в гнёздах на дне океана!" or "У тебя пока нет базы"
	end
	self.empty.Visible = #cells == 0
	local now = workspace:GetServerTimeNow()
	for i, cell in cells do
		local index = cell:GetAttribute("Index")
		local r = self:row(i, cell)
		C.image(r, "Icon", self.mode == "Fish" and "SharkFin" or "Egg", UDim2.fromOffset(8, 7), UDim2.fromOffset(60, 60), 22)
		local nameLabel = text(r, "Title", "", {
			Position = UDim2.fromOffset(76, 8), Size = UDim2.new(1, -250, 0, 26), TextSize = 19,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 22,
		})
		local info = text(r, "Info", "", {
			Position = UDim2.fromOffset(76, 38), Size = UDim2.new(1, -250, 0, 22), TextSize = 16,
			TextColor3 = Theme.Coins.valueTop, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
		})
		if self.mode == "Fish" then
			local fishType = cell:GetAttribute("FishType")
			local level = cell:GetAttribute("FishLevel") or 1
			local fish = Config and Config.Fish[fishType]
			nameLabel.Text = fish and fish.name or tostring(fishType)
			nameLabel.TextColor3 = fish and Config.RarityColors[fish.rarity] or Color3.new(1, 1, 1)
			info.Text = string.format("Ур. %d · +%s/сек", level, format(cell:GetAttribute("Income") or 0))
			local remove = button(r, "Remove", "Убрать", BLUE, UDim2.new(1, -168, 0.5, -20), UDim2.fromOffset(72, 40))
			table.insert(self.rowConnections, remove.Activated:Connect(function()
				if self.sound then self.sound:Play() end
				send("RemoveFish", index)
			end))
			local maxed = Config and level >= Config.MaxFishLevel
			local cost = Config and not maxed and Config.upgradeCost(fishType, level) or 0
			local afford = coins >= cost and not maxed
			local upgrade, caption = button(r, "Upgrade", maxed and "Макс." or ("↑ " .. format(cost)), afford and GREEN or GRAY,
				UDim2.new(1, -90, 0.5, -20), UDim2.fromOffset(84, 40))
			caption.TextSize = 15
			table.insert(self.rowConnections, upgrade.Activated:Connect(function()
				if not afford then return end
				if self.sound then self.sound:Play() end
				send("UpgradeFish", index)
			end))
		else
			local eggType = cell:GetAttribute("EggType")
			local egg = Config and Config.Eggs[eggType]
			nameLabel.Text = egg and egg.name or tostring(eggType)
			info.Text = "Вылупится через " .. clock((cell:GetAttribute("HatchAt") or now) - now)
			local confirming = self.confirm[index] and os.clock() - self.confirm[index] < 3
			local delete = button(r, "Delete", confirming and "Точно?" or "Удалить", RED, UDim2.new(1, -110, 0.5, -20), UDim2.fromOffset(100, 40))
			table.insert(self.rowConnections, delete.Activated:Connect(function()
				if self.sound then self.sound:Play() end
				if self.confirm[index] and os.clock() - self.confirm[index] < 3 then
					self.confirm[index] = nil
					send("DeleteEgg", index)
				else
					self.confirm[index] = os.clock()
					self:refresh()
				end
			end))
		end
	end
end

-- Placement: just above the buttons that open it (bottom-right).
function PenMenuController:place(position: UDim2, scale: number)
	self.panel.Position = position
	self.anchorScale = scale
	if not self.mode then self.scale.Scale = scale end
end

function PenMenuController:open(mode: string)
	self.mode = mode
	self.rowConnections = self.rowConnections or {}
	self.icon.Image = Assets.image(mode == "Fish" and "SharkFin" or "Egg")
	self:refresh()
	if self.onOpen then self.onOpen() end
	if not self.panel.Visible then
		self.panel.Visible = true
		local scale = self.anchorScale or 1
		self.scale.Scale = scale * 0.9
		Anim.tween(self.panel, Theme.Time.MenuOpen, {GroupTransparency = 0}, nil, nil, "fade")
		Anim.tween(self.scale, Theme.Time.MenuOpen, {Scale = scale}, Enum.EasingStyle.Back, Enum.EasingDirection.Out, "scale")
	end
end

function PenMenuController:close()
	if not self.mode then return end
	self.mode = nil
	Anim.tween(self.panel, Theme.Time.MenuClose, {GroupTransparency = 1}, nil, nil, "fade", function()
		if not self.mode then self.panel.Visible = false end
	end)
end

function PenMenuController:toggle(mode: string)
	if self.mode == mode then self:close() else self:open(mode) end
end

function PenMenuController:destroy()
	for _, connection in self.connections do connection:Disconnect() end
	for _, connection in self.cellConnections do connection:Disconnect() end
	self.connections = nil
end

return PenMenuController
