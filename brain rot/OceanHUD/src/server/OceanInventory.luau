-- OceanInventory (ModuleScript, ServerScriptService): server-owned inventory.
-- Items live in Player.Inventory (replicated to that player's client), one
-- Folder per item with attributes the HUD reads:
--   DisplayName, Category ("Eggs" | "Fish"), Icon, Count, HotbarSlot (1-10, optional)
--
--   local Inventory = require(game.ServerScriptService.OceanInventory)
--   Inventory.add(player, "BasicEgg", {Name = "Обычное яйцо", Category = "Eggs", Icon = "Egg"})
--   Inventory.remove(player, "BasicEgg", 1)
--   Inventory.setHotbar(player, "BasicEgg", 1)
local OceanInventory = {}

OceanInventory.Categories = {Eggs = true, Fish = true}
OceanInventory.HotbarSlots = 10

function OceanInventory.folder(player: Player): Folder
	local folder = player:FindFirstChild("Inventory")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Inventory"
		folder.Parent = player
	end
	return folder
end

-- info = {Name: string, Category: string, Icon: string?, Count: number?, Data: {[string]: any}?}
function OceanInventory.add(player: Player, id: string, info)
	assert(type(id) == "string" and id ~= "", "Item id required")
	assert(OceanInventory.Categories[info.Category], "Unknown category: " .. tostring(info.Category))
	local amount = math.max(1, math.floor(info.Count or 1))
	local folder = OceanInventory.folder(player)
	local item = folder:FindFirstChild(id)
	if item then
		item:SetAttribute("Count", (item:GetAttribute("Count") or 0) + amount)
		return item
	end
	item = Instance.new("Folder")
	item.Name = id
	item:SetAttribute("DisplayName", info.Name or id)
	item:SetAttribute("Category", info.Category)
	item:SetAttribute("Icon", info.Icon or "")
	item:SetAttribute("Count", amount)
	for key, value in pairs(info.Data or {}) do item:SetAttribute(key, value) end
	item.Parent = folder
	return item
end

-- Removes `count` (default: all). Returns true if the player had enough.
function OceanInventory.remove(player: Player, id: string, count: number?): boolean
	local item = OceanInventory.folder(player):FindFirstChild(id)
	if not item then return false end
	local have = item:GetAttribute("Count") or 0
	local take = count and math.floor(count) or have
	if take > have then return false end
	if have - take <= 0 then
		item:Destroy()
	else
		item:SetAttribute("Count", have - take)
	end
	return true
end

function OceanInventory.count(player: Player, id: string): number
	local item = OceanInventory.folder(player):FindFirstChild(id)
	return item and (item:GetAttribute("Count") or 0) or 0
end

-- Puts an item into quick slot 1-10 (nil clears it); one item per slot. This is
-- the starting order of the quick bar; the client then keeps recent picks first.
function OceanInventory.setHotbar(player: Player, id: string, slot: number?)
	local folder = OceanInventory.folder(player)
	local item = folder:FindFirstChild(id)
	if not item then return end
	if slot ~= nil then
		slot = math.floor(slot)
		assert(slot >= 1 and slot <= OceanInventory.HotbarSlots, "Hotbar slot must be 1-10")
		for _, other in folder:GetChildren() do
			if other ~= item and other:GetAttribute("HotbarSlot") == slot then
				other:SetAttribute("HotbarSlot", nil)
			end
		end
	end
	item:SetAttribute("HotbarSlot", slot)
end

return OceanInventory
