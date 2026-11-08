local fs = require("@lune/fs")
local r = require("@lune/roblox")
local luau = require("@lune/luau")
local NewBlocks = require("./new-blocks")
local g = r.deserializePlace(fs.readFile("build/LuckyTide.rbxl"))
local count, active = 0, 0
for _, obj in ipairs(g:GetDescendants()) do
	if obj:IsA("LuaSourceContainer") then
		if not obj:IsDescendantOf(g:GetService("ServerStorage")) then
			luau.compile(obj.Source)
			count += 1
			if obj:IsA("BaseScript") then
				assert(not obj.Disabled, "Active game script was disabled: " .. obj:GetFullName())
				active += 1
			end
		else
			if obj:IsA("BaseScript") then assert(obj.Disabled, "Archived asset script must be disabled") end
		end
	end
end
local assets = g:GetService("ServerStorage").LuckyTideAssets.LuckyBlocks
local catalog = NewBlocks.catalog()
local allowedSources, usedSources, allowedMeshes = {}, {}, {}
assert(#assets:GetChildren() == #catalog, "Block library differs from new blocks folder")
for _, entry in ipairs(catalog) do
	local source = "new blocks/" .. entry.File
	allowedSources[source] = true
	local model = assert(assets:FindFirstChild(entry.Name), "Missing new blocks asset: " .. entry.Name)
	assert(model:GetAttribute("SourceFile") == source, "Block source mismatch")
end
local meshCount = 0
for _, p in ipairs(assets:GetDescendants()) do
	if p:IsA("MeshPart") then
		meshCount += 1
		local ok, content = pcall(function() return p.MeshContent end)
		if not ok then content = p.MeshId end
		assert(tostring(content):find("rbxassetid"), "Missing mesh reference: " .. tostring(content))
		allowedMeshes[tostring(content)] = true
	end
end
local world = g.Workspace.LuckyTideWorld
assert(#world.Plots:GetChildren() == 6)
assert(#world.Blocks:GetChildren() == 30)
for _, display in ipairs(world.Blocks:GetChildren()) do
	if display:IsA("Model") then
		local source = display:GetAttribute("SourceFile")
		assert(allowedSources[source], "Station uses an excluded block")
		usedSources[source] = true
		assert(not display:FindFirstChild("Cube"), "Procedural fallback cube must not remain")
	end
end
for source in pairs(allowedSources) do assert(usedSources[source], "New block is never displayed: " .. source) end
assert(not g:GetService("ServerStorage").OriginalPlace:FindFirstChild("Scene"), "Old lucky blocks remain in archive")
for _, obj in ipairs(g:GetDescendants()) do
	if obj:IsA("MeshPart") then
		local ok, content = pcall(function() return obj.MeshContent end)
		if not ok then content = obj.MeshId end
		assert(allowedMeshes[tostring(content)], "Excluded mesh remains in place: " .. obj:GetFullName())
	end
end
local textureCount = 0
for _, p in ipairs(g:GetDescendants()) do if p:IsA("SurfaceAppearance") then textureCount += 1 end end
print("PLACE VERIFIED: " .. count .. " compiled game scripts/modules; " .. active .. " enabled entry scripts; " .. meshCount .. " user meshes; " .. textureCount .. " material instances; ONLY " .. #catalog .. " new blocks assets")
