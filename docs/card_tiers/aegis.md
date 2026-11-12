# Aegis Ward (`aegis`, kind `aegis`, no element)

## Today
- A flat violet-blue disc (`Color(0.7,0.6,1.0)`, the default) of `radius` 40 for 8 s. Each frame every player inside gets `shield_time = max(shield_time, 0.3)`, so all damage to them is ignored. Nothing else.
- Adds already (default pool): t2 `wide`, t3 `lingers`, t4 `twin`, t5 `echo`, t6 `refund`.

Palette: ward `Color(0.65,0.75,1.0)`, white `Color(0.95,0.97,1.0)`, gold `Color(1.0,0.88,0.45)`, deep `Color(0.3,0.35,0.7)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Repel | A hex pattern dome: an inner hexagon (radius 0.55 r) with 6 spokes to the rim and a thin second rim at 0.92 r; 6 white sparks slide along the rim (`angle = since*1.2 + i*TAU/6`). | When an enemy is shoved: `burst` radius 8 ward colour at the rim. `Sfx.play("whoosh")` at most every 0.5 s. | **Repel**: enemies in the outer band (0.8 r to r + 8 px) are shoved outward: `e.push(dir_from_centre * 70, 0.15)` every 0.2 s. Players are never pushed; an enemy cannot sit on the people inside. | wide |
| 3 Bulwark | A heater shield emblem stands in the middle (polygon 7 points, height 18, deep body, white edge, gold cross), slowly hovering (`-2 + 2 sin(since*2)` px). | A mend spark `motes` count 3 rise 12 on mended guards/structures, throttled. | **Bulwark**: guards and structures inside are mended 8% of their maximum health per second (`hp += max_hp * 0.08 * delta`). Players keep the full block. | lingers |
| 4 Rune Pulse | 3 rune glyphs orbit at 0.78 r (diamond 6 px with a cross, ward colour, white centre dot; angular speed 0.9 rad/s). Each pulse lights the whole rim for 0.2 s (arc alpha jumps to 1.0, width 3). | Every 1.2 s `ripple` radius r + 10 rings 1; hit enemies get `burst` radius 8. `Sfx.play("hit")`. | **Rune pulse**: every 1.2 s the ward emits a pulse that hurts and slows every enemy in `r + 10`: damage `AEGIS_PULSE[tier-1]` (3.0 at t4), `apply_slow(0.5, 0.8)`. | twin |
| 5 Mirror | Eight mirror facets (kite polygons from 0.3 r to 0.95 r, white at 0.25 alpha, edges 0.6) and a diagonal white glint that sweeps across the dome every 1.5 s (a thin quad moving with `fposmod(since/1.5,1)`). The shield emblem becomes a mirror (white fill with a deep border). | Reflected shot: `line` from impact to a new direction (length 30, white, life 0.15) + `burst` radius 10. `Sfx.play("hit")`. | **Mirror**: enemy projectiles (`EnemyProjectile`) that enter the dome are reflected: `vel = -vel * 1.3` and they now hurt enemies (a reflected shot damages the first enemy it meets for `AEGIS_REFLECT` x the shot's own damage / 10). Implementation: set a flag, see rules. | echo |
| 6 Sanctuary | A golden dome: 4 columns (rect 3x14, gold, black edge) at the compass points of the rim joined by an arch arc at 0.85 r above, a halo ring (radius 0.9 r, gold, alpha 0.5, rotating dashes), a faint gold light column in the centre. White wings of light at the sides (two tapered polygons). | **Finale** when it ends: the dome shatters outward: `shards` count 18 radius 1.3 r gold, `flash` radius 1.3 r, `ripple` radius 1.6 r rings 3, `Sfx.play("ultimate")`. | **Sanctuary**: players inside regain `AEGIS_SANCTUARY` hp/s (4.0) while the dome stands. **Shatter (FINALE)**: when it ends everything within 1.3 r takes `3 x AEGIS_PULSE[5]` damage and is shoved out (push 160). Skipped when `data.copy`. | refund |

`AEGIS_PULSE := [0, 0, 0, 3.0, 5.0, 8.0]`, `AEGIS_REFLECT := 1.0` (reflected shot damage = shot.damage / 10), `AEGIS_SANCTUARY := 4.0`.

## Rules for the implementer
- `SpellTiers.tick_aegis(s, tier, delta)` after the base shield loop. Private: `_repel_t`, `_pulse_t`, `_mend_cd` (dictionary node -> time), `_finale_done`.
- Repel: for each enemy in `_in_radius("enemy")` (r+8 uses `WeaponUtil.enemies_in_circle(tree, pos, r + 8)`), if `distance >= radius * 0.8` push outward.
- Bulwark: groups `guard`, `structure`; `max_hp` exists on both.
- Mirror: add `add_to_group("enemy_shot")` in `_ready` of `enemies/spitter/enemy_projectile.gd` (one line; allowed because the shot is already replicated), then in `tick_aegis` loop `get_tree().get_nodes_in_group("enemy_shot")` inside r: reflect once each (`set_meta("reflected", true)`); a reflected shot is turned into a `WeaponProjectile.shoot(world, p.position, -p.vel.normalized(), p.vel.length()*1.3, p.damage/10.0*AEGIS_REFLECT, tint, 1.5, 0, 60.0)` and the enemy shot is freed.
- Finale at `since >= effect_time - 0.05` (effect_time = duration).
- `shield_time` stays the base protection at every tier; do not extend it beyond 0.3 s per frame.
- Draw in `SpellArt.draw_aegis`; emblem selection by tier (hex dome, shield, runes, mirror, sanctum).
- Multiplayer: shield_time is set on the host player objects as today; reflections are projectile spawns.

## How to test (`tools/tests/tier_aegis.gd`)
1. Repel: dummy at 0.9 r with physics off and at tier 2: after 0.5 s it is further out; tier 1: unchanged.
2. Bulwark: a guard (`load("res://cards/guard.gd")`) at 5/20 hp inside gains hp at tier 3, not at tier 2; same for a Structure.
3. Pulse: tier 4 dummy inside loses ~3 hp in the first 1.3 s and has `slow_mult <= 0.5`; tier 3 loses none.
4. Mirror: fire an `EnemyProjectile` (load by path) through the dome at tier 5: it is gone and a `projectile.gd` node flies the other way; at tier 4 it passes on.
5. Sanctuary + finale: tier 6 heals a hurt player; at the end a dummy at 1.2 r took a big hit and moved away; `copy = true` skips the shatter.
6. Draw smoke for six tiers.
