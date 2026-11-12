# Witch Staff (`witchstaff`, Ancient, poison, light weapon (55), fusion tier 2 of Bog Staff + Staff, H = 6.0, inherits `t1x/bogstaff.gd`)

## Today
- Attack Poison bolt (cd 0.5): a green `WeaponProjectile` (speed 240, 1.0 H, life 1.0, PIERCE 1, knock 40) with 5 bleed ticks of 0.9. Hex (tier 2+, cd 7): a `ring` r 70 at the cursor (range 120) and a mud patch r 70 (factor 0.4, 7 s); everything in it is exposed 6 s, hit for 3.0 and gets 9 bleed ticks of 1.0; plus four rotting pustules (r 20 `ground_strike`, 3.0, delays 0.5 to 0.8) round it at 52 px.
- Bog Hop (dash, cd 4, far): a 75 px blink leaving mud r 30 (5 s). Swamp Swell (tier 3+, from the Bog Staff): mud r 125 for 9 s, 10 bleed ticks, then 5 pulses of r 110 every 0.8 s.
- Looks: green rings and mud.

Palette: witch green `Color(0.55,0.90,0.35)`, hex purple `Color(0.60,0.30,0.75)`, brew `Color(0.35,0.70,0.30)`, bone `Color(0.92,0.90,0.80)`. Names: 2 Hex Mark, 3 Pox, 4 Cauldron, 5 Coven, 6 Witch Queen.

THE ANCIENT SYSTEM: **Hex and Rot together** (Bog Staff's Rot stacks plus the Staff's runes). Rot is inherited from `bogstaff.md` (same `wt_rot` meta, same helpers with Witch constants). New here: the **Hex Mark**: a marked enemy (`wt_hex` until 8 s) takes +20% damage from everything (`Game.MARKS["hexed_until"] = 1.2`, one line in `Game.mark_mult`; bosses ignore marks as for every mark) and, when it dies, the curse JUMPS: 2 nearby enemies (within 70 px) are hexed with full duration and a `bolt` fx between. Hex marks are drawn as a purple rune over the head (`star` count 5 radius 7, 0.5 s cadence, 8 enemies max).

## Tier table (fusion tier 2: rows 2 to 6)

| Tier | ART | ATTACK | ABILITY (Hex) | DASH (Bog Hop) | ULTIMATE (Swamp Swell) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Hex Mark | A purple rune-glow on the gem, a trailing wisp (aura `motes` violet); bolts are style `glob` size 1.2 + `trail 4`; aura twinkle. Light +5. | **Hex Mark**: the 3rd bolt in a row at one target hexes it (Hex mark above; it also adds Rot 1 per hit as the Bog Staff would). | **Hex Mark**: the Hex circle marks EVERY enemy in it (not only exposes): `star` runes appear over them; the circle is a `sigil` r 70 (count 5, purple) not a plain ring. | - | locked | lifesteal |
| 3 Pox | Tip glow; rune circle on the ground under the cursor aim line. Light +10. | **Pox**: a bolt that kills a hexed enemy makes the curse jump (above) and the corpse bursts in a pox cloud (`burst_r` 34, 0.8 H = 4.8, adds 2 Rot). | **Pox**: the four pustules become a ring of 6 and each pustule bursting leaves a `slow` patch r 18 (4 s) and hexes enemies inside. | = | unlocked; `sigil` r 125 (purple, 10 points). | lifesteal |
| 4 Cauldron | 3 orbit green/purple motes, gem pixel. Light +15. | **Cursed Bolt**: every 4th bolt is a witch-bolt: size 1.8, pierce 3, `chain 2` (55 px), leaves a `slow` patch on the first victim. | **Cauldron**: the Hex spot gets a CAULDRON for 8 s (drawn as a `star`/`motes` bubbling cauldron: a `sigil` r 20 + `motes` count 8 rising each 0.4 s): every 1.0 s it spits a glob (`WeaponProjectile` style `glob`, size 1.4, 0.6 H = 3.6, homing 1.5, burst r 22) at the nearest enemy within 110 px (adds Rot, hexes). | **Witch Hop**: the hop leaves a cauldron-bubble trail (3 `slow` patches r 16, 4 s) and `streak` (width 6); everything near the start is hexed; the arrival `burst` r 30 (0.8 H). | = | thunder |
| 5 Coven | 5 orbit motes, rune ghost trail. Light +20. | = | = | = | **Stage 2 Coven**: 1.0 s into the swamp, three witch spirits (aura `kind "witches"`, public `phase`, `n_witch` 3) circle at r 60 for 8 s: each fires a `bolt` fx + a hex-bolt (`WeaponProjectile` homing, 0.8 H = 4.8, `chain 1`, applies Hex) every 1.2 s at the nearest unhexed enemy; the swamp mud grows to r 150 with a `vortex` (r 150, count 3) respawned each 1.0 s. | chain |
| 6 Witch Queen | Halo ring (rune ring), 10 motes (violet and green), tip star; a crow of 3 raven silhouettes circle (aura). Light +30. | **Finisher** every 6th bolt: a curse nova: all enemies within 80 px of the target are hexed, each takes 0.5 H and a `ripple` r 80 rings 2. | = | = | **FINALE + TRANSFORMATION Witch Queen (12 s)**: you are the Queen: for 12 s EVERY enemy within 150 px is hexed automatically (a hex pulse each 1.0 s: `ring` + `star`), every hexed enemy takes a curse tick of 0.25 H (1.5, quiet) per second, and each hexed enemy that dies explodes in a toad-swarm: 5 `WeaponProjectile` globs (style `glob`, 0.5 H, speed 120, life 0.6, homing 2.0, burst r 18) in a ring, cap 24 alive. At the end the Queen's Wrath: all hexed enemies within 170 px take 2.0 H (12.0) plus 0.5 H per Rot stack, a `flash` r 85, `ripple` r 170 rings 3, `pillar` height 150 (violet). Shake 8, `Sfx ultimate` + `boss_roar` quiet. | bleed |

Caps (H = 6.0): attack +0.5 H avg (witch-bolt every 4th: chain 2 x 0.6 = 1.2 H/4 = 0.3 H; hexed targets +20% from marks only (a mark, not a stat)); ability pustules 6 x 0.5 H + cauldron 8 globs x 3.6 on distinct targets over 8 s = +3.6 H per target at most (2 spits per target); dash 0.8 H; ultimate: coven bolts 6 x 4.8 spread over several targets (2 on one: 9.6 H) + queen ticks of 0.15 H (0.9) per second = 10.8 H over 12 s + wrath 12 H + Rot 2.5 H, about 35 H on a central target (Ancient k = 52). Marks multiply: the +20% mark is the one multiplier above: do not let two marks stack (`toxic_until` 1.2 and `hexed_until` 1.2 combine to 1.44 as `mark_mult` multiplies: acceptable, both are 6 to 8 s windows).

## What makes this feel like Ancient
Two parents' ideas at once: Rot stacks from the swamp and Hex curses from the arcane side, plus minions (cauldron, witch spirits, toad swarms) and a 12-second transformation that curses the whole screen. Compared with Mythic Bog Staff (a swamp form you stand in), the Witch Staff's curse chains jump from corpse to corpse and its allies act on their own.

## Rules for the implementer
- `items/weapons/tiers/witchstaff.gd` (`preload("bogstaff.gd")` Rot helpers; `Game.MARKS` gets `"hexed_until": 1.2`).
- `witchstaff.gd` edits: bolt counters (`_st.streak` per target for tier 2, every 4th for tier 4 through `pre_attack` setting projectile extras), `ability()` marking, pustule count and cauldron (module `ability(w)` at +0.5 s), `dash_attack()`, `ultimate()` inherited: coven at press + 1.0 s, queen at 5.5 s (the swamp swell ends ~4.3 s: pulses end), wrath at 17.5 s.
- Curse jump: `on_hit` cannot see kills reliably: use a `death watch`: in `tick`, keep `_st.hexed: Array` of weak refs; each tick if an entry became invalid or `health <= 0` -> jump from its LAST known position (store positions each tick).
- Constants: `WS_HEX_SECS := 8.0`, `WS_HEX_JUMP := 2`, `WS_HEX_JUMP_R := 70.0`, `WS_POX_MULT := 0.8`, `WS_PUSTULES := 6`, `WS_CAULDRON_SECS := 8.0`, `WS_CAULDRON_EVERY := 1.0`, `WS_CAULDRON_MULT := 0.6`, `WS_WITCHES := 3`, `WS_WITCH_SECS := 8.0`, `WS_QUEEN_SECS := 12.0`, `WS_QUEEN_R := 150.0`, `WS_QUEEN_TICK := 0.15`, `WS_TOADS := 5`, `WS_TOAD_CAP := 24`, `WS_WRATH_MULT := 2.0`, `WS_FINISHER_EVERY := 6`.
- Multiplayer: marks are `WeaponFx star`; witches in the aura; projectiles/patches are net nodes. Never harms players.
- Performance: Queen peak ~40 fx/s + 24 projectiles cap.

## How to test (section `witchstaff`)
1. Hex Mark: tier 2: three bolts at one dummy set `wt_hex` and `Game.mark_mult(e) >= 1.19`; tier 1 none; the Hex circle marks 3 dummies.
2. Pox: tier 3: kill a hexed dummy (hp 1): its neighbours at 50 px become hexed; a cloud damages a neighbour.
3. Cauldron: tier 4: a cauldron spits >= 3 projectiles in 4 s at a dummy 80 px away; the 4th bolt has `size >= 1.5`.
4. Coven: tier 5 ultimate: aura `n_witch == 3` for ~8 s and homing projectiles with Hex; tier 4 none.
5. Witch Queen: tier 6: dummies within 150 px are hexed automatically; one killed leaves 5 projectiles; at ~17.5 s `flash` r 85 and a dummy takes >= 12.
6. Draw smoke; Bog Staff unaffected.
