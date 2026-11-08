local map = workspace:WaitForChild("OceanMap")
local water = require(game:GetService("ServerStorage"):WaitForChild("OceanWater"))
-- Apply clarity even when Terrain has already been baked in Studio.
water.ApplyAppearance()
if not map:GetAttribute("WaterBaked") then
	water.Build()
end
