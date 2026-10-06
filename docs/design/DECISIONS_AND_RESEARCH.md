# Decisions and Research Log

A record of the planning conversation that led to the design in `GAME_DESIGN.md`. Market figures come from third-party trackers and web searches in October 2026 and are estimates. Re-verify before relying on them.

## Decision timeline
1. **Would a shooter do well on Roblox?** Yes. Arsenal, Phantom Forces, Rivals, Bad Business, Big Paintball and Criminality have all had large audiences. Rivals (fast arena shooter) is the clearest recent success.
2. **Audience:** target is mature, 16+. This moves the design away from fast arcade shooters toward slower, higher-stakes games.
3. **Types considered for a mature audience:** extraction shooter, tactical co-op PvE, horror or survival co-op, PvPvE, milsim PvP. Arena shooters were ruled out as already done.
4. **Inspiration:** ARC Raiders (machine-ravaged setting, PvPvE extraction) and Rust (base building, wipes). Concept name: The Zone, dystopian near-future.
5. **IP rule:** original world only. No ARC Raiders names, creatures, lore or assets.
6. **Extraction vs persistent:** considered an "ARC Raiders-Lite" extraction game first (short instanced raids, menu hub). Extraction was the lower-risk option.
7. **Final decision:** persistent open world with data wipes, "ARC meets Rust". Reasoning: extraction on Roblox competes directly with Arena Breakout: Infinite, Project Delta and ARC Raiders itself, while a persistent, free, wipe-based machine-threat survival game on Roblox appears to be an open niche.

## Market research notes
**Extraction on Roblox**
- Project Delta: hardcore tactical extraction shooter, reported 133M+ visits and about 2,800 concurrent players in July 2026.
- Roblox 2026 Incubator program backs mature (18+) games, including Drifters, an extraction shooter by Alex Seropian (Bungie co-founder).

**Tactical and co-op PvE**
- TTK Testing: tactical FPS with co-op PvE, 8M+ plays, aiming for squad AI and door-kicker missions.
- Entry Point is an established tactical co-op heist game (current numbers not verified).

**Competitive shooters**
- Rivals: about 145K live players in August 2026 and roughly 400K concurrent in January 2026. Third-party estimates put revenue at $8M to $15M+ per month, almost entirely from weapon skins and battle passes. Kill effects (299 R$) reportedly the best-selling item type. This is an extreme outlier.

**Persistent survival on Roblox**
- Searches found no polished, verifiable breakout Rust-style persistent game with reliable player data. Could mean an open niche or evidence the format is hard. Treat demand as unproven.

**Off-platform comparison**
- Once Human (free, open world, PvPvE, seasonal wipes, base building) appears to occupy similar ground. Not verified here. Study before locking features.

## Revenue view
- Short term: extraction would have shipped and monetized sooner.
- Long term: persistent with wipes has a plausible higher ceiling because each wipe is a recurring reason to return and spend, but it is unproven on Roblox.
- A mature rating narrows the audience and discovery. Plan for a smaller, more committed audience, not Rivals-scale reach.

## Roblox constraints noted
- Servers are not permanent worlds. Bases must be saved and reloaded, which is why wipe cycles (1 to 2 weeks) are used.
- Server size is limited, so aim for about 30 to 60 players per world.
- Offline raiding is the most dangerous design problem.
- Server authority and anti-cheat are required from day one.
- Mobile is a large share of players, so aim assist and touch controls matter eventually.
- Maturity labels and age verification affect features and discovery. Check current Roblox policy before designing around gore or mature themes.

## Open items
See section 13 of `GAME_DESIGN.md`.
