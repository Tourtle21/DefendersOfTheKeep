# Hand Torch (`torch`, Common, fire, light weapon, H = 2.7)

## Today
- Attack Burn: `arc` r 36 (half angle 35 degrees), 1.0 H + 3 bleed ticks of 0.6 (it keeps burning), knock 70; its glow (`LIGHT` 110) cuts the night and every hit lights the enemy (`WeaponUtil.lit`, `Game.light_up 2 s`).
- Flare (tier 2, cd 8): ring r 55, 0.4 s later `LightSource` r 95 for 10 s at the cursor (range 110), 2.0 + knock 120 and `light_up 8` on enemies in r 55. Flame Dash (cd 4): 55 px dash, hits 1.2, a `burn` patch r 20 for 3 s (hurts players) and a 70 light for 4 s. Sunburst (tier 3, cd 55): light r 150 for 8 s, ring r 120, all lit 8 s and exposed 4 s, then two pulses of 3.0 (stun 0.4).
- The only weapon of the Common band whose identity is light; at night the lit enemies take full damage.

Palette: flame `Color(1.0,0.55,0.15)`, hot `Color(1.0,0.80,0.30)`, core `Color(1.0,0.97,0.85)`, ember `Color(0.40,0.12,0.05)`. Names: 2 Kindle, 3 Fan of Flame, 4 Blaze Trail, 5 Corona, 6 Noon.

## Tier table

| Tier | ART | ATTACK | ABILITY (Flare) | DASH (Flame Dash) | ULTIMATE (Sunburst) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Kindle | Icon polished, flame head flickers (aura: 2 ember motes rise from the head every 0.5 s); torch light pulses +-6% (`light_radius` unchanged). | Each hit drops 1 `motes` (count 3, `flame`) | **Kindle**: the Flare ignites what it lands on: every enemy in its r 55 burns 4 ticks of 0.15 H (0.4) via `WeaponUtil.bleed` and `Fx` `burst` in `hot`. The ring is replaced by a `flash` r 55. | - | locked | thunder |
| 3 Fan of Flame | Tip glow `hot`; a short orange swing trail. Light radius +10. | **Fan of Flame**: every 3rd burn is a `cone` r 44, half angle 0.9: hits the whole cone for +0.8 H (2.2), `Game.light_up 3 s`, `shards` count 4. | = | = | unlocked; a `sigil` r 80 (`hot`) for 0.25 s before the ring. Sunburst light +20. | thunder |
| 4 Blaze Trail | 2 orbiting embers, ember gem; light +20 total. | = | = | **Blaze Trail**: the dash is a `streak` (width 6, `flame`); everything passed burns 4 ticks of 0.15 H and is lit 3 s; arrival pops a `flash` r 30 and hits r 30 for 1.0 H (2.7), knock 140. The patch is r 26. | = | bleed |
| 5 Corona | 4 embers, ghost swing trail, light +30. | = | = | = | **Stage 2 Corona**: 1.0 s after the pulses 8 flame tongues erupt in a ring r 80 around where you stand (`ground_strike`, strike r 14, 0.35 s each staggered 0.05 s, 1.0 H = 2.7, knock 120, `Sfx whoosh`); each lights its victims 6 s; a `ripple` r 120 rings 2. | bleed |
| 6 Noon | Halo ring, 4 embers, tip star, light +40 and a steady warm pulse. | = | = | = | **FINALE Noon**: a `flash` r 140 (`core`) + `pillar` height 120 width 28 (`hot`) at you and, 0.3 s later, every enemy in r 120 takes 1.1 H (3.0) with knock 220 and `light_up 10`; the Sunburst `LightSource` becomes r 190 for 8 s; shake 4.5, `Sfx ultimate` (one). | chill |

Caps (H = 2.7): attack avg +0.27 H; ability + 4 x 0.15 H ticks = +0.6 H; dash +1.0 H + burn; ultimate stage 2 2.7 + finale 3.0 vs today 6.0 + ... = +95%.

## What makes this feel like Common
One colour (orange), one idea (light and burn), no timers to read. The flames are warm and obvious; there is no stack or window. Compare with the Hammer (also Common): both are "do the obvious thing harder". Compare upward with Dawnbringer (Legendary), whose light becomes weather: the torch's biggest moment is a pillar and a ring.

## Rules for the implementer
- `items/weapons/tiers/torch.gd`; edit `torch.gd` for: Kindle (in `ability()` after the timer: replace ring by `flash`, bleed the hit enemies), Fan of Flame counter (`_st.burns`), the Corona call inside `ultimate()` after `pulse_around` (use `await get_tree().create_timer(1.0).timeout` guarded by `is_inside_tree()`). Aura/hooks for the rest.
- Constants: `TORCH_FAN_EVERY := 3`, `TORCH_FAN_R := 44.0`, `TORCH_FAN_MULT := 0.8`, `TORCH_KINDLE_TICKS := 4`, `TORCH_KINDLE_MULT := 0.15`, `TORCH_CORONA_N := 8`, `TORCH_CORONA_R := 80.0`, `TORCH_NOON_R := 120.0`, `TORCH_NOON_MULT := 1.1`, `TORCH_LIGHT_BONUS := [0, 0, 10, 20, 30, 40]` added to `light_radius` in `equip(w)` (and re-applied to `GlowLight` via the same `attach` call used in `Weapon._ready`: set `w.light_radius` BEFORE `_ready` attaches it, i.e. in `Torch._init` read tier... tier is known only in `_ready`, so do the bonus in `equip(w)` by freeing and re-attaching the `GlowLight` child).
- Burn patches hurt players: the larger Blaze Trail patch (r 26) is the only new burn patch; do not add others.
- Light budget: `LightSource` count: Flare 1, Sunburst 1 (r 190 only at tier 6), Dash 1; never more than 3 alive.
- Multiplayer: nothing special; everything is fx, `LightSource`, `Hazard`. Hand glow comes from the aura (`state` unused).
- Performance: peak about 20 fx at tier 6 (8 tongues x 2 + flash + pillar + ripple); inside the Common cap (6 added per burst is violated by Corona's 16 ring fx: use ONE `ripple` and draw each tongue's ring with `life 0.2`; or add only every second ring). Decision: tongues spawn `WeaponFx ring` only at the 4 even indices.

## How to test (section `torch`)
1. Kindle: tier 2 Flare on a dummy: its health keeps falling for >= 1.5 s after the flare hit (>= 3 extra ticks); tier 1 only the first hit.
2. Fan of Flame: 3 burns at tier 3 on a dummy at 40 px (outside the 36 arc, inside the cone): only the 3rd hurts it; fx `cone` seen once.
3. Blaze Trail: tier 4 dash through 2 dummies: both keep burning; fx `streak` and `flash` seen; hazard count 1 with `radius 26`.
4. Corona: tier 5 ultimate: >= 8 strikes (kinds `ring`) within 2.0 s and a dummy at 80 px loses an extra >= 2.7 vs tier 4.
5. Noon: tier 6: kinds `flash` and `pillar` seen; `LightSource` with `light_radius >= 190`; torch still lights hits (`Game.is_lit` true after a hit).
6. Light radius grows with tier (+0, 10, 20, 30, 40 on the weapon's `light_radius`); draw smoke.
