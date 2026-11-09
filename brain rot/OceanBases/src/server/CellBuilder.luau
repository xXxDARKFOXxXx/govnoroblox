-- CellBuilder: one cell of the yard = one studded 8x8 floor tile. An egg can
-- be placed on any free cell; the fish that hatches floats above it.
--
-- CellN (Model, attributes Index/Row/Column/State)
--   Tile             (walkable floor tile, checker colour)
--   EggPlacement     (invisible Part at the tile centre: eggs stand here)
--   InteractionPoint (invisible Part with the ProximityPrompt and CellInfo label)
--   Content          (Folder: runtime egg / fish model)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("OceanBases"):WaitForChild("BaseConfig"))
local Pieces = require(script.Parent:WaitForChild("BasePieces"))
local C = Config.Colors

local CellBuilder = {}

local function label(parent, name, position, size, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = position
	l.Size = size
	l.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.2
	l.Text = ""
	l.Parent = parent
	return l
end

function CellBuilder.build(parent: Instance, origin: CFrame, row: number, column: number, index: number)
	local s = Config.CellSize
	local spot = Config.cellCenter(row, column)
	local top = Config.FloorTop
	local cf = origin * CFrame.new(spot.X, top, spot.Y)
	local cell = Pieces.model(parent, "Cell" .. index)
	cell:SetAttribute("Index", index)
	cell:SetAttribute("Row", row)
	cell:SetAttribute("Column", column)
	cell:SetAttribute("State", "Empty")

	local color = (row + column) % 2 == 0 and C.TileA or C.TileB
	cell.PrimaryPart = Pieces.solid(cell, "Tile", Vector3.new(s, 1, s), cf * CFrame.new(0, -0.5, 0), color)
	Pieces.part(cell, "EggPlacement", Vector3.new(2, 0.2, 2), cf * CFrame.new(0, 0.1, 0), C.White, nil, {Transparency = 1})
	Pieces.folder(cell, "Content")

	local point = Pieces.part(cell, "InteractionPoint", Vector3.new(2, 2, 2), cf * CFrame.new(0, 2, 0), C.White, nil, {Transparency = 1})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CellPrompt"
	prompt.ActionText = "Поставить яйцо"
	prompt.ObjectText = "Клетка " .. index
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 5
	prompt.RequiresLineOfSight = false
	prompt.Parent = point
	local gui = Instance.new("BillboardGui")
	gui.Name = "CellInfo"
	gui.Size = UDim2.fromOffset(170, 50)
	gui.StudsOffset = Vector3.new(0, Config.FishHeight + 2.6, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 40
	gui.Enabled = false
	gui.Parent = point
	label(gui, "Title", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.55), C.White)
	label(gui, "Line", UDim2.fromScale(0, 0.55), UDim2.fromScale(1, 0.45), C.GlowGold)
	return cell
end

return CellBuilder
