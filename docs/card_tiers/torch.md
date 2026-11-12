# Torch (`torch`, kind `build`/`torch`, element fire, night)

## Today
- A stick with a three-layer flame (flickering). `hp` 10, `light` 85: at night it is a light source (`GlowLight`, group `light`): enemies inside lose their shroud and sentries/turrets can see them. In the dark it also draws a faint circle at the light radius.
- Every 0.5 s with the right adds: `blaze` burns enemies in the light (1 + 0.5 x tier), `sunfire` burns them more (1.5 + 0.5 x tier), `warding` slows them (0.65).
- Adds already (`BUILD_TWISTS.torch`): t2 `wide_field` (+40% light), t3 `blaze`, t4 `bright` (+30% light), t5 `warding`, t6 `sunfire`.

Palette: flame `Color(1.0,0.45,0.1)`, mid `Color(1.0,0.8,0.3)`, core `Color(1.0,0.98,0.8)`, iron `Color(0.3,0.3,0.34)`, gold `Color(1.0,0.85,0.4)`, wood `Color(0.55,0.38,0.2)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Brazier | The stick stands in an iron bowl (trapezoid 12 wide, 5 high, iron, black edge, lighter rim) heaped with embers (3 small orange dots); the flame is 30% bigger and sheds 3 sparks (dots rising and fading, `jit`). | Flame guard: `ring` radius 26 flame colour + `burst` radius 16; `Sfx.play("hit")`. | **Flame guard**: when an enemy comes within 26 px the brazier flares: `pulse(st, 26, TORCH_DMG[tier-1], 140, 0.0, flame, "fire")`, cooldown 3.0 s. | wide_field |
| 3 Ember Flick | The pole is taller (+6 px) with two flames (a main and a small one on a side arm), ember flecks (6) drift up and out in an arc; the iron bowl has a glowing crack. | Ember: a `WeaponProjectile` bolt (small fire dot) with `burst` radius 8 on impact; `Sfx.play("whoosh")`. | **Ember flick**: every 2.0 s the torch flicks a burning ember at the nearest enemy inside its light: `WeaponProjectile.shoot(world, pos, dir, 200, TORCH_DMG[tier-1] * 0.8, flame, 0.7, 0, 40)`. | blaze |
| 4 Hearth | A warm ground glow (disc r = light*0.5 alpha 0.08 flame) with a ring of 6 stones (rect 4x3, grey, black edge) around the base and a small hanging lantern shape on the side arm. A tiny heart-shaped heat shimmer (two wavy lines) over the flame. | Every 2 s: `motes` count 4 rise 14 warm yellow over each healed player. | **Hearth**: players standing inside the light recover `1.5 hp/s` (`p.heal(1.5 * delta)`, only if `p.needs_health()`). | bright |
| 5 Fire Orbs | Three flame sprites orbit at 0.45 x light radius (angular speed 1.4 rad/s, each a 3-layer mini flame r 4, tail of 3 dots), faint orbit ring (alpha 0.12). The brazier is double-bowled. The tier-5 gold ring from `structure.gd` stays. | Hit: `burst` radius 8 flame at the enemy. | **Fire orbs**: the 3 orbs circle the torch and burn what they touch: each orb damages enemies within 12 px of it every 0.5 s for `TORCH_DMG[tier-1] * 0.6` (fire, aoe). Orbit angle `a_i = _age * 1.4 + i * TAU / 3`; position `st.global_position + from_angle(a_i) * light_radius * 0.45`. | warding |
| 6 Sun Crown | Behind the flame a gold sun-disc: 12 triangular rays (length 0.4 x 14.. ~18 px, gold, alpha 0.6, slowly rotating), white-hot core flame, gold pole bands; the glow ring pulses. A cap of gold on the bowl. Light colour shifts to white-gold (`_glow.color`). | **Sunburst** every 8 s: `flash` radius = light radius * 0.8 white-gold, `ripple` radius light radius 3 rings, `star` radius 24 count 12, `Sfx.play("ultimate")` (quiet pitch). | **Sunburst**: every 8.0 s the torch flares: `pulse(st, light_radius, TORCH_DMG[tier-1] * 3.0, 220, 0.4, gold, "fire")`, and every enemy hit is lit for 6 s (`Game.light_up(e, 6.0)`). While `charge` nears 1 (last 1 s) the flame grows. | sunfire |

`TORCH_DMG := [0.0, 2.0, 3.0, 5.0, 8.0, 12.0]` (index = tier-1).

## Rules for the implementer
- `StructureTiers.tick_torch(st, delta)`: `pace` timers `"flame" 3.0` (only when an enemy is within 26 px), `"ember" 2.0` (needs a visible enemy: `Game.defence_sees`), `"sun" 8.0`; `st.charge = timer / 8.0` for tier 6.
- Hearth uses `get_tree().get_nodes_in_group("player")` within `light_radius` (use `st.light_radius`, which already includes `wide_field`/`bright`).
- Orbs: compute positions with one function `StructureTiers.orb_pos(st, i)`; drawn by `StructureArt.draw_torch` with the same function (it uses `_age`, which ticks on puppets).
- Day vs night: the damaging abilities work in the day too; the light circle visual and GlowLight are night-only as today. Do not change `light_radius` for tier abilities.
- Draw: `StructureArt.draw_torch(st, col)` keeps the flicker (`flick`) of the old drawing and layers the bowl, pole, orbs, sun by tier.
- Constants: `TORCH_DMG`, `TORCH_FLAME_R := 26.0`, `TORCH_EMBER_T := 2.0`, `TORCH_SUN_T := 8.0`, `TORCH_HEARTH := 1.5`.
- Multiplayer: `charge` public; light group replicates today.

## How to test (`tools/tests/tier_torch.gd`)
1. Flame guard: tier 2 dummy placed 20 px away takes damage within 0.5 s and was pushed; tier 1 none.
2. Ember: tier 3 dummy at 60 px (inside light): `projectile.gd` node appears within 2.2 s and the dummy loses health; tier 2 only (flame guard needs 26 px).
3. Hearth: tier 4 hurt player standing in the light heals (Health rect width grows); tier 3 does not. Note: players have no `needs_health` while at full.
4. Orbs: tier 5 dummy at the orb position at `_age = t0` is damaged over 1 s; `orb_pos(st, 0)` differs after 0.5 s.
5. Sunburst: tier 6 after 8.1 s a `flash` fx has been seen and a dummy 70 px away is lit (`Game.is_lit(dummy)` true) and damaged >= `TORCH_DMG[5]*3`.
6. Cumulative: tier 6 still has flame guard, ember, hearth and orbs.
