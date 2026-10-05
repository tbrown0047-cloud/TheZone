# THE ZONE: handoff for Claude Code with Roblox Studio MCP

You're continuing work on a Roblox game with Studio open over MCP. This note
summarises an earlier cloud session that couldn't see Studio and worked from
exported files. Check everything below against the live place before acting
on it.

> The `src/` folder in this repo (TheZone on GitHub) is **not** the game in
> Studio. It's a separate menu/inventory system built earlier in that session
> and never adopted. Don't copy it into the place or mix the two.

## Ground rules

- **Never run the `Zone23` installer again.** On every run it permanently deletes
  every key in the DataStores `PlayerProfile_v1`, `FactionChoice_v1` and
  `CharacterLook_v1`.
- Before editing a script, clone it into **ServerStorage** as
  `<Name>_bk_Before<Change>` (Disabled), the way earlier patches did.
- Ask the user before large rewrites. They have had several menu versions and
  care which one they get.
- Don't round-trip script source through a text editor. A Windows-1252 export
  already turned `▲ ◆ ° ¬` into `?`. Edit in Studio (via MCP) or use
  `ScriptEditorService:UpdateSourceAsync`.

## How the game is built

| Where | What |
|---|---|
| `StarterPlayer.StarterPlayerScripts.InventoryUI` (LocalScript, ~16,600 lines) | Almost all client UI: inventory, HUD, main menu, faction picker, character customiser, settings/controls, vendors |
| `ServerScriptService.InventoryDrops` | Loot, matchmaking, `shared.WearDress` / `MakeLootBody` / `ACSHit` |
| `ServerScriptService.AIServer` + `ServerStorage.AIConfig` | R15 AI combatants |
| `ServerScriptService.ProfileServer` | Saves (`PlayerProfile_v2` since Zone23) |
| `ReplicatedFirst.LoadingScreen`, `ReplicatedStorage.ZoneLogo` | Loading screen, logo module |
| ACS 2.0.1, R15 version ("Dogu15") | Guns. `ReplicatedStorage.ACS_Engine` (GunModels/Server, ServerConfigs.Config), gun Tools in `ServerStorage.ACS_Tools` |

Characters are **R15**.

## Patch history (InventoryUI)

The user applied "ZoneNN" installers (ModuleScripts run from the Command Bar)
made in other chats. Each one cloned the previous script to
`ServerStorage.InventoryUI_bk_BeforeZoneNN` first.

1. **Zone22**: polished the **Battlefield 6 ("B6") main menu**: a "THE ZONE >" logo
   in a see-through top bar, clicking a mode in the list starts matchmaking (no
   mode card or START button), a single team control. Added as a block
   headed `polish: one logo that can't overlap...`, using `B6.*` / `BF.*` tables.
2. **Zone23**: replaced the whole menu with a **Gray Zone Warfare layout**
   (`GRAY ZONE LOOK` section, `G.*` table) in Battlefield 6 colours. Also
   replaced `LoadingScreen`, `AIServer`, `AIConfig` and `InventoryDrops`, added
   `ZoneLogo`, and **wiped the saves** (see ground rules). After this, no `B6.`
   code remains.
3. **Zone29**: recoloured to Battlefield 2042 (navy + teal), centred the logo,
   removed the gun from the menu soldier, "CHARACTER" became "OPERATOR", and
   rebuilt the faction picker and customiser Gray Zone-style.
4. **Unknown later patch** (possibly one called `BFMenu2`): recoloured back to
   Battlefield 6 charcoal/white, logo top left again, and added a guard so
   CONTINUE can't save twice (`G.contDone`).

**Live state today:** Zone29's structure, Battlefield 6 colours, logo left,
menu soldier unarmed, "OPERATOR" wording.

Expected backups in ServerStorage: `InventoryUI_bk_BeforeZone22`,
`InventoryUI_bk_BeforeZone23` (the **Zone22 version**, with the full B6
menu), `InventoryUI_bk_BeforeZone29`, plus backups of the other scripts
Zone23 replaced. Check they exist.

## To do

### 1. Bring back Zone22's main menu (the user's choice)
- Source: `ServerStorage.InventoryUI_bk_BeforeZone23`.
- Goal: keep the current InventoryUI (inventory, HUD and every fix since
  Zone22) and swap **only the main menu** back to Zone22's B6 menu with the
  Zone22 polish.
- In the current script the menu lives roughly between
  `-- GRAY ZONE LOOK: the main menu laid out like Gray Zone Warfare's` and
  `-- loading: the world blurred behind a spinning circle, nothing else`. That
  range also contains the faction picker, customiser, first-join flow and
  in-game menu (`BACK MAP CHARACTER VENDORS TASKS SETTINGS`).
- First compare the two versions and work out how the B6 menu hooks into
  shared pieces (`M.*`, `BF.*`, deploy/matchmaking, first join). Then tell the
  user what carries over cleanly and ask whether to keep Zone29's newer
  faction picker and customiser.

### 2. Crouch + move backwards flings the player
- **InventoryUI is ruled out.** It only sets `Humanoid.WalkSpeed` (in
  `applyWalkSpeed`, reading the `StanceSpeed` attribute ACS sets) and applies
  no forces.
- Look at the ACS stance code and the **Dogu15 R15 conversion**. Likely cause:
  crouch changes HipHeight or the root joint so the body clips the ground when
  moving back.

### 3. AI bots don't equip guns
- `AIServer` → `AI.equip(bot, toolName)` builds its own R15 gun rig: AnimBase,
  Fake arms, Motor6Ds, and a gun model `S<name>` parented to the bot.
- It needs `ServerStorage.ACS_Tools[toolName]` and
  `ACS_Engine.GunModels.Server[toolName]` (with a `Grip`). First check Output
  for `[AI] no ACS tool / server model for ...`.
- The user believes **Dogu15** interferes. Bots are easy to exclude: each bot
  model has the attribute `AI = true` (set before parenting) and lives in
  `workspace.AI`. Make Dogu15 apply only to player characters
  (`Players:GetPlayerFromCharacter(model)`), or skip models with `AI` set.

### Superseded
- A "Zone30" (gun back on the menu soldier + CHARACTER wording) was prepared
  and is **not** installed. Drop it: the user wants Zone22's menu instead.
