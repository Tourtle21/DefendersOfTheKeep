# Sword (`sword`, Common, tool, no element, H = 2.0)

## Today
- Attack: Slash, an animation-driven hitbox arc (sprite sheet `excalibur_.png`, 0.4 s swing); 2.0 damage through `Enemy.take_damage` (`SWORD_HIT`), not scaled by `WeaponUtil.power`.
- Ability (tier 2): Whirlwind, 3 pulses of r 34 x `area()` every 0.3 s, 2.0 each, knock 160, you keep moving. Dash: Slash Dash, 50 px dash then a 28 px 130-degree slash (2.5). Ultimate (tier 3): Blade Tempest, 16 pulses of r 44 x `area()` every 0.15 s, 2.0 each, knock 140.
- All of it is plain white `ring`/`arc`/`line`. `Tool.area()` already grows every area by 12% per tier. Class is `Tool` (`items/item.gd`), not `Weapon`.

Palette: steel `Color(0.80,0.86,0.95)`, edge `Color(0.95,0.98,1.0)`, glint `Color(1.0,1.0,1.0)`, wind `Color(0.7,0.85,1.0)`.
Names: 2 Gale, 3 Crescent, 4 Riposte Step, 5 Bladestorm, 6 Last Cut.

## Tier table (rows are cumulative; `=` means unchanged from the row above)

| Tier | ART | ATTACK | ABILITY (Whirlwind) | DASH (Slash Dash) | ULTIMATE (Blade Tempest) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Gale | Aura twinkle (tier 2 recipe); sprite `modulate` shimmers to `edge` for 0.15 s after each swing. Sword icon in HUD polished. | Every swing that hits throws a `burst` r 8 (`glint`) on up to 3 enemies in the 26 px, 60-degree arc (visual only; hitbox does the damage). | **Gale**: pulse radii grow 1.0 / 1.15 / 1.3 x (34 x `area()`); the 3rd pulse shoves (`push` 300) and chills `apply_slow(0.5, 1.0)`. Pulses draw a `slash` r = pulse radius thick 6 instead of the plain ring. | - | locked | lifesteal |
| 3 Crescent | Tip glow (tier 3 recipe), a short white trail behind the blade during the swing (3 faded lines from the aura `swing`). | **Crescent**: every 3rd swing also fires a `slash` fx (r 38 x `area()`, 65-degree half angle, `edge`) and hits the arc for +1.0 H (2.0), knock 120, plus `shards` count 4. | = | = | unlocked. **Sigil**: a `sigil` r = 44 x `area()` count 6 under you for 0.25 s before pulse 1 (Common-size telegraph); Blade Tempest otherwise as today. | lifesteal |
| 4 Riposte Step | Orbit motes (2), accent gem pixel. | = | = | **Riposte Step**: the dash line is a `streak` (width 5); after the arrival slash, 0.14 s later a return cut sweeps the opposite way (`slash`, same radius/angle, +1.0 H, knock 160 pulling toward you), so you cut forwards and backwards. | = | thunder |
| 5 Bladestorm | 4 motes, swing ghost, trail of tip positions. | = | = | = | **Stage 2 Bladestorm**: pulses 4, 8, 12, 16 each fire 2 wind blades (`WeaponProjectile`, style `blade`, size 0.8, speed 240, life 0.3, dmg 0.5 H = 1.0, pierce 1, knock 60) in opposite directions at `pulse_index * 0.7 rad`; an `orbit` fx (shape `blade`, count 4, r 40 x `area()`, spin 8, life 0.7) re-spawned every 0.6 s shows four blades circling you. | thunder |
| 6 Last Cut | Halo ring, 6 motes (Common aura cap 4: use 4), tip star. | = | = | = | **FINALE Last Cut**: 0.2 s after pulse 16 a `cut` (r 40 x `area()`) and a `shock` (r 60 x `area()`, thick 6) land; every enemy in r 60 x `area()` takes 2.5 H (5.0) with knock 300; `flash` r 26 at you, shake 4.5, `Sfx big_hit`. Skipped if the ultimate was interrupted (weapon swapped). | bleed |

Cumulative caps check (H = 2.0): attack riders avg +0.33 H; ability +0 damage (shape); dash +1.0 H; ultimate: blades 8 x 1.0 (on one target 2-3 hits) + finale 5.0 vs today's 32 = +40%.

## What makes this feel like Common
It stays one clean white shape at a time. Compared with the Daggers (Uncommon) which need a combo reading (expose, backstab), the Sword only ever asks you to spin and cut: no state to track. The tier 6 spectacle is a single readable X-cut and ring, about six added fx nodes and one sound. A Common at tier 6 is about as showy as an Uncommon at tier 3.

## Rules for the implementer
- File `items/weapons/tiers/sword.gd` (static functions: `equip`, `attack`, `ability`, `dash`, `ultimate`, `tick`). `Tool` (`items/item.gd`) needs the facade of `_SCALING.md` 5.2 first (`weapon_id`, `player`, `aim`, `fx`, `game_world`, `_st`, hook calls).
- Constants: `SWORD_CRESCENT_EVERY := 3`, `SWORD_CRESCENT_R := 38.0`, `SWORD_GALE_GROW := [1.0, 1.15, 1.3]`, `SWORD_GALE_PUSH := 300.0`, `SWORD_RETURN_DELAY := 0.14`, `SWORD_BLADE_PULSES := [4, 8, 12, 16]`, `SWORD_FINALE_MULT := 2.5`, `SWORD_FINALE_R := 60.0`.
- `Tool.use_ability` runs Whirlwind inline (a loop with `await`). Change the radius to `34.0 * area() * grow[i]` and, on `i == 2` and `tier >= 2`, push/chill the circle; the module only draws extra visuals (the `slash` replacing `ring` when `tier >= 2`). Blade Tempest is `WeaponUtil.pulses` (16 pulses): replace the call by a local loop (same timings) when `tier >= 5` so pulses 4/8/12/16 can fire blades; keep the original call for tiers 3-4. The finale runs after the loop with `if tier >= 6 and is_inside_tree()`.
- Crescent counter: `_st.swings += 1` in `attack(w)`; guard double-count with `_st.last_swing_ms` (ignore clicks within 250 ms). The extra hit happens 0.12 s after the click (the hit moment of the animation); it only hits if `w.player` has not been freed.
- Everything that damages calls `w._claim()` first, uses `WeaponUtil.hit(e, dmg, pos, knock)`; the echo/return cut and blades use `quiet = true` only for blades after the first target.
- Multiplayer: all visuals via `WeaponFx.spawn`; blades are `WeaponProjectile` (net); aura per 5.1. The tier shimmer on the sprite is local (`modulate`), cosmetic only.
- Performance: Blade Tempest tier 6 peaks at about 12 live fx (16 `slash` rings are replaced by 16 short-lived `slash`; keep `life` 0.2) and 2 projectiles per volley, 8 total; well under caps.

## How to test (`weapon_tier_abilities.gd`, section `sword`)
1. Gale: tier 2 vs tier 1, a dummy at 30 px: after Whirlwind the tier 2 dummy has `slow_mult <= 0.51` and is pushed further (> 12 px more) than tier 1; fx kind `slash` seen.
2. Crescent: tier 3, three clicks (spaced 0.5 s) next to a dummy at 30 px: the third click's total damage is >= 1.9 H more than the first; fx `slash` seen exactly once in 3 swings; tier 2 never sees it.
3. Riposte Step: tier 4 dash through a line of 2 dummies, one ahead and one that the first slash does not reach but the return cut does (placed 25 px behind the arrival point): it takes damage at tier 4, none at tier 3.
4. Bladestorm: tier 5 ultimate with a dummy at 45 x `area()` px: `WeaponProjectile` count seen >= 2 within 1.2 s; at tier 4 zero; kind `orbit` seen at tier 5.
5. Last Cut: tier 6 ultimate: kinds `cut` and `shock` seen, a dummy at 50 x `area()` px takes >= 5.0 more than at tier 5 (equal pulses), and the Sword still has Gale (check 1 at tier 6).
6. Draw smoke tiers 1-6 incl. aura count (0 at tier 1, 1 afterwards); no script error.
