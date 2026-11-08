local fs = require("@lune/fs")
local r = require("@lune/roblox")
local luau = require("@lune/luau")
local Config = require("../src/shared/Config")
local Rules = require("../src/shared/Rules")
local game = r.deserializePlace(fs.readFile("build/LuckyTide.rbxl"))
local workspace = game:GetService("Workspace")
local signals, requests, tasks, tests = {}, {}, {}, 0
local function signal()
	local callbacks = {}
	return {Connect = function(_, fn) table.insert(callbacks, fn) end,
		Fire = function(_, ...) for _, fn in ipairs(callbacks) do fn(...) end end}
end
local function event(obj, name)
	signals[obj] = signals[obj] or {}; signals[obj][name] = signals[obj][name] or signal(); return signals[obj][name]
end
for class, names in pairs({GuiButton = {"Activated"}, RemoteEvent = {"OnClientEvent"}, RunService = {"RenderStepped"}, UserInputService = {"InputBegan"}}) do
	for _, name in ipairs(names) do r.implementProperty(class, name, function(obj) return event(obj, name) end) end
end
r.implementMethod("Instance", "WaitForChild", function(obj, name) return assert(obj:FindFirstChild(name), "missing " .. name) end)
r.implementMethod("Instance", "GetPropertyChangedSignal", event)
r.implementMethod("Workspace", "GetServerTimeNow", function() return 100 end)
r.implementMethod("RemoteEvent", "FireServer", function(_, ...) table.insert(requests, {...}) end)
r.implementMethod("Sound", "Play", function() end)
r.implementMethod("Debris", "AddItem", function() end)
r.implementMethod("TweenService", "Create", function(_, target, _, values) return {Play = function() for k, v in pairs(values) do target[k] = v end end} end)
local p = r.Instance.new("Player"); p.Name = "Tester"; p.Parent = game:GetService("Players")
game:GetService("Players").LocalPlayer = p
game:GetService("UserInputService").TouchEnabled = false
local playerGui = r.Instance.new("PlayerGui"); playerGui.Parent = p
local char = r.Instance.new("Model"); char.Parent = workspace; p.Character = char
local root = r.Instance.new("Part"); root.Name = "HumanoidRootPart"; root.Parent = char
-- Position is a derived engine property not available in Lune's data-only classes.
root.Position = r.Vector3.zero
workspace.CurrentCamera.ViewportSize = r.Vector2.new(1280, 720)
local env = {game = game, workspace = workspace, task = {spawn = function(fn) table.insert(tasks, fn) end, delay = function() end, wait = function() end},
	require = function(module) return if module.Name == "Config" then Config else Rules end, TweenInfo = {new = function() return {} end}}
for _, key in ipairs({"Instance", "Vector3", "Vector2", "CFrame", "Color3", "UDim2", "UDim", "Enum", "Font"}) do env[key] = r[key] end
luau.load(fs.readFile("src/client/Main.client.luau"), {debugName = "Client", environment = env})()
local gui = playerGui.LuckyTideHUD
local function check(v, name) assert(v, name); tests += 1; print("PASS " .. name) end
local function findText(value)
	for _, item in ipairs(gui:GetDescendants()) do
		if (item:IsA("TextLabel") or item:IsA("TextButton")) and item.Text == value then return item end
	end
end
check(findText("LUCKY TIDE") ~= nil, "HUD creates without engine startup errors")
local state = game:GetService("ReplicatedStorage").LuckyTide.State.OnClientEvent
local data = {Cash = 500, Bank = 0, Strength = 0, Weight = 0, Speed = 0, Slots = 6, Rebirths = 0, Income = 3, Hatched = 1,
	Tutorial = 3, Inventory = {{Id = "pet1", PetId = "mint_cat", Tier = 1, Mutation = "Normal", Hatched = true, ReadyAt = 0}},
	Discovered = {mint_cat = true}, PlotId = 1, Home = r.Vector3.zero, ShieldRemaining = 20, ShieldCooldown = 0, Practice = true}
state:Fire("Profile", data)
check(findText("$500") ~= nil and findText("+$3 / сек") ~= nil, "profile updates wallet and income")
findText("МАГАЗИН").Activated:Fire()
check(findText("УЛУЧШЕНИЯ  ·  $500") ~= nil, "shop opens")
findText("$100").Activated:Fire()
check(requests[#requests][1] == "Upgrade" and requests[#requests][2] == "Weight", "upgrade button sends defined intent")
findText("×").Activated:Fire()
findText("ПИТОМЦЫ").Activated:Fire()
check(findText("Мятный кот") ~= nil, "pet inventory renders actual pet")
local prior = #requests
findText("ПРОДАТЬ").Activated:Fire()
check(findText("ПРОДАТЬ ПИТОМЦА?") ~= nil and #requests == prior, "selling requires explicit second click")
findText("ПРОДАТЬ").Activated:Fire()
check(requests[#requests][1] == "Sell" and requests[#requests][2] == "pet1", "sale confirms selected pet only")
findText("×").Activated:Fire()
findText("ПЕРЕРОЖД.").Activated:Fire()
check(findText("ПОДТВЕРДИТЬ") ~= nil, "rebirth shows reset explanation and confirmation")
findText("×").Activated:Fire()
findText("ПОМОЩЬ").Activated:Fire()
check(findText("КАК ИГРАТЬ") ~= nil, "help opens")
findText("ВЫКЛЮЧИТЬ").Activated:Fire()
check(findText("ВКЛЮЧИТЬ") ~= nil, "sound preference toggles")
findText("×").Activated:Fire()
data.Carrying = {Tier = 1, Golden = false, Stolen = false}
state:Fire("Profile", data)
workspace:SetAttribute("NextWave", 106); workspace:SetAttribute("WaveActive", false)
game:GetService("RunService").RenderStepped:Fire()
check(findText("ВОЗВРАЩАЙСЯ НА БЕРЕГ") ~= nil, "wave warning displays countdown")
workspace:SetAttribute("WaveActive", true)
game:GetService("RunService").RenderStepped:Fire()
check(findText("В УКРЫТИЕ!") ~= nil, "active wave alert displays")
workspace.CurrentCamera.ViewportSize = r.Vector2.new(390, 844)
event(workspace.CurrentCamera, "ViewportSize"):Fire()
local gymButton, shopButton, petsButton = findText("ТРЕНИРОВКА"), findText("МАГАЗИН"), findText("ПИТОМЦЫ")
check(gymButton.Position.Y.Offset == 0 and petsButton.Position.Y.Offset == 55, "portrait navigation wraps into two touch rows")
check(shopButton.Size.Y.Offset == 48, "portrait actions retain touch target height")
workspace.CurrentCamera.ViewportSize = r.Vector2.new(1280, 720)
event(workspace.CurrentCamera, "ViewportSize"):Fire()
check(petsButton.Position.Y.Offset == 0 and petsButton.Size.Y.Offset == 56, "desktop layout restored after resize")
state:Fire("Training", {Gain = 4})
check(findText("+4 СИЛА") ~= nil, "training feedback renders")
print("PASSED " .. tests .. " client integration tests (no rendered Studio graphics)")
