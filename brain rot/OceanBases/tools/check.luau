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
check(occupied / courtArea < 0.25, string.format("Bases use %.0f%% of the court at the start", occupied / courtArea * 100))

local roofless, studded, total = true, true, 0
for id, base in bases do
	check(base.PrimaryPart == base.Root and base:GetAttribute("Rows") == 2, "Base " .. id .. " starts with 2 rows")
	local cells = Pens.cells(base)
	check(#cells == 10, "Base " .. id .. " starts with 10 cells")
	for _, cell in cells do
		for _, name in {"Tile", "EggPlacement", "InteractionPoint", "Content"} do assert(cell:FindFirstChild(name), name) end
		assert(cell.InteractionPoint:FindFirstChild("CellPrompt") and cell.InteractionPoint:FindFirstChild("CellInfo"))
		assert(cell.Tile.Size.X == Config.CellSize and cell.Tile.Size.Z == Config.CellSize)
	end
	check(true, "Base " .. id .. " cells are 8x8 tiles with a prompt and a label")
	for _, part in base:GetDescendants() do
		if part:IsA("BasePart") then
			total += 1
			-- Open yard: nothing large hangs above the fence (no roof).
			if part.Transparency < 1 and part.Size.X * part.Size.Z > 30 and part.CFrame.Position.Y > Config.Origins[id].Y + 3 then roofless = false end
			if part:IsA("Part") and part.Shape == r.Enum.PartType.Block and part.Material == r.Enum.Material.Plastic and part.TopSurface ~= r.Enum.SurfaceType.Studs then
				studded = false
			end
		end
	end
	check(base:FindFirstChild("Chest", true) == nil and base:FindFirstChild("Floors") == nil and base:FindFirstChild("Lift", true) == nil, "Base " .. id .. " has no chest, floors or lift")
	check(base:FindFirstChild("OwnerSign", true) == nil and base.Yard.OwnerTag:FindFirstChild("OwnerGui"), "Base " .. id .. " owner name floats in the air (no sign board)")
end
check(roofless, "Yards are open (no roof)")
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

-- Eggs on any cell
Inventory.add(alice, "BasicEgg", {Name = "Обычное яйцо", Category = "Eggs", Icon = "Egg", Count = 3})
Inventory.add(alice, "GoldEgg", {Name = "Золотое яйцо", Category = "Eggs", Icon = "Egg"})
local cells = Pens.cells(baseA)
local first, last = cells[1], cells[10]
check(first.InteractionPoint.CellPrompt:GetAttribute("Active") == true and not first.InteractionPoint.CellInfo.Enabled, "Empty cell: prompt on, no label clutter")
event(first.InteractionPoint.CellPrompt, "Triggered"):Fire(bob)
check(first:GetAttribute("State") == "Empty", "Another player cannot place eggs in your yard")
event(first.InteractionPoint.CellPrompt, "Triggered"):Fire(alice)
event(last.InteractionPoint.CellPrompt, "Triggered"):Fire(alice)
event(cells[7].InteractionPoint.CellPrompt, "Triggered"):Fire(alice)
check(first:GetAttribute("State") == "Egg" and last:GetAttribute("State") == "Egg" and cells[7]:GetAttribute("State") == "Egg", "Eggs go on any cell of the yard")
check(Inventory.count(alice, "BasicEgg") == 0 and Inventory.count(alice, "GoldEgg") == 1, "Placed eggs leave the inventory")
local egg = first.Content:FindFirstChild("Egg")
check(egg and math.abs(egg.Shell.CFrame.Position.Y - (first.Tile.CFrame.Position.Y + 0.5 + 1.4)) < 0.3, "Egg stands on the cell tile")
check(math.abs(egg.Shell.CFrame.Position.X - first.Tile.CFrame.Position.X) < 1e-3 and math.abs(egg.Shell.CFrame.Position.Z - first.Tile.CFrame.Position.Z) < 1e-3, "Egg is centred on its cell")
check(first.InteractionPoint.CellPrompt:GetAttribute("Active") == false and first.InteractionPoint.CellInfo.Enabled, "Busy cell hides its prompt and shows a label")
-- Hand-held egg via the hotbar remote.
local selectItem = game:GetService("ReplicatedStorage").OceanBases.Remotes.SelectItem
event(selectItem, "OnServerEvent"):Fire(alice, "GoldEgg")
check(alice:GetAttribute("HeldItem") == "GoldEgg", "Hotbar selection reaches the server")
event(selectItem, "OnServerEvent"):Fire(alice, "NotMine")
check(alice:GetAttribute("HeldItem") == "GoldEgg", "Server ignores items the player does not have")
event(cells[4].InteractionPoint.CellPrompt, "Triggered"):Fire(alice)
check(cells[4]:GetAttribute("EggType") == "GoldEgg", "The egg in the hand is used")
event(cells[5].InteractionPoint.CellPrompt, "Triggered"):Fire(alice)
check(cells[5]:GetAttribute("State") == "Empty", "No eggs left: nothing is placed")

-- Hatching
Pens.tick(1)
check(first.InteractionPoint.CellInfo.Line.Text:find("0:15") ~= nil, "Countdown above the egg")
serverTime += 15
Pens.tick(1)
check(first:GetAttribute("State") == "Fish" and last:GetAttribute("State") == "Fish", "Eggs hatch when their time is up")
check(cells[4]:GetAttribute("State") == "Egg", "Slower eggs keep waiting")
local fish = first.Content:FindFirstChildWhichIsA("Model")
check(fish and fish.PrimaryPart and math.abs(fish.PrimaryPart.CFrame.Position.Y - (first.EggPlacement.CFrame.Position.Y + Config.FishHeight)) < 1e-3, "Fish appears floating above its cell")
check(Config.Eggs.BasicEgg.fish[first:GetAttribute("FishType")] ~= nil, "Fish comes from the egg's table")

-- Income straight into the pocket
alice:SetAttribute("Coins", 0)
local perSecond = first:GetAttribute("Income") + last:GetAttribute("Income") + cells[7]:GetAttribute("Income")
Pens.tick(10)
check(alice:GetAttribute("Coins") == perSecond * 10, "Fish income goes straight into the owner's coins")
check(baseA:GetAttribute("Income") == perSecond, "Base knows its income per second")
Pens.tick(0.5)
Pens.tick(0.5)
check(alice:GetAttribute("Coins") == perSecond * 11, "Fractions of a second add up, nothing is lost")
check(bob:GetAttribute("Coins") == nil or bob:GetAttribute("Coins") == 0, "Other players earn nothing from your fish")

-- Expansion: one more row per level, wider yard, no floors
local board = baseA.Yard.UpgradeBoard
check(board.BoardFace.UpgradeLabel.Text.Text:find("5,000") ~= nil and board.BoardFace.UpgradeLabel.Text.Text:find("10 → 15") ~= nil, "Board shows price and new cell count")
local before = bounds(baseA)
alice:SetAttribute("Coins", 100)
event(board.UpgradePoint.UpgradePrompt, "Triggered"):Fire(alice)
check(baseA:GetAttribute("Rows") == 2 and alice:GetAttribute("Coins") == 100, "Expansion needs enough coins")
bob:SetAttribute("Coins", 999999)
event(board.UpgradePoint.UpgradePrompt, "Triggered"):Fire(bob)
check(baseA:GetAttribute("Rows") == 2 and bob:GetAttribute("Coins") == 999999, "Nobody can expand someone else's base")
alice:SetAttribute("Coins", 31000)
event(board.UpgradePoint.UpgradePrompt, "Triggered"):Fire(alice)
check(baseA:GetAttribute("Rows") == 3 and #Pens.cells(baseA) == 15 and alice:GetAttribute("Coins") == 26000, "Expansion 1: 15 cells for 5,000")
local after = bounds(baseA)
check(after.maxZ > before.maxZ + 7 and math.abs(after.minZ - before.minZ) < 0.01 and math.abs((after.maxX - after.minX) - (before.maxX - before.minX)) < 0.01, "The yard grows a row towards the front")
local topBefore, topAfter = -math.huge, -math.huge
for _, part in baseA:GetDescendants() do
	if part:IsA("BasePart") and part.Transparency < 1 then topAfter = math.max(topAfter, part.CFrame.Position.Y) end
end
check(topAfter < Config.Origins[1].Y + 9, "Expansion adds no floors (stays one level)")
check(first:GetAttribute("State") == "Fish" and first.Content:FindFirstChildWhichIsA("Model"), "Fish stay in place when the yard grows")
local newCell = Pens.cells(baseA)[13]
Inventory.add(alice, "StarEgg", {Name = "Звёздное яйцо", Category = "Eggs", Icon = "Egg"})
event(newCell.InteractionPoint.CellPrompt, "Triggered"):Fire(alice)
check(newCell:GetAttribute("State") == "Egg", "New cells work right away")
check(baseA.Yard.OwnerTag.OwnerGui.OwnerName.Text == "Alice", "Owner name stays after expansion")
local newBoard = baseA.Yard.UpgradeBoard
event(newBoard.UpgradePoint.UpgradePrompt, "Triggered"):Fire(alice)
check(baseA:GetAttribute("Rows") == 4 and #Pens.cells(baseA) == 20 and alice:GetAttribute("Coins") == 1000, "Expansion 2: 20 cells for 25,000")
check(baseA.Yard.UpgradeBoard.UpgradePoint.UpgradePrompt:GetAttribute("Active") == false and baseA.Yard.UpgradeBoard.BoardFace.UpgradeLabel.Text.Text:find("Максимум") ~= nil, "Max size reached")
local full = bounds(baseA)
check(full.maxZ <= court.maxZ and full.maxZ <= -105, "A fully expanded yard still leaves the court front free")
local neighbours = true
for id = 2, 5 do neighbours = neighbours and full.maxX + 4 <= boxes[id].minX end
check(neighbours, "A fully expanded yard does not reach the neighbours")

-- Leaving frees the base
event(Players, "PlayerRemoving"):Fire(alice)
check(baseA:GetAttribute("OwnerUserId") == 0 and baseA.Yard.OwnerTag.OwnerGui.OwnerName.Text == "Свободная база", "Leaving frees the base")
check(baseA:GetAttribute("Rows") == 2 and #Pens.cells(baseA) == 10, "Freed base shrinks back to 10 cells")
local busy = 0
for _, cell in Pens.cells(baseA) do if cell:GetAttribute("State") ~= "Empty" then busy += 1 end end
check(busy == 0, "Freed base has empty cells")
local carol = makePlayer("Carol", 303)
check(Ownership.baseOf(carol) == baseA and baseA.Yard.OwnerTag.OwnerGui.OwnerName.Text == "Carol", "Next player gets the freed base")

-- Creature models
local scratch = r.Instance.new("Folder")
for eggType in Config.Eggs do
	local e = Creatures.egg(scratch, eggType, r.CFrame.new())
	assert(e.PrimaryPart and e:GetAttribute("EggType") == eggType)
	local rolled = {}
	for _ = 1, 200 do rolled[Creatures.rollFish(eggType)] = true end
	for f in rolled do assert(Config.Eggs[eggType].fish[f], "Unexpected fish " .. f) end
end
check(true, "Every egg type builds and only rolls its own fish")
for fishType in Config.Fish do
	local model = Creatures.fish(scratch, fishType, r.CFrame.new())
	local tails = 0
	for _, part in model:GetChildren() do if part:GetAttribute("Tail") then tails += 1 end end
	assert(model.PrimaryPart and tails == 2 and model:FindFirstChild("Ripple"), fishType)
end
check(true, "Every fish type builds with a body, wagging tail and floor ring")

-- Client animation
local Anim = load(tree.client.FishAnimationController)
local cell = Pens.cells(baseA)[1]
cell:SetAttribute("EggType", "BasicEgg")
Pens.hatch(cell, "ClownFish")
local fishModel = cell.Content:FindFirstChildWhichIsA("Model")
Anim.start()
local center = fishModel:GetAttribute("Center")
local positions = {}
for i = 0, 3 do
	Anim.step(i * 1.3, center + r.Vector3.new(0, 10, 10))
	positions[i] = fishModel.PrimaryPart.CFrame.Position
end
local tile = cell.Tile.CFrame.Position
local inside = true
for _, p in positions do
	inside = inside and math.abs(p.X - tile.X) <= Config.CellSize / 2 and math.abs(p.Z - tile.Z) <= Config.CellSize / 2
end
check(inside and (positions[0] - positions[2]).Magnitude > 0.5, "Fish swims in a circle over its own cell")
check(math.abs(fishModel.Ripple.CFrame.Position.Y - (cell.EggPlacement.CFrame.Position.Y + 0.05)) < 1e-3, "Glow ring lies on the cell floor")
Anim.step(5, center + r.Vector3.new(0, 1000, 0))
check(fishModel.PrimaryPart.CFrame.Position == positions[3], "Far-away fish are not animated")
Anim.stop()

fs.writeFile(root .. "test-report.json", serde.encode("json", {passed = true, count = #tests, tests = tests, studioPlayTest = false}, true))
print("PASS: " .. #tests .. " checks")
