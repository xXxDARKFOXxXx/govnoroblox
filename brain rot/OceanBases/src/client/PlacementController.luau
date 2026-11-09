-- PlacementController (client): putting the held egg / fish into the yard.
-- While the player holds an egg or a fish (Player attribute HeldItem, picked in
-- the HUD inventory) and stands in their own yard, a ring follows the mouse on
-- the yard floor: green = it can go there, red = not (outside the pool, too
-- close to another egg, or the base is full). A click (or tap) sends the spot
-- to the server (remote PlaceItem), which checks everything again.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))

local PlacementController = {}
local GOOD, BAD = Color3.fromRGB(110, 240, 140), Color3.fromRGB(255, 90, 90)

local player = Players.LocalPlayer
local connections = {}
local ring, hint, hintLabel
local current -- {base, spot, ok}

local function ownBase(): Model?
	local folder = workspace:FindFirstChild("OceanBases")
	if not folder then return nil end
	for _, base in folder:GetChildren() do
		if base:GetAttribute("OwnerUserId") == player.UserId then return base end
	end
	return nil
end

-- Is the held item something that goes into the yard?
function PlacementController.holding(): boolean
	local held = player:GetAttribute("HeldItem")
	if type(held) ~= "string" then return false end
	if player:GetAttribute("CarryEgg") then return false end
	local inventory = player:FindFirstChild("Inventory")
	local item = inventory and inventory:FindFirstChild(held)
	if not item then return false end
	return Config.Eggs[held] ~= nil or item:GetAttribute("Category") == "Fish"
end

-- Floor spot for a screen point, and whether it is free (client-side guess).
function PlacementController.spotAt(base: Model, screen: Vector2): (Vector3?, boolean, string?)
	local camera = workspace.CurrentCamera
	if not camera or not base.PrimaryPart then return nil, false end
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local origin = base.PrimaryPart.CFrame
	local floorY = origin:PointToWorldSpace(Vector3.new(0, Config.FloorTop, 0)).Y
	if math.abs(ray.Direction.Y) < 1e-4 then return nil, false end
	local t = (floorY - ray.Origin.Y) / ray.Direction.Y
	if t <= 0 or t > 400 then return nil, false end
	local point = ray.Origin + ray.Direction * t
	local lp = origin:PointToObjectSpace(point)
	local depth = base:GetAttribute("YardDepth") or Config.depth(1)
	-- Far outside the yard: no ring at all.
	if math.abs(lp.X) > Config.YardWidth / 2 + 6 or lp.Z < -6 or lp.Z > depth + 6 then return nil, false end
	local held = player:GetAttribute("HeldItem")
	local isEgg = type(held) == "string" and Config.Eggs[held] ~= nil
	local cells = base:FindFirstChild("Cells")
	local count = cells and #cells:GetChildren() or 0
	if count >= (base:GetAttribute("Capacity") or Config.StartCapacity) then return point, false, "full" end
	if not Config.insideYard(lp.X, lp.Z, depth) then return point, false, "outside" end
	if isEgg and cells then
		for _, cell in cells:GetChildren() do
			local placement = cell:FindFirstChild("EggPlacement")
			if placement and cell:GetAttribute("State") == "Egg" then
				local p = placement.CFrame.Position
				if Vector2.new(p.X - point.X, p.Z - point.Z).Magnitude < Config.PlaceSpacing then return point, false, "busy" end
			end
		end
	end
	return point, true, nil
end

local function makeVisuals()
	ring = Instance.new("Part")
	ring.Name = "OceanPlaceRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.12, Config.PlaceSpacing - 0.6, Config.PlaceSpacing - 0.6)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.45
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Parent = nil

	hint = Instance.new("ScreenGui")
	hint.Name = "OceanPlaceHint"
	hint.ResetOnSpawn = false
	hint.DisplayOrder = 30
	hint.Enabled = false
	hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "Hint"
	hintLabel.AnchorPoint = Vector2.new(0.5, 1)
	hintLabel.Position = UDim2.new(0.5, 0, 1, -150)
	hintLabel.Size = UDim2.fromOffset(460, 36)
	hintLabel.BackgroundColor3 = Color3.fromRGB(20, 26, 40)
	hintLabel.BackgroundTransparency = 0.3
	hintLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	hintLabel.TextScaled = true
	hintLabel.TextColor3 = Color3.new(1, 1, 1)
	hintLabel.Parent = hint
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = hintLabel
	hint.Parent = player:WaitForChild("PlayerGui")
end

local REASONS = {full = "База заполнена — улучши её", busy = "Слишком близко к другому яйцу", outside = "Ставь внутри вольера"}

function PlacementController.update(screen: Vector2)
	current = nil
	local base = nil
	if PlacementController.holding() then base = ownBase() end
	local spot, ok, reason
	if base then spot, ok, reason = PlacementController.spotAt(base, screen) end
	if not spot then
		ring.Parent = nil
		hint.Enabled = base ~= nil
		if base then
			local cells = base:FindFirstChild("Cells")
			hintLabel.Text = string.format("Кликни по полу вольера, чтобы поставить · %d/%d", cells and #cells:GetChildren() or 0, base:GetAttribute("Capacity") or Config.StartCapacity)
		end
		return
	end
	current = {base = base, spot = spot, ok = ok}
	ring.Color = ok and GOOD or BAD
	ring.CFrame = CFrame.new(spot + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	hint.Enabled = true
	local cells = base:FindFirstChild("Cells")
	local used = cells and #cells:GetChildren() or 0
	hintLabel.Text = ok and string.format("Клик — поставить · места %d/%d", used, base:GetAttribute("Capacity") or Config.StartCapacity)
		or REASONS[reason or ""] or "Сюда нельзя"
end

function PlacementController.start()
	makeVisuals()
	local remotes = ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("Remotes", 30)
	local placeItem = remotes and remotes:WaitForChild("PlaceItem", 30)
	table.insert(connections, RunService.RenderStepped:Connect(function()
		PlacementController.update(UserInputService:GetMouseLocation())
	end))
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not placeItem then return end
		local click = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
		if not click then return end
		if input.UserInputType == Enum.UserInputType.Touch then
			PlacementController.update(Vector2.new(input.Position.X, input.Position.Y))
		end
		if current and current.ok then placeItem:FireServer(current.spot) end
	end))
end

function PlacementController.stop()
	for _, c in connections do c:Disconnect() end
	table.clear(connections)
	if ring then ring:Destroy() end
	if hint then hint:Destroy() end
end

return PlacementController
