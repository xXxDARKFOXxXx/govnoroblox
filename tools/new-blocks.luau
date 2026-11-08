-- The GLBs in new blocks are the allow-list. Reuse their existing uploaded
-- Roblox meshes only after matching every named component and its dimensions.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Blocks = {}

function Blocks.catalog()
	local files = fs.readDir("new blocks")
	table.sort(files)
	local catalog = {}
	for _, file in ipairs(files) do
		if file:sub(-4):lower() == ".glb" then
			local bytes = fs.readFile("new blocks/" .. file)
			local data = buffer.fromstring(bytes)
			assert(bytes:sub(1, 4) == "glTF" and buffer.readu32(data, 4) == 2, "Invalid GLB: " .. file)
			assert(buffer.readu32(data, 16) == 0x4E4F534A, "GLB JSON chunk missing: " .. file)
			local gltf = serde.decode("json", bytes:sub(21, 20 + buffer.readu32(data, 12)))
			local preset = assert(file:match("^LB_%d+_(%w+)_v2%.glb$"), "Unmapped block filename: " .. file)
			local components = {}
			for _, node in ipairs(gltf.nodes) do
				if node.mesh ~= nil then
					assert(not node.matrix and not node.translation and not node.rotation and not node.scale,
						"Transformed GLB nodes require reimport: " .. file)
					local mesh = gltf.meshes[node.mesh + 1]
					assert(#mesh.primitives == 1, "Multi-primitive GLB requires reimport: " .. file)
					local bounds = gltf.accessors[mesh.primitives[1].attributes.POSITION + 1]
					components[node.name] = {
						bounds.max[1] - bounds.min[1], bounds.max[2] - bounds.min[2], bounds.max[3] - bounds.min[3],
					}
				end
			end
			table.insert(catalog, {File = file, Name = file:sub(1, -5), Preset = preset, Components = components})
		end
	end
	assert(#catalog > 0, "new blocks contains no GLBs")
	return catalog
end

function Blocks.findImported(original, entry)
	local matches = {}
	for _, scene in ipairs(original.Workspace:GetChildren()) do
		if scene:IsA("Model") and scene:FindFirstChild("Body_" .. entry.Preset .. "_Node") then
			local found = {}
			for _, part in ipairs(scene:GetDescendants()) do
				if part:IsA("MeshPart") then
					local size = assert(entry.Components[part.Name], "Unexpected imported component: " .. part.Name)
					assert(not found[part.Name], "Duplicated imported component: " .. part.Name)
					assert(math.abs(part.Size.X - size[1]) < 0.001 and math.abs(part.Size.Y - size[2]) < 0.001
						and math.abs(part.Size.Z - size[3]) < 0.001, "Imported dimensions differ from GLB: " .. entry.File .. "/" .. part.Name)
					found[part.Name] = true
				end
			end
			for component in pairs(entry.Components) do assert(found[component], "Missing imported component: " .. component) end
			table.insert(matches, scene)
		end
	end
	assert(#matches == 1, "Expected one already-imported matching block for " .. entry.File .. "; got " .. #matches)
	return matches[1]
end

return Blocks
