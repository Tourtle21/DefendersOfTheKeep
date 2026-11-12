# Barricade (`barricade`, kind `build`/`barricade`, wood, no element)

## Today
- A solid wall (`radius` 16 footprint, `hp` 24, collision layer 16 so enemies path around or chew). Every 0.5 s each enemy within `radius + 9` chews it (-1 hp, boss -4) and takes `thorns` if it has any (from tier 2). Drawn as a brown rect with 3 plank lines, spikes on top when it has thorns, an hp bar when damaged.
- Permanent until destroyed. Merge-promoting adds one thing per tier (`BUILD_TWISTS.barricade`): t2 `thorned`, t3 `regrow`, t4 `tough` (+40% hp), t5 `thorns_plus` (x2 thorns), t6 `last_stand` (burst when destroyed).
- Family flavour: Barricade = a fortress wall that grows into a castle. Iron Bulwark = armour, Thorn Hedge = vines, Magma Wall = fire, Spiked Wall = spikes, Bonfire Wall = flame.

Palette: wood `Color(0.65,0.45,0.25)` (card colour), dark wood `Color(0.4,0.27,0.15)`, iron `Color(0.55,0.58,0.65)`, stone `Color(0.62,0.62,0.66)`, gold trim `Color(1.0,0.85,0.4)`.

## Tier table (tier 1 unchanged)

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Braced | Two vertical iron straps (rect 3 wide, iron colour, black edge) across the planks with 2 rivets each (circles r 1); a plank cross-brace line (diagonal, dark wood); the thorn spikes (existing) stay. | Shove: `ring` radius r+14 wood, `shards` count 8 radius 20; `Sfx.play("thump")` throttled. | **Shove**: every 4.0 s the wall bucks: `StructureTiers.pulse(st, radius + 14, 0, 220, 0.3, wood)` (no damage, knocks chewing enemies back and stuns 0.3 s). `charge` fills over the 4 s (public var 0..1) and the wall's top edge glows with it. | thorned |
| 3 Palisade | The top edge is a row of 6 sharpened stakes (triangles height 7 above the wall, dark wood with pale tips) and the wall is slightly taller (+3 px up). Grass tufts (3 small green lines) at the base: it is rooted in the ground. | Stake strike: a vertical `pillar` height 28 width 6 wood at the victim + `burst` radius 8; `Sfx.play("hit")`. | **Stakes**: every 3.0 s the enemy gnawing the wall closest to the centre is skewered: `thorns * 4.0` piercing damage (element `"pierce"`) and exposed 1.5 s (`WeaponUtil.expose`). | regrow |
| 4 Ballista Wall | Two arrow slits (dark rect 2x6) with a warm glint on the wall; a small ballista bolt-head poking out of the right slit; a pennant (triangle flag) on a pole at the corner that waves with `sin(_age*3)`; hp bar gets gold ends. | Bolt: `line` from the wall to the target (`StructureTiers.bolt`), colour pale wood, width 3, `Sfx.play("whoosh")`. | **Ballista**: the wall shoots the nearest enemy within 100 px every 1.5 s for `thorns * 0.8` piercing damage (it sees what is lit at night like a sentry: use `Game.defence_sees`). | tough |
| 5 Rampart | The lower half becomes grey stone blocks (3 rows of staggered rect lines, stone colour), the wooden planks sit above; the top gets crenellations (4 merlons rect 5x5) instead of stakes; the tier-5 ring glows gold. A shield emblem (small kite polygon, gold) hangs in the centre. | Rebuke: `ring` radius 44 gold-white, `ripple` radius 44 rings 2, `shards` count 10, `Sfx.play("big_hit")`. | **Rebuke**: when its hp falls below 75%, 50% and 25% of max (each once per fall, `threshold`) the wall strikes back with a shockwave of radius 44: `pulse(st, 44, thorns * 3.0, 260, 0.5, gold)`. | thorns_plus |
| 6 Citadel | Corner towers: two pillars (rect 6 wide, 8 px taller than the wall, stone, merlons) at the left and right ends, a banner (gold cloth, small emblem) between them on a pole, gold trim lines along the top, runes glowing on the stone (2 small diamonds pulsing). | Second wind: `flash` radius 50 gold-white, `ripple` radius 70 rings 3, `Sfx.play("ultimate")`; during the 3 s of invulnerability a gold shield dome (arc 1.2 x radius, alpha 0.3) is drawn. | **Second wind (once)**: the first time hp falls below 20%, the wall heals itself to 60%, becomes untouchable for 3.0 s (`_invuln`) and sends a shockwave of radius 60 (`pulse(st, 60, thorns * 5.0, 320, 0.8, gold)`). Once per wall (tier 6 is the last tier, so it cannot re-arm). | last_stand |

## Rules for the implementer
- `StructureTiers.tick_barricade(st, delta)` (called from `_physics_process` after the match): private timers by `pace`: `"shove" 4.0`, `"stake" 3.0`, `"ballista" 1.5` with the tier gates (tier >= 2, 3, 4). `charge = fposmod(timer / 4.0, 1.0)` stays in sync for drawing. Rebuke thresholds: `threshold(st, "r75", 0.75)`, `"r50"`, `"r25"` (tier >= 5). Second wind: `tier >= 6 and !_wind_used and hp < 0.2 * max_hp` -> `hp = max_hp * 0.6`, `_invuln = 3.0`, `_wind_used = true`. Public `invuln_view: bool` (true while `_invuln > 0`) so clients draw the dome.
- `structure.gd` change: in the barricade gnaw loop use `hp -= (1.0 if !(e is Boss) else 4.0) * StructureTiers.guard_mult(self)` (the function returns 0 while `_invuln > 0`); call `StructureTiers.on_gnaw(self, e)` for each gnawer.
- Stakes target: nearest gnawer from `_near_enemies(radius + 9)`; none means no stake (do not waste the timer: keep it at 3.0).
- Ballista honours `Game.defence_sees(e, global_position)` and `data.range` is absent: use the constant `BARRICADE_BALLISTA_RANGE := 100.0`.
- Second wind is once per wall: `_wind_used` starts false and each promotion (`on_promote_barricade`) resets it to false.
- Constants: `BARR_SHOVE_T := 4.0`, `BARR_STAKE_T := 3.0`, `BARR_BALLISTA_T := 1.5`, `BARR_REBUKE_R := 44.0`, `BARR_WIND_R := 60.0`.
- Draw: `StructureArt.draw_barricade(st, col)`: base wall as today plus layers by tier; hp bar and thorn spikes retained.
- Multiplayer: `charge`, `invuln_view`, `fx_pulse` are public; timers private.

## How to test (`tools/tests/tier_barricade.gd`)
1. Shove: tier 2 wall with a dummy chewing (dummy at 20 px, physics on, huge health): after 4.3 s the dummy was pushed (distance grew) ; tier 1 never moved.
2. Stakes: tier 3: dummy health loss after 3.2 s >= `thorns * 4`; and `WeaponUtil.is_exposed(dummy)` true at 3.3 s.
3. Ballista: tier 4 with a dummy at 80 px (not chewing): it loses health about every 1.5 s; tier 3 stays at full health.
4. Rebuke: tier 5: set `hp = 0.7 * max_hp`: a `ring` fx with radius 44 appears and a chewing dummy is pushed; setting hp to 0.7 again without healing above does not repeat.
5. Second wind: tier 6: set `hp = 0.1 * max_hp`: next frame `hp >= 0.55 * max_hp`, `_invuln > 2.5`; a second drop does nothing.
6. Tier 6 still has stakes/ballista/rebuke (cumulative) and thorns doubled.
