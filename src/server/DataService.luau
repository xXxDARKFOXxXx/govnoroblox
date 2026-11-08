local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("LuckyTide")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)

local Data = {Profiles = {}, Sessions = {}}
local studio = RunService:IsStudio()
local store = if not studio then DataStoreService:GetDataStore(Config.DataStore) else nil
local token = game.JobId .. HttpService:GenerateGUID(false)
local LOCK_TIME = 180

function Data.Load(player)
	local raw
	if store then
		local loaded = false
		for attempt = 1, 3 do
			local accepted = false
			local ok, result = pcall(function()
				return store:UpdateAsync("Player_" .. player.UserId, function(old)
					old = if type(old) == "table" then old else {}
					accepted = false
					if old.Session and old.Session ~= token and (old.LockExpires or 0) > os.time() then return nil end
					accepted = true
					return {Data = old.Data or {}, Session = token, LockExpires = os.time() + LOCK_TIME}
				end)
			end)
			if ok and accepted and result then
				raw = result.Data
				loaded = true
				break
			end
			if not ok then warn("[LuckyTide] Profile load failed: ", result) end
			task.wait(attempt * 2)
		end
		if not loaded then
			player:Kick("Не удалось безопасно загрузить прогресс. Подождите минуту и зайдите снова.")
			return nil
		end
	end
	local profile = Rules.cleanProfile(raw, Config, os.time())
	local elapsed = math.clamp(os.time() - profile.LastSeen, 0, Config.OfflineCap)
	local offline = 0
	for _, item in ipairs(profile.Inventory) do
		if item.Hatched then
			offline += Rules.income(Rules.findPet(Config, item.PetId), item.Mutation, profile.Rebirths) * elapsed * 0.25
		end
	end
	profile.Bank = math.min(Config.MaxCash, profile.Bank + math.floor(offline))
	profile.LastSeen = os.time()
	Data.Profiles[player] = profile
	Data.Sessions[player] = {Busy = false, LastSave = os.clock(), Failures = 0, Closing = false}
	player:SetAttribute("PracticeMode", studio)
	return profile, math.floor(offline)
end

function Data.Save(player, release)
	local session = Data.Sessions[player]
	if not session then return false end
	if release then session.Closing = true end
	while session.Busy do task.wait(0.1) end
	if Data.Sessions[player] ~= session then return false end
	if session.Closing and not release then return false end
	session.Busy = true
	local profile = Data.Profiles[player]
	local snapshot = Rules.cleanProfile(profile, Config, os.time())
	snapshot.LastSeen = os.time()
	local succeeded = not store
	if store then
		for attempt = 1, 3 do
			local ownsLock = false
			local ok, err = pcall(function()
				store:UpdateAsync("Player_" .. player.UserId, function(old)
					ownsLock = type(old) == "table" and old.Session == token
					if not ownsLock then return nil end
					return {Data = snapshot, Session = if release then nil else token,
						LockExpires = if release then 0 else os.time() + LOCK_TIME}
				end)
			end)
			if ok and ownsLock then succeeded = true; break end
			if ok and not ownsLock then
				player:Kick("Сессия прогресса изменилась. Перезайдите, чтобы защитить сохранение.")
				break
			end
			warn("[LuckyTide] Save retry: ", err)
			task.wait(attempt)
		end
	end
	if succeeded then session.LastSave = os.clock(); session.Failures = 0
	else session.Failures += 1 end
	session.Busy = false
	if release then
		Data.Profiles[player] = nil
		Data.Sessions[player] = nil
	elseif not succeeded and os.clock() - session.LastSave > 120 then
		player:Kick("Сохранение временно недоступно. Перезайдите через минуту.")
	end
	return succeeded
end

return Data
