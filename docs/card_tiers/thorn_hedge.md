# Thorn Hedge (`thorn_hedge`, kind `build`/`barricade`, no element)

## Today
- A tough living wall: `radius` 18, `hp` 95, `thorns` 3 (every 0.5 s each chewing enemy takes 3 and costs 1 hp). Green rect with plank lines and five light-green spikes along the top.
- Adds already (`BUILD_TWISTS.barricade`): t2 `thorned` (thorns at least 2 x 1.5^(tier-1), the card already has 3 so it stays 3 until barbed), t3 `regrow`, t4 `tough`, t5 `thorns_plus` (x2), t6 `last_stand`.
- Flavour: Thorn Hedge = living nature: vines, brambles, healing sap, rebirth.

Palette: leaf `Color(0.4,0.75,0.3)` (card colour), dark leaf `Color(0.2,0.45,0.18)`, thorn `Color(0.85,0.95,0.5)`, berry `Color(0.85,0.2,0.3)`, flower `Color(1.0,0.75,0.85)`, sap `Color(1.0,0.9,0.5)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Creeping Vines | Vines wrap the hedge: two sine-curve polylines (leaf green, width 2) winding along its length with 6 small leaves (ellipse polygons) and a few vine tendrils whipping out when enemies chew (a short curved line toward the gnawer). | Entangle: `burst` radius 8 leaf at the gnawer; the tendril lines. | **Entangle**: every gnawing enemy is held by the vines: `apply_slow(0.3, 0.8)` on each gnaw tick (so a pack gets stuck and keeps taking thorns). | thorned |
| 3 Thorn Volley | Thorns are bigger (spikes 8 px, red-tipped, 7 of them) with 3 red berries between them; a ring of 4 seed pods bulges at the sides (small circles r 3). | Volley: 3 thorn `WeaponProjectile`s (thorn colour, speed 260) in a small fan; `Sfx.play("whoosh")`. | **Thorn volley**: every 2.5 s it shoots 3 thorns (fan +-0.15 rad) at the nearest enemy within 90 px: `thorns * 0.8` each, pierce 0. Honours `defence_sees`. | regrow |
| 4 Bramble Field | Low brambles curl on the ground around the hedge: two mounded bushes (arc polygons dark leaf) at both ends and a ring of 10 small thorn arcs on the ground at 1.7 x radius (alpha 0.35), the hedge itself taller by 3 px. | Patch refresh: `motes` count 3 rise 6 leaf (subtle) every 5 s. | **Bramble field**: the ground round the hedge is overgrown: a slow patch of radius `radius * 2.2` is kept under it (`slow_patch(st, radius*2.2, 6.0, 0.6)` renewed every 5 s). Everything crossing it is slowed to 60%. | tough |
| 5 Heart Sap | Pink five-petal flowers bloom on the hedge (5 flowers, circles r 2.5 around a yellow centre), amber sap drops (small teardrops) slide down the hedge and glow; a faint green healing disc (radius 50, alpha 0.07) at the base. | Heal: `motes` count 4 rise 16 sap/yellow above each healed player (throttled to 1 per player per 1.5 s). | **Heart sap**: the hedge heals players within 50 px for 1.5 hp/s (hurt players only) and guards for 1.5 hp/s (`StructureTiers.mend`). | thorns_plus |
| 6 Ancient Hedge | An ancient twisted hedge: taller (+6 px), a twisted arch of branches across the top (two curved polylines forming an arch with leaves), a glowing golden-green aura (disc alpha 0.1 r 1.5 x radius), a big white-gold bloom in the middle (8 petals), spores (6 gold dots) rising. | **Thorn storm** every 8 s: `ripple` radius 50 rings 2 leaf, `shards` count 12 radius 50 thorn; `Sfx.play("big_hit")`. **Rebirth**: `star` radius 22 count 6 gold + `motes` count 12 at the seedling. | **Thorn storm**: every 8.0 s it fires 12 thorns in a ring (`radial(st, 12, thorns * 1.0, thorn)`); **Rebirth**: when enemies destroy it (after the `last_stand` burst) a seedling hedge (a fresh tier-1 `thorn_hedge`, full hp, flagged `seedling` so it cannot be reborn) grows in its place. | last_stand |

## Rules for the implementer
- `StructureTiers.on_gnaw_thorn_hedge(st, e)` (called per gnaw): `e.apply_slow(0.3, 0.8)` for tier >= 2.
- `tick_thorn_hedge(st, delta)`: `pace` `"volley" 2.5` (tier >= 3, nearest visible enemy within 90 via `StructureTiers.nearest(st, 90.0)`), `"bramble" 5.0` (tier >= 4), `"storm" 8.0` (tier >= 6, needs an enemy within 60 px or at least one in sight: `nearest(st, 80.0) != null`), sap each frame: `mend(st, 50.0, 1.5, delta)` plus players in 50 px with `needs_health()` (tier >= 5).
- Rebirth: `on_expire_thorn_hedge(st)` (called in `_expire` AFTER `last_stand`): only when `st.hp <= 0.0` (destroyed, not removed by the structure cap) and `tier >= 6` and not `data.get("seedling", false)`: build `d = Game.stats_of(Game.make_entry("thorn_hedge", 1, ""))`, `d.seedling = true`, `s = Structure.new(); s.setup(d, st.position); world.add_child(s)` (do not call `settle`, so it will not merge).
- Constants: `HEDGE_ENTANGLE := 0.3`, `HEDGE_VOLLEY_T := 2.5`, `HEDGE_BRAMBLE_R := 2.2`, `HEDGE_SAP := 1.5`, `HEDGE_STORM_T := 8.0`.
- Draw: `StructureArt.draw_thorn_hedge(st, col)`; keep the hp bar. Sine vines use `_age`.
- Multiplayer: seedling is a normal structure (net group); `seedling` is a public data key.

## How to test (`tools/tests/tier_thorn_hedge.gd`)
1. Entangle: tier 2 chewing dummy has `slow_mult <= 0.31` during chewing; tier 1 not.
2. Volley: tier 3 dummy at 70 px (not chewing): 3 `projectile.gd` nodes appear within 2.6 s; tier 2 none.
3. Brambles: tier 4: a `slow` hazard of radius ~`radius*2.2` exists; a dummy at 2 x radius has `slow_mult <= 0.61`.
4. Sap: tier 5 hurt player at 40 px heals; a hurt guard at 5 hp gains hp; tier 4 not.
5. Storm + rebirth: tier 6: 12 projectiles within 8.2 s with an enemy near; set `hp = 0` and wait: a new structure with `data.seedling == true` and `tier == 1` exists at the same position; the seedling destroyed leaves nothing.
6. Cumulative: tier 6 has entangle/volley/brambles/sap.
