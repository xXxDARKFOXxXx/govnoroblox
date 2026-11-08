-- OceanHUD (HUDController) | LocalScript in StarterPlayer > StarterPlayerScripts.
-- Child ModuleScripts: UITheme, UIAssets, UIComponents, UIAnimations,
-- UIDataController, MenuController.
--
-- Layout follows the 1648x928 reference: four candy buttons top-left,
-- coins + speed bottom-left, XP panel bottom-centre. The ScreenGui is built
-- once; data changes only update text, fills and animations.
local Players = game:GetService("Players")

local Theme = require(script.UITheme)
local Assets = require(script.UIAssets)
local C = require(script.UIComponents)
local Anim = require(script.UIAnimations)
local Data = require(script.UIDataController)
local MenuController = require(script.MenuController)

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
gui:SetAttribute("Version", "3.0.0")
gui:SetAttribute("UseExternalMenus", false)
local openMenuEvent = C.new("BindableEvent", gui, {Name = "OpenMenu"})
local clickSound = C.new("Sound", gui, {Name = "ClickSound", SoundId = Assets.ClickSound, Volume = 0.6})
local root = C.holder(gui, "SafeArea", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))

local menus = MenuController.new(root, openMenuEvent, clickSound)

---------------------------------------------------------------- left buttons
local NAV_H = S.ButtonH * 4 + S.ButtonGap * 3
local navigation = C.holder(root, "Navigation", UDim2.fromOffset(S.Left, S.Top), UDim2.fromOffset(S.ButtonW, NAV_H))
local navScale = C.new("UIScale", navigation, {Scale = 1})
-- One candy button: glow, volumetric plate, white rim, picture icon, caption.
local function makeSlot(parent, spec, position, captionSize)
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
	for _, connection in Anim.bindButton({button = button, scale = scale, rim = rim, glow = glow, sound = clickSound}, function()
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
speed.value.Text = "Уровень 1"

---------------------------------------------------------------- fish & eggs (bottom-right)
local inventory = C.holder(root, "Inventory", UDim2.fromOffset(0, 0), UDim2.fromOffset(S.InventoryW, S.InventoryH))
local inventoryScale = C.new("UIScale", inventory, {Scale = 1})
for i, spec in Theme.Inventory do
	makeSlot(inventory, spec, UDim2.fromOffset((i - 1) * (S.ButtonW + S.InventoryGap), 0), 26)
end

---------------------------------------------------------------- XP panel
local xp = C.holder(root, "LevelProgress", UDim2.fromOffset(0, 0), UDim2.fromOffset(S.XPW, S.XPH))
local xpScale = C.new("UIScale", xp, {Scale = 1})
local PANEL_X, PANEL_W, PANEL_Y, PANEL_H = 0, S.XPW, 30, 78
local _, panel = C.plate(xp, "Panel", UDim2.fromOffset(PANEL_X, PANEL_Y), UDim2.fromOffset(PANEL_W, PANEL_H), {
	top = Theme.XP.top, bottom = Theme.XP.bottom, rim = Theme.XP.rim, rimThickness = 3.5, glow = Theme.XP.glow, radius = 0.5,
}, 1)
local TRACK_X, TRACK_W = 26, PANEL_W - 26 - 108
C.label(panel, "Title", "Опыт (XP)", {
	Position = UDim2.fromOffset(TRACK_X, 3), Size = UDim2.fromOffset(TRACK_W, 28), TextSize = 23, ZIndex = 6,
})
local track = C.frame(panel, "Track", {
	Position = UDim2.fromOffset(TRACK_X, 34), Size = UDim2.fromOffset(TRACK_W, 32),
	BackgroundColor3 = Theme.XP.track, ZIndex = 4,
})
C.corner(track, 0.5)
C.stroke(track, Color3.fromRGB(4, 8, 30), 2.5)
local fillClip = C.holder(track, "FillClip", UDim2.fromOffset(3, 3), UDim2.new(1, -6, 1, -6), 5)
fillClip.ClipsDescendants = true
C.corner(fillClip, 0.5)
local fill = C.frame(fillClip, "BlueFill", {Size = UDim2.fromScale(0, 1), Visible = false, ZIndex = 5})
C.corner(fill, 0.5)
C.gradient(fill, Theme.XP.fillTop, Theme.XP.fillBottom)
-- Diagonal stripes as a tiled image: rotated frames would not be clipped by Roblox.
fill.ClipsDescendants = true
local stripes = C.image(fill, "Stripes", "Stripes", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 6)
stripes.ScaleType = Enum.ScaleType.Tile
stripes.TileSize = UDim2.fromOffset(26, 26)
local fillGloss = C.frame(fill, "Gloss", {Position = UDim2.fromOffset(5, 2), Size = UDim2.new(1, -10, 0.38, 0), BackgroundTransparency = 0.5, ZIndex = 7})
C.corner(fillGloss, 0.5)
local innerGlow = C.holder(track, "InnerGlow", UDim2.fromOffset(1, 1), UDim2.new(1, -2, 1, -2), 8)
C.corner(innerGlow, 0.5)
C.stroke(innerGlow, Theme.XP.rim, 1.5, 0.55)
local progressText = C.label(track, "ProgressText", "0 / 10,000 XP", {Size = UDim2.fromScale(1, 1), TextSize = 20, ZIndex = 9})

-- Level star at the right end (crown-sized): current level inside, caption below.
local badge = C.holder(xp, "LevelBadge", UDim2.fromOffset(PANEL_X + PANEL_W - 110, 0), UDim2.fromOffset(110, 106), 10)
local starHolder = C.holder(badge, "StarHolder", UDim2.new(0.5, -36, 0, 0), UDim2.fromOffset(72, 72), 11)
local badgeScale = C.new("UIScale", starHolder, {Scale = 1})
local starFlash = C.image(starHolder, "Flash", "Sparkle", UDim2.fromOffset(-34, -34), UDim2.fromOffset(140, 140), 10)
starFlash.ImageTransparency = 1
C.image(starHolder, "Star", "LevelStar", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 11)
local levelText = C.label(starHolder, "Level", "1", {Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 32), TextSize = 30, ZIndex = 12})
C.label(badge, "Caption", "Уровень", {Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 24), TextSize = 20, ZIndex = 12})
for _, spot in {{6, 10, 18}, {90, 4, 22}} do
	C.image(badge, "Sparkle", "Sparkle", UDim2.fromOffset(spot[1], spot[2]), UDim2.fromOffset(spot[3], spot[3]), 12)
end

---------------------------------------------------------------- data binding
local shownCoins = C.new("NumberValue", gui, {Name = "ShownCoins", Value = 0})
connect(shownCoins:GetPropertyChangedSignal("Value"), function()
	coins.value.Text = Data.format(shownCoins.Value)
end)
local currentFraction = 0
local pendingLevelUp = false
local data

local function setFill(fraction)
	fill.Visible = fraction > 0
	fill.Size = UDim2.fromScale(fraction, 1)
end
local function showProgress()
	local xpValue = math.max(0, data:get("XP"))
	local required = data:get("XPRequired")
	if required > 0 then
		progressText.Text = Data.format(xpValue) .. " / " .. Data.format(required) .. " XP"
	else
		progressText.Text = "МАКС. УРОВЕНЬ"
	end
	local fraction = required > 0 and math.clamp(xpValue / required, 0, 1) or 1
	if fraction == currentFraction and not pendingLevelUp then return end
	if pendingLevelUp then
		-- Finish the old bar, then carry the leftover progress into the new level.
		pendingLevelUp = false
		fill.Visible = true
		Anim.tween(fill, Theme.Time.Fill * 0.6, {Size = UDim2.fromScale(1, 1)}, nil, nil, "fill", function()
			setFill(0)
			fill.Visible = fraction > 0
			Anim.tween(fill, Theme.Time.Fill, {Size = UDim2.fromScale(fraction, 1)}, nil, nil, "fill")
		end)
	else
		fill.Visible = fraction > 0 or currentFraction > 0
		Anim.tween(fill, Theme.Time.Fill, {Size = UDim2.fromScale(fraction, 1)}, nil, nil, "fill", function()
			fill.Visible = fraction > 0
		end)
	end
	currentFraction = fraction
end

data = Data.new(player, function(key, value, old)
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
		speed.value.Text = "Уровень " .. Data.format(math.max(1, value))
		if old ~= nil and value > old then
			Anim.pop(speed.valueScale, 1.3)
			Anim.wiggle(speed.icon, 16)
			Anim.flash(speed.shine, "ImageTransparency", 0.2)
		end
	elseif key == "Level" then
		levelText.Text = Data.format(math.max(1, math.floor(value)))
		if old ~= nil and value > old then
			pendingLevelUp = true
			Anim.pop(badgeScale, 1.22)
			Anim.flash(starFlash, "ImageTransparency", 0)
		end
		showProgress()
	else -- XP / XPRequired
		showProgress()
	end
end)

---------------------------------------------------------------- layout
-- Pixel layout from the safe area: groups keep their reference proportions,
-- scale with the screen and never overlap. Narrow screens stack the counters
-- (left) and fish/eggs buttons (right) above the XP panel.
local function layout()
	local area = root.AbsoluteSize
	if area.X < 1 or area.Y < 1 then return end
	local w, h = area.X, area.Y
	local s = math.clamp(math.min(w / S.Reference.X, h / S.Reference.Y), 0.4, 1.3)
	local side = math.max(10, S.Left * s)
	local bottom = math.max(8, S.Bottom * s)
	local leftEdge = side + COUNTERS_W * s + 16
	local rightEdge = w - side - S.InventoryW * s - 16
	local stacked = w / 2 - S.XPW * s / 2 < leftEdge or w / 2 + S.XPW * s / 2 > rightEdge
	local xs = stacked and math.min(s * 1.1, (w - 2 * side) / S.XPW) or s
	xpScale.Scale = xs
	local xpTop = h - S.XPH * xs - bottom
	xp.Position = UDim2.fromOffset(math.floor((w - S.XPW * xs) / 2), math.floor(xpTop))
	counterScale.Scale = s
	local countersBottom = stacked and (xpTop - 6) or (h - bottom)
	local countersTop = countersBottom - COUNTERS_H * s
	counters.Position = UDim2.fromOffset(math.floor(side), math.floor(countersTop))
	inventoryScale.Scale = s
	local inventoryBottom = stacked and (xpTop - 6) or (h - bottom)
	inventory.Position = UDim2.fromOffset(math.floor(w - side - S.InventoryW * s), math.floor(inventoryBottom - S.InventoryH * s))
	local top = math.max(8, S.Top * s)
	local available = countersTop - top - 18
	local ns = math.clamp(math.min(s * 1.05, available / NAV_H), 0.3, 1.3)
	navScale.Scale = ns
	navigation.Position = UDim2.fromOffset(math.floor(side), math.floor(math.max(8, math.min(top, countersTop - 18 - NAV_H * ns))))
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
	Anim.cancelAll()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
end)
layout()
