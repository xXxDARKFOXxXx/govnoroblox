-- HeldItemService (server): shows the item picked in the HUD (Player attribute
-- HeldItem: an egg id or a fish item id) in the character's hands, so the
-- owner sees what a click on the yard floor will place. Eggs keep their
-- original size; fish are shrunk to fit in the hands. While the player carries
-- an egg stolen from a nest (overhead), nothing is shown in the hands.
--
-- Character child "HeldItem" (Model, attribute Held = true, welded to the root,
-- massless and non-colliding). The client poses the arms for it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))
local Creatures = require(script.Parent:WaitForChild("CreatureModels"))

local HeldItemService = {}
local FISH_HOLD_LENGTH = 3.5

local function weldAll(model: Model, root: BasePart)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
	end
end

-- What the player holds: ("Egg", eggType) / ("Fish", fishType) / nil.
function HeldItemService.heldKind(player: Player): (string?, string?)
	local held = player:GetAttribute("HeldItem")
	if type(held) ~= "string" then return nil, nil end
	local inventory = player:FindFirstChild("Inventory")
	local item = inventory and inventory:FindFirstChild(held)
	if not item then return nil, nil end
	if Config.Eggs[held] then return "Egg", held end
	local fishType = item:GetAttribute("FishType")
	if item:GetAttribute("Category") == "Fish" and Config.Fish[fishType] then return "Fish", fishType end
	return nil, nil
end

function HeldItemService.update(player: Player)
	local character = player.Character
	if not character then return end
	local old = character:FindFirstChild("HeldItem")
	if old then old:Destroy() end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or player:GetAttribute("CarryEgg") then return end
	local kind, name = HeldItemService.heldKind(player)
	if not kind then return end
	-- Held in front of the chest, in both hands (arms forward on the client).
	local front = root.CFrame * CFrame.new(0, -0.4, -2.0)
	local model
	if kind == "Egg" then
		local size = Config.Eggs[name].size or Vector3.new(2.6, 3.5, 2.6)
		model = Creatures.egg(character, name, front * CFrame.new(0, 0, -size.Z / 2 + 0.6))
	else
		model = Creatures.fish(character, name, front * CFrame.new(0, 1.0, -0.6) * CFrame.Angles(0, math.rad(90), 0))
		local length = Config.Fish[name].length or 4
		if length > FISH_HOLD_LENGTH then
			local pivot = model:GetPivot()
			model:ScaleTo(model:GetScale() * FISH_HOLD_LENGTH / length)
			model:PivotTo(pivot)
		end
		local ripple = model:FindFirstChild("Ripple")
		if ripple then ripple:Destroy() end
	end
	model.Name = "HeldItem"
	-- Not animated in place by the pen animation (that would pin the player).
	model:RemoveTag("OceanEgg")
	model:RemoveTag("OceanFish")
	model:SetAttribute("Held", true)
	model:SetAttribute("Carried", true)
	weldAll(model, root)
end

function HeldItemService.watch(player: Player)
	player:GetAttributeChangedSignal("HeldItem"):Connect(function() HeldItemService.update(player) end)
	player:GetAttributeChangedSignal("CarryEgg"):Connect(function() HeldItemService.update(player) end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		HeldItemService.update(player)
	end)
	-- The item may run out (placed, deleted): drop it from the hands.
	local function watchInventory(folder: Instance)
		folder.ChildRemoved:Connect(function(item)
			if player:GetAttribute("HeldItem") == item.Name then player:SetAttribute("HeldItem", nil) end
		end)
	end
	local inventory = player:FindFirstChild("Inventory")
	if inventory then watchInventory(inventory) end
	player.ChildAdded:Connect(function(child)
		if child.Name == "Inventory" then watchInventory(child) end
	end)
end

function HeldItemService.init()
	for _, player in Players:GetPlayers() do HeldItemService.watch(player) end
	Players.PlayerAdded:Connect(HeldItemService.watch)
end

return HeldItemService
