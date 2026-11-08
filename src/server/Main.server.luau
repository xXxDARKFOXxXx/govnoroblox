local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("LuckyTide")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local Data = require(script.Parent.DataService)
local V = require(script.Parent.Visuals)
local World = require(script.Parent.World)
local world = World.Load()
local remote = Shared:WaitForChild("Action")
local stateRemote = Shared:WaitForChild("State")
local fx = Shared:WaitForChild("Effects")
local random = Random.new()
local sessions, drops = {}, {}
local closing = false
local nextWave = workspace:GetServerTimeNow() + Config.WaveInterval
local waveStart, wavePart = nil, nil
local refreshPlot, cancelCarry, deposit, sendState

local function notify(player, text, kind)
	if player.Parent then stateRemote:FireClient(player, "Toast", {Text = text, Kind = kind or "Info"}) end
end

local function rootOf(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return nil end
	return char:FindFirstChild("HumanoidRootPart"), hum
end

local function cooldown(player, key, duration)
	local s = sessions[player]
	if not s then return false end
	local now = os.clock()
	if now < (s.Cooldowns[key] or 0) then return false end
	s.Cooldowns[key] = now + duration
	return true
end

local function incomeOf(data)
	local total = 0
	for _, item in ipairs(data.Inventory) do
		if item.Hatched then total += Rules.income(Rules.findPet(Config, item.PetId), item.Mutation, data.Rebirths) end
	end
	return total
end

local function updateSpeed(player)
	local s, data = sessions[player], Data.Profiles[player]
	local _, hum = rootOf(player)
	if hum and s and data then hum.WalkSpeed = Rules.speed(data.Speed, s.Carry ~= nil) end
end

sendState = function(player)
	local data, s = Data.Profiles[player], sessions[player]
	if not data or not s or not player.Parent then return end
	local inventory = {}
	for _, item in ipairs(data.Inventory) do
		table.insert(inventory, {Id = item.Id, PetId = item.PetId, Tier = item.Tier, Mutation = item.Mutation,
			ReadyAt = item.ReadyAt, Hatched = item.Hatched, Stolen = item.ReservedBy ~= nil})
	end
	stateRemote:FireClient(player, "Profile", {
		Cash = data.Cash, Bank = data.Bank, Strength = data.Strength, Weight = data.Weight, Speed = data.Speed,
		Slots = data.Slots, Rebirths = data.Rebirths, Income = incomeOf(data), Hatched = data.Hatched,
		Tutorial = data.Tutorial, Inventory = inventory, Discovered = data.Discovered,
		PlotId = s.Plot.Model:GetAttribute("PlotId"), Home = s.Plot.Spawn.CFrame.Position,
		Carrying = s.Carry and {Tier = s.Carry.Item.Tier, Golden = s.Carry.Item.Mutation == "Golden", Stolen = s.Carry.Origin ~= nil},
		ShieldRemaining = math.max(0, math.ceil(s.ShieldUntil - os.clock())),
		ShieldCooldown = math.max(0, math.ceil(s.ShieldReady - os.clock())),
		Practice = RunService:IsStudio(),
	})
	local ls = player:FindFirstChild("leaderstats")
	if ls then ls.Cash.Value = math.floor(data.Cash); ls.Power.Value = data.Strength; ls.Rebirths.Value = data.Rebirths end
end

local function destroyDrop(id)
	local drop = drops[id]
	if drop then drops[id] = nil; drop.Part:Destroy() end
end

cancelCarry = function(player, reason)
	local s = sessions[player]
	if not s or not s.Carry then return end
	local carry = s.Carry; s.Carry = nil
	if carry.Part then carry.Part:Destroy() end
	if carry.Origin and Data.Profiles[carry.Origin] then
		carry.Item.ReservedBy = nil
		refreshPlot(carry.Origin)
		sendState(carry.Origin)
	end
	updateSpeed(player); sendState(player)
	if reason then notify(player, reason, "Warn") end
end

local function beginCarry(player, item, origin)
	local s, data = sessions[player], Data.Profiles[player]
	local root = rootOf(player)
	if not s or not root or s.Carry then return false end
	if #data.Inventory >= data.Slots then notify(player, "База заполнена. Продайте питомца или купите место.", "Warn"); return false end
	local part = V.egg(world.Drops, root.CFrame * CFrame.new(0, 1, -2.6), item.Tier, item.Mutation == "Golden")
	part.Anchored = false; part.Massless = true; part.CanCollide = false; part.CanTouch = false
	local weld = Instance.new("WeldConstraint"); weld.Part0 = root; weld.Part1 = part; weld.Parent = part
	V.label(part, "ДОНЕСИ НА БАЗУ", V.color(Config.Rarities[item.Tier].Color), 180, 40, Vector3.new(0, 2.5, 0))
	s.Carry = {Item = item, Origin = origin, Part = part, Started = os.clock()}
	if origin then item.ReservedBy = player end
	data.Tutorial = math.max(data.Tutorial, 1)
	updateSpeed(player); sendState(player)
	notify(player, "Яйцо у тебя! Вернись на зелёную площадку своей базы.", "Success")
	return true
end

deposit = function(player)
	local s, data = sessions[player], Data.Profiles[player]
	if not s or not s.Carry or #data.Inventory >= data.Slots then return end
	local root = rootOf(player)
	if not root or (root.CFrame.Position - s.Plot.Deposit.CFrame.Position).Magnitude > 12 then return end
	local carry = s.Carry
	if carry.Origin then
		local ownerData = Data.Profiles[carry.Origin]
		local index = ownerData and table.find(ownerData.Inventory, carry.Item)
		if not index or carry.Item.ReservedBy ~= player then cancelCarry(player, "Это яйцо уже вернулось владельцу."); return end
		table.remove(ownerData.Inventory, index)
		refreshPlot(carry.Origin); sendState(carry.Origin)
		notify(carry.Origin, "Яйцо похищено! Включайте щит у входа.", "Warn")
	end
	carry.Item.ReservedBy = nil
	carry.Item.ReadyAt = os.time() + Config.Rarities[carry.Item.Tier].Hatch
	carry.Item.Hatched = false
	table.insert(data.Inventory, carry.Item)
	s.Carry = nil; carry.Part:Destroy()
	data.Tutorial = math.max(data.Tutorial, 2)
	updateSpeed(player); refreshPlot(player); sendState(player)
	fx:FireAllClients("Burst", s.Plot.Deposit.CFrame.Position + Vector3.new(0, 2, 0), carry.Item.Tier)
	notify(player, "Яйцо в гнезде. Скоро вылупится питомец!", "Success")
end

refreshPlot = function(player)
	local s, data = sessions[player], Data.Profiles[player]
	if not s or not data then return end
	s.Plot.Display:ClearAllChildren()
	for i, pad in ipairs(s.Plot.Slots) do
		pad.Color = if i <= data.Slots then Color3.fromRGB(201, 218, 215) else Color3.fromRGB(90, 105, 111)
		local old = pad:FindFirstChild("Label"); if old then old:Destroy() end
		if i > data.Slots then V.label(pad, "ЗАКРЫТО", Color3.fromRGB(165, 177, 190), 100, 30, Vector3.new(0, 1.5, 0)) end
		local item = data.Inventory[i]
		if item and not item.ReservedBy then
			local pet = Rules.findPet(Config, item.PetId)
			if item.Hatched then
				local model, body = V.pet(s.Plot.Display, pad.CFrame * CFrame.new(0, 1.85, 0), item)
				model:SetAttribute("PetId", pet.Id)
				V.label(body, (if item.Mutation == "Golden" then "★ " else "") .. pet.Name .. "\n+$" .. Rules.format(Rules.income(pet, item.Mutation, data.Rebirths)) .. "/сек", V.color(Config.Rarities[pet.Tier].Color), 190, 55)
			else
				local egg = V.egg(s.Plot.Display, pad.CFrame * CFrame.new(0, 2, 0), item.Tier, item.Mutation == "Golden")
				egg:SetAttribute("ReadyAt", item.ReadyAt)
				V.label(egg, Config.Rarities[item.Tier].Name .. "\nВылупление: " .. math.max(0, item.ReadyAt - os.time()) .. "с", V.color(Config.Rarities[item.Tier].Color), 200, 60)
				V.prompt(egg, "Украсть яйцо", "Чужое гнездо", 2.5, function(thief)
					if thief == player or item.Hatched or item.ReservedBy or not sessions[thief] then return end
					if not table.find(data.Inventory, item) then return end
					if os.clock() < s.ShieldUntil then notify(thief, "База защищена щитом.", "Warn"); return end
					if beginCarry(thief, item, player) then
						notify(player, thief.DisplayName .. " крадёт яйцо! Догоните и нажмите Q.", "Warn")
						refreshPlot(player); sendState(player)
					end
				end)
			end
		end
	end
end

local function newItem(tier)
	local options = {}
	for _, pet in ipairs(Config.Pets) do if pet.Tier == tier then table.insert(options, pet) end end
	local pet = options[random:NextInteger(1, #options)]
	return {Id = HttpService:GenerateGUID(false), PetId = pet.Id, Tier = tier,
		Mutation = if random:NextNumber() < 0.06 then "Golden" else "Normal", ReadyAt = 0, Hatched = false}
end

local function spawnDrop(item, position, owner)
	local part = V.egg(world.Drops, CFrame.new(position), item.Tier, item.Mutation == "Golden")
	local id = item.Id
	local drop = {Part = part, Item = item, Owner = owner, ClaimAt = os.clock() + 5, Expires = os.clock() + Config.EggLifetime}
	drops[id] = drop
	V.label(part, (if item.Mutation == "Golden" then "★ ЗОЛОТОЕ\n" else "") .. Config.Rarities[item.Tier].Name .. " ЯЙЦО", V.color(Config.Rarities[item.Tier].Color), 220, 65)
	V.prompt(part, "Поднять", "Отнеси на базу", 0.15, function(player)
		if drops[id] ~= drop then return end
		if player ~= owner and os.clock() < drop.ClaimAt then notify(player, "Это яйцо пока закреплено за другим игроком."); return end
		if beginCarry(player, item) then destroyDrop(id) end
	end)
end

local function fillStation(station)
	local model, part = V.block(world.Blocks, CFrame.new(station.Position), station.Tier, world.Templates, station.Variant)
	station.Model = model; station.Busy = false
	local rarity = Config.Rarities[station.Tier]
	V.label(part, rarity.Name .. "\nСила " .. rarity.Required, V.color(rarity.Color), 190, 55)
	V.prompt(part, "Пнуть!", "Лаки-блок", 0.2, function(player)
		local s, data = sessions[player], Data.Profiles[player]
		if not s or station.Busy or s.Carry then return end
		if data.Strength < rarity.Required then notify(player, "Нужна сила " .. rarity.Required .. ". Тренируйся в центре!", "Warn"); return end
		if #data.Inventory >= data.Slots then notify(player, "Освободите место на базе.", "Warn"); return end
		local ownedDrops = 0
		for _, drop in pairs(drops) do if drop.Owner == player then ownedDrops += 1 end end
		if ownedDrops >= 3 then notify(player, "Сначала подбери уже выбитые яйца.", "Warn"); return end
		if not cooldown(player, "Kick", Config.KickCooldown) then return end
		station.Busy = true
		for _, obj in ipairs(model:GetDescendants()) do if obj:IsA("ProximityPrompt") or obj:IsA("BillboardGui") then obj:Destroy() end end
		local item = newItem(Rules.rollTier(station.Tier, random:NextNumber()))
		local startCF = model:GetPivot()
		local distance = math.min(30, 12 + data.Strength * 0.06)
		local offset = Vector3.new(0, 0, distance)
		fx:FireAllClients("Kick", station.Position, station.Tier, player)
		task.spawn(function()
			local start = os.clock()
			while model.Parent and os.clock() - start < 0.85 do
				local t = math.clamp((os.clock() - start) / 0.85, 0, 1)
				model:PivotTo(startCF + offset * t + Vector3.new(0, math.sin(t * math.pi) * 10, 0))
				RunService.Heartbeat:Wait()
			end
			model:Destroy()
			local landing = Vector3.new(station.Position.X, 2, station.Position.Z + distance)
			spawnDrop(item, landing, player)
			fx:FireAllClients("Burst", landing, item.Tier)
			notify(player, "Выпало " .. Config.Rarities[item.Tier].Name:lower() .. " яйцо!", "Success")
			task.wait(6)
			if not closing then fillStation(station) end
		end)
	end)
end

local function collect(player)
	local s, data = sessions[player], Data.Profiles[player]
	if not s or not cooldown(player, "Collect", 0.7) then return end
	local root = rootOf(player)
	if not root or (root.CFrame.Position - s.Plot.Collect.CFrame.Position).Magnitude > 13 then return end
	local amount = math.floor(data.Bank)
	if amount <= 0 then return end
	data.Cash = math.min(Config.MaxCash, data.Cash + amount); data.Bank = 0
	data.Tutorial = math.max(data.Tutorial, 4)
	notify(player, "+$" .. Rules.format(amount), "Success"); sendState(player)
end

local function shield(player)
	local s = sessions[player]
	if not s or not cooldown(player, "Shield", 1) then return end
	local root = rootOf(player)
	if not root or (root.CFrame.Position - s.Plot.Shield.CFrame.Position).Magnitude > 13 then return end
	if os.clock() < s.ShieldReady then notify(player, "Щит перезаряжается: " .. math.ceil(s.ShieldReady - os.clock()) .. "с"); return end
	s.ShieldUntil = os.clock() + Config.ShieldDuration; s.ShieldReady = os.clock() + Config.ShieldCooldown
	notify(player, "Гнёзда защищены на 45 секунд.", "Success"); sendState(player)
end

local function onPlayer(player)
	local data, offline = Data.Load(player)
	if not data then return end
	if not player.Parent or closing then Data.Save(player, true); return end
	local plot
	for _, candidate in ipairs(world.Plots) do if not candidate.Owner then plot = candidate; break end end
	if not plot then Data.Save(player, true); player:Kick("Все 6 баз заняты. Выберите другой сервер."); return end
	plot.Owner = player; plot.Model:SetAttribute("OwnerId", player.UserId); plot.Title.Text = player.DisplayName .. " · БАЗА"
	sessions[player] = {Plot = plot, Cooldowns = {}, ShieldUntil = os.clock() + 45, ShieldReady = 0, LastTrain = 0, RateAt = 0, RateCount = 0}
	local ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = player
	for _, name in ipairs({"Cash", "Power", "Rebirths"}) do local v = Instance.new("NumberValue"); v.Name = name; v.Parent = ls end
	player.RespawnLocation = plot.Spawn
	local function characterAdded(char)
		local root = char:WaitForChild("HumanoidRootPart", 10)
		local hum = char:WaitForChild("Humanoid", 10)
		if not root or not hum or not sessions[player] then return end
		char:PivotTo(plot.Spawn.CFrame + Vector3.new(0, 4, 0))
		updateSpeed(player)
		hum.Died:Connect(function() cancelCarry(player, "Яйцо потеряно. Попробуй ещё раз!") end)
		sendState(player)
	end
	player.CharacterAdded:Connect(characterAdded)
	if player.Character then task.spawn(characterAdded, player.Character) end
	refreshPlot(player); sendState(player)
	if offline > 0 then task.delay(3, function() notify(player, "Питомцы заработали без тебя: $" .. Rules.format(offline) .. ". Забери на базе!", "Success") end) end
end

for _, plot in ipairs(world.Plots) do
	V.prompt(plot.Deposit, "Положить яйцо", "Твоя база", 0, function(p) if plot.Owner == p then deposit(p) end end)
	V.prompt(plot.Collect, "Собрать доход", "Копилка", 0, function(p) if plot.Owner == p then collect(p) end end)
	V.prompt(plot.Shield, "Включить щит", "Защита яиц", 0.2, function(p) if plot.Owner == p then shield(p) end end)
end

V.prompt(world.Gym, "Тренироваться", "Встань на синюю площадку", 0, function(player)
	notify(player, "Стой на синей площадке: сила растёт каждую секунду.")
end)
V.prompt(world.Shop, "Открыть", "Улучшения", 0, function(player) stateRemote:FireClient(player, "OpenShop", {}) end)
for _, station in ipairs(world.Stations) do fillStation(station) end

remote.OnServerEvent:Connect(function(player, action, value)
	local s, data = sessions[player], Data.Profiles[player]
	if not s or not data or type(action) ~= "string" or not rootOf(player) then return end
	local now = os.clock()
	if now - s.RateAt >= 1 then s.RateAt = now; s.RateCount = 0 end
	s.RateCount += 1; if s.RateCount > 12 then return end
	if action == "Sync" then if cooldown(player, "Sync", 0.5) then sendState(player) end
	elseif action == "Home" or action == "Gym" then
		if s.Carry then notify(player, "С яйцом нужно дойти пешком!", "Warn"); return end
		if not cooldown(player, "Travel", 2) then return end
		local target = if action == "Home" then s.Plot.Spawn.CFrame else world.Gym.CFrame
		player.Character:PivotTo(target + Vector3.new(0, 4, 0))
	elseif action == "Drop" then cancelCarry(player, "Яйцо отпущено.")
	elseif action == "Upgrade" then
		if type(value) ~= "string" or not cooldown(player, "Upgrade", 0.25) then return end
		local level = if value == "Slots" then data.Slots - Config.BaseSlots else data[value]
		if value ~= "Slots" and value ~= "Weight" and value ~= "Speed" then return end
		local max = if value == "Slots" then Config.MaxSlots - Config.BaseSlots else 12
		if level >= max then notify(player, "Максимальный уровень."); return end
		local cost = Rules.upgradeCost(value, level)
		if data.Cash < cost then notify(player, "Нужно $" .. Rules.format(cost), "Warn"); return end
		data.Cash -= cost; data[value] += 1
		updateSpeed(player); refreshPlot(player); sendState(player); notify(player, "Улучшение куплено!", "Success")
	elseif action == "Sell" then
		if type(value) ~= "string" or not cooldown(player, "Sell", 0.3) then return end
		for i, item in ipairs(data.Inventory) do
			if item.Id == value and item.Hatched then
				local amount = Rules.income(Rules.findPet(Config, item.PetId), item.Mutation, data.Rebirths) * 30
				table.remove(data.Inventory, i); data.Cash = math.min(Config.MaxCash, data.Cash + amount)
				refreshPlot(player); sendState(player); notify(player, "Питомец продан: +$" .. Rules.format(amount), "Success"); break
			end
		end
	elseif action == "Rebirth" then
		if not cooldown(player, "Rebirth", 2) or data.Rebirths >= 15 then return end
		if s.Carry then notify(player, "Сначала положите яйцо.", "Warn"); return end
		local cost = Rules.rebirthCost(data.Rebirths)
		if data.Cash < cost then notify(player, "Для перерождения нужно $" .. Rules.format(cost), "Warn"); return end
		data.Cash = Config.StartingCash; data.Bank = 0; data.Strength = 0; data.Weight = 0; data.Speed = 0; data.Rebirths += 1
		refreshPlot(player); updateSpeed(player); sendState(player)
		notify(player, "Перерождение! Доход и тренировка усилены. Питомцы сохранены.", "Success")
	elseif action == "Shove" then
		if not cooldown(player, "Shove", 3) then return end
		local root = rootOf(player)
		for target, ts in pairs(sessions) do
			if target ~= player and ts.Carry and ts.Carry.Origin == player then
				local other = rootOf(target)
				if other and (other.CFrame.Position - root.CFrame.Position).Magnitude < 11 then
					cancelCarry(target, "Владелец отбил своё яйцо!")
					notify(player, "Яйцо вернулось в гнездо.", "Success")
					fx:FireAllClients("Burst", other.CFrame.Position, 2); break
				end
			end
		end
	end
end)

local function leave(player)
	local s = sessions[player]
	if s then
		cancelCarry(player)
		for other, otherSession in pairs(sessions) do
			if otherSession.Carry and otherSession.Carry.Origin == player then cancelCarry(other, "Владелец вышел; яйцо вернулось на его базу.") end
		end
		s.Plot.Owner = nil; s.Plot.Model:SetAttribute("OwnerId", nil)
		s.Plot.Title.Text = "СВОБОДНАЯ БАЗА"; s.Plot.Barrier.Transparency = 1
		s.Plot.BankLabel.Text = "$0\nСОБРАТЬ"; s.Plot.Display:ClearAllChildren()
		sessions[player] = nil
	end
	Data.Save(player, true)
end

Players.PlayerAdded:Connect(function(p) task.spawn(onPlayer, p) end)
Players.PlayerRemoving:Connect(leave)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end

task.spawn(function()
	while not closing do
		task.wait(Config.AutosaveInterval)
		for p in pairs(Data.Profiles) do task.spawn(Data.Save, p, false) end
	end
end)

local incomeClock, updateClock, elapsedClock = 0, 0, 0
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	if not waveStart and serverNow >= nextWave then
		waveStart = serverNow
		wavePart = V.part(world.Effects, "Tsunami", Vector3.new(144, 11, 12), CFrame.new(0, 4, 355), Color3.fromRGB(55, 176, 238), Enum.Material.Glass)
		wavePart.Transparency = 0.25; wavePart.CanCollide = false
		local foam = V.part(wavePart, "Foam", Vector3.new(144, 1.5, 13), wavePart.CFrame * CFrame.new(0, 5, 0), Color3.fromRGB(225, 251, 255), Enum.Material.Neon)
		foam.CanCollide = false
		fx:FireAllClients("Wave")
	end
	if waveStart then
		local progress = (serverNow - waveStart) / Config.WaveDuration
		local z = 355 - progress * 326
		wavePart.CFrame = CFrame.new(0, 4, z)
		wavePart.Foam.CFrame = wavePart.CFrame * CFrame.new(0, 5, 0)
		for player, s in pairs(sessions) do
			local root, hum = rootOf(player)
			if root and root.CFrame.Position.Z > 29 and math.abs(root.CFrame.Position.X) < 73 and root.CFrame.Position.Y < 12 and math.abs(root.CFrame.Position.Z - z) < 9 then
				cancelCarry(player, "Волна смыла яйцо! В следующий раз ищи укрытие.")
				player.Character:PivotTo(s.Plot.Spawn.CFrame + Vector3.new(0, 4, 0))
				hum.Health = math.max(1, hum.Health - 25)
			end
		end
		if progress >= 1 then
			wavePart:Destroy(); wavePart = nil; waveStart = nil
			nextWave = serverNow + Config.WaveInterval
		end
	end
	workspace:SetAttribute("NextWave", nextWave)
	workspace:SetAttribute("WaveActive", waveStart ~= nil)
	incomeClock += dt; updateClock += dt; elapsedClock += dt
	if elapsedClock < 0.25 then return end
	elapsedClock = 0
	local paySeconds = math.floor(incomeClock)
	if paySeconds > 0 then incomeClock -= paySeconds end
	for id, drop in pairs(drops) do if drop.Expires <= now then destroyDrop(id) end end
	for player, s in pairs(sessions) do
		local data = Data.Profiles[player]
		local root = rootOf(player)
		local changed = false
		if data then
			if paySeconds > 0 then data.Bank = math.min(Config.MaxCash, data.Bank + incomeOf(data) * paySeconds) end
			for _, item in ipairs(data.Inventory) do
				if not item.Hatched and not item.ReservedBy and item.ReadyAt <= os.time() then
					item.Hatched = true; data.Hatched += 1; data.Discovered[item.PetId] = true; data.Tutorial = math.max(data.Tutorial, 3)
					changed = true
					notify(player, "Вылупился " .. Rules.findPet(Config, item.PetId).Name .. "!", "Success")
					fx:FireAllClients("Burst", s.Plot.Spawn.CFrame.Position + Vector3.new(0, 5, 0), item.Tier)
				end
			end
			s.Plot.BankLabel.Text = "$" .. Rules.format(data.Bank) .. "\nСОБРАТЬ"
			s.Plot.Barrier.Transparency = if now < s.ShieldUntil then 0.65 else 1
			for _, egg in ipairs(s.Plot.Display:GetChildren()) do
				if egg:IsA("BasePart") and egg:GetAttribute("ReadyAt") then
					local t = math.max(0, egg:GetAttribute("ReadyAt") - os.time())
					egg.Label.Text.Text = "ЯЙЦО\nВылупление: " .. t .. "с"
				end
			end
			if root then
				if root.CFrame.Position.Y < -18 then cancelCarry(player, "Ты упал в океан."); player.Character:PivotTo(s.Plot.Spawn.CFrame + Vector3.new(0, 4, 0)) end
				if s.Carry then
					if now - s.Carry.Started > Config.CarryTimeout then cancelCarry(player, "Время доставки истекло.")
					elseif (root.CFrame.Position - s.Plot.Deposit.CFrame.Position).Magnitude < 9 then deposit(player) end
				elseif (root.CFrame.Position - world.Gym.CFrame.Position).Magnitude < 8 and now - s.LastTrain >= 1.1 then
					s.LastTrain = now
					local gain = math.max(1, math.floor((2 + data.Weight * 2) * Rules.multiplier(data.Rebirths)))
					data.Strength = math.min(Config.MaxStrength, data.Strength + gain)
					stateRemote:FireClient(player, "Training", {Gain = gain})
				end
				if (root.CFrame.Position - s.Plot.Collect.CFrame.Position).Magnitude < 6 then collect(player) end
			end
			if changed then refreshPlot(player) end
			if updateClock >= 1 then sendState(player) end
		end
	end
	if updateClock >= 1 then updateClock = 0 end
end)

game:BindToClose(function()
	closing = true
	local pending = 0
	for player in pairs(Data.Profiles) do
		pending += 1
		task.spawn(function() leave(player); pending -= 1 end)
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < 25 do task.wait(0.1) end
end)

print("[LuckyTide] Ready: 6 plots, 15 lucky block stations, waves, hatching, upgrades and protected saves.")
