-- Shared geometry rules for water, swimming, camera effects and breath.
local Environment = {}
Environment.SurfaceY = 0
Environment.HalfWidth = 64
Environment.SectionLength = 192
Environment.Length = 960
Environment.FloorLevels = {4, -20, -44, -76, -116, -164}
Environment.VerticalSpeed = 10

function Environment.FloorAt(z)
	local section = math.clamp(math.floor(z / Environment.SectionLength) + 1, 1, 5)
	local alpha = math.clamp((z - (section - 1) * Environment.SectionLength) / Environment.SectionLength, 0, 1)
	return Environment.FloorLevels[section] + (Environment.FloorLevels[section + 1] - Environment.FloorLevels[section]) * alpha
end

function Environment.IsSubmerged(position, margin)
	return math.abs(position.X) < Environment.HalfWidth
		and position.Z >= 0 and position.Z < Environment.Length
		and position.Y < Environment.SurfaceY - (margin or 0.12)
		and position.Y > Environment.FloorAt(position.Z) - 0.5
end

function Environment.VerticalTarget(up, down)
	return ((up and 1 or 0) - (down and 1 or 0)) * Environment.VerticalSpeed
end

return Environment
