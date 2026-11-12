# Healing Lantern (`healing_lantern`, kind `build`/`mender`, no element, night, FUSED mender + torch)

## Today
- A healer that is also a light: `radius` 55, `heal_per_sec` 8, `duration` 70 (budget 560 hp), `light` 70 (a night light). Heals hurt players in range each frame; expires when its budget is spent. Warm gold `Color(1.0,0.85,0.5)`; generic mender totem look. Fixed twist `swift_heal` (kept).
- Adds (`BUILD_TWISTS.mender`): t2 `wide_field`, t3 `swift_heal` (already fixed), t4 `potent`, t5 `regrow`, t6 `tough`.
- Flavour: Healing Lantern = a guiding lamp: a healing wisp, revealing light, a guiding shield, wisps that zap, the dawn.

Palette: lantern gold `Color(1.0,0.85,0.5)` (card colour), warm white `Color(1.0,0.97,0.85)`, soft green `Color(0.6,1.0,0.7)`, iron `Color(0.3,0.3,0.34)`, glass `Color(0.9,0.95,1.0)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Wisp | The pole is a lantern post: iron pole with a hanging glass lantern (rect 8x10, glass alpha 0.4, a warm flame inside, iron caps), a curled hook arm. A small wisp (r 3 warm white orb with a 4-dot tail) floats near it, drifting toward the most hurt player in the field (a `line` filament between). | Wisp heal: tiny green `motes` count 3 rise 10 over the player, throttled. | **Healing wisp**: a wisp follows the most hurt player in the field and heals them an extra `heal_per_sec * 0.5` per second on top of the field (not counted against the budget). Its position is public `wisp_pos` so clients draw it. | wide_field |
| 3 Revealing Light | The lantern glows more (flame bigger, halo disc r 14 alpha 0.2); the field floor shows a faint lit ring and 6 lit "windows" on the ground (soft ellipses) flickering. Lit enemies show a tiny pale ring. | Reveal: a soft `ring` radius = field every 2 s, `Sfx.play("cast")` quiet. | **Revealing light**: every enemy inside the field is lit permanently while inside (`Game.light_up(e, 2.0)` refreshed every second: no shroud, so night defences hit it at full damage) and slowed to 85% (`apply_slow(0.85, 0.3)`). | swift_heal |
| 4 Guiding Light | A second smaller lantern hangs below the first on a chain; a halo ring around the first rotates slowly; ribbon of light curls to the shielded player. | Shield: `star` radius 16 count 6 warm white at the player, `Sfx.play("unlock")`. | **Guiding light**: when a player in the field falls below 50% health, the lantern shields them for 1.5 s (`shield_time = 1.5`); once per player per 15 s. | potent |
| 5 Spirit Lanterns | Three small lantern spirits orbit (r 4 warm orbs with soft flames, tails) at 0.6 radius (angular speed 1.2 rad/s) and the post is tall and ornate with brass curls; a ring of 6 tiny hanging lamps on a chain. | Zap: a warm `line` from the spirit to the enemy, `burst` radius 8, `Sfx.play("hit")`. | **Spirit lanterns**: the three spirits zap the nearest enemy within the field every 1.2 s each (staggered) for `heal_per_sec * 0.6` fire damage, and each zap that hits restores 1 hp to the most hurt player. | regrow |
| 6 Dawn Lantern | A great ornate lantern: gold frame with an openwork dome, a radiant sun-flower flame inside (white-gold petals, 10), halo with rays, light columns at the sides, dawn-coloured gradient glow (disc pink-gold alpha 0.12 over the field). | **Dawn** every 20 s: `flash` radius 1.5 x field white-gold, `ripple` radius 1.5 x field rings 3, `star` radius field count 10, `Sfx.play("ultimate")`. | **Dawn**: every 20.0 s the lantern flares: everyone in 1.5 x the field is healed 25% of their health at once (not budgeted), enemies there take `heal_per_sec * 3.0` fire damage, are pushed back (push 160) and lit for 8 s (`light_up`). | tough |

## Rules for the implementer
- `tick_healing_lantern(st, delta)`: wisp: target = player in `radius` with the lowest `hp_frac` (< 0.99); `wisp_pos` moves toward the target at 90 px/s (else drifts around the pole), healing only while within 10 px: `p.heal(data.heal_per_sec * 0.5 * delta)`; revealing `pace "reveal" 1.0` (and slow each frame: use the same pace at 0.25 s); guiding light via `_shield := {}` (player -> time since) with `hp_frac(p) < 0.5`; spirits: three timers 0.4 apart; dawn `pace "dawn" 20.0`.
- `StructureTiers.hp_frac`, `Game.light_up` as defined elsewhere.
- Night: the light group and glow already exist; at tier 6 raise `light_radius` to `data.light * 1.3`.
- Constants: `LANT_WISP := 0.5`, `LANT_REVEAL_SLOW := 0.85`, `LANT_SHIELD_AT := 0.5`, `LANT_SHIELD_CD := 15.0`, `LANT_ZAP_T := 1.2`, `LANT_ZAP := 0.6`, `LANT_DAWN_T := 20.0`, `LANT_DAWN_HEAL := 0.25`.
- Draw: `StructureArt.draw_healing_lantern(st, col)`.
- Multiplayer: `wisp_pos` public Vector2; `charge` (dawn progress) public.

## How to test (`tools/tests/tier_healing_lantern.gd`)
1. Wisp: tier 2: hurt player heals faster than at tier 1 by about `0.5 * hps` after the wisp arrives (2 s); `wisp_pos` near the player.
2. Reveal: tier 3: dummy in the field `Game.is_lit` and `slow_mult <= 0.86`.
3. Guide: tier 4: Health rect 100/228: `shield_time > 1.0` within a frame; repeated within 15 s no.
4. Spirits: tier 5: dummy in field loses `~hps*0.6` per 1.2 s per spirit; `line` fx seen.
5. Dawn: tier 6 after 20 s: hurt player +25%, dummies pushed and lit; `flash` seen.
6. Budget still expires it.
