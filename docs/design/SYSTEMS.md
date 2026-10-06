# The Zone: Systems Lists

Two lists: core systems (the game does not work without them), then polish and expansion. Written first for the extraction concept, then adapted for the chosen persistent, wipe-based design (section 3).

Rule of thumb: nothing in List 2 matters until List 1 works end to end.

## 1. List 1: Core systems

**Player and combat**
1. Character controller (move, sprint, crouch, vault, stamina)
2. Camera and aiming
3. Weapons (firing, recoil, reload, ammo types)
4. Damage model (health, armor, hit zones, healing, death)
5. Equipment and throwables

**Enemies**
6. AI framework (perception, pathfinding, state or behavior logic)
7. Machine enemy types (light, heavy, flyer, turret, boss)
8. AI performance budgeting (spawn, despawn, activation limits)

**World and structure**
9. Map and level (collision, cover, verticality, streaming)
10. Spawn logic and spawn protection
11. Dynamic events (supply drops, machine surges, bosses)

**Loot and items**
12. Item database (types, rarity, stats, weight)
13. Loot tables and spawners
14. Inventory (slots or grid, weight, equipment slots)
15. Death and loss rules

**Economy and progression**
16. Stash or storage
17. Crafting and workbenches
18. Traders and currency
19. Basic progression
20. Quests and contracts

**Multiplayer**
21. Squads and parties
22. Server management and failure recovery
23. Replication and server-authoritative logic

**Data and backend**
24. Player data persistence
25. Save safety (atomic saves, versioning, anti-duplication)
26. Remote config

**Interface**
27. HUD
28. Core menus (inventory, crafting, map, quests, settings)
29. Input handling (keyboard and mouse, gamepad, touch, rebinding)

**Security**
30. Server-side validation of movement, damage and item use
31. Rate limiting and exploit detection
32. Moderation and reporting tools

**Launch foundation**
33. Tutorial and onboarding
34. Basic audio
35. Basic analytics and crash tracking

## 2. List 2: Polish and expansion

**Depth:** weapon customization, skill trees and perks, additional machine types and bosses, more maps and variants, advanced crafting and salvage, player trading with abuse protection, difficulty scaling.

**Social:** friends and presence, proximity or voice chat where permitted, ping system, leaderboards, spectating and revive or downed state, emotes.

**Presentation:** animation polish, VFX polish, lighting, weather and time of day, audio polish (occlusion, dynamic music), art direction pass, lore delivery (audio logs, environmental storytelling).

**Quality of life:** accessibility (colorblind modes, text scaling, subtitles), aim assist and touch control tuning, HUD customization, death recap and stats, achievements and titles.

**Monetization and retention:** cosmetic store, battle pass and seasons, limited-time events, daily and weekly challenges, premium currency flow.

**Live operations:** advanced analytics and balance telemetry, economy dashboards, anti-cheat refinement, update pipeline (staging, rollout, rollback), support tooling (item restoration, bug reports), community channels and public roadmap.

**Platform and performance:** optimization (LODs, pooling, network), console and mobile optimization, localization.

## 3. Changes for the persistent, wipe-based design

**New or heavier than extraction:**
- Base building (pieces, material tiers, placement validation, piece caps)
- Raiding rules (structure damage, offline protection, raid windows, decay)
- World persistence (base and structure saving per wipe, world state reset)
- Wipe cycle management (timers, resets, carried-over rewards, wipe-day events)
- Survival layer (hunger, thirst, exposure, kept light)
- Resource nodes and respawning world loot
- Territory and map control (danger tiers, machine nests, incursions on bases)
- Large-world streaming and server population limits

**Lighter than extraction:** matchmaking and raid lifecycle, extraction points (the pressure concept becomes the late-wipe event).

**Build order:**
1. Foundation: movement, shooting, damage, one machine type
2. World slice: one map section with resource nodes, loot, machine spawns
3. Survival and crafting
4. Base building with saving and loading
5. Raiding and protection rules
6. Machines and tech tiers
7. Wipe system
8. Multiplayer hardening (server population, anti-cheat, security)
9. Polish and live ops
