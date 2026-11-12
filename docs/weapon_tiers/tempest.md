# Tempest Lash (`tempest`, Mythic, no element, fusion tier 2 of Staff + Whip, H = 4.82)

## Today
- Attack Chain lightning (cd 0.45): the nearest enemy in a 75 px, +-28 degree arc is hit for 1.0 H (knock 40), then jumps up to 2 more times to the nearest un-hit enemy within 45 px (hits 0.6 and 0.36 H), a `line` fx per link, and each victim gets a CHARGE (`e.set_meta("charge", n)`, max 5; dots over its head drawn in the host's weapon node). Thunderclap (tier 2+, cd 6): every charged enemy takes 1.5 x charges (knock 100, stun 0.8 at 2+ charges), a `ring` r 14 + 4 x charges, shake 3; no charges: cd 0.6 s.
- Static Dash (cd 4): 50 px dash, hits 1.0, +1 charge on each. Storm (tier 3+): ring r 140, 0.4 s later +3 charges on all in r 140, then an immediate Thunderclap.
- Looks: blue-white lines and rings; charges as light-blue dots.

Palette: lightning `Color(0.70,0.85,1.0)`, core `Color(1.0,1.0,1.0)`, storm violet `Color(0.50,0.45,0.95)`, copper `Color(0.85,0.60,0.30)`. Names: 2 Static, 3 Overcharge, 4 Ball Lightning, 5 Thunderhead, 6 Stormlord.

THE MYTHIC SYSTEM: **Charge and Detonate** (already the weapon's idea), made visible and strategic: charges are drawn by the aura for every enemy (via `WeaponFx motes` count = charges, blue, every 0.4 s, at most 8 enemies; the charge value is a host meta so clients see only the motes). Thunderclap is the payoff; a full 5-charge enemy is "overloaded" and arcs on its own.

## Tier table (fusion tier 2: rows 2 to 6)

| Tier | ART | ATTACK | ABILITY (Thunderclap) | DASH (Static Dash) | ULTIMATE (Storm) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Static | The whip-staff head crackles: 2 `bolt` mini sparks every 0.8 s around the head (aura); hair-thin lightning coils the shaft; aura twinkle. | Every chain link is a jagged `bolt` fx (not a plain line) with a `burst` r 8 at each victim. | **Static**: Thunderclap sends a `bolt` from you to each charged enemy and its `ring` becomes a `flash` r 12 + 3 x charges. | - | locked | chain |
| 3 Overcharge | Tip glow; a blue corona. | **Overcharge**: the chain can jump 3 times (45 -> 55 px) and every hit adds charge; a victim at 5 charges is OVERLOADED: it immediately arcs to 2 neighbours within 60 px (0.6 H, adds charge) with `bolt`s, then resets to 2 charges. | **Overcharge**: Thunderclap detonates with a splash: each detonation also hits everything within 30 px of that enemy for 0.5 H x charges (quiet aoe, max 3 victims). | = | unlocked; `sigil` r 100 (storm violet, 6 points). | chain |
| 4 Ball Lightning | 3 orbit sparks, gem pixel (storm violet). | **Ball Lightning**: every 4th attack launches a ball of lightning (`WeaponProjectile` style `orb`, size 1.6, glow 0.4, speed 130, life 1.6, 0.8 H = 3.9, `chain 3`, pierce 2, on-hit `bolt`s): it drifts through the pack and zaps everything within 40 px every 0.4 s (0.4 H, quiet, adds charge). | **Ball Lightning**: Thunderclap leaves a ball at each enemy it killed (up to 3, 2 s, each zaps within 40 px every 0.5 s for 0.4 H). | **Ball Lightning Dash**: the dash is a `streak` (width 6) and drops one ball behind you (as above, 2 s). | = | thunder |
| 5 Thunderhead | 5 sparks, ghost trail. | = | = | = | **Stage 2 Thunderhead**: after the Storm clap, a thundercloud hangs over the area for 6 s: a dark `vortex`-like `sigil` r 110 (storm violet) re-spawned each 0.8 s plus `motes` (rain, count 20, rise -> falling: `rise` negative); every 0.5 s a bolt (`bolt` from above, length 80) strikes a random charged enemy within 110 px (1.0 H = 4.8, adds charge, `ground_strike` r 14). | thunder |
| 6 Stormlord | Halo ring (lightning ring), 8 sparks, tip star; the aura crackles with 4 live `bolt` arcs between the motes. | **Finisher** every 6th attack: a storm-forked bolt: 5 `bolt`s fork from the first victim to 5 targets within 90 px (0.6 H each, adds 2 charges). | = | = | **FINALE + TRANSFORMATION Stormlord (8 s)**: you ARE the storm: for 8 s every attack is the finisher fork, every 0.7 s a `bolt` strikes each overloaded enemy, Thunderclap's cooldown is 1.0 s (set `_ability_cd = min(_ability_cd, 1.0)` while active), and charges arc between charged enemies (a web: `bolt` every 0.5 s between charged enemies within 70 px, 0.3 H quiet). At the end a mega-clap: every charged enemy within 160 px detonates at 2 x charges (x2 H), `flash` r 90, `ripple` r 160 rings 4, `pillar` height 160 at you. Shake 7, `Sfx ultimate` + `big_hit`. | lifesteal |

Caps (H = 4.82): attack +0.5 H avg (the extra jump 0.2 H; a ball every 4th attack deals 0.8 H + 3 zaps x 0.4 H = 2.0 H, i.e. 0.5 H per attack); ability splash up to 0.5 H x charges on three neighbours; dash zaps 3 x 0.4 H; ultimate: thunderhead 12 strikes x 1.0 H spread over the pack + a mega-clap that doubles today's detonation (about 2 x 1.5 H x 5 charges on one overloaded target = 15 H): inside Mythic k = 40 H.

## What makes this feel like Mythic
Charge is a system the player plays with; here it escalates: overloads chain across the pack, balls drift, a thundercloud hangs, and finally the player becomes the storm for 8 s (a cooldown-free Thunderclap). Compared with Epic Chain Fangs (a tether), Tempest's links are in the enemies themselves.

## Rules for the implementer
- `items/weapons/tiers/tempest.gd`; `tempest.gd` edits: replace the plain `line` in `attack()` by `bolt` fx at tier >= 2, `_charge()` triggers overload at 5 (tier >= 3), `ability()` splash and balls (tier 4), `dash_attack()` ball, `ultimate()` unchanged: stage 2 at press + 0.4 + 0.1 s = 0.5 s (the clap has just fired), the transformation at 6.5 s, the mega-clap at 14.5 s.
- Charge display: `tick(w, delta)` spawns `WeaponFx motes` (count = charges, radius 4, rise 8, life 0.4) above up to 8 charged enemies each 0.4 s. The old local `_draw` dots may stay for the host; the motes are for clients.
- Stormlord cooldown trick: in `tick` while `_st.lord_until > now`: `if w._ability_cd > 1.0: w._ability_cd = 1.0`.
- Stormfall bow (`stormbow`) is a different weapon (`warpbow`/`tempest` fusion): its module may `preload` this one for the `bolt` helpers.
- Constants: `TL_JUMPS := [2, 2, 3, 3, 3, 3]`, `TL_OVERLOAD := 5`, `TL_OVERLOAD_RESET := 2`, `TL_SPLASH_R := 30.0`, `TL_BALL_EVERY := 4`, `TL_BALL_TICKS := 3`, `TL_BALL_MULT := 0.4`, `TL_CLOUD_SECS := 6.0`, `TL_CLOUD_TICK := 0.5`, `TL_CLOUD_MULT := 1.0`, `TL_LORD_SECS := 8.0`, `TL_WEB_R := 70.0`, `TL_MEGA_R := 160.0`, `TL_FINISHER_EVERY := 6`.
- Charges are host-only metas; all visible parts are `WeaponFx`.
- Performance: transformation ~30 fx per second; balls cap 3 alive.

## How to test (section `tempest`)
1. Static: tier 2 chain: kind `bolt` is seen (not only `line`); tier 1 only `line`.
2. Overcharge: tier 3, a dummy at 4 charges takes one more charge: it is overloaded and two neighbours at 50 px lose health; its charge drops to 2.
3. Ball Lightning: tier 4, 4 attacks: a projectile of style `orb` size >= 1.5 appears and zaps a dummy at 30 px >= 2 times; Thunderclap's splash hits a neighbour at 25 px.
4. Thunderhead: tier 5 ultimate: >= 6 bolt strikes within 6 s on charged dummies; tier 4 none.
5. Stormlord: tier 6: `_ability_cd <= 1.0` while active; a mega-clap `flash` r 90 at ~14.5 s detonates charged dummies at 150 px; after the window the cd is normal.
6. Draw smoke; charge motes appear at every tier >= 1 (client visibility).
