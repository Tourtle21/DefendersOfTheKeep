# Siege Lance (`lance`, Uncommon, pierce, fusion tier 2 of Hammer + Spear, H = 3.64)

## Today
- Attack Impale: `thrust(14)`, `line` fx 52 long, tip (>= 34 px) 1.0 H with knock 240 and a gold `ring` r 14, shake 2; closer hits 0.5 H. Charge (hold right click, tier 2+, cd 7): you move at 50% for up to 1.0 s while a line and a ring preview the ram; release dashes 60 + 90 x ratio px in 0.2 + 0.1 x ratio s, hits 4 + 4 x ratio along the way (knock 260), and ends with a ring r 26 + 20 x ratio hitting 3.0, knock 300, stun 0.8.
- Pole Vault (cd 4): 70 px dash + `ground_strike` r 22, 2.0, stun 0.3. Dragoon Dive (tier 3+, cd 60): dash to the cursor (range 130) and a `ground_strike` r 50, 0.4 s, 10.0, knock 360, stun 1.5.
- Combines the Spear's tip rule and the Hammer's hold-to-charge. The gold line is the only art.

Palette: steel-gold `Color(1.0,0.90,0.50)`, ram gold `Color(1.0,0.80,0.20)`, shock white `Color(1.0,0.98,0.85)`, shaft `Color(0.70,0.45,0.25)`. Names: 2 Shock Cone, 3 Long Lance, 4 Spikefall, 5 Reverb, 6 Dive Bomb.

## Tier table (fusion tier 2: rows 2 to 6; must out-spectacle Hammer and Spear at the same tier)

| Tier | ART | ATTACK | ABILITY (Charge) | DASH (Pole Vault) | ULTIMATE (Dragoon Dive) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Shock Cone | Both parents' marks: gold spearhead with a hammer-like collar glint; aura twinkle; while charging the tip heats from gold to white (aura `state`). Entry twist thunder. | Tip hits throw a gold `burst` r 10 | **Shock Cone**: the ram ends with a forward `cone` (r 56, half angle 0.6, `ram gold`) hitting what is ahead of the end point for 0.8 H (2.9), knock 300; the ring becomes a `shock` r = ring radius (thick 5). | - | locked | thunder |
| 3 Long Lance | Tip glow; swing ghost. | **Long Lance**: every 3rd Impale is 70 long (`streak` width 5), the tip zone starts at 48, everyone in line takes at least 0.5 H and the tip +1.0 H; `star` count 4 at the end. | = | = | unlocked; a `sigil` r 50 at the landing point appears the moment you press (the dive takes 0.35 s to arrive). | thunder |
| 4 Spikefall | 2 gold motes, gem pixel. | = | = | **Spikefall**: the vault is a visible hop (weapon sprite rises 5 px, shadow ellipse stays); at the landing three lance spikes erupt in a triangle of side 26 around the landing point (strike r 12, 0.3 s, 0.8 H = 2.9, knock 180, `crack` count 3). Dash is a `streak`. | = | bleed |
| 5 Reverb | 4 motes, trail on the lance head. | = | = | = | **Stage 2 Reverb**: after the crash two `ripple` rings expand at 0.4 s and 0.8 s (r 70): each hits 0.5 H (1.8) with knock 160 and slows 0.6 for 1 s. | bleed |
| 6 Dive Bomb | Halo ring, 5 motes, tip star. | **Finisher** every 6th Impale: the entire line counts as the tip (full damage) and a forward `cone` (r 60, 0.8 H) follows. | = | = | **FINALE Dive Bomb**: the dive starts with a leap (0.35 s travel; `fall` comet radius 8 height 120 over the landing point at +0.0 s), lands with `flash` r 60 + `pillar` height 100 + `shock` r 70 thick 7, stun 2.0 on the crash, and 6 radial lances (`WeaponProjectile` style `lance`, 1.0 H = 3.6, pierce 2, speed 280, life 0.35). Shake 5, `Sfx thump` + `big_hit`. | chill |

Caps (H = 3.64): attack avg +0.25 H; ability +0.8 H; dash +0.8 H (3 spikes only one typically hits: 0.8); ultimate: ripples 2 x 1.8 + lances 3.6 vs today 10.0 = +72%.

## What makes this feel like Uncommon
It merges two Common ideas (Spear tip, Hammer charge) and adds one new layer per tier. Compared with Spear tier 6 (a single huge falling spear), the Lance's dive is a leap, a crash, ripples and radial lances: a second, wider layer, but still one clear blast.

## Rules for the implementer
- `items/weapons/tiers/lance.gd` (may `preload` `spear.gd` module for the Skewer-style helper). Edits in `lance.gd`: `attack()` length from `_st.long` (set by `pre_attack` every 3rd), `release_ability()` (cone after the ram; end of function `WeaponTiers.run(self, "release")`), `dash_attack()` landing spikes, `ultimate()` finale/stage 2 (module schedules ripples at +0.75 s and +1.15 s after the press since the dive takes 0.35 s plus the 0.4 s telegraph).
- Dragoon Pike `extends lance.gd`; it owns its module. The Pike must not run Lance riders twice: dispatch is by `w.weapon_id`, so the Pike's module explicitly calls `preload("lance.gd")` functions it wants.
- Constants: `LANCE_CONE_R := 56.0`, `LANCE_CONE_HALF := 0.6`, `LANCE_CONE_MULT := 0.8`, `LANCE_LONG_EVERY := 3`, `LANCE_LONG_LEN := 70.0`, `LANCE_SPIKES := 3`, `LANCE_SPIKE_MULT := 0.8`, `LANCE_REVERB := [[0.4, 70.0], [0.8, 70.0]]`, `LANCE_RADIAL := 6`, `LANCE_STUN := 2.0`.
- Multiplayer: nothing beyond the aura `state` (charge). Performance: finale about 18 fx and 6 projectiles.

## How to test (section `lance`)
1. Shock Cone: tier 2 ram at a dummy 20 px beyond the end point (inside the cone, outside the ring): it takes >= 0.8 H; tier 1 not; kind `cone` seen.
2. Long Lance: tier 3, the 3rd Impale reaches a dummy at 66 px; thrusts 1 and 2 do not.
3. Spikefall: tier 4 vault: dummies at the 3 triangle corners each take 0.8 H within 0.6 s; tier 3 none; three `crack` kinds.
4. Reverb: tier 5 dive: a dummy at 60 px from the landing takes damage in three steps (crash zone does not reach: r 50; ripple 1; ripple 2); tier 4 none.
5. Dive Bomb: tier 6: 6 projectiles with style `lance` after the crash; kinds `fall`, `flash`, `pillar`, `shock` seen; a dummy at the crash is stunned >= 1.8 s.
6. Draw smoke; charge ratio still scales distance at tier 6.
