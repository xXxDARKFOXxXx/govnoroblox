local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local game = roblox.deserializePlace(fs.readFile("game.rbxl"))
local function walk(obj, depth)
	if depth < 4 or obj:IsA("LuaSourceContainer") then
		print(string.rep("  ", depth) .. obj.ClassName .. " | " .. obj.Name .. " | " .. #obj:GetChildren())
	end
	if obj:IsA("LuaSourceContainer") then
		local name = obj:GetFullName():gsub("[^%w_-]", "_")
		fs.writeFile("build/original_" .. name .. ".luau", obj.Source)
		print("SCRIPT: " .. name .. " length=" .. #obj.Source)
	end
	for _, c in ipairs(obj:GetChildren()) do walk(c, depth + 1) end
end
walk(game, 0)
fs.writeFile("build/original.rbxlx", roblox.serializePlace(game, true))
