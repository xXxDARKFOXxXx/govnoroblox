-- Shared Lune helpers: load the OceanBases scripts into a DataModel and run
-- their ModuleScripts offline with Roblox data types (require shim).
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")

local Env = {}

Env.SERVER_MODULES = {"BasePieces", "CellBuilder", "BaseBuilder", "SeabedBuilder", "CreatureModels", "BaseOwnershipService", "FishPenController", "BaseUpgradeService", "NestService", "PredatorService", "SwimSpeedService", "HeldItemService"}
Env.CLIENT_MODULES = {"FishAnimationController", "BaseVisualEffects", "PlacementController", "CarryPoseController"}

-- WaitForChild does not exist offline; behave like a strict FindFirstChild.
roblox.implementMethod("Instance", "WaitForChild", function(object, name)
	return assert(object:FindFirstChild(name), "Missing child " .. tostring(name) .. " in " .. object:GetFullName())
end)

local function newScript(class, name, source, parent)
	local s = roblox.Instance.new(class)
	s.Name = name
	s.Source = source
	assert(#luau.compile(source) > 0, "Compile failed: " .. name)
	s.Parent = parent
	return s
end

-- Inserts the script tree into `game` (replacing an older copy) and returns it.
function Env.install(game, root: string)
	local read = function(path) return fs.readFile(root .. path) end
	local rs = game:GetService("ReplicatedStorage")
	local sss = game:GetService("ServerScriptService")
	local starter = game:GetService("StarterPlayer")
	local sps = starter:FindFirstChild("StarterPlayerScripts")
	if not sps then
		sps = roblox.Instance.new("StarterPlayerScripts")
		sps.Parent = starter
	end
	for _, pair in {{rs, "OceanBases"}, {sss, "OceanBases"}, {sps, "OceanBasesClient"}} do
		local old = pair[1]:FindFirstChild(pair[2])
		if old then old:Destroy() end
	end
	local shared = roblox.Instance.new("Folder")
	shared.Name = "OceanBases"
	shared.Parent = rs
	newScript("ModuleScript", "BaseConfig", read("src/shared/BaseConfig.luau"), shared)
	local server = roblox.Instance.new("Folder")
	server.Name = "OceanBases"
	server.Parent = sss
	for _, name in Env.SERVER_MODULES do
		newScript("ModuleScript", name, read("src/server/" .. name .. ".luau"), server)
	end
	newScript("Script", "OceanBasesServer", read("src/server/OceanBases.server.luau"), server)
	local client = newScript("LocalScript", "OceanBasesClient", read("src/client/OceanBasesClient.client.luau"), sps)
	for _, name in Env.CLIENT_MODULES do
		newScript("ModuleScript", name, read("src/client/" .. name .. ".luau"), client)
	end
	return {shared = shared, server = server, client = client}
end

-- require() for ModuleScripts inside `game`, with Roblox globals.
function Env.loader(game, extra)
	local cache = {}
	local function makeEnv(scriptInstance)
		local env = {game = game, workspace = game:GetService("Workspace"), script = scriptInstance}
		for _, key in {"Instance", "Vector2", "Vector3", "CFrame", "Color3", "UDim", "UDim2", "Enum",
			"ColorSequence", "NumberSequence", "NumberRange", "BrickColor", "Random", "Font"} do
			env[key] = roblox[key]
		end
		env.Random = env.Random or {new = function() return {NextNumber = function() return math.random() end} end}
		for key, value in extra or {} do env[key] = value end
		env.require = function(module)
			if cache[module] == nil then
				cache[module] = luau.load(module.Source, {debugName = module:GetFullName(), environment = makeEnv(module)})()
			end
			return cache[module]
		end
		return env
	end
	return function(module)
		return makeEnv(module).require(module)
	end, makeEnv
end

return Env
