# Phoenix Shrine (`phoenix_shrine`, kind `build`/`mender`, element none (flavour fire), night, LEGENDARY)

## Today
- A burning shrine: `radius` 95, `heal_per_sec` 24, `duration` 100 (a budget of 2400 hp), `light` 90 (night light). Heals hurt players in range each frame; expires when its budget is spent. Generic mender totem look in orange.
- Adds already (`BUILD_TWISTS.mender`): t2 `wide_field` (also widens the light), t3 `swift_heal`, t4 `potent`, t5 `regrow`, t6 `tough`.
- Flavour: Phoenix Shrine = fire and rebirth: purifying flames, ashes that heal, a diving phoenix, a second life, a final song.

Palette: flame `Color(1.0,0.55,0.2)` (card colour), gold `Color(1.0,0.82,0.35)`, red `Color(0.9,0.25,0.15)`, white-hot `Color(1.0,0.96,0.8)`, ash `Color(0.35,0.3,0.3)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Purifying Flame | A stone bowl-pillar (trapezoid) crowned by a tall 3-layer flame (SpellArt.flame, height 16), a wreath of 8 small flames round the field edge (alternating), embers floating. | Burn tick: `burst` radius 6 flame on scorched enemies (max 3 per second). | **Purifying flame**: enemies inside the field are scorched: fire damage `heal_per_sec * 0.12` per second (every 0.5 s, aoe). The shrine hurts what it heals around. | wide_field |
| 3 Ashes | Fine ash drifts down (12 grey dots falling) and a gold ash ring on the ground at 0.5 radius; the flame has red-gold edges; ember arcs rise in pairs. | Ash heal: `motes` count 8 rise 24 gold above each healed player, `Sfx.play("unlock")`. | **Ashes to ashes**: every enemy that dies inside the field heals every hurt player in it by 6% of their health (`p.heal(0.06 * 228 * hp_scale)`), not counted against the budget. | swift_heal |
| 4 Phoenix Spirit | A phoenix spirit circles the shrine: a bird silhouette (body ellipse r 4, two wing polygons, long tail of 3 flame dots) flying a figure circle at 0.5 radius (`_age`), translucent red-gold, trailing embers. | Dive: the bird flies (a `line` streak from the shrine to the player, red-gold, life 0.25) and `pillar` height 40 width 16 + `ring` radius 30 on arrival; `Sfx.play("cast")`. | **Phoenix dive**: every 5.0 s the phoenix dives onto the most hurt player in the field: heals them 20% at once and bursts for `heal_per_sec * 0.5` fire damage around the player (radius 30). | potent |
| 5 Second Life | Big wings of flame spread behind the shrine (two large feathered polygons, red to gold gradient, flapping slowly), the flame doubles in height, a gold ring floats around the bowl. | Rebirth: `pillar` height 100 width 40 gold, `flash` radius 40, `ripple` radius 60 rings 3, `star` radius 50 count 8; `Sfx.play("ultimate")`. | **Second life**: when a player in the field falls below 10% health the shrine saves them: heals to 70%, `shield_time = 2.5`, and a fire nova (`pulse(st at the player, 60, heal_per_sec * 2.0, 260, 0.5, flame, "fire")` centred on the player). Once per player per 45 s. | regrow |
| 6 Eternal Phoenix | A full phoenix perches on the shrine (body, head with crest, wings at half spread, a long tail of 5 flame feathers cascading), gold halo ring (r 14), the field's edge is a ring of fire (arc alpha 0.5, small flames every 20 degrees), heat haze. During its last 10% of budget the phoenix rises in flames (brighter). | **Phoenix song** (when the budget is spent): `flash` radius 95 white-gold, `pillar` height 160 width 70, `ripple` radius 140 rings 4, `star` radius 90 count 12, `Sfx.play("ultimate")`. | **Phoenix song (FINALE)**: when the shrine's healing is spent it does not just vanish: it sings once, fully healing every player within 1.5 x radius, giving them `shield_time = 4.0`, and a fire wave (`pulse(st, radius * 1.5, heal_per_sec * 6.0, 300, 1.0, gold, "fire")`) scorches enemies. | tough |

## Rules for the implementer
- `tick_phoenix_shrine(st, delta)`: scorch `pace "scorch" 0.5` -> `enemies(st, radius)` for `data.heal_per_sec * 0.12 * 0.5`; deaths via `StructureTiers.deaths(st, radius)` -> heal players in the field; dive `pace "dive" 5.0` (needs a hurt player: `hp_frac < 0.95`; choose the lowest fraction); second life with `_saved := {}` and `hp_frac(p) < 0.10`; use `StructureTiers.hp_frac`.
- Phoenix song: `on_expire_phoenix_shrine(st)` runs from `_expire` (the mender's budget end triggers `_expire`); heal each player to full: `p.heal(1.0 * 228.0 * Game.hp_scale())`.
- Phoenix spirit position: `st.global_position + Vector2.from_angle(_age * 1.2) * radius * 0.5` with a figure orbit; public draw only. Dive animation: public `dive_to: Vector2` and `dive_t` (seconds since the dive) so clients can draw the streak.
- Night light: tier effects keep `light` as is.
- Constants: `PHX_SCORCH := 0.12`, `PHX_ASH := 0.06`, `PHX_DIVE_T := 5.0`, `PHX_DIVE := 0.2`, `PHX_LIFE_AT := 0.10`, `PHX_LIFE_TO := 0.7`, `PHX_LIFE_CD := 45.0`, `PHX_SONG := 6.0`.
- Draw: `StructureArt.draw_phoenix_shrine(st, col)`.
- Multiplayer: `dive_to`, `dive_t` public.

## How to test (`tools/tests/tier_phoenix_shrine.gd`)
1. Scorch: tier 2 dummy in the field loses health steadily; tier 1 none.
2. Ashes: tier 3: hurt player gets a sudden jump when a dummy (health 1) dies in the field (+6%); not at tier 2.
3. Dive: tier 4: after 5 s a hurt player is healed ~20% and a dummy within 30 px of them is hurt; `line` fx seen.
4. Second life: tier 5: set Health rect to 15 (of 228, ~6%): healed to >= 70% with shield; again within 45 s not.
5. Song: tier 6: force `_expire()`: players full health, `shield_time >= 3.9`, `flash` fx seen, dummy hurt >= `hps*6`.
6. Cumulative; the budget still expires the shrine.
