# Charm (`charm`, kind `charm`, no element)

## Today
- Lands, calls `e.charm(duration 6)` on every enemy in `radius` 50 (bosses have no `charm`, they are skipped), shows one mint `ring` and the spell node frees itself at once.
- A charmed enemy joins group `ally`, tints green, and hunts the nearest other enemy within 220 px (`Enemy._charmed`: speed x1.4, hit `(2 + level) * power` every 0.6 s); other enemies see it as a target.
- Adds already: t2 `wide`, t3 `lingers`, t4 `twin`, t5 `refund`, t6 `potent` (no effect here, charm has no damage key; the new abilities below use it, see rules).

Palette: mint `Color(0.5,1.0,0.7)`, pink `Color(1.0,0.5,0.7)`, rose `Color(1.0,0.75,0.85)`, gold `Color(1.0,0.85,0.4)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Infatuation | The landing ring has 6 small hearts around the rim (heart = two circles r 2.5 + a triangle, pink) and a faint heart-shaped swirl in the centre; charmed enemies get a pink heart above their head (drawn by the spell for 1.0 s only: hearts rise from the enemy position). | `motes` count 8 radius r rise 30 in pink; `star` radius 0.6 r count 5 rose. `Sfx.play("cast")`. | **Infatuation**: charmed enemies fight with devotion: `charm_power` 1.5 (hits 50% harder) and move 15% faster than a plain charm. | wide |
| 3 Charm Field | The spell now stays (see rules): a pulsing pink-mint disc with 3 concentric dashed rings turning in opposite directions; hearts rise continuously (6 particles, `fposmod(since*0.4+jit(i),1)`). | Each new enemy that steps in: `burst` radius 10 pink at it. | **Charm field**: the spell stays for 3.0 s (or `data.duration` x 0.5, whichever is longer) and every enemy that enters it in that time is charmed too, for the card's `duration` counted from then. | lingers |
| 4 Heartbreak | A big rotating heart-shaped aura: polygon heart (radius 0.5 r) with a glowing edge in the centre, plus 8 spark hearts orbiting. | When a charmed enemy dies: `flash` radius 30 pink, `burst` radius 30 pink, `Sfx.play("big_hit")`. | **Heartbreak**: a charmed enemy that dies bursts in a heartbreak: `CHARM_BLAST[tier-1]` damage (4.0 at t4) to every NON-charmed enemy within 40 px. | twin |
| 5 Contagion | Pink vapour: 10 soft circles (r 5..9, alpha 0.12) drifting across the disc, chain lines of tiny hearts between charmed enemies (`line` pink from one to the next, life 0.2 each time the spread happens). The disc rim gets 12 petals. | On each spread: `line` from the charmed carrier to the new victim (pink, width 2, life 0.25) and `burst` radius 10. `Sfx.play("whoosh")`. | **Contagion**: every 0.5 s every charmed enemy infects ONE uncharmed enemy within 32 px (charm for 3.0 s, `charm_power` 1.0). At most `CHARM_SPREAD_MAX` (6) infections per cast. | refund |
| 6 Royal Decree | A throne-lit field: a crown (zig-zag polygon, gold, 5 points, 10 px wide) floats above the "favourite" (see ability) and a gold halo ring (radius 12) circles it, 16 gold hearts fall slowly across the disc, the disc has a rotating gold dashed border and a faint rose-gold glow. | **Finale on landing**: `flash` radius r pink-gold, `ripple` radius 1.4 r rings 3, `star` radius r count 8 gold, `Sfx.play("ultimate")`. | **Royal decree (FINALE)**: the strongest charmed enemy in the area (highest `max_health`, not a boss) becomes the Favourite: charmed for double the time, `charm_power` 3.0 and scaled up 1.3x. It leaves a small `burst` trail every 0.5 s while it fights. Skipped on `data.copy` (a twin charms normally). `potent` is respected: `charm_power` is multiplied by 1.25 if "potent" in adds (it is, at tier 6). | potent |

`CHARM_BLAST := [0, 0, 0, 4.0, 7.0, 12.0]`, `CHARM_SPREAD_MAX := 6`, `CHARM_POWER := [1.0, 1.5, 1.5, 1.5, 1.5, 1.5]`.

## Rules for the implementer
- `enemies/enemy.gd` (small, additive): new vars `var charm_power := 1.0` and `var charm_blast := 0.0`; `_charmed()` uses `(2.0 + level) * power * charm_power` for the hit and `speed * 1.4 * (1.0 + 0.15 * float(charm_power > 1.0))` ... simpler: `speed * 1.4 * minf(charm_power, 1.15)`; `die()`: before the existing body, `if charm_time > 0.0 and charm_blast > 0.0:` call `WeaponFx.spawn(...flash..)` and damage uncharmed enemies within 40 px (`e.get("charm_time") == 0`), then continue. `charm(time)` gains optional parameters: `func charm(time: float, power := 1.0, blast := 0.0)` setting those vars (keeps the old call signature working). When charm ends (`charm_time <= 0.0` branch in `_charmed`), reset `charm_power = 1.0`, `charm_blast = 0.0`.
- `cards/spell.gd`: in the landed block replace `charm` branch: `for e in _in_radius("enemy"): e.charm(data.duration, SpellTiers.charm_power(s, tier), CHARM_BLAST[tier-1])` then `if tier < 3: queue_free(); return` (tiers 1 and 2 still disappear instantly; from tier 3 the node stays). Add `"charm": pass` to the tail `match`, and `SpellTiers.effect_time(s)` returns for charm: tier 3+ `maxf(3.0, duration * 0.5)`, tier 5+ `maxf(6.0, duration)`. Bosses: guard with `e.has_method("charm")` (as now).
- `SpellTiers.tick_charm(s, tier, delta)`: Charm field (tier >= 3, `since < 3.0`): each 0.2 s charm uncharmed enemies in the disc. Contagion (tier >= 5): every 0.5 s, for charmed enemies (group `ally`, `charm_time > 0`) within 1.3 r of the spell, find the nearest uncharmed enemy within 32 px and `charm(3.0, 1.0, 0.0)`, counting `_spread` against `CHARM_SPREAD_MAX`.
- Favourite: at landing (tier 6, not copy) pick the strongest by `max_health`; give `e.charm(duration * 2.0, 3.0 * 1.25, CHARM_BLAST[tier-1])`, `e.scale *= 1.3` (restore when `charm_time <= 0`: do it in the enemy's reset branch with a remembered `_charm_scale`), and publish its position every tick in a PUBLIC var on the spell `favourite_pos: Vector2` (and `favourite_on := true`) so clients can draw the crown; clear when charm ends or the enemy is gone.
- Draw: `SpellArt.draw_charm`; hearts via a helper `SpellArt.heart(canvas, pos, size, color)` (two circles + a triangle polygon).
- Multiplayer: the new enemy vars are public and replicate by the generic rule; fx via `WeaponFx`.

## How to test (`tools/tests/tier_charm.gd`)
1. Infatuation: tier 2 sets `charm_power == 1.5` on a charmed dummy, tier 1 leaves 1.0.
2. Field: tier 3; spawn a second dummy 2 s after landing inside the disc: it becomes charmed (`charm_time > 0`); at tier 2 it does not.
3. Heartbreak: tier 4: charmed dummy with health 1 and an uncharmed one 20 px away with huge health; kill the first (`spell_damage(5)`): the second took >= 3.9 damage.
4. Contagion: tier 5: three dummies in a row 25 px apart, only the first inside the disc at landing... after 3 s all three are charmed; at tier 4 only the first.
5. Decree: tier 6 with dummies of different `max_health`: the highest has `charm_power >= 3.0` and `scale.x ~ 1.3`, and the spell's `favourite_pos` is near it; a `copy` cast does not.
6. Boss check: a boss in the area is never charmed or errors.
