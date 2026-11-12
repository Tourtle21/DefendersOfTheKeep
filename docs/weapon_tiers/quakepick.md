# Quake Pick (`quakepick`, Uncommon, crush, fusion tier 2 of Hammer + Pickaxe, H = 4.36)

## Today
- Attack: `swing(1.0)`, 0.18 s later `arc` r 30 (+-60 degrees), 1.0 H, knock 160, shake 1.5, and breaks rocks and trees 3 times in front. Fissure (tier 2+, cd 7): 5 ground strikes in a line from 22 px every 18 px (r 18, delays 0.4 to 0.8 s, 3.0, knock 220, stun 0.3, breakables).
- Burrow (cd 5): 70 px dash then a `ground_strike` 70 px ahead (r 26, 0.35 s, 3.5, stun 0.6). Cataclysm (tier 3+): three rings of six strikes at 30/60/90 px (r 22, delays 0.3/0.65/1.0, 4.0, stun 0.5).
- Looks: brown rings only. It is the miner's version of the Hammer: ground effects that also clear terrain.

Palette: earth `Color(0.80,0.60,0.30)`, crack glow `Color(1.0,0.60,0.20)`, dark `Color(0.30,0.20,0.10)`, dust `Color(0.88,0.76,0.55)`. Names: 2 Branching Fissure, 3 Rock Spike, 4 Tunnel, 5 Chasm, 6 Cataclysm Prime.

## Tier table

| Tier | ART | ATTACK | ABILITY (Fissure) | DASH (Burrow) | ULTIMATE (Cataclysm) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Branching Fissure | Pick head and hammer face both glint; aura twinkle; the head glows ember at the moment of impact (0.1 s). | Breakable hits throw `shards` count 4 r 12 | **Branching Fissure**: the 2nd and 4th eruptions each fork: two small strikes (r 12, 0.4 H = 1.7, knock 120) 26 px to either side; every eruption draws a `crack` (count 3, length 20) toward the next. | - | locked | thunder |
| 3 Rock Spike | Tip glow; a dust trail on the swing. | **Rock Spike**: every 3rd swing a stone spike erupts 40 px ahead (`ground_strike` r 14, 0.3 s, 1.0 H, knock 220 plus `crack` count 4 and `shards` 4). | = | = | unlocked; a `sigil` r 90 (`earth`) for 0.25 s before ring 1. | thunder |
| 4 Tunnel | 2 dust motes orbit, gem pixel. | = | = | **Tunnel**: you dive under: the dash is a `streak` (width 8, `dark`) with `motes` dust behind you; 3 eruptions burst along the path after you (r 14, delays 0.15/0.3/0.45 s, 0.8 H = 3.5, knock 200); you arrive braced (`shield_time` 0.3 s as an earthshaker will, small). | = | bleed |
| 5 Chasm | 4 motes, swing ghost. | = | = | = | **Stage 2 Chasm**: 0.4 s after ring 3 the centre collapses: a `vortex` fx (inward, r 70, count 3, life 1.0) pulls enemies within 70 px toward you (`push` 200, 0.3 s), then a `ground_strike` r 40 around you (0.5 s, 0.6 H = 2.6, stun 0.5) and a `slow` patch r 40, factor 0.5, 4 s. | bleed |
| 6 Cataclysm Prime | Halo ring, 5 motes, tip star. | **Finisher** every 6th swing: three spikes in a line (40/66/92 px, 0.8 H each), `crack` between them. | = | = | **FINALE Cataclysm Prime**: 4 `pillar`s (height 90, width 18, `earth`) erupt at the compass points at r 90 (each a `ground_strike` r 20, 0.45 s, 1.0 H, stun 0.5), joined by a ring of `crack` (count 12, r 100), then the centre `flash` r 70 and `shock` r 90 thick 8 (hits r 80, 1.2 H = 5.2, knock 300). Shake 5, `Sfx thump` + `big_hit`. | chill |

Caps (H = 4.36): attack avg +0.2 H; ability forks 2 x 0.4 H (one fork reaches a given target = +0.4 H); dash +0.8 H; ultimate: chasm 2.6 + finale 4 x 1.0 (one) + 5.2 = at most 11.8 vs today 24 on a target in the middle = +49%... accept, the centre target in all three rings is rare; for fairness the finale pillars are at r 90 (edge) and the centre blast is 5.2.

## What makes this feel like Uncommon
Terrain-flavoured and rhythmic like the Hammer but with a pattern to read: lines, forks, rings. The tier 6 finale is a second layer around the first (pillars then blast). Compared with Pickaxe (Common) the strikes are staggered into sequences rather than one eruption.

## Rules for the implementer
- `items/weapons/tiers/quakepick.gd`; `quakepick.gd` edits: `ability()` forks for `i` in [1, 3] when `tier >= 2` (use `ground_strike` with the same delays + 0.05), `dash_attack()` extra eruptions (they must follow the player's path: compute `o` before the dash and place at `o + aim * (20 + 20 * k)`), `ultimate()` unchanged, module schedules Chasm at 1.4 s and the finale at 2.4 s after the press (ring 3 lands at 1.0 s).
- Earthshaker `extends quakepick.gd` and has its own module.
- Constants: `QP_FORK_EVERY := [1, 3]`, `QP_FORK_MULT := 0.4`, `QP_SPIKE_EVERY := 3`, `QP_TUNNEL_N := 3`, `QP_TUNNEL_MULT := 0.8`, `QP_CHASM_PULL := 200.0`, `QP_PILLARS := 4`, `QP_FINALE_MULT := 1.2`, `QP_FINISHER_EVERY := 6`.
- All strikes break breakables the same way (`["stone","stick"]`).
- Multiplayer: strikes, `Hazard`; no new nodes. Performance: finale about 20 fx; Fissure with forks 5 + 4 strikes x2 fx.

## How to test (section `quakepick`)
1. Fork: tier 2 Fissure: a dummy 26 px to the side of eruption 2 takes damage; tier 1 not; kind `crack` seen.
2. Rock Spike: tier 3, 3 swings; a dummy 40 px ahead (outside the 30 arc) is hurt only after the 3rd swing.
3. Tunnel: tier 4 dash with dummies along the path at 25 and 45 px behind the start: both are hit by eruptions 0.15 to 0.5 s later; tier 3 none.
4. Chasm: tier 5: a dummy at 60 px is pulled > 15 px toward the player between 1.4 and 1.8 s; a `slow` hazard radius 40 exists; tier 4 neither.
5. Cataclysm Prime: tier 6: 4 `pillar` kinds seen, `shock` r 90 seen, the centre dummy takes >= 5.2 after 2.4 s; tier 5 not.
6. Draw smoke; the finisher spawns 3 strikes on the 6th swing.
