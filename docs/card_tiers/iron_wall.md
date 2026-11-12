# Iron Bulwark (`iron_wall`, kind `build`/`barricade`, no element)

## Today
- A heavy barricade: `radius` 18, `hp` 80 (3.3x the wood wall), iron colour `Color(0.75,0.78,0.85)`. Enemies within `radius + 9` chew it every 0.5 s (-1 hp, boss -4); thorns only appear with the t2 addition.
- Drawn like the wooden wall (rect, plank lines) in iron grey.
- Adds already (`BUILD_TWISTS.barricade`): t2 `thorned`, t3 `regrow`, t4 `tough`, t5 `thorns_plus`, t6 `last_stand`.
- Flavour: Iron Bulwark = armour and mass (damage reduction, slams, auras, reflection).

Palette: iron `Color(0.75,0.78,0.85)`, dark iron `Color(0.35,0.38,0.45)`, rivet `Color(0.9,0.92,0.98)`, brass `Color(0.9,0.75,0.35)`, gold `Color(1.0,0.85,0.4)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Plated | The face is a grid of 2x3 riveted plates (thin dark seam lines, a rivet circle r 1 in each corner of each plate), bevel highlight along the top edge, thorn spikes (existing) kept. | Hits on the wall: a white spark `burst` radius 6 on the side that was chewed (throttled 0.5 s). | **Armour plating**: enemies chew less: `guard_mult` 0.75 (each gnaw costs 0.75 hp, boss 3.0). | thorned |
| 3 Ram | A heavy piston on each side (rect 4x10 with a lighter cylinder), chevron hazard stripes (yellow/black, alternating 4 px diagonal bands) along the bottom edge, a blunt ram plate on the front. | Slam: `ring` radius r+16 iron-white, `shards` count 8 radius 26, `Sfx.play("thump")`; the pistons flash out 3 px (`fx_pulse < 0.2`). | **Ram slam**: every 5.0 s the wall slams out: `pulse(st, radius + 16, thorns * 2.0, 200, 0.8, iron)`: a heavy knock-back and a 0.8 s stun on whoever is gnawing. | regrow |
| 4 Bulwark Aura | A big embossed shield emblem on the face (kite polygon, dark iron border, brass boss in the middle), thin dashed link lines (alpha 0.25) to neighbouring structures in range, a faint dashed aura circle (60 px) when `selected`/always at alpha 0.1. | A pale brass ring is drawn at each covered neighbour's position from this wall's own `_draw`. | **Bulwark aura**: every structure within 60 px takes 20% less gnaw damage (multiply by 0.8; walls of the same aura do not stack beyond 0.64). | tough |
| 5 Mirror Plate | Polished plates: a bright diagonal gleam band sweeps across the face every 2 s (`fposmod(_age/2,1)`, white quad alpha 0.5), plate edges chamfered, the thorns are curved blades. | Reflection: `line` from the wall in the reflected direction (white, length 28, life 0.15) + `burst` radius 8. `Sfx.play("hit")`. | **Deflect**: enemy shots (`EnemyProjectile`, group `enemy_shot`) that hit the wall are thrown back: replaced by a `WeaponProjectile` going the other way with the shot's `damage / 10` damage (min 1). | thorns_plus |
| 6 Anvil Bell | A bell crown: a bell silhouette (polygon: wide base 14, rounded shoulders, 12 high) with a brass band and a hanging clapper sits on top of the wall; engraved runes (3 glowing marks) on the face; gold rivets; edge gold trim. The bell swings slightly (`sin(_age*2)*0.1` rad) and glows white at `charge` near 1. | **Toll** every 12 s: `flash` radius 90 white-gold, `ripple` radius 90 rings 3, `shards` count 14 radius 90, `Sfx.play("gong")`. | **Anvil bell**: every 12.0 s the bell tolls: `pulse(st, 90, thorns * 6.0, 320, 1.0, gold)`: every enemy within 90 px is hurt, thrown away and stunned for a second. `charge` tracks the 12 s cycle. | last_stand |

## Rules for the implementer
- Central helper `StructureTiers.guard_mult(st) -> float` (replaces the plain `_guard_mult` var for barricade-kind walls): `base = 0.75 if st.data.id == "iron_wall" and tier >= 2 else 1.0` times, for each OTHER `structure` within 60 px that is an `iron_wall` of tier >= 4, `0.8` (at most two neighbours count); times 0.0 while `_invuln > 0`. The barricade branch in `structure.gd` already uses `* guard_mult(self)` (see `barricade.md`; if barricade was built first the function exists: add the iron wall rules in it).
- `tick_iron_wall(st, delta)`: `pace(st, "slam", 5.0)` (tier >= 3, only when at least one enemy is within `radius + 16`, otherwise wait); `pace(st, "bell", 12.0)` for tier >= 6 (always fires, even with nothing around, and `charge = timer / 12`).
- Deflect: loop `get_tree().get_nodes_in_group("enemy_shot")` (needs the one-line group in `enemy_projectile.gd`, see `aegis.md`) within `radius + 6`.
- `thorns` value: `st.data.get("thorns", 0.0)`; for tier 3 it already exists (tier 2 `thorned` made it).
- Constants: `IRON_PLATE := 0.75`, `IRON_AURA_R := 60.0`, `IRON_AURA := 0.8`, `IRON_SLAM_T := 5.0`, `IRON_BELL_T := 12.0`, `IRON_BELL_R := 90.0`.
- Draw: `StructureArt.draw_iron_wall(st, col)`; neighbour rings use `get_tree().get_nodes_in_group("structure")` in `_draw` (small, fine).
- Multiplayer: `charge`, `fx_pulse` public.

## How to test (`tools/tests/tier_iron_wall.gd`)
1. Plating: tier 2 wall with a gnawing dummy loses hp about 25% slower than tier 1 over 10 s.
2. Ram: tier 3: after ~5 s a chewing dummy was pushed away and stunned (`slow_mult == 0`); tier 2 never.
3. Aura: tier 4 wall next to a tier-1 `barricade` (within 40 px): the neighbour loses hp 20% slower.
4. Deflect: tier 5: an `EnemyProjectile` fired at the wall disappears and a `projectile.gd` appears going the other way.
5. Bell: tier 6: after 12 s a `flash` fx appears and a dummy at 80 px took >= `thorns*6` and is stunned.
6. Cumulative: tier 6 keeps plating (0.75 x) and slam.
