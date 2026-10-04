--!strict
-- Everything specific to the gun system lives here. Set up for ACS 2.0.1;
-- if your copy names things differently, change them here and nothing else.

return {
	SYSTEM_NAME = "ACS",

	-- ServerStorage folder holding the gun Tools the inventory hands out.
	-- Move ACS's gun Tools here from StarterPack.
	TOOLS_FOLDER = "Weapons",

	-- ReplicatedStorage paths searched for a gun's model (by Tool name) to draw
	-- its inventory icon. If none match, equipped guns are drawn from the Tool.
	MODEL_FOLDERS = {
		{ "ACS_Engine", "GunModels" },
		{ "SPH_Assets", "WeaponModels" },
	},

	-- Settings module inside each gun Tool (read for the inspect panel and the
	-- HUD ammo counter).
	STATS_MODULES = { "ACS_Settings", "WeaponStats" },

	-- Inspect panel rows: { field in the settings module, label }. Fields that
	-- aren't present are skipped; if none match, every simple field is listed.
	STAT_FIELDS = {
		{ "gunName", "Name" },
		{ "Type", "Type" },
		{ "Ammo", "Magazine" },
		{ "StoredAmmo", "Reserve" },
		{ "MaxStoredAmmo", "Max reserve" },
		{ "ShootRate", "Fire rate (rpm)" },
		{ "Bullets", "Projectiles" },
		{ "BulletSpeed", "Muzzle velocity" },
		{ "MuzzleVelocity", "Muzzle velocity" },
		{ "HeadDamage", "Head damage" },
		{ "TorsoDamage", "Torso damage" },
		{ "LimbDamage", "Limb damage" },
		{ "LimbsDamage", "Limb damage" },
		{ "Distance", "Range" },
		{ "camRecoil", "Camera recoil" },
		{ "gunRecoil", "Gun recoil" },
	},

	-- HUD ammo counter. Checked as attributes / Value objects on the equipped
	-- Tool first, then as fields of its settings module (ACS keeps the live
	-- count there on the client).
	SHOW_HUD_AMMO = true, -- set false to rely on ACS's own ammo HUD instead
	AMMO_KEYS = { "AmmoInGun", "CurrentAmmo", "MagAmmo" },
	RESERVE_KEYS = { "StoredAmmo", "ReserveAmmo", "SpareAmmo" },
	FIREMODE_KEYS = { "FireMode", "Firemode" },
}
