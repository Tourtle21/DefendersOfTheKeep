# Prism Tower (`prism_tower`, kind `build`/`sentry`, no element)

## Today
- Strong splashing sentry: `range` 160, `damage` 4, `interval` 0.7, `burst` 3 (splash `burst * 0.5` within 24 px). Instant pale-pink shot line; generic sentry look in pink-white.
- Adds already (`BUILD_TWISTS.sentry`): t2 `twin_shot`, t3 `frost_shot`, t4 `rapid`, t5 `heavy`, t6 `blast_shot`.
- Flavour: Prism Tower = split light: three colours, lenses, a burst of beams, refraction, a white-light lance.

Palette: prism white `Color(1.0,0.8,1.0)` (card colour), red `Color(1.0,0.35,0.3)`, blue `Color(0.4,0.6,1.0)`, yellow `Color(1.0,0.9,0.4)`, glass `Color(0.9,0.95,1.0)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Spectrum | The head is a glass triangular prism (triangle 12 wide, translucent glass with white edges, black outline) on the box; the colour of the next shot is shown as a glowing dot inside (red / blue / yellow cycle, `aim`-independent, public `charge` 0, 0.33, 0.66 maps to the colour). | Shot in the current colour (`line` 3 px + `burst` radius 8 in that colour). `Sfx.play("whoosh")`. | **Spectrum**: shots cycle red, blue, yellow. Red: burns (`bleed` 3 ticks of `damage * 0.3`). Blue: chills (`apply_slow(0.5, 1.5)`). Yellow: exposes (`WeaponUtil.expose(e, 2.0)`). | twin_shot |
| 3 Focus Lens | A round lens ring in front of the prism (arc r 7, glass, white glint) that rotates to focus; a thin dotted guide line shows the aim. | When focused (only one target): the shot `line` is white and width 5, `flash` radius 14. `Sfx.play("big_hit")`. | **Focus lens**: if exactly one enemy is visible in range, the shot is focused for double damage (`shot_mult` 2.0). With a crowd it behaves as before. | frost_shot |
| 4 Prismatic Burst | A hexagon of small crystals (6) around the prism, each in a different hue (cycle), the prism glows from inside more; the tower base has a lit rainbow ring (arc segments in 6 hues). | Burst: 12 `line` rays (length `range * 0.6`, each alternating red/blue/yellow, width 2) radiating from the prism, `ripple` radius 40 rings 2, `Sfx.play("ultimate")` (quiet, pitch 1.5). | **Prismatic burst**: every 8th shot also fires 12 rays round the tower: every enemy within `range * 0.6` along any ray (`enemies_in_line`, width 5) takes `damage * 0.8`; the 12 rays cover 12 directions. | rapid |
| 5 Refraction | Mirror shards float round the prism (3 triangles, silver, drifting), the glass has a rainbow edge; a faint refracted copy of the beam is drawn bending at each mirror. | The shot bends: `line` from the tower to the target, then up to 2 more `line` segments (white-hue) from victim to victim. | **Refraction**: the shot bounces: from the target it jumps to the nearest other enemy within 70 px for 60% damage, then once more (60% again), each with a colour effect of the current colour. | heavy |
| 6 Spectrum Lance | A full glass crown: 3 stacked prisms, a rotating rainbow halo (arc segments in 6 hues, radius 14), a beam of white light shooting straight up (column alpha 0.4), floor rainbow caustics (6 light spots moving). `charge` fills a white core ring. | **Lance** every 15 s: a white-rainbow beam (`line` width 18 white under 6 thinner hue lines), `flash` radius 28, `ripple` rings 3, `Sfx.play("ultimate")`. | **Spectrum lance**: every 15.0 s the tower fires a massive beam at the toughest visible enemy (highest `max_health`) through everything behind it: length `range`, width 18: `damage * 8.0` to all in the line, with all three colour effects (burn, chill, expose). | blast_shot |

## Rules for the implementer
- Hooks section 10: `shot_mult` (focus lens: count visible enemies in range via `StructureTiers.enemies(st, range)` filtered with `Game.defence_sees`; if exactly 1 -> 2.0); `on_shot`: colour effect by `_shots % 3`, burst every 8th `_shots`, refraction chain (two jumps), lance `pace(st, "lance", 15.0)`.
- Current colour `colour_i = _shots % 3` also published as public `charge = colour_i / 3.0` for drawing.
- Rays/lines: `WeaponFx` kinds `line` with `dir`/`length`; damage uses `WeaponUtil.enemies_in_line(tree, pos, dir, len, 5)`.
- Constants: `PRISM_FOCUS := 2.0`, `PRISM_BURST_EVERY := 8`, `PRISM_BURST := 0.8`, `PRISM_REFRACT_R := 70.0`, `PRISM_REFRACT := 0.6`, `PRISM_LANCE_T := 15.0`, `PRISM_LANCE := 8.0`.
- Draw: `StructureArt.draw_prism_tower(st, col)`; hues via `Color.from_hsv`.
- Multiplayer: `charge`, `aim` public; nothing else.

## How to test (`tools/tests/tier_prism_tower.gd`)
1. Spectrum: tier 2: three consecutive shots on a dummy: a bleed (health keeps dropping), `slow_mult <= 0.51`, and `is_exposed` each appear in order.
2. Focus: tier 3: one dummy: shot damage 2x the tier-2 equivalent (compare with 2 dummies present: 1x).
3. Burst: tier 4: on the 8th shot 12 `line` fx of the burst appear and dummies at 40 px in several directions are hurt.
4. Refraction: tier 5: dummies A (target), B 50 px from A, C 50 px from B: B and C both lose health on each shot; tier 4 only A.
5. Lance: tier 6: within 15.2 s a `line` fx of width 18 and the toughest dummy takes >= 8 x damage; dummies behind it on the line too.
6. Cumulative.
