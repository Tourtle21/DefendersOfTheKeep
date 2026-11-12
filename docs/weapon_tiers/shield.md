# Shield (`shield`, Rare, no element, H = 5.0)

## Today
- Attack Bash: `thrust(9)`, `arc` r 22 (+-65 degrees), 1.0 H, knock 300, stun 0.5. Parry (tier 2, cd 8): for 0.35 s `player.parry_time` is open; if something hits you in the window: a gold `ring` r 56, shockwave 3.5 to everything in 56 px, knock 320, stun 1.6, 0.4 s of invulnerability, shake 3, and the cooldown is cut to 20%. If nothing hits you, a plain 1.0 s protective shield.
- Shield Charge (cd 5): 55 px dash, hits 1.0, knock 320, stuns what it hits 0.6 s. Bastion (tier 3): 5 s untouchable (`shield_time`) and 5 shoving pulses of r 46 every 0.9 s (2.5, knock 270, stun 0.35).
- Looks: blue arcs and rings; the weapon is a round blue shield with a gold boss.

Palette: steel blue `Color(0.50,0.70,1.0)`, gold `Color(1.0,0.90,0.40)`, white `Color(0.95,0.97,1.0)`, shadow `Color(0.20,0.30,0.55)`. Names: 2 Reflection, 3 Shield Slam, 4 Ram, 5 Citadel, 6 Aegis Eternal.

## Tier table

| Tier | ART | ATTACK | ABILITY (Parry) | DASH (Shield Charge) | ULTIMATE (Bastion) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Reflection | Aura twinkle on the boss; while the parry window is open the shield rim glows white (aura `state` 1). | Bash hits throw `shards` count 3 r 12 (blue) | **Reflection**: a successful parry sends every `enemy_shot` within 80 px back (velocity reversed, now hurting enemies: reuse the card trick `sh.vel = -sh.vel` and join `ally` shots via the same helper Aegis uses) and the shockwave is a `ripple` r 56 rings 2 with 6 `star` points. | - | locked | chain |
| 3 Shield Slam | Tip glow; rim glints. | **Shield Slam**: every 3rd bash is a `cone` r 34 (half 1.0): +1.0 H, stun 0.9, knock 360, `shock` r 20 at the point of impact. | = | = | unlocked; `sigil` r 46 (`steel blue`) 0.25 s. | chain |
| 4 Ram | 2 orbit motes (white), gem pixel. | = | **Retaliation**: a parried enemy (the attacker, found by `on_parry(from)`) is exposed for 3 s and the player's next 3 bashes within 4 s deal x1.5 and knock x1.3 (`_st.retal = 3`, shown by 3 gold dots on the aura `state`). | **Ram**: the dash is a `streak` (width 10, steel); enemies are carried along (pushed with the dash direction each time they are hit, once); at the end `shock` r 36 hits all within 36 for 0.8 H (4.0), stun 0.8. | = | lifesteal |
| 5 Citadel | 4 motes, rim ghost. | = | = | = | **Stage 2 Citadel**: the pulses grow (r 46, 54, 62, 70, 78) and each pulse sends a `ripple` ring; shots entering r 40 are destroyed (`enemy_shot` group, `queue_free`) with a `burst`; the 5th pulse is a Nova: 1.5 H (7.5), stun 1.2, knock 380. | lifesteal |
| 6 Aegis Eternal | Halo ring, 6 motes, tip star; the boss glows gold. | **Finisher** every 6th bash: a bash plus an immediate counter-thrust (a 50 px `streak` line, 1.0 H). | = | = | **FINALE Aegis Eternal**: when the 5 s end the shield bursts: `flash` r 80, `shards` count 12 r 90, `ripple` r 90 rings 3; everything in r 80 takes 1.2 H (6.0), knock 360, stun 1.0 (`WeaponUtil.stun`); you get 0.6 s extra `shield_time` (never above +25%). Shake 5.5, `Sfx big_hit` + `ultimate`. | thunder |

Caps (H = 5.0): attack avg +0.3 H; ability reflection: reflected shot damage is the enemy's own, no extra; dash +0.8 H; ultimate Nova 7.5 + finale 6.0 vs today 12.5 = +108% (accept: the shield deals the least damage per second of its band; pulses 2 to 4 use the old 2.5). Invulnerability: 5 s + 0.6 = +12%.

## What makes this feel like Rare
Everything is conditional (windows, stacks). The Shield asks you to read incoming attacks: the Parry window and its payoffs (reflect, retaliation). The upgrades make the payoffs bigger rather than the spectacle wider. Compared with Hammer (Common), the Shield's best moments only happen when you get hit.

## Rules for the implementer
- `items/weapons/tiers/shield.gd`; `shield.gd` edits: `_on_parry` (reflection, retaliation setup; uses the `from` position to find the attacker = the nearest enemy to `from`), `attack()` damage multiplier from `_st.retal` (`pre_attack`: sets `_st.mult`) and the 3rd-bash cone in `attack(w)`, `dash_attack()` carry + end shock (schedule 0.24 s), `ultimate()` unchanged: the module replaces the 5 pulses at tier >= 5 by the growing ones (set a flag so the old pulses do not also run: add `if WeaponTiers.owns(self, "bastion"): return` at the top of the old `pulse_around` line, or call a new `_bastion(tier)` that `ultimate()` uses for tiers >= 5).
- Projectile reflect: set `vel = -vel`, `set_meta("friendly", true)` and have `EnemyProjectile` skip players for friendly shots, hurting enemies instead (one line there, document it). If the Aegis spell already offers that helper, call it: `SpellTiers.reflect_shot(sh)`.
- Constants: `SHIELD_SLAM_EVERY := 3`, `SHIELD_SLAM_MULT := 1.0`, `SHIELD_RETAL_BASHES := 3`, `SHIELD_RETAL_MULT := 1.5`, `SHIELD_RAM_MULT := 0.8`, `SHIELD_PULSE_R := [46, 54, 62, 70, 78]`, `SHIELD_NOVA_MULT := 1.5`, `SHIELD_FINALE_MULT := 1.2`, `SHIELD_FINISHER_EVERY := 6`.
- Multiplayer: parry window glow and retaliation dots through the aura `state`; fx via `WeaponFx`.
- Performance: Bastion tier 6 about 20 fx (5 pulses x 2 + finale 6).

## How to test (section `shield`)
1. Reflection: tier 2 parry with an `enemy_shot` node nearby (create one with `vel` toward the player): after the hit its velocity points away; tier 1 unchanged.
2. Shield Slam: tier 3, 3 bashes, dummy at 31 px (outside 22, inside 34): only the third hurts it and it is stunned >= 0.8 s; kind `cone` seen.
3. Retaliation / Ram: tier 4 after a parry, the next bash does x1.5 (compare health lost); the dash carries a dummy and a second dummy 30 px past the end takes 0.8 H from the end shock.
4. Citadel: tier 5 ultimate: pulse radii grow (dummies at 60 px are hit only by pulses 3 to 5); a spawned `enemy_shot` within 40 px is freed; the 5th pulse stuns >= 1.0 s.
5. Aegis Eternal: tier 6: at 5.1 s kind `flash` r 80 seen and a dummy at 70 px takes >= 1.2 H, stunned; tier 5 not.
6. Draw smoke; finisher: the 6th bash spawns a `streak` and a second hit.
