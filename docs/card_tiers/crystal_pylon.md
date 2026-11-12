# Crystal Pylon (`crystal_pylon`, kind `build`/`sentry`, element pierce, night)

## Today
- A long-range rapid sentry: `range` 170 (the longest of the basics), `damage` 2.5 piercing (ignores armour), `interval` 0.35 s, `light` 50 (night light). Shot is a pale instant `line`. Looks like the generic sentry in violet.
- Adds already (`BUILD_TWISTS.sentry`): t2 `twin_shot`, t3 `frost_shot`, t4 `rapid`, t5 `heavy`, t6 `blast_shot`.
- Flavour: Crystal Pylon = crystal resonance: embedded shards, a pylon network, laser lances, brilliance, starfall.

Palette: amethyst `Color(0.8,0.6,1.0)` (card colour), deep `Color(0.45,0.25,0.75)`, white `Color(0.95,0.92,1.0)`, glint `Color(0.85,1.0,1.0)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Shardburst | A crystal floats above the box (hex prism height 10, three facets dark/mid/white, black outline), turning slowly (`_age`) with a glint star every 2 s; small embedded-shard pips (up to 4) shown on the box face as the target's stack count (public `charge = stacks/4`). | Embedded shards: tiny violet 3-line stars on the target (`burst` radius 5 per hit); when they burst: `shards` count 8 radius 30 amethyst + `flash` radius 22; `Sfx.play("big_hit")`. | **Shardburst**: every hit embeds a shard in the target (stack up to 4, kept 5 s); on the 4th stack the shards explode: `damage * 4.0` piercing to the target and `damage * 2.0` to enemies within 30 px, stacks reset. | twin_shot |
| 3 Resonance | Two small crystals orbit the main one at 9 px (angular speed 2 rad/s), the box gets inlaid violet lines; thin beam lines (violet-white, 1.5 px, alpha 0.5) connect to linked pylons. | A linked pylon's barrel flashes in time (draw only). | **Resonant link**: another Crystal Pylon (or Prism Tower) within 100 px resonates with this one: each linked partner (max 2) makes it fire 25% faster (`interval_mult` 1/(1+0.25 n)). The link works both ways. | frost_shot |
| 4 Laser Lance | The main crystal is larger (height 14) with a lens-like glow at its tip that charges (a white circle growing r 1..4 as `charge` approaches the lance shot); the box has a second layer. | Lance: `line` (width 8, length range, violet-white) from the tip to max range along the aim, a second thinner white `line` over it, `flash` radius 14 at the muzzle; `Sfx.play("ultimate")` (pitch 1.4). | **Laser lance**: every 10th shot is a piercing beam: `WeaponUtil.enemies_in_line(tree, pos, dir, range, 8)` all take `damage * 5.0` piercing. `charge` = shots/10. | rapid |
| 5 Brilliance | A bright halo behind the main crystal (disc r 12 alpha 0.25 + 4 rays), rainbow edge on the prism (facet highlight lines cycling hue slowly: `Color.from_hsv(fposmod(_age*0.2+i*0.15,1),0.4,1)`), the base lit. The night light ring is larger. | Dazzled enemies: tiny glint star (3 px) over them (drawn from enemy positions inside the light, max 12). | **Brilliance**: the light radius doubles (`light_radius = base * 2`, `_glow` scaled) and every enemy inside the light is dazzled: `apply_slow(0.8, 0.4)` and exposed (`WeaponUtil.expose(e, 0.5)`). | heavy |
| 6 Starfall | A crown of 6 crystals floats around the main one (radius 14, different heights, hue shifts), runes glow on the ground (ring of 8 marks r 20), a column of violet light. | Starfall: for each target a `fall` fx (crystal head, radius 4, height 120, life 0.4) with the telegraph `ring` radius 14, then `shards` count 6; `Sfx.play("big_hit")` per impact. | **Starfall**: every 10.0 s six crystal shards fall on six distinct enemies in range: `WeaponUtil.ground_strike(radius 14, delay 0.4, damage * 3.0, knock 100, amethyst, stun 0.3, [], "pierce")`; afterwards the pylon is supercharged for 4 s (`interval_mult` 0.5). | blast_shot |

## Rules for the implementer
- Hooks per section 10: `interval_mult` (resonant partners; supercharge), `shot_mult` = 1.0, `on_shot`: stacks (`_stacks := {}` enemy -> [count, time]), lance every 10th `_shots` (always spend the shot normally AND the lance in addition), starfall via `pace(st, "star", 10.0)` when enemies in range.
- Link: `StructureTiers.linked(st)` returns other structures in group `structure` with `data.id in ["crystal_pylon", "prism_tower"]` within 100 px and `tier >= 3`, capped at 2. Draw the link lines from both sides (cheap) using the same function.
- Brilliance: set once when the tier changes: `on_promote_crystal_pylon(st, t)` (and `_ready` for a card placed at tier 5 or 6) sets `light_radius = data.light * 2.0`; ensure `_glow.texture_scale` updated (copy the pattern in `Structure.promote`). Tick: `enemies(st, light_radius)` are dazzled at all times (day too; only the shroud is night-only).
- Constants: `PYLON_STACKS := 4`, `PYLON_BURST := 4.0`, `PYLON_BURST_SPLASH := 2.0`, `PYLON_LINK_R := 100.0`, `PYLON_LINK := 0.25`, `PYLON_LANCE_EVERY := 10`, `PYLON_LANCE := 5.0`, `PYLON_STAR_T := 10.0`, `PYLON_SUPER := 0.5`, `PYLON_SUPER_T := 4.0`.
- Draw: `StructureArt.draw_crystal_pylon(st, col)`; replaces the sentry head by the obelisk (box + crystal) from tier 1 with a small crystal, floating crystal grows by tier.
- Multiplayer: `charge`, `aim`; links computed from structure positions on both sides.

## How to test (`tools/tests/tier_crystal_pylon.gd`)
1. Shardburst: tier 2, dummy A in range, 4 shots: on the 4th hit a bigger step of damage (>= 4 x damage) occurs; tier 1 none.
2. Link: tier 3 pylon with a partner 80 px away fires ~25% more often over 6 s than alone; partner out of range (150 px) none.
3. Lance: tier 4: on the 10th shot dummies 20 and 100 px along the line both take >= 5 x damage; an off-line dummy does not.
4. Brilliance: tier 5: `light_radius ~= 2 x` the tier-4 value; a dummy inside has `slow_mult <= 0.81`.
5. Starfall: tier 6: with 6 dummies in range, after 10 s six `ring` fx of life 0.4 and each dummy hurt; then `interval` effectively halves for 4 s (count shots).
6. Cumulative: tier 6 still lances and shardbursts.
