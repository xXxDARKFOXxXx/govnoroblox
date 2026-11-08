"""Regenerate the offline Studio Command Bar installer after editing the TXT."""
from pathlib import Path

folder = Path(__file__).resolve().parent
source = (folder / "Roblox_Opening_Animation_Adapted.txt").read_text(encoding="utf-8")
assert "]====]" not in source
installer = '''-- SKYBRICK INSTALLER: paste the WHOLE file into Studio's Command Bar.
-- Stop Play first and select the Lucky Block model (or its existing Script).
-- Runs in the editor; no HTTP requests, plugins or asset IDs required.
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "[Skybrick] Stop Play before installing")
local selection = game:GetService("Selection"):Get()
assert(#selection == 1, "[Skybrick] Select ONE Lucky Block model in Explorer first")
local selected = selection[1]
local model = selected
while model and not model:IsA("Model") do model = model.Parent end
assert(model and model ~= workspace, "[Skybrick] Select the Lucky Block model, not Workspace")
local source = [====[
''' + source + '''
]====]

-- Disable only recognized animation controllers, keeping unrelated scripts.
local disabled = 0
for _, item in ipairs(model:GetDescendants()) do
    if item:IsA("BaseScript") then
        local readable, text = pcall(function() return item.Source end)
        local recognized = readable and (string.find(text, "SKYBRICK", 1, true)
            or string.find(text, "WINGED LUCKY BLOCK", 1, true))
        if recognized or item == selected then
            item.Enabled = false
            disabled = disabled + 1
        elseif item.Enabled then
            warn("[Skybrick] Another script remains enabled: " .. item:GetFullName()
                .. ". Check that it is not another opening animation")
        end
    end
end
local opening = model:FindFirstChild("Opening_Skybrick")
if opening and not opening:IsA("Script") then
    opening.Name = "Opening_Skybrick_Old"
    opening = nil
end
if not opening then
    opening = Instance.new("Script")
    opening.Name = "Opening_Skybrick"
    opening.Parent = model
end
opening.Enabled = false
opening.Source = source
opening.RunContext = Enum.RunContext.Server
if not model:IsDescendantOf(workspace) then model.Parent = workspace end
opening.Enabled = true
model:SetAttribute("SkybrickStatus", "Installed: press Play")
game:GetService("Selection"):Set({opening})
print("[Skybrick] INSTALLED: " .. opening:GetFullName() .. "; disabled old controllers: " .. disabled)
print("[Skybrick] Press PLAY (F5), approach the block and hold E. Output should show [Skybrick] READY")
if not game:GetService("ProximityPromptService").Enabled then
    warn("[Skybrick] ProximityPromptService.Enabled is false; enable it to display prompts")
end
'''
(folder / "Studio_Install_CommandBar.txt").write_text(installer, encoding="utf-8")
print("Generated Studio_Install_CommandBar.txt")
