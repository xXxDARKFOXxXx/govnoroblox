-- InventoryController: backpack button [G], hotbar slots 1-8 and the inventory
-- window (category tabs, search, item grid), in a dark translucent style.
--
-- Data comes from the server: Player.Inventory (Folder) holds one Folder per
-- item with attributes DisplayName, Category ("Eggs" | "Fish" | "Food"),
-- Icon (UIAssets name or rbxassetid://...), Count and optional HotbarSlot (1-8).
-- See OceanInventory on the server. The client never creates items.
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.UITheme)
local Assets = require(script.Parent.UIAssets)
local C = require(script.Parent.UIComponents)
local Anim = require(script.Parent.UIAnimations)

local InventoryController = {}
InventoryController.__index = InventoryController

InventoryController.Categories = {
	{key = "All", title = "Все", icon = "Backpack"},
	{key = "Eggs", title = "Яйца", icon = "Egg"},
	{key = "Fish", title = "Рыбы", icon = "SharkFin"},
	{key = "Food", title = "Еда", icon = "Food"},
}
local SLOT, GAP, SLOTS = 92, 8, 8
local TAB, TAB_GAP = 100, 10
InventoryController.Slot = SLOT
InventoryController.Gap = GAP
InventoryController.RowW = SLOT * (SLOTS + 1) + GAP * SLOTS
InventoryController.PanelW, InventoryController.PanelH = 1000, 500

local DARK = Color3.fromRGB(20, 24, 26)
local BLACK = Color3.fromRGB(0, 0, 0)
local KEYS = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6, [Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8,
}

-- Roblox string.lower only handles ASCII; this also lowers Cyrillic for search.
local function lower(text: string): string
	local out = {}
	for _, code in utf8.codes(text) do
		if code >= 1040 and code <= 1071 then
			code += 32
		elseif code == 1025 then
			code = 1105
		elseif code >= 65 and code <= 90 then
			code += 32
		end
		table.insert(out, utf8.char(code))
	end
	return table.concat(out)
end
InventoryController.lower = lower

local function iconFor(name: string?): string
	if type(name) ~= "string" or name == "" then return "" end
	if string.find(name, "://") then return name end
	return Assets.image(name)
end

-- Dark translucent rounded tile with a black outline and a faint top sheen.
local function tile(parent, class, name, position, size, z)
	local object = C.new(class, parent, {
		Name = name, Position = position, Size = size, BackgroundColor3 = DARK,
		BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = z or 1,
	})
	if object:IsA("TextButton") then
		object.Text = ""
		object.AutoButtonColor = false
	end
	C.corner(object, 0, 12)
	local stroke = C.stroke(object, BLACK, 3)
	local sheen = C.frame(object, "Sheen", {
		Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 0.45, 0),
		BackgroundTransparency = 0.88, ZIndex = (z or 1) + 1,
	})
	C.corner(sheen, 0, 10)
	C.fadeGradient(sheen, 0.2, 1)
	return object, stroke
end

local function plainLabel(parent, name, text, props)
	local label = C.label(parent, name, text, props)
	label.Font = Enum.Font.GothamBold
	return label
end

function InventoryController.new(root: GuiObject, player: Player, sound: Sound?)
	local self = setmetatable({
		root = root, player = player, sound = sound, isOpen = false, category = "All",
		selected = nil, connections = {}, itemConnections = {}, slots = {}, tabs = {}, places = nil,
	}, InventoryController)
	local function connect(signal, callback)
		table.insert(self.connections, signal:Connect(callback))
	end

	-- Backpack button: alone in the middle when closed, first slot of the row when open.
	local backpack = C.holder(root, "Backpack", UDim2.fromOffset(0, 0), UDim2.fromOffset(SLOT, SLOT), 3)
	self.backpack = backpack
	self.backpackScale = C.new("UIScale", backpack, {Scale = 1})
	local button, stroke = tile(backpack, "TextButton", "Button", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 3)
	self.backpackStroke = stroke
	C.image(button, "Icon", "Backpack", UDim2.new(0.5, -32, 0, 4), UDim2.fromOffset(64, 64), 5)
	plainLabel(button, "Key", "[G]", {Position = UDim2.new(0, 0, 1, -28), Size = UDim2.new(1, 0, 0, 24), TextSize = 22, ZIndex = 6})
	local pop = C.new("UIScale", button, {Scale = 1})
	connect(button.MouseEnter, function() Anim.tween(pop, Theme.Time.Hover, {Scale = 1.06}, nil, nil, "hover") end)
	connect(button.MouseLeave, function() Anim.tween(pop, Theme.Time.Hover, {Scale = 1}, nil, nil, "hover") end)
	connect(button.Activated, function()
		if self.sound then self.sound:Play() end
		pop.Scale = 0.92
		Anim.tween(pop, Theme.Time.Release, {Scale = 1}, Enum.EasingStyle.Back, Enum.EasingDirection.Out, "hover")
		self:toggle()
	end)

	-- Hotbar slots 1-8 (shown while the inventory is open).
	local hotbar = C.new("CanvasGroup", root, {
		Name = "Hotbar", Size = UDim2.fromOffset(SLOT * SLOTS + GAP * (SLOTS - 1), SLOT),
		BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, ZIndex = 3,
	})
	self.hotbar = hotbar
	self.hotbarScale = C.new("UIScale", hotbar, {Scale = 1})
	for i = 1, SLOTS do
		local slot, slotStroke = tile(hotbar, "TextButton", "Slot" .. i, UDim2.fromOffset((i - 1) * (SLOT + GAP), 0), UDim2.fromOffset(SLOT, SLOT), 3)
		plainLabel(slot, "Number", tostring(i), {
			Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(30, 26), TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
		})
		local icon = C.image(slot, "Icon", "Backpack", UDim2.new(0.5, -30, 0.5, -26), UDim2.fromOffset(60, 60), 5)
		icon.Image = ""
		connect(slot.Activated, function() self:select(i) end)
		self.slots[i] = {button = slot, stroke = slotStroke, icon = icon}
	end
	self.selectEvent = C.new("BindableEvent", root, {Name = "HotbarSelected"})

	-- Inventory window: tabs on the left, search + grid on the right.
	local panel = C.new("CanvasGroup", root, {
		Name = "InventoryPanel", Size = UDim2.fromOffset(InventoryController.PanelW, InventoryController.PanelH),
		BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, ZIndex = 3,
	})
	self.panel = panel
	self.panelScale = C.new("UIScale", panel, {Scale = 1})
	for i, spec in InventoryController.Categories do
		local tab, tabStroke = tile(panel, "TextButton", spec.key .. "Tab", UDim2.fromOffset(0, (i - 1) * (TAB + TAB_GAP)), UDim2.fromOffset(TAB, TAB), 3)
		local gradient = C.gradient(tab, Color3.fromRGB(96, 196, 255), Color3.fromRGB(30, 110, 200))
		gradient.Enabled = false
		C.image(tab, "Icon", spec.icon, UDim2.new(0.5, -32, 0, 4), UDim2.fromOffset(64, 64), 5)
		plainLabel(tab, "Caption", spec.title, {Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, 0, 0, 26), TextSize = 21, ZIndex = 6})
		connect(tab.Activated, function()
			if self.sound then self.sound:Play() end
			self:setCategory(spec.key)
		end)
		self.tabs[spec.key] = {button = tab, stroke = tabStroke, gradient = gradient}
	end
	local main = tile(panel, "Frame", "Main", UDim2.fromOffset(TAB + 12, 0),
		UDim2.fromOffset(InventoryController.PanelW - TAB - 12, InventoryController.PanelH), 2)
	main.UICorner.CornerRadius = UDim.new(0, 18)
	local search = C.new("TextBox", main, {
		Name = "Search", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(380, 46),
		BackgroundColor3 = Color3.fromRGB(40, 44, 48), BackgroundTransparency = 0.1, BorderSizePixel = 0,
		Text = "", PlaceholderText = "Поиск", PlaceholderColor3 = Color3.fromRGB(150, 156, 160),
		TextColor3 = Theme.White, Font = Enum.Font.GothamMedium, TextSize = 22, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
	})
	C.corner(search, 0, 8)
	C.new("UIPadding", search, {PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 12)})
	self.search = search
	local grid = C.new("ScrollingFrame", main, {
		Name = "Grid", Position = UDim2.fromOffset(16, 74), Size = UDim2.new(1, -32, 1, -88),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		CanvasSize = UDim2.fromScale(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 4,
	})
	C.new("UIGridLayout", grid, {
		CellSize = UDim2.fromOffset(112, 126), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder,
	})
	C.new("UIPadding", grid, {PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4)})
	self.grid = grid
	local empty = plainLabel(main, "Empty", "Здесь пока ничего нет", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.new(1, -40, 0, 60),
		TextSize = 40, TextColor3 = Color3.fromRGB(160, 166, 172), ZIndex = 5,
	})
	empty.UIStroke.Transparency = 1
	self.empty = empty

	connect(search:GetPropertyChangedSignal("Text"), function() self:render() end)
	connect(UserInputService.InputBegan, function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.G then
			self:toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and self.isOpen then
			self:close()
		elseif KEYS[input.KeyCode] then
			self:select(KEYS[input.KeyCode])
		end
	end)
	connect(player.ChildAdded, function(child)
		if child.Name == "Inventory" then self:bindItems() end
	end)
	connect(player.ChildRemoved, function(child)
		if child.Name == "Inventory" then self:bindItems() end
	end)
	self:bindItems()
	self:setCategory("All")
	return self
end

---------------------------------------------------------------- data
function InventoryController:clearItemConnections()
	for _, connection in self.itemConnections do connection:Disconnect() end
	table.clear(self.itemConnections)
end

function InventoryController:bindItems()
	self:clearItemConnections()
	local folder = self.player:FindFirstChild("Inventory")
	if folder then
		local function rebind() self:bindItems() end
		table.insert(self.itemConnections, folder.ChildAdded:Connect(rebind))
		table.insert(self.itemConnections, folder.ChildRemoved:Connect(rebind))
		for _, item in folder:GetChildren() do
			table.insert(self.itemConnections, item.AttributeChanged:Connect(function() self:render() end))
		end
	end
	self:render()
end

function InventoryController:items()
	local list = {}
	local folder = self.player:FindFirstChild("Inventory")
	if not folder then return list end
	for _, item in folder:GetChildren() do
		local count = item:GetAttribute("Count")
		table.insert(list, {
			id = item.Name,
			name = tostring(item:GetAttribute("DisplayName") or item.Name),
			category = item:GetAttribute("Category"),
			icon = item:GetAttribute("Icon"),
			count = if type(count) == "number" then count else 1,
			slot = item:GetAttribute("HotbarSlot"),
		})
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

---------------------------------------------------------------- view
function InventoryController:render()
	for _, child in self.grid:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local query = lower(self.search.Text)
	local shown = 0
	local bySlot = {}
	for _, item in self:items() do
		if type(item.slot) == "number" and self.slots[item.slot] then
			bySlot[item.slot] = item
		end
		local inCategory = self.category == "All" or item.category == self.category
		local matches = query == "" or string.find(lower(item.name), query, 1, true) ~= nil
		if inCategory and matches and item.count > 0 then
			shown += 1
			local card = tile(self.grid, "Frame", "Item_" .. item.id, UDim2.new(), UDim2.new(), 5)
			card.LayoutOrder = shown
			C.image(card, "Icon", "Backpack", UDim2.new(0.5, -34, 0, 8), UDim2.fromOffset(68, 68), 6).Image = iconFor(item.icon)
			local name = plainLabel(card, "ItemName", item.name, {
				Position = UDim2.new(0, 4, 1, -44), Size = UDim2.new(1, -8, 0, 40), TextSize = 16, TextWrapped = true, ZIndex = 7,
			})
			name.TextYAlignment = Enum.TextYAlignment.Center
			if item.count > 1 then
				plainLabel(card, "Count", "x" .. tostring(item.count), {
					AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 4), Size = UDim2.fromOffset(50, 22),
					TextSize = 18, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 7,
				})
			end
		end
	end
	self.empty.Visible = shown == 0
	self.shownCount = shown
	for i, slot in self.slots do
		local item = bySlot[i]
		slot.icon.Image = item and iconFor(item.icon) or ""
		slot.item = item
	end
end

function InventoryController:setCategory(key: string)
	self.category = key
	for tabKey, tab in self.tabs do
		local active = tabKey == key
		tab.gradient.Enabled = active
		tab.button.BackgroundColor3 = active and Theme.White or DARK
		tab.button.BackgroundTransparency = active and 0 or 0.25
		tab.stroke.Color = active and Color3.fromRGB(10, 40, 80) or BLACK
	end
	self:render()
end

function InventoryController:select(index: number)
	if self.selected == index then
		index = nil -- pressing the same number again unselects
	end
	self.selected = index
	for i, slot in self.slots do
		slot.stroke.Color = i == index and Theme.White or BLACK
	end
	local item = index and self.slots[index].item
	self.selectEvent:Fire(index, item and item.id or nil)
end

function InventoryController:placeBackpack(animated: boolean?)
	local places = self.places
	if not places then return end
	local target = self.isOpen and places.backpackOpen or places.backpackClosed
	if animated then
		Anim.tween(self.backpack, 0.22, {Position = target}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, "move")
	else
		self.backpack.Position = target
	end
	self.backpackStroke.Color = self.isOpen and Theme.White or BLACK
end

-- places = {scale, backpackClosed, backpackOpen, hotbar (UDim2), panel (UDim2), panelScale}
function InventoryController:applyLayout(places)
	self.places = places
	self.backpackScale.Scale = places.scale
	self.hotbarScale.Scale = places.scale
	self.hotbar.Position = places.hotbar
	self.panel.Position = places.panel
	self.panelScale.Scale = places.panelScale
	self:placeBackpack(false)
end

function InventoryController:open(category: string?)
	if category then self:setCategory(category) end
	if self.isOpen then return end
	self.isOpen = true
	if self.onOpen then self.onOpen() end
	for _, group in {self.panel, self.hotbar} do
		group.Visible = true
		Anim.tween(group, Theme.Time.MenuOpen, {GroupTransparency = 0}, nil, nil, "fade")
	end
	local scale = self.places and self.places.panelScale or 1
	self.panelScale.Scale = scale * 0.92
	Anim.tween(self.panelScale, Theme.Time.MenuOpen, {Scale = scale}, Enum.EasingStyle.Back, Enum.EasingDirection.Out, "scale")
	self:placeBackpack(true)
end

function InventoryController:close()
	if not self.isOpen then return end
	self.isOpen = false
	self.search:ReleaseFocus()
	for _, group in {self.panel, self.hotbar} do
		Anim.tween(group, Theme.Time.MenuClose, {GroupTransparency = 1}, nil, nil, "fade", function()
			if not self.isOpen then group.Visible = false end
		end)
	end
	self:placeBackpack(true)
end

function InventoryController:toggle(category: string?)
	if self.isOpen and (category == nil or category == self.category) then
		self:close()
	else
		self:open(category)
	end
end

function InventoryController:destroy()
	self:clearItemConnections()
	for _, connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
end

return InventoryController
