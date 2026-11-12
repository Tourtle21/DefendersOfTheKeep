# Dragoon Pike (`dragoonpike`, Epic, pierce, fusion tier 3 of Siege Lance + Rapier, H = 4.81, inherits `t2/lance.gd`)

## Today
- Attack Impale (from the Lance): `thrust(14)`, `line` fx 52, tip (>= 34 px) 1.0 H knock 240 gold ring and shake 2; closer 0.5 H. Charge (hold right click, cd 6): ram 60 + 90 x ratio px, hits 4 + 4 x ratio, ring r 26 + 20 x ratio (3.0, stun 0.8); then, 0.55 s later, three automatic lunges at the 3 nearest distinct enemies within 130 px (dash 0.1 s, 4.0 each, knock 160, line fx, 0.16 s apart).
- Sky Vault (dash, cd 4): a 110 px leap in 0.28 s and two ground strikes at the landing (r 30 0.3 s 3.0 stun 0.6; r 52 0.55 s 2.0). Dragon Dive (tier 3+, from the Lance): leap to the cursor (range 130) and a `ground_strike` r 50 0.4 s 10.0 knock 360 stun 1.5.
- Looks: gold lines and rings.

Palette: dragon gold `Color(1.0,0.82,0.30)`, scale red `Color(0.85,0.25,0.15)`, flame `Color(1.0,0.55,0.15)`, steel `Color(0.95,0.95,1.0)`. Names: 3 Wyvern's Fang, 4 Dragonfire, 5 Wyrm Chase, 6 Dragon Descent.

## Tier table (fusion tier 3: rows 3 to 6; the entry row carries the upgrades of tier 2 and 3)

| Tier | ART | ATTACK | ABILITY (Charge + chain lunges) | DASH (Sky Vault) | ULTIMATE (Dragon Dive) | Twist (est.) |
|---|---|---|---|---|---|---|
| 3 Wyvern's Fang (entry) | The spearhead is a dragon fang with a red scale collar and a rapier-thin shaft; aura twinkle + tip glow; a faint gold wake while charging (aura `state`). | **Wyvern's Fang**: the tip hit lights a gold `burst` and `shards` count 5; every 3rd thrust is 70 long (Lance Long Lance) and a thin wave `WeaponProjectile` style `lance` (0.6 H = 2.9, pierce 2) follows the 2nd thrust (Rapier rhythm). | **Shock Cone + Fang Lunges**: the ram ends with a forward `cone` r 56 (0.8 H, knock 300) and each of the three lunges is a `streak` + `cut` r 12, exposes 2 s. | = | unlocked: `sigil` r 50 under the landing; dive with a leap shadow. | lifesteal |
| 4 Dragonfire | 2 orbit embers (flame), gem pixel (ruby). | = | **Dragonfire**: the lunges are fire-tipped: each lunge ignites its target (3 bleed ticks of 0.2 H) and leaves a short flame trail (`motes` flame count 6); four lunges instead of three. | **Dragonfire Vault**: the vault is a visible hop (shadow ellipse); the landing is a `flash` r 36, 3 spikes (Lance Spikefall at 0.8 H = 3.8) and a cone of flame forward (`cone` r 60 half 0.6, 0.8 H, ignites). | = | thunder |
| 5 Wyrm Chase | 4 flame motes, trail. | = | = | = | **Stage 2 Wyrm Chase**: after the crash the dragon chases: 5 lunges at the 5 nearest enemies within 150 px (dash 0.1 s, 0.16 s apart, 1.0 H = 4.8 each, flame trail, `streak`), then you land back at the crash point (a `blink` with a `flash`). | thunder |
| 6 Dragon Descent | Halo ring (red scales), 6 motes (flame), tip star; a dragon's head glint at the tip. | **Finisher** every 6th thrust: a roar: `cone` r 70 half 0.6 (0.8 H, `Sfx boss_roar` quiet pitch 1.2) that pushes (200). | = | = | **FINALE Dragon Descent**: the dive begins with a red `fall` (radius 9, height 150, `flame`); the crash is a `sigil` r 80 (0.4 s) then `flash` r 70, `pillar` height 130 width 34, `shock` r 80, 8 radial lances (`WeaponProjectile` style `lance`, 1.2 H = 5.8, pierce 3, speed 280, life 0.4) as a spiral and a `slow` patch r 50 for 4 s; all within 80 px: 1.5 H (7.2), stun 1.5 (`WeaponUtil.stun`). Shake 7, `Sfx ultimate` + `thump`. | chain |

Caps (H = 4.81): attack avg +0.3 H; ability +0.8 H cone + 0.6 ignite per lunge x 4 (spread: lunges hit different targets); dash 0.8 H + 0.8 H; ultimate: chase 5 x 1.0 H (4.8, one lunge per distinct target) + finale 1.5 H (7.2) + lances 1.2 H (5.8, one or two hit one target) vs today 10.0 = about +100% (see constants).

## What makes this feel like Epic
It chases: a chain of automatic lunges in place of a single charge (Rapier's footwork on Lance's ram). Compared with Lance (Uncommon, one vault and a crash) the Pike's ultimate is a three-act dragon: leap, hunt, descent. It is Epic's most mobile weapon; spectacle is lines and flame, not fields.

## Rules for the implementer
- `items/weapons/tiers/dragoonpike.gd` (`preload("lance.gd")` for Long Lance / Spikefall / Shock Cone helpers, with Pike constants). `dragoonpike.gd` edits: `release_ability()` lunge count (4 at tier >= 4) and per-lunge ignite (inside the loop: `WeaponUtil.bleed`), `dash_attack()` landing extras (flame cone, spikes), `ultimate()` inherited: the module adds the chase at press + 0.35 + 0.4 + 0.3 = 1.05 s and the finale at +1.8 s.
- Constants: `DP_LUNGES := [3, 3, 4, 4]` (tiers 3 to 6), `DP_IGNITE_TICKS := 3`, `DP_IGNITE_MULT := 0.2`, `DP_CHASE_N := 5`, `DP_CHASE_MULT := 1.0`, `DP_FINALE_MULT := 1.5`, `DP_LANCES := 8`, `DP_LANCE_MULT := 1.2`, `DP_ROAR_EVERY := 6`.
- Crossing damage: the chase lunges `player.dash` between targets, so `shield_time` already covers you; the final return blink lands at the crash point (cap 200 px).
- Multiplayer: nothing new. Performance: finale ~30 fx + 8 projectiles.

## How to test (section `dragoonpike`)
1. Entry: a Pike at tier 3 has Shock Cone (a dummy 20 px beyond the ram's end is hurt), the 2nd thrust spawns a projectile, the 3rd is 70 long.
2. Dragonfire: tier 4: four lunges occur with 4 dummies (count line fx), each lunge target burns (health keeps falling 1 s); tier 3 only three.
3. Vault: tier 4 dash: dummy in the forward cone 40 px ahead takes 0.8 H and burns; tier 3 not.
4. Chase: tier 5 ultimate with 5 dummies within 150 px: all get hit once more at ~1.05 s (>= 4.8 each); the player ends within 40 px of the crash point.
5. Dragon Descent: tier 6: `fall` radius 9 seen, 8 projectiles style `lance`, `pillar` seen, a dummy at 70 px stunned >= 1.2 s and takes >= 7.2 extra.
6. Draw smoke; Siege Lance unaffected.
