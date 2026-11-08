-- Checks the saved settings and both startup paths without a Studio renderer.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local root = "C:/gpt/roblox-game/brain rot/OceanMap/"
local contents = fs.readFile(root .. "OceanMap-v4.rbxl")
local calls = 0
roblox.implementMethod("Instance", "WaitForChild", function(self, name)
	return assert(self:FindFirstChild(name), "Missing " .. name)
end)
-- Terrain rendering/physics belong to Studio. Capture the build requests
-- here only to check that an appearance fix never refills baked terrain.
roblox.implementMethod("Terrain", "FillBlock", function(_, frame, size, material)
	assert(material == roblox.Enum.Material.Water)
	assert(size.X == 128 and size.Z == 4 and size.Y > 0)
	assert(frame.Position.Y + size.Y / 2 == 0)
	assert(frame.Position.Z >= 2 and frame.Position.Z <= 958)
	calls += 1
end)

for _, baked in {false, true} do
	calls = 0
	local place = roblox.deserializePlace(contents)
	local workspace = place:GetService("Workspace")
	local map, terrain = workspace.OceanMap, workspace.Terrain
	assert(terrain.WaterTransparency == 1 and terrain.WaterReflectance == 0)
	for _, panel in map.WaterPreview:GetChildren() do
		assert(panel.Transparency > 0.93 and panel.Material == roblox.Enum.Material.SmoothPlastic)
	end
	map:SetAttribute("WaterBaked", baked)
	-- Emulate an older, already baked scene retaining the old water values.
	terrain.WaterTransparency, terrain.WaterReflectance = 0.72, 0.08
	local environment = luau.load(place:GetService("ReplicatedStorage").OceanEnvironment.Source)()
	local water = luau.load(place:GetService("ServerStorage").OceanWater.Source, {
		environment = {workspace = workspace, game = place, require = function() return environment end, Color3 = roblox.Color3, CFrame = roblox.CFrame, Vector3 = roblox.Vector3, Enum = roblox.Enum},
	})()
	luau.load(place:GetService("ServerScriptService").OceanStart.Source, {
		environment = {workspace = workspace, game = place, require = function() return water end},
	})()
	assert(terrain.WaterTransparency == 1, "Startup restored opaque water")
	assert(terrain.WaterReflectance == 0, "Sky reflection still covers the bottom")
	assert(math.abs(terrain.WaterColor.R - 126 / 255) < 0.001)
	assert(map:FindFirstChild("WaterPreview") == nil, "Preview still covers real water")
	assert(map:GetAttribute("WaterBaked"), "New water did not record its baked state")
	assert(calls == (baked and 0 or 240), "Unexpected terrain rebuild")
	water.ApplyAppearance()
	assert(map:FindFirstChild("WaterPreview") == nil, "Appearance update is not repeatable")
	print("PASS", baked and "pre-baked water" or "fresh water", "clarity + no duplicate surface")
end
