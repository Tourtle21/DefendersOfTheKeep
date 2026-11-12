# Sandstorm (`sandstorm`, kind `zone`, element earth)

## Today
- A tan zone of `radius` 55 for `duration` 6 s: enemies inside are slowed to 0.5 and take `dps` (2.0) per second (a tick every 0.5 s). Flat tan disc with rim.
- Adds already (zone pool): t2 `wide`, t3 `aftermath` (slow patch), t4 `lingers`, t5 `echo` (wider second storm), t6 `shrapnel` (6 bolts).
- Flavour of the family: Sandstorm = wind, grit, burying. Blizzard = cold and stacks, Lava = eruptions, Poison = infection.

Palette: sand `Color(0.92,0.75,0.4)`, dust `Color(0.75,0.6,0.35)`, bright `Color(1.0,0.9,0.6)`, dark `Color(0.45,0.32,0.18)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Dust Devil | A small whirlwind at the centre: 3 stacked arcs (radius 4/8/12 at heights -2/-8/-14, rotating at different speeds, sand colour, width 2). 14 sand grains orbit the whole zone at 0.3..0.95 r (angular speed 1.0..2.0 by `jit`, size 1.5, dust colour). | Landing: `ring` radius r, `motes` count 12 radius r rise 14 sand. `Sfx.play("whoosh")`. | **Dust devil**: a steady inward pull, enemies inside are dragged toward the centre: `e.push(dir_to_centre * 30, 0.12)` every 0.2 s (stops within 6 px). They clump. | wide |
| 3 Scour | Rim lines of wind: 6 curved streaks (arcs 40 degrees, at r 0.5..0.95 r, alpha 0.4) sweeping around; grit grains grow to 24 and some are bright. Floor pattern of ripples (3 concentric dashed arcs). | When an enemy is scoured: `burst` radius 10 dust at it (once per enemy). `Sfx.play("hit")`. | **Scour**: after an enemy has stood in the storm for 1.0 s its armour is stripped by half for good (`e.armor *= 0.5`, once, mark `e.set_meta("scoured", true)`) and its `shield` (if any) loses 50%. | aftermath |
| 4 Gale Burst | Dark sand clouds: 5 overlapping soft circles (r 10..16, alpha 0.18) roll around the zone, and a gale arrow motif: 3 chevrons orbiting at 0.7 r showing the push direction. | Every 2.0 s a burst: `ripple` radius r rings 2 sand, `shards` count 10 radius r (sand grains flung), `Sfx.play("thump")`. | **Gale burst**: every 2.0 s a gust slams the zone: damage `dps * 1.5` and a shove `push(dir * 150, 0.2)` in the gust direction `GALE_ANGLE = since * 0.9` (the direction turns, clockwise), so crowds are flung round. | lingers |
| 5 Burial | Dunes: 6 low mounds along the rim (half-ellipses polygons, dust colour, shaded darker underside), the dust devil becomes a tall funnel (5 stacked arcs, radius 3 to 17, 26 px high). A sinking sand pit marker (dark ellipse) shows under a buried enemy. | Burial: `pillar` height 30 width 14 sand at the victim, `burst` radius 14, `Sfx.play("big_hit")`. | **Burial**: every 2.5 s up to 2 random enemies are buried: stunned 1.2 s (`apply_slow(0.0, 1.2)`) and take `dps * 3`. (Bosses only slowed.) | echo |
| 6 Collapse | The funnel becomes a massive tornado: 8 stacked arcs, radius 4 to 24, 40 px high, dark/bright alternation; lightning-like sand flashes. The rim is a ring of 12 standing stones (rect 3x7, dark, black outline) that rise from the sand in the first 0.5 s. | **Finale** at the end: `flash` radius 1.5 r sand, `ripple` radius 1.6 r rings 3, `shards` count 18 radius 1.5 r, `Sfx.play("ultimate")`. | **Collapse (FINALE)**: when the storm ends the ground gives way: every enemy within 1.5 r is pulled to the centre (set position 70% of the way, via `push(dir * 260, 0.25)`), stunned 1.2 s and takes `dps * 5`. Skipped when `data.copy`. | shrapnel |

All lower abilities stay (tier 6 has pull + scour + gale + burial + collapse).

## Rules for the implementer
- `SpellTiers.tick_sandstorm(s, tier, delta)` after the base zone tick. Use `SpellTiers.pace(s, "pull", 0.2, delta)`, `"gale", 2.0`, `"bury", 2.5`. `_inside_t := {}` (enemy -> seconds inside) for Scour.
- Pull: skip enemies closer than 6 px. Scour: runs when `_inside_t[e] >= 1.0` and no meta. Armor and shield are plain vars on `Enemy` (`armor`, `shield`).
- Gale direction is computed from `since` (host) and drawn from `since` (clients): `Vector2.from_angle(since * 0.9)` with `since = age - flight`.
- Finale at `since >= effect_time - 0.05`; the 12 stones in the draw fade in over `min(1, since*2)`.
- Constants: `SAND_PULL := 30.0`, `SAND_GALE_T := 2.0`, `SAND_GALE_PUSH := 150.0`, `SAND_BURY_T := 2.5`, `SAND_COLLAPSE := 260.0`.
- Draw: `SpellArt.draw_sandstorm`; funnel size by tier (tier 2 devil 3 arcs, 5 funnel 5 arcs, 6 tornado 8 arcs); `flight_sandstorm` gets a small swirl head from tier 3 on.
- Multiplayer: nothing special.

## How to test (`tools/tests/tier_sandstorm.gd`)
1. Dust devil: dummy at 0.8 r with physics off at tier 2: after 1 s the distance to centre dropped by > 6 px; at tier 1 unchanged.
2. Scour: dummy with `armor = 4`: at tier 3 after 1.5 s `armor == 2.0` (and exactly once, still 2.0 at 3 s); at tier 2 still 4.
3. Gale: tier 4 dummy takes extra damage (`1.5 x dps` per 2 s above baseline) and has moved; tier 3 not.
4. Burial: tier 5 with two dummies: within 3 s at least one had `slow_mult == 0.0` at some sample; tier 4 never.
5. Collapse: tier 6 with a dummy at 1.2 r: after the storm ends it is nearer to the centre and stunned; `copy = true` leaves it alone. fx `flash` seen.
6. Draw smoke at all tiers.
