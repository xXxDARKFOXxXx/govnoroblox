-- PredatorService (server): the guards of each ocean section. They patrol
-- calmly around their area and only attack a player who carries an egg taken
-- from a nest of their section. Deeper sections have faster guards. A guard
-- that catches the carrier takes the egg back (it returns to the nest) and
-- knocks the player away; if the carrier escapes the section, guards give up.
--
-- Models: Workspace.OceanPredators/<kind>, moved here with PivotTo (anchored,
-- no collision). Imported StudPredators rigs are animated by their runtime.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))
local Creatures = require(script.Parent:WaitForChild("CreatureModels"))
local Seabed = require(script.Parent:WaitForChild("SeabedBuilder"))
local Nests = require(script.Parent:WaitForChild("NestService"))

local PredatorService = {}
PredatorService.guards = {}
PredatorService.knock = nil -- function(player, velocity)

local MARGIN = 10 -- guards may follow a little past their section's ends
local GIVE_UP = 1.5 -- seconds outside the section before giving up

local function clampToSection(guard, pos: Vector3): Vector3
	local section = Config.Sections[guard.section]
	-- Never onto the start court or the shallow beach right after it.
	local z = math.clamp(pos.Z, math.max(section.fromZ - MARGIN, 24), section.toZ + MARGIN)
	local x = math.clamp(pos.X, -56, 56)
	local floor = Seabed.sandTop(x, math.clamp(z, 1, 959))
	local low = floor + guard.size * 0.25 + 1
	local y = math.clamp(pos.Y, math.min(low, -2), -2)
	return Vector3.new(x, y, z)
end

-- Turns the guard towards `direction` (quickly while chasing, so it always
-- swims head first at the player) and moves it to `pos`.
local function place(guard, pos: Vector3, direction: Vector3, turn: number?)
	local flat = Vector3.new(direction.X, direction.Y * 0.4, direction.Z)
	if flat.Magnitude < 1e-3 then flat = guard.heading end
	local goal = flat.Unit
	local heading = guard.heading:Lerp(goal, turn or 0.2)
	-- Turning right round: Lerp would pass through zero; swing sideways instead.
	if heading.Magnitude < 0.35 then
		local side = Vector3.new(-goal.Z, 0, goal.X)
		heading = (side.Magnitude > 1e-3 and side or Vector3.new(1, 0, 0)) + goal * 0.5
	end
	guard.heading = heading.Unit
	local cf = CFrame.lookAt(pos, pos + guard.heading) * CFrame.Angles(0, math.rad(guard.model:GetAttribute("ForwardYaw") or 0), 0)
	guard.model:PivotTo(cf)
	guard.pos = pos
end

function PredatorService.spawn(parent: Instance, kind: string, section: number, home: Vector3, radius: number)
	local info = Config.Predators[kind]
	local start = home + Vector3.new(radius, 0, 0)
	local model = Creatures.predator(parent, kind, CFrame.new(start))
	model:SetAttribute("Section", section)
	local guard = {
		model = model, kind = kind, section = section, home = home, radius = radius,
		size = info.length, pos = start, heading = Vector3.new(0, 0, 1),
		phase = (section * 1.7 + #PredatorService.guards * 2.3) % (math.pi * 2),
		state = "Patrol", target = nil, outside = 0, cooldown = 0,
	}
	table.insert(PredatorService.guards, guard)
	place(guard, start, Vector3.new(0, 0, 1))
	return guard
end

-- Nearest carrier of an egg from this guard's section, inside its reach.
local function findTarget(guard)
	local best, bestDistance = nil, math.huge
	for player, carry in Nests.carriers do
		if carry.section == guard.section then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local d = (root.CFrame.Position - guard.pos).Magnitude
				if d < bestDistance then best, bestDistance = player, d end
			end
		end
	end
	return best
end

local function inSection(guard, pos: Vector3): boolean
	local section = Config.Sections[guard.section]
	-- The shallow beach by the court counts as safe: guards cannot reach it.
	return pos.Z >= math.max(section.fromZ - MARGIN, 16) and pos.Z <= section.toZ + MARGIN
end

function PredatorService.step(dt: number, t: number)
	local sectionSpeed = function(guard) return Config.Sections[guard.section] end
	for _, guard in PredatorService.guards do
		local section = sectionSpeed(guard)
		guard.cooldown = math.max(0, guard.cooldown - dt)
		local target = guard.cooldown <= 0 and findTarget(guard) or nil
		local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		if root and inSection(guard, root.CFrame.Position) then
			guard.state, guard.target, guard.outside = "Chase", target, 0
		elseif guard.state == "Chase" then
			guard.outside += dt
			if guard.outside > GIVE_UP or not root then guard.state, guard.target = "Return", nil end
		end
		if guard.state == "Chase" and root then
			local goal = root.CFrame.Position
			local delta = goal - guard.pos
			local step = math.min(delta.Magnitude, section.chase * dt)
			local pos = clampToSection(guard, guard.pos + (delta.Magnitude > 0 and delta.Unit * step or Vector3.zero))
			place(guard, pos, delta, 0.45)
			-- The head is at the front of the model.
			local head = guard.pos + guard.heading * guard.size * 0.35
			if (head - goal).Magnitude < Config.CatchRadius + guard.size * 0.1 or (guard.pos - goal).Magnitude < Config.CatchRadius then
				Nests.drop(target, "caught")
				local away = (goal - guard.pos)
				away = Vector3.new(away.X, 0, away.Z)
				away = away.Magnitude > 0 and away.Unit or Vector3.new(0, 0, -1)
				-- The character is client-owned: the client applies the push.
				if PredatorService.knock then PredatorService.knock(target, away * 70 + Vector3.new(0, 35, 0)) end
				guard.cooldown = 3
				guard.state, guard.target = "Return", nil
			end
		else
			-- Patrol (or swim back to the patrol oval).
			local a = guard.phase + t * section.patrol / math.max(guard.radius, 4)
			local goal = guard.home + Vector3.new(math.cos(a) * guard.radius, math.sin(t * 0.7 + guard.phase) * 2, math.sin(a) * guard.radius * 0.55)
			goal = clampToSection(guard, goal)
			local delta = goal - guard.pos
			local speed = guard.state == "Return" and section.chase * 0.6 or section.patrol * 1.5
			if guard.state == "Return" and delta.Magnitude < 3 then guard.state = "Patrol" end
			local step = math.min(delta.Magnitude, speed * dt)
			place(guard, guard.pos + (delta.Magnitude > 0 and delta.Unit * step or Vector3.zero), delta)
		end
		guard.model:SetAttribute("State", guard.state)
	end
end

function PredatorService.init(seabed: Instance)
	local folder = workspace:FindFirstChild("OceanPredators") or Instance.new("Folder")
	folder.Name = "OceanPredators"
	folder.Parent = workspace
	for s, section in Config.Sections do
		local spots = Seabed.nestSpots(s)
		local mid = (section.fromZ + section.toZ) / 2
		local midFloor = Seabed.sandTop(0, mid)
		-- The big predator circles the middle of the section.
		PredatorService.spawn(folder, section.predator, s, Vector3.new(0, math.min(-6, midFloor + 14), mid), 30)
		-- Smaller scary guards stay close to the nests.
		for g, kind in section.guards do
			local spot = spots[(g - 1) % #spots + 1]
			PredatorService.spawn(folder, kind, s, Vector3.new(spot.X * 0.6, spot.Y + 6, spot.Z), 10)
		end
	end
	local start = os.clock()
	RunService.Heartbeat:Connect(function(dt)
		PredatorService.step(math.min(dt, 0.1), os.clock() - start)
	end)
end

return PredatorService
