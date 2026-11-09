-- BaseOwnershipService: gives every joining player a free base, moves their
-- character to it, and frees the base when they leave. All permission checks
-- (cells, upgrades) go through isOwner on the server. The owner's name floats
-- above the base.
local Players = game:GetService("Players")

local BaseOwnershipService = {}
BaseOwnershipService.bases = {} -- array of base models, index = BaseId
BaseOwnershipService.byPlayer = {} -- [Player] = base
BaseOwnershipService.onAssigned = {} -- callbacks(player, base)
BaseOwnershipService.onReleased = {} -- callbacks(base)

local FREE_COLOR = Color3.fromRGB(200, 230, 235)
local OWNER_COLOR = Color3.fromRGB(255, 255, 255)

-- Floating name above the yard (Yard.OwnerTag.OwnerGui.OwnerName).
function BaseOwnershipService.refreshTag(base: Model)
	local yard = base:FindFirstChild("Yard")
	local tag = yard and yard:FindFirstChild("OwnerTag")
	local gui = tag and tag:FindFirstChild("OwnerGui")
	local label = gui and gui:FindFirstChild("OwnerName")
	if not label then return end
	local name = base:GetAttribute("OwnerName")
	if base:GetAttribute("OwnerUserId") ~= 0 and name and name ~= "" then
		label.Text = name
		label.TextColor3 = OWNER_COLOR
	else
		label.Text = "Свободная база"
		label.TextColor3 = FREE_COLOR
	end
end
local function setSign(base: Model)
	BaseOwnershipService.refreshTag(base)
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
	local spawn = base and base:FindFirstChild("Yard") and base.Yard:FindFirstChild("SpawnPoint")
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
			setSign(base)
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
	setSign(base)
end

function BaseOwnershipService.init(bases: {Model})
	BaseOwnershipService.bases = bases
	for _, base in bases do
		base:SetAttribute("OwnerUserId", 0)
		setSign(base)
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
