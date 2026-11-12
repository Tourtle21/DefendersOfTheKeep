# Lava Pool (`lava_pool`, kind `zone`, element fire, night)

## Today
- An orange zone of `radius` 45 for 7 s: heavy damage `dps` 6 per second (ticks 0.5 s), barely slows (0.85). At night it is a light source (`light_radius = radius`). Flat orange disc with rim.
- Adds already (zone pool): t2 `wide`, t3 `aftermath` (burn patch), t4 `lingers`, t5 `echo`, t6 `shrapnel`.
- Flavour: molten rock, bubbles, eruptions.

Palette: lava `Color(1.0,0.4,0.1)`, glow `Color(1.0,0.75,0.25)`, crust `Color(0.25,0.1,0.08)`, white-hot `Color(1.0,0.95,0.7)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Bubbling | A dark crust ring on the rim (arc 0.9 r..1.0 r crust colour, broken into 5 segments) with a glowing interior; 5 bubbles (circles r 2..4, glow colour, each swells from 0 to full over 1.2 s then pops; phase from `jit(i)`). | Bubble pop on an enemy: `burst` radius 10 lava, `Sfx.play("hit")`. | **Magma bubbles**: every 1.2 s a bubble bursts under a random enemy inside: `ground_strike(radius 14, delay 0.4, dps * 1.5, knock 60, stun 0.0, "fire")`. | wide |
| 3 Molten Touch | Heat shimmer: 3 wavy outlines (sine-modulated arcs, alpha 0.25) above the pool; the surface shows flowing streaks (5 curved bright lines drifting). | Enemies that carry burn: tiny flame `motes` count 2 (every 1 s) from them. | **Molten touch**: every enemy inside is set alight: `WeaponUtil.bleed(tree, e, 4, dps * 0.3)` refreshed every 2 s per enemy (`_ignite := {}`), so it keeps burning for 2 s after it leaves the pool. | aftermath |
| 4 Cinder Fountain | A crater lip: a raised ring (two arcs, crust colour, with 8 jagged rocks as little triangles) and a glowing core; ash flecks (10 dark dots) rising and fading. | On an enemy dying: `pillar` height 40 width 12 lava + `shards` count 6 radius 30 glow. `Sfx.play("big_hit")`. | **Cinder fountain**: an enemy that dies inside the pool spits 4 burning cinders: 4 `WeaponProjectile`s from its position, directions spread at random from the pool centre outward +-0.5 rad, damage `dps * 0.6`, speed 150, life 0.5. | lingers |
| 5 Magma Geyser | Geysers: 3 vents drawn at fixed spots (angles from `jit`, 0.5 r) as dark holes with orange rims; before an eruption the vent glows white and shakes (0.4 s telegraph). The pool is brighter: inner second disc 0.6 r of glow alpha 0.2. | Eruption: `pillar` height 70 width 22 lava (life 0.5), `ripple` radius 30 rings 2, `Sfx.play("thump")`. | **Geyser**: every 2.5 s a vent erupts under the densest group of enemies (`densest(radius, 30)`): `ground_strike(radius 26, delay 0.4 telegraph, dps * 4, knock 160, stun 0.6, "fire")`. | echo |
| 6 Volcano | The pool bulges into a volcano cone: a trapezoid mound (polygon, crust colour with glow cracks as 6 bright lines) centred, a summit crater glowing white-orange, smoke puffs (6 grey circles rising). The rim is a ring of 10 rocks. The last second: the whole pool whitens. LightSource radius 2.0 r at night while it lasts. | **Finale**: `flash` radius 1.5 r white-hot, `pillar` height 110 width 40, `ripple` radius 1.8 r rings 3, `Sfx.play("ultimate")`; 8 lava bombs land in a ring at 1.2 r. | **Volcano (FINALE)**: at the end it erupts: 8 lava bombs (`WeaponUtil.rain(tree, world, pos, radius * 1.3, 8, 1.2, dps * 3, 20.0, lava)`) and a blast of `dps * 4` to everything within 1.0 r with a shove outward (push 200). Skipped when `data.copy`. | shrapnel |

## Rules for the implementer
- `SpellTiers.tick_lava_pool(s, tier, delta)` after the base zone tick. Private: `_ignite` (enemy -> seconds), `_vent_i`, `_finale_done`. Use `pace(s, "bubble", 1.2)`, `"geyser", 2.5`.
- Deaths: `SpellTiers.deaths(s)` each tick; for each position spawn 4 `WeaponProjectile.shoot(world, pos, Vector2.from_angle(base + (i-1.5)*0.35 + jit), 150.0, dps*0.6, glow, 0.5, 0, 40.0)`.
- Geysers: three vent positions are `Vector2.from_angle(vent_angle(i)) * radius * 0.5`, `vent_angle(i) = jit(i, 3.0)*TAU`; the erupting one is the vent nearest to the densest group (position of the strike is the group centre; the vent only plays the telegraph).
- `ground_strike` calls are async: do not await. Their `rings` double as the telegraph.
- Fire lighting: from tier 4 `light_radius = radius * 1.2`; tier 6 `GlowLight` energy bump (`_glow.base_energy = 0.85`) and a `LightSource.spawn(world, pos, radius*2.0, 2.0)` at the finale.
- No burn patches (they hurt players): the volcano leaves no patch.
- Constants: `LAVA_BUBBLE := 1.5`, `LAVA_IGNITE := 0.3`, `LAVA_CINDER := 0.6`, `LAVA_GEYSER := 4.0`, `LAVA_BOMBS := 8`.
- Multiplayer: vent glow telegraph derives from `since` and fixed interval (`fposmod(since, 2.5)` > 2.1 means erupting soon): both sides compute it.

## How to test (`tools/tests/tier_lava_pool.gd`)
1. Bubbles: tier 2, 4 s: ring fx of life 0.4 appear ~3 times; dummy total damage > tier 1 over the same time.
2. Molten touch: tier 3 dummy inside 1 s then moved out (set position): keeps losing health for 1.5 s afterwards; tier 2 stops immediately.
3. Cinder fountain: tier 4: dummy A (health 2) inside, dummy B 25 px away: A dies, then `projectile.gd` nodes appear (>= 3) and B takes extra damage; tier 3 none.
4. Geyser: tier 5, cluster of 4 dummies: one eruption within 2.6 s hits all four for >= `dps*4` and `slow_mult == 0` for at least one.
5. Volcano: tier 6 at the end: >= 8 `ring` fx of life 0.45 over the next 1.5 s and `flash` seen; `copy` none.
6. Draw smoke at all tiers, day and night (`game.night_level = 1.0`).
