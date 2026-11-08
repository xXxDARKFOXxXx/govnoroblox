-- UIAssets: every image and sound the HUD uses, in one place.
--
-- The PNG icons live in OceanHUD/assets (drawn by tools/draw_icons.py).
-- For a published game: upload them once (Studio > Asset Manager > Bulk Import),
-- then paste each "rbxassetid://..." into Uploaded below. Only real IDs from your
-- own uploads belong here.
-- Until then, Studio can show them from its local content folder
-- (tools/install-studio-textures.ps1 copies them there); that path only works
-- on this computer, not for other players.
local UIAssets = {}

UIAssets.Uploaded = {
	Rebirth = "",
	Gifts = "",
	Shop = "",
	Index = "",
	Coin = "",
	Flippers = "",
	SharkFin = "",
	Egg = "",
	Sparkle = "",
	Backpack = "",
	Food = "",
}

UIAssets.LocalFolder = "rbxasset://textures/OceanHUD/"

-- Built-in Roblox client sound (ships with every client, no upload needed).
UIAssets.ClickSound = "rbxasset://sounds/volume_slider.ogg"

function UIAssets.image(name: string): string
	local id = UIAssets.Uploaded[name]
	if type(id) == "string" and id ~= "" then
		return id
	end
	return UIAssets.LocalFolder .. name .. ".png"
end

function UIAssets.isUploaded(name: string): boolean
	local id = UIAssets.Uploaded[name]
	return type(id) == "string" and id ~= ""
end

return UIAssets
