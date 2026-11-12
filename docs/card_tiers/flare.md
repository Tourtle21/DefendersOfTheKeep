# Flare (`flare`, kind `flare`, element fire, night)

## Today
- Lands almost at once (flight 0.1 s) at your aim and then FOLLOWS the caster's aimer (`caster.aim_point()`) for `duration` 12 s; at night it is a light source (`light_radius = radius`, group `light`, GlowLight). A flat pale disc (`Color(1.0,0.9,0.5)`) with a rim.
- Every 0.5 s enemies inside take `dps * 0.5` fire damage (dps 1), and fire lights what it hits.
- Adds already: t2 `wide`, t3 `lingers`, t4 `burn`, t5 `twin` (second flare 0.5 s later), t6 `refund` (30% mana back).

Palette: sun `Color(1.0,0.9,0.5)`, amber `Color(1.0,0.65,0.2)`, white `Color(1.0,0.98,0.9)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Dazzle | A 4-point lens-flare star at the centre: two crossed rays (length 0.4 r, tapered polygons, width 5 to 0) rotating with `since*0.6`, a white 3 px core, soft halo disc 0.25 r alpha 0.3. | Landing: `star` radius 0.5 r count 4 colour sun. `Sfx.play("cast")`. | **Dazzle**: enemies in the light are dazzled: `apply_slow(0.8, 0.3)` every tick (20% slower). | wide |
| 3 Searing Rays | Two opposite rays sweep round like a lighthouse: tapered polygons from the centre to 1.0 r (width 9 at base to 2 at tip, alpha 0.45, white core line alpha 0.8), angle `since*1.3`. | Each enemy the ray crosses gets a `burst` radius 8 amber at its position. | **Searing rays**: a rotating beam pair (angle `a = since*1.3`, plus PI) hits every enemy whose bearing from the centre is within 0.14 rad of the beam, for `dps * 2.0` fire damage, at most once per 0.4 s per enemy (`_ray_hit` dictionary). | lingers |
| 4 Solar Flare | Corona: 12 short flame tongues around the rim (triangles height 8..14 px by `jit`), flickering with `sin(since*8+i)`; the disc fill is a two-layer glow (outer sun alpha 0.12, inner amber 0.12 at 0.6 r). | Every 3 s: `ripple` radius r rings 2 colour amber, `Sfx.play("whoosh")`. | **Solar pulse**: every 3.0 s a wave leaves the centre: enemies inside take `dps * 1.5` fire damage and are shoved outward `push(dir * 90, 0.15)`. First pulse 1 s after landing. | burn |
| 5 Twin Suns | Two small suns orbit at 0.6 r opposite each other (angular speed 1.8 rad/s from `age`): 4 px white core, 7 px amber halo, 3 short trailing dots. A faint orbit ring (alpha 0.15). | Each sun fires: `line` from the sun to the target (length = distance, amber, life 0.12) plus a fire bolt `WeaponProjectile` impact `burst` radius 8. | **Orbiting suns**: each sun shoots the nearest enemy within r every 0.8 s (stagger the second by 0.4 s): `WeaponProjectile.shoot(world, sun_pos, dir, 260.0, dps*1.6, amber, 0.5, 0, 40.0)`; the bolt carries element fire (use the card's usual damage path). The suns follow the flare while it follows the aim. | twin |
| 6 Daybreak | The disc turns into a small sunrise: a gold half-disc rising over the centre (arc fan of 10 rays from -160 to -20 degrees, length 1.1 r, alpha 0.3, slowly pulsing), the lens star doubles to 8 rays, a double halo. A gold crown ring (radius 1.04 r) with 16 notches. | **Finale** at the end (last 0.05 s): `flash` radius 1.4 r gold, `ripple` radius 1.8 r rings 3, `star` radius 1.2 r count 8, `Sfx.play("ultimate")`. LightSource radius 2.0 r for 6 s. | **Daybreak (FINALE)**: when the flare ends it bursts: fire damage `dps * 6` to all within 1.4 r, and every enemy within 2.0 r is lit for 6 s (`Game.light_up(e, 6.0)`, so no shroud at night). While the flare lasts, players standing in its light also regain `0.5 * dps` hp/s via `p.heal` (always on at tier 6, copies too). The burst finale is skipped when `data.copy`. | refund |

## Rules for the implementer
- `SpellTiers.tick_flare(s, tier, delta)` runs after the base 0.5 s damage tick in `spell.gd`'s `"flare"` branch (tier code adds, does not replace). Private vars on the spell: `_ray_hit := {}`, `_pulse_t`, `_sun_t := [0.0, 0.4]`, `_finale_done`.
- The ray angle and the suns' angles are pure functions of `since` / `age` (draw and logic use the same formula via `SpellTiers.ray_angle(since)` and `SpellTiers.sun_pos(s, i)`), so puppets draw them in the same place.
- The flare moves with the aimer: positions are `global_position + Vector2.from_angle(a) * r`; the suns use `s.radius * 0.6` (radius includes `wide`).
- Daybreak: finale at `since >= effect_time - 0.05` (`effect_time` for flare = `duration`). Use `Game.light_up(e, 6.0)` (exists, used by fire spells).
- Healing aura (t6): `for p in s._in_radius("player"): p.heal(data.dps * 0.5 * delta)`.
- Constants: `FLARE_RAY_SPEED := 1.3`, `FLARE_RAY_ARC := 0.14`, `FLARE_PULSE := 3.0`, `FLARE_SUN_SPEED := 1.8`, `FLARE_SUN_INTERVAL := 0.8`.
- Night: the existing glow stays; t4+ add `light_radius = radius * 1.15`; t6 flare's GlowLight energy 0.8.
- Multiplayer: suns/rays are drawn from `since`; bolts are `WeaponProjectile` (already net).

## How to test (`tools/tests/tier_flare.gd`)
1. Dazzle: tier 2 dummy inside has `slow_mult <= 0.81`; tier 1 has `slow_mult == 1.0`.
2. Rays: tier 3 with a dummy at 0.7 r: it takes more total damage in 4 s than the tier-2 baseline (ray hits are 2x dps); record `_ray_hit` is filled.
3. Pulse: tier 4 dummy at 0.5 r is farther from the centre after 4 s than a tier-3 dummy held in the same place (push) — dummies not frozen for this check (`set_physics_process(true)` with huge health).
4. Suns: tier 5 spawns `WeaponProjectile` nodes (scan `world.get_children()` for `projectile.gd`) at about 2.5 shots/s; tier 4 spawns none.
5. Daybreak: tier 6 near the end spawns fx kinds `flash` and `star`; dummy at 1.3 r takes a big hit at the end; `copy = true` does not.
6. The flare still follows the aimer at all tiers (`position` equals `caster.aim_point()`).
