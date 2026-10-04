--!strict
-- Server-authoritative inventory. Owns every player's items, money, vitals and
-- settings, validates every client request, saves to a DataStore, and turns
-- guns in the Primary / Secondary / Sidearm slots into gun Tools (ACS; see
-- Shared.WeaponConfig).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPack = game:GetService("StarterPack")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Inventory = require(Shared:WaitForChild("Inventory"))
local ItemDefs = require(Shared:WaitForChild("ItemDefs"))
local VendorDefs = require(Shared:WaitForChild("VendorDefs"))
local WeaponConfig = require(Shared:WaitForChild("WeaponConfig"))

type ItemInst = Inventory.ItemInst
type Data = {
	version: number,
	money: number,
	items: { [string]: ItemInst },
	vitals: { hydration: number, energy: number },
	tasks: { [string]: string },
	settings: { [string]: any },
}

local DATASTORE_NAME = "TheZoneProfile_v1"
local AUTOSAVE_INTERVAL = 120
local VITALS_TICK = 10
local HYDRATION_DRAIN = 0.35 -- per tick
local ENERGY_DRAIN = 0.25
local STARVING_DAMAGE = 1 -- per tick at 0 hydration or energy
local SELL_RATE = 0.5
local ACTION_COOLDOWN = 0.05

local InventoryService = {}

local profiles: { [Player]: Data } = {}
local lastAction: { [Player]: number } = {}
local store: DataStore? = nil
local warnedNoStore = false
local warnedMissingTool: { [string]: boolean } = {}
local statsCache: { [string]: { { string } } } = {}

-- Tool names of every gun the inventory manages
local inventoryToolNames: { [string]: boolean } = {}
for _, def in ItemDefs do
	if def.tool then
		inventoryToolNames[def.tool] = true
	end
end

--------------------------------------------------------------------------------
-- Data helpers
--------------------------------------------------------------------------------

local function newUid(): string
	return string.sub(HttpService:GenerateGUID(false), 1, 13)
end

local function addItem(data: Data, id: string, count: number, at: string?): ItemInst?
	local def = ItemDefs[id]
	if not def then
		return nil
	end
	local item: ItemInst = { uid = newUid(), id = id, count = count, at = "locker", x = 0, y = 0, rot = false }

	if at and Inventory.slotOf(at) then
		item.at = at
		data.items[item.uid] = item
		return item
	end

	local order = if at then { at } else { "locker" }
	for _, container in order do
		local x, y, rot = Inventory.findSpace(data, container, def)
		if x and y then
			item.at, item.x, item.y, item.rot = container, x, y, rot or false
			data.items[item.uid] = item
			return item
		end
	end
	return nil
end

local function starterData(): Data
	local data: Data = {
		version = 1,
		money = 10245,
		items = {},
		vitals = { hydration = 100, energy = 100 },
		tasks = {},
		settings = {},
	}
	-- Carriers first, so their grids exist for the items below
	addItem(data, "Vest", 1, "slot:Vest")
	addItem(data, "Backpack", 1, "slot:Backpack")
	addItem(data, "Belt", 1, "slot:Belt")
	addItem(data, "Helmet", 1, "slot:Helmet")
	addItem(data, "M4A1", 1, "slot:Primary")
	addItem(data, "G17", 1, "slot:Sidearm")

	addItem(data, "Ammo556", 60, "vest")
	addItem(data, "Ammo556", 60, "vest")
	addItem(data, "Bandage", 4, "vest")
	addItem(data, "Ammo9", 50, "belt")
	addItem(data, "Water", 1, "backpack")
	addItem(data, "Ration", 1, "backpack")
	addItem(data, "Ibalin", 4, "pockets")
	addItem(data, "Tracker", 1, "pockets")

	addItem(data, "AKM", 1)
	addItem(data, "Mosin", 1)
	addItem(data, "Ammo762", 60)
	addItem(data, "Ammo762", 60)
	addItem(data, "Ammo762R", 40)
	addItem(data, "Headset", 1)
	addItem(data, "Tourist", 1)
	addItem(data, "SurgKit", 1)
	addItem(data, "Splint", 5)
	addItem(data, "Water", 1)
	addItem(data, "Soda", 1)
	addItem(data, "Wafers", 1)
	addItem(data, "Wafers", 1)
	return data
end

-- Drop anything that no longer has a definition (e.g. an item you removed).
local function sanitize(data: Data)
	for uid, item in data.items do
		if not ItemDefs[item.id] then
			data.items[uid] = nil
		end
	end
	data.vitals = data.vitals or { hydration = 100, energy = 100 }
	data.tasks = data.tasks or {}
	data.settings = data.settings or {}
end

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok then
		store = result
		return store
	end
	if not warnedNoStore then
		warnedNoStore = true
		warn("[Inventory] DataStores unavailable; progress will not save this session:", result)
	end
	return nil
end

local function load(player: Player): Data
	local ds = getStore()
	if ds then
		local ok, saved = pcall(function()
			return ds:GetAsync("player_" .. player.UserId)
		end)
		if ok and type(saved) == "table" then
			local data = saved :: Data
			sanitize(data)
			return data
		elseif not ok and not warnedNoStore then
			warnedNoStore = true
			warn("[Inventory] Could not load data (enable Studio API access to test saving):", saved)
		end
	end
	return starterData()
end

local function save(player: Player)
	local data = profiles[player]
	local ds = getStore()
	if not data or not ds then
		return
	end
	local ok, err = pcall(function()
		ds:SetAsync("player_" .. player.UserId, data)
	end)
	if not ok then
		warn("[Inventory] Save failed for", player.Name, err)
	end
end

--------------------------------------------------------------------------------
-- Gun tools (ACS)
--------------------------------------------------------------------------------

local function findToolTemplate(name: string): Tool?
	local weapons = ServerStorage:FindFirstChild(WeaponConfig.TOOLS_FOLDER)
	local tool = weapons and weapons:FindFirstChild(name)
	if not tool then
		tool = StarterPack:FindFirstChild(name)
	end
	if tool and tool:IsA("Tool") then
		return tool
	end
	if not warnedMissingTool[name] then
		warnedMissingTool[name] = true
		warn(`[Inventory] No {WeaponConfig.SYSTEM_NAME} Tool named "{name}" in ServerStorage.{WeaponConfig.TOOLS_FOLDER}; the gun will show in the inventory but can't be fired.`)
	end
	return nil
end

local function findTool(player: Player, uid: string): Tool?
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } :: { Instance? } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("ItemUid") == uid then
					return child
				end
			end
		end
	end
	return nil
end

-- Make the player's Tools match the guns in their weapon slots.
local function syncTools(player: Player)
	local data = profiles[player]
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not backpack then
		return
	end

	local wanted: { [string]: ItemInst } = {}
	for _, slot in Inventory.WEAPON_SLOTS do
		local item = Inventory.slotItem(data, slot)
		if item then
			wanted[item.uid] = item
		end
	end

	-- Remove tools for guns that left their slot, plus loose copies of
	-- inventory guns (e.g. handed out by StarterPack) the inventory didn't issue
	for _, container in { backpack, player.Character } :: { Instance? } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") then
					local uid = child:GetAttribute("ItemUid")
					if (type(uid) == "string" and not wanted[uid]) or (uid == nil and inventoryToolNames[child.Name]) then
						child:Destroy()
					end
				end
			end
		end
	end

	-- Give tools for newly equipped guns
	for uid, item in wanted do
		if not findTool(player, uid) then
			local def = ItemDefs[item.id]
			local template = def and def.tool and findToolTemplate(def.tool)
			if template then
				local tool = template:Clone()
				tool:SetAttribute("ItemUid", uid)
				tool:SetAttribute("ItemSlot", Inventory.slotOf(item.at))
				tool.CanBeDropped = false
				tool.Parent = backpack
			end
		end
	end
end

-- Turns a settings value into display text. Handles plain values and
-- {min, max} pairs (ACS stores some damage values that way).
local function formatStat(value: any): string?
	local kind = type(value)
	if kind == "number" then
		return string.format("%g", value)
	elseif kind == "string" or kind == "boolean" then
		return tostring(value)
	elseif kind == "table" and type(value[1]) == "number" and type(value[2]) == "number" and #value == 2 then
		return string.format("%g – %g", value[1], value[2])
	end
	return nil
end

-- Rows for the inspect panel from the gun's settings module (ACS_Settings).
-- Uses WeaponConfig.STAT_FIELDS when any of them exist, otherwise lists every
-- simple field.
local function weaponStats(toolName: string): { { string } }
	if statsCache[toolName] then
		return statsCache[toolName]
	end
	local rows = {}
	local template = findToolTemplate(toolName)
	local module: Instance? = nil
	for _, name in WeaponConfig.STATS_MODULES do
		module = module or (template and template:FindFirstChild(name, true))
	end
	if module and module:IsA("ModuleScript") then
		local ok, stats = pcall(require, module)
		if ok and type(stats) == "table" then
			local seenLabels = {}
			for _, field in WeaponConfig.STAT_FIELDS do
				local text = formatStat((stats :: any)[field[1]])
				if text and not seenLabels[field[2]] then
					seenLabels[field[2]] = true
					table.insert(rows, { field[2], text })
				end
			end
			if #rows == 0 then
				for key, value in stats :: { [any]: any } do
					local text = formatStat(value)
					if type(key) == "string" and text then
						table.insert(rows, { key, text })
					end
				end
				table.sort(rows, function(a, b)
					return a[1] < b[1]
				end)
			end
		end
	end
	statsCache[toolName] = rows
	return rows
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

local function removeItem(data: Data, item: ItemInst, count: number?)
	local n = count or item.count
	item.count -= n
	if item.count <= 0 then
		data.items[item.uid] = nil
	end
end

-- An equipped carrier can only leave its slot when empty.
local function canLeaveSlot(data: Data, item: ItemInst): (boolean, string?)
	local slot = Inventory.slotOf(item.at)
	local container = slot and Inventory.containerForSlot(slot)
	if container and not Inventory.isEmpty(data, container) then
		return false, "Empty the " .. ItemDefs[item.id].name .. " first"
	end
	return true, nil
end

local function moveItem(data: Data, item: ItemInst, to: string, x: number, y: number, rot: boolean): (boolean, string?)
	local def = ItemDefs[item.id]
	local toSlot = Inventory.slotOf(to)

	if item.at == to and (toSlot or (item.x == x and item.y == y and item.rot == rot)) then
		return true, nil
	end

	local ok, err = canLeaveSlot(data, item)
	if not ok then
		return false, err
	end

	if toSlot then
		if not table.find(Inventory.SLOTS, toSlot) or not Inventory.canEquip(def, toSlot) then
			return false, "Can't equip that there"
		end
		if Inventory.slotItem(data, toSlot) then
			return false, "Slot is occupied"
		end
		item.at, item.x, item.y, item.rot = to, 0, 0, false
		return true, nil
	end

	local fromSlot = Inventory.slotOf(item.at)
	if fromSlot and Inventory.containerForSlot(fromSlot) == to then
		return false, "Can't put that inside itself"
	end
	if not Inventory.containerSize(data, to) then
		return false, "Nowhere to put that"
	end

	-- Dropping onto the same stackable item merges the stacks
	local target = Inventory.itemAt(data, to, x, y, item.uid)
	local maxStack = def.stack or 1
	if target and target.id == item.id and maxStack > 1 then
		local moved = math.min(item.count, maxStack - target.count)
		if moved <= 0 then
			return false, "Stack is full"
		end
		target.count += moved
		removeItem(data, item, moved)
		return true, nil
	end

	local w, h = Inventory.footprint(def, rot)
	if not Inventory.fits(data, to, w, h, x, y, item.uid) then
		return false, "No room there"
	end
	item.at, item.x, item.y, item.rot = to, x, y, rot
	return true, nil
end

local function quickMove(data: Data, item: ItemInst): (boolean, string?)
	local def = ItemDefs[item.id]
	local fromSlot = Inventory.slotOf(item.at)

	-- Unequip into the first container with room
	if fromSlot then
		local ok, err = canLeaveSlot(data, item)
		if not ok then
			return false, err
		end
		local own = Inventory.containerForSlot(fromSlot)
		for _, container in Inventory.QUICK_ORDER do
			if container ~= own then
				local x, y, rot = Inventory.findSpace(data, container, def, item.uid)
				if x and y then
					return moveItem(data, item, container, x, y, rot or false)
				end
			end
		end
		return false, "No room to unequip"
	end

	-- Equip into the first free matching slot
	if def.slots then
		for _, slot in def.slots do
			if not Inventory.slotItem(data, slot) then
				return moveItem(data, item, "slot:" .. slot, 0, 0, false)
			end
		end
	end

	-- Otherwise shuttle between the locker and your carriers
	local order = if item.at == "locker" then { "pockets", "belt", "vest", "backpack" } else { "locker" }
	for _, container in order do
		local x, y, rot = Inventory.findSpace(data, container, def, item.uid)
		if x and y then
			return moveItem(data, item, container, x, y, rot or false)
		end
	end
	return false, "No room"
end

local function useItem(player: Player, data: Data, item: ItemInst): (boolean, string?)
	local def = ItemDefs[item.id]
	if not Inventory.isConsumable(def) then
		return false, "Can't use that"
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if def.heal then
		if not humanoid or humanoid.Health <= 0 then
			return false, "You need to be alive"
		end
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + def.heal)
	end
	if def.hydration then
		data.vitals.hydration = math.min(100, data.vitals.hydration + def.hydration)
	end
	if def.energy then
		data.vitals.energy = math.min(100, data.vitals.energy + def.energy)
	end
	removeItem(data, item, 1)
	return true, nil
end

local function findStock(vendorId: string, itemId: string): VendorDefs.StockEntry?
	for _, vendor in VendorDefs do
		if vendor.id == vendorId then
			for _, entry in vendor.stock do
				if entry.item == itemId then
					return entry
				end
			end
		end
	end
	return nil
end

local function findTask(taskId: string): VendorDefs.Task?
	for _, vendor in VendorDefs do
		for _, task in vendor.tasks do
			if task.id == taskId then
				return task
			end
		end
	end
	return nil
end

local function deploy(player: Player)
	local spawns = workspace:FindFirstChild("DeploySpawns")
	local character = player.Character
	if not spawns or not character then
		return
	end
	local points = {}
	for _, child in spawns:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(points, child)
		end
	end
	if #points > 0 then
		local point = points[math.random(1, #points)]
		character:PivotTo(point.CFrame + Vector3.new(0, 3, 0))
	end
end

-- Every handler returns (ok, message?, extra?). Arguments come straight from
-- the client, so each one is type-checked before use.
local handlers: { [string]: (Player, Data, ...any) -> (boolean, string?, any) } = {
	move = function(_player, data, uid, to, x, y, rot)
		if type(uid) ~= "string" or type(to) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then
			return false, "Bad request"
		end
		local item = data.items[uid]
		if not item then
			return false, "Item not found"
		end
		return moveItem(data, item, to, math.floor(x), math.floor(y), rot == true)
	end,

	quick = function(_player, data, uid)
		local item = type(uid) == "string" and data.items[uid]
		if not item then
			return false, "Item not found"
		end
		return quickMove(data, item)
	end,

	use = function(player, data, uid)
		local item = type(uid) == "string" and data.items[uid]
		if not item then
			return false, "Item not found"
		end
		return useItem(player, data, item)
	end,

	discard = function(_player, data, uid)
		local item = type(uid) == "string" and data.items[uid]
		if not item then
			return false, "Item not found"
		end
		local ok, err = canLeaveSlot(data, item)
		if not ok then
			return false, err
		end
		removeItem(data, item)
		return true, nil
	end,

	sell = function(_player, data, uid)
		local item = type(uid) == "string" and data.items[uid]
		if not item then
			return false, "Item not found"
		end
		local ok, err = canLeaveSlot(data, item)
		if not ok then
			return false, err
		end
		local earned = math.floor(ItemDefs[item.id].value * item.count * SELL_RATE)
		data.money += earned
		removeItem(data, item)
		return true, nil, earned
	end,

	buy = function(_player, data, vendorId, itemId)
		if type(vendorId) ~= "string" or type(itemId) ~= "string" then
			return false, "Bad request"
		end
		local entry = findStock(vendorId, itemId)
		if not entry then
			return false, "Not for sale"
		end
		if data.money < entry.price then
			return false, "Not enough money"
		end
		if not addItem(data, entry.item, entry.count or 1) then
			return false, "No room in your locker"
		end
		data.money -= entry.price
		return true, nil
	end,

	acceptTask = function(_player, data, taskId)
		if type(taskId) ~= "string" or not findTask(taskId) then
			return false, "Unknown task"
		end
		data.tasks[taskId] = if data.tasks[taskId] == "ACTIVE" then nil else "ACTIVE"
		return true, nil
	end,

	inspect = function(_player, data, uid)
		local item = type(uid) == "string" and data.items[uid]
		if not item then
			return false, "Item not found"
		end
		local def = ItemDefs[item.id]
		return true, nil, if def.tool then weaponStats(def.tool) else {}
	end,

	saveSettings = function(_player, data, settings)
		if type(settings) ~= "table" then
			return false, "Bad request"
		end
		local clean = {}
		for key, value in settings do
			local kind = type(value)
			if type(key) == "string" and #key <= 32 and (kind == "number" or kind == "boolean" or kind == "string") then
				clean[key] = value
			end
		end
		data.settings = clean
		return true, nil
	end,

	deploy = function(player, _data)
		deploy(player)
		return true, nil
	end,

	wipe = function(player, data)
		local fresh = starterData()
		fresh.settings = data.settings
		profiles[player] = fresh
		return true, nil
	end,
}

-- Actions that don't change what the client sees
local READ_ONLY = { inspect = true, deploy = true }

--------------------------------------------------------------------------------
-- Wiring
--------------------------------------------------------------------------------

function InventoryService.Start()
	local remotes = Instance.new("Folder")
	remotes.Name = "InventoryRemotes"

	local getState = Instance.new("RemoteFunction")
	getState.Name = "GetState"
	getState.Parent = remotes

	local action = Instance.new("RemoteFunction")
	action.Name = "Action"
	action.Parent = remotes

	local stateEvent = Instance.new("RemoteEvent")
	stateEvent.Name = "State"
	stateEvent.Parent = remotes

	remotes.Parent = ReplicatedStorage

	local function push(player: Player)
		local data = profiles[player]
		if data then
			stateEvent:FireClient(player, data)
		end
	end

	local function waitForProfile(player: Player): Data?
		local started = os.clock()
		while not profiles[player] and player.Parent and os.clock() - started < 15 do
			task.wait(0.1)
		end
		return profiles[player]
	end

	getState.OnServerInvoke = function(player)
		return waitForProfile(player)
	end

	action.OnServerInvoke = function(player, name, ...)
		local data = profiles[player]
		local handler = type(name) == "string" and handlers[name]
		if not data or not handler then
			return false, "Unavailable"
		end
		local now = os.clock()
		if now - (lastAction[player] or 0) < ACTION_COOLDOWN then
			return false, "Slow down"
		end
		lastAction[player] = now

		local ok, success, message, extra = pcall(handler, player, data, ...)
		if not ok then
			warn("[Inventory] Action failed:", name, success)
			return false, "Something went wrong"
		end
		if success and not READ_ONLY[name] then
			syncTools(player)
			push(player)
		end
		return success, message, extra
	end

	local function onPlayerAdded(player: Player)
		profiles[player] = load(player)
		player.CharacterAdded:Connect(function()
			-- The Backpack is recreated on respawn; re-issue equipped guns.
			-- Run again shortly after, once StarterPack copies have arrived.
			task.defer(syncTools, player)
			task.delay(1, syncTools, player)
		end)
		if player.Character then
			task.defer(syncTools, player)
		end
		push(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
		lastAction[player] = nil
	end)

	game:BindToClose(function()
		for player in profiles do
			task.spawn(save, player)
		end
		task.wait(3)
	end)

	-- Autosave
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(save, player)
			end
		end
	end)

	-- Hydration and energy drain
	task.spawn(function()
		while true do
			task.wait(VITALS_TICK)
			for player, data in profiles do
				local vitals = data.vitals
				vitals.hydration = math.max(0, vitals.hydration - HYDRATION_DRAIN)
				vitals.energy = math.max(0, vitals.energy - ENERGY_DRAIN)
				if vitals.hydration <= 0 or vitals.energy <= 0 then
					local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid:TakeDamage(STARVING_DAMAGE)
					end
				end
				push(player)
			end
		end
	end)
end

return InventoryService
