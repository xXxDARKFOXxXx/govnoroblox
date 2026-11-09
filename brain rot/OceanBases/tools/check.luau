-- Offline checks for the player bases: geometry/layout, structure, and the real
-- server + client scripts running against Roblox data types with event doubles.
-- Not a Studio play test. Run from the OceanBases folder:
--   ..\..\tools\lune\lune.exe run tools/check.luau
local fs = require("@lune/fs")
local r = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local process = require("@lune/process")
local Env = require("./env")
local root = process.cwd:gsub("\\", "/"):gsub("/?$", "/")

local tests = {}
local function check(condition, name)
	assert(condition, name)
	table.insert(tests, name)
end

---------------------------------------------------------------- doubles
local signals = {}
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
	Players = {"PlayerAdded", "PlayerRemoving"}, Player = {"CharacterAdded"},
	ProximityPrompt = {"Triggered"}, RemoteEvent = {"OnServerEvent"}, RunService = {"Heartbeat"},
	Instance = {"DescendantAdded", "ChildAdded", "ChildRemoved"},
} do
	for _, name in names do r.implementProperty(class, name, function(object) return event(object, name) end) end
end
r.implementMethod("Instance", "GetAttributeChangedSignal", function(object, name) return event(object, "attribute:" .. name) end)
r.implementMethod("Instance", "GetPropertyChangedSignal", function(object, name) return event(object, "property:" .. name) end)
local serverTime = 1000
r.implementMethod("Workspace", "GetServerTimeNow", function() return serverTime end)
r.implementMethod("Players", "GetPlayers", function(players) return players:GetChildren() end)
r.implementMethod("RunService", "IsStudio", function() return false end)
local notices = {}
r.implementMethod("RemoteEvent", "FireClient", function(_, p, message) table.insert(notices, {p, message}) end)
local tagged = {}
local tagRoot -- set once the DataModel exists
r.implementMethod("CollectionService", "GetTagged", function(_, tag)
	local list = {}
	for _, object in tagRoot:GetDescendants() do
		if object:HasTag(tag) then table.insert(list, object) end
	end
	return list
end)
r.implementMethod("CollectionService", "GetInstanceAddedSignal", function(_, tag) return event(tagged, "add:" .. tag) end)
r.implementMethod("CollectionService", "GetInstanceRemovedSignal", function(_, tag) return event(tagged, "remove:" .. tag) end)
local function pivotOf(model)
	if model.PrimaryPart then return model.PrimaryPart.CFrame end
	local part = model:FindFirstChildWhichIsA("BasePart", true)
	return part and part.CFrame or r.CFrame.new()
end
r.implementMethod("Model", "GetPivot", pivotOf)
r.implementMethod("Model", "PivotTo", function(model, target)
	local delta = target * pivotOf(model):Inverse()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then part.CFrame = delta * part.CFrame end
	end
end)
r.implementMethod("Model", "GetBoundingBox", function(m)
	local p = m:FindFirstChildWhichIsA("BasePart", true)
	return p.CFrame, p.Size
end)
r.implementMethod("Model", "GetScale", function() return 1 end)
r.implementMethod("Model", "ScaleTo", function(m, s)
	for _, p in m:GetDescendants() do if p:IsA("BasePart") then p.Size = p.Size * s end end
end)
r.implementProperty("Attachment", "WorldPosition", function(a) return (a.Parent.CFrame * a.CFrame).Position end)
r.implementProperty("BasePart", "Position", function(p) return p.CFrame.Position end)

---------------------------------------------------------------- place
local game = r.Instance.new("DataModel")
tagRoot = game
for _, name in {"Workspace", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "Players", "StarterPlayer", "CollectionService", "RunService"} do
	game:GetService(name)
end
local tree = Env.install(game, root)
-- HUD server modules (coins + inventory) as in the real game.
for _, name in {"OceanHUDStats", "OceanInventory"} do
	local m = r.Instance.new("ModuleScript")
	m.Name = name
	m.Source = fs.readFile(root .. "../OceanHUD/src/server/" .. name .. ".luau")
	m.Parent = game:GetService("ServerScriptService")
end
local taskStub = {spawn = function() end, wait = function() return 0 end, defer = function(f, ...) f(...) end}
local load, makeEnv = Env.loader(game, {task = taskStub})
local Config = load(tree.shared.BaseConfig)

-- Run the server bootstrap exactly as Roblox would (it builds the bases, no baked copy here).
luau.load(tree.server.OceanBasesServer.Source, {debugName = "OceanBasesServer", environment = makeEnv(tree.server.OceanBasesServer)})()
local Ownership = load(tree.server.BaseOwnershipService)
local Pens = load(tree.server.FishPenController)
local Upgrades = load(tree.server.BaseUpgradeService)
local Creatures = load(tree.server.CreatureModels)
local Inventory = load(game:GetService("ServerScriptService").OceanInventory)

local basesFolder = game:GetService("Workspace").OceanBases
local bases = {}
for id = 1, 5 do bases[id] = basesFolder["Base" .. id] end

---------------------------------------------------------------- layout & structure
local function bounds(base)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, part in base:GetDescendants() do
		if part:IsA("BasePart") then
			-- Exact world-space box of a rotated part: |R| * half size.
			local _, _, _, r00, r01, r02, _, _, _, r20, r21, r22 = part.CFrame:GetComponents()
			local p, h = part.CFrame.Position, part.Size / 2
			local ex = math.abs(r00) * h.X + math.abs(r01) * h.Y + math.abs(r02) * h.Z
			local ez = math.abs(r20) * h.X + math.abs(r21) * h.Y + math.abs(r22) * h.Z
			minX, maxX = math.min(minX, p.X - ex), math.max(maxX, p.X + ex)
			minZ, maxZ = math.min(minZ, p.Z - ez), math.max(maxZ, p.Z + ez)
		end
	end
	return {minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ}
end
check(#basesFolder:GetChildren() == 5, "Five bases on the start court")
local court = {minX = -144, maxX = 144, minZ = -160, maxZ = 0}
local boxes, occupied = {}, 0
for id, base in bases do
	local b = bounds(base)
	boxes[id] = b
	occupied += (b.maxX - b.minX) * (b.maxZ - b.minZ)
	check(b.minX >= court.minX and b.maxX <= court.maxX and b.minZ >= court.minZ and b.maxZ <= court.maxZ, "Base " .. id .. " stays inside the start court")
end
for a = 1, 4 do
	check(boxes[a].maxX + 4 <= boxes[a + 1].minX, "Bases " .. a .. " and " .. (a + 1) .. " do not touch")
end
local courtArea = (court.maxX - court.minX) * (court.maxZ - court.minZ)
check(occupied / courtArea < 0.30, string.format("Bases use %.0f%% of the court at the start", occupied / courtArea * 100))

local roofless, studded, total = true, true, 0
for id, base in bases do
	check(base.PrimaryPart == base.Root and base:GetAttribute("Level") == 0 and base:GetAttribute("Capacity") == 10 and base:GetAttribute("YardSize") == 1, "Base " .. id .. " starts at level 0 with room for 10 fish")
	check(#Pens.cells(base) == 0 and base:FindFirstChild("CellPrompt", true) == nil and base:FindFirstChild("Tile", true) == nil, "Base " .. id .. " has no cell grid (eggs go anywhere)")
	for _, part in base:GetDescendants() do
		if part:IsA("BasePart") then
			total += 1
			-- Open yard: nothing large hangs above the fence (no roof).
			if part.Transparency < 1 and part.Size.X * part.Size.Z > 30 and part.CFrame.Position.Y > Config.Origins[id].Y + 6 then roofless = false end
			if part:IsA("Part") and part.Shape == r.Enum.PartType.Block and part.Material == r.Enum.Material.Plastic and part.TopSurface ~= r.Enum.SurfaceType.Studs then
				studded = false
			end
		end
	end
	check(base:FindFirstChild("Chest", true) == nil and base:FindFirstChild("Floors") == nil and base:FindFirstChild("Lift", true) == nil, "Base " .. id .. " has no chest, floors or lift")
	check(base:FindFirstChild("OwnerSign", true) == nil and base.Yard.OwnerTag:FindFirstChild("OwnerGui"), "Base " .. id .. " owner name floats in the air (no sign board)")
end
check(roofless, "Yards are open (no roof)")
for id, base in bases do
	local pool = base:FindFirstChild("Pool")
	assert(pool and pool:FindFirstChild("Water") and pool:FindFirstChild("FishZone"), "pool " .. id)
	local depth = pool.FishZone.CFrame.Position.Y - pool.PoolBottom.CFrame.Position.Y
	assert(depth > 1.4 and depth < 2.2, "pool depth " .. depth)
	assert(not pool.Water.CanCollide)
end
check(true, "Every yard has a shallow pool (about a third of a character tall)")
do
	local base = bases[1]
	local water, fenceMinX, fenceMaxX, fenceMaxZ = base.Pool.Water, math.huge, -math.huge, -math.huge
	local fenceLow = math.huge
	for _, part in base.Yard.Fence:GetChildren() do
		local p = part.CFrame.Position
		fenceMinX, fenceMaxX, fenceMaxZ = math.min(fenceMinX, p.X), math.max(fenceMaxX, p.X), math.max(fenceMaxZ, p.Z)
		if part.Name == "FencePost" then fenceLow = math.min(fenceLow, p.Y - part.Size.Y / 2) end
	end
	local w = water.CFrame.Position
	check(water.Size.X >= (fenceMaxX - fenceMinX) - 1.5 and water.Size.Z >= Config.depth(1) - 3
		and math.abs(w.Z - Config.depth(1) / 2 - Config.Origins[1].Z) < 0.5, "Pool water fills the whole yard")
	check(fenceLow >= w.Y + water.Size.Y / 2 - 0.01, "Fence stands on the pool rim on every side")
	check(base.Pool:FindFirstChild("EntranceStep") and base.Pool:FindFirstChild("InnerStep"), "Steps lead over the rim into the pool")
end
check(studded, "Plastic blocks have studs, like the court floor and walls")
check(total / 5 < 400, "Light bases (" .. math.floor(total / 5) .. " parts each)")
local anchored = true
for _, part in basesFolder:GetDescendants() do
	if part:IsA("BasePart") then anchored = anchored and part.Anchored end
end
check(anchored, "Every base part is anchored")

---------------------------------------------------------------- players
local Players = game:GetService("Players")
local function makePlayer(name, userId)
	local p = r.Instance.new("Player")
	p.Name = name
	p.UserId = userId
	p.DisplayName = name
	p.Parent = Players
	local character = r.Instance.new("Model")
	character.Name = name
	local hrp = r.Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Parent = character
	character.PrimaryPart = hrp
	character.Parent = game:GetService("Workspace")
	p.Character = character
	event(Players, "PlayerAdded"):Fire(p)
	return p
end
r.implementMethod("Players", "GetPlayerByUserId", function(players, id)
	for _, p in players:GetChildren() do if p.UserId == id then return p end end
	return nil
end)
local alice = makePlayer("Alice", 101)
local bob = makePlayer("Bob", 202)
local baseA, baseB = Ownership.baseOf(alice), Ownership.baseOf(bob)
check(baseA == bases[1] and baseB == bases[2], "Joining players get free bases in order")
check(baseA.Yard.OwnerTag.OwnerGui.OwnerName.Text == "Alice", "Owner name floats above the base")
check(bases[3].Yard.OwnerTag.OwnerGui.OwnerName.Text == "Свободная база", "Free bases say so")
check((alice.Character.HumanoidRootPart.CFrame.Position - baseA.Yard.SpawnPoint.CFrame.Position).Magnitude < 4, "Owner is moved into their yard")
check(Ownership.isOwner(alice, baseA) and not Ownership.isOwner(bob, baseA), "Ownership check")

-- Eggs anywhere in the yard: hold an egg, click the floor (remote PlaceItem)
Inventory.add(alice, "TideEgg", {Name = "Обычное яйцо", Category = "Eggs", Icon = "Egg", Count = 3})
Inventory.add(alice, "OceanCrownEgg", {Name = "Золотое яйцо", Category = "Eggs", Icon = "Egg"})
local selectItem = game:GetService("ReplicatedStorage").OceanBases.Remotes.SelectItem
local placeRemote = game:GetService("ReplicatedStorage").OceanBases.Remotes.PlaceItem
local originA = baseA.PrimaryPart.CFrame
local function at(base, x, z) return base.PrimaryPart.CFrame:PointToWorldSpace(r.Vector3.new(x, 5, z)) end
local clock = 0
local function place(p, x, z, base)
	clock += 1
	return Pens.placeAt(p, at(base or baseA, x, z))
end
event(selectItem, "OnServerEvent"):Fire(alice, "TideEgg")
check(alice:GetAttribute("HeldItem") == "TideEgg", "Picked item reaches the server (held in the hands)")
event(selectItem, "OnServerEvent"):Fire(alice, "NotMine")
check(alice:GetAttribute("HeldItem") == "TideEgg", "Server ignores items the player does not have")
check(not Pens.placeAt(bob, at(baseA, 0, 20)) and #Pens.cells(baseA) == 0, "Another player cannot place eggs in your yard")
check(place(alice, -15.3, 9.7) and place(alice, 14.1, 27.2), "Eggs go anywhere on the yard floor (not on a grid)")
local cells = Pens.cells(baseA)
local first, last = cells[1], cells[2]
local p1 = originA:PointToObjectSpace(first.EggPlacement.CFrame.Position)
check(math.abs(p1.X + 15.3) < 1e-3 and math.abs(p1.Z - 9.7) < 1e-3 and math.abs(p1.Y - Config.FloorTop - 0.1) < 1e-3, "The egg stands exactly where it was clicked, on the floor")
check(not place(alice, -13, 11), "Not too close to another egg")
check(not place(alice, 0, -5) and not place(alice, 40, 20) and not place(alice, 0, Config.depth(1) - 2), "Only inside the pool (not on the rim, outside or on the entrance steps)")
check(place(alice, 5, 15), "Third egg")
check(Inventory.count(alice, "TideEgg") == 0 and Inventory.count(alice, "OceanCrownEgg") == 1, "Placed eggs leave the inventory")
check(alice:GetAttribute("HeldItem") == nil, "The last one placed: the hands are empty")
local egg = first.Content:FindFirstChild("Egg")
check(egg and math.abs(egg.Shell.Size.Y - Config.BaseEggHeight) < 0.05, "Eggs in the yard are as tall as a character")
check(first.InteractionPoint.CellInfo.Enabled and first.InteractionPoint.CellInfo.Title.Text ~= "", "Egg shows its name and timer")
event(selectItem, "OnServerEvent"):Fire(alice, "OceanCrownEgg")
event(placeRemote, "OnServerEvent"):Fire(alice, at(baseA, -5, 30))
local crown = Pens.cells(baseA)[4]
check(crown and crown:GetAttribute("EggType") == "OceanCrownEgg", "The egg in the hand is used (remote PlaceItem)")
check(not place(alice, 15, 15), "No eggs left: nothing is placed")
event(placeRemote, "OnServerEvent"):Fire(alice, "garbage")
check(#Pens.cells(baseA) == 4, "Bad remote data is ignored")

-- Hatching
Pens.tick(1)
check(first.InteractionPoint.CellInfo.Line.Text:find("0:20") ~= nil, "Countdown above the egg")
serverTime += 20
Pens.tick(1)
check(first:GetAttribute("State") == "Fish" and last:GetAttribute("State") == "Fish", "Eggs hatch when their time is up")
check(crown:GetAttribute("State") == "Egg", "Slower eggs keep waiting")
local fish = first.Content:FindFirstChildWhichIsA("Model")
local zone = baseA.Pool.FishZone
local fp = fish.PrimaryPart.CFrame.Position
check(fp.Y >= zone.CFrame.Position.Y + Config.FishFlyHeight[1] - 0.01 and fp.Y <= zone.CFrame.Position.Y + Config.FishFlyHeight[2] + 0.01, "Fish flies in the air above the water, not in it")
check(math.abs(fp.X - zone.CFrame.Position.X) <= zone.Size.X / 2 and math.abs(fp.Z - zone.CFrame.Position.Z) <= zone.Size.Z / 2, "Fish is over the pool")
check(fish:GetAttribute("FloorY") == zone.CFrame.Position.Y, "Fish ring sits on the water surface")
check(first.InteractionPoint.CellInfo.Adornee == fish.PrimaryPart, "The fish's label flies with the fish")
check(Config.Eggs.TideEgg.tiers[Config.Fish[first:GetAttribute("FishType")].tier] ~= nil, "Fish comes from the egg's tiers")

-- Income straight into the pocket
alice:SetAttribute("Coins", 0)
local perSecond = 0
for _, cell in Pens.cells(baseA) do perSecond += cell:GetAttribute("Income") or 0 end
Pens.tick(10)
check(perSecond > 0 and alice:GetAttribute("Coins") == perSecond * 10, "Fish income goes straight into the owner's coins")
check(baseA:GetAttribute("Income") == perSecond, "Base knows its income per second")
Pens.tick(0.5)
Pens.tick(0.5)
check(alice:GetAttribute("Coins") == perSecond * 11, "Fractions of a second add up, nothing is lost")
check(bob:GetAttribute("Coins") == nil or bob:GetAttribute("Coins") == 0, "Other players earn nothing from your fish")

-- Capacity: 10 places at the start
Inventory.add(alice, "TideEgg", {Name = "Яйцо", Category = "Eggs", Icon = "Egg", Count = 20})
local spots = {}
for _, z in {9, 16, 23, 30} do for _, x in {-20, -13, -6, 1, 8, 15, 21} do table.insert(spots, {x, z}) end end
for _, spot in spots do place(alice, spot[1], spot[2]) end
check(#Pens.cells(baseA) == 10, "A new base holds 10 fish and eggs")
local before10 = Inventory.count(alice, "TideEgg")
check(not place(alice, 21, 36) and Inventory.count(alice, "TideEgg") == before10, "A full base takes no more")

-- Base upgrades: +1 place each, up to 20; the price grows; the yard grows at 5 and 10
local board = baseA.Yard.UpgradeBoard
check(board.BoardFace.UpgradeLabel.Text.Text:find("1,000") ~= nil and board.BoardFace.UpgradeLabel.Text.Text:find("10 → 11") ~= nil, "Board shows price and the next capacity")
check(board.BoardFace.UpgradeLabelBack.Text.Text == board.BoardFace.UpgradeLabel.Text.Text, "Board text on both sides")
local faceBox = board.BoardFace
local postsClear = true
for _, post in board:GetChildren() do
	if post.Name == "BoardPost" then
		local dx = math.abs(post.CFrame.Position.X - faceBox.CFrame.Position.X)
		postsClear = postsClear and dx >= faceBox.Size.X / 2 + post.Size.X / 2 - 0.01
	end
end
check(postsClear, "Board posts stand beside the text, not across it")
local frontFence = -math.huge
for _, part in baseA.Yard.Fence:GetChildren() do frontFence = math.max(frontFence, part.CFrame.Position.Z) end
check(board.BoardFace.CFrame.Position.Z > frontFence + 1 and board.UpgradePoint.CFrame.Position.Z > frontFence, "Upgrade board stands outside the yard")
local prices, growing = {}, true
for level = 0, 9 do prices[level] = Config.basePrice(level) end
for level = 1, 9 do growing = growing and prices[level] > prices[level - 1] end
check(growing and Config.capacity(0) == 10 and Config.capacity(10) == 20, "Every upgrade costs more; 10 → 20 places")
local before = bounds(baseA)
alice:SetAttribute("Coins", 100)
event(board.UpgradePoint.UpgradePrompt, "Triggered"):Fire(alice)
check(baseA:GetAttribute("Level") == 0 and alice:GetAttribute("Coins") == 100, "Upgrade needs enough coins")
bob:SetAttribute("Coins", 999999)
event(board.UpgradePoint.UpgradePrompt, "Triggered"):Fire(bob)
check(baseA:GetAttribute("Level") == 0 and bob:GetAttribute("Coins") == 999999, "Nobody can upgrade someone else's base")
local total = 0
for level = 0, 9 do total += Config.basePrice(level) end
alice:SetAttribute("Coins", total + 5)
event(baseA.Yard.UpgradeBoard.UpgradePoint.UpgradePrompt, "Triggered"):Fire(alice)
check(baseA:GetAttribute("Level") == 1 and baseA:GetAttribute("Capacity") == 11 and alice:GetAttribute("Coins") == total + 5 - 1000, "Upgrade 1: 11 places for 1,000")
check(place(alice, 21, 36) and #Pens.cells(baseA) == 11, "The new place works right away")
local sameSize = bounds(baseA)
check(math.abs(sameSize.maxZ - before.maxZ) < 0.01, "Upgrades 1-4 do not change the yard size")
for _ = 2, 5 do event(baseA.Yard.UpgradeBoard.UpgradePoint.UpgradePrompt, "Triggered"):Fire(alice) end
local mid = bounds(baseA)
check(baseA:GetAttribute("Level") == 5 and baseA:GetAttribute("Capacity") == 15 and baseA:GetAttribute("YardSize") == 2, "Upgrade 5: 15 places and a bigger yard")
check(mid.maxZ > before.maxZ + 7 and math.abs(mid.minZ - before.minZ) < 0.01 and math.abs((mid.maxX - mid.minX) - (before.maxX - before.minX)) < 0.01, "The yard grows towards the front")
check(baseA.Pool.Water.Size.Z >= Config.depth(2) - 3, "The pool grows with the yard")
local topAfter = -math.huge
for _, part in baseA:GetDescendants() do
	if part:IsA("BasePart") and part.Transparency < 1 and not part:FindFirstAncestor("Content") then topAfter = math.max(topAfter, part.CFrame.Position.Y) end
end
check(topAfter < Config.Origins[1].Y + 12, "Upgrades add no floors (stays one level)")
check(first:GetAttribute("State") == "Fish" and first.Parent and first.Content:FindFirstChildWhichIsA("Model"), "Fish stay when the yard grows")
check(baseA.Yard.OwnerTag.OwnerGui.OwnerName.Text == "Alice", "Owner name stays after the upgrade")
for _ = 6, 10 do event(baseA.Yard.UpgradeBoard.UpgradePoint.UpgradePrompt, "Triggered"):Fire(alice) end
check(baseA:GetAttribute("Level") == 10 and baseA:GetAttribute("Capacity") == 20 and baseA:GetAttribute("YardSize") == 3 and alice:GetAttribute("Coins") == 5, "Upgrade 10: 20 places, the biggest yard, all coins counted")
check(baseA.Yard.UpgradeBoard.UpgradePoint.UpgradePrompt:GetAttribute("Active") == false and baseA.Yard.UpgradeBoard.BoardFace.UpgradeLabel.Text.Text:find("Максимум") ~= nil, "Max level reached")
local full = bounds(baseA)
check(full.maxZ <= court.maxZ and full.maxZ <= -90, "A fully upgraded yard still leaves 90+ studs of the court free in front")
local neighbours = true
for id = 2, 5 do neighbours = neighbours and full.maxX + 4 <= boxes[id].minX end
check(neighbours, "A fully upgraded yard does not reach the neighbours")

-- Leaving frees the base
event(Players, "PlayerRemoving"):Fire(alice)
check(baseA:GetAttribute("OwnerUserId") == 0 and baseA.Yard.OwnerTag.OwnerGui.OwnerName.Text == "Свободная база", "Leaving frees the base")
check(baseA:GetAttribute("Level") == 0 and baseA:GetAttribute("Capacity") == 10 and baseA:GetAttribute("YardSize") == 1, "Freed base goes back to the start")
check(#Pens.cells(baseA) == 0, "Freed base is empty")
local carol = makePlayer("Carol", 303)
check(Ownership.baseOf(carol) == baseA and baseA.Yard.OwnerTag.OwnerGui.OwnerName.Text == "Carol", "Next player gets the freed base")

-- Creature models
local scratch = r.Instance.new("Folder")
for eggType in Config.Eggs do
	local e = Creatures.egg(scratch, eggType, r.CFrame.new())
	assert(e.PrimaryPart and e:GetAttribute("EggType") == eggType)
	local rolled = {}
	for _ = 1, 200 do rolled[Creatures.rollFish(eggType)] = true end
	for f in rolled do assert(Config.Eggs[eggType].tiers[Config.Fish[f].tier], "Unexpected fish " .. f) end
end
check(true, "Every egg type builds and only rolls fish of its tiers")
for fishType in Config.Fish do
	local model = Creatures.fish(scratch, fishType, r.CFrame.new())
	local tails = 0
	for _, part in model:GetChildren() do if part:GetAttribute("Tail") then tails += 1 end end
	assert(model.PrimaryPart and tails == 2 and model:FindFirstChild("Ripple"), fishType)
end
check(true, "Every fish type builds with a body, wagging tail and floor ring")

-- Client animation
local Anim = load(tree.client.FishAnimationController)
local cell = Pens.createCell(baseA, at(baseA, 0, 20))
cell:SetAttribute("EggType", "TideEgg")
Pens.hatch(cell, "Clown")
local fishModel = cell.Content:FindFirstChildWhichIsA("Model")
Anim.start()
local center = fishModel:GetAttribute("Center")
local positions = {}
for i = 0, 3 do
	Anim.step(i * 1.3, center + r.Vector3.new(0, 10, 10))
	positions[i] = fishModel.PrimaryPart.CFrame.Position
end
local poolZone = baseA.Pool.FishZone
local inside = true
for _, p in positions do
	inside = inside and math.abs(p.X - poolZone.CFrame.Position.X) <= poolZone.Size.X / 2 and math.abs(p.Z - poolZone.CFrame.Position.Z) <= poolZone.Size.Z / 2
		and p.Y > poolZone.CFrame.Position.Y + 2
end
check(inside and (positions[0] - positions[2]).Magnitude > 0.5, "Fish flies around in the air over the pool")
local look = fishModel.PrimaryPart.CFrame.LookVector
Anim.step(3 * 1.3 + 0.05, center + r.Vector3.new(0, 10, 10))
local moved = (fishModel.PrimaryPart.CFrame.Position - positions[3]).Unit
check(look:Dot(moved) > 0.5, "Fish faces the way it flies")
check(math.abs(fishModel.Ripple.CFrame.Position.Y - (poolZone.CFrame.Position.Y + 0.05)) < 1e-3, "Glow ring lies on the water")
Anim.step(5, center + r.Vector3.new(0, 1000, 0))
local frozen = fishModel.PrimaryPart.CFrame.Position
Anim.step(9, center + r.Vector3.new(0, 1000, 0))
check(fishModel.PrimaryPart.CFrame.Position == frozen, "Far-away fish are not animated")
Anim.stop()


---------------------------------------------------------------- content: 40 fish, 10 eggs, 5 sections
local fishCount, eggCount = 0, 0
for _ in Config.Fish do fishCount += 1 end
for _ in Config.Eggs do eggCount += 1 end
check(fishCount == 40 and eggCount == 10, "40 fish (Studfish + SeaLife) and 10 eggs (StudEggs)")
local tierIncome = {}
for tier, list in Config.FishTiers do
	local best = 0
	for _, f in list do best = math.max(best, Config.Fish[f].income) end
	tierIncome[tier] = best
end
check(tierIncome[1] < tierIncome[2] and tierIncome[2] < tierIncome[3] and tierIncome[3] < tierIncome[4] and tierIncome[4] < tierIncome[5], "Rarer tiers earn more")
local better = true
for s = 2, 5 do
	local prev, cur = Config.Sections[s - 1], Config.Sections[s]
	better = better and cur.chase > prev.chase and Config.Eggs[cur.eggs[1]].section > Config.Eggs[prev.eggs[1]].section
end
check(better, "Deeper sections: better eggs and faster predators")
check(Config.fishIncome("Clown", 3) > Config.fishIncome("Clown", 2) and Config.upgradeCost("Clown", 3) > Config.upgradeCost("Clown", 2), "Fish level raises income and the upgrade price")

---------------------------------------------------------------- seabed
local seabed = game:GetService("Workspace"):FindFirstChild("OceanSeabed")
check(seabed and seabed:FindFirstChild("Sand") and seabed:FindFirstChild("Walls") and seabed:FindFirstChild("Nests"), "Seabed with sand relief, wall rocks and nests")
local heights, stalactites, stalagmites = {}, 0, 0
for _, part in seabed.Sand:GetChildren() do heights[math.floor(part.Size.Y)] = true end
local distinct = 0
for _ in heights do distinct += 1 end
check(distinct >= 5, "Sand has many different heights (" .. distinct .. ")")
for _, part in seabed.Walls:GetChildren() do
	if part.Name == "Stalactite" then stalactites += 1 elseif part.Name == "Stalagmite" then stalagmites += 1 end
end
check(stalactites > 20 and stalagmites > 20, "Stalactites and stalagmites along the walls")
local studs = true
for _, part in seabed:GetDescendants() do
	if part:IsA("Part") and part.Shape == r.Enum.PartType.Block and part.Material == r.Enum.Material.Plastic then
		studs = studs and part.TopSurface == r.Enum.SurfaceType.Studs
	end
end
check(studs, "Seabed blocks are studded like the court")
local nestsBySection = {}
for _, nest in seabed.Nests:GetChildren() do
	local s = nest:GetAttribute("Section")
	nestsBySection[s] = (nestsBySection[s] or 0) + 1
	assert(table.find(Config.Sections[s].eggs, nest:GetAttribute("EggType")), "nest egg of its section")
	local z = nest.EggSpot.CFrame.Position.Z
	assert(z >= Config.Sections[s].fromZ and z <= Config.Sections[s].toZ, "nest inside its section")
end
check(nestsBySection[1] == 3 and nestsBySection[2] == 4 and nestsBySection[5] == 4, "Nests in every section with that section's eggs (one on the beach removed)")
local dry = false
for _, nest in seabed.Nests:GetChildren() do
	if nest.Mound.CFrame.Position.Y + nest.Mound.Size.Y / 2 > -0.5 then dry = true end
end
check(not dry, "Every nest is under water, none on the beach")
do
	local fits = true
	for _, nest in seabed.Nests:GetChildren() do
		local size = Config.Eggs[nest:GetAttribute("EggType")].size
		local glow = nest.NestGlow.Size.Z -- cylinder diameter
		fits = fits and glow >= math.max(size.X, size.Z) and glow <= math.max(size.X, size.Z) + 2
	end
	local small, big = seabed.Nests.Nest_1_1.Mound.Size.X, nil
	for _, nest in seabed.Nests:GetChildren() do
		if nest:GetAttribute("EggType") == "OceanCrownEgg" then big = nest.Mound.Size.X end
	end
	check(fits and big and big > small, "Nests are sized to their eggs (bigger egg, bigger nest)")
end

---------------------------------------------------------------- nests: take, carry, deliver
local Nests = load(tree.server.NestService)
local Predators = load(tree.server.PredatorService)
local SeabedB = load(tree.server.SeabedBuilder)
local nest = seabed.Nests:FindFirstChild("Nest_1_1")
local nestState = Nests.nests[nest]
check(nestState and nestState.available and nest:FindFirstChild("Egg"), "Every nest holds an egg")
local diver = makePlayer("Diver", 404)
local diverRoot = diver.Character.HumanoidRootPart
local humanoid = r.Instance.new("Humanoid"); humanoid.Health = 100; humanoid.Parent = diver.Character
diverRoot.CFrame = r.CFrame.new(nest.EggSpot.CFrame.Position + r.Vector3.new(0, 3, 0))
local farPlayer = makePlayer("Far", 505)
farPlayer.Character.HumanoidRootPart.CFrame = r.CFrame.new(0, 0, -50)
local farHumanoid = r.Instance.new("Humanoid"); farHumanoid.Health = 100; farHumanoid.Parent = farPlayer.Character
event(nest.EggSpot.TakePrompt, "Triggered"):Fire(farPlayer)
check(nestState.available, "Taking needs to be close to the nest")
event(nest.EggSpot.TakePrompt, "Triggered"):Fire(diver)
check(not nestState.available and diver:GetAttribute("CarryEgg") == nest:GetAttribute("EggType") and diver:GetAttribute("CarrySection") == 1, "Taking the egg: the diver carries it")
check(diver.Character:FindFirstChild("CarriedEgg") and not nest:FindFirstChild("Egg") and not nest.EggSpot.TakePrompt.Enabled, "Egg moves from the nest to above the diver's head")
check(not diver.Character.CarriedEgg:HasTag("OceanEgg") and diver.Character.CarriedEgg:GetAttribute("Carried"), "Carried egg is not rocked in place by the client (the diver can move)")
local nest2 = seabed.Nests:FindFirstChild("Nest_1_2")
diverRoot.CFrame = r.CFrame.new(nest2.EggSpot.CFrame.Position + r.Vector3.new(0, 3, 0))
event(nest2.EggSpot.TakePrompt, "Triggered"):Fire(diver)
check(Nests.nests[nest2].available, "Only one egg at a time")

-- Predators: calm until an egg of their section is taken
Predators.init(seabed)
local guards1, guards3 = {}, {}
for _, guard in Predators.guards do
	if guard.section == 1 then table.insert(guards1, guard) elseif guard.section == 3 then table.insert(guards3, guard) end
end
check(#Predators.guards >= 10 and #guards1 >= 2, "Every section has guards (" .. #Predators.guards .. " in total)")
check(game:GetService("Workspace"):FindFirstChild("OceanPredators") and guards1[1].model:HasTag("OceanPredator"), "Predator models in Workspace.OceanPredators")
local victim = guards1[1]
diverRoot.CFrame = r.CFrame.new(victim.pos + r.Vector3.new(30, 0, 0))
Predators.step(0.1, 1)
check(victim.state == "Chase", "Guards of the egg's section chase the carrier")
check(guards3[1].state ~= "Chase", "Guards of other sections ignore him")
local knocked
Predators.knock = function(p, v) knocked = {p, v} end
local d0 = (victim.pos - diverRoot.CFrame.Position).Magnitude
Predators.step(0.5, 1.5)
check((victim.pos - diverRoot.CFrame.Position).Magnitude < d0, "The chaser closes in")
check((d0 - (victim.pos - diverRoot.CFrame.Position).Magnitude) <= Config.Sections[1].chase * 0.5 + 0.01, "Chase speed is the section's speed")
diverRoot.CFrame = r.CFrame.new(victim.pos)
Predators.step(0.05, 2)
check(diver:GetAttribute("CarryEgg") == nil and nestState.available and nest:FindFirstChild("Egg"), "Caught: the egg goes back to its nest")
check(knocked and knocked[1] == diver and knocked[2].Magnitude > 30, "Caught: the diver is pushed away")
check(victim.state == "Return", "After the catch the guard swims back")
-- Escape: leaving the section makes guards give up
diverRoot.CFrame = r.CFrame.new(nest.EggSpot.CFrame.Position + r.Vector3.new(0, 3, 0))
event(nest.EggSpot.TakePrompt, "Triggered"):Fire(diver)
check(diver:GetAttribute("CarryEgg") ~= nil, "The egg can be taken again")
for _, guard in guards1 do guard.cooldown = 0 end
diverRoot.CFrame = r.CFrame.new(guards1[1].pos + r.Vector3.new(0, 0, -40))
Predators.step(0.1, 3)
diverRoot.CFrame = r.CFrame.new(0, -5, -1)
for i = 1, 30 do Predators.step(0.1, 3 + i * 0.1) end
check(guards1[1].state ~= "Chase", "Guards give up when the diver leaves their section")
local inside = true
for _, guard in Predators.guards do
	local sec = Config.Sections[guard.section]
	inside = inside and guard.pos.Z >= math.max(sec.fromZ - 10.01, 23.99) and guard.pos.Z <= sec.toZ + 10.01 and guard.pos.Y <= -1.99
end
check(inside, "Guards stay in their section and under water")
-- Delivery at the court
diverRoot.CFrame = r.CFrame.new(0, 6, -20)
Nests.step()
check(diver:GetAttribute("CarryEgg") == nil and Inventory.count(diver, nest:GetAttribute("EggType")) == 1, "Reaching the court puts the egg into the inventory")
check(not nestState.available and nestState.respawnAt ~= nil, "The nest refills later")
nestState.respawnAt = 0
Nests.step()
check(nestState.available and nest:FindFirstChild("Egg"), "The nest gets a new egg")

---------------------------------------------------------------- fish actions from the HUD menus
local owner = makePlayer("Owner", 606)
local ownBase = Ownership.baseOf(owner)
local ownCell = Pens.createCell(ownBase, at(ownBase, 0, 20))
ownCell:SetAttribute("EggType", "TideEgg")
Pens.hatch(ownCell, "Clown")
local idx = ownCell:GetAttribute("Index")
check(ownCell:GetAttribute("FishLevel") == 1 and ownCell:GetAttribute("Income") == Config.Fish.Clown.income, "Hatched fish start at level 1")
owner:SetAttribute("Coins", 0)
Pens.action(owner, "UpgradeFish", idx)
check(ownCell:GetAttribute("FishLevel") == 1, "Upgrade needs coins")
local price = Config.upgradeCost("Clown", 1)
owner:SetAttribute("Coins", price + 7)
Pens.action(owner, "UpgradeFish", idx)
check(ownCell:GetAttribute("FishLevel") == 2 and owner:GetAttribute("Coins") == 7 and ownCell:GetAttribute("Income") == Config.fishIncome("Clown", 2), "Upgrade: level up, more income, coins spent")
check(ownCell.InteractionPoint.CellInfo.Line.Text:find("Ур. 2") ~= nil, "Fish label shows the level")
Pens.action(diver, "UpgradeFish", idx)
Pens.action(diver, "RemoveFish", idx)
check(ownCell.Parent and ownCell:GetAttribute("FishLevel") == 2, "Nobody else can upgrade or take your fish")
Pens.action(owner, "RemoveFish", idx)
local itemId = Pens.fishItemId("Clown", 2)
check(ownCell.Parent == nil and #Pens.cells(ownBase) == 0 and Inventory.count(owner, itemId) == 1, "Убрать moves the fish to the inventory and frees its place")
check(owner.Inventory[itemId]:GetAttribute("Category") == "Fish" and owner.Inventory[itemId]:GetAttribute("Level") == 2, "The fish keeps its level in the inventory")
owner:SetAttribute("HeldItem", itemId)
check(Pens.placeAt(owner, at(ownBase, 10, 25)), "A held fish can be put back")
local back = Pens.cells(ownBase)[1]
check(back:GetAttribute("State") == "Fish" and back:GetAttribute("FishLevel") == 2 and Inventory.count(owner, itemId) == 0, "A fish from the inventory goes back into the yard with its level")
Inventory.add(owner, "TideEgg", {Name = "Яйцо прилива", Category = "Eggs", Icon = "Egg"})
owner:SetAttribute("HeldItem", nil)
check(Pens.placeAt(owner, at(ownBase, -10, 25)), "Egg placed")
local eggCell = Pens.cells(ownBase)[2]
Pens.action(owner, "DeleteEgg", eggCell:GetAttribute("Index"))
check(eggCell.Parent == nil and #Pens.cells(ownBase) == 1, "Удалить removes the egg")
Pens.action(owner, "Explode", 1)
check(true, "Unknown actions are ignored")

---------------------------------------------------------------- imported GLB models are used when present
local models = r.Instance.new("Folder"); models.Name = "OceanModels"; models.Parent = game:GetService("ReplicatedStorage")
for _, data in {{"Fish", "Clown"}, {"Predators", "01_Barracuda"}, {"Eggs", "01_Tide"}} do
	local folder = models:FindFirstChild(data[1]) or r.Instance.new("Folder")
	folder.Name = data[1]; folder.Parent = models
	local m = r.Instance.new("Model"); m.Name = data[2]
	local mesh = r.Instance.new("MeshPart"); mesh.Name = data[2] .. "_Body"; mesh.Size = r.Vector3.new(4, 2, 2); mesh.Parent = m
	m.Parent = folder
end
local importedFish = Creatures.fish(scratch, "Clown", r.CFrame.new(0, 10, 0))
check(importedFish:GetAttribute("Imported") and importedFish:GetAttribute("ForwardYaw") == -90 and importedFish:FindFirstChild("Clown_Body"), "Imported fish model is used (head at -X, turned to face forward)")
do
	local facing = r.CFrame.lookAt(r.Vector3.zero, r.Vector3.new(0, 0, -1)) * r.CFrame.Angles(0, math.rad(-90), 0)
	check((facing:VectorToWorldSpace(r.Vector3.new(-1, 0, 0)) - r.Vector3.new(0, 0, -1)).Magnitude < 1e-4, "ForwardYaw turns the model's head (-X) the way it moves")
end
local bigEgg = Creatures.egg(scratch, "TideEgg", r.CFrame.new(), Config.BaseEggHeight)
check(bigEgg:FindFirstChild("01_Tide_Body").Size.Y > 2 * 1.5, "Imported eggs are scaled up to character height in the yard")
local importedPredator = Creatures.predator(scratch, "01_Barracuda", r.CFrame.new())
check(importedPredator:GetAttribute("Imported") and importedPredator["01_Barracuda_Body"]:GetAttribute("PatrolRadius") == 0, "Imported predator: its runtime only animates, the server moves it")
local importedEgg = Creatures.egg(scratch, "TideEgg", r.CFrame.new(0, 0, 0))
check(importedEgg:GetAttribute("Imported") and not importedEgg:FindFirstChild("Shell"), "Imported egg model is used")
check(not Creatures.fish(scratch, "Whale", r.CFrame.new()):GetAttribute("Imported"), "Missing models fall back to built ones")

---------------------------------------------------------------- swim speed
local SwimSpeed = load(tree.server.SwimSpeedService)
owner:SetAttribute("SpeedLevel", 18)
check(SwimSpeed.speedFor(owner) == Config.BaseWalkSpeed + 18 * Config.SpeedPerLevel, "Upgraded speed makes you swim faster")

---------------------------------------------------------------- held items and arm poses
local Held = load(tree.server.HeldItemService)
local holder = makePlayer("Holder", 707)
Inventory.add(holder, "CoralEgg", {Name = "Коралловое яйцо", Category = "Eggs", Icon = "Egg"})
holder:SetAttribute("HeldItem", "CoralEgg")
Held.update(holder)
local inHands = holder.Character:FindFirstChild("HeldItem")
local unanchored = inHands ~= nil
for _, part in (inHands and inHands:GetDescendants() or {}) do
	if part:IsA("BasePart") then unanchored = unanchored and not part.Anchored and part.Massless and not part.CanCollide end
end
check(inHands and inHands:GetAttribute("Held") and not inHands:HasTag("OceanEgg") and unanchored, "The picked egg appears in the hands (welded, does not hold the player)")
holder:SetAttribute("CarryEgg", "TideEgg")
Held.update(holder)
check(holder.Character:FindFirstChild("HeldItem") == nil, "Nothing in the hands while carrying a stolen egg overhead")
holder:SetAttribute("CarryEgg", nil)
holder:SetAttribute("HeldItem", nil)
Held.update(holder)
check(holder.Character:FindFirstChild("HeldItem") == nil, "Empty hands when nothing is picked")

local Pose = load(tree.client.CarryPoseController)
local rig = r.Instance.new("Model")
local upperTorso = r.Instance.new("Part"); upperTorso.Name = "UpperTorso"; upperTorso.Parent = rig
local joints = {}
for _, side in {"Right", "Left"} do
	local upper = r.Instance.new("Part"); upper.Name = side .. "UpperArm"; upper.Parent = rig
	local lower = r.Instance.new("Part"); lower.Name = side .. "LowerArm"; lower.Parent = rig
	local shoulder = r.Instance.new("Motor6D"); shoulder.Name = side .. "Shoulder"; shoulder.Parent = upper
	local elbow = r.Instance.new("Motor6D"); elbow.Name = side .. "Elbow"; elbow.Parent = lower
	joints[side] = shoulder
end
local carried = r.Instance.new("Model"); carried.Name = "CarriedEgg"; carried.Parent = rig
check(Pose.poseFor(rig) == "Up", "Carrying a nest egg: arms-up pose")
Pose.apply(rig, "Up")
local hand = joints.Right.Transform:VectorToWorldSpace(r.Vector3.new(0, -1, 0))
local handL = joints.Left.Transform:VectorToWorldSpace(r.Vector3.new(0, -1, 0))
check(hand.Y > 0.9 and handL.Y > 0.9, "Both arms point up: the egg is held over the head (legs keep swimming)")
carried:Destroy()
local heldModel = r.Instance.new("Model"); heldModel.Name = "HeldItem"; heldModel.Parent = rig
Pose.apply(rig, Pose.poseFor(rig))
hand = joints.Right.Transform:VectorToWorldSpace(r.Vector3.new(0, -1, 0))
check(Pose.poseFor(rig) == "Front" and hand.Z < -0.8, "Holding a picked item: arms forward")

---------------------------------------------------------------- predators face the player head first
do
	local guard = guards1[1]
	guard.cooldown = 0
	guard.state = "Patrol"
	diverRoot.CFrame = r.CFrame.new(nest.EggSpot.CFrame.Position + r.Vector3.new(0, 3, 0))
	event(nest.EggSpot.TakePrompt, "Triggered"):Fire(diver)
	-- The diver is behind the guard: it must turn round and swim at him head first.
	diverRoot.CFrame = r.CFrame.new(guard.pos - guard.heading * 25)
	for i = 1, 30 do Predators.step(1 / 60, 10 + i / 60) end
	local toDiver = (diverRoot.CFrame.Position - guard.pos).Unit
	check(guard.state == "Chase" and guard.heading:Dot(toDiver) > 0.9, "A chasing guard turns to face the player")
	local pivot = guard.model.PrimaryPart.CFrame
	local yaw = guard.model:GetAttribute("ForwardYaw") or 0
	local headDir = yaw == 0 and pivot.LookVector or pivot:VectorToWorldSpace(r.Vector3.new(-1, 0, 0))
	check(headDir:Dot(toDiver) > 0.85, "Its head (not its tail) points at the player")
	Nests.drop(diver, "test")
end

fs.writeFile(root .. "test-report.json", serde.encode("json", {passed = true, count = #tests, tests = tests, studioPlayTest = false}, true))
print("PASS: " .. #tests .. " checks")
