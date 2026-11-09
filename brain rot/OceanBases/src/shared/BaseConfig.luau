-- BaseConfig (ReplicatedStorage.OceanBases.BaseConfig): sizes, palette, layout,
-- eggs, fish and upgrade prices for the player bases. Shared by server and client.
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local BaseConfig = {}

---------------------------------------------------------------- placement
-- Five open yards in a row along the back wall of the spawn court (floor top
-- Y = 4). Each yard grows a little towards the front with every upgrade; the
-- middle and the front of the court stay free for future buildings.
BaseConfig.BaseCount = 5
-- Base origin = centre of the yard's back edge, on the court floor.
BaseConfig.Origins = {
	Vector3.new(-114, 4, -156),
	Vector3.new(-57, 4, -156),
	Vector3.new(0, 4, -156),
	Vector3.new(57, 4, -156),
	Vector3.new(114, 4, -156),
}
BaseConfig.Facing = 0 -- yards open towards +Z (the court and the ocean corridor)

---------------------------------------------------------------- yard & cells
BaseConfig.CellSize = 8 -- one cell = one 8x8 floor tile (same grid as the court)
BaseConfig.Columns = 6
BaseConfig.FloorTop = 1 -- the yard floor is one stud above the court
BaseConfig.Margin = 2 -- between the fence and the cells
BaseConfig.FrontWalk = 7 -- walkway between the last row and the front fence
-- Pool at the back of the yard (fish fly in the air above its water).
BaseConfig.PoolZone = 16 -- depth of the strip that holds the pool
BaseConfig.PoolSize = Vector2.new(32, 12) -- inner water area
BaseConfig.PoolDepth = 1.8 -- about a third of a character's height
BaseConfig.PoolRim = 1.2
BaseConfig.StartRows = 2
BaseConfig.MaxRows = 4
-- Upgrade to N rows: cells and price.
BaseConfig.Levels = {
	[2] = {cells = 12, price = 0},
	[3] = {cells = 18, price = 5000},
	[4] = {cells = 24, price = 25000},
}
BaseConfig.EntranceWidth = 10

function BaseConfig.width(): number
	return BaseConfig.Columns * BaseConfig.CellSize + BaseConfig.Margin * 2
end

-- Depth of the yard (back fence to front fence) for a number of rows.
function BaseConfig.depth(rows: number): number
	return BaseConfig.Margin + BaseConfig.PoolZone + rows * BaseConfig.CellSize + BaseConfig.FrontWalk
end

-- Local centre (X, Z) of the pool and the height of its water surface.
function BaseConfig.poolCenter(): Vector2
	return Vector2.new(0, BaseConfig.Margin + BaseConfig.PoolZone / 2)
end
function BaseConfig.waterTop(): number
	return BaseConfig.FloorTop + BaseConfig.PoolDepth
end

-- Local centre (X, Z) of a cell; rows count from the back.
function BaseConfig.cellCenter(row: number, column: number): Vector2
	local s = BaseConfig.CellSize
	local x = (column - (BaseConfig.Columns + 1) / 2) * s
	local z = BaseConfig.Margin + BaseConfig.PoolZone + (row - 0.5) * s
	return Vector2.new(x, z)
end

---------------------------------------------------------------- palette
-- Studded Plastic everywhere, like the court floor and walls.
BaseConfig.Colors = {
	TileA = rgb(130, 225, 224), TileB = rgb(91, 196, 212), -- yard checker (wall palette)
	Border = rgb(47, 100, 106), BorderLight = rgb(74, 180, 200),
	Wood = rgb(196, 140, 78), WoodDark = rgb(150, 100, 52), WoodLight = rgb(224, 172, 104),
	Stone = rgb(155, 134, 100), StoneDark = rgb(121, 101, 72),
	GlowBlue = rgb(110, 232, 255), GlowGold = rgb(255, 206, 92),
	Kelp = rgb(60, 196, 130), KelpDark = rgb(30, 150, 110),
	Water = rgb(36, 176, 232), PoolRim = rgb(74, 150, 170), PoolRimTop = rgb(200, 240, 245), PoolBottom = rgb(246, 222, 160),
	CoralPink = rgb(255, 120, 178), CoralPurple = rgb(176, 110, 255),
	Shell = rgb(255, 232, 226), Starfish = rgb(255, 150, 120),
	Red = rgb(232, 60, 60), White = rgb(255, 255, 255), Gold = rgb(255, 200, 40),
	Foam = rgb(210, 250, 255), Metal = rgb(140, 150, 170),
}

---------------------------------------------------------------- rarity
BaseConfig.Rarities = {
	{name = "Обычная", color = rgb(220, 230, 240), income = 3},
	{name = "Необычная", color = rgb(120, 230, 120), income = 10},
	{name = "Редкая", color = rgb(90, 200, 255), income = 30},
	{name = "Эпическая", color = rgb(200, 130, 255), income = 90},
	{name = "Легендарная", color = rgb(255, 210, 60), income = 270},
}
BaseConfig.RarityColors = {}
for _, rarity in BaseConfig.Rarities do BaseConfig.RarityColors[rarity.name] = rarity.color end

---------------------------------------------------------------- fish
-- 40 fish from the Studfish and Studfish SeaLife packs, in 5 tiers. The id is
-- the GLB file name (and the model name after import into OceanModels.Fish).
-- body/belly/stripe/fin colour the built-in fallback model.
local FISH_TIERS = {
	{ -- 1 · Обычная
		{"Sardine", "Сардина", rgb(170, 190, 210), rgb(230, 240, 250), rgb(90, 110, 150), rgb(150, 170, 200)},
		{"PygmyGoby", "Карликовый бычок", rgb(150, 210, 90), rgb(220, 250, 170), rgb(90, 150, 50), rgb(190, 240, 110)},
		{"Shrimp", "Креветка", rgb(255, 150, 120), rgb(255, 210, 190), rgb(230, 100, 80), rgb(255, 180, 150)},
		{"Tetra", "Неонка", rgb(60, 140, 255), rgb(255, 90, 90), rgb(110, 240, 255), rgb(120, 180, 255)},
		{"Goldfish", "Золотая рыбка", rgb(255, 150, 40), rgb(255, 220, 140), rgb(255, 255, 255), rgb(255, 190, 80)},
		{"Clown", "Рыба-клоун", rgb(255, 128, 32), rgb(255, 196, 120), rgb(255, 255, 255), rgb(255, 150, 60)},
		{"Flounder", "Камбала", rgb(200, 170, 120), rgb(240, 220, 180), rgb(150, 120, 80), rgb(220, 190, 140)},
		{"SeaUrchin", "Морской ёж", rgb(170, 120, 230), rgb(220, 190, 255), rgb(110, 70, 180), rgb(200, 150, 255), round = true},
	},
	{ -- 2 · Необычная
		{"Butterflyfish", "Рыба-бабочка", rgb(255, 220, 60), rgb(255, 250, 200), rgb(40, 40, 60), rgb(255, 180, 40)},
		{"Mandarin", "Рыба-мандаринка", rgb(60, 160, 255), rgb(255, 150, 60), rgb(255, 90, 60), rgb(80, 220, 200)},
		{"Betta", "Петушок", rgb(220, 40, 90), rgb(255, 140, 170), rgb(120, 20, 60), rgb(255, 80, 140)},
		{"Discus", "Дискус", rgb(255, 120, 60), rgb(80, 200, 230), rgb(60, 120, 220), rgb(255, 160, 90), round = true},
		{"HermitCrab", "Рак-отшельник", rgb(255, 160, 120), rgb(255, 220, 190), rgb(200, 90, 60), rgb(255, 190, 150)},
		{"Starfish", "Морская звезда", rgb(255, 170, 60), rgb(255, 220, 140), rgb(255, 110, 80), rgb(255, 200, 100)},
		{"Seahorse", "Морской конёк", rgb(255, 200, 80), rgb(255, 240, 170), rgb(230, 140, 40), rgb(255, 220, 120)},
		{"Salmon", "Лосось", rgb(190, 200, 215), rgb(255, 180, 170), rgb(120, 130, 150), rgb(220, 160, 170)},
	},
	{ -- 3 · Редкая
		{"RegalTang", "Королевский хирург", rgb(40, 96, 230), rgb(90, 150, 255), rgb(20, 30, 90), rgb(255, 214, 40)},
		{"MoorishIdol", "Мавританский идол", rgb(255, 240, 200), rgb(255, 250, 230), rgb(30, 30, 40), rgb(255, 210, 60)},
		{"Parrotfish", "Рыба-попугай", rgb(80, 220, 160), rgb(255, 150, 200), rgb(40, 150, 120), rgb(255, 120, 180)},
		{"RibbonTrout", "Радужная форель", rgb(160, 200, 160), rgb(255, 160, 200), rgb(200, 90, 160), rgb(190, 220, 190)},
		{"Koi", "Карп кои", rgb(255, 255, 255), rgb(255, 245, 235), rgb(240, 80, 40), rgb(255, 150, 120)},
		{"Puffer", "Рыба-фугу", rgb(255, 214, 60), rgb(255, 246, 190), rgb(230, 150, 30), rgb(255, 170, 40), round = true},
		{"Lionfish", "Крылатка", rgb(255, 120, 90), rgb(255, 230, 210), rgb(140, 40, 40), rgb(255, 160, 140)},
		{"Cuttlefish", "Каракатица", rgb(120, 200, 150), rgb(200, 240, 210), rgb(140, 80, 200), rgb(150, 220, 180)},
	},
	{ -- 4 · Эпическая
		{"Catfish", "Сом", rgb(120, 100, 160), rgb(200, 190, 220), rgb(70, 60, 100), rgb(150, 130, 190)},
		{"Lobster", "Омар", rgb(220, 50, 50), rgb(255, 140, 120), rgb(150, 20, 30), rgb(255, 90, 80)},
		{"Nautilus", "Наутилус", rgb(255, 240, 220), rgb(255, 250, 240), rgb(210, 120, 80), rgb(255, 210, 180), round = true},
		{"SeaTurtle", "Морская черепаха", rgb(90, 190, 140), rgb(200, 240, 200), rgb(60, 130, 90), rgb(140, 220, 170)},
		{"Sunfish", "Рыба-луна", rgb(170, 180, 210), rgb(230, 235, 250), rgb(110, 120, 160), rgb(200, 205, 230), round = true},
		{"Eel", "Угорь", rgb(80, 160, 90), rgb(190, 230, 150), rgb(40, 100, 50), rgb(120, 200, 110)},
		{"Jelly", "Медуза", rgb(255, 150, 230), rgb(255, 210, 245), rgb(200, 90, 200), rgb(255, 180, 240), round = true, sparkle = true},
		{"Angler", "Удильщик", rgb(150, 80, 230), rgb(220, 170, 255), rgb(100, 40, 180), rgb(255, 120, 200), lure = true, sparkle = true},
		{"Octopus", "Осьминог", rgb(240, 90, 120), rgb(255, 170, 190), rgb(180, 50, 80), rgb(255, 130, 160), round = true},
	},
	{ -- 5 · Легендарная
		{"Manta", "Манта", rgb(40, 60, 110), rgb(230, 240, 255), rgb(20, 30, 60), rgb(70, 100, 170), sparkle = true},
		{"Swordfish", "Рыба-меч", rgb(60, 110, 200), rgb(200, 220, 250), rgb(30, 60, 140), rgb(100, 150, 230), sparkle = true},
		{"Hammerhead", "Рыба-молот", rgb(130, 140, 160), rgb(230, 235, 240), rgb(90, 100, 120), rgb(160, 170, 190), sparkle = true},
		{"Shark", "Акула", rgb(110, 140, 170), rgb(235, 240, 245), rgb(70, 90, 120), rgb(140, 170, 200), sparkle = true},
		{"Orca", "Косатка", rgb(30, 30, 40), rgb(255, 255, 255), rgb(255, 255, 255), rgb(40, 40, 50), sparkle = true},
		{"Whale", "Кит", rgb(70, 110, 180), rgb(200, 220, 240), rgb(40, 70, 130), rgb(100, 140, 200), round = true, sparkle = true},
		{"Kraken", "Кракен", rgb(170, 40, 70), rgb(255, 150, 170), rgb(110, 20, 50), rgb(220, 80, 120), round = true, crown = true, sparkle = true},
	},
}

-- income = coins per second at level 1 (straight into the owner's pocket).
BaseConfig.Fish = {}
BaseConfig.FishTiers = {}
for tier, list in FISH_TIERS do
	BaseConfig.FishTiers[tier] = {}
	local rarity = BaseConfig.Rarities[tier]
	for i, f in list do
		BaseConfig.Fish[f[1]] = {
			name = f[2], tier = tier, rarity = rarity.name,
			income = math.floor(rarity.income * (1 + (i - 1) * 0.1) + 0.5),
			body = f[3], belly = f[4], stripe = f[5], fin = f[6],
			round = f.round, lure = f.lure, crown = f.crown, sparkle = f.sparkle or tier >= 4,
		}
		table.insert(BaseConfig.FishTiers[tier], f[1])
	end
end

-- Fish levels: income grows by 50% of the base per level; upgrades cost more each time.
BaseConfig.MaxFishLevel = 25
function BaseConfig.fishIncome(fishType: string, level: number): number
	local base = BaseConfig.Fish[fishType].income
	return math.floor(base * (1 + 0.5 * (level - 1)) + 0.5)
end
function BaseConfig.upgradeCost(fishType: string, level: number): number
	local base = BaseConfig.Fish[fishType].income
	return math.floor(base * 30 * 1.6 ^ (level - 1) + 0.5)
end

---------------------------------------------------------------- eggs
-- 10 eggs from the StudEggs pack, two per ocean section. The id matches the
-- inventory item id; model = imported model name in OceanModels.Eggs.
-- Each egg rolls a tier (weights) and then a random fish of that tier.
local EGGS = {
	{"TideEgg", "01_Tide", "Яйцо прилива", 1, 20, rgb(120, 220, 255), rgb(255, 255, 255), {[1] = 85, [2] = 15}},
	{"LagoonEgg", "02_Lagoon", "Лагунное яйцо", 1, 30, rgb(90, 230, 190), rgb(255, 240, 150), {[1] = 60, [2] = 40}},
	{"CoralEgg", "03_Coral", "Коралловое яйцо", 2, 45, rgb(255, 130, 170), rgb(255, 230, 120), {[2] = 80, [3] = 20}},
	{"PearlEgg", "04_Pearl", "Жемчужное яйцо", 2, 60, rgb(250, 240, 255), rgb(200, 170, 255), {[2] = 55, [3] = 45}},
	{"GlacierEgg", "05_Glacier", "Ледниковое яйцо", 3, 80, rgb(190, 240, 255), rgb(90, 170, 255), {[3] = 80, [4] = 20}},
	{"JellyEgg", "06_Jelly", "Медузье яйцо", 3, 100, rgb(255, 170, 240), rgb(170, 120, 255), {[3] = 55, [4] = 45}},
	{"StormEgg", "07_Storm", "Грозовое яйцо", 4, 130, rgb(110, 120, 200), rgb(255, 240, 100), {[4] = 80, [5] = 20}},
	{"KrakenEgg", "08_Kraken", "Яйцо кракена", 4, 160, rgb(180, 50, 90), rgb(255, 150, 200), {[4] = 55, [5] = 45}},
	{"VentEgg", "09_Vent", "Вулканическое яйцо", 5, 200, rgb(255, 110, 40), rgb(255, 220, 80), {[4] = 30, [5] = 70}},
	{"OceanCrownEgg", "10_OceanCrown", "Яйцо Короны океана", 5, 240, rgb(255, 214, 70), rgb(120, 230, 255), {[5] = 100}},
}
BaseConfig.Eggs = {}
BaseConfig.EggOrder = {}
for _, e in EGGS do
	BaseConfig.Eggs[e[1]] = {
		name = e[3], model = e[2], section = e[4], hatch = e[5],
		shell = e[6], spots = e[7], tiers = e[8], glow = e[4] >= 2,
	}
	table.insert(BaseConfig.EggOrder, e[1])
end

---------------------------------------------------------------- ocean sections
-- The corridor has 5 sections (wall colours change between them). Each has
-- nests with its two eggs and guards: one big predator from StudPredators and
-- scary fish from the Studfish expansion. Guards only attack an egg carrier.
BaseConfig.Sections = {
	{name = "Лагуна", fromZ = 0, toZ = 192, eggs = {"TideEgg", "LagoonEgg"}, nests = 4,
		predator = "01_Barracuda", guards = {"Piranha"}, chase = 14, patrol = 6, sand = {rgb(238, 214, 150), rgb(226, 198, 132)}, rock = rgb(120, 170, 180)},
	{name = "Риф", fromZ = 192, toZ = 384, eggs = {"CoralEgg", "PearlEgg"}, nests = 4,
		predator = "02_TigerShark", guards = {"Moray", "Stonefish"}, chase = 18, patrol = 7, sand = {rgb(230, 200, 150), rgb(214, 182, 132)}, rock = rgb(110, 150, 175)},
	{name = "Синева", fromZ = 384, toZ = 576, eggs = {"GlacierEgg", "JellyEgg"}, nests = 4,
		predator = "03_Viperfish", guards = {"Wolffish", "Sawfish"}, chase = 22, patrol = 8, sand = {rgb(200, 190, 170), rgb(180, 170, 155)}, rock = rgb(90, 120, 170)},
	{name = "Сумерки", fromZ = 576, toZ = 768, eggs = {"StormEgg", "KrakenEgg"}, nests = 4,
		predator = "04_Reefbreaker", guards = {"GoblinShark", "Fangtooth"}, chase = 26, patrol = 9, sand = {rgb(150, 150, 170), rgb(130, 130, 155)}, rock = rgb(80, 80, 130)},
	{name = "Бездна", fromZ = 768, toZ = 960, eggs = {"VentEgg", "OceanCrownEgg"}, nests = 4,
		predator = "05_Leviathan", guards = {"GulperEel", "Dragonfish", "FrilledShark"}, chase = 30, patrol = 10, sand = {rgb(110, 100, 130), rgb(90, 82, 115)}, rock = rgb(60, 50, 90)},
}
BaseConfig.Predators = {
	["01_Barracuda"] = {name = "Рифовая барракуда", length = 17, color = rgb(190, 200, 120)},
	["02_TigerShark"] = {name = "Тигровая акула", length = 22, color = rgb(140, 150, 170)},
	["03_Viperfish"] = {name = "Рыба-гадюка", length = 25, color = rgb(170, 40, 70)},
	["04_Reefbreaker"] = {name = "Рифолом", length = 32, color = rgb(160, 120, 80)},
	["05_Leviathan"] = {name = "Левиафан Бездны", length = 40, color = rgb(40, 50, 90)},
	Piranha = {name = "Пиранья", length = 4.3, color = rgb(90, 180, 170)},
	Moray = {name = "Мурена", length = 9.6, color = rgb(140, 170, 60)},
	Stonefish = {name = "Рыба-камень", length = 5.8, color = rgb(170, 140, 100)},
	Wolffish = {name = "Зубатка", length = 7, color = rgb(160, 180, 220)},
	Sawfish = {name = "Рыба-пила", length = 10.3, color = rgb(120, 200, 210)},
	GoblinShark = {name = "Акула-гоблин", length = 10, color = rgb(230, 170, 190)},
	Fangtooth = {name = "Саблезуб", length = 6.1, color = rgb(140, 90, 200)},
	GulperEel = {name = "Большерот", length = 9.6, color = rgb(80, 70, 140)},
	Dragonfish = {name = "Глубоководный дракон", length = 7.8, color = rgb(50, 60, 100)},
	FrilledShark = {name = "Плащеносная акула", length = 9.6, color = rgb(150, 120, 100)},
}
BaseConfig.CatchRadius = 5 -- studs from the predator's head to the player
BaseConfig.NestRespawn = 25 -- seconds until a taken egg reappears
BaseConfig.BaseWalkSpeed = 16
BaseConfig.SpeedPerLevel = 0.5 -- swim speed per point of upgraded speed

---------------------------------------------------------------- effects & timing
BaseConfig.IncomeTick = 1 -- seconds between payouts
-- Fish fly above the pool: each one gets its own oval path and height.
BaseConfig.FishFlyHeight = {3.0, 6.5} -- above the water surface
BaseConfig.FishSwimSpeed = 0.55 -- radians per second
BaseConfig.AnimationDistance = 220

return BaseConfig
