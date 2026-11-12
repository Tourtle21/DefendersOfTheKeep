# Bonfire Wall (`bonfire_wall`, kind `build`/`barricade`, element fire, night, FUSED barricade + torch)

## Today
- A wall that burns bright: `radius` 18, `hp` 36, `thorns` 1.5, `light` 80 (a night light, group `light`, GlowLight). Fixed twist `regrow` (kept, 1.5 hp/s). Orange `Color(1.0,0.55,0.2)`; generic barricade look.
- Adds (`BUILD_TWISTS.barricade`): t2 `thorned`, t3 `regrow` (already fixed), t4 `tough`, t5 `thorns_plus`, t6 `last_stand`.
- Flavour: Bonfire Wall = an open fire: scorching flames, flung brands, feeding on fire, spreading flames, a pyre. (Magma Wall is molten rock; this is wood and flame.)

Palette: fire `Color(1.0,0.55,0.2)`, flame core `Color(1.0,0.85,0.4)`, white `Color(1.0,0.97,0.8)`, charred wood `Color(0.3,0.2,0.14)`, ember `Color(1.0,0.4,0.1)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Scorching Flames | Charred logs (stacked 3 horizontal logs with bark rings at the ends) form the wall; a row of 5 flames (SpellArt.flame, heights 8..14, sway with `_age + i`) along the top, embers rising and floating off, glow disc on the ground. | Flame tick: `burst` radius 6 flame on scorched enemies, throttled (max 3 per second). | **Scorching flames**: every enemy within 32 px takes `thorns * 0.5` fire damage each 0.5 s (even when not chewing). | thorned |
| 3 Firebrand | A pile of ready brands (3 burning sticks leaning against the wall) at the side; a catapult-like lever arm on top that snaps when it throws. | Brand: `fall` fx (orange log head r 3, height 50, life 0.3) onto the target, `flash` radius 22, `ring` radius 18; `Sfx.play("big_hit")`. | **Firebrand**: every 3.0 s it flings a burning log at the nearest visible enemy within 100 px: `ground_strike(radius 18, delay 0.3, thorns * 2.0, knock 100, fire, 0.0, [], "fire")`. | regrow |
| 4 Feeding Flame | The fire rises (taller flames, 7 of them, brighter white cores); thin ember lines (streaks) stream from burning enemies into the wall (drawn from enemies in aura range, 3 dots travelling along the line toward the wall, `since`-based). Logs glow orange at the cracks. | Absorb: tiny `motes` count 2 rise 8 where an enemy burns. | **Feeding flame**: the wall feeds on what it burns: each enemy scorched by the flames mends it for 0.5 hp (up to 4 enemies per tick), so a wall in a big fight holds longer. | tough |
| 5 Spreading Blaze | Flames lick out sideways and over the top (tongues curl, 12 flames), the light ring is bigger, ground scorch marks, the fire shows a heat wave. A burning enemy has a small flame drawn over it by the wall (positions of up to 8 burning enemies). | Spread: `line` flame colour from burning enemy to the new victim, `burst` radius 8. `Sfx.play("whoosh")` throttled. | **Spreading blaze**: scorched enemies set others alight: every 1.0 s a burning enemy ignites one other enemy within 25 px (a burn of 3 ticks `thorns * 0.3`). Light radius x1.4 (`light_radius = data.light * 1.4`). | thorns_plus |
| 6 Pyre | A towering pyre: 9 big flames layered on the wall, a column of fire rising above (pillar polygon, white core), a crown of embers, black iron frame bands; fire glow disc r 2 x radius; the wall is hot white at the core. | **Firestorm** every 15 s: `flash` radius 80 white-gold, `pillar` x3 (height 80 width 24) along the wall, `ripple` radius 80 rings 3, `Sfx.play("ultimate")` quiet. | **Pyre**: every 15.0 s the bonfire erupts in a firestorm: 5 ground strikes (radius 22, delay 0.35) spread round the wall within 70 px, each `thorns * 4.0` fire damage and stun 0.3; `charge` shows the build-up. | last_stand |

## Rules for the implementer
- `tick_bonfire_wall(st, delta)`: scorch `pace "scorch" 0.5` -> `enemies(st, 32.0)`; feeding: `hp = min(max_hp, hp + 0.5 * min(n, 4))`; firebrand `pace "brand" 3.0` (nearest visible within 100, tier >= 3); spread `pace "spread" 1.0` over enemies in `_burning := {}` (enemy -> time left 3 s; filled whenever the wall scorches or ignites); pyre `pace "pyre" 15.0` (tier 6; wait while no enemy within 120 px), `charge = timer / 15`.
- Light: tier 5: `light_radius = data.light * 1.4` and `_glow.texture_scale` updated (see `Structure.promote`); nothing at lower tiers.
- Public `burning_pos: Array` (max 8 Vector2) for drawing the flames over enemies.
- `last_stand` already bursts when destroyed.
- Constants: `BONF_SCORCH_R := 32.0`, `BONF_SCORCH := 0.5`, `BONF_BRAND_T := 3.0`, `BONF_BRAND := 2.0`, `BONF_FEED := 0.5`, `BONF_SPREAD_R := 25.0`, `BONF_PYRE_T := 15.0`, `BONF_PYRE := 4.0`.
- Draw: `StructureArt.draw_bonfire_wall(st, col)`; keep the hp bar.
- Multiplayer: `charge`, `burning_pos` public.

## How to test (`tools/tests/tier_bonfire_wall.gd`)
1. Scorch: tier 2 dummy at 28 px (not chewing) loses health every 0.5 s; tier 1 none.
2. Brand: tier 3: dummy at 80 px: a `fall` fx and a hit of `>= thorns*2` within 3.2 s.
3. Feeding: tier 4: wall at 50% hp with 3 dummies scorched gains hp faster than the regrow alone (+1.5 per tick).
4. Spread: tier 5: dummy B 20 px from burning A (B not in the 32 px aura) catches fire within 2 s; `light_radius` is 1.4 x the base.
5. Pyre: tier 6: after 15 s five `ring` fx radius 22 and a `flash`; dummies within 70 px hurt and stunned.
6. Cumulative.
