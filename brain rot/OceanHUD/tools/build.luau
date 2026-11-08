-- Builds the OceanHUD script tree and a playable copy of the ocean map.
-- Run from the OceanHUD folder:  ..\..\tools\lune\lune.exe run tools/build.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local process = require("@lune/process")
local root = process.cwd:gsub("\\", "/"):gsub("/?$", "/")

local MODULES = {"UITheme", "UIAssets", "UIComponents", "UIAnimations", "UIDataController", "MenuController"}

local function source(path)
	local text = fs.readFile(root .. path)
	assert(#luau.compile(text) > 0, "Compile failed: " .. path)
	return text
end

-- Client: LocalScript "OceanHUD" (HUDController) with the UI modules inside it.
local function clientTree()
	local hud = roblox.Instance.new("LocalScript")
	hud.Name = "OceanHUD"
	hud.Source = source("src/OceanHUD.client.luau")
	for _, name in MODULES do
		local module = roblox.Instance.new("ModuleScript")
		module.Name = name
		module.Source = source("src/modules/" .. name .. ".luau")
		module.Parent = hud
	end
	return hud
end

-- Server: stats module (source of truth) + Studio-only test values.
local function serverTree()
	local stats = roblox.Instance.new("ModuleScript")
	stats.Name = "OceanHUDStats"
	stats.Source = source("src/server/OceanHUDStats.luau")
	local test = roblox.Instance.new("Script")
	test.Name = "OceanHUDTestData"
	test.Source = source("src/server/OceanHUDTestData.server.luau")
	return {stats, test}
end

fs.writeFile(root .. "OceanHUD.rbxmx", roblox.serializeModel({clientTree()}, true))
fs.writeFile(root .. "OceanHUD-Server.rbxmx", roblox.serializeModel(serverTree(), true))

-- Insert into a COPY of the map; the user's OceanMap files are never changed.
local game = roblox.deserializePlace(fs.readFile(root .. "../OceanMap/OceanMap-v4.rbxl"))
local starter = game:GetService("StarterPlayer")
local scripts = starter:FindFirstChild("StarterPlayerScripts")
if not scripts then
	scripts = roblox.Instance.new("StarterPlayerScripts")
	scripts.Parent = starter
end
assert(not scripts:FindFirstChild("OceanHUD"), "Source map already contains OceanHUD")
clientTree().Parent = scripts
for _, object in serverTree() do
	object.Parent = game:GetService("ServerScriptService")
end
local bytes = roblox.serializePlace(game)
fs.writeFile(root .. "OceanMap-with-HUD.rbxl", bytes)

-- Round-trip check: every script in the place compiles and the tree is intact.
local restored = roblox.deserializePlace(bytes)
local hud = restored:GetService("StarterPlayer").StarterPlayerScripts.OceanHUD
for _, name in MODULES do
	assert(hud:FindFirstChild(name) and hud[name]:IsA("ModuleScript"), "Missing module " .. name)
end
assert(restored:GetService("ServerScriptService"):FindFirstChild("OceanHUDStats"))
local count = 0
for _, object in restored:GetDescendants() do
	if object:IsA("LuaSourceContainer") then
		assert(#luau.compile(object.Source) > 0, "Invalid script: " .. object:GetFullName())
		count += 1
	end
end
fs.writeFile(root .. "build-report.json", serde.encode("json", {
	compiled = true, placeRoundTrip = true, modules = MODULES,
	placeScriptCount = count, placeBytes = #bytes,
}, true))
print("Built OceanHUD.rbxmx, OceanHUD-Server.rbxmx, OceanMap-with-HUD.rbxl; all " .. count .. " scripts compile.")
