# Ember Flail (`emberflail`, Epic, fire, light weapon (95), H = 5.8)

## Today
- Attack Swing: `swing(1.2)`, 0.17 s later `arc` r 32 (+-60 degrees at 34 px), 1.0 H, knock 140, and a `burn` patch r 14 for 3 s at 26 px ahead (it HURTS players). Eruption (tier 2, cd 6): `ground_strike` at the cursor (range 90) r 32, 0.45 s, 5.5, stun 0.4, six sparks (r 16 at 52 px, 3.0, 0.6 to 0.85 s) and a burn pool r 30 for 4 s. Lava Surge (dash, cd 5): 60 px dash leaving 4 burn patches (r 12, 4 s).
- Magma Ring (tier 3): 12 strikes at 85 px (r 22, 4.5, delays 0.3 to 0.74) each with a burn patch r 20 for 6 s, plus 6 inner strikes at 45 px.
- Looks: orange arcs and rings; the ground is its medium (burn patches).

Palette: magma `Color(1.0,0.40,0.10)`, lava `Color(1.0,0.55,0.20)`, ember core `Color(1.0,0.82,0.30)`, char `Color(0.25,0.10,0.06)`. Names: 2 Spitfire, 3 Burning Orbit, 4 Lava Whip, 5 Caldera, 6 Volcano.

## Tier table

| Tier | ART | ATTACK (Swing) | ABILITY (Eruption) | DASH (Lava Surge) | ULTIMATE (Magma Ring) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Spitfire | The flail ball glows and drips embers (2 `motes` rise every 0.4 s from the ball, from the aura); aura twinkle. Light +10. | **Spitfire**: every swing flings 2 fire sparks (`WeaponProjectile` style `orb`, size 0.8, 0.3 H = 1.7, speed 200, life 0.35, no pierce) at +-0.35 rad. | The eruption spawns a `pillar` (height 60, width 20, `magma`) and `shards` count 8 (`ember`); sparks become 8 around the ring. | - | locked | chain |
| 3 Burning Orbit | Tip glow; fire trail. Light +20. | **Burning Orbit**: the 3rd swing releases the ball: a spinning flaming ball orbits you at r 28 for 2.0 s (`orbit` fx shape `star` count 1 life 0.2 re-spawned each 0.1 s) and hits every 0.4 s within 12 px for 0.4 H (2.3, quiet, igniting): total ~5 hits. | = | = | unlocked; `sigil` r 90 count 12 in `magma` for 0.3 s before the first strike. | chain |
| 4 Lava Whip | 3 orbit embers, gem pixel (ruby). Light +30. | = | **Lava Whip**: the eruption sends 3 lava tongues that crawl outward from the centre in a 3-armed spiral: 6 small strikes per arm (r 12, 0.12 s apart, 0.4 H = 2.3) along a curve; each strike leaves a `slow` patch (r 12, 3 s, factor 0.6), NO new burn patches. | **Lava Whip**: the dash is a `streak` (width 8, `magma`) and then 3 patches become 4 patches (r 14, 4 s, the existing burn type) and a flame wall is shown by `pillar`s (height 30, width 10) at each patch; passing enemies burn 3 ticks of 0.15 H. | = | lifesteal |
| 5 Caldera | 4 embers, ghost trail. Light +40. | = | = | = | **Stage 2 Caldera**: after the outer ring, the ground inside collapses into a caldera for 6 s: a `vortex` fx (inward, r 85, count 4, life 1.0, `lava`) every 0.8 s, a `slow` patch r 85 factor 0.6, and every enemy inside takes 0.2 H (1.2) per second (quiet, aoe, fire) and is pulled 12 px/s toward the middle; light 140 for 6 s. | thunder |
| 6 Volcano | Halo ring (ember), 8 motes, tip star; light +60 and a steady pulse. | **Finisher** every 6th swing: the flail slams: `shock` r 40 (thick 7), `crack` count 6, +1.0 H, knock 260, plus 3 sparks. | = | = | **FINALE Volcano**: after 5.0 s a volcano erupts in the centre: `pillar` height 140 width 34 + `flash` r 70, a `ground_strike` r 50 (0.5 s telegraph via `sigil`) for 2.5 H (14.5), knock 360, stun 1.0, then 10 lava bombs (`fall` radius 4 + `ground_strike` r 18, 1.0 H = 5.8, over 1.5 s) rain in r 120 (each from the volcano outward). Shake 6.5, `Sfx ultimate` + `thump`. | chill |

Caps (H = 5.8): attack sparks 2 x 0.3 H = +0.6 H (cap: sparks only count once if they hit the same target: 0.3 H) + orbit 5 hits x 0.4 H every 3 swings (per swing +0.7 H: reduce orbit hits to 0.3 H); ability lava tongues up to 0.4 H x 6 = 2.4 H spread (a target meets 1 or 2); dash 3 x 0.15; ultimate: caldera 6 x 0.2 + finale 2.5 + bombs 1.0 x 10 spread (2 per target): about +7 H vs today 4.5 x 12 = 54 H of ring: tiny relative to the ring.

## What makes this feel like Epic
The ground changes: lava tongues, a caldera that pulls and slows, a volcano. Compared with Frost Glaive (Rare) where the screen ends with one shatter, the Ember Flail has a three-act ultimate (ring, collapse, eruption) and a persistent field. Burn patches already hurt players, so new ground effects are `slow`.

## Rules for the implementer
- `items/weapons/tiers/emberflail.gd`; `emberflail.gd` edits: `attack()` sparks and the 3rd-swing orbit (module `attack(w)`, orbit via `tick`), `ability()` pillar/shards and the tongues (timers; strikes through `ground_strike`), `dash_attack()` 4 patches (the existing `_fire`), `ultimate()` unchanged: the module schedules the caldera at 1.2 s (the ring ends at 0.74 + 0.3) and the volcano at 7.0 s.
- Magma Maul `extends emberflail.gd` but has its own module.
- Constants: `EF_SPARKS := 2`, `EF_SPARK_MULT := 0.3`, `EF_ORBIT_EVERY := 3`, `EF_ORBIT_SECS := 2.0`, `EF_ORBIT_MULT := 0.3`, `EF_TONGUES := 3`, `EF_TONGUE_STRIKES := 6`, `EF_CALDERA_SECS := 6.0`, `EF_CALDERA_R := 85.0`, `EF_VOLCANO_MULT := 2.5`, `EF_BOMBS := 10`, `EF_BOMB_MULT := 1.0`, `EF_FINISHER_EVERY := 6`, `EF_LIGHT_BONUS := [0, 10, 20, 30, 40, 60]`.
- The caldera pull uses `Enemy.push` each 0.25 s (40% for bosses).
- Burn patches hurt PLAYERS: do not add new ones (Lava Whip tongues use `slow`; only the existing Eruption pool, Lava Surge and Magma Ring keep theirs; at tier 4 the dash uses 4 existing-size patches).
- Multiplayer: nothing new. Performance: finale about 30 fx over 2 s; at most 3 `LightSource`.

## How to test (section `emberflail`)
1. Spitfire: tier 2 swing: 2 projectiles within 0.1 s; a dummy at 45 px, 0.35 rad off, loses 1.7 health.
2. Orbit: tier 3, 3 swings: a dummy at 28 px from the player loses health in >= 3 hits over 2 s only at tier 3+; tier 2 none.
3. Lava Whip: tier 4 ability: six `slow` hazards exist; dummies along an arm lose health; no new `burn` hazard appears beyond the old pool; dash makes 4 patches.
4. Caldera: tier 5 ultimate: at ~2 s a `slow` hazard radius 85 exists; a dummy at 60 px moves toward the centre >= 10 px and loses >= 3 steps over 5 s; tier 4 not.
5. Volcano: tier 6: at ~7 s `pillar` height 140 seen and the centre dummy takes >= 14; 10 `fall` kinds; tier 5 not.
6. Draw smoke; the 6th swing produces `shock`.
