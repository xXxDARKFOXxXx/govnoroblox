-- CarryPoseController (client): arm poses while holding something.
-- * An egg (stolen from a nest = "CarriedEgg", or picked in the inventory =
--   "HeldItem") is held up over the head with both arms — standing, running,
--   swimming and while putting it down. The legs keep their walk / swim
--   animation, so the player swims with the legs only.
-- * A fish picked in the inventory ("HeldItem" with HeldKind = "Fish") is held
--   in front of the chest.
-- Runs for every character, so other players see the pose too.
--
-- How: the shoulder / elbow Motor6D.C0 is turned (the walk / swim animation
-- only adds its swing on top of C0), and the animation's arm swing is cleared
-- every frame (Transform = identity, written after the Animator in Stepped).
-- C0 goes back to the original when the hands are empty. R15 and R6.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CarryPoseController = {}
local connections = {}
local original = setmetatable({}, {__mode = "k"}) -- [Motor6D] = C0 before posing

local UP, FORWARD = math.rad(175), math.rad(80)

-- Rotation for a joint (in its C0 frame). side = 1 right / -1 left.
local function r15Shoulder(pose: string, side: number): CFrame
	if pose == "Up" then
		-- Straight up, hands a little inwards to hold the egg over the head.
		return CFrame.Angles(UP, 0, side * math.rad(-8))
	end
	return CFrame.Angles(FORWARD, 0, side * math.rad(12))
end
local function r15Elbow(pose: string): CFrame
	return pose == "Up" and CFrame.Angles(math.rad(12), 0, 0) or CFrame.Angles(math.rad(25), 0, 0)
end
local function r6Shoulder(pose: string, side: number): CFrame
	return CFrame.Angles(0, 0, side * (pose == "Up" and UP or FORWARD))
end

function CarryPoseController.poseFor(character: Model): string?
	if character:FindFirstChild("CarriedEgg") then return "Up" end
	local held = character:FindFirstChild("HeldItem")
	if held then return held:GetAttribute("HeldKind") == "Fish" and "Front" or "Up" end
	return nil
end

-- The arm joints of a character: {joint, rotation function}.
local function armJoints(character: Model)
	local list = {}
	if character:FindFirstChild("RightUpperArm") then
		for _, data in {{"Right", 1}, {"Left", -1}} do
			local name, side = data[1], data[2]
			local upper = character:FindFirstChild(name .. "UpperArm")
			local lower = character:FindFirstChild(name .. "LowerArm")
			local shoulder = upper and upper:FindFirstChild(name .. "Shoulder")
			local elbow = lower and lower:FindFirstChild(name .. "Elbow")
			if shoulder and shoulder:IsA("Motor6D") then
				table.insert(list, {shoulder, function(pose) return r15Shoulder(pose, side) end})
			end
			if elbow and elbow:IsA("Motor6D") then
				table.insert(list, {elbow, r15Elbow})
			end
		end
	else
		local torso = character:FindFirstChild("Torso")
		for _, data in {{"Right Shoulder", 1}, {"Left Shoulder", -1}} do
			local joint = torso and torso:FindFirstChild(data[1])
			if joint and joint:IsA("Motor6D") then
				local side = data[2]
				table.insert(list, {joint, function(pose) return r6Shoulder(pose, side) end})
			end
		end
	end
	return list
end

-- Poses the arms (pose = "Up" / "Front") or puts them back (pose = nil).
function CarryPoseController.apply(character: Model, pose: string?)
	for _, entry in armJoints(character) do
		local joint, rotation = entry[1], entry[2]
		if pose then
			if not original[joint] then original[joint] = joint.C0 end
			joint.C0 = original[joint] * rotation(pose)
			joint.Transform = CFrame.new()
		elseif original[joint] then
			joint.C0 = original[joint]
			original[joint] = nil
		end
	end
end

function CarryPoseController.step()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			CarryPoseController.apply(character, CarryPoseController.poseFor(character))
		end
	end
end

function CarryPoseController.start()
	if #connections > 0 then return end
	-- C0 every frame, arm swing cleared after the Animator (Stepped) and again before drawing.
	table.insert(connections, RunService.Stepped:Connect(CarryPoseController.step))
	table.insert(connections, RunService.RenderStepped:Connect(CarryPoseController.step))
end

function CarryPoseController.stop()
	for _, c in connections do c:Disconnect() end
	table.clear(connections)
end

return CarryPoseController
