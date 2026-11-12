# Pickaxe (`pickaxe`, Common, tool, no element, H = 2.0)

## Today
- Attack: Mine, an animation hitbox swing (sprite sheet `pickaxe.png`), 2.0 to enemies, breaks rocks and trees. Ability (tier 2) Seismic Strike: `WeaponUtil.ground_strike` at the cursor (range 80), r 24 x `area()` x (1 + 0.25 x (tier-2)), 0.5 s telegraph, 3.0 dmg, knock 260, then `hit_breakables` 3 + 2 x tier times.
- Dash-Mine: 72 px line, 2.0 to everything on it, breaks breakables on the way, dash 70 px. Ultimate (tier 3) Earthquake: ring r 150 x `area()` for 0.6 s, then 4.0 + knock 200 + stun 1.5 to everything, breaks breakables 6 + 3 x tier times, shake 6.
- Looks: one brown `ring` per use. Class `Tool` (see sword.md for the facade).

Palette: stone `Color(0.72,0.55,0.35)`, dust `Color(0.90,0.78,0.55)`, spark `Color(1.0,0.90,0.50)`, rock `Color(0.45,0.42,0.40)`.
Names: 2 Shatter, 3 Heavy Mine, 4 Rubble Trail, 5 Aftershocks, 6 Rockfall.

## Tier table

| Tier | ART | ATTACK | ABILITY (Seismic Strike) | DASH (Dash-Mine) | ULTIMATE (Earthquake) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Shatter | Aura twinkle; the head of the sprite flashes `spark` for 0.1 s on every rock it breaks (`burst` r 8 at the rock, via `hit_breakables` caller). | Hits on enemies throw 2 `shards` (count 2, r 12, `dust`) | **Shatter**: the strike throws rock debris: `shards` count 6 r = 1.6 x strike radius; every enemy in that wider ring (not already in the core) takes 0.5 H (1.0) and `push` 100. `crack` count 4 at the centre stays 0.6 s. | - | locked | lifesteal |
| 3 Heavy Mine | Tip glow; swing trail. | **Heavy Mine**: every 3rd swing also sends a short shockwave: `shock` r 30 (thick 4) 20 px ahead, +1.0 H (2.0), knock 140, `hit_breakables` 2 extra times at that spot. | = | = | unlocked; a `sigil` r 60 for 0.25 s before the 0.6 s ring (the ring still takes the old 0.6 s; the sigil draws inside it). | lifesteal |
| 4 Rubble Trail | 2 dust motes orbit, gem pixel. | = | = | **Rubble Trail**: the dash line is a `streak` (width 7, `dust`); 3 rubble `slow` patches (`WeaponUtil.patch`, r 14, factor 0.6, 2.5 s) along it; enemies passed are `push`ed sideways 120 and `motes` count 6 rise. | = | thunder |
| 5 Aftershocks | 4 motes, swing ghost. | = | = | = | **Stage 2 Aftershocks**: 0.5 s and 1.0 s after the main quake two smaller `shock` rings (0.7 and 0.5 of the radius): everything inside takes 0.5 H (1.0) and a 0.6 s stun (`WeaponUtil.stun`); each breaks breakables 2 more times; `crack` count 8 on the ground for 1.0 s. | thunder |
| 6 Rockfall | Halo ring, 4 motes (Common cap), tip star. | = | = | = | **FINALE Rockfall**: after the last aftershock 4 boulders fall (`fall` fx radius 5 life 0.4) at 4 random enemies within the quake radius (or random points if none), each a `ground_strike` r 14, 0.4 s, 1.25 H (2.5), knock 200, with a `flash` r 20 on impact; shake 4.5, `Sfx big_hit` x2. | bleed |

Caps (H = 2.0): attack avg +0.33 H; ability +0.5 H debris; dash +0 (control); ultimate stage 2 up to 2.0 on one target + finale 2.5 vs today 4.0 (+ breakables): small because the Earthquake is mostly a stun field.

## What makes this feel like Common
Brown dust, cracks and falling rocks: no status system, no combos. The Pickaxe remains the weapon whose point is mining; every new thing either breaks more rocks or shoves enemies. Compare with Quake Pick (Uncommon, its fusion with the Hammer) whose fissure travels in a line and pops in sequence.

## Rules for the implementer
- `items/weapons/tiers/pickaxe.gd`; the `Tool` facade from `_SCALING.md` 5.2 (same as sword).
- Constants: `PICK_DEBRIS_R := 1.6`, `PICK_DEBRIS_MULT := 0.5`, `PICK_HEAVY_EVERY := 3`, `PICK_TRAIL_PATCHES := 3`, `PICK_AFTERSHOCKS := [[0.5, 0.7], [1.0, 0.5]]`, `PICK_ROCKS := 4`, `PICK_ROCK_MULT := 1.25`.
- Seismic Strike: `await WeaponUtil.ground_strike(...)` already returns after the hit; the module's `ability(w)` waits `0.5 s` and does the debris (so it runs with the strike). Reuse the same centre `c` computed by `Tool.use_ability` by storing it in `w._st.strike_c` there (one line).
- Dash-Mine: `Tool.use_dash` computes `o` and `aim`; store them in `_st` before calling `dash(w)`.
- Earthquake: `Tool.use_ultimate` awaits 0.6 s then loops; the module's `ultimate(w)` starts in parallel and schedules aftershocks at 0.6 + 0.5, 0.6 + 1.0 and the rockfall at 0.6 + 1.7 s. Every callback starts with `if !is_instance_valid(w) or !w.is_inside_tree(): return` and calls `w._claim()` before hits.
- Boulders: pick targets with `WeaponUtil.random_enemies(tree, o, er, 4)`; bosses can be hit but not stunned.
- Multiplayer: effects are `WeaponFx`/`Hazard`; nothing else. Performance: peak about 14 fx and 3 patches.

## How to test (section `pickaxe`)
1. Shatter: tier 2 strike with a dummy at 1.3 x strike radius (outside the core): it takes >= 0.9 damage (before power) and moves; tier 1 does not; fx `crack` and `shards` seen.
2. Heavy Mine: 3 swings next to a dummy at 24 px: the third produces fx `shock` and extra damage >= 1.9; swings 1 and 2 do not.
3. Rubble Trail: tier 4 dash: `count_script("hazard.gd") == 3` right after, with `factor 0.6`; a dummy on the line is pushed sideways; tier 3 leaves 0.
4. Aftershocks: tier 5 ultimate with a dummy at 0.5 x `er` and `health` sampled at 0.7 s, 1.3 s, 2.0 s: it loses health in three steps (quake + 2 aftershocks); tier 4 only one step.
5. Rockfall: tier 6: fx `fall` seen 4 times and a dummy under a boulder takes >= 2.5 extra; tier 5 none; `shake` is not asserted.
6. Draw smoke tiers 1-6 (aura count 0 at tier 1).
