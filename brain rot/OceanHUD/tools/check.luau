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
r.implementMethod("TextBox", "ReleaseFocus", function() end)
r.implementProperty("Instance", "AttributeChanged", function(object) return event(object, "AttributeChanged") end)
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
player.UserId = 777
player.Parent = game:GetService("Players")
game:GetService("Players").LocalPlayer = player
local playerGui = r.Instance.new("PlayerGui")
playerGui.Parent = player

-- Script tree exactly like the build: LocalScript with ModuleScript children.
local MODULES = {"UITheme", "UIAssets", "UIComponents", "UIAnimations", "UIDataController", "MenuController", "InventoryController", "PenMenuController"}
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
	local env = {game = game, script = scriptInstance, workspace = game:GetService("Workspace"), TweenInfo = {new = function() return {} end},
		task = {spawn = function() end, wait = function() return 0 end, defer = function(f, ...) f(...) end, delay = function() end}}
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
for _, name in {"Rebirth", "Gifts", "Shop", "Index", "Coin", "Flippers", "SharkFin", "Egg", "Sparkle", "Backpack"} do
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
check(coinsValue.Text == "0" and speedValue.Text == "0", "Defaults for counters")
check(root:FindFirstChild("LevelProgress") == nil, "No XP bar on screen")
local hasXPText = false
for _, object in gui:GetDescendants() do
	if object:IsA("TextLabel") and (object.Text:find("XP") or object.Text:find("Опыт")) then hasXPText = true end
end
check(not hasXPText, "No XP text anywhere")

-- Reference values
attr("Coins", 125430); attr("SpeedLevel", 18)
check(coinsValue.Text == "125,430", "Coins 125,430")
check(speedValue.Text == "18", "Speed shows only the number 18")

-- Animated updates
local before = tweenCount
attr("Coins", 130000)
check(coinsValue.Text == "130,000" and tweenCount > before, "Coins count up through a tween")
check(counters.CoinsCounter.Icon.UIScale.Scale == 1 and counters.CoinsCounter.Shine.ImageTransparency == 1, "Coin bounce and shine settle")
attr("Coins", 2.5e9 + 0.5) -- Lune stores whole attributes as int32; Roblox uses doubles
check(coinsValue.Text == "2.5B", "Huge values are shortened")
attr("Coins", 125430)
attr("SpeedLevel", 1250)
check(speedValue.Text == "1,250" and counters.SpeedCounter.Icon.Rotation == 0, "Speed upgrade pops, settles, uses separators")
attr("Speed", 99)
check(speedValue.Text == "1,250", "SpeedLevel wins over Speed alias")
attr("SpeedLevel", 18)


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
local col = root.Collection
check(col.FishSlot.Plate.Body.Caption.Text == "Рыбы" and col.EggsSlot.Plate.Body.Caption.Text == "Яйца", "Fish and Eggs buttons bottom-right")
check(col.FishSlot.Plate.Body.Icon.Image:find("SharkFin") and col.EggsSlot.Plate.Body.Icon.Image:find("Egg"), "Shark fin and egg icons")

-- Inventory
local uis = game:GetService("UserInputService")
local function key(code) event(uis, "InputBegan"):Fire({KeyCode = code}, false) end
local backpack = root.Backpack
local hotbar = root.Hotbar
local panel = root.InventoryPanel
local main = panel.Main
check(backpack.Button.Key.Text == "[G]" and backpack.Button.Icon.Image:find("Backpack"), "Closed inventory: backpack with [G]")
check(not panel.Visible and not hotbar.Visible, "Closed: no window, no hotbar")
check(main.Empty.Visible and main.Empty.Text == "Здесь пока ничего нет", "Empty inventory message")
local tabNames = {}
for _, spec in {"All", "Eggs", "Fish"} do tabNames[#tabNames + 1] = panel[spec .. "Tab"].Caption.Text end
check(table.concat(tabNames, ",") == "Все,Яйца,Рыбы" and panel:FindFirstChild("FoodTab") == nil, "Tabs Все / Яйца / Рыбы, no Еда")
check(panel.FishTab.Icon.Image:find("SharkFin") and panel.AllTab.Icon.Image:find("Backpack"), "Tab icons")
check(main.Search.PlaceholderText == "Поиск", "Search box")
for i = 1, 8 do assert(hotbar["Slot" .. i].Number.Text == tostring(i)) end
check(true, "Hotbar slots numbered 1-8")
key(r.Enum.KeyCode.G)
check(panel.Visible and panel.GroupTransparency == 0 and hotbar.Visible, "G opens the inventory")
check(backpack.Button.UIStroke.Color == r.Color3.new(1, 1, 1), "Open backpack slot is outlined white")
check(backpack.Position.X.Offset < hotbar.Position.X.Offset, "Backpack moves to the start of the hotbar")
-- CanvasGroups clip their contents: every outlined tile must keep its whole
-- outline (drawn outside the frame) inside the group, on all four sides.
for _, group in {hotbar, panel} do
	local gw, gh = group.Size.X.Offset, group.Size.Y.Offset
	for _, child in group:GetChildren() do
		local outline = child:IsA("GuiObject") and child:FindFirstChildOfClass("UIStroke")
		if outline then
			local x, y = child.Position.X.Offset, child.Position.Y.Offset
			local t = outline.Thickness
			local ok = x >= t and y >= t and x + child.Size.X.Offset + t <= gw and y + child.Size.Y.Offset + t <= gh
			check(ok, "Outline not clipped: " .. group.Name .. "." .. child.Name)
		end
	end
end
local gridPad = main.Grid.UIPadding
check(gridPad.PaddingTop.Offset >= 3 and gridPad.PaddingLeft.Offset >= 3 and gridPad.PaddingRight.Offset >= 3 and gridPad.PaddingBottom.Offset >= 3, "Item cards keep room for outlines in the scrolling grid")
-- Server-style items in Player.Inventory
local folder = r.Instance.new("Folder"); folder.Name = "Inventory"; folder.Parent = player
local function item(id, name, category, icon, count, slot)
	local f = r.Instance.new("Folder"); f.Name = id
	f:SetAttribute("DisplayName", name); f:SetAttribute("Category", category)
	f:SetAttribute("Icon", icon); f:SetAttribute("Count", count); f:SetAttribute("HotbarSlot", slot)
	f.Parent = folder
	return f
end
event(player, "ChildAdded"):Fire(folder)
item("BasicEgg", "Обычное яйцо", "Eggs", "Egg", 3, nil)
item("Shark", "Акула", "Fish", "SharkFin", 1, 1)
local apple = item("GoldEgg", "Золотое яйцо", "Eggs", "Egg", 5, 2)
event(folder, "ChildAdded"):Fire()
local function cards()
	local n = 0
	for _, child in main.Grid:GetChildren() do if child:IsA("Frame") then n += 1 end end
	return n
end
check(cards() == 3 and not main.Empty.Visible, "All tab shows every item")
check(main.Grid.Item_BasicEgg.Count.Text == "x3" and main.Grid.Item_BasicEgg.ItemName.Text == "Обычное яйцо", "Item card with name and count")
check(main.Grid.Item_Shark:FindFirstChild("Count") == nil, "Single items have no count badge")
check(hotbar.Slot1.Icon.Image:find("SharkFin") and hotbar.Slot2.Icon.Image:find("Egg") and hotbar.Slot3.Icon.Image == "", "Hotbar shows assigned items")
event(panel.EggsTab, "Activated"):Fire()
check(cards() == 2 and main.Grid:FindFirstChild("Item_BasicEgg") and main.Grid:FindFirstChild("Item_GoldEgg"), "Eggs tab filters")
check(panel.EggsTab.UIGradient.Enabled and not panel.AllTab.UIGradient.Enabled, "Selected tab is highlighted blue")
event(panel.FishTab, "Activated"):Fire()
check(cards() == 1 and main.Grid:FindFirstChild("Item_Shark"), "Fish tab filters")
event(panel.AllTab, "Activated"):Fire()
main.Search.Text = "ОБЫЧН"; event(main.Search, "property:Text"):Fire()
check(cards() == 1 and main.Grid:FindFirstChild("Item_BasicEgg"), "Search is case-insensitive in Russian")
main.Search.Text = "кит"; event(main.Search, "property:Text"):Fire()
check(cards() == 0 and main.Empty.Visible, "No matches shows the empty message")
main.Search.Text = ""; event(main.Search, "property:Text"):Fire()
apple:SetAttribute("Count", 6); event(apple, "AttributeChanged"):Fire("Count")
check(main.Grid.Item_GoldEgg.Count.Text == "x6", "Count updates live")
local picks = {}
root.HotbarSelected.Event:Connect(function(index, id) table.insert(picks, tostring(index) .. ":" .. tostring(id)) end)
key(r.Enum.KeyCode.One)
check(hotbar.Slot1.UIStroke.Color == r.Color3.new(1, 1, 1) and picks[#picks] == "1:Shark", "Key 1 selects slot 1")
key(r.Enum.KeyCode.One)
check(hotbar.Slot1.UIStroke.Color == r.Color3.new(0, 0, 0) and picks[#picks] == "nil:nil", "Pressing 1 again unselects")
event(hotbar.Slot2, "Activated"):Fire()
check(picks[#picks] == "2:GoldEgg", "Clicking a slot selects it")
key(r.Enum.KeyCode.G)
check(not panel.Visible and not hotbar.Visible, "G closes the inventory")
-- Pen menus (Рыбы / Яйца): a base owned by the player with one fish and one egg.
local serverNow = 5000
r.implementMethod("Workspace", "GetServerTimeNow", function() return serverNow end)
local sent = {}
r.implementMethod("RemoteEvent", "FireServer", function(_, ...) table.insert(sent, table.concat({...}, ":")) end)
local shared = r.Instance.new("Folder"); shared.Name = "OceanBases"; shared.Parent = game:GetService("ReplicatedStorage")
local configModule = r.Instance.new("ModuleScript"); configModule.Name = "BaseConfig"
configModule.Source = fs.readFile(rootPath .. "../OceanBases/src/shared/BaseConfig.luau"); configModule.Parent = shared
local remotes = r.Instance.new("Folder"); remotes.Name = "Remotes"; remotes.Parent = shared
local penRemote = r.Instance.new("RemoteEvent"); penRemote.Name = "PenAction"; penRemote.Parent = remotes
local basesFolder = r.Instance.new("Folder"); basesFolder.Name = "OceanBases"; basesFolder.Parent = game:GetService("Workspace")
local myBase = r.Instance.new("Model"); myBase.Name = "Base1"; myBase.Parent = basesFolder
myBase:SetAttribute("OwnerUserId", player.UserId)
local cellsFolder = r.Instance.new("Folder"); cellsFolder.Name = "Cells"; cellsFolder.Parent = myBase
local fishCell = r.Instance.new("Model"); fishCell.Name = "Cell3"; fishCell.Parent = cellsFolder
for k, v in {Index = 3, State = "Fish", FishType = "Clown", FishLevel = 2, Income = 5} do fishCell:SetAttribute(k, v) end
local eggCell = r.Instance.new("Model"); eggCell.Name = "Cell5"; eggCell.Parent = cellsFolder
for k, v in {Index = 5, State = "Egg", EggType = "TideEgg", HatchAt = serverNow + 75} do eggCell:SetAttribute(k, v) end
local penMenu = root.PenMenu
local menuBody = penMenu.Body
local function rows()
	local list = {}
	for _, child in menuBody.List:GetChildren() do if child:IsA("Frame") then table.insert(list, child) end end
	return list
end
attr("Coins", 10)
event(col.FishSlot.Fish, "Activated"):Fire()
check(penMenu.Visible and penMenu.GroupTransparency == 0 and not panel.Visible, "Рыбы opens the fish list (not the inventory)")
check(menuBody.Title.Text == "Мои рыбы · 1" and #rows() == 1, "Fish list shows the fish in the pen")
local fishRow = menuBody.List.Row3
check(fishRow.Title.Text == "Рыба-клоун" and fishRow.Info.Text == "Ур. 2 · +5/сек", "Fish row: name, level and income")
local cost = 5 * 30 * 1.6 -- Clown: base income 5, level 2
check(fishRow.Upgrade.Caption.Text == "↑ " .. tostring(math.floor(cost + 0.5)), "Upgrade price grows with the level")
event(fishRow.Upgrade, "Activated"):Fire()
check(#sent == 0, "Upgrade is disabled without enough coins")
attr("Coins", 100000)
fishRow = menuBody.List.Row3
event(fishRow.Upgrade, "Activated"):Fire()
check(sent[#sent] == "UpgradeFish:3", "Upgrade asks the server")
event(fishRow.Remove, "Activated"):Fire()
check(sent[#sent] == "RemoveFish:3", "Убрать asks the server to move the fish to the inventory")
fishCell:SetAttribute("FishLevel", 3); fishCell:SetAttribute("Income", 8)
event(fishCell, "AttributeChanged"):Fire("FishLevel")
check(menuBody.List.Row3.Info.Text == "Ур. 3 · +8/сек", "List updates live")
event(col.EggsSlot.Eggs, "Activated"):Fire()
check(menuBody.Title.Text == "Мои яйца · 1" and menuBody.List:FindFirstChild("Row5") and not menuBody.List:FindFirstChild("Row3"), "Яйца shows eggs waiting to hatch")
check(menuBody.List.Row5.Title.Text == "Яйцо прилива" and menuBody.List.Row5.Info.Text == "Вылупится через 1:15", "Egg row: name and time left")
local before = #sent
event(menuBody.List.Row5.Delete, "Activated"):Fire()
check(#sent == before and menuBody.List.Row5.Delete.Caption.Text == "Точно?", "Удалить asks to confirm first")
event(menuBody.List.Row5.Delete, "Activated"):Fire()
check(sent[#sent] == "DeleteEgg:5", "Second press deletes the egg")
event(col.EggsSlot.Eggs, "Activated"):Fire()
check(not penMenu.Visible, "Pressing Яйца again closes the menu")
event(col.FishSlot.Fish, "Activated"):Fire()
event(backpack.Button, "Activated"):Fire()
check(not penMenu.Visible and panel.Visible, "Inventory and pen menu close each other")
key(r.Enum.KeyCode.G)
fishCell:SetAttribute("State", "Empty")
event(col.FishSlot.Fish, "Activated"):Fire()
check(menuBody.Empty.Visible and #rows() == 0, "Empty pen shows a hint")
event(menuBody.Close, "Activated"):Fire()
check(not penMenu.Visible, "Close button closes the menu")
event(backpack.Button, "Activated"):Fire()
check(panel.Visible, "Clicking the backpack opens the inventory")
press("Shop")
check(not panel.Visible and shown("Shop"), "Opening a menu closes the inventory")
event(backpack.Button, "Activated"):Fire()
check(panel.Visible and not backdrop.Visible, "Opening the inventory closes the menu")
key(r.Enum.KeyCode.Escape)
check(not panel.Visible, "Escape closes the inventory")
check(counters.SpeedCounter.Icon.Image:find("Flippers"), "Speed uses the flippers icon")
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
	local inv = box(root.Collection, 238, 106)
	local tag = w .. "x" .. h
	check(inside(n, w, h) and inside(c, w, h) and inside(inv, w, h), "All groups on screen at " .. tag)
	check(apart(n, c) and apart(inv, c) and apart(inv, n), "No overlap at " .. tag)
	local closedBag = box(root.Backpack, 92, 92)
	check(inside(closedBag, w, h) and apart(closedBag, n) and apart(closedBag, c) and apart(closedBag, inv), "Closed backpack clear of other HUD at " .. tag)
	key(r.Enum.KeyCode.G)
	local bag, bar, win = box(root.Backpack, 92, 92), box(root.Hotbar, 804, 104), box(root.InventoryPanel, 1012, 512)
	local ok = inside(bag, w, h) and inside(bar, w, h) and inside(win, w, h) and apart(bag, bar) and apart(bar, win) and apart(bag, win)
	for _, other in {n, c, inv} do ok = ok and apart(bag, other) and apart(bar, other) and apart(win, other) end
	check(ok, "Open inventory clear of other HUD at " .. tag)
	check(root.InventoryPanel.UIScale.Scale >= 0.2, "Inventory window visible at " .. tag)
	key(r.Enum.KeyCode.G)
	check(nav.UIScale.Scale >= 0.3, "Buttons stay usable at " .. tag)
	table.insert(layoutReport, {size = tag, nav = n, counters = c, inventory = inv})
end
screen = r.Vector2.new(1648, 928); root.AbsoluteSize = screen; event(root, "property:AbsoluteSize"):Fire()
check(nav.Position.X.Offset == 35 and counters.Position.X.Offset == 35, "Reference left margin 35 px")
check(math.abs(nav.UIScale.Scale - 1) < 0.06 and counters.UIScale.Scale == 1, "Reference size at 1648x928")
check(root.Collection.Position.Y.Offset + 106 <= 928 and root.Collection.Position.X.Offset > 1300, "Fish/Eggs buttons bottom-right at reference size")
check(math.abs(root.Backpack.Position.X.Offset + 46 - 824) <= 2 and root.Backpack.Position.Y.Offset > 780, "Closed backpack bottom-centre at reference size")

-- Cleanup
event(gui, "Destroying"):Fire()
local last = coinsValue.Text
attr("Coins", 1)
check(coinsValue.Text == last, "Cleanup disconnects data subscriptions")

-- Server stats module: level carry-over
local statsModule = luau.load(fs.readFile(rootPath .. "src/server/OceanHUDStats.luau"), {debugName = "OceanHUDStats"})()
local p = r.Instance.new("Player")
statsModule.init(p, {Coins = 125430, SpeedLevel = 18})
statsModule.addSpeed(p, 2)
check(p:GetAttribute("SpeedLevel") == 20, "Server: addSpeed adds upgrades")
statsModule.setSpeed(p, -4)
check(p:GetAttribute("SpeedLevel") == 0, "Server: speed never goes negative")
check(p:GetAttribute("XP") == nil and p:GetAttribute("Level") == nil, "Server: no XP or level attributes")
statsModule.addCoins(p, -999999)
check(p:GetAttribute("Coins") == 0, "Server: coins never go negative")

-- Server inventory module
local invModule = luau.load(fs.readFile(rootPath .. "src/server/OceanInventory.luau"), {debugName = "OceanInventory", environment = {Instance = r.Instance}})()
invModule.add(p, "BasicEgg", {Name = "Обычное яйцо", Category = "Eggs", Icon = "Egg", Count = 2})
invModule.add(p, "BasicEgg", {Name = "Обычное яйцо", Category = "Eggs", Icon = "Egg"})
check(invModule.count(p, "BasicEgg") == 3 and p.Inventory.BasicEgg:GetAttribute("DisplayName") == "Обычное яйцо", "Server: add stacks items")
check(not pcall(invModule.add, p, "Rock", {Name = "Камень", Category = "Rocks"}), "Server: unknown category is rejected")
check(not invModule.remove(p, "BasicEgg", 5) and invModule.count(p, "BasicEgg") == 3, "Server: cannot remove more than owned")
check(invModule.remove(p, "BasicEgg", 3) and p.Inventory:FindFirstChild("BasicEgg") == nil, "Server: removing the last one deletes the item")
invModule.add(p, "Shark", {Name = "Акула", Category = "Fish", Icon = "SharkFin"})
invModule.add(p, "GoldEgg", {Name = "Золотое яйцо", Category = "Eggs", Icon = "Egg"})
check(not pcall(invModule.add, p, "Apple", {Name = "Яблоко", Category = "Food"}), "Server: Food category no longer exists")
invModule.setHotbar(p, "Shark", 1)
invModule.setHotbar(p, "GoldEgg", 1)
check(p.Inventory.GoldEgg:GetAttribute("HotbarSlot") == 1 and p.Inventory.Shark:GetAttribute("HotbarSlot") == nil, "Server: one item per hotbar slot")
check(not pcall(invModule.setHotbar, p, "GoldEgg", 9), "Server: hotbar slot must be 1-8")

fs.writeFile(rootPath .. "test-report.json", serde.encode("json", {passed = true, count = #tests, tests = tests, layout = layoutReport, studioPlayTest = false}, true))
print("PASS: " .. #tests .. " checks")
