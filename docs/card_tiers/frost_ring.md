# Frost Ring (`frost_ring`, kind `frost_ring`, element ice)

## Today
- Flies out, lands as a pale blue circle of `radius` 55 for `duration` 6 s; every frame each enemy inside gets `apply_slow(slow 0.35, 0.3)`. No damage at all.
- Drawing is the shared one: a pulsing flat disc, a rim arc, and one inner ring per tier.
- Adds already: t2 `wide`, t3 `aftermath` (slow patch left behind), t4 `deep_freeze` (slow gets much stronger), t5 `echo` (wider second ring 0.35 s later), t6 `twin` (a second ring 0.5 s later).

Palette: ice `Color(0.55,0.85,1.0)`, frost white `Color(0.9,0.97,1.0)`, deep `Color(0.25,0.5,0.85)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Flash Freeze | A 6-spoke snowflake lies in the ring (spokes 0.8 r, each with two V branches at 0.45 r and 0.65 r), rotating 0.15 rad/s; 8 small diamond crystals sit on the rim (polygon 4 pts, size 4). | On landing: `ring` radius r, `shards` count 8 radius r colour frost white. `Sfx.play("whoosh")`. | **Flash freeze**: enemies inside when it lands are frozen solid for 0.6 s (`apply_slow(0.0, 0.6)`; bosses are only slowed by their own rule). | wide |
| 3 Frostbite | The rim becomes a crystal fence: 24 triangles (base 5 px, height 6 px) pointing inward along the rim, alternating ice / frost white. 5 frost-crack lines on the floor from 0.25 r to 0.75 r at `jit` angles (alpha 0.35). | Every second a handful of snow: `motes` count 6 radius 0.8 r rise 22 colour white. A damage tick shows a tiny `burst` radius 6 on each hit enemy only if fewer than 6 enemies are in the ring (avoid spam). | **Frostbite**: ice damage over time to everything inside: `BITE[tier]` per second, ticked every 0.5 s with `e.spell_damage(BITE*0.5, "ice", true)`. Table `BITE = [0, 0, 1.5, 2.5, 4.0, 6.0]` (index = tier-1... use `BITE[tier-1]` with t1 = 0). | aftermath |
| 4 Icicle Fall | A blue-white crystal spire (3 prisms: tall polygon height 16, two small ones 10) stands at the centre; floor gets a lighter inner disc (alpha 0.18, radius 0.6 r) like a sheet of ice. 4 hanging icicle silhouettes (triangle, pointing down, length 7) circle slowly around the spire. | Each icicle drop: a `ring` radius 12 telegraph (0.3 s, from `ground_strike`) then `shards` count 5 radius 16 on impact; `Sfx.play("hit")`. | **Icicle fall**: every 1.0 s up to 3 icicles drop on distinct random enemies inside the ring: `WeaponUtil.ground_strike(tree, world, enemy_pos, 12.0, 0.3, BITE*1.5, 40.0, ice, 0.25, [], "ice")`; each hit also stuns 0.25 s. Fewer targets means fewer icicles. | deep_freeze |
| 5 Shatter | An outer halo of 12 diamond crystals orbits at 1.08 r (angular speed 0.5 rad/s, size 5, alpha 0.8) and 16 snow motes drift down inside (`p = fposmod(since*0.25 + jit(i), 1)`; position `jit` x/y, y falls 18 px). The snowflake is twice as detailed (3 branch pairs). | Shatter nova: `ripple` radius 40 rings 2 plus `shards` count 8 radius 36 at the dead enemy's last position; `Sfx.play("big_hit")`. | **Shatter**: when an enemy dies inside the ring it explodes in a frost nova: 3 x `BITE` to every enemy within 36 px of it and a 0.5 s freeze. Needs the death position, see rules. | echo |
| 6 Absolute Zero | A giant faint snowflake (8 spokes, 3 branch pairs, alpha 0.25) fills the ring, aurora arcs: three concentric arcs at 0.55/0.75/0.95 r, 70-degree sweeps, colours cyan / white / violet-blue, rotating in different speeds. During the last 1.0 s of the ring a white circle contracts from r to 0.2 r (a clear warning). | **Finale** at the end of the ring: `flash` radius r colour white-ice, `ripple` radius 1.25 r rings 3, `shards` count 18 radius 1.2 r; `Sfx.play("ultimate")`. | **Absolute zero (FINALE)**: when the ring ends, every enemy inside is frozen 1.5 s (`apply_slow(0,1.5)`), made exposed for 2.5 s (`WeaponUtil.expose`) and takes 4 x `BITE` ice damage. Skipped when `data.copy`. | twin |

## Rules for the implementer
- `SpellTiers.tick_frost_ring(s, tier, delta)`: private vars on the spell (underscore): `_bite_t`, `_ice_t`, `_seen` (Dictionary enemy -> last position), `_finale_done`.
- Frostbite: every 0.5 s, `for e in s._in_radius("enemy")`: `e.spell_damage(BITE[tier-1] * 0.5, "ice", true)`.
- Icicle fall: every 1.0 s pick up to 3 random enemies from `_in_radius`, `WeaponUtil.ground_strike` is `async` (it awaits a timer) — just call it, do not await.
- Shatter: each tick refresh `_seen[e] = e.global_position` for enemies currently inside; any key that is now invalid or has `e.dead`/`health <= 0` was killed: nova at `_seen[e]`, erase the key. Keys that left the ring alive simply stop being refreshed (remove keys that are not in the ring and still valid). Guard: at most 4 novas per second (`_nova_cd`), novas do not trigger further novas (kill by a nova is ignored: set a flag during nova).
- Finale: in `tick_frost_ring`, `if tier >= 6 and !_finale_done and !data.get("copy", false) and (age - flight) >= effect_time - 0.05` do the finale once. Draw the contracting warning in `SpellArt.draw_frost_ring` for `since >= effect_time - 1.0`.
- Flash freeze goes in `land_frost_ring`.
- Constants in `SpellTiers`: `FROST_BITE := [0.0, 0.0, 1.5, 2.5, 4.0, 6.0]` (per second, index tier-1).
- Draw in `SpellArt.draw_frost_ring(s, since, col)`; the shot (`flight_frost_ring`) gets a snow-crystal head at t3+ (small 6-spoke flake, 5 px) with a frost-dust trail of 6 pale dots.
- The echo/twin copies (t5/t6) are rings without the copy's finale; they still get Frostbite/Icicles so a tier-6 cast is a double ring of ice: acceptable.
- Multiplayer: nothing special (host ticks; art derives from `since`, `tier`).

## How to test (`tools/tests/tier_frost_ring.gd`)
1. Flash freeze: at tier 2 a dummy inside has `slow_mult == 0.0` right after landing and `slow_time > 0.4`; at tier 1 `slow_mult` is 0.35.
2. Frostbite: a dummy inside takes 0 damage at tier 2, about `BITE*1` per second at tier 3 (measure over 2 s, +/- 30%), more at 4 and 6.
3. Icicle fall: at tier 4 with 5 dummies at spread positions the fx scan shows `ring` fx of `life` 0.3 and total damage per dummy over 3 s is larger than at tier 3; at tier 3 there are none.
4. Shatter: dummy A health 2 and dummy B (huge health) 20 px away at tier 5: A dies from Frostbite; B is frozen (`slow_mult == 0`) and took the nova; same setup at tier 4 leaves B unfrozen by the death.
5. Finale: with `duration` shortened to 1.5 s in the test dict, tier 6 spawns `flash` near the end and a dummy ends exposed (`WeaponUtil.is_exposed(e)`); with `copy = true` it does not.
6. Draw smoke for all six tiers during the last second.
