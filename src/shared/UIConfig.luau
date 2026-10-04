--!strict
-- Menu content you can edit without touching the UI code.
-- Image/audio values take uploaded asset IDs ("rbxassetid://..."); "" = not set.

return {
	GAME_NAME = "THE ZONE",
	LOGO_IMAGE = "", -- assets/title/logo.png
	LOGO_ASPECT = 1024 / 335,
	DEPLOY_IMAGE = "", -- art on the lobby deploy card
	MAP_IMAGE = "", -- map tab
	MENU_MUSIC_ID = "",
	CLICK_SOUND_ID = "",
	BUILD = "BUILD 0.1",

	MODES = {
		{
			name = "WARFARE",
			title = "THE ZONE",
			description = "The full PvEvP experience. Everyone you meet can be a potential ally or a deadly threat.",
		},
		{
			name = "JOINT OPS",
			title = "JOINT OPERATIONS",
			description = "Co-operative PvE. Team up, take contracts and push into the zone together.",
		},
	},

	REGIONS = { "EUROPE WEST", "EUROPE EAST", "NORTH AMERICA", "SOUTH AMERICA", "ASIA", "OCEANIA" },

	NEWS = {
		title = "LIVE UPDATE",
		summary = "Stay ahead in the ever-evolving zone. Here you'll find real-time insights, hotfixes, patch notes and server status.",
		body = "BUILD 0.1\n\n• New main menu, character and vendor screens\n• Grid inventory with drag and drop, rotation (R) and quick move (double-click)\n• ACS weapons equip straight from your Primary, Secondary and Sidearm slots\n• Vendors and tasks\n• Hydration and energy now drain over time",
	},

	CREDITS = "THE ZONE\n\nWeapon system: ACS (Advanced Combat System) by 00scorpion00\n\nThanks for playing.",
}
