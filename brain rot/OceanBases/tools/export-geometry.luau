-- Exports the parts of one base (plus its locked floors, optional) to JSON for
-- the offline preview renderer (tools/render_preview.py).
-- Usage: lune run tools/export-geometry.luau <place.rbxl> <out.json> <baseId> [floors]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")

local placePath, outPath = process.args[1], process.args[2]
local baseId = tonumber(process.args[3]) or 3
local floors = tonumber(process.args[4]) or 2
local game = roblox.deserializePlace(fs.readFile(placePath))
local base = game:GetService("Workspace").OceanBases["Base" .. baseId]
local list = {}
local function add(root)
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 0.99 then
			local shape = "Block"
			if part:IsA("WedgePart") then
				shape = "Wedge"
			elseif part:IsA("Part") then
				shape = part.Shape.Name
				if part:FindFirstChildOfClass("SpecialMesh") then shape = "Ellipsoid" end
			end
			local c = part.Color
			table.insert(list, {
				s = shape, size = {part.Size.X, part.Size.Y, part.Size.Z},
				cf = {part.CFrame:GetComponents()},
				c = {math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255)},
				t = part.Transparency, neon = part.Material == roblox.Enum.Material.Neon,
			})
		end
	end
end
add(base)
local storage = game:GetService("ServerStorage"):FindFirstChild("OceanBasesLocked")
local locked = storage and storage:FindFirstChild("Base" .. baseId)
if locked then
	for k = 3, floors do
		local floor = locked:FindFirstChild("Floor" .. k)
		if floor then add(floor) end
	end
end
fs.writeFile(outPath, serde.encode("json", list))
print("exported " .. #list .. " parts")
