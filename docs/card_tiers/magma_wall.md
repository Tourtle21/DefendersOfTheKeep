# Magma Wall (`magma_wall`, kind `build`/`barricade`, element fire)

## Today
- A tough wall that scorches: `radius` 18, `hp` 70, `thorns` 4 (fire damage to every chewing enemy each 0.5 s). Orange rect with plank lines and light-green spikes (the generic thorn art).
- Adds already (`BUILD_TWISTS.barricade`): t2 `thorned`, t3 `regrow`, t4 `tough`, t5 `thorns_plus`, t6 `last_stand`.
- Flavour: Magma Wall = molten rock: cracks, lava spit, heat aura, eruptions, a lava pool when it falls.

Palette: magma `Color(0.9,0.4,0.2)` (card colour), crust `Color(0.25,0.12,0.1)`, lava `Color(1.0,0.55,0.15)`, white-hot `Color(1.0,0.95,0.7)`, ash `Color(0.4,0.35,0.35)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Molten Cracks | The face is dark crust with 4 glowing cracks (zig-zag polylines, lava colour, alpha pulsing with `_age`), the green thorn spikes are replaced by black obsidian spikes with orange tips. Embers (4) rise off it. | Ignite: `burst` radius 8 lava on the gnawer. | **Molten cracks**: every gnawing enemy catches fire: `WeaponUtil.bleed(tree, e, 3, thorns * 0.3)` (fire), refreshed per gnaw tick. | thorned |
| 3 Lava Spit | Two lava channels (vertical glowing lines) run down the face to a dripping spout at the bottom (drops fall and splat as small orange circles), crust thickens at the edges. | Spit: a lava glob `WeaponProjectile` (lava colour, speed 200) with `burst` radius 10 at impact; `Sfx.play("hit")`. | **Lava spit**: every 3.0 s it spits a glob at the nearest visible enemy within 90 px: damage `thorns * 1.2`, fire, with 3 ticks of bleed `thorns * 0.2`. | regrow |
| 4 Heat Wall | The wall glows: orange halo behind it (disc r 1.8 x radius alpha 0.12) and heat shimmer (2 wavy lines above). At night it is a light source (light 60, group `light`, GlowLight, see rules). Cracks widen. | Aura tick: tiny `motes` count 2 rise 10 ember over scorched enemies, throttled. | **Heat wall**: every enemy within 40 px of the wall (even if not chewing) takes `thorns * 0.4` fire damage every 0.5 s; and it lights the night (enemies in its light lose their shroud). | tough |
| 5 Eruption | Lava fountains: two small vents on top spout flames (SpellArt.flame x2); the lower half is molten (bright gradient bar 40% of height) when hp is low (`hp/max_hp < 0.66` brightens the cracks). A thin lava drip trail on the ground. | Eruption: `flash` radius 55 lava, `ripple` radius 55 rings 2, `pillar` height 60 width 20 lava; `Sfx.play("big_hit")`. | **Eruption**: when its hp falls below 66% and again below 33% (`threshold`), the wall erupts: `pulse(st, 55, thorns * 4.0, 240, 0.6, lava, "fire")` and a small lava pool forms (`cast(st, "lava_pool", 0.8, -2)` at the wall). | thorns_plus |
| 6 Magma Core | A white-hot core glows through the cracks (inner rect white-gold, alpha pulsing), the wall is crowned with 5 flame tongues, lava drips and a floor glow disc; below 30% hp it turns white-hot with a halo. A crater-rim base of black rocks. | Death: see `last_stand`; plus `flash` radius 70 white, `pillar` height 100 width 40, `Sfx.play("ultimate")`. | **Magma core**: while below 30% hp the heat wall's damage doubles and thorns burn x2 (rage); when it is destroyed it bursts into a full Lava Pool (`cast(st, "lava_pool", 1.0, -1)` at its place, a pool one tier below the wall) after the normal `last_stand` blast. | last_stand |

## Rules for the implementer
- `on_gnaw_magma_wall(st, e)`: bleed (tier >= 2). `tick_magma_wall(st, delta)`: spit `pace "spit" 3.0` (tier >= 3, visible enemy within 90), heat aura `pace "heat" 0.5` (tier >= 4: `enemies(st, 40.0)`, damage `thorns * 0.4 * (2 if hp < 0.3*max_hp and tier >= 6 else 1)`), thresholds `r66`, `r33` (tier >= 5).
- Night light: in `on_promote_magma_wall` and when a tier >= 4 wall is created, set `st.light_radius = 60.0`, `st.add_to_group("light")`, `_glow = GlowLight.attach(st, 60.0, ...)` if not yet attached (mirror the lines in `Structure._ready`).
- `on_expire_magma_wall(st)` (after `last_stand`): tier >= 6 and `hp <= 0` -> `cast(st, "lava_pool", 1.0, -1)`.
- Constants: `MAGMA_BLEED := 0.3`, `MAGMA_SPIT_T := 3.0`, `MAGMA_SPIT := 1.2`, `MAGMA_HEAT_R := 40.0`, `MAGMA_HEAT := 0.4`, `MAGMA_ERUPT_R := 55.0`.
- Draw: `StructureArt.draw_magma_wall(st, col)`, glow intensity from `hp / max_hp`.
- Multiplayer: lava pools are spell nodes; wall glow derived from `hp`.

## How to test (`tools/tests/tier_magma_wall.gd`)
1. Cracks: tier 2 chewing dummy keeps losing health after being moved away (bleed); tier 1 stops.
2. Spit: tier 3 dummy at 70 px: a `projectile.gd` appears within 3.2 s.
3. Heat: tier 4 dummy at 35 px (not chewing) loses health every 0.5 s; tier 3 none; wall is in group `light`.
4. Eruption: tier 5 set `hp = 0.6 * max_hp`: a `flash` fx and a spell with `data.id == "lava_pool"` appear; same for 0.3; no repeat without healing.
5. Core: tier 6 `hp = 0`: a lava pool spell exists after the wall is gone.
6. Cumulative.
