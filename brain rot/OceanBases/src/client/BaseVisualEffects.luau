-- BaseVisualEffects (client): light, centralised decorative animation for the
-- bases — pulsing glow on lamps and crystals. Runs at 15 Hz and only touches parts near the camera.
local RunService = game:GetService("RunService")

local BaseVisualEffects = {}
local items = {}
local connection

local SHIMMER = {}
local PULSE = {Lamp = true, Crystal = true}

function BaseVisualEffects.collect(root: Instance)
	table.clear(items)
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") and (SHIMMER[part.Name] or PULSE[part.Name]) then
			table.insert(items, {part = part, base = part.Transparency, shimmer = SHIMMER[part.Name] == true,
				phase = (part.Position.X + part.Position.Z) * 0.15})
		end
	end
end

function BaseVisualEffects.step(t: number, cameraPosition: Vector3)
	for _, item in items do
		local part = item.part
		if part.Parent and (part.Position - cameraPosition).Magnitude < 160 then
			if item.shimmer then
				part.Transparency = math.clamp(item.base + 0.12 * math.sin(t * 1.8 + item.phase), 0, 0.95)
			else
				part.Transparency = 0.12 * (1 + math.sin(t * 2.4 + item.phase))
			end
		end
	end
end

function BaseVisualEffects.start(root: Instance)
	BaseVisualEffects.collect(root)
	-- The yard is rebuilt on upgrades: refresh the list when it changes.
	root.DescendantAdded:Connect(function(object)
		if object:IsA("Folder") and object.Name == "Yard" then
			task.defer(BaseVisualEffects.collect, root)
		end
	end)
	local start, last = os.clock(), 0
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - start
		if t - last < 1 / 15 then return end
		last = t
		local camera = workspace.CurrentCamera
		if camera then BaseVisualEffects.step(t, camera.CFrame.Position) end
	end)
end

function BaseVisualEffects.stop()
	if connection then connection:Disconnect() end
	table.clear(items)
end

return BaseVisualEffects
