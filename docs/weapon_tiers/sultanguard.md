# Sultan's Guard (`sultanguard`, Epic, earth, fusion tier 2 of Scimitar + Shield, H = 2.88, inherits `t1x/scimitar.gd`)

## Today
- Attack: the Scimitar's alternating slash (`arc` r 30, +-70 degrees, 1.0 H, knock 60, 3 bleed ticks of 0.7; cd 0.3). Riposte Wave (tier 2+, cd 7): `parry_time` 0.4 s; if hit in the window: shake 2.5, 0.5 s `shield_time`, four crescents (`WeaponProjectile` speed 260, 3.0, pierce 3, life 0.5, 4 bleed ticks of 1.0) fan out in the four directions (rotated by the aim), cd back to 1.5 s.
- Mirage Guard (dash, cd 4): the Scimitar's 50 px dash (bleeds what it passes) plus 0.7 s of `shield_time`. Sand Cyclone (tier 3+): 5 pulses r 52 every 0.3 s, 2.0 each, pulling enemies in.
- Looks: sand-gold arcs and rings.

Palette: brass `Color(0.95,0.80,0.45)`, shield blue `Color(0.50,0.65,0.95)`, sand `Color(0.92,0.75,0.40)`, ruby `Color(0.80,0.20,0.20)`. Names: 2 Mirrored Wave, 3 Desert Shield, 4 Oasis Mirage, 5 Sandwall, 6 Sultan's Judgment.

## Tier table (fusion tier 2: rows 2 to 6; must beat Scimitar and Shield at the same tier)

| Tier | ART | ATTACK | ABILITY (Riposte Wave) | DASH (Mirage Guard) | ULTIMATE (Sand Cyclone) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Mirrored Wave | A small round shield is fused to the scimitar's guard; aura twinkle; during the parry window the shield glows (aura `state`). | Bleeding enemies show sand `motes` (as Scimitar tier 2) | **Mirrored Wave**: 6 crescents instead of 4 (60-degree steps), style `crescent` size 1.2, and the reflection of enemy shots (shots within 70 px are reversed). | - | locked | lifesteal |
| 3 Desert Shield | Tip glow; sand trail. | **Desert Shield**: every 3rd slash is a double swing (as Scimitar Dune Dance) and also a shield bash on the opposite arc (0.6 H, knock 240, stun 0.4). | The window is 0.55 s (`parry_time`); a whiffed parry now raises a brief sand veil: `shield_time` 0.4 s and `motes` count 6. | = | unlocked; `sigil` r 52 (sand) 0.25 s. | thunder |
| 4 Oasis Mirage | 2 orbit sand motes, gem pixel. | = | **Oasis**: after a successful parry a mirage of you (an `orbit` fx shape `blade` count 1) stays for 3 s at the spot: every 0.5 s it cuts all within 30 px (0.4 H = 1.2, bleeds). | **Oasis Mirage**: the guard dash is a `streak` (width 7, sand) and leaves a mirage (2.5 s) that stands where you were: it cuts everything within 26 px every 0.4 s for 0.4 H (1.2, quiet) and slows it to 0.6 (no aggro tricks). | = | bleed |
| 5 Sandwall | 4 motes, ghost trail. | = | = | = | **Stage 2 Sandwall**: during the cyclone you are surrounded by a wall of sand: the pulses are `vortex` rings (r 52 -> 70), the wall absorbs projectiles (frees `enemy_shot` within 50 px), and after the last pulse a 4-second `slow` patch r 70 (factor 0.5) with a dust devil that deals 0.3 H (0.9) per second (quiet). | bleed |
| 6 Sultan's Judgment | Halo ring (gold ring with ruby gems), 6 motes, tip star. | **Finisher** every 6th slash: a free Riposte Wave (2 crescents forward, 1.0 H). | = | = | **FINALE Sultan's Judgment**: the cyclone explodes: `pillar` height 120 width 30 (sand), `flash` r 70, `shock` r 80, and 8 great scimitars fly out (`WeaponProjectile` style `crescent` size 1.6, 1.0 H = 2.9, pierce 3, speed 240, life 0.5, 3 bleed ticks): the ring of blades spirals once (`spin`). Shake 6, `Sfx big_hit` + `ultimate`. | chain |

Caps (H = 2.88): attack avg +0.3 H; ability +2 crescents (3.0 each; one pair hits a target: +0.6 of its ability); dash mirage 4 x 0.4 H = +1.6 H over 2.5 s (accept for Epic); ultimate dust devil 4 x 0.3 H + finale 8 blades (2 per target) 2.9 x 2 = 5.8 vs today 5 x 2.0 = 10 H: +100%.

## What makes this feel like Epic
It is a counter weapon with a sand theme: each tier gives a mirage, a wall or a bigger counter. Compared with Scimitar (Uncommon), which only slashes and bleeds, the Guard answers hits and leaves clones; compared with Shield (Rare) its parry has radial payoffs and a lasting echo of itself.

## Rules for the implementer
- `items/weapons/tiers/sultanguard.gd` (may `preload("scimitar.gd")`; dispatch is by `weapon_id`, so the Scimitar's module does NOT run for the Guard unless called). `sultanguard.gd` edits: `ability()` window, `_on_parry` (crescent count by tier, shot reflection, mirage), `dash_attack()` (super, then mirage), the double swing and bash via the module.
- Constants: `SG_CRESCENTS := 6`, `SG_REFLECT_R := 70.0`, `SG_WINDOW := 0.55`, `SG_MIRAGE_SECS := 3.0`, `SG_MIRAGE_TICK := 0.5`, `SG_MIRAGE_MULT := 0.4`, `SG_DEVIL_SECS := 4.0`, `SG_DEVIL_MULT := 0.3`, `SG_BLADES := 8`, `SG_FINISHER_EVERY := 6`.
- Mirage is a host timer in `_st` and a repeating `orbit` fx; it hits with `quiet = true`.
- Multiplayer: nothing new; state bit for the parry glow in the aura.
- Performance: finale ~20 fx and 8 projectiles.

## How to test (section `sultanguard`)
1. Mirrored Wave: tier 2 parry: 6 projectiles spawn (tier 1: 4); an `enemy_shot` within 70 px flips direction.
2. Desert Shield: tier 3, 3 slashes: the third shows two arcs and stuns a dummy at 20 px; window = 0.55.
3. Oasis: tier 4 parry: a dummy next to the parry spot loses health every 0.5 s for 3 s; the dash leaves a mirage cutting a dummy at 20 px.
4. Sandwall: tier 5 ultimate: an `enemy_shot` within 50 px is freed; a `slow` hazard r 70 exists at 2 s; tier 4 neither.
5. Sultan's Judgment: tier 6: 8 projectiles of style `crescent` spawn, `pillar` seen; a dummy at 100 px takes >= 2.9; tier 5 not.
6. Draw smoke; Scimitar unchanged.
