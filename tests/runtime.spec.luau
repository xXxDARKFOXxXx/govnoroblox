-- Deterministic server integration harness. Uses real Roblox instance serialization
-- and data types via Lune; it does not emulate physics, rendering or Roblox services.
local fs = require("@lune/fs")
local r = require("@lune/roblox")
local luau = require("@lune/luau")
local game = r.deserializePlace(fs.readFile("build/LuckyTide.rbxl"))
game.JobId = "TEST"
local workspace = game:GetService("Workspace")
local now, guid, tests = 0, 0, 0
local queue, messages, signals, closes = {}, {}, {}, {}
local function check(value, name) assert(value, name); tests += 1; print("PASS " .. name) end
local function signal()
	local handlers = {}
	return {Connect = function(_, fn) table.insert(handlers, fn); return {Disconnect = function() end} end,
		Fire = function(_, ...) for _, fn in ipairs(handlers) do fn(...) end end,
		Wait = function() coroutine.yield(0.1) end}
end
local function propSignal(class, name)
	r.implementProperty(class, name, function(instance)
		signals[instance] = signals[instance] or {}
		signals[instance][name] = signals[instance][name] or signal()
		return signals[instance][name]
	end)
end
for class, names in pairs({Players = {"PlayerAdded", "PlayerRemoving"}, Player = {"CharacterAdded"},
	RunService = {"Heartbeat"}, Humanoid = {"Died"}, RemoteEvent = {"OnServerEvent"},
	ProximityPrompt = {"Triggered", "PromptButtonHoldBegan"}}) do
	for _, name in ipairs(names) do propSignal(class, name) end
end
local function resume(co, ...)
	local ok, delay = coroutine.resume(co, ...)
	assert(ok, tostring(delay) .. "\n" .. debug.traceback(co))
	if coroutine.status(co) ~= "dead" then table.insert(queue, {Thread = co, At = now + (delay or 0.1)}) end
end
local tasks = {
	spawn = function(fn, ...) local co = coroutine.create(fn); resume(co, ...); return co end,
	wait = function(n) return coroutine.yield(n or 0.1) end,
	delay = function(n, fn, ...) local args = {...}; table.insert(queue, {Thread = coroutine.create(function() fn(unpack(args)) end), At = now + n}) end,
}
r.implementMethod("Instance", "WaitForChild", function(obj, name) return assert(obj:FindFirstChild(name), "Missing " .. obj.Name .. "." .. name) end)
r.implementProperty("BasePart", "Position", function(p) return p.CFrame.Position end, function(p, pos) p.CFrame = r.CFrame.new(pos) * (p.CFrame - p.CFrame.Position) end)
r.implementMethod("Model", "GetPivot", function(m) return if m.PrimaryPart then m.PrimaryPart.CFrame else r.CFrame.new() end)
r.implementMethod("Model", "PivotTo", function(m, cf)
	local delta = cf * m:GetPivot():Inverse()
	for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then p.CFrame = delta * p.CFrame end end
end)
r.implementMethod("Players", "GetPlayers", function(p) return p:GetChildren() end)
r.implementMethod("Player", "Kick", function(p, reason) error("Unexpected kick " .. p.Name .. ": " .. reason) end)
r.implementMethod("RunService", "IsStudio", function() return true end)
r.implementMethod("Workspace", "GetServerTimeNow", function() return now end)
r.implementProperty("DataModel", "JobId", function() return "TEST" end)
r.implementMethod("DataModel", "BindToClose", function(_, callback) table.insert(closes, callback) end)
r.implementMethod("HttpService", "GenerateGUID", function() guid += 1; return "test-guid-" .. guid end)
r.implementMethod("RemoteEvent", "FireClient", function(_, player, kind, data) messages[player] = messages[player] or {}; messages[player][kind] = data end)
r.implementMethod("RemoteEvent", "FireAllClients", function() end)
local cache = {}
local function runModule(module)
	if cache[module] then return cache[module] end
	local env = {game = game, workspace = workspace, script = module, require = runModule, task = tasks,
		os = {clock = function() return now end, time = function() return 1000000 + math.floor(now) end},
		Random = {new = function() return {NextNumber = function() return 0.5 end, NextInteger = function(_, low) return low end} end},
		warn = function(...) print("WARN", ...) end}
	for _, key in ipairs({"Instance", "Vector3", "Vector2", "CFrame", "Color3", "UDim2", "UDim", "Enum", "Font", "ColorSequence", "NumberSequence"}) do env[key] = r[key] end
	local result = luau.load(module.Source, {debugName = module.Name, environment = env})()
	cache[module] = result or true
	return result
end
local function advance(seconds)
	for _ = 1, math.ceil(seconds / 0.1) do
		now += 0.1
		local pending = queue; queue = {}
		for _, job in ipairs(pending) do if job.At <= now then resume(job.Thread) else table.insert(queue, job) end end
		game:GetService("RunService").Heartbeat:Fire(0.1)
	end
end
local function addPlayer(id)
	local p = r.Instance.new("Player"); p.Name = "Player" .. id; p.DisplayName = "Tester " .. id; p.UserId = id; p.Parent = game:GetService("Players")
	local char = r.Instance.new("Model"); char.Name = p.Name; char.Parent = workspace
	local root = r.Instance.new("Part"); root.Name = "HumanoidRootPart"; root.Parent = char; char.PrimaryPart = root
	local hum = r.Instance.new("Humanoid"); hum.Parent = char; hum.Health = 100
	p.Character = char
	game:GetService("Players").PlayerAdded:Fire(p)
	return p, root
end
local function prompt(part, player)
	local pp = assert(part:FindFirstChildWhichIsA("ProximityPrompt", true), "No prompt in " .. part.Name)
	pp.PromptButtonHoldBegan:Fire(player); advance(pp.HoldDuration + 0.2); pp.Triggered:Fire(player)
end
local function action(player, name, value) game:GetService("ReplicatedStorage").LuckyTide.Action.OnServerEvent:Fire(player, name, value) end
local server = game:GetService("ServerScriptService").LuckyTide
runModule(server.Main)
local Data = runModule(server.DataService)
local p1, root1 = addPlayer(1)
local p2, root2 = addPlayer(2)
advance(1)
local world = workspace.LuckyTideWorld
check(#world.Plots:GetChildren() == 6, "six bases assembled")
check(Data.Profiles[p1].Cash == 150, "server loads new player")
check(world.Plots.Plot1:GetAttribute("OwnerId") == 1 and world.Plots.Plot2:GetAttribute("OwnerId") == 2, "unique plot ownership")
check((root1.CFrame.Position - world.Plots.Plot1.Spawn.CFrame.Position).Magnitude < 6, "player spawns at own base")

local block
for _, m in ipairs(world.Blocks:GetChildren()) do
	if m:IsA("Model") and m:FindFirstChildWhichIsA("ProximityPrompt", true) then
		local pos = m:FindFirstChildWhichIsA("ProximityPrompt", true).Parent.CFrame.Position
		if pos.Z < 70 then block = m; break end
	end
end
local blockPrompt = block:FindFirstChildWhichIsA("ProximityPrompt", true)
blockPrompt.Triggered:Fire(p1)
check(#world.Drops:GetChildren() == 0, "distant and unheld kick rejected")
root1.CFrame = blockPrompt.Parent.CFrame + r.Vector3.new(0, 0, -5)
prompt(block, p1); advance(1.2)
local egg = world.Drops:FindFirstChild("Egg")
check(egg ~= nil, "kick produces a real egg")
root1.CFrame = egg.CFrame + r.Vector3.new(0, 0, -3)
prompt(egg, p1)
check(messages[p1].Profile.Carrying ~= nil, "pickup attaches carried egg")
local before = root1.CFrame.Position
action(p1, "Home")
check(root1.CFrame.Position == before, "home teleport denied while carrying")
root1.CFrame = world.Plots.Plot1.Deposit.CFrame + r.Vector3.new(0, 3, 0)
advance(0.5)
check(#Data.Profiles[p1].Inventory == 1 and messages[p1].Profile.Carrying == nil, "delivery moves egg into base exactly once")
advance(12)
check(Data.Profiles[p1].Inventory[1].Hatched and Data.Profiles[p1].Hatched == 1, "egg hatches once")
advance(3)
check(Data.Profiles[p1].Bank > 0, "pet generates passive income")
root1.CFrame = world.Plots.Plot1.Collect.CFrame + r.Vector3.new(0, 3, 0)
advance(1)
check(Data.Profiles[p1].Cash > 150, "collection credits wallet")
action(p1, "Upgrade", "Weight")
check(Data.Profiles[p1].Weight == 1, "valid upgrade purchased")
root1.CFrame = world.Plots.Plot1.Spawn.CFrame + r.Vector3.new(0, 3, 0)
local cashBefore = Data.Profiles[p1].Cash
advance(0.4); action(p1, "Upgrade", "Speed")
check(Data.Profiles[p1].Speed == 0 and Data.Profiles[p1].Cash == cashBefore, "unaffordable purchase rejected")
action(p1, "Gym"); advance(3)
check(Data.Profiles[p1].Strength >= 8, "gym increases strength")
local owned = Data.Profiles[p1].Inventory[1].Id
action(p2, "Sell", owned)
check(#Data.Profiles[p1].Inventory == 1, "cannot sell another player's pet")

-- Inject a newly earned unhatched egg, then exercise the actual nest prompt.
local p3, root3 = addPlayer(3)
Data.Profiles[p3].Inventory = {{Id = "steal-test", PetId = "star_dragon", Tier = 5, Mutation = "Normal", Hatched = false, ReadyAt = 1000000 + math.floor(now) + 60}}
Data.Profiles[p3].Cash = 1000
action(p3, "Upgrade", "Weight") -- refreshes base display
local nest = world.Plots.Plot3.Collection:FindFirstChild("Egg")
root2.CFrame = nest.CFrame + r.Vector3.new(0, 0, -2)
prompt(nest, p2)
check(messages[p2].Profile.Carrying == nil, "fresh base shield prevents theft")
advance(46)
nest = world.Plots.Plot3.Collection:FindFirstChild("Egg")
root2.CFrame = nest.CFrame + r.Vector3.new(0, 0, -2)
prompt(nest, p2)
check(messages[p2].Profile.Carrying and messages[p2].Profile.Carrying.Stolen, "unprotected egg can be stolen")
root3.CFrame = root2.CFrame + r.Vector3.new(2, 0, 0)
action(p3, "Shove")
check(messages[p2].Profile.Carrying == nil and #Data.Profiles[p3].Inventory == 1, "owner recovers stolen egg without duplication")

nest = world.Plots.Plot3.Collection:FindFirstChild("Egg")
root2.CFrame = nest.CFrame + r.Vector3.new(0, 0, -2)
prompt(nest, p2)
root2.CFrame = world.Plots.Plot2.Deposit.CFrame + r.Vector3.new(0, 3, 0)
advance(0.5)
check(#Data.Profiles[p3].Inventory == 0 and #Data.Profiles[p2].Inventory == 1, "successful theft transfers inventory ownership")

Data.Profiles[p1].Cash = 50000; Data.Profiles[p1].Bank = 10000
action(p1, "Rebirth")
check(Data.Profiles[p1].Rebirths == 1 and Data.Profiles[p1].Cash == 150 and Data.Profiles[p1].Bank == 0, "rebirth resets wallet and bank")
check(#Data.Profiles[p1].Inventory == 1 and Data.Profiles[p1].Strength == 0, "rebirth keeps pets and resets power")
local saved = Data.Save(p1, false)
check(saved, "practice saving works without network permissions")

-- Run through a full wave and verify the authoritative sweep relocates a player.
action(p1, "Home"); advance(2)
root1.CFrame = r.CFrame.new(0, 3, 160)
local remaining = math.max(0, workspace:GetAttribute("NextWave") - now)
advance(remaining + 9)
check(root1.CFrame.Position.Z < 29, "wave evacuates exposed player")
game:GetService("Players").PlayerRemoving:Fire(p3)
check(Data.Profiles[p3] == nil and world.Plots.Plot3:GetAttribute("OwnerId") == nil, "leaving releases data and base")
print("PASSED " .. tests .. " server integration tests")
