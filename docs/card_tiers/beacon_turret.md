# Beacon Turret (`beacon_turret`, kind `build`/`sentry`, element fire, night, FUSED torch + sentry)

## Today
- A sentry that is also a torch: `range` 120, `damage` 2.2, default interval, `light` 75 (a night light: enemies in it lose their shroud and the defences see them). Fires at two targets (fixed twist `twin_shot`, kept). Instant shot lines; generic sentry look in orange.
- Adds (`BUILD_TWISTS.sentry`): t2 `twin_shot` (already fixed), t3 `frost_shot`, t4 `rapid`, t5 `heavy`, t6 `blast_shot`.
- Flavour: Beacon Turret = a lighthouse: signal fire shots, a sweeping beam, flare shells, an alarm horn, a searchlight.

Palette: flame `Color(1.0,0.7,0.25)` (card colour), brass `Color(0.9,0.75,0.35)`, white `Color(1.0,0.97,0.85)`, stone `Color(0.7,0.68,0.65)`, red `Color(0.85,0.25,0.2)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Signal Fire | A brazier lamp on the turret: an iron cage (3 vertical bars) around a flame (SpellArt.flame, height 10) above the box, sparks rising, a brass band. | Shot: orange `line` with `burst` radius 8 flame at the impact; `Sfx.play("hit")`. | **Signal fire**: every hit sets the target alight (`bleed` 3 ticks of `damage * 0.25`, fire) and lights it for 3 s (`Game.light_up(e, 3.0)`). | twin_shot |
| 3 Sweeping Beam | A lighthouse lens: a glass drum (rect with 3 vertical glints) and a rotating beam (a thin wedge polygon of angle 0.22 rad, length `light radius`, white-gold alpha 0.35, plus a bright center line) turning at 1.3 rad/s, drawn under the flame. | Where the beam crosses an enemy: `burst` radius 7 white, throttled per enemy. | **Sweeping beam**: the beam sweeps all round the beacon (angle `_age * 1.3`); enemies within `light_radius` whose bearing is within 0.11 rad of it are hit for `damage * 0.8` (once per 0.5 s per enemy). | frost_shot |
| 4 Flare Shell | The tower grows: a second tier of the housing, a flare rack (3 flare tubes with red caps) at the side; a gauge shows the shots until the next flare (`charge = (_shots % 6) / 6`). | A flare soars: the Flare spell's own flight and landing; `Sfx.play("cast")`. | **Flare shell**: every 6th shot also launches a Flare at the target spot: `StructureTiers.cast(st, "flare", 0.8, -2)`: lights up and burns the area for its duration (the Flare spell's own abilities at tier-2). | rapid |
| 5 Alarm Horn | A big brass horn (cone polygon) on the side of the tower with a red banner; sound-waves (3 arcs) radiate from it when it blows; beacon flame bigger, red warning light blinks (circle r 3 red, `sin` blink) when enemies are in range. | Horn: `ripple` radius `range` rings 2 brass, `Sfx.play("boss_roar", 0.0, 1.6)` (quiet). | **Alarm horn**: when 3 or more enemies are within range, the horn blows (cooldown 12 s): every enemy in range is slowed to 70% for 3 s and lit for 6 s. | heavy |
| 6 Lighthouse | A full lighthouse: tapered stone tower with red/white bands, a gold-roofed lantern room with a huge flame, gallery railing, the sweeping beam is long and bright with a halo; a second counter-beam opposite. During the searchlight: a thick white beam locked on one enemy with a lens flare. | **Searchlight**: a thick `line` (width 14, white-gold) from the lamp to the target each frame (via `fx` every 0.1 s), `flash` radius 18 at the target; `Sfx.play("ultimate")` at lock. | **Searchlight**: every 15.0 s the beacon locks a searchlight onto the toughest visible enemy in range for 4 s: it takes `damage * 3.0` per second, is held slow (0.5) and marked (+40% damage taken: `marked_until`). | blast_shot |

## Rules for the implementer
- `on_shot_beacon_turret`: signal fire, flare shell every 6th `_shots`. `tick_beacon_turret(st, delta)`: sweep each frame with per-enemy cooldown `_beam_cd`, horn `pace "horn" 12.0` gated by `enemies(st, range).size() >= 3`, searchlight `pace "search" 15.0` -> `_lock` (enemy, time left 4.0), public `lock_pos: Vector2` and `lock_on: bool` for drawing; each 0.5 s apply `damage * 3.0 * 0.5`.
- Beam angle `_age * 1.3` shared function `StructureTiers.beam_angle(st)`; the counter-beam at tier 6 is `+ PI`.
- Light radius stays `data.light` (it grows with `wide_field`/`bright` adds only if that card had them: not for sentry pool, so unchanged).
- Constants: `BEACON_SIGNAL := 0.25`, `BEACON_SWEEP := 0.8`, `BEACON_SWEEP_SPEED := 1.3`, `BEACON_FLARE_EVERY := 6`, `BEACON_HORN_T := 12.0`, `BEACON_SEARCH_T := 15.0`, `BEACON_SEARCH_LEN := 4.0`.
- Draw: `StructureArt.draw_beacon_turret(st, col)`.
- Multiplayer: `charge`, `aim`, `lock_pos`, `lock_on` public.

## How to test (`tools/tests/tier_beacon_turret.gd`)
1. Signal fire: tier 2: dummy keeps losing health after a shot, `Game.is_lit` true; tier 1 no.
2. Sweep: tier 3: a dummy 50 px away (not the target) is hit periodically (once per beam pass, every ~4.8 s at 1.3 rad/s; in the test set `_age` so the beam is about to pass).
3. Flare: tier 4: on the 6th shot a spell with `data.id == "flare"` and `copy == true` exists.
4. Horn: tier 5: 3 dummies in range: they get `slow_mult <= 0.71` and `fx ripple` once; not repeated within 12 s.
5. Searchlight: tier 6: after 15 s the toughest dummy takes ~`damage*3` per second for 4 s and `marked_until` is set.
6. Cumulative.
