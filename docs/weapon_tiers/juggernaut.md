# Juggernaut (`juggernaut`, Mythic, crush, fusion tier 3 of Bulwark Maul + Knight's Blade, H = 8.57, inherits `t2/bulwark.gd`)

## Today
- Attack: the Bulwark maul swing (cd 0.8): `arc` r 32 (+-60 degrees), 1.0 H, knock 340, stun 0.4, shake 2. Fortress (tier 2+, cd 7, hold): brace at 70% speed (`brace_speed 0.7`), untouchable, stores up to 8 blocked hits (`max_store 8`), each block also shoves everything within 30 px (2.0, knock 220, stun 0.3); release: ring r 30 + 8 x stored, 2 + 1.5 x stored, knock 240 + 40 x stored, stun.
- Shoulder Charge (dash): 60 px, 2.0, knock 380, stun 0.8. Unbreakable (tier 3+): 6 s `shield_time` with six pulses of r 58 every 1.0 s (3.0, knock 300, stun 0.6).
- Looks: gold/blue rings, a moving fortress.

Palette: plate `Color(0.62,0.72,0.95)`, gold `Color(1.0,0.85,0.40)`, rivet `Color(0.95,0.95,1.0)`, shadow `Color(0.20,0.25,0.40)`. Names: 3 Siege Plate, 4 Reactive Armour, 5 Siege Engine, 6 Colossus.

THE MYTHIC SYSTEM: **Armour Plates**. The hits you block while braced (`_stored`, max 8) are shown as plates: small gold shields orbiting you (aura `kind "plates"`, `state` = plates, up to 8). Plates are gained by blocking (1 per block) and by the tier 4+ charge, spent by releasing the Fortress (the more plates, the bigger the release: today's stored hits ARE the plates), and from tier 4 each plate is also ammunition for the reactive shard and the Colossus salvo. No new defence: plates never reduce damage taken.

## Tier table (fusion tier 3: rows 3 to 6; entry carries tier 2 and tier 3 upgrades)

| Tier | ART | ATTACK | ABILITY (Fortress) | DASH (Shoulder Charge) | ULTIMATE (Unbreakable) | Twist (est.) |
|---|---|---|---|---|---|---|
| 3 Siege Plate (entry) | The maul has a layered plate shoulder (both parents' dome and crest) and rivets; aura twinkle + glow ring; plates orbit as small gold shields (up to 8). | **Siege Plate**: the maul throws `shards` count 6 and every 3rd swing is a slam (`shock` r 40 + `crack` 6, +1.0 H, stun 0.8). | **Counterweight + Siege Plate**: a block pushes attackers (`ring` r 24, push 200, `star`); while braced, left click is a shield bash (0.5 H) extending the brace 0.5 s (cap 4.5 s). | = | unlocked; `sigil` r 60. Plates (stored hits) show on the aura. | lifesteal |
| 4 Reactive Armour | 3 orbit plates, gem pixel. | = | **Reactive Armour**: each block also fires a plate-shard back at the attacker (`WeaponProjectile` style `shard`, 0.4 H = 3.4, homing 2.0, toward the attacker's position); at 8 stored the release also fires a `cone` r 100 (1.5 H, knock 420). | **Reactive Charge**: the charge is a `streak` (width 12), carries enemies 60 px and slams (`shock` r 40, 1.0 H, stun 1.0); every enemy hit adds a plate (max 8). | = | thunder |
| 5 Siege Engine | 5 plates orbit, ghost trail. | = | = | = | **Stage 2 Siege Engine**: Unbreakable's 6 pulses grow (r 58, 66, 74, 82, 90, 98) and each fires a `ring` of 8 `WeaponProjectile` plate-shards (style `shard`, 0.3 H = 2.6, speed 200, life 0.3, pierce 1), staggered; the fortress absorbs enemy shots within 50 px (frees `enemy_shot`) and each absorbed shot adds a plate. | thunder |
| 6 Colossus | Halo ring (plate ring), 8 plates orbit, tip star; the whole sprite gets a white-gold rim. | **Finisher** every 6th swing: a stomp: `shock` r 50, `crack` count 8, 1.5 H, stun 1.0. | = | = | **FINALE + TRANSFORMATION Colossus (8 s)**: after the pulses you become a Colossus: size x1.25 (the player's `scale` x1.25 visual only: `Sprite2D` scale of the weapon and aura radius), speed 85%, and: every footstep (every 0.5 s) a `shock` r 40 (0.4 H = 3.4, quiet, knock 160), blocks cost nothing and every enemy hit by you is carried (knock 200); all your plates fire as a salvo each second (1 plate -> 1 shard at the nearest enemy, 0.4 H). At the end a titanic slam: `sigil` r 90 (0.4 s), `flash` r 90, `shock` r 100 thick 9, `crack` 12, 2.5 H (21.4) + plates x 0.5 H, knock 440, stun 1.2. Shake 7, `Sfx thump` + `ultimate`. | chain |

Caps (H = 8.57): attack +0.3 H; ability reactive shard 0.4 H per block; dash 1.0 H + plates; ultimate: stage 2 up to 8 x 6 x 0.3 H (a target in the ring meets ~12 shards = 3.6 H... capped at 8 shards per pulse alive: 12 projectiles/s) + Colossus steps 8 x 0.4 H + finale 2.5 H + plates 4 H = ~11 H on a central target vs today 6 x 3.0 = 18 H (+60%).
No invulnerability beyond today's 6 s (+25% = 1.5 s max: the Colossus window does NOT add invulnerability, only "blocks cost nothing", i.e. plates are not consumed).

## What makes this feel like Mythic
A SYSTEM of plates: gain by blocking, spend by releasing, spent by firing; the ultimate turns you into a walking earthquake. Compared with Epic Bulwark Maul, where a brace stores hits and slams once, the Juggernaut turns those stored hits into a visible resource that powers every verb. It is slower than any other Mythic weapon and the heaviest.

## Rules for the implementer
- `items/weapons/tiers/juggernaut.gd` (`preload("bulwark.gd")`; Bulwark's tier 4 to 6 riders are NOT inherited: the Juggernaut's own rows replace them, the entry row replays the Bulwark's tier 2 and 3 riders with Juggernaut constants).
- `juggernaut.gd` edits: `_on_absorb` (reactive shard), plates counter = `_stored` (already a var: public aura `state = _stored`), `dash_attack()` carry and plates, `ultimate()` replaced pulses at tier >= 5 (flag), Colossus in the module: `_st.colossus_until`; the weapon `scale`, `speed_mult 0.85`, the footstep timer in `tick`.
- Worldbreaker `extends juggernaut.gd` and has its own module.
- Constants: `JG_SHARD_MULT := 0.4`, `JG_CONE_R := 100.0`, `JG_CARRY := 60.0`, `JG_PULSE_R := [58, 66, 74, 82, 90, 98]`, `JG_PULSE_SHARDS := 8`, `JG_SHARD_PULSE_MULT := 0.3`, `JG_COLOSSUS_SECS := 8.0`, `JG_STEP_EVERY := 0.5`, `JG_STEP_MULT := 0.4`, `JG_FINALE_MULT := 2.5`, `JG_PLATE_BONUS := 0.5`, `JG_FINISHER_EVERY := 6`.
- Colossus scale: apply to the weapon node only (`w.scale`), not to the player scene (movement collision unchanged): purely visual.
- Multiplayer: plates in aura `state`; shards are net projectiles (cap 24 from pulses). Performance: finale ~25 fx, 24 projectiles.

## How to test (section `juggernaut`)
1. Entry: tier 3 braces store plates (aura `state` increases per `_on_absorb` call); block pushes attackers; bash while braced hurts a dummy at 20 px.
2. Reactive Armour: tier 4: a block spawns a homing projectile of style `shard`; with 8 stored the release hits a dummy at 90 px; charge carries a dummy 60 px.
3. Siege Engine: tier 5 ultimate: >= 24 projectiles over 6 s; pulse radii grow (a dummy at 90 px hit only by pulses 5 and 6); an `enemy_shot` within 50 px is freed.
4. Colossus: tier 6: for 8 s a `shock` fx every ~0.5 s; weapon `scale.x > 1.2`; at ~14.5 s `flash` r 90 and a dummy at 70 px takes >= 21 and is stunned >= 1.0.
5. Draw smoke; Worldbreaker and Bulwark remain separate (dispatch by `weapon_id`).
