local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local root = "C:/gpt/roblox-game/brain rot/OceanHUD/"
local source = fs.readFile(root .. "src/OceanHUD.client.luau")
assert(#luau.compile(source) > 0)
local script = roblox.Instance.new("LocalScript")
script.Name = "OceanHUD"
script.Source = source
fs.writeFile(root .. "OceanHUD.rbxmx", roblox.serializeModel({script}, true))
fs.writeFile(root .. "OceanHUD.client.luau", source)
fs.writeFile(root .. "OceanHUD.txt", source)

-- Add to a COPY of v4; never change the user's original place.
local game = roblox.deserializePlace(fs.readFile("C:/gpt/roblox-game/brain rot/OceanMap/OceanMap-v4.rbxl"))
local starter = game:GetService("StarterPlayer")
local scripts = starter:FindFirstChild("StarterPlayerScripts")
if not scripts then
	scripts = roblox.Instance.new("StarterPlayerScripts")
	scripts.Parent = starter
end
assert(not scripts:FindFirstChild("OceanHUD"), "Copy already contains OceanHUD")
script:Clone().Parent = scripts
local bytes = roblox.serializePlace(game)
fs.writeFile(root .. "OceanMap-with-HUD.rbxl", bytes)
local restored = roblox.deserializePlace(bytes)
assert(restored:GetService("StarterPlayer").StarterPlayerScripts.OceanHUD.Source == source)
local count = 0
for _, object in restored:GetDescendants() do
	if object:IsA("LuaSourceContainer") then
		assert(#luau.compile(object.Source) > 0, "Invalid script: " .. object:GetFullName())
		count += 1
	end
end
local model = roblox.deserializeModel(fs.readFile(root .. "OceanHUD.rbxmx"))
assert(#model == 1 and model[1].ClassName == "LocalScript" and model[1].Source == source)
fs.writeFile(root .. "build-report.json", serde.encode("json", {
	compiled = true, modelRoundTrip = true, placeRoundTrip = true,
	placeScriptCount = count, placeBytes = #bytes, sourceBytes = #source,
}, true))
print("Built OceanHUD.rbxmx, OceanHUD.client.luau, OceanMap-with-HUD.rbxl; all " .. count .. " scripts compile.")
