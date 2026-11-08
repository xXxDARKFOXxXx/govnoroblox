-- UIComponents: reusable building blocks. Volume is faked with stacked layers:
-- outer shadow, darker bottom edge, gradient body, light top highlight and gloss.
local Theme = require(script.Parent.UITheme)
local Assets = require(script.Parent.UIAssets)

local UIComponents = {}

function UIComponents.new(class: string, parent: Instance?, props: {[string]: any}?): any
	local object = Instance.new(class)
	for key, value in pairs(props or {}) do
		object[key] = value
	end
	object.Parent = parent
	return object
end
local new = UIComponents.new

function UIComponents.corner(object: Instance, scale: number?, offset: number?)
	return new("UICorner", object, {CornerRadius = UDim.new(scale or 0, offset or 0)})
end

function UIComponents.stroke(object: Instance, color: Color3, thickness: number, transparency: number?)
	return new("UIStroke", object, {
		Color = color, Thickness = thickness, Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round,
	})
end

function UIComponents.gradient(object: Instance, top: Color3, bottom: Color3, rotation: number?)
	return new("UIGradient", object, {Color = ColorSequence.new(top, bottom), Rotation = rotation or 90})
end

function UIComponents.fadeGradient(object: Instance, from: number, to: number, rotation: number?)
	return new("UIGradient", object, {
		Transparency = NumberSequence.new(from, to), Rotation = rotation or 90,
	})
end

function UIComponents.frame(parent: Instance, name: string, props: {[string]: any}?)
	local object = new("Frame", parent, {Name = name, BorderSizePixel = 0, BackgroundColor3 = Theme.White})
	for key, value in pairs(props or {}) do
		object[key] = value
	end
	return object
end

function UIComponents.holder(parent: Instance, name: string, position: UDim2, size: UDim2, z: number?)
	return UIComponents.frame(parent, name, {
		Position = position, Size = size, BackgroundTransparency = 1, ZIndex = z or 1,
	})
end

-- Text with a thick dark outline. A gradient (top -> bottom) is optional; the
-- text colour is white then, because UIGradient multiplies it.
function UIComponents.label(parent: Instance, name: string, text: string, props: {[string]: any}?, outline: Color3?, gradientColors: {Color3}?)
	local object = new("TextLabel", parent, {
		Name = name, Text = text, BackgroundTransparency = 1, BorderSizePixel = 0,
		Font = Theme.Font, TextColor3 = Theme.White, TextSize = 20, ZIndex = 5,
	})
	for key, value in pairs(props or {}) do
		object[key] = value
	end
	new("UIStroke", object, {
		Color = outline or Theme.Ink, Thickness = math.clamp(object.TextSize / 10, 1.5, 3.5),
		LineJoinMode = Enum.LineJoinMode.Round,
	})
	if gradientColors then
		object.TextColor3 = Theme.White
		UIComponents.gradient(object, gradientColors[1], gradientColors[2])
	end
	return object
end

function UIComponents.image(parent: Instance, name: string, assetName: string, position: UDim2, size: UDim2, z: number?)
	return new("ImageLabel", parent, {
		Name = name, Image = Assets.image(assetName), Position = position, Size = size,
		BackgroundTransparency = 1, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Fit, ZIndex = z or 4,
	})
end

-- Volumetric rounded plate. Returns the body frame (put content inside the
-- returned holder, which is a sibling-safe container of the same size).
-- style = {top, bottom, edge?, rim, rimThickness?, glow?, radius (scale)}
function UIComponents.plate(parent: Instance, name: string, position: UDim2, size: UDim2, style, z: number?)
	z = z or 1
	local holder = UIComponents.holder(parent, name, position, size, z)
	local radius = UDim.new(style.radius or 0.5, 0)
	local glow
	if style.glow then
		glow = UIComponents.frame(holder, "Glow", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 14, 1, 14), BackgroundColor3 = style.glow,
			BackgroundTransparency = style.glowTransparency or 0.62, ZIndex = z,
		})
		new("UICorner", glow, {CornerRadius = radius})
	end
	local shadow = UIComponents.frame(holder, "Shadow", {
		Position = UDim2.fromOffset(0, 7), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Ink, BackgroundTransparency = 0.45, ZIndex = z,
	})
	new("UICorner", shadow, {CornerRadius = radius})
	local edge = UIComponents.frame(holder, "Edge", {
		Position = UDim2.fromOffset(0, 4), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = style.edge or style.bottom:Lerp(Theme.Ink, 0.45), ZIndex = z,
	})
	new("UICorner", edge, {CornerRadius = radius})
	local body = UIComponents.frame(holder, "Body", {Size = UDim2.fromScale(1, 1), ZIndex = z + 1})
	new("UICorner", body, {CornerRadius = radius})
	UIComponents.gradient(body, style.top, style.bottom)
	local rim = UIComponents.stroke(body, style.rim, style.rimThickness or 3)
	-- Light upper half: a white sheet that fades out towards the middle.
	local sheen = UIComponents.frame(body, "Sheen", {
		Position = UDim2.fromOffset(4, 3), Size = UDim2.new(1, -8, 0.5, 0),
		BackgroundTransparency = 0.55, ZIndex = z + 2,
	})
	new("UICorner", sheen, {CornerRadius = radius})
	UIComponents.fadeGradient(sheen, 0.25, 1)
	return holder, body, rim, glow
end

return UIComponents
