-- UIDataController: reads the player's stats and reports changes.
-- The server is the source of truth: it writes player attributes (see
-- OceanHUDStats on the server) or leaderstats values; the client only reads.
local UIDataController = {}
UIDataController.__index = UIDataController

-- Attributes win over same-named leaderstats values; the first name found wins.
UIDataController.Aliases = {
	Coins = {"Coins", "Money", "Cash", "Монеты", "Деньги"},
	SpeedLevel = {"SpeedLevel", "Speed", "Скорость"},
}
UIDataController.Defaults = {Coins = 0, SpeedLevel = 0}

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

-- onChange(key, newValue, oldValue) fires once per real change.
function UIDataController.new(player: Player, onChange: (string, number, number?) -> ())
	local self = setmetatable({
		player = player, onChange = onChange, values = {}, connections = {}, statConnections = {}, alive = true,
	}, UIDataController)
	for _, names in pairs(UIDataController.Aliases) do
		for _, name in names do
			table.insert(self.connections, player:GetAttributeChangedSignal(name):Connect(function() self:refresh() end))
		end
	end
	table.insert(self.connections, player.ChildAdded:Connect(function(child)
		if child.Name == "leaderstats" then self:bindStats() end
	end))
	table.insert(self.connections, player.ChildRemoved:Connect(function(child)
		if child.Name == "leaderstats" then self:bindStats() end
	end))
	return self
end

-- Call after storing the controller: reads current values and fires onChange for each.
function UIDataController:start()
	self:bindStats()
end

function UIDataController:read(key: string): number
	local names = UIDataController.Aliases[key]
	for _, name in names do
		local value = self.player:GetAttribute(name)
		if finite(value) then return value end
	end
	local stats = self.player:FindFirstChild("leaderstats")
	if stats then
		for _, name in names do
			local object = stats:FindFirstChild(name)
			if object and (object:IsA("IntValue") or object:IsA("NumberValue")) and finite(object.Value) then
				return object.Value
			end
		end
	end
	return UIDataController.Defaults[key]
end

function UIDataController:get(key: string): number
	return self.values[key] or self:read(key)
end

function UIDataController:refresh()
	if not self.alive then return end
	for _, key in {"Coins", "SpeedLevel"} do
		local value = self:read(key)
		local old = self.values[key]
		if value ~= old then
			self.values[key] = value
			self.onChange(key, value, old)
		end
	end
end

function UIDataController:clearStats()
	for _, connection in self.statConnections do connection:Disconnect() end
	table.clear(self.statConnections)
end

function UIDataController:bindStats()
	self:clearStats()
	local stats = self.player:FindFirstChild("leaderstats")
	if stats then
		local function changed() self:bindStats() end
		table.insert(self.statConnections, stats.ChildAdded:Connect(changed))
		table.insert(self.statConnections, stats.ChildRemoved:Connect(changed))
		for _, object in stats:GetChildren() do
			if object:IsA("IntValue") or object:IsA("NumberValue") then
				table.insert(self.statConnections, object:GetPropertyChangedSignal("Value"):Connect(function() self:refresh() end))
			end
		end
	end
	self:refresh()
end

function UIDataController:destroy()
	self.alive = false
	self:clearStats()
	for _, connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
end

-- 125430 -> "125,430"; huge values are shortened (2.5B) to keep plates tidy.
function UIDataController.format(value: number): string
	value = math.max(0, math.floor(value + 0.5))
	for _, unit in {{1e15, "Qa"}, {1e12, "T"}, {1e9, "B"}} do
		if value >= unit[1] then
			return (string.gsub(string.format("%.1f", value / unit[1]), "%.0$", "")) .. unit[2]
		end
	end
	local text = string.format("%d", value)
	local result = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (result:gsub("^,", ""))
end

return UIDataController
