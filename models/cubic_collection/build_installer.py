"""Generate an offline, multi-selection Studio Command Bar installer."""
from pathlib import Path
folder=Path(__file__).resolve().parent
source=(folder/'Cubic_Opening.txt').read_text(encoding='utf-8')
assert ']====]' not in source
prefix='''-- CUBIC COLLECTION INSTALLER: STOP Play, select block Model(s), paste ALL in Command Bar.
-- Normalizes size to 4 studs, preserves the model's ground level, creates Server Scripts.
local RESIZE_TO_FOUR_STUDS = true
assert(not game:GetService("RunService"):IsRunning(), "[Cubic] Stop Play before installing")
local selection=game:GetService("Selection"):Get()
assert(#selection>0,"[Cubic] Select one or more complete Lucky Block Models in Explorer")
local source=[====[
'''
suffix='''
]====]
local presets={"Toilet","Crab","Shark","Frog","Mystic","Paradise","Pumpkin","Pizza","Chicken","Glitch"}
local candidates,seen={},{}
local function findPresets(model)
    local found={}
    for _,part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") and part.Name:lower():sub(1,4)=="body" then
            for _,preset in ipairs(presets) do
                if part.Name:lower():find(preset:lower(),1,true) then found[preset]=true end
            end
        end
    end
    local names={}; for name in pairs(found) do table.insert(names,name) end
    return names
end
local function collect(model)
    if seen[model] then return end
    seen[model]=true
    local names=findPresets(model)
    if #names==1 then table.insert(candidates,{model=model,preset=names[1]})
    elseif #names>1 then
        for _,child in ipairs(model:GetChildren()) do if child:IsA("Model") then collect(child) end end
    else warn("[Cubic] Skipped "..model:GetFullName()..": no Body_<preset> mesh; import components separately") end
end
for _,item in ipairs(selection) do
    local model=item
    while model and model~=workspace and not model:IsA("Model") do model=model.Parent end
    if model and model~=workspace then collect(model) end
end
assert(#candidates>0,"[Cubic] No collection blocks found. Select the full imported Models, not a single combined MeshPart")
local installed={}
for _,entry in ipairs(candidates) do
    local model=entry.model
    -- Disable only known opening controllers, keeping unrelated game scripts.
    for _,item in ipairs(model:GetDescendants()) do
        if item:IsA("BaseScript") then
            local ok,text=pcall(function() return item.Source end)
            if ok and (text:find("CUBIC LUCKY COLLECTION",1,true) or text:find("SKYBRICK",1,true) or text:find("WINGED LUCKY BLOCK",1,true)) then
                item.Enabled=false
            elseif item.Enabled then warn("[Cubic] Check other enabled Script: "..item:GetFullName()) end
        end
    end
    if not model:IsDescendantOf(workspace) then model.Parent=workspace end
    for _,part in ipairs(model:GetDescendants()) do
        if part:IsA("MeshPart") then part.Color=Color3.fromRGB(255,255,255); part.Material=Enum.Material.SmoothPlastic end
    end
    if RESIZE_TO_FOUR_STUDS then
        local before,size=model:GetBoundingBox()
        local bottom=before.Position.Y-size.Y*.5
        local largest=math.max(size.X,size.Y,size.Z)
        assert(largest>0,"[Cubic] Empty model")
        model:ScaleTo(model:GetScale()*4/largest)
        local after,newSize=model:GetBoundingBox()
        local delta=bottom-(after.Position.Y-newSize.Y*.5)
        model:PivotTo(CFrame.new(0,delta,0)*model:GetPivot())
    end
    model:SetAttribute("LuckyPreset",entry.preset)
    local opening=model:FindFirstChild("Cubic_Opening")
    if opening and not opening:IsA("Script") then opening.Name="Cubic_Opening_Old"; opening=nil end
    if not opening then opening=Instance.new("Script"); opening.Name="Cubic_Opening"; opening.Parent=model end
    opening.Enabled=false; opening.Source=source; opening.RunContext=Enum.RunContext.Server; opening.Enabled=true
    model:SetAttribute("CubicStatus","Installed: press Play")
    table.insert(installed,model)
    print("[Cubic] INSTALLED "..entry.preset..": "..model:GetFullName())
end
game:GetService("Selection"):Set(installed)
print("[Cubic] Installed "..#installed.." block(s). Press PLAY/F5. Output should say [Cubic] READY")
if not game:GetService("ProximityPromptService").Enabled then warn("[Cubic] ProximityPromptService.Enabled=false: enable global prompts") end
'''
(folder/'Install_CommandBar.txt').write_text(prefix+source+suffix,encoding='utf-8')
print('Generated Install_CommandBar.txt')
