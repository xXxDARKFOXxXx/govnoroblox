# Copies the HUD icons into every installed Roblox Studio version's content folder,
# so "rbxasset://textures/OceanHUD/<name>.png" shows them in Studio play tests.
# This is a local preview only: other players need uploaded asset IDs (see README).
# Studio updates create a new version folder; run this again after an update.
$assets = Join-Path $PSScriptRoot "..\assets"
$versions = Join-Path $env:LOCALAPPDATA "Roblox\Versions"
$count = 0
Get-ChildItem $versions -Directory | Where-Object { Test-Path (Join-Path $_.FullName "RobloxStudioBeta.exe") } | ForEach-Object {
    $target = Join-Path $_.FullName "content\textures\OceanHUD"
    New-Item -ItemType Directory -Force $target | Out-Null
    Copy-Item (Join-Path $assets "*.png") $target -Force
    Write-Output "Installed icons into $target"
    $count++
}
if ($count -eq 0) { Write-Error "Roblox Studio not found in $versions" }
