# Bulwark Maul (`bulwark`, Epic, crush, fusion tier 2 of Hammer + Shield, H = 7.69)

## Today
- Attack: slow maul `swing(1.1)`, 0.22 s later `arc` r 32 (+-60 degrees), 1.0 H, knock 340, stun 0.4, shake 2, breaks stones. Brace (hold right click, tier 2+, cd 8): you move at 40% and are untouchable (parry stays open); each blow you block stores a charge (max 5); on release (or after 3 s) a ring of r 30 + 8 x stored hits for 2 + 1.5 x stored, knock 240 + 40 x stored, stun 0.5 + 0.2 x stored.
- Shoulder Charge (cd 5): 60 px dash, hits 2.0, knock 380, stun 0.8. Quake Fortress (tier 3+): 4 s `shield_time` and 4 pulses (r 52, 2.0, knock 280, stun 0.5, 1 s apart). Juggernaut and Worldbreaker extend it.
- Looks: blue rings, gold ring when blocking.

Palette: maul steel `Color(0.60,0.75,1.0)`, gold `Color(1.0,0.85,0.40)`, white `Color(0.95,0.97,1.0)`, iron `Color(0.45,0.50,0.60)`. Names: 2 Counterweight, 3 Fortress Slam, 4 Bulldozer, 5 Citadel Pulse, 6 Titan's Judgment.

## Tier table (fusion tier 2: rows 2 to 6)

| Tier | ART | ATTACK | ABILITY (Brace) | DASH (Shoulder Charge) | ULTIMATE (Quake Fortress) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Counterweight | Head and shield-plate both shine; aura twinkle; while bracing, a translucent half-dome shield (r 16, `steel`) is drawn in front of you (aura `state` = stored charges 0..5). | Maul hits throw `shards` count 4 r 14 | **Counterweight**: each absorbed blow also shoves attackers back (a `ring` r 24, push 200 from `_on_absorb`) and pops a `star` (count = stored). | - | locked | lifesteal |
| 3 Fortress Slam | Tip glow; heavy dust trail. | **Fortress Slam**: every 3rd maul is a slam: `shock` r 40 + `crack` count 6, hit circle r 40, 1.0 H + 0.8 H, stun 0.8. | **Fortress Slam**: while braced, the maul swing (left click) still works: a shield bash (0.5 H, knock 200) that stores nothing but extends the brace timer by 0.5 s (cap 4.5 s total, `BM_BRACE_MAX`). | = | unlocked; `sigil` r 60 (`steel`, 8 points) 0.3 s. | lifesteal |
| 4 Bulldozer | 2 orbit steel motes, gem pixel. | = | **Overpressure**: at 5 stored charges the release also fires a forward `cone` r 90 half 0.7: 1.5 H (11.5), knock 400; the release ring becomes a `shock` r = ring radius. | **Bulldozer**: the dash is a `streak` width 12 (`steel`); enemies are carried along 50 px and slammed at the end: `shock` r 36, 1.0 H (7.7), stun 1.0; a trail of 3 `crack`. | = | thunder |
| 5 Citadel Pulse | 4 motes, shield ghost. | = | = | = | **Stage 2 Citadel Pulse**: the 4 pulses grow (r 52, 64, 76, 88; knock 280) and each pulse sends out a ring of 6 `shards` fragments (`WeaponProjectile` style `shard`, 0.3 H = 2.3, speed 200, life 0.3); the fortress also absorbs enemy shots within 40 px (frees `enemy_shot`). | thunder |
| 6 Titan's Judgment | Halo ring, 8 motes, tip star; the aura draws a faint full-body shield while `shield_time > 0`. | **Finisher** every 6th maul: a 2-ring slam r 34 then 52 (0.15 s later) with `crack`. | = | = | **FINALE Titan's Judgment**: when the fortress ends, a great slam at your position: `sigil` r 90 (0.4 s telegraph), then `flash` r 90, `shock` r 90 thick 9, `crack` count 12; all in r 90 take 2.0 H (15.4) + 0.5 H per pulse they were hit by (up to 4 pulses: +2 H), knock 420, stun 1.2. Shake 6.5, `Sfx thump` + `big_hit` + `ultimate`. | chain |

Caps (H = 7.69): attack avg +0.3 H; ability cone 1.5 H once per release; dash 1.0 H; ultimate stage 2 6 x 0.3 H fragments (one or two hit one target) + finale 2.0 to 4.0 H vs today 4 x 2.0 = 8.0 (1.0 H): this is a defensive ultimate, so numbers are generous: finale up to 4.0 H max.

## What makes this feel like Epic
A stance weapon with consequences: the dome, the stored charges, the fortress that eats shots. The upgrades make the stance proactive (bash while braced, bulldozer). Compared with Rare Shield (a parry window), the Maul holds a stance for seconds and has a big three-stage ultimate (fortress, pulses, judgment).

## Rules for the implementer
- `items/weapons/tiers/bulwark.gd`; `bulwark.gd` edits: `_on_absorb` (push ring and star), `use_ability` / braced state: left click while braced (`use_item` override: `if _braced and tier >= 3: bash()`), `release_ability()` (cone at 5 stored; end of function `WeaponTiers.run(self, "release")`), `dash_attack()`/`_on_dash_hit` (carry), `ultimate()` unchanged: the module schedules pulses at tier 5 (replaces `pulse_around`: add `if tier >= 5: _fortress_pulses()`; the old call stays for tiers 3 and 4) and the finale at 4.0 s.
- Juggernaut and Worldbreaker extend `bulwark.gd`, but their modules (different `weapon_id`) are separate; they `preload("bulwark.gd")`.
- Constants: `BM_PUSH := 200.0`, `BM_SLAM_EVERY := 3`, `BM_BASH_MULT := 0.5`, `BM_BASH_EXTEND := 0.5`, `BM_BRACE_MAX := 4.5`, `BM_CONE_R := 90.0`, `BM_CONE_MULT := 1.5`, `BM_CARRY := 50.0`, `BM_PULSE_R := [52, 64, 76, 88]`, `BM_FRAGMENTS := 6`, `BM_FINALE_MULT := 2.0`.
- Pulses and the finale call `_claim()` on resume.
- Multiplayer: the dome and the stored count via the aura `state`; the fortress shield is the player's own `shield_time` (already synced as a tint).
- Performance: finale 4 pulses x (1 ring + 6 projectiles) = 24 projectiles at once: stagger by 0.05 s and cap alive projectiles at 40.

## How to test (section `bulwark`)
1. Counterweight: tier 2 brace, an enemy hit on the player (call `player.take_damage` with a source): attackers within 24 px are pushed; `star` kind seen.
2. Fortress Slam: tier 3 3 maul swings: the 3rd hits a dummy at 38 px (outside 32); braced bash hurts a dummy at 20 px for ~0.5 H; brace timer extended.
3. Overpressure/Bulldozer: tier 4 with 5 stored charges the cone hits a dummy at 80 px; dash carries a dummy 50 px.
4. Citadel Pulse: tier 5 ultimate: dummy at 80 px hit by pulses 3 and 4 only; >= 12 projectiles spawned over 4 s; an `enemy_shot` inside 40 px is freed.
5. Titan's Judgment: tier 6: at ~4.4 s kind `flash` r 90 seen; a dummy at 70 px takes >= 15 extra and is stunned >= 1.0 s.
6. Draw smoke; Juggernaut still brace-stores up to 8 (unchanged).
