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
local Stats = load(game:GetService("ServerScriptService").OceanHUDStats)

local basesFolder = game:GetService("Workspace").OceanBases
local locked = game:GetService("ServerStorage").OceanBasesLocked
local bases = {}
for id = 1, 5 do bases[id] = basesFolder["Base" .. id] end

---------------------------------------------------------------- layout & structure
check(#basesFolder:GetChildren() == 5, "Five bases on the start court")
local court = {minX = -144, maxX = 144, minZ = -160, maxZ = 0}
local boxes, occupied = {}, 0
for id, base in bases do
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
	boxes[id] = {minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ}
	occupied += (maxX - minX) * (maxZ - minZ)
	check(minX >= court.minX and maxX <= court.maxX and minZ >= court.minZ and maxZ <= court.maxZ, "Base " .. id .. " stays inside the start court")
end
for a = 1, 4 do
	check(boxes[a].maxX + 4 <= boxes[a + 1].minX, "Bases " .. a .. " and " .. (a + 1) .. " do not touch")
end
local courtArea = (court.maxX - court.minX) * (court.maxZ - court.minZ)
check(occupied / courtArea < 0.35, string.format("Bases use %.0f%% of the court (room left for buildings)", occupied / courtArea * 100))
local frontmost = -math.huge
for _, b in boxes do frontmost = math.max(frontmost, b.maxZ) end
check(-frontmost >= 105, "At least 105 studs of free court in front of the bases")

local PEN_PARTS = {"Base", "Walls", "Water", "Decorations", "EggPlacement", "FishMovementArea", "InteractionPoint", "Effects", "Content"}
for id, base in bases do
	check(base.PrimaryPart == base.Root and base:FindFirstChild("SpawnPoint"), "Base " .. id .. " has a root pivot and spawn point")
	check(base:GetAttribute("Floors") == 2 and #Pens.pens(base) == 10, "Base " .. id .. " starts with 2 floors and 10 pens")
	local store = locked["Base" .. id]
	local lockedPens = 0
	for _, floor in store:GetChildren() do lockedPens += #floor.Pens:GetChildren() end
	check(lockedPens == 10 and store:FindFirstChild("Floor3") and store:FindFirstChild("Floor4"), "Base " .. id .. " can grow to 20 pens (floors 3 and 4 stored)")
	for _, pen in Pens.pens(base) do
		for _, name in PEN_PARTS do assert(pen:FindFirstChild(name), "Pen part " .. name) end
		assert(pen.EggPlacement:FindFirstChild("FishSpawn") and pen.InteractionPoint:FindFirstChild("IncomeDisplay"))
	end
	check(true, "Base " .. id .. " pens have Base/Walls/Water/Decorations/EggPlacement/FishSpawn/FishMovementArea/InteractionPoint/IncomeDisplay/Effects")
end
local anchored, decorCollide, lights = true, 0, 0
for _, part in basesFolder:GetDescendants() do
	if part:IsA("BasePart") then
		anchored = anchored and part.Anchored
		if part.CanCollide and (part.Name:find("Kelp") or part.Name:find("Coral") or part.Name:find("Shell") or part.Name:find("Star") or part.Name:find("Rope")) then
			decorCollide += 1
		end
	elseif part:IsA("PointLight") then
		lights += 1
	end
end
check(anchored, "Every base part is anchored")
check(decorCollide == 0, "Small decor has no collision")
check(lights <= 5 * 4, "Few real lights (" .. lights .. " for five bases)")
-- Floor heights: upgrades stack upwards, not outwards.
local f3 = locked.Base1.Floor3
check(math.abs(f3.FloorRoot.CFrame.Position.Y - (bases[1].Root.CFrame.Position.Y + Config.floorTop(3))) < 1e-3, "Floor 3 sits one storey above floor 2")
local footprint = boxes[1]
local f4 = locked.Base1.Floor4
local fx = 0
for _, part in f4:GetDescendants() do
	if part:IsA("BasePart") then fx = math.max(fx, math.abs(part.CFrame.Position.X - bases[1].Root.CFrame.Position.X)) end
end
check(fx <= (footprint.maxX - footprint.minX) / 2 + 1, "Upper floors keep the same footprint")

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
local alice = makePlayer("Alice", 101)
local bob = makePlayer("Bob", 202)
local baseA, baseB = Ownership.baseOf(alice), Ownership.baseOf(bob)
check(baseA == bases[1] and baseB == bases[2], "Joining players get free bases in order")
check(baseA:GetAttribute("OwnerUserId") == 101 and baseA.Entrance.OwnerSign.OwnerLabel.Text.Text == "База: Alice", "Owner sign shows the player name")
check((alice.Character.HumanoidRootPart.CFrame.Position - baseA.SpawnPoint.CFrame.Position).Magnitude < 4, "Owner is moved to their base")
check(Ownership.isOwner(alice, baseA) and not Ownership.isOwner(bob, baseA), "Ownership check")

-- Eggs from the inventory
Inventory.add(alice, "BasicEgg", {Name = "Обычное яйцо", Category = "Eggs", Icon = "Egg", Count = 2})
Inventory.add(alice, "GoldEgg", {Name = "Золотое яйцо", Category = "Eggs", Icon = "Egg"})
local penA = Pens.pens(baseA)[1]
local prompt = penA.InteractionPoint.PenPrompt
check(prompt:GetAttribute("Active") == true and penA.InteractionPoint.PenInfo.Title.Text == "Свободный загон", "Empty pen invites to place an egg")
event(prompt, "Triggered"):Fire(bob)
check(penA:GetAttribute("State") == "Empty", "Another player cannot place eggs in your pen")
-- Hand-held egg via the hotbar remote.
local selectItem = game:GetService("ReplicatedStorage").OceanBases.Remotes.SelectItem
event(selectItem, "OnServerEvent"):Fire(alice, "GoldEgg")
check(alice:GetAttribute("HeldItem") == "GoldEgg", "Hotbar selection reaches the server")
event(selectItem, "OnServerEvent"):Fire(alice, "NotMine")
check(alice:GetAttribute("HeldItem") == "GoldEgg", "Server ignores items the player does not have")
event(selectItem, "OnServerEvent"):Fire(alice, nil)
event(prompt, "Triggered"):Fire(alice)
check(penA:GetAttribute("State") == "Egg" and penA:GetAttribute("EggType") == "BasicEgg", "Owner places an egg")
check(Inventory.count(alice, "BasicEgg") == 1, "The egg leaves the inventory")
check(#penA.Content:GetChildren() == 1 and penA.Content.Egg.PrimaryPart, "Egg model stands on the pedestal")
check(math.abs(penA.Content.Egg.Shell.CFrame.Position.Y - (penA.EggPlacement.CFrame.Position.Y + 1.4)) < 0.2, "Egg sits on top of the pedestal")
check(prompt:GetAttribute("Active") == false, "A busy pen hides its prompt")
event(prompt, "Triggered"):Fire(alice)
check(Inventory.count(alice, "BasicEgg") == 1, "Cannot place a second egg in the same pen")
alice:SetAttribute("HeldItem", "GoldEgg")
local penA2 = Pens.pens(baseA)[2]
event(penA2.InteractionPoint.PenPrompt, "Triggered"):Fire(alice)
check(penA2:GetAttribute("EggType") == "GoldEgg" and Inventory.count(alice, "GoldEgg") == 0, "The egg in the hand is used first")

-- Hatching
Pens.tick(1)
check(penA:GetAttribute("State") == "Egg" and penA.InteractionPoint.PenInfo.Line.Text:find("0:15") ~= nil, "Countdown shown until hatching")
serverTime += 15
Pens.tick(1)
check(penA:GetAttribute("State") == "Fish", "Egg hatches when its time is up")
local fishType = penA:GetAttribute("FishType")
check(Config.Eggs.BasicEgg.fish[fishType] ~= nil, "Fish comes from the egg's table")
local fish = penA.Content:FindFirstChildWhichIsA("Model")
check(fish and fish:GetAttribute("Center") and fish.PrimaryPart, "Fish model with a swim path appears in the pen")
check(penA.InteractionPoint.PenInfo.Line.Text == "+" .. Config.Fish[fishType].income .. " / сек", "Pen shows income per second")

-- Income
baseA:SetAttribute("Stored", 0)
Pens.tick(10)
local expected = Config.Fish[fishType].income * 10
check(math.abs(baseA:GetAttribute("Stored") - expected) < 1e-6, "Fish income goes into the base chest")
check(baseA.Chest.ChestPoint.ChestInfo.Amount.Text == tostring(expected), "Chest shows stored coins")
alice:SetAttribute("Coins", 0)
event(baseA.Chest.ChestPoint.CollectPrompt, "Triggered"):Fire(bob)
check(baseA:GetAttribute("Stored") == expected, "Another player cannot collect your coins")
event(baseA.Chest.ChestPoint.CollectPrompt, "Triggered"):Fire(alice)
check(alice:GetAttribute("Coins") == expected and baseA:GetAttribute("Stored") == 0, "Owner collects the coins")
Pens.tick(10)
check(baseB:GetAttribute("Stored") == 0, "Empty bases earn nothing")

-- Upgrades
local board = baseA.UpgradeBoard
check(board.BoardFace.UpgradeLabel.Text.Text:find("5,000") ~= nil, "Board shows the next floor price")
alice:SetAttribute("Coins", 100)
event(board.UpgradePoint.UpgradePrompt, "Triggered"):Fire(alice)
check(baseA:GetAttribute("Floors") == 2 and alice:GetAttribute("Coins") == 100, "Upgrade needs enough coins")
bob:SetAttribute("Coins", 999999)
event(board.UpgradePoint.UpgradePrompt, "Triggered"):Fire(bob)
check(baseA:GetAttribute("Floors") == 2 and bob:GetAttribute("Coins") == 999999, "Nobody can upgrade someone else's base")
alice:SetAttribute("Coins", 31000)
event(board.UpgradePoint.UpgradePrompt, "Triggered"):Fire(alice)
check(baseA:GetAttribute("Floors") == 3 and alice:GetAttribute("Coins") == 26000, "Buying floor 3 costs 5,000")
check(#Pens.pens(baseA) == 15 and baseA.Floors:FindFirstChild("Floor3"), "Floor 3 adds 5 pens on top")
check(math.abs(baseA.Floors.Floor3.FloorRoot.CFrame.Position.Y - (baseA.Root.CFrame.Position.Y + Config.floorTop(3))) < 1e-3, "New floor is placed above, not beside")
event(board.UpgradePoint.UpgradePrompt, "Triggered"):Fire(alice)
check(baseA:GetAttribute("Floors") == 4 and #Pens.pens(baseA) == 20 and alice:GetAttribute("Coins") == 1000, "Floor 4: 20 pens, 25,000 coins")
check(board.UpgradePoint.UpgradePrompt:GetAttribute("Active") == false and board.BoardFace.UpgradeLabel.Text.Text:find("Максимум") ~= nil, "Max level reached")
local newPen = baseA.Floors.Floor4.Pens:GetChildren()[1]
Inventory.add(alice, "StarEgg", {Name = "Звёздное яйцо", Category = "Eggs", Icon = "Egg"})
event(newPen.InteractionPoint.PenPrompt, "Triggered"):Fire(alice)
check(newPen:GetAttribute("State") == "Egg", "Pens on new floors work")

-- Lift
local lift1, lift4 = baseA.Floors.Floor1.Lift.LiftPoint, baseA.Floors.Floor4.Lift.LiftPoint
check(lift1.LiftUp:GetAttribute("Active") and not lift1.LiftDown:GetAttribute("Active"), "Ground lift only goes up")
check(not lift4.LiftUp:GetAttribute("Active") and lift4.LiftDown:GetAttribute("Active"), "Top lift only goes down")
check(baseA.Floors.Floor4.Lift.LiftTube.Transparency == 1 and baseA.Floors.Floor3.Lift.LiftTube.Transparency < 1, "Lift tube only below an upper floor")
event(lift1.LiftUp, "Triggered"):Fire(alice)
local y = alice.Character.HumanoidRootPart.CFrame.Position.Y
check(math.abs(y - (baseA.Floors.Floor2.Lift.LiftArrival.CFrame.Position.Y + 1)) < 1e-3, "Lift takes the player one floor up")
event(lift4.LiftUp, "Triggered"):Fire(alice)
check(alice.Character.HumanoidRootPart.CFrame.Position.Y == y, "Lift cannot go above the top floor")

-- Leaving frees the base
event(Players, "PlayerRemoving"):Fire(alice)
check(baseA:GetAttribute("OwnerUserId") == 0 and baseA.Entrance.OwnerSign.OwnerLabel.Text.Text == "Свободная база", "Leaving frees the base")
check(baseA:GetAttribute("Floors") == 2 and locked.Base1:FindFirstChild("Floor3") and locked.Base1:FindFirstChild("Floor4"), "Freed base goes back to 2 floors")
local busy = 0
for _, pen in Pens.pens(baseA) do if pen:GetAttribute("State") ~= "Empty" then busy += 1 end end
check(busy == 0 and baseA:GetAttribute("Stored") == 0, "Freed base has empty pens and chest")
local carol = makePlayer("Carol", 303)
check(Ownership.baseOf(carol) == baseA, "Next player gets the freed base")

-- Creature models
local scratch = r.Instance.new("Folder")
for eggType in Config.Eggs do
	local egg = Creatures.egg(scratch, eggType, r.CFrame.new())
	assert(egg.PrimaryPart and egg:GetAttribute("EggType") == eggType)
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
check(true, "Every fish type builds with a body, wagging tail and ripple")

-- Client animation
local Anim = load(tree.client.FishAnimationController)
local fishModel = Pens.pens(baseA)[1].Content:FindFirstChildWhichIsA("Model")
if not fishModel then
	-- Carol's base was reset; hatch a fresh fish for the animation check.
	local pen = Pens.pens(baseA)[1]
	pen:SetAttribute("EggType", "BasicEgg")
	Pens.hatch(pen, "ClownFish")
	fishModel = pen.Content:FindFirstChildWhichIsA("Model")
end
event(tagged, "add:OceanFish"):Fire(fishModel)
Anim.start()
event(tagged, "add:OceanFish"):Fire(fishModel)
local center = fishModel:GetAttribute("Center")
local positions = {}
for i = 0, 3 do
	Anim.step(i * 1.3, center + r.Vector3.new(0, 10, 10))
	positions[i] = fishModel.PrimaryPart.CFrame.Position
end
local area = fishModel.Parent.Parent.FishMovementArea
local inside = true
for _, p in positions do
	inside = inside and math.abs(p.X - area.CFrame.Position.X) <= area.Size.X / 2 and math.abs(p.Z - area.CFrame.Position.Z) <= area.Size.Z / 2
end
check(inside and (positions[0] - positions[2]).Magnitude > 0.5, "Fish swims around inside its pen")
Anim.step(5, center + r.Vector3.new(0, 1000, 0))
check(fishModel.PrimaryPart.CFrame.Position == positions[3], "Far-away fish are not animated")
Anim.stop()

fs.writeFile(root .. "test-report.json", serde.encode("json", {passed = true, count = #tests, tests = tests, studioPlayTest = false}, true))
print("PASS: " .. #tests .. " checks")
