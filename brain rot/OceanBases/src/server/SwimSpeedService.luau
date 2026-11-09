-- SwimSpeedService (server): the speed upgraded in the HUD (player attribute
-- SpeedLevel) makes the character swim and walk faster:
-- WalkSpeed = BaseWalkSpeed + SpeedLevel * SpeedPerLevel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))

local SwimSpeedService = {}

function SwimSpeedService.speedFor(player: Player): number
	local level = player:GetAttribute("SpeedLevel")
	if type(level) ~= "number" then level = 0 end
	return Config.BaseWalkSpeed + math.max(0, level) * Config.SpeedPerLevel
end

function SwimSpeedService.apply(player: Player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.WalkSpeed = SwimSpeedService.speedFor(player) end
end

function SwimSpeedService.init()
	local function join(player: Player)
		player:GetAttributeChangedSignal("SpeedLevel"):Connect(function() SwimSpeedService.apply(player) end)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			SwimSpeedService.apply(player)
		end)
		SwimSpeedService.apply(player)
	end
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do join(player) end
end

return SwimSpeedService
