# The Zone: Gear and Equipment Style Guide (v0.1)

Style name: **grounded near-future industrial**. Heavy, matte, modular tools that look built to survive. Not neon cyberpunk.

This guide covers weapons, armor, gadgets and machine hardware. World and terrain art direction is separate.

## 1. Core look
- **Heavy and utilitarian:** gear looks engineered, not decorative.
- **Matte, dark, worn:** gunmetal, matte black, brushed steel, dull polymer. Scratches and edge wear matter more than any light effect.
- **Modular:** visible rails, side modules, fold-out braces, swappable magazines. Modularity is both the look and the gameplay (attachments, customization).
- **Small details sell the future:** panel lines, bolts, vents, exposed cabling, printed markings, tiny status LEDs.
- **Little to no glow.** Light is limited to small indicators (a status LED, a sight reticle). No neon accents on weapons or armor.

## 2. Silhouette rules
Roblox view distance hides fine detail, so the shape must read first.
1. Every weapon class has a distinct silhouette (pistol, SMG, rifle, shotgun, marksman, heavy).
2. One bold feature per weapon: a big brace, an angled magazine, a long module, an oversized muzzle device.
3. Slab-and-angle shapes over curves. Chamfered edges, flat panels.
4. Keep large masses and small details separate: big readable blocks, then small detail on top.

## 3. Materials and palette
| Material | Use |
|---|---|
| Matte black polymer | Main bodies, grips, magazines |
| Gunmetal / dark steel | Slides, barrels, receivers |
| Brushed steel / aluminum | Highlight panels, serrations |
| Textured rubber / checkered grip | Grips, handguards |
| Worn paint / bare metal edges | Wear on all hard surfaces |

- Base palette: black, charcoal, gunmetal, with steel highlights.
- Faction or tier accent: one small color panel or stripe per item (for example amber, olive, off-white). Used sparingly.
- Gear should sit quietly against the red-rock desert and let the world's color carry the scene.

## 4. Detail language
- Serial numbers and short fictional markings (original manufacturer names and logos only).
- Panel seams, screw heads, vents, cable runs.
- Side-mounted modules (sensors, laser, battery pack) as separate chunky blocks.
- Folding or collapsible parts (stocks, braces, bipods).
- Wear: edge scratches, carbon at the muzzle, dust in the crevices.

## 5. Machines
Machine hardware uses the same language: matte hard-surface plates, exposed joints and cabling, small sensor lights, corporate-style markings. Keeps gear and enemies visually related.

## 6. Roblox production notes
- **Target:** photorealistic weapons. No self-imposed triangle budget. Platform limits (per-mesh triangle cap, texture size) still apply at export; verify current values in the Roblox docs.
- **Pipeline:** build a high-detail model in Blender, make a Roblox-ready low-poly version, and bake the detail into normal, roughness and ambient-occlusion maps. Use PBR materials (SurfaceAppearance). Split weapons into several meshes (receiver, magazine, attachments) to carry more detail.
- **Texturing:** the look relies on materials. Use a shared texture atlas or material set (metal, polymer, grip, wear) and normal or roughness maps for brushed metal and grip texture.
- **Attachments:** build as separate meshes with consistent attachment points so any module fits any compatible weapon.
- **Lighting:** matte materials need no special lighting. Keep indicator lights tiny to avoid bloom and mobile cost.
- **Authoring in Blender:** modular parts (receivers, barrels, magazines, sights, braces) assembled by script into many weapon variants.

## 7. Originality rules
- Reference images are for style only. Do not copy shapes, markings, logos or brand text from existing games or weapons.
- All manufacturer names, logos, serial formats and weapon names are original.
- Use real firearm conventions only at a generic level (bullpup, rail, magazine), never a recognizable copy of a real or fictional model.

## 8. Open questions
- Faction accent colors and how many factions at launch.
- Fictional manufacturers: how many, and what each one's design signature is.
- Final weapon list and class silhouettes for launch.
- Hand-painted textures versus procedural-only for the first pass.
- Whether hero weapons get a human texture-painting pass.
