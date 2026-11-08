-- Runs the actual player script with Roblox instances and simulated service
-- events. This checks lifecycle/input/FX, not Roblox's physics solver.
local fs = require("@lune/fs")
local rbx = require("@lune/roblox")
local luau = require("@lune/luau")
local rootPath = "C:/gpt/roblox-game/brain rot/OceanMap/"
local place = rbx.deserializePlace(fs.readFile(rootPath .. "OceanMap-v4.rbxl"))
local workspace = place:GetService("Workspace")
local map = workspace.OceanMap
map:SetAttribute("WaterBaked", true)
local environment = luau.load(place:GetService("ReplicatedStorage").OceanEnvironment.Source)()
local V, C = rbx.Vector3, rbx.CFrame
local function signal()
	local result = {slots = {}}
	function result:Connect(callback)
		local slot = {callback = callback, connected = true}
		table.insert(self.slots, slot)
		return {Disconnect = function() slot.connected = false end}
	end
	function result:Fire(...)
		for _, slot in self.slots do if slot.connected then slot.callback(...) end end
	end
	return result
end
local ancestrySignals = {}
rbx.implementProperty("Instance", "AncestryChanged", function(self)
	if not ancestrySignals[self] then ancestrySignals[self] = signal() end
	return ancestrySignals[self]
end)
rbx.implementMethod("Instance", "WaitForChild", function(self, name)
	return assert(self:FindFirstChild(name), "Missing " .. name)
end)
rbx.implementProperty("BasePart", "Position", function(self) return self.CFrame.Position end,
	function(self, value) self.CFrame = self.CFrame + value - self.CFrame.Position end)
rbx.implementProperty("BasePart", "AssemblyMass", function() return 70 end)
local jumpEnabled = {}
rbx.implementMethod("Humanoid", "GetStateEnabled", function(self)
	return jumpEnabled[self] ~= false
end)
rbx.implementMethod("Humanoid", "SetStateEnabled", function(self, _, enabled)
	jumpEnabled[self] = enabled
end)

local function newRig(name, position)
	local rig = rbx.Instance.new("Model")
	rig.Name = name
	rig.Parent = workspace
	local root = rbx.Instance.new("Part")
	root.Name, root.Size, root.CFrame = "HumanoidRootPart", V.new(2, 2, 1), C.new(position)
	root.Anchored = false
	root.Parent = rig
	local head = rbx.Instance.new("Part")
	head.Name, head.Size, head.CFrame = "Head", V.new(2, 1, 1), C.new(position + V.new(0, 2, 0))
	head.Parent = rig
	local humanoid = rbx.Instance.new("Humanoid")
	humanoid.Health, humanoid.Sit = 100, false
	humanoid.Parent = rig
	return rig, root, head, humanoid
end
local rig, root, head, humanoid = newRig("TestR6", V.new(0, 8, -80))
local gui = rbx.Instance.new("PlayerGui")
local player = {Character = rig, CharacterAdded = signal(), CharacterRemoving = signal()}
function player:WaitForChild(name) assert(name == "PlayerGui"); return gui end
local players = {LocalPlayer = player, PlayerRemoving = signal()}
function players:GetPlayers() return {player} end
local input = {WindowFocusReleased = signal(), TextBoxFocused = signal(), focused = false, held = {}}
function input:GetFocusedTextBox() return self.focused and {} or nil end
function input:IsKeyDown(key) return self.held[key] == true end
local actions = {bound = {}}
function actions:BindActionAtPriority(name, callback, touch, priority)
	assert(touch and priority > 3000)
	self.bound[name] = callback
end
function actions:UnbindAction(name) self.bound[name] = nil end
function actions:SetTitle() end
function actions:SetPosition() end
local run = {PreSimulation = signal(), Heartbeat = signal()}
local services = {
	Players = players, RunService = run, ContextActionService = actions, UserInputService = input,
	GuiService = {MenuOpened = signal()}, Lighting = place:GetService("Lighting"),
	ReplicatedStorage = place:GetService("ReplicatedStorage"),
}
local gameMock = {GetService = function(_, name) return assert(services[name], name) end}
local scriptMock = {Destroying = signal()}
local api = {
	game = gameMock, workspace = workspace, script = scriptMock,
	require = function() return environment end,
	task = {spawn = function(fn, ...) fn(...) end},
	Random = {new = function() return {NextNumber = function(_, a, b) return (a + b) / 2 end} end},
}
for _, name in {"Instance", "Enum", "Color3", "Vector3", "CFrame", "UDim2", "NumberSequence"} do api[name] = rbx[name] end
luau.load(place:GetService("StarterPlayer").StarterPlayerScripts.OceanPlayer.Source, {environment = api})()
local function step(n)
	for _ = 1, n or 1 do run.PreSimulation:Fire(0.1); run.Heartbeat:Fire(0.1) end
end
local function move(position)
	root.CFrame = C.new(position)
	head.CFrame = C.new(position + V.new(0, 2, 0))
end
local function key(action, state, code)
	assert(actions.bound[action], "Action is not bound: " .. action)(action, state,
		{KeyCode = code, UserInputType = rbx.Enum.UserInputType.Keyboard})
end
local function visibleBubbles()
	local count = 0
	for _, part in workspace.OceanBreathBubbles:GetChildren() do
		if part.Name == "MouthBubble" and part.Transparency < 1 then count += 1 end
	end
	return count
end
local begin, finish = rbx.Enum.UserInputState.Begin, rbx.Enum.UserInputState.End
local constraint = root.OceanDepthControl
step()
assert(not constraint.Enabled and next(actions.bound) == nil, "Dry spawn must use normal controls")
move(V.new(0, -20, 300))
workspace.CurrentCamera.CFrame = C.new(0, -18, 298)
step(8)
assert(constraint.Enabled and constraint.LineVelocity == 0, "Idle must request zero vertical speed")
assert(constraint.VelocityConstraintMode == rbx.Enum.VelocityConstraintMode.Line and constraint.LineDirection == V.yAxis)
assert(constraint.RelativeTo == rbx.Enum.ActuatorRelativeTo.World)
assert(constraint.MaxForce > 70 * workspace.Gravity, "Force limit cannot counter gravity/buoyancy")
assert(jumpEnabled[humanoid] == false and not humanoid.Jump)
assert(visibleBubbles() > 0, "Submerged mouth does not emit bubbles")
assert(services.Lighting.OceanImmersionTint.TintColor.R < 0.9, "Camera has no underwater effect")
assert(services.Lighting.OceanImmersionSoftness.Size > 0)

key("OceanSwimUp", begin, rbx.Enum.KeyCode.Space); step()
assert(constraint.LineVelocity == 10)
key("OceanSwimUp", begin, rbx.Enum.KeyCode.E)
key("OceanSwimUp", finish, rbx.Enum.KeyCode.Space); step()
assert(constraint.LineVelocity == 10, "Releasing one ascent key cancelled another held key")
key("OceanSwimDown", begin, rbx.Enum.KeyCode.Q); step()
assert(constraint.LineVelocity == 0, "Opposite directions must cancel")
key("OceanSwimUp", finish, rbx.Enum.KeyCode.E); step()
assert(constraint.LineVelocity == -10)
input.WindowFocusReleased:Fire(); step()
assert(constraint.LineVelocity == 0, "Focus loss left a direction held")
key("OceanSwimDown", begin, rbx.Enum.KeyCode.Q)
input.focused = true; input.TextBoxFocused:Fire(); step()
assert(constraint.LineVelocity == 0)
input.focused = false

-- The torso may be submerged while the mouth and camera are above water.
move(V.new(0, -1, 300))
workspace.CurrentCamera.CFrame = C.new(0, 4, 296)
step(35)
assert(constraint.Enabled, "Neutral depth should still hold a partially submerged body")
assert(visibleBubbles() == 0, "Mouth above water must stop emitting")
assert(services.Lighting.OceanImmersionTint.TintColor.R > 0.999)
assert(services.Lighting.OceanImmersionSoftness.Size == 0)

move(V.new(0, 8, -80)); step()
assert(not constraint.Enabled and next(actions.bound) == nil and jumpEnabled[humanoid])
move(V.new(0, -20, 300)); humanoid.Sit = true; step()
assert(not constraint.Enabled, "Seated characters must not be controlled")
humanoid.Sit = false; step(); humanoid.Health = 0; step()
assert(not constraint.Enabled and next(actions.bound) == nil, "Death left swimming active")

player.CharacterRemoving:Fire(rig)
assert(constraint.Parent == nil, "Old depth constraint leaked after respawn")
rig, root, head, humanoid = newRig("TestR15", V.new(0, -20, 300))
head.Size = V.new(1.4, 1.4, 1.4)
player.Character = rig
player.CharacterAdded:Fire(rig); step(5)
assert(root.OceanDepthControl.Enabled and root.OceanDepthControl.LineVelocity == 0)
assert(visibleBubbles() > 0, "Respawn did not restore breath")
scriptMock.Destroying:Fire()
assert(root:FindFirstChild("OceanDepthControl") == nil and next(actions.bound) == nil)
assert(workspace:FindFirstChild("OceanBreathBubbles") == nil)
assert(services.Lighting:FindFirstChild("OceanImmersionTint") == nil)

assert(not environment.IsSubmerged(V.new(0, -2, -30)))
assert(not environment.IsSubmerged(V.new(70, -20, 300)))
assert(not environment.IsSubmerged(V.new(0, -50, 300)))
assert(environment.IsSubmerged(V.new(0, -120, 900)))
print("PASS neutral Y-only control; ascent/descent; focus; surface; camera FX; breath; death; respawn; cleanup")
