# Scimitar (`scimitar`, Uncommon, earth, H = 2.2)

## Today
- Attack: alternating `swing(+-1.0)`, `arc` r 30 (+-70 degrees), 1.0 H, knock 60, and 3 bleed ticks of 0.7 on everything cut (cd 0.3). Crescent Wave (tier 2, cd 5): a piercing projectile (speed 260, 2.5, pierce 3, life 0.55) with 4 bleed ticks of 0.8. Mirage Step (cd 4): 50 px dash, hits 1.5, bleeds 3 x 0.8.
- Sand Cyclone (tier 3): 5 pulses of r 52 every 0.3 s, 2.0 each, pulling enemies toward you (160). Sand-gold rings only. The desert realm's weapon: bleeding is its identity.

Palette: brass `Color(0.95,0.80,0.45)`, sand `Color(0.92,0.75,0.40)`, blood `Color(0.80,0.20,0.15)`, dust `Color(0.85,0.75,0.60)`. Names: 2 Wide Crescent, 3 Dune Dance, 4 Afterimages, 5 Sandstorm, 6 Desert Wrath.

## Tier table

| Tier | ART | ATTACK | ABILITY (Crescent Wave) | DASH (Mirage Step) | ULTIMATE (Sand Cyclone) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Wide Crescent | Aura twinkle on the curve; blade tint drifts brass to sand. Bleeding enemies show a red drip (`motes` count 2, red, rises 8) from `tick` every 0.6 s, at most 4 enemies. | Slashes leave a 2-dot sand `trail` on the arc end | **Wide Crescent**: the wave is `style crescent` size 1.4, trail 4, pierce 5 (from 3), flies 0.7 s, and every enemy it cuts gets 2 extra bleed ticks (6 total). | - | locked | lifesteal |
| 3 Dune Dance | Tip glow (sand); a sand-coloured swing trail. | **Dune Dance**: every 3rd slash is a double swing: a second `slash` arc (opposite side) 0.1 s later hits for 0.6 H and refreshes the bleed; 6 `motes` sand. | = | = | unlocked; `sigil` r 52 (`sand`) for 0.25 s; the first pulse lands after it. | lifesteal |
| 4 Afterimages | 2 sand motes orbit, gem pixel (ruby). | = | = | **Afterimages**: the dash is a `streak` (width 6, `sand`); at 1/3 and 2/3 of the path two afterimages (`orbit` shape `blade` r 10 count 3, life 0.3) each make a 360-degree cut of r 22 0.2 s after you pass: 0.4 H each (0.9), bleed 3 x 0.8. | = | thunder |
| 5 Sandstorm | 4 motes, ghost trail. | = | = | = | **Stage 2 Sandstorm**: the last pulse leaves a sand zone at your position: `slow` patch r 52, factor 0.5, 4.0 s (harmless to players) with a `vortex` fx (r 52, count 3, spin 5, life 1.0) re-spawned 3 times; enemies caught in the pulses gain 3 bleed ticks of 0.8 (= 0.4 H over 1.5 s). | thunder |
| 6 Desert Wrath | Halo ring, 5 motes, tip star. | **Finisher** every 6th slash throws a free Crescent Wave at 50% damage (size 1.0, pierce 3). | = | = | **FINALE Desert Wrath**: after the pulses a sand `pillar` (height 100, width 26, `sand`) rises at you and 6 sand scimitars (`WeaponProjectile` style `crescent`, size 1.0, 1.0 H = 2.2, pierce 2, speed 240, life 0.4, 3 bleed ticks) fly outward at 60-degree steps; shake 4, `Sfx big_hit`. | bleed |

Caps (H = 2.2): attack avg +0.2 H; ability +2 bleed ticks (+1.6) ; dash +0.8 H; ultimate stage 2 bleed 2.4 + finale scimitars 2.2 (one per target usually) vs today 10.0 = +46% plus the slow.

## What makes this feel like Uncommon
It is still "slash, bleed", but now you manage several bleeding targets and its ultimate has two layers (pulses then blades). Compared with the Hammer (Common), the upgrades are more numerous but each is small and fast; compared with Whip (Rare) there is no timing window.

## Rules for the implementer
- `items/weapons/tiers/scimitar.gd`; `scimitar.gd` edits: `ability()` wave params (`extra`: `style`, `size`, `trail`, `bleed_ticks 6`, `life 0.7`, `pierce 5` when `tier >= 2`), `_on_dash_hit` unchanged, `ultimate()`: after the loop call `WeaponTiers.run`-driven stage 2/finale (the module's `ultimate(w)` schedules stage 2 at 1.5 s after the press, the finale at 1.7 s).
- Sultan's Guard `extends scimitar.gd`: it uses its own module (`tiers/sultanguard.gd`) which may call `preload("tiers/scimitar.gd")` functions.
- Constants: `SCIM_DANCE_EVERY := 3`, `SCIM_DANCE_MULT := 0.6`, `SCIM_AFTER_N := 2`, `SCIM_AFTER_R := 22.0`, `SCIM_AFTER_MULT := 0.4`, `SCIM_ZONE_SECS := 4.0`, `SCIM_BLADES := 6`, `SCIM_BLADE_MULT := 1.0`, `SCIM_FINISHER_EVERY := 6`.
- Bleed uses `WeaponUtil.bleed` (3 timers per call): extra bleeds in the ultimate apply one call per enemy (max 8 enemies), not per pulse.
- Multiplayer: bleeding drips are `WeaponFx`; patches/projectiles are net nodes. Performance: peak about 20 fx and 6 projectiles.

## How to test (section `scimitar`)
1. Wide Crescent: tier 2 wave through 5 dummies in a line: all five bleed; tier 1 hits 3; each has >= 6 bleed damage events (health drops for ~3 s).
2. Dune Dance: tier 3, 3 slashes: the 3rd produces two `slash`/`arc` kinds and 0.6 H extra on a dummy at 25 px; slashes 1 and 2 not.
3. Afterimages: tier 4 dash: a dummy placed at 1/3 of the path, 18 px to the side of the line, takes 0.4 H; at tier 3 nothing.
4. Sandstorm: tier 5 ultimate: a `slow` hazard of radius 52 exists at 1.6 s and lasts 4 s; tier 4 none; `vortex` kind seen.
5. Desert Wrath: tier 6: 6 projectiles of style `crescent` spawn at the end, kind `pillar` seen, a dummy 90 px out in the aim direction takes extra damage >= 2.2.
6. Draw smoke; finisher: the 6th slash spawns a projectile.
