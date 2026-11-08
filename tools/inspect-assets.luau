local fs = require("@lune/fs")
local r = require("@lune/roblox")
local g = r.deserializePlace(fs.readFile("game.rbxl"))
local function bounds(m)
	local lo, hi = r.Vector3.new(math.huge, math.huge, math.huge), r.Vector3.new(-math.huge, -math.huge, -math.huge)
	local count = 0
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			count += 1
			local v = p.CFrame.Position
			lo = lo:Min(v - p.Size / 2); hi = hi:Max(v + p.Size / 2)
		end
	end
	return tostring(lo), tostring(hi), count
end
for _, m in ipairs(g.Workspace:GetChildren()) do
	if m:IsA("Model") or m:IsA("Folder") then
		print(m.Name, bounds(m))
		for _, c in ipairs(m:GetChildren()) do print("  ", c.Name, c.ClassName, bounds(c)) end
	end
end
for _, c in ipairs(g.Workspace.StealAnEggMap.Base1:GetDescendants()) do
	if c:IsA("BasePart") then print("BASE PART", c.Name, c.CFrame.Position, c.Size) end
end
