# Hammer (`hammer`, Common, crush, H = 5.1)

## Today
- Attack Smash: `swing(1.1)`, 0.2 s later an orange `ring` r 26 at 22 px ahead, 1.0 H, knock 260, shake 1.5, breaks stones. Charged Slam (hold right click, tier 2, cd 7): you move at 45% speed up to 1.2 s; radius 30 + 40 x ratio, damage 2 + 4 x ratio (x1.5 if released in the gold window from 0.95 s), stun 0.5 + 1.5 x ratio, breaks stones and sticks; a growing preview ring while charging.
- Leap Slam (cd 5): 70 px dash and a `ground_strike` r 30, 0.22 s, 3.0, knock 260, stun 0.5. Meteor (tier 3): `ground_strike` at the cursor (range 120) r 60 after 1.0 s, 12.0, knock 400, stun 2.0.
- Looks: orange rings and a gold ring for the perfect release.

Palette: iron `Color(0.62,0.66,0.72)`, ember `Color(1.0,0.55,0.20)`, gold `Color(1.0,0.85,0.20)`, dust `Color(0.80,0.70,0.50)`. Names: 2 Ripple, 3 Ground Pound, 4 Crater Leap, 5 Shatter, 6 Worldfall.

## Tier table

| Tier | ART | ATTACK | ABILITY (Charged Slam) | DASH (Leap Slam) | ULTIMATE (Meteor) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Ripple | Aura twinkle on the head; during the charge the head glows `ember` growing with ratio (aura `state` = charge 0..100). | Smash hits spawn `shards` (count 3, r 14, `dust`) | **Ripple**: 0.25 s after the slam a second ring (1.5 x radius) hits for 40% of the slam damage, `push` 200, and chills (`apply_slow(0.5, 1.5)`); `ripple` fx rings 2. The gold perfect release also draws a `star` count 6. | - | locked | bleed |
| 3 Ground Pound | Tip glow, swing trail. | **Ground Pound**: every 3rd smash: `shock` r 40 (thick 6) and `crack` count 6; the hit circle grows to r 36 and deals +1.0 H, knock 340; breaks stones in the larger circle. | = | = | unlocked; a `sigil` r 60 with count 8 during the 1.0 s telegraph (the plain ring remains). | bleed |
| 4 Crater Leap | 2 orbit motes (dust), gem pixel. | = | = | **Crater Leap**: the leap is a visible arc (the aura draws a shadow ellipse that stays on the ground and the weapon rises 4 px); the landing is a `shock` r 38 + `crack` count 6; radius 30 to 40, stun 0.5 to 0.8, and `shards` count 8 fly to an outer ring r 55 hitting for 0.5 H (2.6). | = | chill |
| 5 Shatter | 4 motes, swing ghost. | = | = | = | **Stage 2 Shatter**: 0.4 s after impact 6 rock fragments crash around the crater (`fall` radius 3 + `ground_strike` r 16, ring at radius 50 with a 0.45 s telegraph, 0.6 H = 3.0, knock 220); the crater gets 4 `crack` lines that last 2 s. | chill |
| 6 Worldfall | Halo ring, 4 motes, tip star. | = | = | = | **FINALE Worldfall**: the Meteor is preceded by a `fall` comet (radius 8, height 140, life = the 1.0 s telegraph), and the impact is a `flash` r 70 + `shock` r 70 thick 8 + `crack` count 10; the crater stays as a `slow` patch (r 60, factor 0.5, 4 s). 1.2 s after impact an echo quake r 84 deals 0.6 H x 2 = 6.0 (one hit), knock 260, stun 0.5. Shake 5, `Sfx thump` then `big_hit`. | chain |

Caps (H = 5.1): attack avg +0.3 H; ability ripple 40% of slam = +40%; dash +0.5 H; ultimate stage 2 3.0 + finale 6.0 vs today 12 = +75%.

## What makes this feel like Common
Heavy, readable and slow: each upgrade is a bigger or repeated impact, never a status system. The most complex thing is the gold-window release, which already exists. Compare with Bulwark Maul (Epic fusion with the Shield), whose brace stores hits; the Hammer simply hits the ground harder.

## Rules for the implementer
- `items/weapons/tiers/hammer.gd`; edits inside `hammer.gd`: `release_ability` (add the ripple after the slam using a `create_timer(0.25)`; call `WeaponTiers.run(self, "release")` at the end), the Smash counter via the module (`attack`, count `_st.smashes`; the module waits 0.2 s to line up with the hit), `dash_attack` (landing extras in `dash(w)` after `await 0.24`).
- Aura state: `weapon_aura.state` = `int(_charge / MAX_CHARGE * 100)` set by the hammer while charging (the hammer sets `_st.aura_state`; `tick(w, delta)` copies it to the aura).
- Constants: `HAMMER_RIPPLE_DELAY := 0.25`, `HAMMER_RIPPLE_R := 1.5`, `HAMMER_RIPPLE_MULT := 0.4`, `HAMMER_POUND_EVERY := 3`, `HAMMER_POUND_R := 36.0`, `HAMMER_LEAP_R := 40.0`, `HAMMER_FRAGMENTS := 6`, `HAMMER_ECHO_MULT := 6.0`.
- Meteor stays `ground_strike(cursor_target(120), 60, 1.0, ...)`; the module adds fragments at 1.4 s and the echo quake at 2.2 s after the press, with `_claim()` before hits; the cursor is captured at the press.
- Bosses: the stun of the echo uses `WeaponUtil.stun`.
- Multiplayer: nothing new beyond the aura. Performance: peak about 16 fx (6 fragment rings x2 → draw only the `fall`s and one ring each, 12), 1 patch.

## How to test (section `hammer`)
1. Ripple: tier 2 charged slam with a dummy at 1.3 x radius: it takes ~0.4 x slam damage (> 0) and has `slow_mult <= 0.51`; tier 1 untouched; fx `ripple` seen.
2. Ground Pound: tier 3, 3 smashes, dummy at 33 px (outside 26, inside 36): only the 3rd hurts it; fx `shock` and `crack` seen.
3. Crater Leap: tier 4 leap landing next to a dummy at 52 px: it takes ~0.5 H; stun on a dummy at 38 px lasts >= 0.7 s; tier 3 none.
4. Shatter: tier 5 Meteor: fragments land at radius 50: a dummy there loses ~3.0 extra within 1.5 s; tier 4 none.
5. Worldfall: tier 6: kind `fall` radius 8 seen during the telegraph, a `slow` hazard (radius 60) exists 0.2 s after impact, and the echo hit (6.0 within 1.5 s to 2.5 s) lands; tier 5 neither.
6. Draw smoke; aura `state` rises during the charge.
