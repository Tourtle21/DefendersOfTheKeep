# Rapier (`rapier`, Rare, pierce, fusion tier 2 of Daggers + Spear, H = 2.33)

## Today
- Attack Thrust: every thrust steps you 8 px forward, `line` fx 46, `enemies_in_line` (half width 9). Three thrusts within 0.55 s each: the third (or the first after Evade, `_primed_until` 1.2 s) is `big`: x2.5, knock 200, thicker line.
- Fleche (tier 2+, cd 6): dash-stab at the nearest enemy in a 120-degree cone within 110 px (4.0, knock 120); press again within 0.8 s to chain (3 stabs total, then full cooldown; a missed chain costs 4 s, a miss with no target 0.4 s). Evade (cd 3.5): 45 px dash, primes the next thrust 1.2 s. Thousand Stabs (tier 3+): 12 thrusts every 0.1 s (1.5 each) along your aim, `line` 56.
- Looks: thin white lines; no marks.

Palette: steel `Color(1.0,0.92,0.92)`, rose `Color(1.0,0.60,0.65)`, gold `Color(1.0,0.90,0.50)`, flash `Color(1.0,1.0,1.0)`. Names: 2 Flicker, 3 Riposte Rhythm, 4 Afterimage, 5 Duelist's Dance, 6 Final Lunge.

## Tier table (fusion tier 2: rows 2 to 6; must out-do Daggers and Spear at the same tier)

| Tier | ART | ATTACK | ABILITY (Fleche) | DASH (Evade) | ULTIMATE (Thousand Stabs) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Flicker | The blade is long and thin: aura draws a 2 px white after-line 6 px behind the tip while thrusting; entry has twist bleed (est.). | Every thrust ends in a `cut` r 8 (tiny) at the tip | **Flicker**: each stab leaves a rose `streak` and a mark: the target is exposed 2 s; the 3rd stab of a chain is a double (two instant hits of 2.0) and a `flash` r 14. | - | locked | bleed |
| 3 Riposte Rhythm | Tip glow; a rose swing ghost. | **Rhythm**: the 2nd thrust in a rhythm also fires a thin wave: `WeaponProjectile` style `lance`, size 0.8, 0.6 H, pierce 2, speed 300, life 0.25; the big 3rd thrust throws a `star` count 4 r 14 and breaks stuns (a short `flash` r 10). | = | = | unlocked; the thrusts each draw a `streak` and the line preview becomes a rose `beam` (width 3, life 0.1). | bleed |
| 4 Afterimage | 2 orbit motes (rose), gem pixel. | = | **Afterimage**: each Fleche leaves a phantom at its start (`orbit` shape `blade` count 1 r 6 life 0.6); 0.6 s later it stabs the same target again (1.0 H = 2.3, exposed target = x1.5). | **Afterimage Evade**: the dash is a `streak` (width 5, rose) and leaves a phantom at the start that after 0.5 s thrusts (whole 46-line toward the aim you had, 1.0 H). | = | chill |
| 5 Duelist's Dance | 4 motes, rose ghost trail. | = | = | = | **Stage 2 Dance**: during the 12 thrusts you slide forward 6 px each (a 1.2 s lunge of ~70 px; `player.dash` micro steps) and every 4th thrust (3 times) is a flurry: 3 hits in 0.15 s, a `cone` r 56 half 0.5 and `burst` r 14. Between thrusts, 6 phantoms (`orbit` shape `blade`) join the line. | chill |
| 6 Final Lunge | Halo ring, 6 motes, tip star. | **Finisher** every 6th thrust: a 20-px pierce-through teleport (you end beyond the first enemy) and a `cut` r 18; no extra damage, plus +0.5 H on the first enemy. | = | = | **FINALE Final Lunge**: a last great lunge 110 px in the aim direction (dash 0.12 s) hitting everything on the line for 2.0 H (4.7) with knock 260 and a `beam` (width 10, white-rose) along it; at the end `flash` r 40 and a `shock` r 40 (1.0 H, stun 0.8); shake 5.5, `Sfx big_hit` + `ultimate`. | thunder |

Caps (H = 2.33): attack avg +0.2 H; ability: afterimage 2.3 per target; dash 1.0 H; ultimate: flurries 3 x (3 x 1.5) is spread; finale 4.7 + shock 2.3 vs today 12 x 1.5 = 18: +39%.

## What makes this feel like Rare (and beat Daggers + Spear)
It is a rhythm weapon: the third thrust, the chain of three, the phantom that repeats your move. Compared with Spear (Common) where upgrades add one pattern each, the Rapier asks you to keep time and its phantoms echo your own moves. Compared with Daggers (Uncommon), the Rapier's mark/expose are used for burst timing rather than a crowd.

## Rules for the implementer
- `items/weapons/tiers/rapier.gd`; `rapier.gd` edits: `attack()`: the wave on the 2nd thrust (`_combo == 2` before reset) and star on big; `_fleche()`: the exposure and double on stab 3 (at tier 2) and the phantom schedule at tier 4 (`create_timer(0.6)`; must re-find the target by stored reference and check validity); `dash_attack()` phantom thrust; `ultimate()`: add micro-slide per thrust (`player.dash(aim, 6, 0.05)`) and the flurry/phantoms; the finale after the loop (module schedules at 1.3 s).
- Dragoon Pike inherits lance (not rapier): its module borrows `rapier.gd` functions by `preload`.
- Constants: `RAP_WAVE_MULT := 0.6`, `RAP_PHANTOM_T := 0.6`, `RAP_PHANTOM_MULT := 1.0`, `RAP_FLURRY_EVERY := 4`, `RAP_FLURRY_HITS := 3`, `RAP_LUNGE := 110.0`, `RAP_FINALE_MULT := 2.0`, `RAP_FINISHER_EVERY := 6`.
- Phantom hits: `_claim()` before every hit; `quiet = true` for phantom thrusts after the first target.
- Multiplayer: phantoms are fx only. Performance: finale about 16 fx.

## How to test (section `rapier`)
1. Flicker: tier 2 Fleche: the target is exposed afterwards; the 3rd stab of a chain deals 2 hits (health delta ~4.0 vs 2.0 for the 1st).
2. Rhythm: tier 3, 2 thrusts: a `WeaponProjectile` appears after the 2nd (tier 2: none); it hits a dummy 100 px away.
3. Afterimage: tier 4 Fleche: the target takes a second hit of >= 2.3 ~0.6 s later; tier 3 not. Dash phantom: a dummy 30 px ahead of the aim takes a hit 0.5 s after the dash.
4. Dance: tier 5 ultimate: the player advances > 40 px; at least 3 `cone` kinds seen; tier 4 stays in place (within 5 px).
5. Final Lunge: tier 6: kind `beam` seen, the player moved >= 100 px beyond the thrust end, a dummy on the line takes >= 4.7 extra; tier 5 not.
6. Draw smoke tiers 1-6; thrust finisher teleports 20 px at the 6th thrust.
