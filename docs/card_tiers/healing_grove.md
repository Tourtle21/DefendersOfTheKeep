# Healing Grove (`healing_grove`, kind `build`/`mender`, no element)

## Today
- A wide, strong healer: `radius` 60, `heal_per_sec` 14, `duration` 60 (a healing budget of 840 hp; it expires when all is healed). Heals hurt players in range each frame. Generic mender totem look in green.
- Adds already (`BUILD_TWISTS.mender`): t2 `wide_field`, t3 `swift_heal`, t4 `potent`, t5 `regrow`, t6 `tough`.
- Flavour: Healing Grove = living nature: lingering regrowth, fruit, grasping roots, blossom pulses, a world tree that calls back the fallen.

Palette: grove `Color(0.4,1.0,0.6)` (card colour), bark `Color(0.45,0.3,0.18)`, leaf `Color(0.3,0.75,0.35)`, blossom `Color(1.0,0.75,0.85)`, fruit `Color(1.0,0.55,0.2)`, gold `Color(1.0,0.9,0.5)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Glade | The pole becomes a small tree (trunk 3x10, crown of 3 circles r 5/4/4), flowers on the ground (6 small coloured dots with petals) scattered in the field, leaf motes drift up. | Regrowth: a faint green `motes` count 3 rise 10 trail on a player leaving the field. | **Regrowth**: a player healed by the grove keeps healing for 3 s after stepping out: `0.4 * heal_per_sec` per second (`_hot` player -> time left; not counted against the budget). | wide_field |
| 3 Orchard | The crown is fuller (5 circles) with red-orange fruit dots hanging in it; a ripe fruit visibly falls and rests on the ground (circle r 3 fruit colour with a leaf), up to 2 at a time at fixed spots (positions from `jit(index, spawn_count)`). | Eating: `star` radius 12 count 5 fruit colour, `motes` count 6 rise 18, `Sfx.play("coin")`. | **Fruit**: every 10 s a fruit ripens somewhere in the field (max 2 lie around); the first player to touch one (within 12 px) eats it and heals 15% of their health at once (hurt players only). | swift_heal |
| 4 Grasping Roots | Gnarled roots break the ground (6 dark root lines fanning from the trunk to 0.85 radius, thicker near the trunk, 4 small bumps), the trunk has a face-like knot and glowing green eyes while enemies are inside. | Roots grab: `burst` radius 10 leaf at an enemy first entering; throttled. | **Grasping roots**: enemies in the field are slowed to 65% (`apply_slow(0.65, 0.3)` each frame) so the grove becomes a safe place to stand. | potent |
| 5 Blossom Pulse | The tree blooms: crown covered in pink blossoms (12 dots), falling petals (10 deterministic particles), a soft pink-green aura disc, a ring of 8 small flowers on the field edge opening at each pulse (`since` modulo). | Pulse: `ripple` radius = field radius rings 2 pink-green, `motes` count 14 rise 30 blossom; `Sfx.play("unlock")`. | **Blossom pulse**: every 8.0 s a wave sweeps the field: heals every player and guard in it by `heal_per_sec * 1.5` at once, cleanses confusion (`p.confused_time = 0`). Not counted against the budget. | regrow |
| 6 World Tree | A giant ancient tree: trunk 8x24 with two big roots, a crown of 9 overlapping circles in 3 greens (r 8..12), golden glowing leaves (6 gold dots), light shafts (3 translucent triangles from the crown to the ground), a ring of spirit lights (6 small orbs rising), a gold aura. | **Seed of life**: a gold `pillar` height 80 width 30 at the tree; `star` radius 30 count 8; `Sfx.play("ultimate")`. | **Seed of life**: while any player is downed the tree calls them back: every 40 s it shortens a downed player's wait to 3 s (`p.respawn_left = minf(p.respawn_left, 3.0)`), once per 40 s in total. Also the field's healing counts only half against the budget (the tree is generous). | tough |

## Rules for the implementer
- `structure.gd` mender branch computes budget use inside the existing loop; for tier 6 multiply the amount counted into `_healed` by 0.5 (`StructureTiers.budget_mult(st)` returns 0.5 for `healing_grove` tier >= 6, else 1.0).
- `tick_healing_grove(st, delta)`: `_hot` bookkeeping (mark players healed this frame; players that left the field heal at `0.4*hps` until time out); fruit `pace "fruit" 10.0` -> pick a spot `Vector2.from_angle(jit(n,1)*TAU) * radius*0.6 * jit(n,2)` stored in PUBLIC `fruit_pos: Array` (max 2); eating checks `players within 12 px && needs_health()`; roots; blossom `pace "bloom" 8.0`; seed of life `pace "seed" 40.0` only when a player has `downed == true` (keep timer paused until one is).
- Fruit heals `p.heal(0.15 * 228.0 * Game.hp_scale())`.
- Constants: `GROVE_HOT := 0.4`, `GROVE_HOT_T := 3.0`, `GROVE_FRUIT_T := 10.0`, `GROVE_FRUIT := 0.15`, `GROVE_ROOT := 0.65`, `GROVE_BLOOM_T := 8.0`, `GROVE_BLOOM := 1.5`, `GROVE_SEED_T := 40.0`.
- Draw: `StructureArt.draw_healing_grove(st, col)` (separate from the Mender totem drawing).
- Multiplayer: `fruit_pos` public; players' heals are host-side.

## How to test (`tools/tests/tier_healing_grove.gd`)
1. Regrowth: tier 2 player healed in the field then moved out: Health keeps rising for ~3 s; tier 1 stops at once.
2. Fruit: tier 3: after 10.2 s `fruit_pos.size() == 1`; hurt player moved onto it gains ~15% and the entry is removed.
3. Roots: tier 4 dummy inside `slow_mult <= 0.66`.
4. Pulse: tier 5 within 8.2 s a hurt player gets a sudden jump >= 1.5 x hps and a `ripple` fx is seen; `confused_time` cleared.
5. Seed: tier 6 with a downed player (`fall()`): its `respawn_left <= 3.0` once 40 s have passed; a second downed within the next 40 s is not shortened.
6. Budget: the grove still expires after healing its budget.
