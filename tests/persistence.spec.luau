local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Config = require("../src/shared/Config")
local Rules = require("../src/shared/Rules")
local records, now, counter, failures, tests = {}, 10000, 0, false, 0
local function clone(t) if type(t) ~= "table" then return t end; local c = {}; for k, v in pairs(t) do c[k] = clone(v) end; return c end
local function check(value, name) assert(value, name); tests += 1; print("PASS " .. name) end
local store = {UpdateAsync = function(_, key, callback)
	if failures then error("Injected network outage") end
	local new = callback(clone(records[key]))
	if new then records[key] = clone(new); return clone(new) end
	return nil
end}
local function newSession(job)
	local services = {DataStoreService = {GetDataStore = function() return store end}, RunService = {IsStudio = function() return false end},
		HttpService = {GenerateGUID = function() counter += 1; return "guid" .. counter end},
		ReplicatedStorage = {WaitForChild = function() return {Config = Config, Rules = Rules} end}}
	return luau.load(fs.readFile("src/server/DataService.luau"), {environment = {
		game = {JobId = job, GetService = function(_, name) return services[name] end}, require = function(value) return value end,
		task = {wait = function(seconds) now += seconds or 0.1 end},
		os = {time = function() return now end, clock = function() return now end}, warn = function() end,
	}})()
end
local function player(id)
	return {UserId = id, SetAttribute = function() end, Kick = function(self, message) self.Kicked = message end}
end
local a, b = newSession("A"), newSession("B")
local p1, p2 = player(1), player(1)
local data = a.Load(p1)
check(data and data.Cash == 150, "first session creates profile under lock")
data.Cash = 410
check(a.Save(p1, false) and records.Player_1.Data.Cash == 410, "save persists owned profile")
check(b.Load(p2) == nil and p2.Kicked ~= nil, "second live session cannot acquire active lock")
check(records.Player_1.Data.Cash == 410, "rejected login never overwrites saved progress")
check(a.Save(p1, true) and records.Player_1.Session == nil, "leave releases session lock")
p2.Kicked = nil
local loaded = b.Load(p2)
check(loaded and loaded.Cash == 410 and not p2.Kicked, "new session reloads saved profile after release")
records.Player_1.Session = "NEW_OWNER"
loaded.Cash = 999
check(not b.Save(p2, false) and p2.Kicked ~= nil, "lost lock stops saving and rejects stale session")
check(records.Player_1.Data.Cash == 410, "stale session cannot overwrite new owner")
local c, p3 = newSession("C"), player(3)
records.Player_3 = {Data = {Cash = 777}, Session = "CRASHED_SERVER", LockExpires = now - 1}
check(c.Load(p3).Cash == 777, "expired crashed-server lock can be recovered")
failures = true
local d, p4 = newSession("D"), player(4)
check(d.Load(p4) == nil and p4.Kicked ~= nil and records.Player_4 == nil, "network outage does not save empty replacement profile")
failures = false
print("PASSED " .. tests .. " persistence tests (mock DataStore)")
