# Crystal Spikes (`crystal_spikes`, kind `spikes`, element pierce)

## Today
- On landing, 3 ground strikes in a triangle (22 px from the target, angles -90, 30, 150 degrees) with delays 0.30 / 0.45 / 0.60 s: each shows a violet `ring` of `radius` 24, then hits everything in it for `damage` 12 with knock 160 and stun 0.3, and a second brighter ring. `duration` 1.2 s. Piercing damage ignores armour.
- The spell's own drawing is just the shared pulsing disc; the spikes themselves are only rings.
- Adds already (spikes pool): t2 `wide`, t3 `aftermath` (slow patch), t4 `lingers`, t5 `echo`, t6 `shrapnel`.

Palette: amethyst `Color(0.8,0.6,1.0)`, deep `Color(0.45,0.25,0.75)`, white `Color(0.95,0.9,1.0)`, glint `Color(0.85,1.0,1.0)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Impale | The spikes become real crystals: each strike point draws a hex prism rising out of the ground over 0.15 s (width 8, height 18..22, three facets: dark left, amethyst middle, white right, black outline) and stays until the spell ends; cracks (3 short lines) radiate from its base. | On eruption: `shards` count 6 radius 20 amethyst, `burst` radius 14; `Sfx.play("big_hit")`. | **Impale**: an enemy hit is skewered: held 1.2 s (`apply_slow(0.0, 1.2)` instead of 0.3) and marked exposed for 2.0 s (`WeaponUtil.expose`) so every other attack on it hits harder. | wide |
| 3 Crystal Garden | The crystals stay: the spell lives 4.0 s; between the three big crystals 4 small ones (height 8..11) grow after 0.5 s; crystals hum: a slow alpha pulse on the facets and a pale glint star (4 lines of 3 px) travelling across each every 1.2 s. | When a crystal zaps: tiny `bolt` (length = distance, width 2) from the crystal tip to the enemy. | **Crystal garden**: each of the 3 crystals keeps zapping any enemy within 20 px of its base every 0.6 s for `damage * 0.3` (piercing, aoe). Lasts until the spell ends (4 s). | aftermath |
| 4 Fissure | Three cracks run outward from the triangle: each a dark zigzag line (7 segments, width 3, deeper violet) from the strike point 70 px away from the centre, glowing along its centre (white thin line, alpha 0.5); crystals along the crack grow smaller (heights 16, 12, 9). | Each fissure spike: `ring` radius 14 (0.3 s telegraph from the ground strike) + `shards` count 4 radius 14. The sequence travels outward in 0.45 s. | **Fissure**: from each of the 3 spikes a line of 3 more spikes runs outward (`+26 px` each, direction from the cast centre through the spike), delays 0.15 s apart after the spike, each `damage * 0.5`, radius 14, stun 0.3. | lingers |
| 5 Prism Web | Between the three big crystals three thin bright beams (triangle edges, white-violet gradient: a 3 px glow line alpha 0.25 under a 1 px white line alpha 0.9) pulse; each crystal has a floating rhombus prism above it (diamond 5x8) rotating its refraction colour through `Color.from_hsv(fposmod(since*0.3 + i*0.33, 1), 0.35, 1)`. | The beams flash: when an enemy crosses an edge `burst` radius 8 in the refraction colour. | **Prism web**: the 3 crystals are linked: every enemy crossing a triangle edge (`WeaponUtil.enemies_in_line` along each edge, width 5) takes `damage * 0.4` every 0.25 s and is slowed to 0.5. The web is just the triangle (edge length about 38 px). | echo |
| 6 Crystal Bloom | A great crystal cluster at the centre grows during the strike: 7 prisms in a flower (heights 34, 28, 28, 24, 24, 20, 20, angles spread +-50 degrees), faint prismatic rainbow glow disc (r 1.2 r alpha 0.18), 12 floating glints. The bloom shatters when it ends. | **Finale**: after the three spikes (0.9 s) the bloom erupts: `ring` telegraph radius 1.6 r (0.4 s), then `flash` radius 1.6 r, `shards` count 14 radius 1.6 r, `ripple` radius 1.6 r rings 2, `Sfx.play("ultimate")`; 12 crystal shards fly out as projectiles. | **Crystal bloom (FINALE)**: a huge crystal erupts at the cast point: `WeaponUtil.ground_strike(radius 1.6 r, delay 0.4, damage * 2.0, knock 220, color, stun 0.8, [], "pierce")`; when it shatters 12 `WeaponProjectile`s (damage `damage * 0.5`, pierce 1, speed 200, life 0.6, amethyst) fly out. Skipped when `data.copy`. | shrapnel |

## Rules for the implementer
- `SpellTiers.land_crystal_spikes(s, tier)` is called after the base 3 `ground_strike`s in `spell.gd` (`elif data.kind == "spikes"`); change that branch to read the stun from `SpellTiers.spike_stun(tier)` (0.3 base, 1.2 from tier 2) and to mark exposed on hit: since `ground_strike` has no hit callback, do the expose in `tick_crystal_spikes` the frame after each strike delay: any enemy inside the strike radius of a strike whose delay just passed gets `WeaponUtil.expose(e, 2.0)`. (Alternative if the implementer prefers: add an optional `on_hit: Callable` argument to `WeaponUtil.ground_strike` and use it.)
- `effect_time` for `spikes` is `4.0` from tier 3 (`SpellTiers.effect_time`), else the old 1.2.
- Garden/web ticks use `pace`. Crystal base positions are the same triangle spots: `SpellTiers.spike_spots(s)` returns the 3 `Vector2`s (used by logic and `SpellArt`), computed from `position`.
- Fissure: spawn extra ground strikes at `spot + dir * 26 * k` for k=1..3 with delays `delay_i + 0.15 k`.
- Bloom: schedule at `since >= 0.9` once; guard with `_bloom_done`.
- Draw: `SpellArt.draw_crystal_spikes`; each crystal's height factor `clamp((since - delay_i) / 0.15, 0, 1)`; crystals fade over the last 0.5 s.
- Constants: `SPIKE_STUN := [0.3, 1.2, 1.2, 1.2, 1.2, 1.2]`, `SPIKE_ZAP_T := 0.6`, `SPIKE_ZAP_R := 20.0`, `SPIKE_WEB_T := 0.25`, `SPIKE_BLOOM := 2.0`.
- Multiplayer: nothing special.

## How to test (`tools/tests/tier_crystal_spikes.gd`)
1. Impale: tier 2 dummy under a spike: `slow_time > 1.0` after the strike and `WeaponUtil.is_exposed(e)`; tier 1: `slow_time < 0.4`.
2. Garden: tier 3 spell is alive at 3.0 s; a dummy placed 10 px from a crystal base at 2.0 s loses health; tier 2 spell is gone at 2.5 s.
3. Fissure: tier 4 fx scan: >= 12 telegraph rings in the first 1.5 s (3 + 9) vs 3 at tier 3; a dummy 75 px out along a spike's direction is hit at tier 4 only.
4. Web: tier 5 dummy standing on a triangle edge (midpoint of two spots) takes damage repeatedly and has `slow_mult <= 0.5`.
5. Bloom: tier 6: a dummy at 1.4 r from centre takes >= 2x damage after ~1.5 s; >= 12 `projectile.gd` nodes seen; `copy = true` none.
6. Draw smoke at six tiers.
