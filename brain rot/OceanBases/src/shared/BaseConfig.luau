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
	Vector3.new(-112, 4, -156),
	Vector3.new(-56, 4, -156),
	Vector3.new(0, 4, -156),
	Vector3.new(56, 4, -156),
	Vector3.new(112, 4, -156),
}
BaseConfig.Facing = 0 -- yards open towards +Z (the court and the ocean corridor)

---------------------------------------------------------------- yard & cells
BaseConfig.CellSize = 8 -- one cell = one 8x8 floor tile (same grid as the court)
BaseConfig.Columns = 5
BaseConfig.FloorTop = 1 -- the yard floor is one stud above the court
BaseConfig.Margin = 2 -- between the fence and the cells
BaseConfig.FrontWalk = 7 -- walkway between the last row and the front fence
BaseConfig.StartRows = 2
BaseConfig.MaxRows = 4
-- Upgrade to N rows: cells and price.
BaseConfig.Levels = {
	[2] = {cells = 10, price = 0},
	[3] = {cells = 15, price = 5000},
	[4] = {cells = 20, price = 25000},
}
BaseConfig.EntranceWidth = 10

function BaseConfig.width(): number
	return BaseConfig.Columns * BaseConfig.CellSize + BaseConfig.Margin * 2
end

-- Depth of the yard (back fence to front fence) for a number of rows.
function BaseConfig.depth(rows: number): number
	return BaseConfig.Margin + rows * BaseConfig.CellSize + BaseConfig.FrontWalk
end

-- Local centre (X, Z) of a cell; rows count from the back.
function BaseConfig.cellCenter(row: number, column: number): Vector2
	local s = BaseConfig.CellSize
	local x = (column - (BaseConfig.Columns + 1) / 2) * s
	local z = BaseConfig.Margin + (row - 0.5) * s
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
	CoralPink = rgb(255, 120, 178), CoralPurple = rgb(176, 110, 255),
	Shell = rgb(255, 232, 226), Starfish = rgb(255, 150, 120),
	Red = rgb(232, 60, 60), White = rgb(255, 255, 255), Gold = rgb(255, 200, 40),
	Foam = rgb(210, 250, 255), Metal = rgb(140, 150, 170),
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

-- income = coins per second straight into the owner's pocket.
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
BaseConfig.IncomeTick = 1 -- seconds between payouts
BaseConfig.FishHeight = 3.2 -- fish float this high above their cell
BaseConfig.FishSwimRadius = 1.8
BaseConfig.FishSwimSpeed = 0.8 -- radians per second
BaseConfig.AnimationDistance = 220

return BaseConfig
