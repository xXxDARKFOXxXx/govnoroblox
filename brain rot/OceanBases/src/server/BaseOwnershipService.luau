-- BaseOwnershipService: gives every joining player a free base, moves their
-- character to it, and frees the base when they leave. All permission checks
-- (pens, chest, upgrades) go through isOwner on the server.
local Players = game:GetService("Players")

local BaseOwnershipService = {}
BaseOwnershipService.bases = {} -- array of base models, index = BaseId
BaseOwnershipService.byPlayer = {} -- [Player] = base
BaseOwnershipService.onAssigned = {} -- callbacks(player, base)
BaseOwnershipService.onReleased = {} -- callbacks(base)

local function setSign(base: Model, text: string)
	local entrance = base:FindFirstChild("Entrance")
	local sign = entrance and entrance:FindFirstChild("OwnerSign")
	local gui = sign and sign:FindFirstChild("OwnerLabel")
	local label = gui and gui:FindFirstChild("Text")
	if label then label.Text = text end
end

function BaseOwnershipService.baseOf(player: Player): Model?
	return BaseOwnershipService.byPlayer[player]
end

function BaseOwnershipService.isOwner(player: Player, base: Model?): boolean
	return base ~= nil and player ~= nil and base:GetAttribute("OwnerUserId") == player.UserId
		and BaseOwnershipService.byPlayer[player] == base
end

-- Finds the base an instance belongs to (walks up to the BaseN model).
function BaseOwnershipService.baseFrom(instance: Instance): Model?
	local node = instance
	while node and not (node:IsA("Model") and node:GetAttribute("BaseId")) do
		node = node.Parent
	end
	return node
end

function BaseOwnershipService.moveToBase(player: Player)
	local base = BaseOwnershipService.byPlayer[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local spawn = base and base:FindFirstChild("SpawnPoint")
	if root and spawn then
		character:PivotTo(spawn.CFrame + Vector3.new(0, 3, 0))
	end
end

function BaseOwnershipService.assign(player: Player): Model?
	if BaseOwnershipService.byPlayer[player] then return BaseOwnershipService.byPlayer[player] end
	for _, base in BaseOwnershipService.bases do
		if base:GetAttribute("OwnerUserId") == 0 then
			base:SetAttribute("OwnerUserId", player.UserId)
			base:SetAttribute("OwnerName", player.DisplayName)
			BaseOwnershipService.byPlayer[player] = base
			player:SetAttribute("BaseId", base:GetAttribute("BaseId"))
			setSign(base, "База: " .. player.DisplayName)
			for _, callback in BaseOwnershipService.onAssigned do callback(player, base) end
			return base
		end
	end
	return nil -- server full: the player can still swim, but has no base
end

function BaseOwnershipService.release(player: Player)
	local base = BaseOwnershipService.byPlayer[player]
	if not base then return end
	BaseOwnershipService.byPlayer[player] = nil
	for _, callback in BaseOwnershipService.onReleased do callback(base) end
	base:SetAttribute("OwnerUserId", 0)
	base:SetAttribute("OwnerName", "")
	setSign(base, "Свободная база")
end

function BaseOwnershipService.init(bases: {Model})
	BaseOwnershipService.bases = bases
	for _, base in bases do
		base:SetAttribute("OwnerUserId", 0)
		setSign(base, "Свободная база")
	end
	local function join(player: Player)
		BaseOwnershipService.assign(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			task.wait(0.1)
			BaseOwnershipService.moveToBase(player)
		end)
		if player.Character then BaseOwnershipService.moveToBase(player) end
	end
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do join(player) end
	Players.PlayerRemoving:Connect(BaseOwnershipService.release)
end

return BaseOwnershipService
