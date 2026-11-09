-- Builds the full game place: ocean map + HUD (from OceanHUD's build) + the
-- five player bases (open yards) baked into Workspace.
-- Run from the OceanBases folder:  ..\..\tools\lune\lune.exe run tools/build.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local process = require("@lune/process")
local Env = require("./env")
local root = process.cwd:gsub("\\", "/"):gsub("/?$", "/")

local SOURCE = root .. "../OceanHUD/OceanMap-with-HUD.rbxl"
local OUTPUT = root .. "../OceanGame.rbxl"

local game = roblox.deserializePlace(fs.readFile(SOURCE))

-- Keep models the user imported into the previous OceanGame.rbxl
-- (ReplicatedStorage.OceanModels: Eggs, Fish, Predators).
local keptModels = 0
if fs.isFile(OUTPUT) then
	local previous = roblox.deserializePlace(fs.readFile(OUTPUT))
	local models = previous:GetService("ReplicatedStorage"):FindFirstChild("OceanModels")
	if models then
		models.Parent = game:GetService("ReplicatedStorage")
		keptModels = #models:GetDescendants()
	end
end
local tree = Env.install(game, root)
local load = Env.loader(game)
local Config = load(tree.shared.BaseConfig)
local Builder = load(tree.server.BaseBuilder)

local workspaceService = game:GetService("Workspace")
local old = workspaceService:FindFirstChild("OceanBases")
if old then old:Destroy() end

local basesFolder = roblox.Instance.new("Folder")
basesFolder.Name = "OceanBases"
for id = 1, Config.BaseCount do
	Builder.build(basesFolder, id, Builder.origin(id), Config.StartRows)
end
basesFolder.Parent = workspaceService

-- Seabed relief, wall rocks, stalactites and nests along the ocean corridor.
local Seabed = load(tree.server.SeabedBuilder)
local oldSeabed = workspaceService:FindFirstChild("OceanSeabed")
if oldSeabed then oldSeabed:Destroy() end
Seabed.build(workspaceService)
-- Small floor decor of the original map now lies under the sand: remove it.
local buried = 0
for _, part in workspaceService.OceanMap:GetDescendants() do
	if part:IsA("BasePart") and (part.Name:match("^Seabed") or part.Name == "SlopingEdgeInlay" or part.Name == "SectionFloorSeam") then
		part:Destroy()
		buried += 1
	end
end

-- Helper to sort imported GLB rigs into ReplicatedStorage.OceanModels (run once in Studio).
local storage = game:GetService("ServerStorage")
local oldOrganizer = storage:FindFirstChild("OceanModelsOrganizer")
if oldOrganizer then oldOrganizer:Destroy() end
local organizer = roblox.Instance.new("ModuleScript")
organizer.Name = "OceanModelsOrganizer"
organizer.Source = fs.readFile(root .. "src/server/OceanModelsOrganizer.luau")
organizer.Parent = storage

-- Runtime LocalScripts that animate the imported Studfish / StudPredators / StudEggs rigs.
local sps = game:GetService("StarterPlayer").StarterPlayerScripts
for _, data in {
	{"StudfishRuntime", "../StudfishExpansion/StudfishRuntime.txt"},
	{"StudPredatorsRuntime", "../StudPredators/StudPredatorsRuntime.txt"},
	{"StudEggsRuntime", "../StudEggs/StudEggsRuntime.txt"},
} do
	local old = sps:FindFirstChild(data[1])
	if old then old:Destroy() end
	local s = roblox.Instance.new("LocalScript")
	s.Name = data[1]
	s.Source = fs.readFile(root .. data[2])
	s.Parent = sps
end
-- Remove the old floors storage of the previous (multi-storey) design if present.
local oldLocked = game:GetService("ServerStorage"):FindFirstChild("OceanBasesLocked")
if oldLocked then oldLocked:Destroy() end

-- Studio opens looking at the bases from the court, slightly above.
local camera = workspaceService:FindFirstChildOfClass("Camera")
if camera then
	camera.CFrame = roblox.CFrame.lookAt(roblox.Vector3.new(20, 48, -70), roblox.Vector3.new(0, 4, -140))
end

local bytes = roblox.serializePlace(game)
fs.writeFile(OUTPUT, bytes)

-- Round trip: everything compiles, counts are as expected.
local restored = roblox.deserializePlace(bytes)
local scripts, parts = 0, 0
for _, object in restored:GetDescendants() do
	if object:IsA("LuaSourceContainer") then
		assert(#luau.compile(object.Source) > 0, "Invalid script: " .. object:GetFullName())
		scripts += 1
	end
end
for _, object in restored:GetService("Workspace").OceanBases:GetDescendants() do
	if object:IsA("BasePart") then parts += 1 end
end
fs.writeFile(root .. "build-report.json", serde.encode("json", {
	output = "brain rot/OceanGame.rbxl", scripts = scripts, placeBytes = #bytes,
	baseParts = parts, partsPerBase = parts // Config.BaseCount,
}, true))
local seabedParts = 0
for _, object in restored:GetService("Workspace").OceanSeabed:GetDescendants() do
	if object:IsA("BasePart") then seabedParts += 1 end
end
print(string.format("Built OceanGame.rbxl: %d scripts, %d base parts (%d per base), %d seabed parts, %d buried decor parts removed, %d imported model objects kept.",
	scripts, parts, parts // Config.BaseCount, seabedParts, buried, keptModels))
