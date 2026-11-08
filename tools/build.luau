-- Reproducible place assembly. Source place is never modified.
local fs = require("@lune/fs")
local r = require("@lune/roblox")
local luau = require("@lune/luau")
local NewBlocks = require("./new-blocks")
local original = r.deserializePlace(fs.readFile("game.rbxl"))
local game = r.Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local storage = game:GetService("ServerStorage")
local assets = r.Instance.new("Folder"); assets.Name = "LuckyTideAssets"; assets.Parent = storage
local archive = r.Instance.new("Folder"); archive.Name = "OriginalPlace"; archive.Parent = storage
for _, obj in ipairs(original.Workspace:GetChildren()) do
	if not obj:IsA("Terrain") and not obj:IsA("Camera") and obj.Name ~= "Scene" and obj.Name ~= "LuckyBlocks" then
		local copy = obj:Clone(); copy.Parent = archive
		for _, child in ipairs(copy:GetDescendants()) do if child:IsA("BaseScript") then child.Disabled = true end end
	end
end
local oldScripts = r.Instance.new("Folder"); oldScripts.Name = "OriginalScripts"; oldScripts.Parent = archive
for _, oldScript in ipairs(original:GetService("ServerScriptService"):GetChildren()) do
	local copy = oldScript:Clone(); if copy:IsA("BaseScript") then copy.Disabled = true end; copy.Parent = oldScripts
end
local base = original.Workspace.StealAnEggMap.Base1:Clone(); base.Name = "BaseTemplate"; base.Parent = assets
local blockFolder = r.Instance.new("Folder"); blockFolder.Name = "LuckyBlocks"; blockFolder.Parent = assets
local tiers = {Chicken = 1, Frog = 1, Pizza = 1, Crab = 2, Shark = 2, Toilet = 2, Pumpkin = 3, Mystic = 4, Paradise = 4, Glitch = 5}
local manifest = {}

for _, entry in ipairs(NewBlocks.catalog()) do
	local scene = NewBlocks.findImported(original, entry)
	local tier = assert(tiers[entry.Preset], "No rarity configured for " .. entry.File)
	local copy = scene:Clone(); copy.Name = entry.Name; copy:SetAttribute("BlockTier", tier)
	copy:SetAttribute("SourceFile", "new blocks/" .. entry.File)
	for _, child in ipairs(copy:GetDescendants()) do
		if child:IsA("LuaSourceContainer") or child:IsA("ProximityPrompt") then child:Destroy()
		elseif child:IsA("BasePart") then child.Anchored = true end
	end
	copy.Parent = blockFolder
	table.insert(manifest, copy.Name .. " | tier " .. tier .. " | new blocks/" .. entry.File)
end

local shared = r.Instance.new("Folder"); shared.Name = "LuckyTide"; shared.Parent = game:GetService("ReplicatedStorage")
local server = r.Instance.new("Folder"); server.Name = "LuckyTide"; server.Parent = game:GetService("ServerScriptService")
local function source(parent, name, path, class)
	local obj = r.Instance.new(class or "ModuleScript"); obj.Name = name; obj.Source = fs.readFile(path); obj.Parent = parent; return obj
end
source(shared, "Config", "src/shared/Config.luau")
source(shared, "Rules", "src/shared/Rules.luau")
for _, name in ipairs({"Action", "State", "Effects"}) do local event = r.Instance.new("RemoteEvent"); event.Name = name; event.Parent = shared end
for _, name in ipairs({"World", "Visuals", "DataService"}) do source(server, name, "src/server/" .. name .. ".luau") end
source(server, "Main", "src/server/Main.server.luau", "Script")
local starter = game:GetService("StarterPlayer")
starter.CharacterWalkSpeed = 23
local ps = r.Instance.new("StarterPlayerScripts"); ps.Parent = starter
source(ps, "LuckyTideClient", "src/client/Main.client.luau", "LocalScript")
local sky = original:GetService("Lighting"):FindFirstChildOfClass("Sky")
if sky then sky:Clone().Parent = game:GetService("Lighting") end

r.implementMethod("Instance", "WaitForChild", function(obj, name) return assert(obj:FindFirstChild(name), "Missing " .. name) end)
r.implementProperty("BasePart", "Position", function(p) return p.CFrame.Position end, function(p, pos) p.CFrame = r.CFrame.new(pos) * (p.CFrame - p.CFrame.Position) end)
local cache = {}
local function loadModule(module)
	if cache[module] then return cache[module] end
	local env = {game = game, workspace = workspace, script = module, require = loadModule}
	for _, key in ipairs({"Instance", "Vector3", "Vector2", "CFrame", "Color3", "UDim2", "UDim", "Enum", "Font", "ColorSequence", "NumberSequence"}) do env[key] = r[key] end
	local result = luau.load(module.Source, {debugName = module.Name, environment = env})()
	cache[module] = result
	return result
end
local world = loadModule(server.World).Build()
local visuals = loadModule(server.Visuals)
for _, station in ipairs(world.Stations) do
	local _, part = visuals.block(world.Blocks, r.CFrame.new(station.Position), station.Tier, world.Templates, station.Variant)
	visuals.label(part, "ЛАКИ-БЛОК", visuals.color(loadModule(shared.Config).Rarities[station.Tier].Color), 180, 40)
end

local camera = r.Instance.new("Camera"); camera.Name = "Camera"
camera.CFrame = r.CFrame.lookAt(r.Vector3.new(210, 220, 300), r.Vector3.new(0, 0, 45))
camera.Focus = r.CFrame.new(0, 0, 45); camera.Parent = workspace; workspace.CurrentCamera = camera
workspace.FallenPartsDestroyHeight = -100
workspace.Gravity = 196.2
game:GetService("SoundService").RespectFilteringEnabled = true
local info = r.Instance.new("StringValue"); info.Name = "LuckyTide_README"
info.Value = "Play F5. E: interact. Q: recover stolen egg. B: upgrades. Studio is practice mode. Sources and build instructions: C:/gpt/roblox-game/README.md."
info.Parent = storage
fs.writeFile("build/assets.txt", table.concat(manifest, "\n"))
fs.writeFile("build/LuckyTide.rbxl", r.serializePlace(game))
fs.writeFile("build/LuckyTide.rbxlx", r.serializePlace(game, true))
print("BUILT build/LuckyTide.rbxl: " .. #manifest .. " user assets, " .. #world.Plots .. " plots, " .. #world.Stations .. " stations")
print("World instances: " .. #world.Root:GetDescendants())
