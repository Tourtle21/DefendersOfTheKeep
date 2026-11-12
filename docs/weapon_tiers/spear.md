# Spear (`spear`, Common, pierce, H = 2.7)

## Today
- Attack Thrust: `thrust` plus a `line` fx 44 long; `enemies_in_line` (half width 9). A hit at 30 px or more along the line ("the tip") deals 1.0 H, knock 200 and a gold `ring` r 12 with shake 1.5; closer hits deal 0.5 H, knock 120.
- Javelin (tier 2, cd 6): a `WeaponProjectile` speed 330, dmg 4.0, life 0.4, pierce 2. Lunge (cd 5): 80 px dash, hits 4.0, knock 220, and a connecting Lunge cuts the dash cooldown to 35% (chain lunges). Spear Rain (tier 3): `rain` at the cursor (range 120), r 55, 12 javelins over 1.5 s, 4.0 each, strike r 14.
- Looks: one white line, a small gold ring on tip hits, blue-white rain rings.

Palette: steel `Color(0.90,0.95,1.0)`, tip gold `Color(1.0,0.85,0.30)`, shine `Color(1.0,1.0,1.0)`, shaft `Color(0.70,0.50,0.30)`. Names: 2 Barbed, 3 Skewer, 4 Primed, 5 Second Wave, 6 Heaven's Spear.

## Tier table

| Tier | ART | ATTACK | ABILITY (Javelin) | DASH (Lunge) | ULTIMATE (Spear Rain) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Barbed | Aura twinkle at the spear tip; a 1 px white glint runs up the blade every 1.6 s. | Tip hits spawn 2 `shards` (r 10, `tip gold`) | **Barbed**: the javelin is a long `lance` style (size 1.2, trail 4) with pierce 3 (from 2) and every enemy it passes is exposed for 1.5 s (`WeaponUtil.expose`, so the next hit is a backstab-like bonus for weapons that read it and stunned/exposed enemies glow with 2 `motes`); an `orbit`-free design: a gold `burst` r 8 at each victim. | - | locked | chain |
| 3 Skewer | Tip glow; the thrust leaves a faint 4-frame ghost of the blade. | **Skewer**: every 3rd thrust is 62 long (not 44): `streak` width 4 (white, `tip gold` core), `star` count 4 r 10 at the end; the tip zone starts at 44; tip hits +1.0 H; everyone on the line takes at least 0.5 H. | = | = | unlocked; a `sigil` r 55 for 0.25 s at the cursor; strikes now draw a `fall` javelin (radius 3, height 70, life = telegraph 0.45 s) and a `burst` on landing. | chain |
| 4 Primed | 2 orbiting gold motes, gem pixel. | = | = | **Primed**: a Lunge that connects primes the next thrust for 1.5 s: the WHOLE line counts as the tip (full damage), the `streak` is gold and a `flash` r 14 shows at the tip; `Sfx whoosh` pitch 1.4. The dash itself is a `streak` (width 6). | = | lifesteal |
| 5 Second Wave | 4 motes, swing ghost, trail. | = | = | = | **Stage 2 Second Wave**: 1.0 s after the last strike, a second volley: up to 6 spears (`ground_strike`, strike r 14, delay 0.45, 1.1 H = 3.0, knock 160) aimed at the 6 enemies nearest to the cursor within 110 px (random points around the cursor if fewer than 6 enemies). A `ripple` r 60 rings 2 marks the re-aim. | lifesteal |
| 6 Heaven's Spear | Halo ring, 4 motes, tip star. | **Finisher**: no (one upgrade at this tier). | = | = | **FINALE Heaven's Spear**: 0.5 s after the second wave a gigantic spear drops at the cursor: `fall` radius 7 height 130, the ring telegraph r 32 for 0.5 s, then `ground_strike` 1.5 H (4.0), knock 300, stun 0.6; `pillar` height 100 width 24, `shock` r 38, shake 4.5, `Sfx big_hit`. | thunder |

Caps (H = 2.7): attack +0.3 H avg; ability +exposure only (+0 damage); dash +0 damage (primed doubles one thrust at most once per lunge); ultimate stage 2 3.0 + finale 4.0 per target vs today up to 12 x 4.0 spread over 55 radius (a target in the middle usually eats 3 to 4 spears, about 14).

## What makes this feel like Common
Every upgrade is still about reach and spacing, the spear's one idea. No new resource is tracked; the rain is the biggest spectacle and it is a single pattern repeated. Compare with Lance (Uncommon fusion), which turns the same thrust into a charged ram, and Rapier (Rare), which adds footwork rhythm.

## Rules for the implementer
- `items/weapons/tiers/spear.gd` + small edits in `spear.gd`: Javelin params (`style`, `pierce 3`, `expose_secs 1.5` through the `extra` dict at tier >= 2), thrust length constant `LEN := 44.0` read from `WeaponTiers`-supplied `skewer` flag (`attack()` takes `len = 62.0 if _st.skewer else 44.0`; the module sets `_st.skewer` before the old `attack()`: so for this weapon the hook for attack must run BEFORE the old function, add `WeaponTiers.run(self, "pre_attack")` as an optional pre-hook in `use_item`).
- Primed: in `_on_dash_hit` (module `dash_hit(w, e)`) set `_st.primed_until = now + 1.5`; consumed by the next `attack()` (full damage on the whole line, `_st.primed_until = 0`).
- Constants: `SPEAR_SKEWER_EVERY := 3`, `SPEAR_SKEWER_LEN := 62.0`, `SPEAR_PRIMED_T := 1.5`, `SPEAR_WAVE_N := 6`, `SPEAR_WAVE_MULT := 1.1`, `SPEAR_FINALE_MULT := 1.5`.
- Spear Rain is `rain(...)` which awaits per strike; the module's `ultimate(w)` schedules the wave at 2.5 s and the finale at 3.3 s with `create_timer`, each guarded by `is_instance_valid(w)` and `w._claim()`. The cursor point is captured at press time (`w.cursor_target(120.0)`) and stored in `_st`.
- Multiplayer: strikes use the existing `ground_strike`; `fall` is a `WeaponFx`.
- Performance: second wave 6 x 2 fx + finale 6 fx; peak about 40 fx including the rain; the rain's own 12 strikes are grandfathered.

## How to test (section `spear`)
1. Barbed: tier 2 javelin through 3 dummies in a line: all three damaged and exposed (`WeaponUtil.is_exposed`); tier 1 reaches only 2 and exposes none.
2. Skewer: tier 3, three thrusts; dummy at 56 px: only the 3rd thrust hurts it; fx `streak` seen on the 3rd; tier 2 never hurts it.
3. Primed: tier 4, a connecting Lunge then a thrust at a dummy at 15 px (normally 0.5 H): damage equals 1.0 H within 5%; 2 s later a thrust is back to 0.5 H.
4. Second Wave: tier 5 ultimate with 3 dummies 80 px from the cursor: each takes damage from the wave (second burst of damage 2.5 to 3.5 at ~2.5 s); tier 4 only the rain.
5. Heaven's Spear: tier 6: fx `fall` radius 7 and `pillar` seen; the cursor dummy takes >= 4.0 more than tier 5 at ~3.5 s and is stunned.
6. Draw smoke; lunge cd refund still works at tier 6.
