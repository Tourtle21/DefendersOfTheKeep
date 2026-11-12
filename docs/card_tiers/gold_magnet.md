# Gold Magnet (`gold_magnet`, kind `magnet`, no element)

## Today
- Lands on the target and on landing calls `collect_to_pool()` on every gold coin (`gold` group) within `radius` 60: it goes straight into the keep's pool. `duration` 0.5 s, so the node vanishes almost at once. Flat gold disc.
- Adds already (default pool): t2 `wide`, t3 `lingers`, t4 `twin`, t5 `echo`, t6 `refund`.

Palette: gold `Color(1.0,0.85,0.25)`, bright `Color(1.0,0.95,0.6)`, magnet red `Color(0.85,0.2,0.2)`, steel `Color(0.8,0.85,0.95)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Long Reach | A horseshoe magnet at the centre (thick arc 200 degrees radius 8 width 4, red body, steel tips) spinning once a second. 6 field lines: arcs from the rim curving toward the centre, dashes sliding inward (`phase = fposmod(since*1.5, 1)`). | For every coin taken a `line` (gold, length 30 toward the keep, width 2, life 0.25). `Sfx.play("coin")` once (not per coin). | **Long reach**: coins within 1.6 r are collected (the drawn disc stays r; a faint outer dotted ring at 1.6 r shows the real reach). | wide |
| 3 Haul | Two magnets (opposed) rotate around each other; coin glints: 4 gold sparkles on the rim twinkling (`jit`). | Resource pickups collected show `motes` count 4 rise 16 in their own colour (use gold if unknown). | **Haul**: loose resource pickups in the area (group `pickup` whose `item_info.items[item_type]["type"] == "resource"`: sticks, stone, ores...) fly into the pool as well: `Game.add_resource(item_type, 1)` then `queue_free()`. Weapons are never taken. | lingers |
| 4 Fortune | 3 coins orbit the horseshoe at 0.35 r (circles r 3, gold with highlight dot, angular speed 2.4 rad/s), a golden ring pulse breathes. | A lucky coin makes `star` radius 10 count 4 gold at the coin. | **Fortune**: each coin collected has a 25% chance to count double (`Game.add_resource("gold", 1)` extra). Rolled once per coin, never for `copy` casts (twin/echo) so twins do not stack luck. | twin |
| 5 Coin Storm | A golden whirlpool: 3 spiral arms (8-point polylines from 0.1 r to 0.9 r, turning with `since*2.2`, gold alpha 0.5, width 2) and coin sparks flying along them. Horseshoes glow white at the tips. | Each coin collected is fired: a gold `WeaponProjectile` with gold colour, plus a `burst` radius 8 where it lands. `Sfx.play("whoosh")`. | **Coin storm**: every coin collected is hurled at the nearest enemy within 160 px (projectile damage `COIN_DMG[tier]`, speed 220, pierce 0, element ""). The spell now stays for 2.5 s (`effect_time`), and any coin that drops inside the disc during that time (an enemy dies there) is collected and hurled the same way. | echo |
| 6 Treasure Surge | A solar coin: a big gold disc with an engraved ring (two arcs, one dotted), 12 rotating rays, 8 mini coins in the corona; the horseshoe is white-gold. A light pillar of gold motes rises. | **Finale** at the end of the 2.5 s: `flash` radius 1.4 r gold, `ripple` radius 2.2 r rings 3, `motes` count 16 radius r rise 40. `Sfx.play("ultimate")`. | **Treasure surge (FINALE)**: at the end it sweeps everything within 2.2 r (all coins + resource pickups) and pays a tribute of 1 gold for every 5 coins taken during the whole cast (maximum 4). Skipped when `data.copy`. | refund |

`COIN_DMG := [0, 0, 0, 0, 2.5, 4.0]` (index = tier-1; 0 means no projectile).

## Rules for the implementer
- `SpellTiers.land_gold_magnet(s, tier)`: the existing `elif data.kind == "magnet"` loop in `spell.gd` (`for g in _in_radius("gold"): g.collect_to_pool()`) must call `SpellTiers.magnet_sweep(s, tier, reach)` instead: reach = `radius * (1.6 if tier >= 2 else 1.0)`; it gathers `gold` nodes within reach via `get_nodes_in_group("gold")`, then pickups for tier >= 3, applies Fortune (tier >= 4 and not `copy`), spawns coin projectiles (tier >= 5), counts `_coins` (private) for the tribute and spawns the line fx. Capture the coin position before `collect_to_pool()`.
- `SpellTiers.effect_time(s)`: magnet returns `2.5` for tier >= 5 else the old value. `tick_gold_magnet` for tier >= 5 repeats `magnet_sweep` every 0.2 s with reach r (enemies' coins that land inside).
- Projectile target: nearest enemy in `get_nodes_in_group("enemy")` within 160 px of the coin; if none, no projectile (the coin is still taken).
- Finale at `since >= effect_time - 0.05`: sweep with 2.2 r and pay `mini(4, _coins / 5)` through `Game.add_resource("gold", n)`. Announce nothing.
- Economy note: Fortune is +25% on a few coins of one cast, tribute max +4 per cast, both fine against 15 mana.
- Constants: `MAGNET_REACH := 1.6`, `MAGNET_LUCK := 0.25`, `MAGNET_TRIBUTE_PER := 5`, `MAGNET_TRIBUTE_MAX := 4`, `MAGNET_STORM_TIME := 2.5`, `COIN_DMG`.
- Draw: `SpellArt.draw_gold_magnet`. At tier 1 the disc exists only 0.5 s; at tier 5+ it lives 2.5 s so draw fade from `effect_time`.
- Multiplayer: pool changes via `Game.add_resource` are host-side; coins are nodes already replicated; the whirlpool uses `since`.

## How to test (`tools/tests/tier_gold_magnet.gd`)
1. Reach: spawn coins (`GoldCoin.spawn(world, pos, 1)` via `load("res://collectables/gold/gold_coin.gd")`) at 0.9 r and 1.4 r; tier 1 collects only the first, tier 2 both (check `game.resources.gold` delta).
2. Haul: a resource pickup (instance `res://collectables/` scene with `item_type = "stone"`; or a stub node in group `pickup` with `item_type`/`item_info`) is taken at tier 3 (stone count rises), not at tier 2.
3. Fortune: 200 coins at tier 4: gold gained between 225 and 275 (25% luck); tier 3: exactly 200; `copy = true` casts: exactly 200.
4. Coin storm: tier 5 spawns `projectile.gd` nodes when enemies are within 160 px; none at tier 4; the node is alive at 2.0 s at tier 5 and gone at 0.8 s at tier 4.
5. Finale: tier 6 spawns `flash` + `ripple` fx and the pool gets `min(4, coins/5)` extra gold.
6. Draw smoke at six tiers.
