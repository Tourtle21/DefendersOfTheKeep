# Sunspire (`sunspire`, kind `build`/`sentry`, element fire, night, LEGENDARY)

## Today
- A tower of daylight: `light` 170 (a huge night light), `range` 200, `damage` 5, `interval` 0.5, `burst` 4. Fast fierce shots that never lose the dark (it sees through the whole light). Generic sentry look in pale gold.
- Adds already (`BUILD_TWISTS.sentry`): t2 `twin_shot`, t3 `frost_shot`, t4 `rapid`, t5 `heavy`, t6 `blast_shot`.
- Flavour: Sunspire = the sun itself: flares, lances of light, radiant pulses, heliostat mirrors, high noon.

Palette: sun `Color(1.0,0.92,0.5)` (card colour), gold `Color(1.0,0.8,0.3)`, white `Color(1.0,0.99,0.9)`, amber `Color(1.0,0.6,0.2)`, stone `Color(0.85,0.8,0.7)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Solar Flare | The head is a small sun-disc on a stone column (circle r 5 white-gold with 8 short rays rotating slowly), column with a gold band; lens-flare star (4 rays) flickers at the disc. | Shot is a golden `line` (width 3) with `burst` radius 10 amber and a tiny `star` radius 8 count 4 at the impact. `Sfx.play("big_hit")` throttled. | **Solar flare**: each hit sets the target ablaze: `bleed` 3 ticks of `damage * 0.25` (fire) and it is lit for 3 s (`Game.light_up(e, 3.0)`). | twin_shot |
| 3 Solar Lance | The column gets a lens ring (arc r 7) and a focusing crystal; a charge ball grows at the tip (r 1..4 with `charge`); gold filigree on the base. | Lance: `line` width 10 gold-white over the full `range`, `flash` radius 16 at the muzzle, second thin white `line`; `Sfx.play("ultimate")` (pitch 1.5, quiet). | **Solar lance**: every 4.0 s a piercing line of light is fired through the target out to `range`: every enemy in it (width 8) takes `damage * 3.0` fire damage. | frost_shot |
| 4 Radiant Pulse | A wide corona around the disc (circle r 9 alpha 0.25 plus 12 longer rays length 14, slowly counter-rotating), glowing golden steps at the base (3 stacked flat ellipses). | Pulse: `ripple` radius 80 rings 3 gold, `flash` radius 60, `Sfx.play("whoosh")`. | **Radiant pulse**: every 6.0 s a ring of sunlight bursts from the spire: `pulse(st, 80, damage * 2.5, 220, 0.4, gold, "fire")`; players inside the ring are healed 5% of their health (`p.heal(0.05 * 228 * hp_scale)`). | rapid |
| 5 Heliostats | Four mirror dishes orbit the spire at 26 px (little concave arcs, silver with gold rim, angular speed 0.6 rad/s) each tilted toward the target; light beams bounce from the disc to each mirror (thin gold lines alpha 0.3). | Each mirror shot: thin gold `line` from the mirror to the enemy, small `burst` radius 8. | **Heliostats**: four mirrors circle the spire; each fires at the nearest visible enemy within range every 1.0 s (staggered by 0.25 s) for `damage * 0.5` fire damage. Mirror positions `orb_pos(st, i)` from `_age`. | heavy |
| 6 High Noon | A true sun above the tower: large disc r 12 white-gold with a 16-ray crown (length 18) rotating, double corona, a vertical column of light to the ground, tiny gold motes streaming; the stone is gold-plated; the light halo breathes. | **Judgement** every 20 s: `pillar` height 160 width 60 gold-white at the spire, `flash` radius 120, `ripple` radius 170 rings 4, `Sfx.play("ultimate")`; a white `flash` over each judged enemy. | **High noon**: every 20.0 s a judgement falls on everything within `range`: `damage * 6.0` fire damage, all of them are lit for 10 s (`Game.light_up(e, 10.0)`, so no enemy keeps its shroud), and for those 10 s the Sunspire's `interval_mult` is 0.7. | blast_shot |

## Rules for the implementer
- Hooks section 10: `on_shot`: flare (bleed + `Game.light_up`); lance `pace(st, "lance", 4.0)` towards the shot target; `tick_sunspire`: radiant pulse `pace "pulse" 6.0` (tier >= 4, only when an enemy is within 100 px, else hold), heliostats (tier >= 5) with per-mirror timers `m0..m3` staggered, noon `pace "noon" 20.0` (tier 6, only when enemies in range, otherwise hold the timer at full); `interval_mult` 0.7 while `_noon > 0`.
- Mirrors need `Game.defence_sees`; the lit region is huge anyway.
- Public `charge` (lance or noon progress) and `aim`.
- Constants: `SUN_FLARE := 0.25`, `SUN_LANCE_T := 4.0`, `SUN_LANCE := 3.0`, `SUN_PULSE_T := 6.0`, `SUN_PULSE := 2.5`, `SUN_HELIO := 0.5`, `SUN_NOON_T := 20.0`, `SUN_NOON := 6.0`, `SUN_NOON_LEN := 10.0`.
- Draw: `StructureArt.draw_sunspire(st, col)`.
- Multiplayer: `charge`, `aim` public; judgement is host-side; fx mirrored.

## How to test (`tools/tests/tier_sunspire.gd`)
1. Flare: tier 2 dummy keeps losing health after the shot and `Game.is_lit(dummy)`; tier 1 no.
2. Lance: tier 3: within 4.2 s a `line` fx width 10 and a second dummy 150 px away on the same line takes >= 3 x damage.
3. Pulse: tier 4: ring/ripple at ~6 s, dummy at 60 px pushed and hurt; hurt player in the ring healed.
4. Heliostats: tier 5: extra damage per second to a lone dummy about +2 x 0.5 damage compared with tier 4 (4 mirrors / 1 s).
5. Noon: tier 6: at 20 s a `pillar` fx; all dummies in range lit (`is_lit`) and hurt >= 6 x damage; interval shorter during the next 10 s.
6. Cumulative.
