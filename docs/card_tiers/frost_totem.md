# Frost Totem (`frost_totem`, kind `build`/`totem`, element ice)

## Today
- A totem (`radius` 55 aura, `slow` 0.4, no damage) that slows every enemy within `radius` each frame (`apply_slow(slow, 0.3)`). Permanent. Drawn as a dark pole with a pale-blue round head inside a faint pulsing blue field circle.
- Adds already (`BUILD_TWISTS.totem`): t2 `deep_freeze` (slow much stronger), t3 `wide_field` (+40% radius), t4 `potent` (no effect: no damage keys, so tier-4 below does its own thing), t5 `regrow`, t6 `tough`.
- NOTE: the kind `totem` is used only by this card (there is no separate `totem` card id).

Palette: ice `Color(0.6,0.85,1.0)` (card colour), snow `Color(0.95,0.98,1.0)`, deep `Color(0.25,0.45,0.8)`, aurora `Color(0.5,1.0,0.8)`, violet `Color(0.6,0.5,1.0)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Rime Aura | A snowcap on the head (white arc), 6 ice crystals around the base (hex prisms height 6..9, `jit` angles, pale blue with a white highlight), the head becomes a faceted gem; rime lines (4 short strokes) on the pole. Slowly falling snow dots (8) inside the field. | Each frost tick: tiny white `burst` radius 5 on up to 3 chilled enemies per second (throttled). | **Rime aura**: the cold bites: every 0.5 s each enemy in the aura takes `FT_DPS[tier-1] * 0.5` ice damage (`FT_DPS = [0, 1.0, 1.8, 3.0, 5.0, 8.0]`). | deep_freeze |
| 3 Ice Spears | Three ice spears (long thin diamonds, length 16) stand up behind the head in a fan; they dip and one flies when it fires and re-grows 1 s later. | A spear: `WeaponProjectile.shoot(..., pierce 2, colour ice)` plus `line` flash at the muzzle; `Sfx.play("whoosh")`. | **Ice spear**: every 2.5 s hurls a spear at the nearest enemy in the aura: damage `FT_DPS[tier-1] * 2.0`, pierce 2 (hits up to 3), element ice, chilling. | wide_field |
| 4 Frostbitten | A snowflake glyph is carved into the head (6 spokes with V branches), the field circle gets a second inner ring and glowing rune dots (6) on it; frozen breath puffs (3 white circles rising and growing from the pole top). Chilled enemies get a pale-blue ring (drawn by the totem from the enemy positions inside). | Chilled mark: a ring (r 7) at each chilled enemy, drawn not spawned. | **Frostbitten**: enemies in the aura are marked chilled while inside and for 2.5 s after (meta `chilled_until`): they take +25% damage from every source (`Game.mark_mult`). | potent |
| 5 Blizzard Heart | A small storm swirls around the totem: 3 spiral arms (arc segments, snow white alpha 0.4) rotating, 14 snow dots swirling in the spiral, the head glows deep blue with a white core, tier ring cyan. Thin aurora arcs above. | Casting: `ripple` radius 30 rings 2 around the totem and the blizzard copy on the target spot; `Sfx.play("cast")`. | **Blizzard heart**: every 15.0 s, if enemies are in the aura, it casts a Blizzard at the densest group in range (`StructureTiers.cast(st, "blizzard", 0.8)` at that enemy's position; the copy carries `tier` so it gains the Blizzard's own tier abilities). | regrow |
| 6 Winter's Reign | A crown of 7 icicles (long triangles) around the head, a rotating snowflake halo (radius 12, 6 spokes) above it, a base of piled ice blocks (3 rounded rects), a faint aurora curtain behind (2 translucent wavy bands cyan/violet). | **Absolute zero** every 20 s: `flash` radius = aura radius 1.0, `ripple` rings 3, `shards` count 16, `Sfx.play("ultimate")`. Shatter: `ripple` radius 36 + `shards` count 8 at each death. | **Winter's reign**: (1) an enemy that dies inside the aura explodes in a frost nova: `FT_DPS[tier-1] * 3.0` to those within 36 px and a 0.5 s freeze; (2) every 20.0 s absolute zero freezes everything in the aura for 1.5 s and makes it exposed for 2.5 s. | tough |

## Rules for the implementer
- `core/game.gd` `mark_mult`: add `chilled_until` x1.25 to the list (see `sentry.md` / `stasis.md` for the shared function).
- `tick_frost_totem(st, delta)`: the base `apply_slow` stays; `pace` timers `"bite" 0.5`, `"spear" 2.5` (needs a visible enemy), `"blizzard" 15.0` (only when enemies inside), `"zero" 20.0`; `charge = zero_timer / 20.0` for tier 6; set the meta `chilled_until` each frame for tier >= 4. Shatter uses `StructureTiers.deaths(st, radius)`.
- `StructureTiers.cast(st, "blizzard", 0.8)` casts at the densest enemy within `radius` (use a `densest` helper like the spell one, implemented once for structures) and falls back to the totem position. It sets `d.copy = true` so the blizzard copy skips its FINALE but keeps its other abilities.
- Spear: `WeaponProjectile.shoot(world, pos, dir, 220.0, dmg, ice, 0.7, 2, 40.0)`; for chill add `extra = {}`; chilling is in the totem's own slow, no change.
- Constants: `FT_DPS`, `FT_SPEAR_T := 2.5`, `FT_BLIZZ_T := 15.0`, `FT_ZERO_T := 20.0`, `FT_NOVA_R := 36.0`, `FT_MARK := 1.25`.
- Draw: `StructureArt.draw_frost_totem(st, col)`; chilled rings: loop `get_tree().get_nodes_in_group("enemy")` within `radius`, cap 20.
- Multiplayer: nothing special (`charge` public).

## How to test (`tools/tests/tier_frost_totem.gd`)
1. Rime: tier 2 dummy inside loses ~1 hp per second, tier 1 none.
2. Spear: tier 3: a `projectile.gd` node appears within 2.6 s and a dummy at 40 px takes `>= FT_DPS * 2`.
3. Frostbitten: tier 4: `dummy.spell_damage(10)` takes 12.5; 2 s after it leaves still marked; tier 3: 10.
4. Heart: tier 5: within 15.5 s a spell node with `data.id == "blizzard"` exists at the dummy cluster and `data.copy == true`.
5. Reign: tier 6: kill a dummy (health 1) inside: a second dummy 20 px away is frozen; after 20 s a `flash` fx is seen and all dummies in the aura have `slow_mult == 0` and are exposed.
6. Cumulative: tier 6 keeps spears and the bite.
