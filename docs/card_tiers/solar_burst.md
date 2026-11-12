# Solar Burst (`solar_burst`, kind `fireball`, element fire, night, FUSED fireball + flare)

## Today
- A Fireball variant: `radius` 70 (a big blast), `damage` 6, mana 40, gold `Color(1.0,0.9,0.5)`. Same flight and blast code as the Fireball. Fixed twist `shrapnel` (6 fragments, kept).
- Adds from the fireball pool: t2 `wide`, t3 `twin`, t4 `aftermath`, t5 `burn`, t6 `shrapnel` (already fixed).
- Own abilities below (not the Fireball card's): the sun theme: blinding light, seeking sparks, radiance rings, a sun wheel, a supernova. Same hooks as `fireball.md` / `frostfire.md` (`land_solar_burst`, `draw_solar_burst`, `blast_fireball` with id switch).

Palette: sun `Color(1.0,0.9,0.5)` (card colour), amber `Color(1.0,0.65,0.2)`, white `Color(1.0,0.99,0.9)`, ember `Color(1.0,0.4,0.1)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Blinding Flash | Flight: a small sun with 6 rays and a bright halo (r 8, alpha 0.3). Landing: the disc is a bright white-gold glare with 8 sharp rays reaching 1.2 r (alpha 0.4) fading in 0.5 s, lens-flare star at the centre. | `flash` radius 1.2 r white, `star` radius r count 8 gold, `Sfx.play("big_hit")`; `LightSource` radius 2.0 r for 5 s. | **Blinding flash**: every enemy hit is dazzled: stunned 0.5 s (`apply_slow(0.0, 0.5)`) and lit for 5 s (`Game.light_up(e, 5.0)`, no shroud). | wide |
| 3 Seeking Sparks | 6 spark orbs (r 2.5, white core, amber halo) circle the blast edge before leaving; each trails a short comet tail when flying. | Sparks leave and curve: `WeaponProjectile`s launched toward the nearest 6 enemies within 1.8 r (or in random directions if fewer), speed 200; `Sfx.play("whoosh")`. | **Seeking sparks**: six sparks fly out and each aims at a different nearest enemy in 1.8 r: `damage * 0.4` each (so the shrapnel add fragments are not the only spread). | twin |
| 4 Radiance | Three concentric glowing rings expand from the centre in sequence (0.0 / 0.25 / 0.5 s) and vanish at 1.3 r; the disc is a layered gradient (3 discs white/gold/amber). | `ripple` radius 1.3 r rings 3 gold-white; each ring `Sfx.play("hit")` quiet. | **Radiance**: three rings of light follow the blast at 0.25 s intervals, each hurting everything within 1.3 r for `damage * 0.3` and pushing it 60 px outward. | aftermath |
| 5 Sun Wheel | A rotating spoked wheel of 8 beams (length 1.2 r, width 3, gold, alpha 0.6) turns over the landing for 1.4 s; a bright hub (r 6). Beam tips have small flares. | Each beam sweep: `line` fx along the beam (length 1.2 r, life 0.1) every 0.1 s; `Sfx.play("whoosh")` once. | **Sun wheel**: after the blast, the 8 beams sweep a full turn in 1.4 s (angular speed 4.5 rad/s): each enemy near a beam's path (within 6 px width) is hit once per beam for `damage * 0.35`, so a pass can cut an enemy several times. Per-enemy cooldown 0.15 s. | burn |
| 6 Supernova | The impact is a miniature sun: concentric discs white / gold / amber / red edge, 16 rotating rays (long, 1.6 r), solar prominences (6 flame arcs bulging off the rim), a gold shock ring at 2.5 r that expands during the first second. | **Finale**: `flash` radius 2.0 r white-gold, `ripple` radius 2.5 r rings 4, `star` radius 2.0 r count 12, `pillar` height 120 width 60, `Sfx.play("ultimate")`; `LightSource` radius 3.0 r for 6 s. | **Supernova (FINALE)**: a shell of light expands to 2.5 r: everything inside takes `damage * 1.2`, is knocked outward (push 260), lit for 8 s (`light_up`), and burns (5 bleed ticks of `damage * 0.15`). Skipped when `data.copy`. | shrapnel |

## Rules for the implementer
- Dazzle goes into `blast_fireball` (id `solar_burst`): `apply_slow(0.0, 0.5)` and `Game.light_up(e, 5.0)` per enemy.
- Sparks: choose targets with `WeaponUtil.enemies_in_circle(tree, pos, radius * 1.8)` sorted by distance, `dir = (e.pos - pos).normalized()`; fill with `Vector2.from_angle(k * TAU / 6)` for missing.
- Radiance/sun wheel/supernova run in `tick_solar_burst(s, tier, delta)` from `since` thresholds; the sun wheel angle is `since * 4.5` (shared `SpellTiers.wheel_angle(since)` used by draw too); `effect_time` becomes 1.4 (tier >= 5) / 1.6 (tier 6).
- Wheel hit: for each beam i angle `a_i = wheel + i*TAU/8`: enemies with `|angle_diff| < 0.12` rad and within 1.2 r, `_wheel_hit[e]` cooldown 0.15 s.
- Constants: `SB_STUN := 0.5`, `SB_LIT := 5.0`, `SB_SPARK := 0.4`, `SB_RING := 0.3`, `SB_WHEEL := 0.35`, `SB_NOVA := 1.2`, `SB_NOVA_R := 2.5`.
- Multiplayer: nothing special; the wheel is a function of `since`.

## How to test (`tools/tests/tier_solar_burst.gd`)
1. Flash: tier 2: a dummy in the blast has `slow_mult == 0.0` for ~0.5 s and `Game.is_lit(dummy)`; tier 1 not.
2. Sparks: tier 3: 6 `projectile.gd` nodes after landing (plus the shrapnel 6 from the fixed twist: expect 12).
3. Radiance: tier 4: three `ripple` fx events at ~0.25 s spacing; a dummy at 1.2 r was pushed.
4. Wheel: tier 5: a dummy at 0.8 r takes several hits over 1.4 s (>= 3 damage events).
5. Supernova: tier 6: dummy at 2.3 r takes damage and is lit; `copy` skips it.
6. Draw smoke at night and day.
