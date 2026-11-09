-- NestService (server): eggs lying in the seabed nests. A player takes an egg
-- (prompt), carries it above their head and swims back; reaching the start
-- court puts it into the inventory. If a predator catches the carrier, or the
-- carrier dies or leaves, the egg goes back to its nest at once. Taken eggs
-- reappear in the nest after Config.NestRespawn seconds.
--
-- Player attributes while carrying: CarryEgg (egg id), CarrySection (1-5).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))
local Creatures = require(script.Parent:WaitForChild("CreatureModels"))

local NestService = {}
NestService.nests = {} -- [nest Model] = {available, egg, respawnAt}
NestService.carriers = {} -- [Player] = {eggType, nest, section, model}
NestService.notify = nil -- function(player, text, kind)
NestService.safeZ = -2 -- z below this = start court (safe, delivers the egg)

local Inventory

local function prompt(nest: Model): ProximityPrompt
	return nest.EggSpot.TakePrompt
end

function NestService.spawnEgg(nest: Model)
	local state = NestService.nests[nest]
	if state.egg then state.egg:Destroy() end
	local eggType = nest:GetAttribute("EggType")
	state.egg = Creatures.egg(nest, eggType, CFrame.new(nest.EggSpot.CFrame.Position.X, nest:GetAttribute("EggBottom") or (nest.EggSpot.CFrame.Position.Y - 0.3), nest.EggSpot.CFrame.Position.Z))
	state.available = true
	state.respawnAt = nil
	nest:SetAttribute("Available", true)
	prompt(nest).Enabled = true
end

local function attachEgg(player: Player, eggType: string)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	-- Held over the head in both hands (the client raises the arms).
	local frame = root.CFrame * Creatures.OverheadOffset
	local model = Creatures.egg(character, eggType, frame)
	model.Name = "CarriedEgg"
	Creatures.attach(model, root, frame, Creatures.OverheadOffset)
	return model
end

local function clearCarry(player: Player)
	local carry = NestService.carriers[player]
	NestService.carriers[player] = nil
	if carry and carry.model then carry.model:Destroy() end
	player:SetAttribute("CarryEgg", nil)
	player:SetAttribute("CarrySection", nil)
	return carry
end

-- Server-validated: take the egg from a nest.
function NestService.take(player: Player, nest: Model): boolean
	local state = NestService.nests[nest]
	if not state or not state.available or NestService.carriers[player] then return false end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then return false end
	if (root.CFrame.Position - nest.EggSpot.CFrame.Position).Magnitude > 14 then return false end
	local eggType = nest:GetAttribute("EggType")
	state.available = false
	if state.egg then state.egg:Destroy() end
	state.egg = nil
	nest:SetAttribute("Available", false)
	prompt(nest).Enabled = false
	NestService.carriers[player] = {eggType = eggType, nest = nest, section = nest:GetAttribute("Section"), model = attachEgg(player, eggType)}
	player:SetAttribute("CarryEgg", eggType)
	player:SetAttribute("CarrySection", nest:GetAttribute("Section"))
	if NestService.notify then NestService.notify(player, "Ты схватил яйцо! Плыви на базу — хищники уже рядом!", "warn") end
	return true
end

-- The carrier lost the egg (caught, died, left): it returns to its nest now.
function NestService.drop(player: Player, reason: string?)
	local carry = clearCarry(player)
	if not carry then return end
	NestService.spawnEgg(carry.nest)
	if NestService.notify and reason == "caught" then
		NestService.notify(player, "Хищник отобрал яйцо! Оно вернулось в гнездо.", "bad")
	end
end

-- The carrier reached safety: egg goes to the inventory, nest refills later.
function NestService.deliver(player: Player)
	local carry = clearCarry(player)
	if not carry then return end
	local info = Config.Eggs[carry.eggType]
	if Inventory then
		Inventory.add(player, carry.eggType, {Name = info.name, Category = "Eggs", Icon = "Egg"})
	end
	NestService.nests[carry.nest].respawnAt = os.clock() + Config.NestRespawn
	if NestService.notify then NestService.notify(player, info.name .. " теперь в инвентаре!", "good") end
end

function NestService.step()
	local now = os.clock()
	for player, carry in NestService.carriers do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not player.Parent or not humanoid or humanoid.Health <= 0 or not root or not carry.model or not carry.model.Parent then
			NestService.drop(player, "lost")
		elseif root.CFrame.Position.Z < NestService.safeZ then
			NestService.deliver(player)
		end
	end
	for nest, state in NestService.nests do
		if not state.available and state.respawnAt and now >= state.respawnAt then
			NestService.spawnEgg(nest)
		end
	end
end

function NestService.init(seabed: Instance)
	local module = ServerScriptService:FindFirstChild("OceanInventory")
	Inventory = module and require(module) or nil
	for _, nest in seabed.Nests:GetChildren() do
		NestService.nests[nest] = {available = false}
		NestService.spawnEgg(nest)
		prompt(nest).Triggered:Connect(function(player) NestService.take(player, nest) end)
	end
	Players.PlayerRemoving:Connect(function(player)
		if NestService.carriers[player] then NestService.drop(player, "left") end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			NestService.step()
		end
	end)
end

return NestService
