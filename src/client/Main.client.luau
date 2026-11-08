local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("LuckyTide")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local action = Shared:WaitForChild("Action")
local stateEvent = Shared:WaitForChild("State")
local effects = Shared:WaitForChild("Effects")
local palette = {Dark = Color3.fromRGB(17, 33, 48), Card = Color3.fromRGB(26, 46, 62), Line = Color3.fromRGB(64, 87, 100),
	Text = Color3.fromRGB(244, 247, 242), Muted = Color3.fromRGB(166, 190, 197), Mint = Color3.fromRGB(128, 241, 188),
	Gold = Color3.fromRGB(255, 216, 106), Red = Color3.fromRGB(255, 132, 143), Blue = Color3.fromRGB(130, 204, 255)}
local profile, activePanel, muted, confirmAction = nil, nil, false, nil

local function create(class, props, parent)
	local obj = Instance.new(class)
	for k, v in pairs(props) do obj[k] = v end
	obj.Parent = parent
	return obj
end
local function round(obj, radius) create("UICorner", {CornerRadius = UDim.new(0, radius or 14)}, obj) end
local function border(obj, color) create("UIStroke", {Color = color or palette.Line, Thickness = 1, Transparency = 0.25}, obj) end
local function text(parent, value, size, pos, dims, color, bold)
	return create("TextLabel", {BackgroundTransparency = 1, Text = value, Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham,
		TextSize = size, Position = pos, Size = dims, TextColor3 = color or palette.Text,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center}, parent)
end
local function panel(parent, pos, size, color)
	local f = create("Frame", {Position = pos, Size = size, BackgroundColor3 = color or palette.Dark, BorderSizePixel = 0}, parent)
	round(f); border(f); return f
end
local function sound()
	if muted then return end
	local s = create("Sound", {SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.18, PlaybackSpeed = 1.2}, SoundService)
	s:Play(); Debris:AddItem(s, 2)
end
local function button(parent, label, pos, size, color, callback)
	local b = create("TextButton", {Position = pos, Size = size, Text = label, BackgroundColor3 = color or palette.Card,
		TextColor3 = palette.Text, Font = Enum.Font.GothamBold, TextSize = 15, AutoButtonColor = true, BorderSizePixel = 0}, parent)
	round(b, 11); border(b)
	b.Activated:Connect(function() sound(); callback() end)
	return b
end

local gui = create("ScreenGui", {Name = "LuckyTideHUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = false, DisplayOrder = 10}, player:WaitForChild("PlayerGui"))
local hud = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1}, gui)

local stats = panel(hud, UDim2.fromOffset(18, 16), UDim2.fromOffset(294, 110))
local statScale = create("UIScale", {Scale = 1}, stats)
text(stats, "LUCKY TIDE", 13, UDim2.fromOffset(16, 9), UDim2.fromOffset(210, 20), palette.Mint, true)
local cash = text(stats, "$150", 30, UDim2.fromOffset(16, 31), UDim2.fromOffset(250, 37), palette.Gold, true)
local strength = text(stats, "СИЛА  0", 13, UDim2.fromOffset(16, 77), UDim2.fromOffset(123, 22), palette.Text, true)
local income = text(stats, "+$0 / сек", 13, UDim2.fromOffset(146, 77), UDim2.fromOffset(137, 22), palette.Mint, true)
local wave = panel(hud, UDim2.new(0.5, 0, 0, 16), UDim2.fromOffset(300, 69))
wave.AnchorPoint = Vector2.new(0.5, 0)
local waveScale = create("UIScale", {Scale = 1}, wave)
local waveTitle = text(wave, "СЛЕДУЮЩАЯ ВОЛНА", 11, UDim2.fromOffset(16, 9), UDim2.fromOffset(270, 19), palette.Muted, true)
local waveText = text(wave, "01:05", 25, UDim2.fromOffset(16, 29), UDim2.fromOffset(268, 29), palette.Blue, true)
local waveBar = create("Frame", {Position = UDim2.new(0, 0, 1, -3), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = palette.Blue, BorderSizePixel = 0}, wave)

local quest = panel(hud, UDim2.fromOffset(18, 138), UDim2.fromOffset(294, 101))
local questScale = create("UIScale", {Scale = 1}, quest)
text(quest, "ТВОЙ СЛЕДУЮЩИЙ ШАГ", 11, UDim2.fromOffset(15, 10), UDim2.fromOffset(260, 18), palette.Mint, true)
local questText = text(quest, "Найди блок на пляже\nи нажми E, чтобы пнуть.", 14, UDim2.fromOffset(15, 32), UDim2.fromOffset(267, 58), palette.Text, false)
questText.TextWrapped = true
local homeInfo = text(hud, "Загрузка базы…", 12, UDim2.new(1, -275, 0, 20), UDim2.fromOffset(255, 50), palette.Text, true)
homeInfo.TextXAlignment = Enum.TextXAlignment.Right
local practice = text(hud, "", 11, UDim2.new(1, -275, 0, 70), UDim2.fromOffset(255, 30), palette.Gold)
practice.TextXAlignment = Enum.TextXAlignment.Right

local dock = create("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(656, 60), BackgroundTransparency = 1}, hud)
local dockScale = create("UIScale", {Scale = 1}, dock)
local buttons = {}
local openPanel
local defs = {{"БАЗА", "Home"}, {"ТРЕНИРОВКА", "Gym"}, {"МАГАЗИН", "Shop"}, {"ПИТОМЦЫ", "Pets"}, {"ПЕРЕРОЖД.", "Rebirth"}, {"ПОМОЩЬ", "Help"}}
for i, def in ipairs(defs) do
	buttons[def[2]] = button(dock, def[1], UDim2.fromOffset((i - 1) * 111, 0), UDim2.fromOffset(101, 56), if i == 3 then Color3.fromRGB(80, 69, 43) else palette.Dark, function()
		if def[2] == "Home" or def[2] == "Gym" then action:FireServer(def[2]) else openPanel(def[2]) end
	end)
	buttons[def[2]].TextSize = 11
end

local carry = panel(hud, UDim2.new(0.5, 0, 1, -146), UDim2.fromOffset(440, 55), Color3.fromRGB(30, 77, 68))
carry.AnchorPoint = Vector2.new(0.5, 0); carry.Visible = false
local carryScale = create("UIScale", {Scale = 1}, carry)
local carryText = text(carry, "ЯЙЦО В РУКАХ  →  НА БАЗУ", 15, UDim2.fromOffset(14, 8), UDim2.fromOffset(310, 40), palette.Mint, true)
button(carry, "ОТПУСТИТЬ", UDim2.fromOffset(326, 10), UDim2.fromOffset(103, 35), palette.Card, function() action:FireServer("Drop") end).TextSize = 10
local defend = button(hud, "Q  ВЕРНУТЬ ЯЙЦО", UDim2.new(1, -200, 1, -142), UDim2.fromOffset(180, 44), palette.Dark, function() action:FireServer("Shove") end)
defend.TextSize = 12

local toastArea = create("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 100), Size = UDim2.fromOffset(460, 210), BackgroundTransparency = 1}, hud)
local toastScale = create("UIScale", {Scale = 1}, toastArea)
create("UIListLayout", {Padding = UDim.new(0, 7), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, toastArea)
local function toast(message, kind)
	if #toastArea:GetChildren() > 5 then
		for _, c in ipairs(toastArea:GetChildren()) do if c:IsA("Frame") then c:Destroy(); break end end
	end
	local f = panel(toastArea, UDim2.new(), UDim2.fromOffset(450, 48), palette.Dark)
	local color = if kind == "Success" then palette.Mint elseif kind == "Warn" then palette.Red else palette.Text
	local t = text(f, message, 14, UDim2.fromOffset(13, 3), UDim2.new(1, -26, 1, -6), color, true)
	t.TextWrapped = true; t.TextXAlignment = Enum.TextXAlignment.Center
	task.delay(4, function() if f.Parent then f:Destroy() end end)
	if kind == "Success" then sound() end
end

local shade = create("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(), BackgroundTransparency = 0.35,
	Text = "", AutoButtonColor = false, Visible = false, ZIndex = 20}, gui)
local modal = panel(shade, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(580, 490))
modal.AnchorPoint = Vector2.new(0.5, 0.5); modal.ZIndex = 21
local modalScale = create("UIScale", {Scale = 1}, modal)
local modalTitle = text(modal, "УЛУЧШЕНИЯ", 23, UDim2.fromOffset(24, 18), UDim2.fromOffset(470, 40), palette.Text, true)
local close = button(modal, "×", UDim2.new(1, -52, 0, 17), UDim2.fromOffset(34, 34), palette.Card, function() shade.Visible = false; activePanel = nil; confirmAction = nil end)
close.TextSize = 23
local content = create("ScrollingFrame", {Position = UDim2.fromOffset(22, 74), Size = UDim2.new(1, -44, 1, -94), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = palette.Muted, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y}, modal)

local function clearContent()
	content:ClearAllChildren()
	create("UIListLayout", {Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder}, content)
	create("UIPadding", {PaddingBottom = UDim.new(0, 6), PaddingRight = UDim.new(0, 5)}, content)
end
local function row(title, body, btn, callback, color)
	local f = panel(content, UDim2.new(), UDim2.new(1, -5, 0, 98), palette.Card)
	text(f, title, 17, UDim2.fromOffset(14, 10), UDim2.new(1, -160, 0, 27), color or palette.Text, true)
	local t = text(f, body, 12, UDim2.fromOffset(14, 39), UDim2.new(1, -170, 0, 47), palette.Muted)
	t.TextWrapped = true
	if btn then button(f, btn, UDim2.new(1, -144, 0, 28), UDim2.fromOffset(128, 43), Color3.fromRGB(57, 99, 85), callback).TextSize = 13 end
	return f
end
local function paragraph(value, height, color)
	local t = text(content, value, 15, UDim2.new(), UDim2.new(1, -10, 0, height), color or palette.Muted)
	t.TextWrapped = true; t.TextYAlignment = Enum.TextYAlignment.Top
	return t
end

local function renderPanel()
	if not activePanel then return end
	clearContent()
	if not profile then paragraph("Загружаем твой прогресс…", 70); return end
	if activePanel == "Shop" then
		modalTitle.Text = "УЛУЧШЕНИЯ  ·  $" .. Rules.format(profile.Cash)
		for _, def in ipairs({{"Weight", "Гантели", "Больше силы за каждую тренировку."}, {"Speed", "Скорость", "Быстрее бегай и спасай яйца от волны."}, {"Slots", "Места на базе", "Больше питомцев — больше доход."}}) do
			local level = if def[1] == "Slots" then profile.Slots - Config.BaseSlots else profile[def[1]]
			local maximum = if def[1] == "Slots" then Config.MaxSlots - Config.BaseSlots else 12
			local isMax = level >= maximum
			row(def[2] .. " · " .. level .. "/" .. maximum, def[3], if isMax then "МАКС." else "$" .. Rules.format(Rules.upgradeCost(def[1], level)), function()
				if not isMax then action:FireServer("Upgrade", def[1]) end
			end, palette.Gold)
		end
		paragraph("Гантели работают на синей площадке тренировки. Все покупки — за игровую валюту.", 45)
	elseif activePanel == "Pets" then
		modalTitle.Text = "ПИТОМЦЫ  ·  " .. #profile.Inventory .. "/" .. profile.Slots
		if #profile.Inventory == 0 then paragraph("Здесь появятся твои питомцы. Пни блок на пляже, подбери яйцо и донеси его до зелёной площадки своей базы.", 110) end
		for _, item in ipairs(profile.Inventory) do
			local pet = Rules.findPet(Config, item.PetId)
			local rate = Rules.income(pet, item.Mutation, profile.Rebirths)
			local label = if item.Hatched then pet.Name else "Яйцо · " .. Config.Rarities[item.Tier].Name
			local detail = if item.Stolen then "Его уносят! Догони вора и нажми Q." elseif item.Hatched then "+$" .. Rules.format(rate) .. "/сек  ·  " .. (if item.Mutation == "Golden" then "ЗОЛОТОЙ ×2.5" else "Обычная форма") else "Вылупление через " .. math.max(0, item.ReadyAt - os.time()) .. "с"
			row(label, detail, if item.Hatched then "ПРОДАТЬ" else nil, function()
				confirmAction = {Kind = "Sell", Value = item.Id, Name = pet.Name, Amount = rate * 30}
				activePanel = "Confirm"; renderPanel()
			end, Color3.fromRGB(unpack(Config.Rarities[item.Tier].Color)))
		end
		local count = 0; for _ in pairs(profile.Discovered) do count += 1 end
		paragraph("КОЛЛЕКЦИЯ  " .. count .. "/" .. #Config.Pets .. "\n" .. table.concat((function()
			local list = {}; for _, pet in ipairs(Config.Pets) do table.insert(list, if profile.Discovered[pet.Id] then "✓ " .. pet.Name else "? Неизвестный питомец") end; return list
		end)(), "\n"), 290)
	elseif activePanel == "Confirm" then
		modalTitle.Text = "ПРОДАТЬ ПИТОМЦА?"
		if confirmAction then
			paragraph(confirmAction.Name .. " уйдёт с базы. Ты получишь $" .. Rules.format(confirmAction.Amount) .. ".", 100, palette.Text)
			row("Подтверждение", "Этот питомец перестанет приносить доход.", "ПРОДАТЬ", function()
				if confirmAction then action:FireServer("Sell", confirmAction.Value); confirmAction = nil end
				activePanel = "Pets"; renderPanel()
			end, palette.Red)
		end
	elseif activePanel == "Rebirth" then
		modalTitle.Text = "ПЕРЕРОЖДЕНИЕ  ·  " .. profile.Rebirths
		paragraph("Начни новый круг с постоянным усилением. Каждое перерождение даёт +50% к доходу и силе тренировки.", 80, palette.Text)
		paragraph("СБРОСЯТСЯ: деньги, копилка, сила, гантели и скорость.\n\nСОХРАНЯТСЯ: питомцы, яйца, места на базе и коллекция.", 110)
		row("Множитель ×" .. Rules.multiplier(profile.Rebirths) .. " → ×" .. Rules.multiplier(profile.Rebirths + 1), "Стоимость: $" .. Rules.format(Rules.rebirthCost(profile.Rebirths)), "ПОДТВЕРДИТЬ", function()
			action:FireServer("Rebirth")
		end, palette.Gold)
	elseif activePanel == "Help" then
		modalTitle.Text = "КАК ИГРАТЬ"
		paragraph("1. Подойди к блоку на пляже и зажми E.\n2. Подбери выпавшее яйцо и беги домой.\n3. Встань на зелёную площадку своей базы.\n4. Дождись питомца и собери деньги на жёлтой площадке.\n5. Тренируй силу и покупай улучшения.", 170, palette.Text)
		paragraph("ВОЛНА: возвращайся за зелёную линию или поднимайся по ступеням в укрытие. С яйцом телепорт недоступен.\n\nКРАЖА: яйца чужой базы можно унести, пока щит выключен. Владелец может догнать вора и нажать Q. Вылупившиеся питомцы в безопасности.", 145)
		row("Звук", "Короткие звуки наград и кнопок.", if muted then "ВКЛЮЧИТЬ" else "ВЫКЛЮЧИТЬ", function() muted = not muted; renderPanel() end)
		paragraph("В Studio действует тренировочный режим: прогресс сбрасывается после остановки Play. На опубликованном сервере включены сохранения.", 65, palette.Gold)
	end
end

openPanel = function(name)
	activePanel = name; confirmAction = nil; shade.Visible = true; renderPanel()
end

local function updateHUD()
	if not profile then return end
	cash.Text = "$" .. Rules.format(profile.Cash)
	strength.Text = "СИЛА  " .. Rules.format(profile.Strength)
	income.Text = "+$" .. Rules.format(profile.Income) .. " / сек"
	homeInfo.Text = "БАЗА " .. profile.PlotId .. "  ·  " .. #profile.Inventory .. "/" .. profile.Slots .. "\n" .. (if profile.ShieldRemaining > 0 then "ЩИТ  " .. profile.ShieldRemaining .. "с" else "ЩИТ ВЫКЛЮЧЕН")
	practice.Text = if profile.Practice then "STUDIO · ТРЕНИРОВОЧНЫЙ РЕЖИМ" else ""
	carry.Visible = profile.Carrying ~= nil
	if profile.Carrying then
		questText.Text = "Донеси яйцо на зелёную площадку своей базы. Телепорт с яйцом недоступен."
	elseif profile.Tutorial < 1 then questText.Text = "Найди блок на пляже\nи зажми E, чтобы пнуть."
	elseif profile.Tutorial == 1 then questText.Text = "Подбери яйцо и вернись\nна зелёную площадку базы."
	elseif profile.Tutorial == 2 then questText.Text = "Подожди вылупления.\nВключи щит рядом со входом!"
	elseif profile.Tutorial == 3 then questText.Text = "Собери доход на жёлтой площадке своей базы."
	else
		local nextTier
		for _, tier in ipairs(Config.Rarities) do if profile.Strength < tier.Required then nextTier = tier; break end end
		questText.Text = if nextTier then "Следующая цель: сила " .. nextTier.Required .. ".\nТренируйся и открой новые блоки." else "Все зоны открыты!\nСобери редких и золотых питомцев."
	end
end

stateEvent.OnClientEvent:Connect(function(kind, data)
	if kind == "Profile" then
		local previous = profile; profile = data; updateHUD()
		if activePanel and (not previous or previous.Cash ~= data.Cash or previous.Weight ~= data.Weight or previous.Speed ~= data.Speed or previous.Slots ~= data.Slots or previous.Rebirths ~= data.Rebirths or #previous.Inventory ~= #data.Inventory or previous.Hatched ~= data.Hatched) then renderPanel() end
	elseif kind == "Toast" then toast(data.Text, data.Kind)
	elseif kind == "OpenShop" then openPanel("Shop")
	elseif kind == "Training" then
		local t = text(hud, "+" .. data.Gain .. " СИЛА", 24, UDim2.new(0.5, -80, 0.65, 0), UDim2.fromOffset(160, 35), palette.Blue, true)
		t.TextXAlignment = Enum.TextXAlignment.Center
		TweenService:Create(t, TweenInfo.new(1), {Position = UDim2.new(0.5, -80, 0.55, 0), TextTransparency = 1}):Play()
		Debris:AddItem(t, 1.1)
	end
end)

effects.OnClientEvent:Connect(function(kind, position, tier, kicker)
	if kind == "Wave" then toast("ВОЛНА! Беги на берег или в укрытие!", "Warn"); return end
	if typeof(position) ~= "Vector3" then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and (root.Position - position).Magnitude > 180 then return end
	local col = Color3.fromRGB(unpack(Config.Rarities[tier or 1].Color))
	for i = 1, 14 do
		local p = create("Part", {Size = Vector3.new(0.3, 0.3, 0.3), CFrame = CFrame.new(position), Anchored = true,
			CanCollide = false, CanTouch = false, CanQuery = false, Material = Enum.Material.Neon, Color = col}, workspace)
		local angle = math.pi * 2 * i / 14
		TweenService:Create(p, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = position + Vector3.new(math.cos(angle) * 5, 1 + math.random() * 4, math.sin(angle) * 5), Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.05)}):Play()
		Debris:AddItem(p, 0.75)
	end
	if kind == "Kick" and kicker == player then
		local char = player.Character
		local hip = char and char:FindFirstChild("RightHip", true)
		if hip and hip:IsA("Motor6D") then
			local original = hip.C0
			TweenService:Create(hip, TweenInfo.new(0.12), {C0 = original * CFrame.Angles(-0.8, 0, 0)}):Play()
			task.delay(0.15, function() if hip.Parent then TweenService:Create(hip, TweenInfo.new(0.2), {C0 = original}):Play() end end)
		end
		sound()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonY then action:FireServer("Shove") end
	if input.KeyCode == Enum.KeyCode.B then openPanel("Shop") end
end)

local function resize()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local size = camera.ViewportSize
	local small = size.X < 850
	local portrait = size.X < 550
	statScale.Scale = if portrait then 0.58 elseif small then 0.72 else 1
	questScale.Scale = if portrait then 0.65 elseif small then 0.72 else 1
	quest.Position = UDim2.fromOffset(18, if small then 102 else 138)
	waveScale.Scale = if portrait then 0.48 elseif small then 0.68 else 1
	wave.Position = if small then UDim2.new(1, -16, 0, 16) else UDim2.new(0.5, 0, 0, 16)
	wave.AnchorPoint = if small then Vector2.new(1, 0) else Vector2.new(0.5, 0)
	homeInfo.Visible = not small; practice.Visible = not small
	if portrait then
		dock.Size = UDim2.fromOffset(326, 106); dock.AnchorPoint = Vector2.new(0.5, 0); dock.Position = UDim2.new(0.5, 0, 0, 184)
		dockScale.Scale = math.min(1, (size.X - 24) / 326)
		for i, def in ipairs(defs) do
			buttons[def[2]].Position = UDim2.fromOffset(((i - 1) % 3) * 111, math.floor((i - 1) / 3) * 55)
			buttons[def[2]].Size = UDim2.fromOffset(101, 48)
		end
	else
		dock.Size = UDim2.fromOffset(656, 60); dock.AnchorPoint = Vector2.new(0.5, 1); dock.Position = UDim2.new(0.5, 0, 1, -18)
		dockScale.Scale = math.min(1, (size.X - 24) / 656)
		for i, def in ipairs(defs) do buttons[def[2]].Position = UDim2.fromOffset((i - 1) * 111, 0); buttons[def[2]].Size = UDim2.fromOffset(101, 56) end
	end
	modalScale.Scale = math.min(1, (size.X - 24) / 580, (size.Y - 35) / 490)
	toastScale.Scale = math.min(1, (size.X - 30) / 460)
	toastArea.Position = UDim2.new(0.5, 0, 0, if portrait then 300 elseif small then 195 else 100)
	carryScale.Scale = math.min(1, (size.X - 28) / 440)
	defend.Visible = small or UserInputService.TouchEnabled
	if small then defend.Position = UDim2.new(1, -165, 1, -105); defend.Size = UDim2.fromOffset(150, 40) end
end

RunService.RenderStepped:Connect(function()
	local active = workspace:GetAttribute("WaveActive")
	local remaining = math.max(0, (workspace:GetAttribute("NextWave") or workspace:GetServerTimeNow() + 65) - workspace:GetServerTimeNow())
	local danger = active or remaining <= Config.WaveWarning
	waveTitle.Text = if active then "ВОЛНА НА ПЛЯЖЕ" elseif danger then "ВОЗВРАЩАЙСЯ НА БЕРЕГ" else "СЛЕДУЮЩАЯ ВОЛНА"
	waveText.Text = if active then "В УКРЫТИЕ!" else string.format("%02d:%02d", math.floor(remaining / 60), math.floor(remaining % 60))
	waveText.TextColor3 = if danger then palette.Red else palette.Blue
	waveBar.BackgroundColor3 = if danger then palette.Red else palette.Blue
	waveBar.Size = UDim2.new(if active then 1 else math.clamp(remaining / Config.WaveInterval, 0, 1), 0, 0, 3)
	if profile and profile.Carrying then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then carryText.Text = "ДО БАЗЫ  " .. math.floor((root.Position - profile.Home).Magnitude) .. " м  →" end
	end
end)

if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
resize()
task.spawn(function()
	for _ = 1, 20 do
		if profile then break end
		action:FireServer("Sync"); task.wait(1)
	end
end)
