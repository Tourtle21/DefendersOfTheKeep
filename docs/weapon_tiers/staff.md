# Staff (`staff`, Epic, fire, light weapon (75), H = 4.8)

## Today
- Attack Bolt: a violet `WeaponProjectile` (speed 230, 1.0 H, life 1.2, knock 60), `thrust(5)`. Arcane Burst (tier 2, cd 5): a `ground_strike` at the cursor (range 100) r 30, 0.5 s, 3.8, stun 0.4, plus three echo strikes (r 20, 0.7 to 0.9 s, 2.5, stun 0.2) 38 px from it. Blink (dash, cd 4): blink 64 px toward the aim, `ring` r 14; a rift ring (r 32, 1.0 s) at the start explodes after 1.0 s: 4.2, knock 200, slow 0.4 for 1 s in r 44.
- Arcane Storm (tier 3): `rain` around the cursor (range 110) r 70, 8 strikes over 2.0 s, 4.0 each (r 28, stun 0.4). The staff glows (LIGHT_WEAPONS 75), fire element, violet effects.
- It is the first weapon where the dash is a trap (bait onto the rift).

Palette: arcane `Color(0.60,0.45,1.0)`, bright `Color(0.78,0.65,1.0)`, core `Color(0.95,0.90,1.0)`, fire accent `Color(1.0,0.55,0.20)`. Names: 2 Echoing Bolt, 3 Rune Circle, 4 Rift Twins, 5 Arcane Comets, 6 Cosmos.

## Tier table

| Tier | ART | ATTACK (Bolt) | ABILITY (Arcane Burst) | DASH (Blink) | ULTIMATE (Arcane Storm) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Echoing Bolt | Orb glows (the gem pulses), 2 rune sparks orbit the head; aura twinkle. Bolt style `orb` size 1.1, trail 4. | **Echoing Bolt**: the bolt `burst`s on hit (`burst_r` 18, mult 0.4): hits neighbours for 0.4 H (1.9) and a `burst` fx. | The echo blasts are drawn as small runes (`sigil` r 18 count 4) and gain a 4th and 5th (5 echoes at 72-degree steps). | - | locked | chain |
| 3 Rune Circle | Tip glow; the orb flares violet on a cast. Light +10. | **Rune Circle**: every 4th bolt is a big bolt (`size 1.8`, 2 H = 9.6, `burst_r` 28, mult 0.6, pierce 0, `star` count 5 on hit). | **Rune Circle**: the main blast leaves a rune circle for 3 s (`sigil` fx re-spawned every 0.5 s, r 30): each pulse every 1.0 s (3) hits 0.5 H (2.4) quiet aoe, knock 60. | = | unlocked; `sigil` r 80 for 0.3 s over the target area; the first strike lands after it. | chain |
| 4 Rift Twins | 3 orbit motes (violet), a gem pixel (violet); light +20. | **Echoing Bolt 2**: bolts chain: `chain 2` (55 px, 60%) with a `bolt` fx between victims. | **Rift Twins**: a second Burst (r 24, 2.2 H, 0.7 s later) detonates at the mirror position (the cursor reflected through the player, up to 100 px); `bolt`s connect the two blasts (a lightning bridge): enemies on it take 0.5 H. | **Rift Twins**: blink leaves TWO rifts, one at the start and one at the arrival; the one at the arrival has r 26 and explodes after 1.4 s for 0.8x. | = | lifesteal |
| 5 Arcane Comets | 4 motes, orb trail, swing ghost. Light +30. | = | = | = | **Stage 2 Comets**: the storm strikes become comets: each strike is a `fall` (radius 4, height 90, life 0.45) and a lingering `burst`; 1.0 s after the last strike 4 comets with `homing` (0.5, `WeaponProjectile` style `orb`, size 1.4, 2.0 H = 9.6, speed 180, `burst_r` 30, life 2.0) rise from the circle and seek the strongest enemies. | lifesteal |
| 6 Cosmos | Halo ring (rune ring), 8 motes (a miniature constellation orbits), tip star. Light +40. | **Finisher** every 8th bolt: a nova: 8 small bolts radiate from the hit point (0.4 H each, pierce 1). | = | = | **FINALE Cosmos**: the storm area becomes a night sky for 6 s: a `sigil` r 110 (count 12, big), `vortex` fx r 110 re-spawned each 0.8 s, stars (`star` fx count 5 r 6 x 8 at random spots each second); every 1.0 s a star falls on a random enemy in the area (`fall` + `ground_strike` r 18, 1.0 H = 4.8; 6 stars); the last star is a giant `fall` (radius 8) at the centre: r 50 `ground_strike` 2.0 H, stun 1.0. `LightSource` r 150 for 6 s. Shake 6, `Sfx ultimate`. | thunder |

Caps (H = 4.8): attack avg +0.4 H (burst 0.4 on neighbours, big bolt every 4th: +2 H/4 = 0.5 H: lower the chain to 50% on a big bolt); ability rune 3 x 0.5 + twin 2.2 = +3.7 H over three seconds on a target = +60% (accept); dash 0.8x; ultimate: comets 4 x 2.0 H (one or two hit one target) + stars 6 x 1.0 + giant 2.0 vs today 8 x 0.83 H = 6.7 H: +130%: reduce comets to 3 and stars to 5 at implementation if measured above +100%.

## What makes this feel like Epic
It begins to change the ground: rune circles, rifts, twin blasts connected by lightning, a sky that rains stars. A Rare weapon (Frost Glaive) uses one effect at a time; the Staff's tier 4 to 6 verbs each combine two (blast + bridge, rift + rift, storm + comets). The ultimate has setup, main, aftermath.

## Rules for the implementer
- `items/weapons/tiers/staff.gd`; `staff.gd` edits: `attack()` projectile `extra` dict by tier and the shot counter (`_st.bolts`) read by the module (`pre_attack`); `ability()` extra echoes by tier; `dash_attack()` second rift at tier >= 4 (it uses `await` already: add the second timer after the first); `ultimate()` unchanged: the module adds stage 2 at 2.2 s and the finale at 3.5 s after the press.
- Fused children: Warp Bow does not extend staff; Spellblade, Tempest, Witch and Prismatic Staff have their own modules and may `preload` this one.
- Constants: `STAFF_BURST_R := 18.0`, `STAFF_BIG_EVERY := 4`, `STAFF_BIG_MULT := 2.0`, `STAFF_RUNE_SECS := 3.0`, `STAFF_RUNE_PULSE := 0.5`, `STAFF_TWIN_MULT := 2.2/4.8`, `STAFF_COMETS := 3`, `STAFF_STARS := 5`, `STAFF_NOVA_EVERY := 8`, `STAFF_NOVA_N := 8`, `STAFF_LIGHT_BONUS := [0, 0, 10, 20, 30, 40]`.
- The rune circle is a host `tick` (timers in `_st`), the circle itself is a `sigil` fx; no node.
- Multiplayer: comets are `WeaponProjectile` with `homing` (host only). Performance: finale peak ~35 fx (budget Epic 20 added per burst: stars at every second spawn only 3 fx), 3 projectiles.

## How to test (section `staff`)
1. Echoing Bolt: tier 2 bolt into a dummy with a neighbour at 15 px: the neighbour loses health; tier 1 not.
2. Rune Circle: tier 3 ability: a dummy standing at the blast centre loses health at 1.0, 2.0 and 3.0 s (3 extra steps); big bolt on the 4th shot has `size >= 1.5` (read the projectile var).
3. Rift Twins: tier 4 ability: a second `ring`/strike at the mirrored point within 0.9 s; dash leaves two rift rings (count `ring` fx of life 1.0/1.4); chain bolt hits a second dummy 40 px away.
4. Comets: tier 5 ultimate: >= 5 `fall` kinds seen within 3 s and 3 homing projectiles at ~3.3 s; tier 4 none.
5. Cosmos: tier 6: `LightSource` radius 150 exists ~4 s; 5 star strikes plus the giant `fall` radius 8; tier 5 not.
6. Draw smoke; the 8th bolt spawns 8 projectiles.
