-- Builds the full game place: ocean map + HUD (from OceanHUD's build) + the
-- five player bases baked into Workspace, locked floors in ServerStorage.
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
local tree = Env.install(game, root)
local load = Env.loader(game)
local Config = load(tree.shared.BaseConfig)
local Builder = load(tree.server.BaseBuilder)

local workspaceService = game:GetService("Workspace")
local old = workspaceService:FindFirstChild("OceanBases")
if old then old:Destroy() end
local storage = game:GetService("ServerStorage")
local oldLocked = storage:FindFirstChild("OceanBasesLocked")
if oldLocked then oldLocked:Destroy() end

local basesFolder = roblox.Instance.new("Folder")
basesFolder.Name = "OceanBases"
local locked = roblox.Instance.new("Folder")
locked.Name = "OceanBasesLocked"
for id = 1, Config.BaseCount do
	local origin = Builder.origin(id)
	Builder.build(basesFolder, id, origin, Config.StartFloors)
	local store = roblox.Instance.new("Folder")
	store.Name = "Base" .. id
	store.Parent = locked
	for k = Config.StartFloors + 1, Config.MaxFloors do
		Builder.buildFloor(store, origin, k)
	end
end
basesFolder.Parent = workspaceService
locked.Parent = storage

-- Studio opens looking at the bases from the court, slightly above.
local camera = workspaceService:FindFirstChildOfClass("Camera")
if camera then
	camera.CFrame = roblox.CFrame.lookAt(roblox.Vector3.new(30, 62, -40), roblox.Vector3.new(0, 8, -136))
end

local bytes = roblox.serializePlace(game)
fs.writeFile(OUTPUT, bytes)

-- Round trip: everything compiles, counts are as expected.
local restored = roblox.deserializePlace(bytes)
local scripts, parts, lockedParts = 0, 0, 0
for _, object in restored:GetDescendants() do
	if object:IsA("LuaSourceContainer") then
		assert(#luau.compile(object.Source) > 0, "Invalid script: " .. object:GetFullName())
		scripts += 1
	end
end
for _, object in restored:GetService("Workspace").OceanBases:GetDescendants() do
	if object:IsA("BasePart") then parts += 1 end
end
for _, object in restored:GetService("ServerStorage").OceanBasesLocked:GetDescendants() do
	if object:IsA("BasePart") then lockedParts += 1 end
end
fs.writeFile(root .. "build-report.json", serde.encode("json", {
	output = "brain rot/OceanGame.rbxl", scripts = scripts, placeBytes = #bytes,
	baseParts = parts, partsPerBase = parts // Config.BaseCount, lockedFloorParts = lockedParts,
}, true))
print(string.format("Built OceanGame.rbxl: %d scripts, %d base parts (%d per base), %d parts in locked floors.",
	scripts, parts, parts // Config.BaseCount, lockedParts))
