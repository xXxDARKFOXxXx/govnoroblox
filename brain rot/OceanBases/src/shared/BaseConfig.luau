-- BaseConfig (ReplicatedStorage.OceanBases.BaseConfig): sizes, palette, layout,
-- eggs, fish and upgrade prices for the player bases. Shared by server and client.
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local BaseConfig = {}

---------------------------------------------------------------- placement
-- Five bases in a row along the back wall of the spawn court (floor top Y = 4).
-- Each footprint is 44 x 40 studs; the middle and front of the court stay free.
BaseConfig.FloorY = 4
BaseConfig.BaseCount = 5
BaseConfig.Footprint = Vector2.new(44, 40)
BaseConfig.Centers = {
	Vector3.new(-112, 4, -136),
	Vector3.new(-56, 4, -136),
	Vector3.new(0, 4, -136),
	Vector3.new(56, 4, -136),
	Vector3.new(112, 4, -136),
}
-- Bases face +Z (towards the court and the ocean corridor).
BaseConfig.Facing = 0

---------------------------------------------------------------- floors & upgrades
BaseConfig.FloorHeight = 11 -- distance between floor tops
BaseConfig.GroundTop = 1 -- the ground platform is raised by 1 stud
BaseConfig.PensPerFloor = 5
BaseConfig.MaxFloors = 4
BaseConfig.StartFloors = 2 -- 10 pens at the start
-- Upgrade to N floors costs Levels[N].Price coins.
BaseConfig.Levels = {
	[2] = {floors = 2, pens = 10, price = 0},
	[3] = {floors = 3, pens = 15, price = 5000},
	[4] = {floors = 4, pens = 20, price = 25000},
}

-- Pen centres on every floor (local X, Z; +Z is the front of the base).
BaseConfig.PenSize = Vector2.new(12, 10)
BaseConfig.PenSpots = {
	Vector2.new(-14, -13), Vector2.new(0, -13), Vector2.new(14, -13),
	Vector2.new(-14, 4), Vector2.new(14, 4),
}
BaseConfig.LiftSpot = Vector2.new(-16, 15)
BaseConfig.ChestSpot = Vector2.new(16.5, 14)
BaseConfig.UpgradeSpot = Vector2.new(10, 17)
BaseConfig.SpawnSpot = Vector3.new(0, 4, 14) -- where the owner appears (local)
BaseConfig.EntranceWidth = 10

---------------------------------------------------------------- palette
BaseConfig.Colors = {
	Wood = rgb(176, 108, 58), WoodDark = rgb(122, 72, 38), WoodLight = rgb(210, 146, 86),
	Stone = rgb(196, 188, 214), StoneDark = rgb(150, 142, 172), StoneLight = rgb(222, 216, 236),
	Path = rgb(208, 202, 224), Sand = rgb(246, 222, 160),
	Water = rgb(64, 214, 236), WaterDeep = rgb(28, 160, 214), Foam = rgb(210, 250, 255),
	GlowBlue = rgb(110, 232, 255), GlowGold = rgb(255, 206, 92),
	Rope = rgb(220, 184, 120), Net = rgb(232, 206, 150),
	Kelp = rgb(60, 196, 90), KelpDark = rgb(30, 140, 70),
	CoralPink = rgb(255, 120, 178), CoralPurple = rgb(176, 110, 255),
	Shell = rgb(255, 232, 226), Starfish = rgb(255, 150, 90),
	Red = rgb(232, 60, 60), White = rgb(255, 255, 255), Flag = rgb(40, 110, 220),
	Gold = rgb(255, 200, 40), Metal = rgb(140, 150, 170),
}

---------------------------------------------------------------- eggs & fish
-- Egg ids match inventory item ids (OceanInventory, Category "Eggs").
BaseConfig.Eggs = {
	BasicEgg = {name = "Обычное яйцо", hatch = 15, shell = rgb(250, 248, 238), spots = rgb(90, 190, 255),
		fish = {ClownFish = 70, BlueTang = 30}},
	StarEgg = {name = "Звёздное яйцо", hatch = 30, shell = rgb(214, 120, 255), spots = rgb(255, 214, 70), glow = true,
		fish = {BlueTang = 40, PufferFish = 45, Angler = 15}},
	OceanEgg = {name = "Морское яйцо", hatch = 45, shell = rgb(100, 210, 255), spots = rgb(20, 90, 200), glow = true,
		fish = {PufferFish = 40, Angler = 50, KingFish = 10}},
	GoldEgg = {name = "Золотое яйцо", hatch = 60, shell = rgb(255, 214, 70), spots = rgb(255, 250, 200), glow = true,
		fish = {Angler = 40, KingFish = 60}},
}

-- income = coins per second while the fish lives in a pen.
BaseConfig.Fish = {
	ClownFish = {name = "Рыба-клоун", income = 3, rarity = "Обычная",
		body = rgb(255, 128, 32), belly = rgb(255, 196, 120), stripe = rgb(255, 255, 255), fin = rgb(255, 150, 60)},
	BlueTang = {name = "Синий хирург", income = 6, rarity = "Обычная",
		body = rgb(40, 96, 230), belly = rgb(90, 150, 255), stripe = rgb(20, 30, 90), fin = rgb(255, 214, 40)},
	PufferFish = {name = "Рыба-фугу", income = 12, rarity = "Редкая", round = true,
		body = rgb(255, 214, 60), belly = rgb(255, 246, 190), stripe = rgb(230, 150, 30), fin = rgb(255, 170, 40)},
	Angler = {name = "Удильщик", income = 30, rarity = "Эпическая", lure = true, sparkle = true,
		body = rgb(150, 80, 230), belly = rgb(220, 170, 255), stripe = rgb(100, 40, 180), fin = rgb(255, 120, 200)},
	KingFish = {name = "Королевская рыбка", income = 75, rarity = "Легендарная", crown = true, sparkle = true,
		body = rgb(255, 200, 40), belly = rgb(255, 240, 160), stripe = rgb(240, 150, 20), fin = rgb(255, 240, 120)},
}

BaseConfig.RarityColors = {
	["Обычная"] = rgb(220, 230, 240), ["Редкая"] = rgb(90, 200, 255),
	["Эпическая"] = rgb(200, 130, 255), ["Легендарная"] = rgb(255, 210, 60),
}

---------------------------------------------------------------- effects & timing
BaseConfig.IncomeTick = 1 -- seconds between income payouts into the chest
BaseConfig.FishSwimSpeed = 0.55 -- radians per second around the pen
BaseConfig.AnimationDistance = 220 -- fish further than this are not animated

function BaseConfig.floorTop(floor: number): number
	return BaseConfig.GroundTop + (floor - 1) * BaseConfig.FloorHeight
end

function BaseConfig.levelForFloors(floors: number)
	return BaseConfig.Levels[floors]
end

return BaseConfig
