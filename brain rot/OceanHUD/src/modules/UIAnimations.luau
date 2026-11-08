-- UIAnimations: TweenService helpers. Event-driven only (no per-frame loops),
-- and every running tween for an object/property group can be cancelled.
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.UITheme)

local UIAnimations = {}

local running = setmetatable({}, {__mode = "k"})

-- Plays a tween, cancelling the previous one on the same object + channel.
function UIAnimations.tween(object: Instance, duration: number, props: {[string]: any}, style: Enum.EasingStyle?, direction: Enum.EasingDirection?, channel: string?, onDone: (() -> ())?)
	channel = channel or "default"
	running[object] = running[object] or {}
	local previous = running[object][channel]
	if previous then
		previous:Cancel()
	end
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local t = TweenService:Create(object, info, props)
	running[object][channel] = t
	local connection
	connection = t.Completed:Connect(function(state)
		connection:Disconnect()
		if running[object] and running[object][channel] == t then
			running[object][channel] = nil
		end
		if onDone and state == Enum.PlaybackState.Completed then
			onDone()
		end
	end)
	t:Play()
	return t
end

function UIAnimations.cancelAll()
	for _, channels in pairs(running) do
		for _, t in pairs(channels) do
			t:Cancel()
		end
	end
	table.clear(running)
end

-- Quick grow then elastic return. scaleObject is a UIScale.
function UIAnimations.pop(scaleObject: UIScale, peak: number?, duration: number?)
	scaleObject.Scale = peak or 1.25
	return UIAnimations.tween(scaleObject, duration or Theme.Time.Pop, {Scale = 1}, Enum.EasingStyle.Back, Enum.EasingDirection.Out, "pop")
end

-- Brief flash: object becomes visible at `from` transparency and fades out.
function UIAnimations.flash(object: GuiObject, property: string, from: number, duration: number?)
	object[property] = from
	return UIAnimations.tween(object, duration or 0.45, {[property] = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, "flash")
end

-- Little wiggle (rotation), e.g. for the lightning bolt.
function UIAnimations.wiggle(object: GuiObject, angle: number?)
	object.Rotation = angle or 14
	return UIAnimations.tween(object, 0.45, {Rotation = 0}, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, "wiggle")
end

-- Hover / press behaviour for a candy button. Returns its connections.
-- parts = {button, scale (UIScale), rim (UIStroke), glow (Frame), sound (Sound?)}
function UIAnimations.bindButton(parts, onActivated: () -> ())
	local button, scale, rim, glow, sound = parts.button, parts.scale, parts.rim, parts.glow, parts.sound
	local hovered = false
	local function hover(on: boolean)
		hovered = on
		UIAnimations.tween(scale, Theme.Time.Hover, {Scale = on and 1.07 or 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, "hover")
		UIAnimations.tween(rim, Theme.Time.Hover, {Transparency = on and 0 or 0.25}, nil, nil, "rim")
		UIAnimations.tween(glow, Theme.Time.Hover, {BackgroundTransparency = on and 0.45 or 1}, nil, nil, "glow")
	end
	local connections = {
		button.MouseEnter:Connect(function() hover(true) end),
		button.MouseLeave:Connect(function() hover(false) end),
		button.SelectionGained:Connect(function() hover(true) end),
		button.SelectionLost:Connect(function() hover(false) end),
		button.Activated:Connect(function()
			if sound then
				sound:Play()
			end
			UIAnimations.tween(scale, Theme.Time.Press, {Scale = 0.93}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, "hover", function()
				UIAnimations.tween(scale, Theme.Time.Release, {Scale = hovered and 1.07 or 1}, Enum.EasingStyle.Back, Enum.EasingDirection.Out, "hover")
			end)
			onActivated()
		end),
	}
	return connections
end

return UIAnimations
