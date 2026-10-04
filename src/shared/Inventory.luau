--!strict
-- Inventory rules shared by the server (which enforces them) and the client
-- (which uses them to preview drops). Positions are 0-based grid cells.

local ItemDefs = require(script.Parent.ItemDefs)

export type ItemInst = {
	uid: string,
	id: string,
	count: number,
	at: string, -- container name, or "slot:<SlotName>"
	x: number,
	y: number,
	rot: boolean,
}

export type State = {
	money: number,
	items: { [string]: ItemInst },
	[string]: any,
}

local Inventory = {}

Inventory.SLOTS = { "Helmet", "Headset", "Primary", "Secondary", "Sidearm", "Vest", "Backpack", "Belt" }
Inventory.WEAPON_SLOTS = { "Primary", "Secondary", "Sidearm" }

-- Containers that come from an equipped carrier
Inventory.CARRIERS = { vest = "Vest", backpack = "Backpack", belt = "Belt" }

Inventory.LOCKER = { w = 16, h = 24 }
Inventory.POCKETS = { w = 4, h = 1 }

-- Where quick-moves look for room, in order
Inventory.QUICK_ORDER = { "pockets", "belt", "vest", "backpack", "locker" }

function Inventory.slotOf(at: string): string?
	if string.sub(at, 1, 5) == "slot:" then
		return string.sub(at, 6)
	end
	return nil
end

function Inventory.containerForSlot(slot: string): string?
	for container, s in Inventory.CARRIERS do
		if s == slot then
			return container
		end
	end
	return nil
end

function Inventory.slotItem(state: State, slot: string): ItemInst?
	local at = "slot:" .. slot
	for _, item in state.items do
		if item.at == at then
			return item
		end
	end
	return nil
end

function Inventory.containerSize(state: State, container: string): (number?, number?)
	if container == "locker" then
		return Inventory.LOCKER.w, Inventory.LOCKER.h
	elseif container == "pockets" then
		return Inventory.POCKETS.w, Inventory.POCKETS.h
	end
	local slot = Inventory.CARRIERS[container]
	if not slot then
		return nil, nil
	end
	local carrier = Inventory.slotItem(state, slot)
	local def = carrier and ItemDefs[carrier.id]
	if def and def.grid then
		return def.grid.w, def.grid.h
	end
	return nil, nil
end

function Inventory.footprint(def: ItemDefs.ItemDef, rot: boolean): (number, number)
	if rot then
		return def.h, def.w
	end
	return def.w, def.h
end

function Inventory.itemsIn(state: State, container: string): { ItemInst }
	local list = {}
	for _, item in state.items do
		if item.at == container then
			table.insert(list, item)
		end
	end
	return list
end

function Inventory.isEmpty(state: State, container: string): boolean
	for _, item in state.items do
		if item.at == container then
			return false
		end
	end
	return true
end

-- Item covering cell (x, y) in a container, if any.
function Inventory.itemAt(state: State, container: string, x: number, y: number, ignoreUid: string?): ItemInst?
	for _, item in state.items do
		if item.at == container and item.uid ~= ignoreUid then
			local def = ItemDefs[item.id]
			if def then
				local w, h = Inventory.footprint(def, item.rot)
				if x >= item.x and x < item.x + w and y >= item.y and y < item.y + h then
					return item
				end
			end
		end
	end
	return nil
end

function Inventory.fits(
	state: State,
	container: string,
	w: number,
	h: number,
	x: number,
	y: number,
	ignoreUid: string?
): boolean
	local gw, gh = Inventory.containerSize(state, container)
	if not gw or not gh then
		return false
	end
	if x < 0 or y < 0 or x + w > gw or y + h > gh then
		return false
	end
	for _, item in state.items do
		if item.at == container and item.uid ~= ignoreUid then
			local def = ItemDefs[item.id]
			if def then
				local iw, ih = Inventory.footprint(def, item.rot)
				if x < item.x + iw and item.x < x + w and y < item.y + ih and item.y < y + h then
					return false
				end
			end
		end
	end
	return true
end

-- First free spot for an item, trying upright then rotated.
function Inventory.findSpace(
	state: State,
	container: string,
	def: ItemDefs.ItemDef,
	ignoreUid: string?
): (number?, number?, boolean?)
	local gw, gh = Inventory.containerSize(state, container)
	if not gw or not gh then
		return nil, nil, nil
	end
	for _, rot in { false, true } do
		local w, h = Inventory.footprint(def, rot)
		for y = 0, gh - h do
			for x = 0, gw - w do
				if Inventory.fits(state, container, w, h, x, y, ignoreUid) then
					return x, y, rot
				end
			end
		end
	end
	return nil, nil, nil
end

function Inventory.canEquip(def: ItemDefs.ItemDef, slot: string): boolean
	return def.slots ~= nil and table.find(def.slots, slot) ~= nil
end

function Inventory.isConsumable(def: ItemDefs.ItemDef): boolean
	return (def.heal or def.hydration or def.energy) ~= nil
end

function Inventory.totalWeight(state: State): number
	local total = 0
	for _, item in state.items do
		if item.at ~= "locker" then
			local def = ItemDefs[item.id]
			if def then
				total += def.weight * item.count
			end
		end
	end
	return total
end

return Inventory
