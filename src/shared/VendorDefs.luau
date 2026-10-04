--!strict
-- Vendors, what they sell, and the tasks they hand out.
-- `count` is how many units one purchase gives (ammo comes in boxes).

export type StockEntry = { item: string, price: number, count: number? }
export type Task = {
	id: string,
	title: string,
	text: string,
	objectives: { string },
	reward: string,
}
export type Vendor = {
	id: string,
	name: string,
	role: string,
	description: string,
	stock: { StockEntry },
	tasks: { Task },
}

local vendors: { Vendor } = {
	{
		id = "gunny",
		name = "GUNNY",
		role = "ARMS DEALER",
		description = "Former armourer turned supplier. Trades in rifles, sidearms and the rounds to feed them. Doesn't ask where you're going with them.",
		stock = {
			{ item = "M4A1", price = 4600 },
			{ item = "AKM", price = 3400 },
			{ item = "Mosin", price = 2000 },
			{ item = "G17", price = 1000 },
			{ item = "Ammo556", price = 190, count = 60 },
			{ item = "Ammo762", price = 180, count = 60 },
			{ item = "Ammo762R", price = 210, count = 40 },
			{ item = "Ammo9", price = 100, count = 50 },
		},
		tasks = {
			{
				id = "cache_retrieval",
				title = "CACHE RETRIEVAL",
				text = "So, you're one of the new recruits, huh? We've got a problem: a supply cache went dark two days ago, somewhere past the old pumping station. Find it, see what's left, and bring back proof it's still ours.",
				objectives = {
					"Find and mark the cache in one of the town's basements",
					"Find and mark the cache in a shed at the town's landmark",
				},
				reward = "$ 2,500  ·  GUNNY STANDING +0.05",
			},
			{
				id = "zeroing_in",
				title = "ZEROING IN",
				text = "Before I trust you with anything expensive, show me you can hit what you aim at.",
				objectives = { "Eliminate 5 hostiles with a rifle" },
				reward = "$ 1,200  ·  60x SP 5.56",
			},
		},
	},
	{
		id = "doc",
		name = "DOC",
		role = "FIELD MEDIC",
		description = "Runs the aid station out of a shipping container. Medical supplies, food and water, at prices that reflect the situation.",
		stock = {
			{ item = "Bandage", price = 70, count = 4 },
			{ item = "Splint", price = 100, count = 5 },
			{ item = "Ibalin", price = 140, count = 4 },
			{ item = "SurgKit", price = 700 },
			{ item = "Water", price = 90 },
			{ item = "Soda", price = 60 },
			{ item = "Wafers", price = 50 },
			{ item = "Ration", price = 240 },
		},
		tasks = {
			{
				id = "supply_run",
				title = "SUPPLY RUN",
				text = "The clinic in the valley never got its last delivery. If anything's still on the shelves, I want it here, not in some scavenger's pack.",
				objectives = { "Recover 2 Surgical Kits from the valley clinic", "Hand them over to Doc" },
				reward = "$ 1,800  ·  DOC STANDING +0.05",
			},
		},
	},
	{
		id = "quartermaster",
		name = "QUARTERMASTER",
		role = "EQUIPMENT",
		description = "Keeps the base kitted out. Armour, carriers and packs, plus the odd bit of electronics.",
		stock = {
			{ item = "Helmet", price = 1700 },
			{ item = "Headset", price = 800 },
			{ item = "Vest", price = 2700 },
			{ item = "Backpack", price = 1800 },
			{ item = "Tourist", price = 2300 },
			{ item = "Belt", price = 500 },
			{ item = "Tracker", price = 350 },
		},
		tasks = {
			{
				id = "signal_check",
				title = "SIGNAL CHECK",
				text = "Our relay on the ridge stopped reporting. Take a tracker up there and tell me whether it's the hardware or someone who doesn't want us listening.",
				objectives = { "Place a GPS Tracker at the ridge relay", "Survive and extract" },
				reward = "$ 2,000  ·  TOURIST BACKPACK",
			},
		},
	},
}

return vendors
