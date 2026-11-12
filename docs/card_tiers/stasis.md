# Stasis Field (`stasis`, kind `stasis`, no element, LEGENDARY)

## Today
- Lands as a huge pale disc (`radius` 130, the biggest area in the game) for `duration` 5 s. Every frame each enemy inside gets `apply_slow(0.0, 0.3)` (held still; bosses cap at 0.5 slow, max 1.5 s) and `WeaponUtil.expose(e, 0.4)` (exposed: some weapons hit harder). No damage.
- Adds already (default pool): t2 `wide`, t3 `lingers`, t4 `twin` (second field), t5 `echo`, t6 `refund`.

Palette: time `Color(0.75,0.9,1.0)`, brass `Color(1.0,0.85,0.45)`, violet `Color(0.4,0.3,0.7)`, star white `Color(0.95,0.97,1.0)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Suspension | A clock face on the ground: 12 tick marks around the rim (longer at 12/3/6/9, brass), two hands from the centre (long 0.7 r, short 0.45 r) turning BACKWARDS (`-since*0.5`, `-since*0.04`). Frozen enemy shots show a small white ring around them. | When a projectile is caught: `ring` radius 10 time colour at it, `Sfx.play("whoosh")`. | **Suspension**: enemy shots (`EnemyProjectile`) inside the field hang in the air: `vel` is set to zero while inside; they are released with their old velocity when the field ends or they are caught outside (restore `vel`). | wide |
| 3 Entropy | Two brass cogs turn at 0.55 r (gear polygons with 10 teeth, radius 12 and 16, opposite directions), thin cracks spread over the floor disc (6 radial lines alpha 0.3). Sand dots drift upward. | Every second `motes` count 4 rise 16 time colour from each of up to 6 enemies. | **Entropy**: time eats the frozen: every 0.5 s each enemy inside loses `ENTROPY` of its maximum health per second (2% as `0.01 * max_health` per tick, at least 0.5, bosses 0.3%). | lingers |
| 4 Brittle | A big crystalline hourglass stands in the centre (two triangles, glass alpha 0.4 with brass caps, falling sand dots from the top bulb to the bottom, flips every 5 s). Each frozen enemy gets a pale hex frame and crack lines (drawn at the enemy's position: 6 short lines r 9, ring r 8; only up to 24 enemies). | Every 2 s the whole field cracks with a `ripple` radius r rings 2 (no per-hit effect needed). | **Brittle**: frozen enemies are brittle: they take +50% damage from every source while in the field (and for 0.5 s after): `Game.mark_mult(e)` (see rules). | twin |
| 5 Rewind | Zodiac ring: an outer dashed ring at 0.92 r with 12 small glyph squares rotating anticlockwise, a second ring at 0.75 r with moons turning clockwise; the clock hands now spin quickly backwards (`-since*2`) for 0.4 s after every rewind pulse. Blue afterimages: 3 ghost circles trailing behind each frozen enemy toward the spawn side (alpha 0.25). | Every 1.5 s: `ripple` radius r rings 2 (time colour), `Sfx.play("thump")`. | **Rewind**: every 1.5 s time runs backwards: every enemy inside is thrown back 90 px along the line away from the keep (`push((e.pos - keep).normalized() * 600.0, 0.15)`), i.e. back the way it came. | echo |
| 6 Time Break | A full astrolabe: three nested rings (0.35, 0.6, 0.95 r) with Roman-numeral-like ticks, little planets (r 3) orbiting at different speeds, a violet starfield inside the disc (22 twinkling points) and a golden sun at the centre; the last 1 s the whole disc cracks: 10 white fracture lines grow from the centre. | **Finale**: `flash` radius r white, `ripple` radius 1.3 r rings 3, `shards` count 24 radius r time colour, `Sfx.play("ultimate")`. | **Time break (FINALE)**: when the field ends, the time held back catches up in one blow: every enemy inside takes `TIME_BREAK` (15% of its max health, at least 8; bosses 2%) as piercing damage and is thrown out 150 px. Skipped when `data.copy` (twin keeps only the freeze). | refund |

## Rules for the implementer
- `Game.mark_mult(e) -> float` in `core/game.gd` (single source for temporary damage marks): returns `1.2` if `e` has meta `toxic_until` in the future (Poison Cloud t2), times `1.5` if `brittle_until` is in the future. `Enemy.apply_traits` multiplies by it (same one-line hook as in `poison_cloud.md`; if poison was built first, just add the brittle line). The stasis tick sets `e.set_meta("brittle_until", now_seconds + 0.5)` each frame for tier >= 4.
- `SpellTiers.tick_stasis(s, tier, delta)` after the base freeze loop: Suspension: `get_tree().get_nodes_in_group("enemy_shot")` (add `add_to_group("enemy_shot")` to `enemies/spitter/enemy_projectile.gd` `_ready`; aegis.md needs the same), caught shots: `p.set_meta("held_vel", p.vel)` once, `p.vel = Vector2.ZERO`; when the spell ends (`on_end` hook, or `tree_exiting` of the spell) restore `p.vel = p.get_meta("held_vel")`. Shots hanging also keep `life` ticking down, they expire normally.
- Entropy: `pace(s, "entropy", 0.5)`: `e.spell_damage(maxf(0.5, e.max_health * 0.01 * (0.3 if boss else 1.0)), "pierce", true)`. Bosses have `max_health`.
- Rewind: `pace(s, "rewind", 1.5)`; keep pos = `Game.crystal_position()`.
- Time break: at `since >= effect_time - 0.05`: for each enemy: `dmg = maxf(8.0, e.max_health * 0.15)` (boss 0.02), `spell_damage(dmg, "pierce", true)` then `push`. The explosion is a single big hit: ok for legendary.
- A tier-2+ field draws the client-side overlays from `get_tree().get_nodes_in_group("enemy")` within radius; cap 24.
- Constants: `STASIS_ENTROPY := 0.01` (per 0.5 s), `STASIS_REWIND_T := 1.5`, `STASIS_REWIND_PUSH := 600.0`, `STASIS_BREAK := 0.15`, `STASIS_BREAK_BOSS := 0.02`.
- Balance note: 15% finale + 1%/0.5 s entropy + 50% brittle on a 5-7.5 s freeze is strong on a 60-mana legendary; the implementer should run `tools/tests/balance.gd` and scale `STASIS_BREAK` down to 0.10 if a tier-6 stasis clears waves alone.
- Multiplayer: marks are host-side; hourglass/cogs/rings derive from `since`; the held-shots' rings use `get_nodes_in_group("enemy_shot")` positions on the client (puppets).

## How to test (`tools/tests/tier_stasis.gd`)
1. Suspension: fire an `EnemyProjectile` (load by path) through the field at tier 2: its `vel` is zero inside and position stays; at the end it moves again; at tier 1 it flies through.
2. Entropy: tier 3 dummy (`max_health = 100`, physics off): loses ~1% every 0.5 s (about 2 hp after 1 s); tier 2 loses 0.
3. Brittle: tier 4: `dummy.spell_damage(10)` inside takes 15 (check `max_health - health`), at tier 3 takes 10.
4. Rewind: tier 5 dummy placed 100 px from the keep moves away from the keep by >= 60 px in 1.7 s; tier 4 stays put.
5. Time break: tier 6 end: dummy health drops by >= 15% max health in one step; `copy = true` none; fx `flash` seen.
6. Boss in the field is never errored on (slow rule) and takes only the boss rates.
