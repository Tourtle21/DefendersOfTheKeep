# Mender Totem (`mender`, kind `build`/`mender`, no element)

## Today
- A small totem (`radius` 45 healing field, `heal_per_sec` 6, `duration` 60 -> a total healing budget of 360 hp). Each frame it heals any player in range who is hurt (`p.needs_health()`) by `heal_per_sec * delta` and counts it; when the budget is spent it expires (`_expire`).
- Drawn as a dark pole with a round green head inside a pulsing green field circle.
- Adds already (`BUILD_TWISTS.mender`): t2 `wide_field` (+40% radius), t3 `swift_heal` (+60%), t4 `potent` (+25%), t5 `regrow` (self-heal), t6 `tough` (+40% hp).
- Family: Mender = ancestral spirit totem (blessings, wisps, a guardian angel). Healing Grove = living nature, Phoenix Shrine = fire and rebirth, Healing Lantern = light.

Palette: spirit `Color(0.4,1.0,0.5)` (card colour), wood `Color(0.6,0.42,0.25)`, dark wood `Color(0.35,0.22,0.12)`, bone `Color(0.92,0.9,0.78)`, gold `Color(1.0,0.85,0.4)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Carved Totem | The pole shows a carved face on the head: two dark eye slits, a small mouth line, a feather crest (3 bone/green triangles) on top, painted bands (2 horizontal stripes in spirit green). Eyes glow while it heals. | Blessing: `ring` radius = field radius, `motes` count 8 radius radius rise 22 spirit green, `Sfx.play("cast")`. | **Blessing pulse**: every 6.0 s it sends out a pulse that instantly heals every player in range by `heal_per_sec * 1.0` (hurt players only; these pulses do NOT use the healing budget). | wide_field |
| 3 Guardian Spirit | A second smaller head stacked on the first (totem of two), vines winding round the pole (a sine-curve polyline, leaf-green, with 4 tiny leaves), eyes glow brighter. | Mend: little `motes` count 2 rise 10 over each guard/structure mended (throttled to once per 1.5 s per target). | **Shared mending**: guards and structures inside the field mend at half the totem's rate: `StructureTiers.mend(st, radius, heal_per_sec * 0.5, delta)`; the budget is not used. | swift_heal |
| 4 Lifeline | Wooden wings spread from the head (two curved polygons, bone with green tips), hanging charms (3 short lines with a bead that swing with `sin(_age*2+i)`), a rune ring (8 marks) turns in the field at 0.7 radius. | Cleanse: `star` radius 14 count 6 white-green at the cleansed player; `Sfx.play("unlock")`. | **Lifeline**: (1) players below 40% health inside the field are healed double (`x 2.0` on the continuous heal, still counted once against the budget); (2) players that are confused (`confused_time > 0`) are cleansed at once (`p.confused_time = 0.0`, announce nothing). | potent |
| 5 Spirit Wisps | Three wisps (r 3 white-green orbs with a 4-dot tail and a soft halo) circle the totem at 0.55 radius (angular speed 1.6 rad/s). Beam lines of faint green connect the totem to each healed player. The crest is now gold-green. | Spirit link: a pale `line` from the totem to each player healed beyond the field (`life 0.15`, throttled to 4 per second). | **Spirit link**: the totem now reaches 1.5 x its field: players between `radius` and `1.5 * radius` are healed at 50% rate (and count 50% of the budget). A visible beam is drawn to them. | regrow |
| 6 Guardian Angel | A tall three-segment totem with a gold halo ring (arc radius 8 over the head, rotating dash highlights), spread wings of light (two big tapered feather polygons, white-gold, alpha 0.5, flapping slowly `sin(_age*1.5)`), a gold crown of leaf points, and runes in the pole. The field gets a faint gold disc. | **Guardian angel**: `pillar` height 70 width 28 gold, `flash` radius 40, `star` radius 36 count 8, `Sfx.play("ultimate")`. | **Guardian angel**: when a player inside the (extended) field falls below 15% health the totem saves them: instantly heals them to 60% and gives `shield_time = 2.0`; each player can be saved once per 30 s. It does not use the healing budget. | tough |

## Rules for the implementer
- `structure.gd` mender branch: after the heal loop call `StructureTiers.tick_mender(self, delta)`; the base loop itself changes only for Lifeline: the heal amount gets a factor `StructureTiers.heal_mult(self, p)` (1.0 default, 2.0 under 40% at tier 4+). `radius` stays the base field; Spirit link and Guardian angel use `radius * 1.5` (a constant `MENDER_LINK := 1.5`).
- Helper `StructureTiers.hp_frac(p) -> float`: `p.remote_hp / 228.0` for `remote_controlled` players; otherwise the local Health rect: `p.get_parent().get_node_or_null("Hud/Control2/ColorRect/Health")` -> `size.x / 228.0`; return 1.0 if not found (split-screen players: use the same rule as `Player.needs_health()`, look at it and mirror).
- Blessing pulse: `pace(st, "bless", 6.0)`: `for p in players in radius: if p.needs_health(): p.heal(data.heal_per_sec * 1.0)`.
- Angel: `_saved := {}` (player -> time since). Check `hp_frac(p) < 0.15` each tick for players within 1.5 radius; heal with `p.heal((0.6 - frac) * 228.0 * Game.hp_scale())` (`Player.heal` divides by `Game.hp_scale()`, so this lifts the bar to exactly 60%).
- Wisps are pure drawing (positions from `_age`); beams draw to the players the host last healed: public `healed_pos: Array` (Vector2s, at most 4) updated on the tick.
- Constants: `MENDER_BLESS_T := 6.0`, `MENDER_MEND := 0.5`, `MENDER_LIFELINE := 2.0`, `MENDER_LIFELINE_AT := 0.4`, `MENDER_LINK := 1.5`, `MENDER_ANGEL_AT := 0.15`, `MENDER_ANGEL_TO := 0.6`, `MENDER_ANGEL_CD := 30.0`.
- Draw: `StructureArt.draw_mender(st, col)` (also used by `healing_grove` / `phoenix_shrine` only where noted in their files).
- Multiplayer: nothing beyond the public `healed_pos`.

## How to test (`tools/tests/tier_mender.gd`)
1. Blessing: tier 2 with a hurt player (set Health rect to 100): within 6.2 s the Health rect jumps by at least `heal_per_sec` at once on top of the continuous heal; tier 1 only continuous.
2. Shared mending: tier 3 guard at 5 hp and a structure at half hp inside the field gain hp; tier 2 do not.
3. Lifeline: tier 4 player at 30% heals about twice as fast as at 60% (compare per second); a `confused_time = 3` player is cleansed.
4. Link: tier 5 player at 1.3 x radius is healed at ~half rate; tier 4 not healed.
5. Angel: tier 6 player Health rect set to 20 (of 228) is healed to >= 60% within a frame and has `shield_time >= 1.9`; a second drop within 30 s is not saved.
6. Budget: the totem still expires when the continuous healing budget is used up (blessing/angel do not shorten it).
