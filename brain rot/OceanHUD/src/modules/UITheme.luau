-- UITheme: palette, sizes and timings for the OceanHUD. All sizes are at the
-- 1648x928 reference resolution; the controller scales them for each screen.
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local UITheme = {}

UITheme.Font = Enum.Font.FredokaOne
UITheme.Ink = rgb(26, 16, 48)
UITheme.White = rgb(255, 255, 255)

-- Left column, top to bottom.
UITheme.Buttons = {
	{key = "Rebirth", title = "Перерождение", top = rgb(204, 120, 255), bottom = rgb(116, 38, 214), edge = rgb(72, 18, 150), glow = rgb(236, 190, 255)},
	{key = "Gifts", title = "Подарки", top = rgb(255, 222, 70), bottom = rgb(255, 128, 16), edge = rgb(196, 76, 0), glow = rgb(255, 236, 150)},
	{key = "Shop", title = "Магазин", top = rgb(255, 104, 96), bottom = rgb(206, 20, 40), edge = rgb(140, 8, 24), glow = rgb(255, 180, 170)},
	{key = "Index", title = "Индекс", top = rgb(96, 200, 255), bottom = rgb(24, 98, 234), edge = rgb(12, 56, 170), glow = rgb(170, 230, 255)},
}

-- Bottom-right collection buttons: what fish and eggs the player has.
UITheme.Inventory = {
	{key = "Fish", title = "Рыбы", icon = "SharkFin", top = rgb(96, 236, 236), bottom = rgb(0, 140, 172), edge = rgb(0, 86, 118), glow = rgb(170, 250, 250)},
	{key = "Eggs", title = "Яйца", icon = "Egg", top = rgb(156, 236, 96), bottom = rgb(46, 164, 50), edge = rgb(20, 106, 30), glow = rgb(206, 250, 170)},
}

UITheme.Coins = {
	top = rgb(112, 68, 24), bottom = rgb(52, 28, 8), rim = rgb(255, 204, 52), glow = rgb(255, 150, 30),
	valueTop = rgb(255, 244, 130), valueBottom = rgb(255, 178, 20),
}
UITheme.Speed = {
	top = rgb(54, 146, 255), bottom = rgb(16, 56, 198), rim = rgb(128, 230, 255), glow = rgb(70, 200, 255),
	valueTop = rgb(255, 248, 130), valueBottom = rgb(255, 196, 30),
}
UITheme.Size = {
	Reference = Vector2.new(1648, 928),
	ButtonW = 112, ButtonH = 106, ButtonGap = 12,
	Left = 35, Top = 60, Bottom = 22,
	CounterW = 340, CounterH = 88, CounterGap = 14,
	InventoryW = 112 * 2 + 14, InventoryH = 106, InventoryGap = 14,
	MenuW = 560, MenuH = 400,
}

UITheme.Time = {
	Hover = 0.17, Press = 0.08, Release = 0.3,
	MenuOpen = 0.26, MenuClose = 0.16,
	Count = 0.6, Pop = 0.35,
}

return UITheme
