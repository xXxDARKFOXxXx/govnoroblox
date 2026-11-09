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
print(string.format("Built OceanGame.rbxl: %d scripts, %d base parts (%d per base).", scripts, parts, parts // Config.BaseCount))
