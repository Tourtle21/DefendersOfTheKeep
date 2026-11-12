# Stormcaller Bow (`stormbow`, Ancient, no element, fusion tier 3 of Tempest Lash + Warp Bow, H = 3.60, inherits `t2/warpbow.gd`)

## Today
- Attack (from the Bow): hold to draw (0.8 s to full), release; damage `H x (0.33 + 0.67 x ratio)`, speed 200 to 360, full draw pierces 1, perfect window x1.6. Storm Warp (tier 2+, cd 5): the Warp Bow's anchor arrow and second click teleport (`blink`, `ground_strike` r 26 3.0 stun 0.5); ARRIVING also calls lightning: six `ground_strike`s (r 22, 3.5, stun 0.5, delays 0.2 to 0.7) in a ring of 40 px round the arrival.
- Phase Step (dash, cd 3): blink 40 px with 0.3 s shield. Thunder Volley (tier 3+): the Warp Bow's nine piercing arrows (3.0, pierce 3), then a `rain` of 18 strikes over 2.6 s around the cursor (range 130) r 110 (4.2 each, r 24, stun 0.5), and 1.6 s later one huge bolt (r 56, 10.0, stun 1.0).
- Looks: pale blue rings and arrows.

Palette: storm blue `Color(0.70,0.85,1.0)`, bolt white `Color(1.0,1.0,1.0)`, thunderhead `Color(0.35,0.35,0.60)`, rift violet `Color(0.65,0.50,1.0)`. Names: 3 Charged Gates, 4 Storm Gate, 5 Thunderhead, 6 Tempest Archer.

THE ANCIENT SYSTEM: **Charged Gates** (Warp Bow's Rift Gates fused with the Tempest's charge). Arrows that hit leave CHARGES (`wt` charge meta, as in `tempest.md`, max 5; star motes over heads). Gates (from `warpbow.md`, placed by Storm Warp, up to 3) are live: an arrow through a gate is echoed AND gains a `bolt` that arcs to the nearest enemy (0.5 H). **Arrival Thunderclap**: warping to a gate detonates every charge within 100 px of the destination (1.0 H per charge, `bolt` fx), on top of the ring of strikes.

## Tier table (fusion tier 3: rows 3 to 6; the entry carries Warp Bow tiers 2 and 3 rows: Rift Gate and Echo Arrow with Stormbow colours, and Tempest Static)

| Tier | ART | ATTACK | ABILITY (Storm Warp) | DASH (Phase Step) | ULTIMATE (Thunder Volley) | Twist (est.) |
|---|---|---|---|---|---|---|
| 3 Charged Gates (entry) | A bow of storm-grey wood with a gem of crackling blue; arrows are style `bolt`-tipped arrows (style `arrow` + `glow 0.4`, `trail 5`, 1 lightning spark); gates drawn with crackling edges (aura `kind "gates"` with `bolt` arcs between neighbour points); aura twinkle + glow. | **Charged Arrows**: every arrow that hits adds a charge; a full draw hit also adds 1 `bolt` jump (0.5 H) to the nearest enemy within 55 px. | **Storm Warp + Arrival Thunderclap**: the six-strike ring becomes strikes drawn with `fall` bolts (`bolt` fx from above, length 70) and the arrival detonates charges within 100 px (1.0 H each). Gates (Rift Gate: 6 s; Echo Arrow). | **Static Step**: the dash leaves a charge-spark at the start (a 1.5 s `Hazard`-free `orbit` mark): enemies within 30 px of it at 1.0 s are charged and take 0.5 H; `streak` (width 5). | unlocked; `sigil` r 40 (storm blue) at the bow 0.3 s; Thunder Volley arrows add charges. | chain |
| 4 Storm Gate | 3 orbit sparks, gem pixel (white). | = | **Storm Gate**: when you have two gates a lightning line joins them (`bolt` fx every 0.4 s) and enemies crossing it take 0.4 H per 0.5 s (quiet) and gain a charge; with three gates the triangle is live; warping through the line also shocks things on it. | **Phase Gate**: the dash leaves a gate (as Warp Bow tier 4) with storm arcs. | = | thunder |
| 5 Thunderhead | 5 sparks, trail. | = | = | = | **Stage 2 Thunderhead**: after the giant bolt a thundercloud hangs over the area for 6 s: `sigil` r 120 (thunderhead) respawned each 0.8 s + rain `motes`; every 0.5 s a `bolt` strikes a random charged enemy in 120 px (1.0 H = 3.6, adds a charge, `ground_strike` r 14); gates in the area fire a piercing arrow each (0.8 H) at the nearest charged enemy every 1.5 s. | lifesteal |
| 6 Tempest Archer | Halo ring (a ring of storm clouds), 12 sparks, tip star; a faint lightning crown above your head (aura). | **Finisher** every 5th shot: a lightning arrow: a `bolt` forks from the hit to 5 targets within 90 px (0.6 H, +2 charges each) and a `flash` r 20. | = | = | **FINALE + TRANSFORMATION Tempest Archer (12 s)**: the sky answers you: for 12 s (a) every arrow is lightning (it `chain 3` at 55 px, 60% damage, adds charges), (b) 6 gates (Rift Storm ring of 6 at r 90 from the Warp Bow tier 6, with storm arcs) copy your shots at 40%, (c) a `bolt` strikes every 0.5 s (random enemy within 140 px, 0.8 H = 2.9), (d) Thunderclap's arrival effect fires each time a gate copy lands. At the end the Judgement: `sigil` r 90 (0.5 s) at the cursor, then a colossal `bolt` (width 14, length 160) + `flash` r 90 + `pillar` height 170 + `ripple` r 140 rings 4; everything within 90 px takes 2.5 H (9.0), stun 1.2; every charged enemy within 160 px detonates (1.0 H x charges). Shake 8, `Sfx ultimate` + `big_hit`. | thunder |

Caps (H = 3.60): attack +0.3 H avg (jump 0.5 H on full draws only); ability arrival detonation up to 5 x 1.0 H on a charged target = 5 H; gate line 0.4 H x ticks (cap 6); dash 0.5 H; ultimate: thunderhead 12 strikes x 3.6 spread (a target gets 3) + transformation bolts 24 x 2.9 spread (4 on a target) + gate shots + Judgement 9.0 + charges 5 H: about 45 H on a central target vs today 9 x 3.0 + 18 x 4.2 + 10 = ~110 H of spread damage (per target ~27): +60%: inside Ancient k = 52 H.

## What makes this feel like Ancient
Two systems braided: gates for geometry (Warp Bow) and charges for payoff (Tempest), so every arrow is a small storm and every warp an explosion. The ultimate is a four-stage thunderstorm (volley, rain, cloud, judgement) plus a 12-second transformation. Compared with Mythic Warp Bow (gates and copies) the Stormbow's gates DEAL damage themselves.

## Rules for the implementer
- `items/weapons/tiers/stormbow.gd` (`preload("warpbow.gd")` for gate placement, crossing, Rift Storm ring; `preload("tempest.gd")` for charge helpers: the `charge` meta is shared; overload is NOT inherited).
- `stormbow.gd` edits: `_on_warped(dest)` (arrival detonation: the existing strike ring stays, replace the plain ring by `bolt` falls; detonate charges within 100 px), `ultimate()` inherited then `super()`: stage 2 at press + 9 arrows (instant) + 2.6 s rain + 1.6 s bolt = ~4.4 s; transformation at 5.0 s, judgement at 17.0 s.
- Constants: `SB2_JUMP_MULT := 0.5`, `SB2_DETONATE_R := 100.0`, `SB2_DETONATE_MULT := 1.0`, `SB2_STATIC_T := 1.0`, `SB2_LINE_MULT := 0.4`, `SB2_LINE_TICK := 0.5`, `SB2_CLOUD_SECS := 6.0`, `SB2_CLOUD_EVERY := 0.5`, `SB2_CLOUD_MULT := 1.0`, `SB2_FINISHER_EVERY := 5`, `SB2_ARCHER_SECS := 12.0`, `SB2_BOLT_EVERY := 0.5`, `SB2_BOLT_MULT := 0.8`, `SB2_JUDGE_MULT := 2.5`.
- Gate-line damage needs a point-to-segment test (shared with `starfall.md`: `WeaponTiers.seg_dist(p, a, b)` helper written once in `weapon_tiers.gd`).
- Multiplayer: gates/arcs via aura; charges as `WeaponFx` marks; projectile cap 40. Performance: the 12 s transformation ~30 fx/s, <= 30 projectiles.

## How to test (section `stormbow`)
1. Entry: tier 3 full-draw hit: a charge on the dummy and a bolt jump to a neighbour at 50 px; the warp ring uses `bolt` kinds.
2. Arrival Thunderclap: a dummy with 3 charges near the destination loses >= 3.0 on warping; at tier 3 too (entry).
3. Storm Gate: tier 4 with two gates: a dummy standing on the segment loses ~0.4 H each 0.5 s and gains a charge; tier 3 none.
4. Thunderhead: tier 5 ultimate: >= 6 bolt strikes in a 6 s window starting at ~4.4 s; tier 4 none.
5. Tempest Archer: tier 6: arrows `chain` (a second dummy 40 px from the first is hit); `bolt` fx every ~0.5 s for 12 s; at ~17 s kind `flash` r 90 and the cursor dummy takes >= 9.
6. Draw smoke; Warp Bow unaffected (its own module).
