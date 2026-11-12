# Sentry (`sentry`, kind `build`/`sentry`, no element)

## Today
- A small post turret (`radius` 12, `range` 110, `damage` 1.5, default interval 0.7 s). Every interval it picks the nearest enemy in range that `Game.defence_sees` and hits it instantly; a pale `line` is drawn for 0.12 s. Permanent. Drawn as a dark box with a round head.
- Adds already (`BUILD_TWISTS.sentry`): t2 `twin_shot` (also hits the second nearest), t3 `frost_shot` (chills), t4 `rapid` (-40% interval), t5 `heavy` (+30% damage), t6 `blast_shot` (splash).
- Family flavour: Sentry = a marksman's post (pierce, focus, execute); the elemental turrets each have their own theme.

Palette: brass `Color(0.9,0.8,0.4)` (card colour), steel `Color(0.65,0.68,0.75)`, dark steel `Color(0.3,0.32,0.38)`, bolt `Color(1.0,0.95,0.7)`, gold `Color(1.0,0.85,0.4)`, red eye `Color(1.0,0.3,0.25)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Crossbow | The head becomes a crossbow: a steel bow arc (two limbs, 14 px wide) on the head turning to `aim`, a bolt resting in the groove; stone footing (grey ellipse under the box). | The shot is a thin bolt-shaped `line` (length to target, width 2, brass-white); an impact `burst` radius 8. `Sfx.play("whoosh")` throttled. | **Piercing bolt**: the bolt keeps flying past the target: every other enemy within 45 px behind the target along the line takes 60% of the damage (`enemies_in_line(target.pos, dir, 45, 6)`). | twin_shot |
| 3 Marksman | A scope on the barrel (small steel tube + glass dot with a pulsing glint), brass bands on the post, and a focus meter: small pips (up to 6) above the head that light up as the focus builds (use public `charge` = pips/6). | Each focused shot makes the impact `burst` bigger (radius 8 + 2 x pips). | **Focus fire**: consecutive shots on the same target ramp +15% damage each up to +90% (6 stacks), reset on a new target (`shot_mult`). | frost_shot |
| 4 Barrage | A quiver of five arrows hangs at the side (5 thin lines + feather tips), tripod legs under the box (2 dark lines from the base), the head swivels with a small recoil animation (`shot_t`) pushing the barrel back 2 px. | Every 6th shot fires a fan of 5 bolts: `WeaponProjectile`s (brass) in a fan of +-0.3 rad, `ring` radius 14 at the muzzle, `Sfx.play("big_hit")`. | **Volley**: every 6th shot is a fan of 5 bolts toward the target: `WeaponProjectile.shoot(world, pos, dir.rotated(k * 0.15), 320.0, damage * 0.5, bolt, 0.5, 0, 50.0)` for k = -2..2, on top of the normal shot. | rapid |
| 5 Executioner | Steel plating on the box (two bolted plates with edge highlights), a red eye lens on the head that glows brighter as targets weaken (alpha 0.4..1.0 by whether any visible enemy is below 25% health), black and gold paint stripe. | Execution: `flash` radius 16 red-white + `shards` count 6 radius 16; `Sfx.play("big_hit")`. | **Executioner**: shots at an enemy with 25% or less health left deal triple damage (`shot_mult` 3.0 when `target.health <= 0.25 * target.max_health`; combines with focus). | heavy |
| 6 Overwatch | A watchtower look: a taller box with a roof (gold-trimmed triangle), a banner pole on the roof, glowing blue-white rune lines on the plating; laurel wings (two gold curved polygons) at the sides; a faint range ring (dashed, alpha 0.15) around it. A mark symbol (small crosshair circle + 4 ticks, red) is drawn over the marked enemy. | Marking: `star` radius 12 count 4 red at the target, a thin dotted `line` from the post to the mark, `Sfx.play("cast")`. | **Hunter's mark**: every 8.0 s the sentry marks the toughest visible enemy in range (highest `max_health`): it prefers it as its target and the marked enemy takes +40% damage from every source for 6 s (`e.set_meta("marked_until", now+6)`, read by `Game.mark_mult`). | blast_shot |

## Rules for the implementer
- `core/game.gd`: `Game.mark_mult(e)` single source of damage marks (poison `toxic_until` 1.2, stasis `brittle_until` 1.5, `marked_until` 1.4; whichever are active multiply). `Enemy.apply_traits` multiplies by it. If another card's implementation already added `mark_mult`, only add the `marked_until` line. A boss ignores it (own `spell_damage`).
- Sentry hook usage (section 10 of `_CONVENTIONS.md`): `interval_mult` stays 1.0; `shot_mult(st, t)`: focus (`_focus_id`, `_focus_n`: reset when `t` changes), executioner (x3), product; `on_shot`: pierce, volley (every 6th via `_shots`), mark timer `pace(st, "mark", 8.0)`.
- Targeting at tier 6: prefer the marked enemy: in `structure.gd`'s target loop, `StructureTiers.prefer(st, e)` returns true for a currently marked enemy; skip if the shared code is hard to change and just let `on_shot` re-target the mark with an extra bolt (acceptable).
- Facing: `aim` set to the direction of the last target; idle aim slowly sweeps with `sin(_age*0.8)` (derive in draw if `shot_t <= 0`).
- Constants: `SENTRY_PIERCE := 0.6`, `SENTRY_PIERCE_LEN := 45.0`, `SENTRY_FOCUS := 0.15`, `SENTRY_FOCUS_MAX := 6`, `SENTRY_VOLLEY_EVERY := 6`, `SENTRY_EXEC := 3.0`, `SENTRY_EXEC_AT := 0.25`, `SENTRY_MARK_T := 8.0`, `SENTRY_MARK_BONUS := 1.4`.
- Draw: `StructureArt.draw_sentry(st, col)`; the old `shot_t` line is replaced by a bolt line.
- Multiplayer: `charge`, `aim` public; marks host-side, the mark symbol needs the marked enemy: publish its position in a public `mark_pos: Vector2` (and `mark_on`) on the structure.

## How to test (`tools/tests/tier_sentry.gd`)
1. Pierce: tier 2 with dummies A (nearest) and B (30 px behind A on the same line): B loses health with the shot; at tier 1 B untouched.
2. Focus: tier 3, one dummy, 6 shots: the 6th hit deals ~1.9x the first (compare damage per shot using `health` deltas); change target resets.
3. Volley: tier 4: on the 6th shot >= 5 `projectile.gd` nodes appear; not before.
4. Execute: tier 5: dummy with `health = 0.2 * max_health` takes >= 3x the base shot; at 50% health 1x.
5. Mark: tier 6: after 8.1 s `has_meta("marked_until")` on the toughest dummy, and `spell_damage(10)` on it loses ~14; a `star` fx was seen.
6. Cumulative: tier 6 still pierces and volleys.
