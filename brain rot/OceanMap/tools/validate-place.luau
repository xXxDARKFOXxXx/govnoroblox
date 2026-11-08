local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local root = "C:/gpt/roblox-game/brain rot/OceanMap/"
local game = roblox.deserializePlace(fs.readFile(root .. "OceanMap-v4.rbxlx"))
local map = game:GetService("Workspace").OceanMap
local partCount, scriptCount, floorCount = 0, 0, 0
local minX, maxX = math.huge, -math.huge
for _, inst in game:GetDescendants() do
	if inst:IsA("LuaSourceContainer") then
		assert(#luau.compile(inst.Source) > 0, inst.Name .. " did not compile")
		scriptCount += 1
	end
	if inst:IsA("BasePart") and inst.ClassName ~= "Terrain" then
		partCount += 1
		assert(inst.Anchored, inst.Name .. " is not anchored")
		assert(inst.Size.X > 0 and inst.Size.Y > 0 and inst.Size.Z > 0)
		local c = inst.Color
		assert(c.R >= 0 and c.G >= 0 and c.B >= 0)
		if inst.Name == "SpawnFloorTile" then
			floorCount += 1
			local p = inst.CFrame.Position
			minX = math.min(minX, p.X - inst.Size.X / 2)
			maxX = math.max(maxX, p.X + inst.Size.X / 2)
			assert(c.R > c.G and c.G > c.B, "Spawn floor must be sand colored")
			assert(c.R <= 175 / 255, "Spawn floor is too bright")
			assert(inst.TopSurface == roblox.Enum.SurfaceType.Studs, "Studs were lost")
		end
	end
end
assert(scriptCount == 5, "Missing runtime scripts")
assert(floorCount == 720 and minX == -144 and maxX == 144, "Incorrect widened floor")
local sectionCount = 0
for _, section in map.Sections:GetChildren() do
	if section:IsA("Model") then
		sectionCount += 1
		local floors = 0
		for _, p in section:GetChildren() do
			if p.Name == "SlopedFloorTile" then floors += 1 end
		end
		assert(floors == 384, "A corridor floor has missing tiles")
	end
end
assert(sectionCount == 5, "There must be five sections")
for _, p in map.WallDecor:GetDescendants() do
	if p:IsA("BasePart") then
		assert(not p.CanCollide and not p.CanTouch, "Decor blocks the player")
		local pos = p.CFrame.Position
		if pos.Z > 4 and pos.Z < 956 then
			assert(math.abs(pos.X) > 58, "Decor obstructs the canal centre: " .. p.Name)
		elseif pos.Z < -5 and pos.Z > -150 then
			assert(math.abs(pos.X) > 137, "Decor obstructs the spawn centre: " .. p.Name)
		end
	end
end
local environment = luau.load(game:GetService("ReplicatedStorage").OceanEnvironment.Source)()
local seabedParts, middleParts = 0, 0
local coverage = {0, 0, 0, 0, 0}
for _, p in map.SeabedDecor:GetDescendants() do
	if p:IsA("BasePart") then
		assert(not p.CanCollide and not p.CanTouch, "Seabed decor blocks swimming")
		local pos = p.CFrame.Position
		assert(math.abs(pos.X) < 61 and pos.Z > 32 and pos.Z < 960)
		assert(pos.Y < 0, "Seabed decor rises above water")
		assert(pos.Y > environment.FloorAt(pos.Z) - 1, "Seabed decor is buried")
		seabedParts += 1
		if math.abs(pos.X) < 30 then middleParts += 1 end
		local index = math.clamp(math.floor(pos.Z / 192) + 1, 1, 5)
		coverage[index] += 1
	end
end
assert(seabedParts > 3000 and middleParts > 1000, "Seabed is still empty")
for _, count in coverage do assert(count > 400, "A section lacks seabed decoration") end
local native = roblox.serializePlace(game)
fs.writeFile(root .. "OceanMap-v4.rbxl", native)
local reopened = roblox.deserializePlace(native)
assert(#reopened:GetDescendants() == #game:GetDescendants(), "Binary round trip lost objects")
local report = { passed = true, partCount = partCount, scriptCount = scriptCount, spawnWidth = maxX - minX, spawnFloorTiles = floorCount, sectionCount = sectionCount, binaryBytes = #native, seabedParts = seabedParts, seabedCoverage = coverage }
fs.writeFile(root .. "validation.json", serde.encode("json", report, true))
print(report)
