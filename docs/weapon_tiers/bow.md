# Bow (`bow`, Uncommon, no element, H = 2.6)

## Today
- Attack: hold left click to draw (0.8 s to full, you move at 60%), release to fire. Damage `H x (0.33 + 0.67 x ratio)`, speed 200 to 360, full draw pierces 1, release in the gold window (0.8 to 1.1 s) is a perfect shot x1.6 with a gold `ring` and shake 1.5. An aim line grows while drawing.
- Volley (tier 2, cd 6): 5 arrows in a 0.17 rad fan, 1.5 each. Backflip Shot (cd 4): 46 px dash while firing a 2.0 arrow at the cursor. Arrow Storm (tier 3): 13 arrows over 1.3 s (random +-0.18 rad, 1.7 each, you walk at 60%), then a `ground_strike` at the cursor (range 150) r 38, 0.4 s, 4.0, stun 0.4.
- Looks: a plain 14 px arrow, one gold ring, thin aim line.

Palette: wood `Color(0.72,0.52,0.28)`, arrow `Color(0.90,0.80,0.50)`, gold `Color(1.0,0.85,0.20)`, fletch `Color(0.95,0.95,0.95)`. Names: 2 Fan, 3 Overdraw, 4 Smoke Roll, 5 Rainstorm, 6 Skyfall.

## Tier table

| Tier | ART | ATTACK (draw/release) | ABILITY (Volley) | DASH (Backflip Shot) | ULTIMATE (Arrow Storm) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Fan | Aura twinkle on the limb tip; the string glows faintly at full draw. Arrows use style `arrow` with a 2-dot trail. | Arrows leave a 3-dot `trail` | **Fan**: 7 arrows (fan 0.14 rad apart) instead of 5; the centre arrow is a "lead arrow" (pierce 2, gold, `expose_secs` 1.5, size 1.2). | - | locked | chill |
| 3 Overdraw | Tip glow; at full draw a white ring closes around the nock (aura `state` = draw 0..100). | **Overdraw**: a PERFECT shot splits: `split 2` children at +-0.35 rad (40% damage, same style) plus a `star` count 5 r 12 at the bow and a `flash` r 10. Shots that are fully drawn but not perfect get a white trail. | = | = | unlocked; a `sigil` r 38 count 6 at the cursor lands 0.4 s before the finale (the finale telegraph). | chill |
| 4 Smoke Roll | 2 orbit motes (fletch), gem pixel. | = | = | **Smoke Roll**: the dash shot is a 3-arrow fan (centre 2.0, sides 0.6 each, +-0.2 rad) and you leave a smoke puff: `motes` count 8 r 24 and a `slow` patch (`WeaponUtil.patch`, r 24, factor 0.55, 2.0 s). The dash is a `streak`. | = | chain |
| 5 Rainstorm | 4 motes, ghost of the limb, trail on the arrow. | = | = | = | **Stage 2 Rainstorm**: 1.0 s after the slam, 8 arrows fall around the cursor (r 60): `ground_strike` r 10, 0.45 s, 1.4 each (0.54 H), each drawn as a `fall` arrow (radius 2, height 80); `ripple` r 60 rings 2 as the telegraph. | chain |
| 6 Skyfall | Halo ring, 5 motes, tip star. | **Finisher** every 6th fully drawn shot: **Piercing Gale**: a thin `beam` 110 long, all enemies on the line take 0.5 H (1.3) and the arrow itself pierces 4. | = | = | **FINALE Skyfall**: the finale slam becomes a `fall` giant arrow (radius 6, height 150, life 0.4) landing in a r 48 `ground_strike` (4.0, stun 0.6, +`pillar` height 90) that bursts into 6 radial arrows (`WeaponProjectile` style `arrow`, 1.2 each, speed 260, life 0.35, pierce 1). Shake 5, `Sfx big_hit`. | lifesteal |

Caps (H = 2.6): attack finisher avg +0.1 H, overdraw children 40% x 2 on perfect only; ability +2 arrows (3.0) + exposure; dash +0.46 H; ultimate stage 2 up to 2.8 on one target + finale 4.0 + radial arrows 2.4 vs today ~26 (a storm target gets 4 to 8 arrows) = +60%.

## What makes this feel like Uncommon
Compared with Spear (Common) the bow has two layers to play with: draw timing and aim; each tier adds one more arrow trick (a fan, a split, a smoke roll, a rain, a giant arrow) but they stay separate verbs, never overlapping. The finale is a second shape over the first (rain then a big arrow); a Common's finale is a single pop.

## Rules for the implementer
- `items/weapons/tiers/bow.gd`; `WeaponProjectile` upgrades (`style`, `trail`, `split`, `expose_secs` exists). Edits in `bow.gd`: `ability()` count and centre arrow params, `release_item()` after the shot (perfect -> `split`, shot counter `_st.shots` for the finisher incl. `WeaponTiers.run(self, "release")` at its end), `dash_attack()` side arrows and patch, `ultimate()` finale values by tier (finale call at the end of the loop; tier 5 rain scheduled with `create_timer(1.0)`).
- Constants: `BOW_FAN := 7`, `BOW_SPLIT := 2`, `BOW_SPLIT_MULT := 0.4`, `BOW_ROLL_SIDES := 0.6`, `BOW_RAIN_N := 8`, `BOW_RAIN_R := 60.0`, `BOW_RAIN_DMG := 1.4`, `BOW_FINISHER_EVERY := 6`, `BOW_FINALE_R := 48.0`.
- The Warp Bow and Stormcaller Bow inherit `bow.gd` (`extends "res://items/weapons/bow.gd"`): the `weapon_id` differs, so the `tiers/bow.gd` module is NOT run for them (the dispatcher uses `w.weapon_id`); their own modules `preload` this one when they want these functions.
- Multiplayer: the aura's `state` carries the draw ratio so clients see the closing ring. Projectiles are net nodes (cap 40).
- Performance: tier 6 volley 7 arrows + 2 splits at most = 9 projectiles; ultimate peak about 14 fx + 20 projectiles.

## How to test (section `bow`)
1. Fan: tier 2 Volley: `count_script("projectile.gd")` right after >= 7 (tier 1: 5); the centre arrow exposes a dummy in line (`is_exposed`).
2. Overdraw: tier 3 perfect shot (hold 0.9 s): projectile count 3 within 0.1 s of the first hit; tier 2 only 1; kind `star` seen.
3. Smoke Roll: tier 4 dash: 3 arrows spawned, one `slow` hazard (radius 24) exists; tier 3 has 1 arrow and no hazard.
4. Rainstorm: tier 5 ultimate: >= 8 extra `fall` fx kinds seen between 1.3 s and 2.8 s; tier 4 none; a dummy at the cursor takes extra >= 1.4.
5. Skyfall: tier 6: `fall` radius 6 seen, 6 projectiles spawn at impact; tier 5 none. Finisher: 6th full draw spawns kind `beam` and hurts a dummy 100 px away.
6. Draw smoke; `release` does not double-fire at tier 6.
