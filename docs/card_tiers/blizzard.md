# Blizzard (`blizzard`, kind `zone`, element ice)

## Today
- A white-blue zone of `radius` 60 for 5 s: enemies inside are slowed to 0.2 (almost frozen) and take `dps` 2.6 per second (ticks every 0.5 s). Flat pale disc with rim.
- Adds already (zone pool): t2 `wide`, t3 `aftermath`, t4 `lingers`, t5 `echo`, t6 `shrapnel`.
- Flavour: cold that builds up, hail and thunder, a storm that moves.

Palette: snow `Color(0.9,0.97,1.0)`, ice `Color(0.6,0.85,1.0)`, storm `Color(0.35,0.5,0.75)`, bolt `Color(0.85,0.9,1.0)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Deep Chill | Falling snow: 28 flakes (1.5 px dots or 3-px plus signs) falling as diagonal streaks (`y = fposmod(since*40 + jit(i)*r*2, r*2) - r`, drifting x by `sin`), snow colour alpha 0.8. Ice crust: the rim is drawn twice (second arc at 0.94 r, storm colour). | When an enemy freezes: `shards` count 8 radius 20 ice at it, `ring` radius 14. `Sfx.play("big_hit")`. | **Deep chill**: every enemy collects a frost stack every 0.6 s inside the storm (max 5, `_stacks`); on the 5th stack it freezes solid for 1.0 s (`apply_slow(0.0, 1.0)`) and is made exposed for 1.5 s (`WeaponUtil.expose`), then stacks reset to 0 and it cannot freeze again for 4 s. | wide |
| 3 Hailstorm | Hail: 6 hailstones drawn as white circles r 2 with a 1 px highlight, falling faster than snow (`since*90`), bouncing on the floor (a short `draw_arc` ring where they land). Sky darkens: the disc fill gets a second darker disc alpha 0.1. | Hail impact on an enemy: `burst` radius 6 snow + `ring` radius 10 (0.15 s); `Sfx.play("hit")` throttled to 4 per second. | **Hail**: every 0.4 s a hailstone lands on a random enemy inside: `WeaponUtil.ground_strike(tree, world, enemy_pos, 8.0, 0.25, dps * 0.8, 30.0, snow, 0.0, [], "ice")`. | aftermath |
| 4 Thunder Snow | Storm clouds: 4 dark soft circles (r 14..20, alpha 0.18, storm colour) drift across the top of the zone, with a faint white flicker each time a bolt falls (disc alpha jumps by 0.15 for 0.1 s via a `since` modulo). | Every 1.5 s `bolt` from 60 px above the target to it (dir down, length 60, colour bolt, width 3) + `burst` radius 12 white + screen-local `flash` radius 18 at the victim. `Sfx.play("big_hit")`. | **Thunder snow**: every 1.5 s lightning strikes the enemy with the most frost stacks (or a random one): `dps * 3` damage, stun 0.4 s, and 40% of it arcs to the nearest enemy within 40 px. | lingers |
| 5 Roaming Front | The cloud mass is thick: 8 soft circles. A wind arrow motif (3 chevrons) shows the drift direction, and a snow trail behind the zone (the last 30 positions are not stored: instead draw a fading cone of 10 flakes behind along `-drift_dir`). The rim shimmers with an aurora arc (cyan to violet). | A frost wake: every 1.0 s `ring` radius 0.6 r at the zone centre, `Sfx.play("whoosh")` throttled. | **Roaming front**: the blizzard drifts at 18 px/s toward the densest group of enemies within 150 px of it (`SpellTiers.densest`), never further than 120 px from where it was cast. It keeps slowing and damaging as it moves. | echo |
| 6 Ice Age | The storm turns violent: 60 flakes, a spinning eye (ring of 10 chevrons around the centre rotating at 2 rad/s), aurora of three arcs (cyan, white, violet), blue light pillar at the centre. During the last second a crust of ice grows inward from the rim (filled ring from r to r*(1 - 0.5*t), ice colour alpha 0.25). | **Finale**: `flash` radius 1.4 r white-ice, `ripple` radius 1.6 r rings 3, `shards` count 20 radius 1.4 r, `pillar` height 80 width 30 ice, `Sfx.play("ultimate")`. | **Ice age (FINALE)**: when the storm ends, a freeze wave hits everything within 1.4 r: stunned 1.5 s, `dps * 4` ice damage, and the ground stays frozen: a slow patch `WeaponUtil.patch(world, pos, "slow", 1.2 * radius, ice, 7.0, 0.35)` (harmless to players). Skipped when `data.copy`. | shrapnel |

## Rules for the implementer
- `SpellTiers.tick_blizzard(s, tier, delta)` after the base zone tick. Private: `_stacks := {}` (enemy -> stacks), `_stack_t`, `_cool := {}` (enemy -> seconds until it may freeze again), `_home` (cast position, set in `land_blizzard`), `_finale_done`.
- Stacks: every 0.6 s for each enemy inside: `+1`; when it reaches 5: freeze, reset, `_cool[e] = 4.0`. Enemies that leave keep their stacks for 2 s then drop (decay by 1 per second when outside).
- Thunder pick: the enemy with the highest `_stacks`, ties random. Arc: `WeaponUtil.enemies_in_circle(tree, p, 40)` minus the victim, nearest one.
- Roaming: move `position` (this is the Spell node's own position, which Rep syncs and smooths) with `position += dir * 18.0 * delta`, clamp to `_home + 120` radius; `densest` considers enemies within 150 px of the current position. The zone's `_in_radius` automatically follows `global_position`.
- Hail uses `WeaponUtil.ground_strike` (async: just call it).
- Constants: `BLIZ_STACK_T := 0.6`, `BLIZ_FREEZE := 1.0`, `BLIZ_HAIL_T := 0.4`, `BLIZ_BOLT_T := 1.5`, `BLIZ_DRIFT := 18.0`, `BLIZ_LEASH := 120.0`.
- Draw: `SpellArt.draw_blizzard`; flakes are deterministic from `since`; drift direction for the chevrons is a public var `drift: Vector2` set by the host tick (so clients can draw it).
- Multiplayer: `drift` is the only extra public var; the position is synced as for every net node.

## How to test (`tools/tests/tier_blizzard.gd`)
1. Deep chill: dummy with physics off at tier 2: after ~3.5 s `slow_mult == 0.0` was seen at least once; at tier 1 never.
2. Hail: tier 3 ring fx of `life` 0.25 appear about 2.5 per second; a lone dummy takes more than the zone baseline (`dps*0.5` per 0.5 s) over 3 s.
3. Thunder: tier 4 fx scan sees `bolt`; a second dummy 30 px from the first takes arc damage.
4. Roaming: tier 5, dummy cluster 80 px east of the landing: the spell's `position.x` increases by >= 15 px in 2 s and never exceeds `_home + 120`; tier 4 does not move.
5. Ice age: tier 6 at the end: dummy at 1.3 r stunned (`slow_mult == 0`), a `slow` hazard exists (`get_nodes_in_group("hazard")` with `kind == "slow"`); with `copy` neither.
6. Draw smoke at all tiers.
