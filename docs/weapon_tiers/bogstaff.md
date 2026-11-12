# Bog Staff (`bogstaff`, Mythic, poison, light weapon (50), H = 5.9)

## Today
- Attack Poison Glob: `thrust(5)`, a green `WeaponProjectile` (speed 210, 1.0 H, life 0.9, knock 40) with 4 bleed ticks of 0.8 (poison over time). Mire (tier 2+, cd 6): at the cursor (range 110) a `ring` r 44 and a `slow` mud patch r 44, factor 0.4, 6.5 s; everything inside takes 2.0 and 5 bleed ticks of 1.0 immediately.
- Bog Hop (dash, cd 4): blink 50 px and leave a mud patch r 28 (5 s) at the start with a ring r 22. Swamp Swell (tier 3+): mud r 125 (factor 0.35, 9 s) under you, ring r 125, 10 bleed ticks of 1.0 on everyone in it, then five pulses of r 110 every 0.8 s (2.5, knock 90, stun 0.2).
- Looks: olive rings and patches. Swamp realm weapon.

Palette: bog green `Color(0.50,0.85,0.30)`, mud `Color(0.25,0.30,0.12)`, spore `Color(0.80,0.95,0.40)`, rot purple `Color(0.50,0.30,0.55)`. Names: 2 Festering, 3 Spore Pods, 4 Bog Beasts, 5 Miasma, 6 Swamp Lord.

THE MYTHIC SYSTEM: **Rot**. Every poison hit adds a Rot stack to the enemy (`e.set_meta("wt_rot", n)`, max 5, decays after 6 s without a new stack). Rot is visible (green bubbles over the head, `motes`, count = stacks, spawned every 0.5 s by `tick` on up to 6 enemies near you) and all poison ticks deal +10% per stack (quiet bleed). At 5 stacks the enemy BURSTS (spores): see tier 3.

## Tier table

| Tier | ART | ATTACK (Poison Glob) | ABILITY (Mire) | DASH (Bog Hop) | ULTIMATE (Swamp Swell) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Festering | The staff top bubbles (the gem bobs; 2 spore motes rise every 0.4 s from the aura); aura twinkle. Light +5. | **Festering**: globs are style `glob` size 1.2 with a drip trail (trail 4, wobble 2) and every hit adds a Rot stack (the Rot system starts here); a `burst` r 8 (spore) on hit. | **Festering Mire**: the mire adds 2 Rot stacks to everything in it each second (the mud ticks, 4 s) and `motes` count 10 (bubbles) rise from the patch; a `ripple` r 44 rings 2. | - | locked | chill |
| 3 Spore Pods | Tip glow (green); the orb pulses. Light +10. | **Spore Pods**: an enemy reaching 5 Rot stacks bursts: a spore cloud `burst_r` 36 (0.8 H = 4.7, quiet aoe) that adds 2 Rot to everything inside, and a `shards`/`motes` pop (spore, count 10); every 3rd glob is a "pod" (size 1.8, `burst_r` 30, mult 0.6). | **Spore Pods**: mire spawns three pods around the centre (at 28 px, r 14 `ground_strike`, 0.6 s delay, 0.6 H = 3.5): each adds 2 Rot and its `motes` rise; | = | unlocked; `sigil` r 100 (spore) 0.3 s before the mud. | chill |
| 4 Bog Beasts | 3 orbit spore motes, gem pixel (green). Light +15. | **Bog Beast**: a Rot burst or a kill by poison raises a bog beast (a `fall`-free `WeaponProjectile` style `glob`, size 2.4, `homing` 0.6, 1.0 H = 5.9, speed 110, life 1.6, `burst_r` 28 mult 0.5, wobble 6) that crawls toward the nearest enemy (max 2 alive per player, host-tracked in `_st`). | **Bog Beasts**: the mire has "mud hands": every 1.0 s a `crack`-like tendril (`bolt` fx in green, length 30) grabs the enemy nearest the centre (`WeaponUtil.stun` 0.5 s, 0.5 H = 3.0, adds 2 Rot). | **Mud Trail**: the hop leaves a 3-patch mud trail (r 16 factor 0.5, 3 s) and a `streak` (width 6); the arrival splashes: `burst_r`-style hit r 30 (0.8 H = 4.7) adding 2 Rot. | = | lifesteal |
| 5 Miasma | 5 motes, drip trail ghost. Light +20. | = | = | = | **Stage 2 Miasma**: for 8 s a toxic fog fills r 125: `vortex` fx (outward, r 125, count 3) respawned each 0.8 s, `motes` count 14 at random; every enemy inside gains 1 Rot per second and all Rot enemies take +15% from every source (`Game.mark_mult` `toxic_until` x1.2 reused: set `e.set_meta("toxic_until", now + 2.0)` each second) and the fog heals NOTHING (players are unharmed). | chain |
| 6 Swamp Lord | Halo ring (spore ring), 8 motes, tip star; the staff roots: 3 green tendrils curl up the shaft. Light +30. | **Finisher** every 6th glob: a gout: `cone` r 60 half 0.5 of spores: 0.6 H to all in the cone, 2 Rot each. | = | = | **FINALE + TRANSFORMATION Swamp Lord (10 s)**: you become the swamp: for 10 s every glob is a pod (size 1.8, burst), the mud patch follows you (a r 60 `slow` patch re-spawned each 1.0 s at your feet), Rot bursts raise a beast every time (cap 4), and 6 great tendrils (`bolt` fx, green, length 70, width 4) lash the 6 enemies with the most Rot every 1.0 s (1.0 H = 5.9, stun 0.4). When it ends a final Rot Bloom: every Rot enemy within 140 px bursts at once (4.7 each) with a `flash` r 60 and `ripple` r 140 rings 3. Shake 6, `Sfx ultimate`. | thunder |

Caps (H = 5.9): attack avg +0.5 H (pods every 3rd: 0.6 H x 0.33 = +0.2 H, Rot +10% per stack up to +50% of the poison bleed 0.8 x 4 = 3.2: +1.6 on top of 1.0 H: the numbers are small because the bleed is small); ability 2.0 + mud hands 3 x 0.5 H, three pods 3 x 0.6 H = +4.8 H on a target in the centre (Mythic cap +60% of 2.0 + 5 x 1.0 bleed): acceptable when its centre is hit; dash +0.8 H; ultimate: miasma 8 x (mark 1.2x) + tendrils 10 x 1.0 H (spread over six targets) + bloom 0.8 H x ... vs today 10 bleed ticks + 5 x 2.5: Mythic cap k = 40 H.

## What makes this feel like Mythic
It is a SYSTEM: Rot stacks that you watch grow, bursts that chain through a crowd, beasts that crawl, and an ultimate that turns you into a swamp for 10 s (a transformation). Compared with Epic Staff (rune circles, comets) the Bog Staff's effects feed each other: any hit may start a chain of bursts across the pack.

## Rules for the implementer
- `items/weapons/tiers/bogstaff.gd`; `bogstaff.gd` edits: `attack()` projectile `extra` by tier (style, size, trail, wobble, burst), `ability()` per-second Rot ticks in the module (Mire timers: host `tick`), `dash_attack()` trail/splash, `ultimate()` unchanged: stage 2 at press + 4.0 s... the pulses run 4.0 s: Miasma starts at 0.3 s (alongside), the transformation at 4.3 s and ends at 14.3 s; finale bloom at 14.3 s.
- Rot helpers in the module: `rot_add(w, e, n)` (sets meta `wt_rot` = {n, until}), `rot_burst(w, e)`; `WeaponUtil.bleed` ticks read the stacks via `WeaponUtil.rot_mult(e)` (new static, 1.0 + 0.1 x stacks) multiplied inside `bleed` for element poison only. Witch Staff reuses Rot (see witchstaff.md).
- Bog beasts are `WeaponProjectile`s with `homing`; cap them with `_st.beasts` (decremented through a `tick` that counts live nodes by `_owner` meta).
- Constants: `BS_ROT_MAX := 5`, `BS_ROT_DECAY := 6.0`, `BS_ROT_BONUS := 0.1`, `BS_BURST_R := 36.0`, `BS_BURST_MULT := 0.8`, `BS_POD_EVERY := 3`, `BS_BEASTS_MAX := 2`, `BS_FOG_SECS := 8.0`, `BS_LORD_SECS := 10.0`, `BS_BLOOM_MULT := 0.8`, `BS_FINISHER_EVERY := 6`, `BS_LIGHT_BONUS := [0, 5, 10, 15, 20, 30]`.
- Bosses: Rot stacks work on bosses (damage over time is fine); stuns do not.
- Multiplayer: Rot bubbles are `WeaponFx motes`; tendrils/beasts/patches are net nodes. Players are never hurt by the mud (`slow` only).
- Performance: transformation peak ~35 fx/s (cap: tendrils every 1.0 s only 6, fog respawn every 0.8 s), 4 beasts + 2 pods projectiles.

## How to test (section `bogstaff`)
1. Festering: tier 2, two glob hits on a dummy: `get_meta("wt_rot")` stack >= 2, poison ticks of tier 2 exceed tier 1 by >= 10%; `motes` seen.
2. Spore Pods: tier 3: stack a dummy to 5: it bursts and a neighbour at 25 px gains Rot and loses health; the 3rd glob has `size >= 1.5`; tier 2 never bursts.
3. Bog Beasts: tier 4: a poison kill (dummy hp 1) spawns a homing projectile (style `glob`, size >= 2); the mire grabs: a dummy at the centre is stunned 0.5 s each second.
4. Miasma: tier 5 ultimate: a dummy 100 px away gains >= 3 Rot in 4 s and has `toxic_until` set; tier 4 stays at 0.
5. Swamp Lord: tier 6: at ~4.5 s a re-spawning `slow` patch r 60 follows the player; tendril `bolt` fx seen; at 14.5 s kind `flash` r 60; every attack in the window is a pod.
6. Draw smoke; Rot decays after 6 s (stack count falls).
