# Rimelance (`rimelance`, Epic, ice, fusion tier 2 of Frost Glaive + Spear, H = 4.81, inherits `frostglaive.gd`)

## Today
- Attack Frost Thrust: `thrust(12)`, `line` fx 52, line half width 9; tip (>= 32 px) 1.0 H, closer 0.45 H, knock 160, every hit chills (`_chill`: slow 0.5 for 1.5 s and exposed 1.5 s). Glaive Throw (tier 2+, cd 6): a `WeaponProjectile` (speed 300, 4.5, pierce 3, life 0.45, knock 120, expose 2 s) that lands 130 px away leaving a `slow` patch r 26 (factor 0.45, 4 s) 0.45 s later.
- Skate (dash, from the glaive): 90 px slippery dash, hits 1.0, chills. Deep Freeze (tier 3+, inherited): ring r 145, 0.3 s later 3.0, stun 2.5, exposed 4 s on everyone in 145 px.
- Looks: pale blue lines, an icy patch.

Palette: ice `Color(0.70,0.90,1.0)`, spear steel `Color(0.90,0.96,1.0)`, deep `Color(0.30,0.55,0.90)`, frost white `Color(0.95,1.0,1.0)`. Names: 2 Icicle, 3 Frostbite, 4 Winter's Edge, 5 Permafrost, 6 Glacier.

## Tier table (fusion tier 2: rows 2 to 6; must out-show Frost Glaive and Spear)

| Tier | ART | ATTACK | ABILITY (Glaive Throw) | DASH (Skate) | ULTIMATE (Deep Freeze) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Icicle | The spearhead is an icicle with a frosted collar; aura twinkle (snowflake); a cold mist (1 `motes` white every 0.6 s). | The tip hit leaves an icicle: `shards` count 4 and an `ice shard` stuck in the target (a `cut` r 6 in blue) | **Icicle**: the thrown glaive spins (the projectile is style `blade` size 1.4, trail 5) and every enemy it passes is chilled 2.5 s; it shatters at the end into 6 `shards` (r 40, 0.4 H = 1.9 each to enemies within 30 px of the landing). | - | locked | bleed |
| 3 Frostbite | Tip glow; a snow trail on the thrust. | **Frostbite**: a chilled enemy hit by a tip thrust gets a frostbite stack (max 3, 3 s, stored in `e.set_meta("wt_frostbite", n)`): at 3 stacks it is frozen (`WeaponUtil.stun` 1.0 s) and shatters for 1.0 H (4.8) with `cut` and `shards` count 8. | The glaive leaves two extra icicle spikes (r 14 `ground_strike`, 0.4 s delay, 1.0 H, stun 0.4) at +-35 px sideways at the landing. | = | unlocked; `sigil` r 100 (snowflake, count 6). | bleed |
| 4 Winter's Edge | 2 orbit snow motes, gem pixel (sapphire). | = | **Winter's Edge**: the glaive returns: after landing it flies back to you (a second projectile, same path, 60% damage, hits what it missed, chills, `bolt`-less) 0.5 s after landing and 0.3 s travel. | **Winter's Edge**: the skate leaves an ice ribbon: a `slow` patch r 18 factor 0.4 for 4 s every 22 px (4 patches), and chills + exposes all passed 3 s; `streak` width 8. | = | chill |
| 5 Permafrost | 4 motes, ghost trail. | = | = | = | **Stage 2 Permafrost**: after the freeze, for 6 s a `slow` patch r 110 (factor 0.4) covers the area and every 0.8 s an icicle `ground_strike` (r 16, 0.35 s, 0.5 H = 2.4, stun 0.3) falls on a random frozen enemy; 8 icicles total; `vortex` (r 110, count 3). | chill |
| 6 Glacier | Halo ring (ice crystals), 8 motes, tip star. | **Finisher** every 6th thrust: a 90-px ice `beam` (width 6) piercing everyone (0.6 H each) and leaving 3 icicle spikes along it. | = | = | **FINALE Glacier**: when Permafrost ends a glacier shatters: `flash` r 70, `shards` count 24 r 130, `ripple` r 130 rings 3; every enemy in r 130 takes 1.5 H (7.2), x1.5 if frozen/exposed, and is stunned 1.0 s (`WeaponUtil.stun`; bosses slowed). Shake 6, `Sfx big_hit` + `ultimate`. | thunder |

Caps (H = 4.81): attack: frostbite shatter 1.0 H per 3 thrusts (0.33 H avg); ability: shards 0.4 H + spikes 1.0 H + return 0.6 x 4.5 = ~+2.5 H (today 4.5 H plus patch): within +60%; dash +0; ultimate icicles 8 x 0.5 H spread + finale 1.5 H (2.25 H exposed) vs today 3.0 H: +100% (the ultimate is a control tool).

## What makes this feel like Epic
Rimelance combines the Glaive's chill system with the spear's tip: stacks (frostbite), a boomerang glaive, a frozen field and a glacier. It is the first weapon of the ice line with a payoff system, not just a status. Compared with Frost Glaive (Rare) its ultimate has three phases (freeze, permafrost, glacier) and a lingering field.

## Rules for the implementer
- `items/weapons/tiers/rimelance.gd` (may `preload("frostglaive.gd")` and call its Absolute Zero-style helpers with other numbers; the Glaive's Ice Comb / Whiteout / Absolute Zero are NOT inherited: dispatch is by `weapon_id`).
- `rimelance.gd` edits: `attack()` frostbite stacks (module `attack(w)` reading hit victims from the line: use `on_hit(w, e, dmg)` to count the stack, only when `WeaponUtil.is_exposed(e)`/slowed), `ability()` shards/spikes/return (timers 0.45, 0.95 s, `create_timer` guarded), `dash_attack()` unchanged: Skate comes from `frostglaive.gd`, so the dash module must be invoked for Rimelance specifically (the hook calls `tiers/rimelance.gd` `dash(w)`).
- Constants: `RL_SHARDS := 6`, `RL_SHARD_MULT := 0.4`, `RL_FROSTBITE_MAX := 3`, `RL_FROSTBITE_T := 3.0`, `RL_FROST_FREEZE := 1.0`, `RL_SPIKES := 2`, `RL_RETURN_MULT := 0.6`, `RL_RIBBON_N := 4`, `RL_PERMA_SECS := 6.0`, `RL_PERMA_ICICLES := 8`, `RL_FINALE_R := 130.0`, `RL_FINALE_MULT := 1.5`, `RL_FINISHER_EVERY := 6`.
- Stun through `WeaponUtil.stun` (cap 2.0 s per 3 s), bosses are slowed not frozen.
- Multiplayer: nothing new beyond `WeaponProjectile`/`Hazard`. Performance: finale ~25 fx.

## How to test (section `rimelance`)
1. Icicle: tier 2 glaive throw through 2 dummies: both chilled 2.5 s (`slow_time >= 2.0`); shards: a dummy within 30 px of the landing loses ~1.9.
2. Frostbite: tier 3, three tip thrusts on a chilled dummy: at the third it is stunned and loses an extra 4.8; two thrusts do not.
3. Return: tier 4: a second projectile appears ~0.5 s after landing and hits a dummy placed in its path; skate leaves 4 `slow` hazards.
4. Permafrost: tier 5 ultimate: a `slow` hazard radius 110 at 1 s; a frozen dummy takes >= 3 icicle hits over 6 s.
5. Glacier: tier 6: `flash` r 70 at ~7.5 s, a dummy at 100 px takes >= 7.2; tier 5 not.
6. Draw smoke; Frost Glaive's own tiers unaffected (dispatch by `weapon_id`).
