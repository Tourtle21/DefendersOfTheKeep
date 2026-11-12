# Fireball (`fireball`, kind `fireball`, element fire)

## Today
- A slow orange shot (3 px dot, 6-point trail) flies to the target outline, then a flat orange disc of `radius` (45) fades in 0.4 s; every enemy in the radius takes `damage` (5) once.
- Lights the area for 2 s (`LightSource.spawn`) and, at night, glows in flight. Fire lights what it hits.
- Adds already: t2 `wide` (radius x1.4), t3 `twin` (second cast 0.5 s later), t4 `aftermath` (burn patch), t5 `burn` (4 ticks of bleed), t6 `shrapnel` (6 small bolts).

## Tier table (colours: base `Color(1.0,0.45,0.1)`, hot `Color(1.0,0.8,0.3)`, white core `Color(1.0,0.97,0.85)`, ash `Color(0.25,0.12,0.08)`)

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Cinder | Shot is 4 px with a white-hot 2 px core; trail is 8 dots alternating hot/base shrinking. Landing disc gets an inner white disc (0.45 r) that fades in 0.2 s and 4 ember dots that rise 14 px (`jit` positions). | `flash` radius r on land, `shards` count 6 colour hot radius r*1.1; `Sfx.play("big_hit")`. | **Concussion**: every enemy in the blast is shoved away from the centre: `e.push(dir * 150, 0.18)` (bosses barely move, fine). Players are not pushed. | wide |
| 3 Bullseye | Shot has two orbiting embers (radius 6, angular speed 9 rad/s from `age`). The target outline shows a second dashed inner ring at 0.4 r (12 short arcs of 0.3 rad) in white so the player can aim at the core. | White `ring` at 0.4 r with `life 0.25`, plus `burst` radius 0.4 r colour white. | **Bullseye**: enemies within 0.4 r of the centre take double damage (`damage * 2` instead of `damage`). Showing `DamageNumber` happens through the normal `spell_damage` path. | twin |
| 4 Kindling | Flame corona around the landing disc: 8 tongues (triangles base 6 px, height 10..16 px by `jit`) rotating slowly with `since`, hot to base gradient, alpha 0.5. Shot gets a teardrop flame tail (polygon of 5 points behind it, 14 px long). | Per kill: `burst` radius 22 hot + `ring` radius 30. Landing `LightSource` radius `r*2.2` for 3 s. | **Kindling**: an enemy killed by the blast (or by the shrapnel/burn of this spell, only the blast counts) bursts into flame: 45% of `damage` to enemies within 30 px of its position, once (the pops do not chain). | aftermath |
| 5 Firestorm | A pillar of fire stays on the spot for 1.6 s: 5 stacked flame polygons (width r*0.5 shrinking to r*0.2, height 38 px) swaying with `sin(since*7+i)`, base white, tip base colour. Heat rings: 2 thin arcs at 0.55 r and 0.8 r pulsing. Glow `LightSource` r*2.4, 1.8 s. | Three pulses at 0.4/0.8/1.2 s: each `pillar` height 60 width r*0.5 plus `ring` radius 0.8 r; `Sfx.play("thump")` per pulse. | **Pillar of fire**: after the blast the spot keeps burning: 3 pulses at 40% of `damage` each in 0.8 r, enemies hit by a pulse are held in place 0.2 s (`apply_slow(0.3,0.25)`). `effect_time` becomes 1.6 so the node lives long enough. | burn |
| 6 Sunfall | The flight is a comet: 4 px white core, 9 px orange halo (alpha 0.35), 12-dot tail that is 2x as long and sparks. Landing is a miniature sun: concentric discs gold / orange / red-edge (r*0.45, 0.75, 1.0), 12 rotating rays (lines, length 1.3 r, width 2, alpha 0.5) for the whole 1.6 s. | **Finale**: `flash` radius 1.6 r, `ripple` radius 2.0 r rings 3, `Sfx.play("ultimate")`, then 6 meteors (`WeaponUtil.rain`) over 1.0 s. `LightSource` r*3.0 for 4 s. | **Sunfall (FINALE)**: shockwave knocks back everything within 2.0 r (push 220) for 35% of `damage`, then 6 small meteors (strike radius 16, 40% of `damage` each) fall in a ring of 1.3 r. Skipped when `data.copy` (a twin does the normal blast). Together with shrapnel the cast is a full firework. | shrapnel |

All tiers keep every lower tier's ability (Concussion + Bullseye + Kindling + Pillar + Sunfall at 6). Total extra damage at tier 6: pillar 1.2 x damage + kindling pops + bullseye + finale ~ a bit over 2x of the blast alone: acceptable because a tier-6 fireball is a one-shot ultimate-grade card (mana 25 x 1) and `twin` copies skip finale. If the implementer measures more than 2.6 x blast damage, cut the pillar pulses to 30%.

## Rules for the implementer
- `cards/spell_tiers.gd`: `land_fireball(s, tier)` runs after `_apply_twist` (blast damage is already dealt by the existing `if data.kind == "fireball"` code in `spell.gd`; change that loop to go through a helper `SpellTiers.blast_fireball(s, tier)` so the Bullseye multiplier and Kindling kill check live in one place — the old loop calls `e.spell_damage(data.damage, element, true)` per enemy, replace with: compute `d = dist(e, s)`, `mult = 2.0 if tier >= 3 and d <= s.radius*0.4 else 1.0`, call damage, then if `tier >= 2` push, then if `tier >= 4` and the enemy is dead, `pop(s, e_pos)`).
- Capture the enemy position BEFORE damaging (it may be freed after `die()`).
- T5 pillar: do it with `s.get_tree().create_timer(0.4 * i)` callbacks (i = 1..3), each guarded by `is_instance_valid(s)`; or keep the pulses in `tick_fireball` with a private `_pulses` counter and `since` thresholds (preferred, nothing outlives the node). `effect_time` for fireball becomes `1.6 if tier >= 5 else 0.4` in `Spell.setup` (via `SpellTiers.effect_time`).
- T6 finale: `if tier >= 6 and !data.get("copy", false)`. Use `WeaponUtil.rain(tree, world, pos, r*1.3, 6, 1.0, damage*0.4, 16.0, hot)`.
- Draw: `SpellArt.flight_fireball(s, t, col)` (shot variants by tier) and `SpellArt.draw_fireball(s, since, col)` (landing art by tier). The old landing disc (`fade = 1 - since/0.4`) must instead use `fade = 1 - since/effect_time` ONLY for pillar duration; keep the base disc fading in 0.4 s.
- Constants: `FIREBALL_PUSH := 150.0`, `FIREBALL_CORE := 0.4`, `FIREBALL_POP := 0.45`, `FIREBALL_PULSE := 0.4`, `FIREBALL_FINALE_KNOCK := 220.0`, `FIREBALL_METEORS := 6`.
- Fused cards `frostfire` and `solar_burst` are kind `fireball` and run this same code through their own `land_*` that reuses these helpers (see their files).
- Multiplayer: nothing special; pulses and finale are host-side, visuals all through `WeaponFx.spawn`; the pillar drawing derives from `since` and `tier`.

## How to test (`tools/tests/tier_fireball.gd`)
1. Concussion: dummy at 20 px from impact, tier 1 vs tier 2: after 0.3 s the tier-2 dummy is further from the centre (position delta > 8), the tier-1 dummy is not moved.
2. Bullseye: two dummies, one at 5 px, one at 0.8 r; damage taken by the centre one is >= 1.9x the edge one at tier 3 and equal at tier 2.
3. Kindling: dummy A (health 3) at centre, dummy B (health 99999) 20 px from A; at tier 4 B takes damage from the blast plus the pop, at tier 3 only the blast (compare against `expected = damage*1 (+bullseye)`).
4. Pillar: tier 5 `effect_time >= 1.6`, a dummy at the centre takes >= 3 extra hits (collect `DamageNumber`s or compare health at 0.3 s and 1.5 s); tier 4 gets none after 0.5 s.
5. Finale: tier 6 spawns kinds `flash` and `ripple` (fx scan) and 6 ground strikes (count `ring` fx with life 0.45); a `data.copy = true` cast spawns neither.
6. Draw smoke: draw each tier landed and unlanded, no script errors.
