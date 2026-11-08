-- Real, swimmable Terrain water. Also callable from Studio's Command Bar.
-- Only writes inside this map's canal; never clears the user's Terrain.
local Water = {}
local Environment = require(game:GetService("ReplicatedStorage"):WaitForChild("OceanEnvironment"))
Water.SurfaceY = Environment.SurfaceY
Water.Width = Environment.HalfWidth * 2
Water.SectionLength = Environment.SectionLength
Water.FloorLevels = Environment.FloorLevels
Water.FloorAt = Environment.FloorAt

function Water.ApplyAppearance()
	local terrain = workspace.Terrain
	-- Maximum clarity is deliberate: the final section is 164 studs deep.
	-- Saturated cyan and reflected sky otherwise flatten the visible depth.
	terrain.WaterColor = Color3.fromRGB(126, 170, 176)
	terrain.WaterTransparency = 1
	terrain.WaterReflectance = 0
	terrain.WaterWaveSize = 0.06
	terrain.WaterWaveSpeed = 4
	local map = workspace:FindFirstChild("OceanMap")
	if map then
		local preview = map:FindFirstChild("WaterPreview")
		if preview then preview:Destroy() end
	end
end

function Water.Build()
	Water.ApplyAppearance()
	local terrain = workspace.Terrain
	-- All bounds align with the 4-stud terrain grid. Water extends below
	-- the solid sloping floor, so every exposed point stays swimmable.
	for z = 0, 956, 4 do
		local floor = math.min(Water.FloorAt(z), Water.FloorAt(z + 4))
		local bottom = math.floor((floor - 8) / 4) * 4
		terrain:FillBlock(CFrame.new(0, bottom / 2, z + 2), Vector3.new(128, -bottom, 4), Enum.Material.Water)
	end
	local map = workspace:FindFirstChild("OceanMap")
	if map then
		map:SetAttribute("WaterBaked", true)
	end
end

return Water
