# Spellblade (`spellblade`, Mythic, fire, light weapon (60), fusion tier 2 of Staff + Sword, H = 4.29)

## Today
- Attack Wave slash (cd 0.4): `swing(1.0)`, `arc` r 28 (+-55 degrees) hitting for 0.5 H (knock 100) AND a piercing wave `WeaponProjectile` (speed 240, 0.5 H, life 0.5, pierce 1, knock 100). Blade Storm (tier 2+, cd 9): 3 blades orbit you at r 26 for 4 s (6 rad/s); a blade touching an enemy (r 9) hits 1.5 (knock 80) at most every 0.45 s per enemy.
- Arcane Dash (cd 4): 55 px dash, hits 2.5 (knock 140), exposes 1.5 s. Blade Dance (tier 3+, cd 60): 6 blades for 5 s (the same orbit code). Starfall extends it (5 blades, charges).
- Looks: blue-white arcs; diamond blades (a 4-point polygon) drawn inside the weapon node.

Palette: spell blue `Color(0.70,0.80,1.0)`, arcane violet `Color(0.60,0.45,1.0)`, fire edge `Color(1.0,0.60,0.25)`, white `Color(0.97,0.98,1.0)`. Names: 2 Spellweave, 3 Sword Choir, 4 Phantom Edge, 5 Blade Tempest, 6 Sword Saint.

THE MYTHIC SYSTEM: **Spirit Blades**. Every second wave slash that hits conjures a spirit blade that orbits you permanently (max 2 at tier 2, 3 at tier 3, 4 at tier 4, 5 at tier 5, 6 at tier 6). They are separate from the Blade Storm blades; each hits a touching enemy for 0.3 H (quiet, per-enemy cooldown 0.6 s). Drawn by the AURA (`kind "orbit_blades"`, `state` = count) so LAN clients also see them (today the storm blades are drawn only in the host's weapon node and are invisible to clients: fix both through the aura). A spirit blade can be thrown (see Blade Storm at tier 3).

## Tier table (fusion tier 2: rows 2 to 6)

| Tier | ART | ATTACK | ABILITY (Blade Storm) | DASH (Arcane Dash) | ULTIMATE (Blade Dance) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Spellweave | The blade has a rune cross-guard glowing violet; aura twinkle; blades are drawn as glowing diamonds with a `trail` of 3 ghosts. Spirit blade system starts (max 2). Light +5. | **Spirit Blades**: spirit blades start (1 per 2 slashes). Waves are style `crescent` size 1.0, trail 3. | **Spellweave**: the storm doubles its blades (6) for 4 s and the blades throw `bolt`-sparks: each blade touch `burst` r 8. | - | locked | thunder |
| 3 Sword Choir | Tip glow; rune circle under you while the storm runs (`sigil` re-spawned every 0.5 s, r 30). Light +10. | **Sword Choir**: spirit blades also strike enemies that your waves hit (each spirit blade fires a mini-wave toward the target, 0.2 H = 0.9, quiet) on every 3rd slash. | **Sword Choir**: the storm radius grows (r 26 -> 40, then back to 26 at the end) and when it ends the blades are thrown: every blade flies out in its direction (`WeaponProjectile` style `blade`, 0.8 H = 3.4, pierce 2, speed 260, life 0.4) | = | unlocked; `sigil` r 90 (6 points) 0.3 s. | thunder |
| 4 Phantom Edge | 3 orbit motes, gem pixel (violet). Light +15. | **Phantom Edge**: every 4th slash a phantom copy of the swing follows (opposite arc, 0.12 s later, 0.5 H, `slash` fx) and the wave `chain`s 2 (55 px, 60%). | **Phantom Edge**: a phantom of you (an `orbit` fx shape `blade` count 3) appears at the cursor for 3 s and also hosts a storm of 3 blades (r 26) cutting there; | **Phantom Dash**: a `streak` (width 7); two phantom blades follow your path 0.2 s later (2 hits 0.6 H each along the path); exposes 2.5 s. | = | bleed |
| 5 Blade Tempest | 5 motes, blade ghost trail, rune circle bigger. Light +20. | = | = | = | **Stage 2 Blade Tempest**: after the 5 s the blades merge into a cyclone: a `vortex` (r 70, count 6, outward spin) that rotates for 2 s around you and hurts everything inside every 0.25 s (0.4 H = 1.7, quiet aoe, pulls 60), with 12 blade thrusts at the end (a ring of 12 projectiles style `blade`, 0.5 H, pierce 1). | chain |
| 6 Sword Saint | Halo ring (a ring of 6 sword hilts), 8 motes, tip star; the spirit blades have white-gold edges. Light +30. | **Finisher** every 6th slash: all spirit blades fire a volley at the nearest enemy (0.5 H each), returning in 0.6 s. | = | = | **FINALE + TRANSFORMATION Sword Saint (10 s)**: a giant spectral sword (a `fall`-style big blade drawn by the aura: `kind "avatar"`, 24 px) hovers behind you for 10 s and copies each of your slashes with a huge `slash` fx (r 60, 1.0 H = 4.3, quiet, the biggest arc), plus all spirit blades are at max (6) and slash waves are 3 in a fan. At the end a `flash` r 80, `star` count 8 r 80, `ripple` r 120 rings 3 and the sword crashes down: `ground_strike` r 70 (0.5 s) 3.0 H (12.9), stun 1.0. Shake 7, `Sfx ultimate`. | lifesteal |

Caps (H = 4.29): attack avg +0.6 H (spirit blade contacts 0.3 H x up to 6 blades but only vs adjacent targets: +0.6 H per second of contact; mini-waves 0.9 per 3 slashes); ability: when the storm doubles to 6 blades each blade still hits for 1.5 but the per-enemy cooldown rises from 0.45 s to 0.8 s, so doubling the blades does not double the damage per second on one enemy; dash +0.6 H x 2; ultimate: tempest 8 x 0.4 H + ring 12 x 0.5 H spread + finale 3.0 H: sanity k = 40 H.

## What makes this feel like Mythic
A SYSTEM you build and spend: spirit blades accumulate, orbit, are thrown and fired; the ultimate is a transformation into a Sword Saint with a spectral avatar. Compared with Epic Knight's Blade (a ritual with a giant sword once), the Spellblade's blades are always present and every verb uses them. It is also the weapon that finally shows its blades to LAN clients.

## Rules for the implementer
- `items/weapons/tiers/spellblade.gd`; `spellblade.gd` edits: `_process` storm blade positions use `_storm_blades` count and radius from the module (`_st.storm_r`); remove the local `_draw` blade drawing in favour of aura `kind "orbit_blades"` (`state` = count of storm blades + spirit blades, `angle` from `_angle` as a public aura var `phase`); `attack()` conjures spirit blades (module `attack(w)` counts hits via `on_hit`; every second hit that came from a wave: `_st.waves += 1`), `ultimate()` unchanged: stage 2 at press + 5.0 s, transformation at 7.2 s.
- Starfall `extends spellblade.gd`: `blade_count = 5`; its own module may `preload` this one.
- Aura public vars to add: `phase: float` (the orbit angle), `n_blades: int`, `n_spirit: int`, `avatar: bool`; the host sets them in `tick`.
- Constants: `SB_SPIRIT_MAX := [0, 2, 3, 4, 5, 6]` (index = tier - 1 -> tier 2 = 2, ... tier 6 = 6), `SB_SPIRIT_MULT := 0.3`, `SB_SPIRIT_TICK := 0.6`, `SB_STORM_R := 26.0`, `SB_STORM_R3 := 40.0`, `SB_THROWN_MULT := 0.8`, `SB_PHANTOM_EVERY := 4`, `SB_CYCLONE_SECS := 2.0`, `SB_RING_N := 12`, `SB_SAINT_SECS := 10.0`, `SB_AVATAR_MULT := 1.0`, `SB_FINALE_MULT := 3.0`, `SB_FINISHER_EVERY := 6`.
- Blade contact uses `WeaponUtil.enemies_in_circle(pos, 9)`, `quiet = true`, with a per-enemy cooldown table in `_st`.
- Multiplayer: the aura draws every blade from `phase`, `n_blades`, `n_spirit`; no per-blade net nodes. Thrown blades are `WeaponProjectile`s.
- Performance: transformation: 6 spirit + 6 storm blades drawn by the aura (draw calls <= 14), avatar slashes 1 fx per swing; the cyclone vortex 1 fx per 0.5 s.

## How to test (section `spellblade`)
1. Spirit blades: tier 2, 4 wave slashes that hit: aura `n_spirit == 2`; tier 1 has none; a dummy next to the player takes damage from contact over 2 s.
2. Sword Choir: tier 3 ability: after 4 s a `WeaponProjectile` burst of blades (>= 3 projectiles style `blade`); tier 2 none; `n_spirit` max is 3 at tier 3.
3. Phantom Edge: tier 4: every 4th slash shows a second `slash` fx 0.12 s later; the wave chain hits a second dummy 40 px away; the dash exposes a dummy for >= 2.3 s.
4. Blade Tempest: tier 5 ultimate: at ~5.5 s a `vortex` is seen and a dummy at 50 px takes damage every 0.25 s; at ~7 s 12 projectiles appear.
5. Sword Saint: tier 6: `avatar` aura flag true for ~10 s; each slash spawns an extra big `slash`; at ~17 s kind `flash` r 80 and a dummy at 50 px takes >= 12.9.
6. Draw smoke tiers 1-6; `n_blades` equals the storm blade count (3, 6) so a client draws the same blades.
