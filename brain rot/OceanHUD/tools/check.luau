-- Exercises the actual client source with Roblox data types and event doubles.
-- This is an offline contract test, not a Roblox Studio play test.
local fs = require("@lune/fs")
local r = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local rootPath = "C:/gpt/roblox-game/brain rot/OceanHUD/"
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
			local copy = table.clone(entries)
			for _, entry in copy do if entry.connected then entry.callback(...) end end
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
r.implementMethod("TweenService", "Create", function(_, object, _, props)
	return {Play = function() for key, value in props do object[key] = value end end, Cancel = function() end}
end)
local screen = r.Vector2.new(1440, 840)
local game = r.Instance.new("DataModel")
local player = r.Instance.new("Player")
player.Name = "HUDTest"
player.Parent = game:GetService("Players")
game:GetService("Players").LocalPlayer = player
local playerGui = r.Instance.new("PlayerGui")
playerGui.Parent = player
local env = {game = game, TweenInfo = {new = function() return {} end}}
for _, key in {"Instance", "Vector2", "Vector3", "CFrame", "Color3", "UDim", "UDim2", "Enum", "ColorSequence"} do env[key] = r[key] end
env.Instance = {new = function(class)
	local object = r.Instance.new(class)
	if object:IsA("GuiObject") then object.AbsoluteSize = screen end
	return object
end}
local run = luau.load(fs.readFile(rootPath .. "src/OceanHUD.client.luau"), {debugName = "OceanHUD", environment = env})
run()
local gui = playerGui.OceanHUD
local root = gui.SafeArea
local progress = root.LevelProgress
local fill = progress.Track.FillClip.BlueFill
local function check(condition, name)
	assert(condition, name)
	table.insert(tests, name)
end
local function attr(name, value)
	player:SetAttribute(name, value)
	event(player, "attribute:" .. name):Fire()
end
check(#root.Navigation:GetChildren() == 5, "Exactly four navigation slots and one UIScale")
check(not fill.Visible and fill.Size.X.Scale == 0, "Empty progress does not show a minimum blue sliver")
check(progress.ProgressText.Text == "0 / 10000", "Progress is placed above the bar with correct defaults")
attr("XP", 100)
check(math.abs(fill.Size.X.Scale - 0.01) < 1e-6 and progress.ProgressText.Text == "100 / 10000", "100 of 10000 fills exactly one percent")
attr("XPToNextLevel", 20000); attr("XP", 0)
check(progress.ProgressText.Text == "0 / 20000", "Threshold updates independently")
attr("XP", 90000)
check(fill.Size.X.Scale == 1, "Overflow clamps to full track")
attr("XP", -100)
check(fill.Size.X.Scale == 0, "Negative experience clamps to zero")
attr("XPToNextLevel", 0)
check(progress.ProgressText.Text == "МАКС. УРОВЕНЬ" and fill.Size.X.Scale == 1, "Zero threshold handles max level")
attr("Level", 12); attr("Money", 2600); attr("Speed", 155)
check(progress.Track.Level.Text == "Уровень 12", "Level label updates inside bar")
check(root.Counters.CoinsCounter.Value.Text == "2.6K", "Currency aliases and abbreviation")
check(root.Counters.SpeedCounter.Value.Text == "155", "Speed updates separately from XP")
attr("Coins", 1100)
check(root.Counters.CoinsCounter.Value.Text == "1.1K", "Canonical attributes take precedence")
attr("Coins", nil); attr("Money", nil)
local stats = r.Instance.new("Folder"); stats.Name = "leaderstats"; stats.Parent = player
local coins = r.Instance.new("IntValue"); coins.Name = "Coins"; coins.Value = 500; coins.Parent = stats
event(player, "ChildAdded"):Fire(stats)
check(root.Counters.CoinsCounter.Value.Text == "500", "Late leaderstats are discovered")
coins.Value = 750; event(coins, "property:Value"):Fire()
check(root.Counters.CoinsCounter.Value.Text == "750", "Leaderstats changes refresh counter")
coins.Parent = nil; event(stats, "ChildRemoved"):Fire(coins)
check(root.Counters.CoinsCounter.Value.Text == "0", "Removed values do not remain stale")
local requests = {}
event(gui.OpenMenu, "Event"):Connect(function(key) table.insert(requests, key) end)
for _, key in {"Rebirth", "Gifts", "Shop", "Index"} do
	event(root.Navigation[key .. "Slot"][key], "Activated"):Fire()
	check(root.MenuBackdrop.Visible and root.MenuBackdrop.Panel[key .. "Icon"].Visible, key .. " opens its own panel")
	event(root.MenuBackdrop.Panel.Close, "Activated"):Fire()
	check(not root.MenuBackdrop.Visible, key .. " panel closes")
end
check(table.concat(requests, ",") == "Rebirth,Gifts,Shop,Index", "All buttons emit integration events")
gui:SetAttribute("UseExternalMenus", true)
event(root.Navigation.ShopSlot.Shop, "Activated"):Fire()
check(not root.MenuBackdrop.Visible and #requests == 5, "External menu mode does not open built-in shell")
gui:SetAttribute("UseExternalMenus", false)
run()
check(#playerGui:GetChildren() == 1, "Repeated execution cannot duplicate the HUD")

local sizes = {{1920, 1020}, {1440, 840}, {1280, 660}, {1024, 708}, {844, 330}, {600, 330}, {390, 784}, {360, 580}}
for _, dimensions in sizes do
	screen = r.Vector2.new(dimensions[1], dimensions[2])
	root.AbsoluteSize = screen
	event(root, "property:AbsoluteSize"):Fire()
	local nav = root.Navigation
	local counters = root.Counters
	local navBottom = nav.Position.Y.Offset + 476 * nav.UIScale.Scale
	local counterTop = screen.Y + counters.Position.Y.Offset - 130 * counters.UIScale.Scale
	local barLeft = (screen.X - progress.Size.X.Offset) / 2
	local countersRight = counters.Position.X.Offset + 246 * counters.UIScale.Scale
	check(navBottom + 4 <= counterTop, "Navigation clears counters at " .. dimensions[1] .. "x" .. dimensions[2])
	check(progress.Size.X.Offset > 100 and barLeft >= 0, "Progress fits at " .. dimensions[1] .. "x" .. dimensions[2])
	check(counters.Position.Y.Offset <= -112 or countersRight + 4 <= barLeft, "Counters clear progress at " .. dimensions[1] .. "x" .. dimensions[2])
end

-- Save a populated, static snapshot for offline preview generation.
screen = r.Vector2.new(1440, 840); root.AbsoluteSize = screen; event(root, "property:AbsoluteSize"):Fire()
attr("Coins", 2600); attr("Speed", 155); attr("Level", 12); attr("XPToNextLevel", 10000); attr("XP", 3700)
fs.writeFile(rootPath .. "tools/preview-snapshot.rbxmx", r.serializeModel({gui}, true))
local function pair(v) return {v.X, v.Y} end
local function color(v) return {math.round(v.R * 255), math.round(v.G * 255), math.round(v.B * 255)} end
local function udim(v) return {v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset} end
local function export(object)
	local item = {class = object.ClassName, name = object.Name, children = {}}
	if object:IsA("GuiObject") then
		item.size, item.pos, item.anchor = udim(object.Size), udim(object.Position), pair(object.AnchorPoint)
		item.bg, item.alpha, item.z, item.visible = color(object.BackgroundColor3), 1 - object.BackgroundTransparency, object.ZIndex, object.Visible
		item.clip = object.ClipsDescendants
	end
	if object:IsA("TextLabel") or object:IsA("TextButton") then
		item.text, item.fontSize, item.textColor = object.Text, object.TextSize, color(object.TextColor3)
		item.align = object.TextXAlignment.Name
	end
	if object:IsA("UIScale") then item.scale = object.Scale end
	if object:IsA("UICorner") then item.radius = object.CornerRadius.Offset end
	if object:IsA("UIStroke") then
		item.color, item.thickness, item.alpha = color(object.Color), object.Thickness, 1 - object.Transparency
	end
	if object:IsA("UIGradient") then
		item.from, item.to = color(object.Color.Keypoints[1].Value), color(object.Color.Keypoints[#object.Color.Keypoints].Value)
	end
	if object:IsA("BasePart") then
		item.color = color(object.Color)
		item.size3 = {object.Size.X, object.Size.Y, object.Size.Z}
		item.cf = {object.CFrame:GetComponents()}
	end
	if object:IsA("Camera") then item.cf = {object.CFrame:GetComponents()}; item.fov = object.FieldOfView end
	for _, child in object:GetChildren() do table.insert(item.children, export(child)) end
	return item
end
fs.writeFile(rootPath .. "tools/preview-tree.json", serde.encode("json", export(gui)))
event(gui, "Destroying"):Fire()
local lastCoins = root.Counters.CoinsCounter.Value.Text
attr("Coins", 9999)
check(root.Counters.CoinsCounter.Value.Text == lastCoins, "Cleanup disconnects reactive subscriptions")
fs.writeFile(rootPath .. "test-report.json", serde.encode("json", {passed = true, count = #tests, tests = tests, studioPlayTest = false}, true))
print("PASS: " .. #tests .. " runtime contract and layout checks")
