# The Zone: Game Design Document (v0.2)

Persistent, wipe-based PvPvE survival on Roblox. Mature (16+) audience, free to play, live service.

Status: concept. Decisions and open questions are tracked at the bottom and in `DECISIONS_AND_RESEARCH.md`. System lists are in `SYSTEMS.md`.

## 1. Pitch
The Zone is a free-to-play, mature (16+) open-world survival shooter on Roblox. Squads scavenge a sealed, machine-ravaged district, build bases, and fight hostile machines and each other. Each server world runs a **wipe cycle**, so every cycle is a fresh race up the tech ladder.

The short version: ARC Raiders' machine-ravaged setting meets Rust's base building and wipes, on Roblox, for free.

## 2. Why us
- **Niche on Roblox:** research found no polished Roblox game combining persistent open world, base building and machine threats.
- **Platform advantage:** free, no install, friends already there, PC, console and mobile.
- **Clear hook:** machines are the main environmental threat, tech salvage drives progression, bases defend against machines as well as players.
- **Pace:** short wipe cycles fit Roblox habits better than season-long resets.
- **Open question:** off-platform games such as Once Human appear to cover similar ground. Status unverified, study before locking features.

## 3. Pillars
1. **Machines are the world.** They hold territory, hunt, and escalate.
2. **Your base is your story,** and it is worth defending.
3. **Every wipe is a fresh race,** with only cosmetics and account progress carried over.
4. **Easy to enter, hard to master.** The first hour must teach and protect.
5. **Always something new.** A predictable update cadence.

## 4. Setting
A walled district sealed after an automated-security failure. Corporate defense machines, maintenance units and rogue systems still operate. Players are contract scavengers and nobody is coming to rescue them.

**IP rule:** all names, designs, lore and assets are original. Nothing from ARC Raiders (Embark Studios) or any other property.

## 5. Core loop
Scavenge, build and defend, research and craft, hunt machines, contest territory and raid, wipe and restart.

## 6. Systems summary
Full lists live in `SYSTEMS.md`.

**Player and combat:** controller (sprint, crouch, vault, stamina), aiming, recoil, reload, armor and hit zones, healing, bleeding. Small launch weapon set with distinct roles, plus melee and throwables.

**Machines (PvE):**
- Launch archetypes: patrol, heavy, flyer, ambusher, turret, plus one boss.
- Perception-based AI with simple state machines, group behavior and server-side budgets.
- Territory: machines hold zones with danger tiers; nests guard top-tier components.
- Incursions: periodic machine attacks on bases so bases matter while owners are offline.

**Survival layer (light):** health, hunger, thirst, exposure. Tension without chores.

**Resources and crafting:** respawning nodes, machine salvage as the key tech input, stations and blueprints, tech tiers 1 to 3 at launch.

**Base building:** grid-snapped pieces (foundation, wall, doorway, door, roof, storage, workbench), material tiers, per-base piece caps, server-validated placement and demolition.

**Raiding and territory:** structure damage from tools and explosives, offline protection (reduced damage, raid windows, decay), danger-tier map and contested resource zones.

**Economy:** mostly player-crafted, a few NPC traders for essentials, simple currency and sinks at launch.

**Progression:** within a wipe, tech tiers, blueprints and base growth. Across wipes, account level, cosmetics and titles (cosmetic only).

**Wipe cycle:** timers, reset flow, wipe-day event, late-wipe pressure event, rewards carried to the account.

**Multiplayer:** squads and parties, friends, pings, text chat and proximity voice where permitted. Public worlds of roughly 30 to 60 players, one wipe timer per world.

**Onboarding:** protected starter zone, guided first hour, tooltips, starter kit.

## 7. Technical plan
- **Persistence:** compact storage for base pieces, saved per wipe. Account data stored separately. Atomic saves, versioning, backups, rollback tools, anti-duplication safeguards.
- **Server authority:** combat, inventory, building and raiding decided on the server.
- **Performance:** content streaming, per-base piece caps, AI activation radii, object pooling, replication limits.
- **Security:** validation of movement, damage and placement, rate limiting, exploit detection, moderation tools.
- **Live config:** remote tuning for drop rates, machine difficulty and events.

## 8. Monetization
Cosmetic-first: weapon skins, outfits, base decoration, kill effects. Seasonal battle pass with cosmetic tracks. Convenience items that do not affect combat power. No pay-to-win.

## 9. Live-service plan
- **Wipes:** weekly to start, lengthen if players prefer.
- **Seasons:** every 2 to 3 months with a new machine type, gear, map change and cosmetics.
- **Events:** machine surges, supply drops, limited-time modes.
- **Operations:** analytics, balance telemetry, patch notes, public roadmap.

## 10. Roadmap
1. **Prototype:** movement, shooting, one machine in a test map.
2. **World slice:** one map section with resources, loot and machine spawns.
3. **Survival and crafting:** gathering, inventory, basic crafting.
4. **Base building:** pieces, placement, saving and loading.
5. **Raiding and protection rules,** tested with real players.
6. **Machine and tier expansion:** more enemy types, boss, tech tiers.
7. **Wipe system:** reset flow and carried-over rewards.
8. **Hardening:** server population, anti-cheat, security, performance.
9. **Closed test, soft launch, launch with the first season.**

## 11. Launch scope
One map, 4 to 6 machine types plus one boss, 3 tech tiers, a small building set, a small weapon set, cosmetics-only store.

## 12. Risks
| Risk | Mitigation |
|---|---|
| Empty servers | Heavy AI presence, small server size, population targets |
| Save loss or duplication | Atomic saves, rollback, early stress tests |
| Offline raiding drives players away | Protection rules, machine incursions, playtest tuning |
| Harsh first hour | Protected starter zone, guided onboarding |
| Content treadmill | Season cadence sized to team capacity |
| Cheaters | Server authority, rate limits, rapid response |
| Scope creep | One map, limited machine types and tiers at launch |
| Unproven demand | Small vertical slice and playtests before big commitments |

## 13. Open questions
- First-person or third-person? (third-person is easier to build and read, especially on mobile)
- Wipe length: weekly or every two weeks?
- Final offline raid protection rules.
- Death penalty details (what drops, what is protected).
- Player-hosted private servers?
- Team size and roles, which sets milestone dates.
- Competitor review: Once Human and other survival games.
