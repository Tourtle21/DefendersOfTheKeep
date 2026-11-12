# Rejuvenation (`rejuvenation`, kind `rejuvenation`, no element)

## Today
- A green disc of `radius` 40 for `duration` 8 s; each frame players inside get `heal(heal_per_sec * delta)` (14/s). Nothing else; shared flat drawing.
- Adds already: t2 `wide`, t3 `swift_heal` (+60% healing), t4 `lingers`, t5 `twin`, t6 `refund`.

Palette: leaf `Color(0.4,1.0,0.5)`, light green `Color(0.7,1.0,0.7)`, petal pink `Color(1.0,0.75,0.85)`, bark `Color(0.45,0.3,0.18)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Bloom | A six-petal flower lies in the middle (6 ellipse polygons, length 0.28 r, petal pink with a yellow 3 px centre), slowly breathing (scale `1 + 0.08 sin(since*2)`). 6 leaf motes rise from the disc and fade (`fposmod(since*0.4 + jit(i),1)`). | Landing: `motes` count 10 radius r rise 26 leaf colour; `ring` radius r. `Sfx.play("cast")`. | **Shared mending**: guards inside are healed too: `g.hp = min(g.max_hp, g.hp + data.heal_per_sec * 0.5 * delta)` (group `guard`). | wide |
| 3 Mending Roots | Roots: 6 curved root lines (3-point polylines from the centre fanning out to 0.9 r, bark colour, width 2, alpha 0.5) under the flower; tiny green sprouts (2 px upright lines) on them. | A small `motes` puff above a structure when it is healed (throttled to once per 1.5 s per structure). | **Mending roots**: structures inside (group `structure`, `hp < max_hp`) regain `data.heal_per_sec * 0.25 * delta` hp (barricades, hedges and walls are repaired by standing your fire zone there). | swift_heal |
| 4 Sprout Ward | A young sapling stands at the centre: trunk rect 3x12, three leaf circles r 6/5/5 at the top (leaf colour, light highlights), swaying by `sin(since*1.5)*1.5 px`. | When a ward triggers: `star` radius 16 count 6 colour light green on the player, `Sfx.play("unlock")`. | **Sprout ward**: a player who steps into the ring gets a ward: `p.shield_time = max(p.shield_time, 1.0)`; once per player per 6 s (`_warded` dictionary player -> time). | lingers |
| 5 Entangling Vines | Vines climb out of the ground at the rim: 8 spiral vines (6-point polylines from the rim inward 0.25 r, leaf colour, tiny thorn triangles), growing with `min(1, since*1.5)`. The sapling becomes a young tree (trunk 4x16, crown 3 circles r 8). | Hit pulses: every tick `burst` radius 8 leaf colour on each enemy touched only if fewer than 5 enemies inside. | **Entangling vines**: enemies inside are slowed (`apply_slow(0.6, 0.3)` each frame) and take thorn damage `heal_per_sec * 0.15` every 0.5 s (element `""`, aoe true). | twin |
| 6 Tree of Life | A full tree at the centre: trunk 6x22 with two branches, crown of 7 overlapping circles (r 7..10, three greens), pink blossoms (5 dots), falling petals (`motes`-like, 12 particles inside the draw loop). Gold glow disc alpha 0.15 at 0.5 r, and a gold ring pulse each 2 s synchronised with the heal wave. | Every 2.0 s a **heal wave**: `ripple` radius r rings 2 colour light green + `motes` count 12 rise 30. **Finale**: `star` radius r count 8 gold, `flash` radius 0.7 r, `Sfx.play("ultimate")`. | **Tree of life**: every 2.0 s the tree sends out a wave that heals players AND guards inside instantly for `heal_per_sec * 1.0` on top of the steady heal. **Finale (FINALE)**: when it ends, players inside heal for `heal_per_sec * 3.0` at once and get `shield_time = 2.0`. Skipped for the finale when `data.copy` (the waves still run). | refund |

## Rules for the implementer
- `SpellTiers.tick_rejuvenation(s, tier, delta)` runs after the base heal loop. Private state: `_warded := {}`, `_wave_t`, `_house_t` (structure motes cooldown), `_finale_done`, `_vine_t`.
- Players in range: `s._in_radius("player")`; always use `p.heal(...)` (remote players handled inside). Guards: `get_tree().get_nodes_in_group("guard")` + distance check.
- Ward trigger = player in `_in_radius` list now and (`not in _warded` or `since - _warded[p] > 6.0`).
- Vines slow uses `apply_slow` each tick; bosses clamp themselves.
- Constants: `REJUV_GUARD := 0.5`, `REJUV_STRUCT := 0.25`, `REJUV_WARD := 1.0`, `REJUV_WARD_CD := 6.0`, `REJUV_VINE := 0.15`, `REJUV_WAVE := 2.0`, `REJUV_FINALE := 3.0`.
- Draw in `SpellArt.draw_rejuvenation`; flower/sapling/tree are chosen by tier (2 flower, 3 flower+roots, 4 sapling+roots, 5 tree(young)+roots+vines, 6 full tree). Keep the heal disc fill alpha low so the player is visible.
- Multiplayer: wards/waves host-side; waves are mirrored as `ripple`; the tree sway uses `since`.

## How to test (`tools/tests/tier_rejuvenation.gd`)
1. Shared mending: a guard at 5 hp inside gains hp at tier 2 but not at tier 1.
2. Mending roots: a structure with `hp = max_hp*0.5` inside regains hp at tier 3, not at tier 2.
3. Ward: tier 4, player moved into the ring gets `shield_time >= 0.9`; moving out and back in within 6 s does not re-grant; tier 3 never.
4. Vines: tier 5 dummy inside has `slow_mult <= 0.61` and loses health; tier 4 does neither.
5. Tree of life: tier 6 player at 50% hp heals measurably faster than the base rate (compare `Health.size.x` change over 4 s with the tier-3 swift_heal rate x 1.0 + waves); finale: `shield_time >= 1.9` and fx `star` seen at the end.
6. Draw smoke for six tiers.
