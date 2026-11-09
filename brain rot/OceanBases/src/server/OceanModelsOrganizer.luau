-- OceanModelsOrganizer (ModuleScript in ServerStorage): after importing the GLB
-- files into Roblox Studio, run in the Command Bar (edit mode, not Play):
--
--   require(game.ServerStorage.OceanModelsOrganizer)()
--
-- It finds the imported rigs in Workspace by their root bone (StudFish_*,
-- StudPredator_*, StudEgg_*), anchors them, turns off collision, and moves them
-- into ReplicatedStorage.OceanModels/{Fish, Predators, Eggs} under the names
-- the game uses. Then save the place (File → Save). The build keeps this folder.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))

local PREFIXES = {
	{prefix = "StudFish_", category = "Fish"},
	{prefix = "StudPredator_", category = "Predators"},
	{prefix = "StudEgg_", category = "Eggs"},
}

local function folder(parent: Instance, name: string): Instance
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

-- The top-level object in Workspace that contains this bone.
local function topOf(instance: Instance): Instance
	local node = instance
	while node.Parent and node.Parent ~= workspace do node = node.Parent end
	return node
end

return function()
	local root = folder(ReplicatedStorage, "OceanModels")
	local moved, seen = {}, {}
	for _, bone in workspace:GetDescendants() do
		if bone:IsA("Bone") then
			for _, rule in PREFIXES do
				if bone.Name:sub(1, #rule.prefix) == rule.prefix then
					local model = topOf(bone)
					if not seen[model] then
						seen[model] = true
						local name = bone.Name:sub(#rule.prefix + 1)
						-- Scary Studfish (Piranha, Moray, ...) guard the nests: they are predators.
						local category = rule.category
						if category == "Fish" and Config.Predators[name] then category = "Predators" end
						for _, part in model:GetDescendants() do
							if part:IsA("BasePart") then
								part.Anchored = true
								part.CanCollide = false
							end
						end
						if model:IsA("BasePart") then
							model.Anchored = true
							model.CanCollide = false
						end
						local target = folder(root, category)
						local old = target:FindFirstChild(name)
						if old then old:Destroy() end
						model.Name = name
						model.Parent = target
						table.insert(moved, category .. "/" .. name)
					end
				end
			end
		end
	end
	print(string.format("OceanModels: moved %d models: %s", #moved, table.concat(moved, ", ")))
	return moved
end
