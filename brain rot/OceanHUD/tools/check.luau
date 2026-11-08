-- Offline contract test for the OceanHUD scripts, using Roblox data types and
-- event doubles. Not a Studio play test (see README for the Studio check).
-- Run from the OceanHUD folder:  ..\..\tools\lune\lune.exe run tools/check.luau
local fs = require("@lune/fs")
local r = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local process = require("@lune/process")
local rootPath = process.cwd:gsub("\\", "/"):gsub("/?$", "/")

local signals, tests = {}, {}
local function signal()
	local entries = {}
	return {
		Connect = function(_, callback)
			local entry = {connected = true, callback = callback}
			table.insert(entries, entry)
			return {Disconnect = function() entry.connected = false end}
		end,
		Fire = function(_, ...)
			for _, entry in table.clone(entries) do
				if entry.connected then entry.callback(...) end
			end
		end,
	}
end
local function event(object, key)
	signals[object] = signals[object] or {}
	signals[object][key] = signals[object][key] or signal()
	return signals[object][key]
end
for class, names in {
	Instance = {"ChildAdded", "ChildRemoved", "Destroying"},
	GuiObject = {"MouseEnter", "MouseLeave", "SelectionGained", "SelectionLost"},
	GuiButton = {"Activated"}, UserInputService = {"InputBegan"}, BindableEvent = {"Event"},
} do
	for _, name in names do r.implementProperty(class, name, function(object) return event(object, name) end) end
end
r.implementMethod("Instance", "WaitForChild", function(object, name) return assert(object:FindFirstChild(name), name) end)
r.implementMethod("Instance", "GetPropertyChangedSignal", function(object, name) return event(object, "property:" .. name) end)
r.implementMethod("Instance", "GetAttributeChangedSignal", function(object, name) return event(object, "attribute:" .. name) end)
r.implementMethod("BindableEvent", "Fire", function(object, ...) event(object, "Event"):Fire(...) end)
local soundPlays = 0
r.implementMethod("Sound", "Play", function() soundPlays += 1 end)
-- Tweens finish instantly: properties are applied, change signals and Completed fire.
local tweenCount = 0
r.implementMethod("TweenService", "Create", function(_, object, _, props)
	local completed = signal()
	return {
		Completed = completed,
		Play = function()
			tweenCount += 1
			for key, value in props do
				object[key] = value
				event(object, "property:" .. key):Fire()
			end
			completed:Fire(r.Enum.PlaybackState.Completed)
		end,
		Cancel = function() end,
	}
end)

local screen = r.Vector2.new(1648, 928)
local game = r.Instance.new("DataModel")
local player = r.Instance.new("Player")
player.Name = "HUDTest"
player.Parent = game:GetService("Players")
game:GetService("Players").LocalPlayer = player
local playerGui = r.Instance.new("PlayerGui")
playerGui.Parent = player

-- Script tree exactly like the build: LocalScript with ModuleScript children.
local MODULES = {"UITheme", "UIAssets", "UIComponents", "UIAnimations", "UIDataController", "MenuController"}
local hudScript = r.Instance.new("LocalScript")
hudScript.Name = "OceanHUD"
hudScript.Source = fs.readFile(rootPath .. "src/OceanHUD.client.luau")
for _, name in MODULES do
	local module = r.Instance.new("ModuleScript")
	module.Name = name
	module.Source = fs.readFile(rootPath .. "src/modules/" .. name .. ".luau")
	module.Parent = hudScript
end

local cache = {}
local function makeEnv(scriptInstance)
	local env = {game = game, script = scriptInstance, TweenInfo = {new = function() return {} end}}
	for _, key in {"Vector2", "Vector3", "CFrame", "Color3", "UDim", "UDim2", "Enum", "ColorSequence", "NumberSequence"} do env[key] = r[key] end
	env.Instance = {new = function(class)
		local object = r.Instance.new(class)
		if object:IsA("GuiObject") then object.AbsoluteSize = screen end
		return object
	end}
	env.require = function(module)
		if cache[module] == nil then
			cache[module] = luau.load(module.Source, {debugName = module.Name, environment = makeEnv(module)})()
		end
		return cache[module]
	end
	return env
end
local function run()
	table.clear(cache)
	luau.load(hudScript.Source, {debugName = "OceanHUD", environment = makeEnv(hudScript)})()
end
run()

local function check(condition, name)
	assert(condition, name)
	table.insert(tests, name)
end
local function attr(name, value)
	player:SetAttribute(name, value)
	event(player, "attribute:" .. name):Fire()
end

local gui = playerGui.OceanHUD
local root = gui.SafeArea
local nav = root.Navigation
local counters = root.Counters
local coinsValue = counters.CoinsCounter.Body.Value
local speedValue = counters.SpeedCounter.Body.Value
local xp = root.LevelProgress
local track = xp.Panel.Body.Track
local fill = track.FillClip.BlueFill
local levelText = xp.LevelBadge.Level
local nextText = xp.NextLevel.NextLevelText

-- Structure and images
check(#nav:GetChildren() == 5, "Four button slots plus one UIScale")
local order = {}
for _, child in nav:GetChildren() do
	if child:IsA("Frame") then order[child.Position.Y.Offset] = child.Name end
end
check(order[0] == "RebirthSlot" and order[118] == "GiftsSlot" and order[236] == "ShopSlot" and order[354] == "IndexSlot", "Buttons in reference order")
local images = {}
for _, object in gui:GetDescendants() do
	if object:IsA("ImageLabel") then images[object.Image] = true end
end
for _, name in {"Rebirth", "Gifts", "Shop", "Index", "Coin", "Speed", "LevelStar", "Crown", "Sparkle", "Stripes"} do
	check(images["rbxasset://textures/OceanHUD/" .. name .. ".png"], "Uses icon image " .. name)
	check(fs.isFile(rootPath .. "assets/" .. name .. ".png"), "Icon file exists " .. name)
end
for _, object in gui:GetDescendants() do
	if object:IsA("ImageLabel") then
		assert(not string.find(object.Image, "rbxassetid://"), "No invented asset IDs")
	end
end
check(true, "No invented asset IDs")
check(nav.ShopSlot.Plate.Body.Caption.Text == "Магазин", "Captions on buttons")

-- Defaults
check(coinsValue.Text == "0" and speedValue.Text == "Уровень 1", "Defaults for counters")
check(levelText.Text == "1" and nextText.Text == "Уровень 2", "Default level badge and crown")
check(track.ProgressText.Text == "0 / 10,000 XP" and not fill.Visible, "Empty XP bar")

-- Reference values
attr("Coins", 125430); attr("SpeedLevel", 18); attr("Level", 24); attr("XPRequired", 10000); attr("XP", 7850)
check(coinsValue.Text == "125,430", "Coins 125,430")
check(speedValue.Text == "Уровень 18", "Speed Уровень 18")
check(levelText.Text == "24" and nextText.Text == "Уровень 25", "Star 24, crown Уровень 25")
check(track.ProgressText.Text == "7,850 / 10,000 XP", "XP text 7,850 / 10,000 XP")
check(fill.Visible and math.abs(fill.Size.X.Scale - 0.785) < 1e-6, "XP fill 78.5%")

-- Animated updates
local before = tweenCount
attr("Coins", 130000)
check(coinsValue.Text == "130,000" and tweenCount > before, "Coins count up through a tween")
check(counters.CoinsCounter.Icon.UIScale.Scale == 1 and counters.CoinsCounter.Shine.ImageTransparency == 1, "Coin bounce and shine settle")
attr("Coins", 2.5e9 + 0.5) -- Lune stores whole attributes as int32; Roblox uses doubles
check(coinsValue.Text == "2.5B", "Huge values are shortened")
attr("Coins", 125430)
attr("SpeedLevel", 19)
check(speedValue.Text == "Уровень 19" and counters.SpeedCounter.Icon.Rotation == 0, "Speed level-up pops and settles")
attr("Speed", 99)
check(speedValue.Text == "Уровень 19", "SpeedLevel wins over Speed alias")
-- Level up with progress carried over (server writes Level, XPRequired, XP).
attr("Level", 25); attr("XPRequired", 10375); attr("XP", 500)
check(levelText.Text == "25" and nextText.Text == "Уровень 26", "Level-up updates star and crown")
check(math.abs(fill.Size.X.Scale - 500 / 10375) < 1e-6, "Leftover XP carried into the new level")
check(xp.LevelBadge.UIScale.Scale == 1 and xp.LevelBadge.Flash.ImageTransparency == 1, "Star bounce and flash settle")
attr("XP", 99999)
check(fill.Size.X.Scale == 1, "Overflow clamps to full")
attr("XP", -5)
check(fill.Size.X.Scale == 0 and not fill.Visible, "Negative XP clamps to empty")
attr("XPRequired", 0)
check(track.ProgressText.Text == "МАКС. УРОВЕНЬ" and fill.Size.X.Scale == 1, "Max level")
attr("XPRequired", 10000); attr("XP", 7850); attr("Level", 24)

-- leaderstats fallback
attr("Coins", nil)
local stats = r.Instance.new("Folder"); stats.Name = "leaderstats"; stats.Parent = player
local coins = r.Instance.new("IntValue"); coins.Name = "Coins"; coins.Value = 500; coins.Parent = stats
event(player, "ChildAdded"):Fire(stats)
check(coinsValue.Text == "500", "Late leaderstats are discovered")
coins.Value = 750; event(coins, "property:Value"):Fire()
check(coinsValue.Text == "750", "leaderstats changes refresh")
coins.Parent = nil; event(stats, "ChildRemoved"):Fire(coins)
check(coinsValue.Text == "0", "Removed values do not remain stale")
attr("Coins", 125430)

-- Buttons and menus
local backdrop = root.MenuBackdrop
local function press(key) event(nav[key .. "Slot"][key], "Activated"):Fire() end
local function shown(key) return backdrop[key .. "Menu"].Visible and backdrop[key .. "Menu"].GroupTransparency == 0 end
local plays = soundPlays
press("Shop")
check(backdrop.Visible and shown("Shop"), "Shop opens with fade + scale")
check(backdrop.ShopMenu.UIScale.Scale == 1, "Open animation ends at full size")
check(soundPlays == plays + 1, "Click sound plays")
check(nav.ShopSlot.UIScale.Scale == 1, "Press shrink returns to normal size")
press("Shop")
check(not backdrop.Visible and not backdrop.ShopMenu.Visible, "Pressing the same button closes the menu")
press("Gifts"); press("Index")
check(shown("Index") and not backdrop.GiftsMenu.Visible, "Only one menu open at a time")
event(backdrop.IndexMenu.Panel.Body.Close, "Activated"):Fire()
check(not backdrop.Visible, "Close button closes")
press("Rebirth"); event(backdrop, "Activated"):Fire()
check(not backdrop.Visible, "Backdrop click closes")
check(backdrop.RebirthMenu.Panel.Body.Content:IsA("ScrollingFrame"), "Menus have a Content container")
event(nav.IndexSlot.Index, "MouseEnter"):Fire()
check(math.abs(nav.IndexSlot.UIScale.Scale - 1.07) < 1e-4 and nav.IndexSlot.HoverGlow.BackgroundTransparency < 1, "Hover grows and glows")
event(nav.IndexSlot.Index, "MouseLeave"):Fire()
check(nav.IndexSlot.UIScale.Scale == 1 and nav.IndexSlot.HoverGlow.BackgroundTransparency == 1, "Hover ends")
local requests = {}
event(gui.OpenMenu, "Event"):Connect(function(key) table.insert(requests, key) end)
gui:SetAttribute("UseExternalMenus", true)
press("Gifts")
check(requests[#requests] == "Gifts" and not backdrop.Visible, "External menu mode only fires OpenMenu")
gui:SetAttribute("UseExternalMenus", false)
run()
check(#playerGui:GetChildren() == 1, "Running twice does not duplicate the HUD")

-- Layout at desktop, tablet and phone sizes
local function box(object, w, h)
	local s = object.UIScale.Scale
	local x, y = object.Position.X.Offset, object.Position.Y.Offset
	return {x = x, y = y, r = x + w * s, b = y + h * s}
end
local function apart(a, b) return a.r <= b.x or b.r <= a.x or a.b <= b.y or b.b <= a.y end
local function inside(a, w, h) return a.x >= 0 and a.y >= 0 and a.r <= w + 0.5 and a.b <= h + 0.5 end
local layoutReport = {}
local sizes = {{1648, 928}, {1920, 1020}, {1920, 1140}, {1440, 840}, {1280, 660}, {1024, 708}, {844, 330}, {600, 330}, {390, 784}, {360, 580}}
for _, d in sizes do
	local w, h = d[1], d[2]
	screen = r.Vector2.new(w, h)
	root.AbsoluteSize = screen
	event(root, "property:AbsoluteSize"):Fire()
	local n = box(nav, 112, 106 * 4 + 36)
	local c = box(counters, 362, 190)
	local x = box(xp, 560, 116)
	local tag = w .. "x" .. h
	check(inside(n, w, h) and inside(c, w, h) and inside(x, w, h), "All groups on screen at " .. tag)
	check(apart(n, c) and apart(c, x) and apart(n, x), "No overlap at " .. tag)
	check(nav.UIScale.Scale >= 0.3, "Buttons stay usable at " .. tag)
	table.insert(layoutReport, {size = tag, nav = n, counters = c, xp = x})
end
screen = r.Vector2.new(1648, 928); root.AbsoluteSize = screen; event(root, "property:AbsoluteSize"):Fire()
check(nav.Position.X.Offset == 35 and counters.Position.X.Offset == 35, "Reference left margin 35 px")
check(math.abs(nav.UIScale.Scale - 1) < 0.06 and xp.UIScale.Scale == 1, "Reference size at 1648x928")

-- Cleanup
event(gui, "Destroying"):Fire()
local last = coinsValue.Text
attr("Coins", 1)
check(coinsValue.Text == last, "Cleanup disconnects data subscriptions")

-- Server stats module: level carry-over
local statsModule = luau.load(fs.readFile(rootPath .. "src/server/OceanHUDStats.luau"), {debugName = "OceanHUDStats"})()
local p = r.Instance.new("Player")
statsModule.init(p, {Coins = 125430, SpeedLevel = 18, Level = 24, XP = 7850})
check(p:GetAttribute("XPRequired") == 10000, "Server: level 24 needs 10,000 XP")
statsModule.addXP(p, 3000)
check(p:GetAttribute("Level") == 25 and p:GetAttribute("XP") == 850 and p:GetAttribute("XPRequired") == 10375, "Server: addXP carries leftover into level 25")
statsModule.addXP(p, 30000)
check(p:GetAttribute("Level") == 27, "Server: addXP can pass several levels")
statsModule.addCoins(p, -999999)
check(p:GetAttribute("Coins") == 0, "Server: coins never go negative")

fs.writeFile(rootPath .. "test-report.json", serde.encode("json", {passed = true, count = #tests, tests = tests, layout = layoutReport, studioPlayTest = false}, true))
print("PASS: " .. #tests .. " checks")
