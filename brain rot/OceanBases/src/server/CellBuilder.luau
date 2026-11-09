-- CellBuilder: one place in the yard that holds an egg or a fish. There is no
-- grid: a place is created where the owner puts an egg (anywhere on the yard
-- floor) and removed again when the fish is taken out or the egg deleted.
--
-- CellN (Model, attributes Index/State; PrimaryPart = EggPlacement)
--   EggPlacement     (invisible Part on the floor: the egg stands here)
--   InteractionPoint (invisible Part with the CellInfo label: name, timer, income)
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

-- position = world point on the yard floor.
function CellBuilder.build(parent: Instance, position: Vector3, index: number)
	local cf = CFrame.new(position)
	local cell = Pieces.model(parent, "Cell" .. index)
	cell:SetAttribute("Index", index)
	cell:SetAttribute("State", "Empty")
	cell.PrimaryPart = Pieces.part(cell, "EggPlacement", Vector3.new(2, 0.2, 2), cf * CFrame.new(0, 0.1, 0), C.White, nil, {Transparency = 1})
	Pieces.folder(cell, "Content")

	local point = Pieces.part(cell, "InteractionPoint", Vector3.new(1, 1, 1), cf * CFrame.new(0, Config.BaseEggHeight + 0.5, 0), C.White, nil, {Transparency = 1})
	local gui = Instance.new("BillboardGui")
	gui.Name = "CellInfo"
	gui.Size = UDim2.fromOffset(170, 50)
	gui.StudsOffset = Vector3.new(0, 1.2, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 45
	gui.Enabled = false
	gui.Parent = point
	label(gui, "Title", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.55), C.White)
	label(gui, "Line", UDim2.fromScale(0, 0.55), UDim2.fromScale(1, 0.45), C.GlowGold)
	return cell
end

return CellBuilder
