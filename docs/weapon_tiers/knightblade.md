# Knight's Blade (`knightblade`, Epic, no element, fusion tier 2 of Shield + Sword, H = 3.08)

## Today
- Attack: 3-hit combo (cd 0.32, window 0.7 s): hits 1 and 2 are `arc` r 30 (+-55 degrees) 1.0 H, knock 100; the third is big: `arc` r 40 (+-80 degrees), 2.5 H, knock 300, shake 2.5, gold arc, then the combo resets. Riposte (tier 2+, cd 3): `parry_time` 0.6 s; if hit in the window you dash THROUGH the attacker (up to 70 px, 0.12 s) hitting 6.0 on the way (`start_dash_hits`), cd back to 1.5 s; a whiff costs 4.5 s.
- Slash Dash (cd 4): 60 px dash, a slash at the end (2.5), and primes the combo so the next hit is already the big third. Judgment (tier 3+): `shield_time` 1.2 s and 3 pulses r 56 every 0.3 s (6.0 each, knock 300, stun 0.3).
- Looks: white / gold arcs.

Palette: blade white `Color(0.92,0.96,1.0)`, gold `Color(1.0,0.90,0.50)`, blue steel `Color(0.55,0.70,0.95)`, crest `Color(0.85,0.20,0.20)`. Names: 2 Oathkeeper, 3 Crescent Third, 4 Counter-Thrust, 5 Knight's Vow, 6 Judgment Day.

## Tier table (fusion tier 2: rows 2 to 6)

| Tier | ART | ATTACK | ABILITY (Riposte) | DASH (Slash Dash) | ULTIMATE (Judgment) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Oathkeeper | A cross-guard with a shield crest glows on the blade; aura twinkle; while the riposte window is open, a white rim `ring` hugs you (aura `state` 1). Combo counter shown as 3 pips next to the hilt (aura `state` bits). | The third strike throws a `slash` (r 40, thick 5, gold) and `shards` count 4 | **Oathkeeper**: a successful riposte also shields you 0.5 s and pushes everything within 40 px of the attacker (150); `star` count 5 at the attacker; a whiffed riposte costs 3.5 s (not 4.5): the window grows to 0.7 s. | - | locked | lifesteal |
| 3 Crescent Third | Tip glow; blue trail. | **Crescent Third**: the third strike also fires a crescent (`WeaponProjectile` style `crescent`, size 1.3, 1.0 H = 3.1, pierce 3, speed 260, life 0.4). | = | = | unlocked; `sigil` r 70 count 3 (three swords) 0.3 s before pulse 1. | lifesteal |
| 4 Counter-Thrust | 2 orbit gold motes, gem pixel. | = | **Counter-Thrust**: after the riposte dash you strike back the way you came: a 0.1 s later `slash` hits everything within 50 px of the arrival point for 1.5 H (4.6) and the attacker is exposed 3 s; the dash is a `streak` width 8. | **Vanguard Dash**: the dash is a `streak` (width 7); the arrival slash is a `slash` r 40 hitting 3.5 (1.2 H) and the next TWO hits of the combo are big (primes `_combo = 1`, so the next hit is the second and the third big; a pair of big strikes follows). | = | thunder |
| 5 Knight's Vow | 4 motes, blade ghost. | = | = | = | **Stage 2 Knight's Vow**: the 3 pulses become 3 great arcs in a rotating fan (each pulse a 120-degree `cone` r 70 toward 3 directions: aim, aim + 120, aim - 120; hits all inside 3.0 H each), and 3 spectral swords (`orbit` shape `blade` count 3, r 26, life 0.4 re-spawned) circle you for 3 s, cutting every 0.5 s within 20 px for 0.5 H (1.5, quiet). | thunder |
| 6 Judgment Day | Halo ring, 6 motes (gold), tip star. | **Finisher** every 3rd combo (the 9th hit): a rising gold `pillar` height 60 under the target and 1.0 H (the 3rd of a combo of 3 is already big: this adds a 4th hit, 0.5 s later, a vertical downstrike `cut` r 18). | = | = | **FINALE Judgment Day**: a giant sword falls at your position after the vow (`fall` radius 8 height 140, then `sigil` r 80 count 8 for 0.5 s): all within 80 px take 2.0 H (6.2), knock 380, stun 1.2; `pillar` height 120 width 30, `flash` r 80, `ripple` r 100 rings 3; your own `shield_time` extends 0.6 s. Shake 6, `Sfx ultimate`. | chain |

Caps (H = 3.08): attack avg +0.4 H (crescent 1.0 H / 3 = 0.33); ability counter 1.5 H + push; dash 1.2 H; ultimate: pulses unchanged 6.0 x 3, stage 2 cutting 5 x 0.5 H, finale 6.2 vs today 18.0 = +80%.

## What makes this feel like Epic
A duellist's rhythm turned into a ritual: gold crests, spectral swords, a giant sword. Compared with Rapier (Rare), whose rhythm is fast thrusts, the Knight's Blade has stance and set pieces: counter-attacks and a three-act ultimate. It stays formal and readable (white and gold).

## Rules for the implementer
- `items/weapons/tiers/knightblade.gd`; `knightblade.gd` edits: `_on_riposte` (shield, push, counter-thrust timer 0.1 s, exposure), `ability()` window 0.7 s and whiff cooldown 3.5 at tier >= 2 (constants), `attack()` crescent at `big` (module `attack(w)` checks `_st.last_big`; set in the old function: `_last_big = big`), `dash_attack()` unchanged: tier 4 sets `_combo = 1` and the blade strikes (the old sets `_combo = 2`: change to `_combo = 1 if tier >= 4 else 2` and mark `_st.double_big = 2`), `ultimate()` unchanged: the module replaces `pulse_around` at tier >= 5 (flag), schedules the swords and the finale at 1.2 s.
- Constants: `KB_RIPOSTE_WINDOW := 0.7`, `KB_WHIFF := 3.5`, `KB_COUNTER_MULT := 1.5`, `KB_CRESCENT_MULT := 1.0`, `KB_VOW_R := 70.0`, `KB_SWORDS := 3`, `KB_SWORD_SECS := 3.0`, `KB_FINALE_MULT := 2.0`, `KB_FINISHER_EVERY := 9`.
- Multiplayer: nothing new. Performance: finale ~25 fx; swords 1 `orbit` fx per 0.4 s.

## How to test (section `knightblade`)
1. Oathkeeper: tier 2 successful riposte (call `player.take_damage` in the window): shield_time >= 0.4 afterwards and a dummy within 40 px of the attacker is pushed; whiff cooldown 3.5.
2. Crescent Third: tier 3, three hits: a projectile of style `crescent` spawns on the 3rd only and hits a dummy at 90 px.
3. Counter-Thrust: tier 4: after a riposte the area around the arrival takes 1.5 H at +0.1 s; dash makes the next two combo hits big (damage 2.5 H on both).
4. Vow: tier 5 ultimate: three `cone` kinds seen over 1 s (not `ring`); a dummy within 20 px of the sword radius takes extra hits for 3 s; tier 4 none.
5. Judgment Day: tier 6: `fall` radius 8 and `flash` r 80 seen; a dummy at 70 px takes >= 6.2 and is stunned.
6. Draw smoke; combo pips in aura `state` follow `_combo`.
