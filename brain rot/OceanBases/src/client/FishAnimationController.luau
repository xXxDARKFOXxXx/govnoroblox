-- FishAnimationController (client): one shared Heartbeat loop that swims every
-- nearby fish on its oval in the air above the yard pool (bobbing, roll),
-- wags tails, pulses the glow ring on the water under it, and rocks eggs. Only models near the camera move.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))

local FishAnimationController = {}
local fish = {} -- [Model] = state
local eggs = {} -- [Model] = state
local connections = {}

local function trackFish(model: Model)
	local body = model.PrimaryPart or model:FindFirstChild("Body")
	local center = model:GetAttribute("Center")
	if not body or typeof(center) ~= "Vector3" then return end
	local tails = {}
	local ripple = model:FindFirstChild("Ripple")
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part:GetAttribute("Tail") then
			table.insert(tails, {part = part, offset = body.CFrame:ToObjectSpace(part.CFrame)})
		end
	end
	-- The tail swings around the back of the body.
	local hinge = 0
	for _, tail in tails do hinge = math.max(hinge, tail.offset.Position.Z - 0.4) end
	fish[model] = {
		body = body, center = center, tails = tails, hinge = CFrame.new(0, 0, hinge),
		rx = model:GetAttribute("RadiusX") or 2, rz = model:GetAttribute("RadiusZ") or 1.5,
		phase = model:GetAttribute("Phase") or 0, speed = model:GetAttribute("Speed") or Config.FishSwimSpeed,
		ripple = ripple, rippleSize = ripple and ripple.Size, floorY = model:GetAttribute("FloorY") or (center.Y - 3),
		base = model:GetPivot(),
		yaw = CFrame.Angles(0, math.rad(model:GetAttribute("ForwardYaw") or 0), 0),
	}
end

local function trackEgg(model: Model)
	-- Only eggs resting in a nest or a cell rock; an egg welded to a player
	-- must never be moved here (that would hold the player in place).
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if model:GetAttribute("Carried") or not primary or not primary.Anchored then return end
	eggs[model] = {base = model:GetPivot(), phase = math.random() * 6}
end

local function watch(tag, add, map)
	for _, model in CollectionService:GetTagged(tag) do add(model) end
	table.insert(connections, CollectionService:GetInstanceAddedSignal(tag):Connect(function(model)
		-- Attributes and children replicate with the model; wait one frame to be safe.
		task.defer(add, model)
	end))
	table.insert(connections, CollectionService:GetInstanceRemovedSignal(tag):Connect(function(model)
		map[model] = nil
	end))
end

function FishAnimationController.step(t: number, cameraPosition: Vector3)
	local maxDistance = Config.AnimationDistance
	for model, s in fish do
		if not model.Parent then
			fish[model] = nil
		elseif (s.center - cameraPosition).Magnitude < maxDistance then
			local a = s.phase + t * s.speed
			local pos = s.center + Vector3.new(math.cos(a) * s.rx, math.sin(t * 2.2 + s.phase) * 0.12, math.sin(a) * s.rz)
			-- Face the way the fish is moving (some fly clockwise, some anticlockwise).
			local tangent = Vector3.new(-math.sin(a) * s.rx, 0, math.cos(a) * s.rz) * (s.speed >= 0 and 1 or -1)
			-- ForwardYaw turns imported rigs (they look along -X) to face the way they swim.
			local cf = CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, 0, math.sin(t * 3 + s.phase) * 0.07) * s.yaw
			model:PivotTo(cf)
			local bodyCf = s.body.CFrame
			local wag = math.sin(t * 9 + s.phase) * 0.38
			for _, tail in s.tails do
				tail.part.CFrame = bodyCf * s.hinge * CFrame.Angles(0, wag, 0) * s.hinge:Inverse() * tail.offset
			end
			if s.ripple then
				local pulse = 1 + 0.22 * math.sin(t * 2.5 + s.phase)
				s.ripple.Size = Vector3.new(s.rippleSize.X, s.rippleSize.Y * pulse, s.rippleSize.Z * pulse)
				s.ripple.Transparency = 0.55 + 0.25 * (pulse - 0.78) / 0.44
				-- A glowing ring flat on the water, under the fish.
				s.ripple.CFrame = CFrame.new(pos.X, s.floorY + 0.05, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
			end
		end
	end
	for model, s in eggs do
		if not model.Parent or model:GetAttribute("Carried") then
			eggs[model] = nil
		elseif (s.base.Position - cameraPosition).Magnitude < maxDistance then
			local rock = math.sin(t * 2 + s.phase) * 0.06
			model:PivotTo(s.base * CFrame.Angles(rock, t * 0.5, rock * 0.6))
		end
	end
end

function FishAnimationController.start()
	watch("OceanFish", trackFish, fish)
	watch("OceanEgg", trackEgg, eggs)
	local start = os.clock()
	table.insert(connections, RunService.Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera
		if camera then
			FishAnimationController.step(os.clock() - start, camera.CFrame.Position)
		end
	end))
end

function FishAnimationController.stop()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	table.clear(fish)
	table.clear(eggs)
end

return FishAnimationController
