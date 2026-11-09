-- CarryPoseController (client): arm poses while holding something.
-- * An egg stolen from a nest (character child "CarriedEgg") is held up over
--   the head with both arms; the legs keep their walk / swim animation, so
--   the player swims with the legs only.
-- * An item picked in the inventory (character child "HeldItem") is held in
--   front of the chest with both arms.
-- Runs for every character in view, so other players see the pose too.
-- The pose overrides the animation each frame (Motor6D.Transform is written
-- after the Animator, in RunService.Stepped). Works with R15 and R6.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CarryPoseController = {}
local connection

local UP, FORWARD = math.rad(172), math.rad(80)

-- Joint transforms for one arm. side = 1 (right) / -1 (left).
local function r15Arm(pose: string, side: number)
	if pose == "Up" then
		-- Arm straight up, a little outwards; elbow slightly bent towards the egg.
		return CFrame.Angles(UP, 0, side * math.rad(-12)), CFrame.Angles(math.rad(18), 0, 0)
	end
	return CFrame.Angles(FORWARD, 0, side * math.rad(14)), CFrame.Angles(math.rad(25), 0, 0)
end

local function r6Arm(pose: string, side: number)
	local angle = pose == "Up" and UP or FORWARD
	return CFrame.Angles(0, 0, side * angle)
end

function CarryPoseController.poseFor(character: Model): string?
	if character:FindFirstChild("CarriedEgg") then return "Up" end
	if character:FindFirstChild("HeldItem") then return "Front" end
	return nil
end

function CarryPoseController.apply(character: Model, pose: string)
	local upper = character:FindFirstChild("RightUpperArm")
	if upper then
		for _, data in {{"Right", 1}, {"Left", -1}} do
			local name, side = data[1], data[2]
			local shoulder = character:FindFirstChild(name .. "UpperArm")
			local elbowPart = character:FindFirstChild(name .. "LowerArm")
			local joint = shoulder and shoulder:FindFirstChild(name .. "Shoulder")
			local elbow = elbowPart and elbowPart:FindFirstChild(name .. "Elbow")
			local shoulderCf, elbowCf = r15Arm(pose, side)
			if joint and joint:IsA("Motor6D") then joint.Transform = shoulderCf end
			if elbow and elbow:IsA("Motor6D") then elbow.Transform = elbowCf end
		end
		return
	end
	local torso = character:FindFirstChild("Torso")
	if torso then
		for _, data in {{"Right Shoulder", 1}, {"Left Shoulder", -1}} do
			local joint = torso:FindFirstChild(data[1])
			if joint and joint:IsA("Motor6D") then joint.Transform = r6Arm(pose, data[2]) end
		end
	end
end

function CarryPoseController.step()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local pose = character and CarryPoseController.poseFor(character)
		if pose then CarryPoseController.apply(character, pose) end
	end
end

function CarryPoseController.start()
	if connection then return end
	connection = RunService.Stepped:Connect(CarryPoseController.step)
end

function CarryPoseController.stop()
	if connection then connection:Disconnect() end
	connection = nil
end

return CarryPoseController
