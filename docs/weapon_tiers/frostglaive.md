# Frost Glaive (`frostglaive`, Rare, ice, H = 3.75)

## Today
- Attack Cleave: `swing(1.0)`, `arc` r 30 (+-55 degrees), 1.0 H (x1.5 on an exposed target), knock 80; every hit chills (`apply_slow(0.5, 1.5)`) and exposes 1.5 s. Glacial Line (tier 2, cd 6): six ground strikes along the aim from 22 px every 18 px (r 18 + i, delays 0.35 + 0.09 i, 2.6, knock 120, stun 0.5). Skate (cd 4): 90 px slippery dash, hits 1.0, chills.
- Deep Freeze (tier 3): ring r 145 (0.6 s), then after 0.3 s every enemy in 145 px takes 3.0, stun 2.5, exposed 4 s. Looks: pale blue arcs and rings.

Palette: ice `Color(0.70,0.90,1.0)`, deep `Color(0.35,0.60,0.90)`, frost white `Color(0.92,0.98,1.0)`, shard `Color(0.80,0.95,1.0)`. Names: 2 Rime, 3 Ice Comb, 4 Ice Rink, 5 Whiteout, 6 Absolute Zero.

## Tier table

| Tier | ART | ATTACK | ABILITY (Glacial Line) | DASH (Skate) | ULTIMATE (Deep Freeze) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Rime | Aura twinkle (snowflake sparkle: a 6-point `star` mini every 1.6 s); frost mist: 1 `motes` (white) falls from the blade every 0.6 s. | Chilled enemies show frost `motes` count 2 (every 0.6 s, at most 4) | **Rime**: each spike leaves a frost patch on the line: a `slow` patch r 14, factor 0.6, 3 s (6 of them, merged into 3: every 2nd spike) and the eruptions throw `shards` count 4 r 18. | - | locked | thunder |
| 3 Ice Comb | Tip glow (ice); a pale trail. | **Ice Comb**: every 3rd cleave throws 3 ice shards (`WeaponProjectile`, style `shard`, 0.6 H = 2.3, pierce 1, speed 280, life 0.35, chill) in a fan of 0.3 rad; `shards` count 6. | = | = | unlocked; `sigil` r 100 (`ice`, snowflake count 6) for 0.25 s growing to full, then the ring. | thunder |
| 4 Ice Rink | 2 orbit snow motes, gem pixel (sapphire). | = | **Frozen Fan**: after the line a second line of 4 spikes fans out at +-0.45 rad (r 14, 0.5 s delay, 1.4 each, stun 0.4); the strikes use `crack` fx between spikes. | **Ice Rink**: the dash leaves a frozen trail along its length: 3 `slow` patches r 14, factor 0.4 (they also make enemies slide: the existing `Hazard` slow only); everything you pass is chilled 2.5 s and exposed 2 s; `streak` (width 7, `frost white`). | = | bleed |
| 5 Whiteout | 4 motes (snow), ice ghost trail. | = | = | = | **Stage 2 Whiteout**: for 4 s after the freeze a blizzard fills r 120: `vortex` fx (r 120, count 3, spin -3, life 1.0) respawned 4 times, snow `motes` count 14; every enemy in it is chilled (slow 0.5 refreshed), exposed, and takes 0.2 H (0.75) per second (quiet, 4 ticks of one per second, aoe). | bleed |
| 6 Absolute Zero | Halo ring, 6 motes (white-blue), tip star (snowflake). | **Finisher** every 6th cleave: a frozen shockwave `slash` r 44 that stuns 0.8 s and hits for +0.6 H. | = | = | **FINALE Absolute Zero**: when the whiteout ends all exposed/frozen enemies within 140 px shatter: 1.5 H each (5.6; x1.5 = 8.4 on exposed), `shards` count 24 r 140 (ice), `flash` r 60, `ripple` r 140 rings 3; everyone in 140 px stunned 1.0 s (`WeaponUtil.stun`; bosses slowed 0.35). Shake 5.5, `Sfx big_hit` + `ultimate`. | chain |

Caps (H = 3.75): attack avg +0.5 H (3 shards 2.3 each, only one or two hit one target: +0.46 H per 3 swings); ability line patches (control) + fan 1.4 each = +2 H on a target in the middle of both (accept: Rare cap +60% of today's 2.6 x ~3 hits); dash 0; ultimate whiteout 3 x 0.75 + finale 5.6 (8.4) vs today 3.0 + control.

## What makes this feel like Rare
A control weapon: its payoff is a chain of conditions (chilled, exposed, frozen) and the last tiers all cash those in. Compared with Spear (Common), the Glaive keeps several statuses on several enemies and its ultimate has a setup, a lingering field and a delayed shatter.

## Rules for the implementer
- `items/weapons/tiers/frostglaive.gd`; `frostglaive.gd` edits: `ability()` patches / second fan, `dash_attack()` patches (use the position before dash `o` and `aim`), module for the rest. Rimelance `extends frostglaive.gd` (uses `_chill`), but has its own module.
- Frost white patches: `WeaponUtil.patch(world, pos, "slow", 14, Color(0.8,0.95,1.0,0.5), 3.0, 0.6)`. Keep a cap of 6 patches alive per player (count `hazard` nodes whose position is within 120 px).
- Constants: `FG_COMB_EVERY := 3`, `FG_COMB_MULT := 0.6`, `FG_FAN_ANGLE := 0.45`, `FG_FAN_N := 4`, `FG_RINK_PATCHES := 3`, `FG_WHITEOUT_SECS := 4.0`, `FG_WHITEOUT_R := 120.0`, `FG_WHITEOUT_TICK := 0.2`, `FG_FINALE_R := 140.0`, `FG_FINALE_MULT := 1.5`, `FG_SHATTER_EXPOSED := 1.5`, `FG_FINISHER_EVERY := 6`.
- Whiteout ticks run in `tick(w, delta)` with a `_st.whiteout_until`; finale at `until`; both cancelled if the weapon leaves the tree.
- Multiplayer: nothing else. Performance: peak about 24 fx and 3 projectiles.

## How to test (section `frostglaive`)
1. Rime: tier 2 line: a `slow` hazard (factor 0.6) exists near the line at 0.8 s; a dummy walking in it (physics on) is slower than tier 1.
2. Ice Comb: tier 3, 3 cleaves: the 3rd spawns 3 projectiles of style `shard`; a dummy at 70 px in aim takes damage only then.
3. Frozen Fan: tier 4 ability: a dummy at 40 px, +0.45 rad off the aim, takes 1.4 within 1.2 s; tier 3 not. Rink: a dash through a dummy chills it 2.5 s (`slow_time`).
4. Whiteout: tier 5 ultimate: a dummy at 100 px loses health in >= 3 ticks over 4 s after the freeze and stays `slow_mult < 1`; tier 4 not.
5. Absolute Zero: tier 6: kind `flash` seen at ~5.0 s, an exposed dummy takes >= 8 in one step; tier 5 not.
6. Draw smoke; finisher at the 6th cleave stuns a dummy at 40 px.
