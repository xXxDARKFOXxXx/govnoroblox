-- MenuController: one main window at a time, Scale + Fade open/close,
-- close button, backdrop click, Escape, and toggling by pressing the same button.
-- Each window has an empty "Content" ScrollingFrame for the future game content.
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.UITheme)
local C = require(script.Parent.UIComponents)
local Anim = require(script.Parent.UIAnimations)

local MenuController = {}
MenuController.__index = MenuController

local DESCRIPTIONS = {
	Rebirth = "Начни заново и получи постоянный бонус к доходу и скорости.",
	Gifts = "Забирай подарки за время в игре и ежедневные награды.",
	Shop = "Улучшения скорости, яйца и полезные предметы.",
	Index = "Коллекция всех найденных яиц и питомцев.",
}

function MenuController.new(root: GuiObject, openEvent: BindableEvent, sound: Sound?)
	local self = setmetatable({root = root, openEvent = openEvent, sound = sound, windows = {}, current = nil, connections = {}}, MenuController)
	local size = Theme.Size
	local backdrop = C.new("TextButton", root, {
		Name = "MenuBackdrop", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Ink, BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 30,
	})
	self.backdrop = backdrop
	for _, spec in Theme.Buttons do
		local window = C.new("CanvasGroup", backdrop, {
			Name = spec.key .. "Menu", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size.MenuW, size.MenuH + 10), BackgroundTransparency = 1,
			GroupTransparency = 1, Visible = false, ZIndex = 31,
		})
		local scale = C.new("UIScale", window, {Scale = 0.85})
		local panel, body = C.plate(window, "Panel", UDim2.fromOffset(0, 0), UDim2.fromOffset(size.MenuW, size.MenuH), {
			top = spec.top, bottom = spec.bottom, edge = spec.edge, rim = Theme.Ink, rimThickness = 4, radius = 0.08,
		}, 31)
		local fit = C.new("UIScale", panel, {Name = "Fit", Scale = 1})
		local inner = C.holder(body, "InnerRim", UDim2.fromOffset(7, 7), UDim2.new(1, -14, 1, -14), 34)
		C.corner(inner, 0.07)
		C.stroke(inner, Theme.White, 3, 0.3)
		C.image(body, "Icon", spec.key, UDim2.fromOffset(18, 10), UDim2.fromOffset(78, 78), 35)
		local title = C.label(body, "Title", spec.title, {
			Position = UDim2.fromOffset(104, 18), Size = UDim2.fromOffset(360, 56), TextSize = 40,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 35,
		})
		title.TextScaled = false
		local close = C.new("TextButton", body, {
			Name = "Close", Text = "X", Font = Theme.Font, TextSize = 30, TextColor3 = Theme.White,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.fromOffset(52, 52),
			BackgroundColor3 = Theme.White, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 36,
		})
		C.corner(close, 0.3)
		C.gradient(close, Color3.fromRGB(255, 104, 96), Color3.fromRGB(206, 20, 40))
		C.stroke(close, Theme.Ink, 3.5)
		C.new("UIStroke", close, {Color = Theme.Ink, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})
		local closeScale = C.new("UIScale", close, {Scale = 1})
		-- Content area for the real menu items later.
		local content = C.new("ScrollingFrame", body, {
			Name = "Content", Position = UDim2.fromOffset(22, 96), Size = UDim2.new(1, -44, 1, -118),
			BackgroundColor3 = Theme.Ink, BackgroundTransparency = 0.72, BorderSizePixel = 0,
			ScrollBarThickness = 8, CanvasSize = UDim2.fromScale(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 35,
		})
		C.corner(content, 0, 18)
		C.new("UIPadding", content, {
			PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16),
		})
		C.new("UIListLayout", content, {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder})
		local placeholder = C.label(content, "Placeholder", DESCRIPTIONS[spec.key], {
			Size = UDim2.new(1, 0, 0, 90), TextSize = 24, TextWrapped = true, ZIndex = 36,
		})
		placeholder.LayoutOrder = 1
		table.insert(self.connections, close.MouseEnter:Connect(function()
			Anim.tween(closeScale, Theme.Time.Hover, {Scale = 1.1}, nil, nil, "hover")
		end))
		table.insert(self.connections, close.MouseLeave:Connect(function()
			Anim.tween(closeScale, Theme.Time.Hover, {Scale = 1}, nil, nil, "hover")
		end))
		table.insert(self.connections, close.Activated:Connect(function()
			if self.sound then self.sound:Play() end
			self:close()
		end))
		-- Clicks on the window itself must not fall through to the backdrop.
		window.Active = true
		self.windows[spec.key] = {window = window, scale = scale, fit = fit, content = content}
	end
	table.insert(self.connections, backdrop.Activated:Connect(function() self:close() end))
	table.insert(self.connections, UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then self:close() end
	end))
	return self
end

function MenuController:open(key: string)
	local entry = self.windows[key]
	if not entry then return end
	if self.current and self.current ~= key then
		self:hide(self.current, true)
	end
	self.current = key
	self.backdrop.Visible = true
	Anim.tween(self.backdrop, Theme.Time.MenuOpen, {BackgroundTransparency = 0.45}, nil, nil, "fade")
	entry.window.Visible = true
	entry.window.GroupTransparency = 1
	entry.scale.Scale = 0.85
	Anim.tween(entry.window, Theme.Time.MenuOpen, {GroupTransparency = 0}, nil, nil, "fade")
	Anim.tween(entry.scale, Theme.Time.MenuOpen, {Scale = 1}, Enum.EasingStyle.Back, Enum.EasingDirection.Out, "scale")
	self.openEvent:Fire(key)
end

function MenuController:hide(key: string, instant: boolean?)
	local entry = self.windows[key]
	if not entry then return end
	if instant then
		entry.window.Visible = false
		entry.window.GroupTransparency = 1
		return
	end
	Anim.tween(entry.scale, Theme.Time.MenuClose, {Scale = 0.88}, nil, nil, "scale")
	Anim.tween(entry.window, Theme.Time.MenuClose, {GroupTransparency = 1}, nil, nil, "fade", function()
		if self.current ~= key then entry.window.Visible = false end
	end)
end

function MenuController:close()
	local key = self.current
	if not key then return end
	self.current = nil
	self:hide(key)
	Anim.tween(self.backdrop, Theme.Time.MenuClose, {BackgroundTransparency = 1}, nil, nil, "fade", function()
		if not self.current then self.backdrop.Visible = false end
	end)
end

function MenuController:toggle(key: string)
	if self.current == key then
		self:close()
	else
		self:open(key)
	end
end

function MenuController:getContent(key: string): ScrollingFrame?
	local entry = self.windows[key]
	return entry and entry.content
end

function MenuController:destroy()
	for _, connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
end

return MenuController
