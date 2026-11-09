-- OceanHUD (HUDController) | LocalScript in StarterPlayer > StarterPlayerScripts.
-- Child ModuleScripts: UITheme, UIAssets, UIComponents, UIAnimations,
-- UIDataController, MenuController, InventoryController, PenMenuController.
--
-- Layout follows the 1648x928 reference: four candy buttons top-left,
-- coins + speed bottom-left, fish/eggs buttons bottom-right, backpack [G]
-- bottom-centre with 5 quick slots (opens the inventory, 10 quick slots). The ScreenGui is built
-- once; data changes only update text, fills and animations.
local Players = game:GetService("Players")

local Theme = require(script.UITheme)
local Assets = require(script.UIAssets)
local C = require(script.UIComponents)
local Anim = require(script.UIAnimations)
local Data = require(script.UIDataController)
local MenuController = require(script.MenuController)
local InventoryController = require(script.InventoryController)
local PenMenuController = require(script.PenMenuController)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("OceanHUD") then return end

local S = Theme.Size
local connections = {}
local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local gui = C.new("ScreenGui", playerGui, {
	Name = "OceanHUD", ResetOnSpawn = false, DisplayOrder = 20, IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
})
gui:SetAttribute("Version", "3.3.0")
gui:SetAttribute("UseExternalMenus", false)
local openMenuEvent = C.new("BindableEvent", gui, {Name = "OpenMenu"})
local clickSound = C.new("Sound", gui, {Name = "ClickSound", SoundId = Assets.ClickSound, Volume = 0.6})
local root = C.holder(gui, "SafeArea", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))

local menus = MenuController.new(root, openMenuEvent, clickSound)
local inventory = InventoryController.new(root, player, clickSound)
local penMenu = PenMenuController.new(root, player, clickSound)
-- Only one window at a time: inventory, pen menus and the big menus close each other.
inventory.onOpen = function() menus:close(); penMenu:close() end
penMenu.onOpen = function() menus:close(); inventory:close() end
connect(openMenuEvent.Event, function() inventory:close(); penMenu:close() end)

---------------------------------------------------------------- left buttons
local NAV_H = S.ButtonH * 4 + S.ButtonGap * 3
local navigation = C.holder(root, "Navigation", UDim2.fromOffset(S.Left, S.Top), UDim2.fromOffset(S.ButtonW, NAV_H))
local navScale = C.new("UIScale", navigation, {Scale = 1})
-- One candy button: glow, volumetric plate, white rim, picture icon, caption.
local function makeSlot(parent, spec, position, captionSize, onActivated)
	local slot = C.holder(parent, spec.key .. "Slot", position, UDim2.fromOffset(S.ButtonW, S.ButtonH))
	local scale = C.new("UIScale", slot, {Scale = 1})
	local glow = C.frame(slot, "HoverGlow", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 18, 1, 18),
		BackgroundColor3 = spec.glow, BackgroundTransparency = 1, ZIndex = 1,
	})
	C.corner(glow, 0.28)
	local _, body = C.plate(slot, "Plate", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), {
		top = spec.top, bottom = spec.bottom, edge = spec.edge, rim = Theme.Ink, rimThickness = 3.5, radius = 0.24,
	}, 2)
	local inner = C.holder(body, "WhiteRim", UDim2.fromOffset(4, 4), UDim2.new(1, -8, 1, -8), 5)
	C.corner(inner, 0.22)
	local rim = C.stroke(inner, Theme.White, 2.5, 0.25)
	C.image(body, "Icon", spec.icon or spec.key, UDim2.new(0.5, -43, 0, -1), UDim2.fromOffset(86, 86), 6)
	C.label(body, "Caption", spec.title, {
		Position = UDim2.new(0, -8, 1, -33), Size = UDim2.new(1, 16, 0, 30),
		TextSize = captionSize, ZIndex = 7,
	})
	local button = C.new("TextButton", slot, {
		Name = spec.key, Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), Selectable = true, ZIndex = 10,
	})
	for _, connection in Anim.bindButton({button = button, scale = scale, rim = rim, glow = glow, sound = clickSound}, onActivated or function()
		if gui:GetAttribute("UseExternalMenus") then
			openMenuEvent:Fire(spec.key)
		else
			menus:toggle(spec.key)
		end
	end) do
		table.insert(connections, connection)
	end
	return button
end

local buttons = {}
for i, spec in Theme.Buttons do
	buttons[i] = makeSlot(navigation, spec, UDim2.fromOffset(0, (i - 1) * (S.ButtonH + S.ButtonGap)), spec.key == "Rebirth" and 18 or 24)
end
for i, button in buttons do
	button.NextSelectionUp = buttons[(i - 2) % #buttons + 1]
	button.NextSelectionDown = buttons[i % #buttons + 1]
end

---------------------------------------------------------------- counters
local COIN_OUT = 22 -- how far the round icons stick out to the left
local COUNTERS_W = S.CounterW + COIN_OUT
local COUNTERS_H = S.CounterH * 2 + S.CounterGap
local counters = C.holder(root, "Counters", UDim2.fromOffset(S.Left, 0), UDim2.fromOffset(COUNTERS_W, COUNTERS_H))
local counterScale = C.new("UIScale", counters, {Scale = 1})

local function counter(key, title, y, style, iconName)
	local holder, body = C.plate(counters, key .. "Counter", UDim2.fromOffset(COIN_OUT, y), UDim2.fromOffset(S.CounterW, S.CounterH), {
		top = style.top, bottom = style.bottom, rim = style.rim, rimThickness = 3.5, glow = style.glow, radius = 0.5,
	}, 1)
	local caption = C.label(body, "Caption", title, {
		Position = UDim2.fromOffset(84, 8), Size = UDim2.fromOffset(240, 30), TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
	})
	local value = C.label(body, "Value", "0", {
		Position = UDim2.fromOffset(84, 36), Size = UDim2.fromOffset(244, 46), TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
	}, nil, {style.valueTop, style.valueBottom})
	local valueScale = C.new("UIScale", value, {Scale = 1})
	local icon = C.image(holder, "Icon", iconName, UDim2.fromOffset(-COIN_OUT - 6, -8), UDim2.fromOffset(104, 104), 8)
	local iconScale = C.new("UIScale", icon, {Scale = 1})
	local shine = C.image(holder, "Shine", "Sparkle", UDim2.fromOffset(-COIN_OUT - 16, -18), UDim2.fromOffset(124, 124), 9)
	shine.ImageTransparency = 1
	return {caption = caption, value = value, valueScale = valueScale, icon = icon, iconScale = iconScale, shine = shine}
end
local coins = counter("Coins", "Монеты", 0, Theme.Coins, "Coin")
local speed = counter("Speed", "Скорость", S.CounterH + S.CounterGap, Theme.Speed, "Flippers")
speed.value.Text = "0"

---------------------------------------------------------------- fish & eggs (bottom-right)
-- Context menus: fish in the pen (level, remove, upgrade) and eggs waiting to hatch.
local collection = C.holder(root, "Collection", UDim2.fromOffset(0, 0), UDim2.fromOffset(S.InventoryW, S.InventoryH))
local collectionScale = C.new("UIScale", collection, {Scale = 1})
for i, spec in Theme.Inventory do
	makeSlot(collection, spec, UDim2.fromOffset((i - 1) * (S.ButtonW + S.InventoryGap), 0), 26, function()
		penMenu:toggle(spec.key)
	end)
end

---------------------------------------------------------------- data binding
local shownCoins = C.new("NumberValue", gui, {Name = "ShownCoins", Value = 0})
connect(shownCoins:GetPropertyChangedSignal("Value"), function()
	coins.value.Text = Data.format(shownCoins.Value)
end)

local data = Data.new(player, function(key, value, old)
	if key == "Coins" then
		if old == nil then
			shownCoins.Value = value
			coins.value.Text = Data.format(value)
		else
			Anim.tween(shownCoins, Theme.Time.Count, {Value = value}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, "count", function()
				coins.value.Text = Data.format(value)
			end)
			if value > old then
				Anim.pop(coins.iconScale, 1.2)
				Anim.flash(coins.shine, "ImageTransparency", 0.1)
			end
		end
	elseif key == "SpeedLevel" then
		-- Just the upgraded speed amount, no word in front.
		speed.value.Text = Data.format(math.max(0, value))
		if old ~= nil and value > old then
			Anim.pop(speed.valueScale, 1.3)
			Anim.wiggle(speed.icon, 16)
			Anim.flash(speed.shine, "ImageTransparency", 0.2)
		end
	end
end)

---------------------------------------------------------------- layout
-- Pixel layout from the safe area: groups keep their reference proportions,
-- scale with the screen and never overlap. Counters sit bottom-left and the
-- fish/eggs buttons bottom-right; on very narrow screens both shrink to fit side by side.
local function layout()
	local area = root.AbsoluteSize
	if area.X < 1 or area.Y < 1 then return end
	local w, h = area.X, area.Y
	local s = math.clamp(math.min(w / S.Reference.X, h / S.Reference.Y), 0.4, 1.3)
	local side = math.max(10, S.Left * s)
	local bottom = math.max(8, S.Bottom * s)
	local bs = math.min(s, (w - 2 * side - 16) / (COUNTERS_W + S.InventoryW))
	counterScale.Scale = bs
	local countersTop = h - bottom - COUNTERS_H * bs
	counters.Position = UDim2.fromOffset(math.floor(side), math.floor(countersTop))
	collectionScale.Scale = bs
	local collectionTop = h - bottom - S.InventoryH * bs
	collection.Position = UDim2.fromOffset(math.floor(w - side - S.InventoryW * bs), math.floor(collectionTop))
	-- Pen menus open right above the Рыбы / Яйца buttons, inside the screen.
	local menuScale = math.min(bs * 1.15, (w - 2 * side) / 482, (collectionTop - 20) / 432)
	penMenu:place(UDim2.fromOffset(math.floor(w - side), math.floor(collectionTop - 10)), math.max(0.3, menuScale))
	local top = math.max(8, S.Top * s)

	-- Inventory: the backpack + hotbar row sits between the counters and the
	-- fish/eggs buttons; if it does not fit there, it goes above them.
	local slot, rowW = InventoryController.Slot, InventoryController.RowW
	local leftLimit = side + COUNTERS_W * bs + 16
	local rightLimit = w - side - S.InventoryW * bs - 16
	local hs, rowX, rowY = bs, 0, 0
	local wide = rowW * bs <= rightLimit - leftLimit
	if wide then
		rowX = math.clamp(w / 2 - rowW * hs / 2, leftLimit, rightLimit - rowW * hs)
		rowY = h - bottom - slot * hs
	else
		hs = math.min(bs * 1.2, (w - 2 * side) / rowW)
		rowX = (w - rowW * hs) / 2
		rowY = math.min(countersTop, collectionTop) - 10 - slot * hs
	end
	-- Left buttons use the space above the counters (and above the row when it is raised).
	local navFloor = wide and countersTop or math.min(countersTop, rowY)
	local available = navFloor - top - 18
	local ns = math.clamp(math.min(s * 1.05, available / NAV_H), 0.3, 1.3)
	navScale.Scale = ns
	local navTop = math.floor(math.max(8, math.min(top, navFloor - 18 - NAV_H * ns)))
	navigation.Position = UDim2.fromOffset(math.floor(side), navTop)
	local navRight = side + S.ButtonW * ns
	-- Closed: the backpack and 5 quick slots, centred (so the backpack sits a bit left of the middle).
	local closedW = InventoryController.ClosedRowW * hs
	local closedX = math.clamp(w / 2 - closedW / 2, wide and leftLimit or side, math.max(side, (wide and rightLimit or (w - side)) - closedW))
	local closedFitsBottom = closedX >= leftLimit and closedX + closedW <= rightLimit
	local closedY = closedFitsBottom and (h - bottom - slot * hs) or rowY
	-- Window above the row, clear of the left buttons and of the bottom groups.
	local x0 = wide and math.max(leftLimit, navRight + 12) or (navRight + 12)
	local x1 = wide and rightLimit or (w - side)
	local y1 = rowY - 16
	local panelScale = math.max(0.2, math.min(1.15, (x1 - x0) / InventoryController.PanelW, (y1 - top) / InventoryController.PanelH))
	local panelW, panelH = InventoryController.PanelW * panelScale, InventoryController.PanelH * panelScale
	inventory:applyLayout({
		scale = hs,
		backpackClosed = UDim2.fromOffset(math.floor(closedX), math.floor(closedY)),
		hotbarClosed = UDim2.fromOffset(math.floor(closedX + (slot + InventoryController.Gap) * hs), math.floor(closedY)),
		backpackOpen = UDim2.fromOffset(math.floor(rowX), math.floor(rowY)),
		hotbar = UDim2.fromOffset(math.floor(rowX + (slot + InventoryController.Gap) * hs), math.floor(rowY)),
		panel = UDim2.fromOffset(math.floor(x0 + (x1 - x0 - panelW) / 2), math.floor(y1 - panelH)),
		panelScale = panelScale,
	})
	-- Menus shrink to fit small screens (the window's own UIScale is used by the open animation).
	local menuFit = math.min(1, (w - 24) / S.MenuW, (h - 24) / (S.MenuH + 10))
	for _, entry in menus.windows do
		entry.fit.Scale = menuFit
		entry.window.Size = UDim2.fromOffset(S.MenuW * menuFit, (S.MenuH + 10) * menuFit)
	end
end
connect(root:GetPropertyChangedSignal("AbsoluteSize"), layout)
data:start()

connect(gui.Destroying, function()
	data:destroy()
	menus:destroy()
	inventory:destroy()
	penMenu:destroy()
	Anim.cancelAll()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
end)
layout()
