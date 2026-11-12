# Ember Turret (`ember_turret`, kind `build`/`sentry`, element fire, night)

## Today
- A slow, hard-hitting fire sentry: `range` 120, `damage` 3, `interval` 1.0, `burst` 2.5 (splash: enemies within 24 px of the target take `burst * 0.5`), `light` 55 (a night light, group `light`, `GlowLight`). Hits instantly like every sentry. Drawn with the shared sentry look in orange.
- Adds already (`BUILD_TWISTS.sentry`): t2 `twin_shot`, t3 `frost_shot` (chills; odd for fire, left as is), t4 `rapid`, t5 `heavy`, t6 `blast_shot`.
- Family flavour: Ember Turret = a fire mortar: burning, shells, cluster bombs, an inferno mode.

Palette: ember `Color(1.0,0.45,0.15)` (card colour), iron `Color(0.3,0.3,0.34)`, glow `Color(1.0,0.75,0.3)`, white-hot `Color(1.0,0.96,0.8)`, ash `Color(0.2,0.12,0.1)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Incendiary | A squat iron mortar replaces the generic head: thick barrel (rect 5x9 turning to `aim`), glowing ember ring at the muzzle (circle r 3.5 glow, pulsing), two small flame vents on the sides (3-layer mini flames from `SpellArt.flame`), orange glow on the base. | Muzzle flash: `burst` radius 8 glow at the barrel tip; impact `burst` radius 12 ember; `Sfx.play("big_hit")` throttled. | **Incendiary rounds**: every hit enemy catches fire: `WeaponUtil.bleed(tree, e, 3, damage * 0.25)` (fire). | twin_shot |
| 3 Mortar | The barrel is a thick mortar tube angled up (polygon, iron with a brass band), a rack of 3 shells (small orange-tipped capsules) beside it, a recoil kick of 3 px along `aim` for 0.2 s after a shot. | Lobbed shell: `fall` fx at the target (radius 3, height 40, life 0.15) then `flash` radius 22; `ripple` radius 38 rings 1. | **Mortar shell**: the blast widens: on top of the normal splash, every enemy within 38 px of the target (except the target) takes `burst * 0.8` fire damage. | frost_shot |
| 4 Fire Shell | A small heat gauge: a dial on the side with a needle rising to the red as `_shots % 5` climbs (uses public `charge = (_shots % 5) / 5`); soot streaks, the shell rack holds a bigger golden shell. | Fireball: the Fireball spell's own flight and landing; a `ring` radius 16 at the muzzle. `Sfx.play("cast")`. | **Fireball shell**: every 5th shot also lobs a mini Fireball at the target: `StructureTiers.cast(st, "fireball", 0.8, -2)` (a Fireball two tiers below the turret's own, minimum 1, 80% radius). | rapid |
| 5 Cluster Bomb | Three small tubes on the head (cluster pack, fan of 3 narrow barrels with orange rims); the glow ring becomes a double ring; heat shimmer lines above the barrel (2 wavy lines). | Bomblets: 3 small `fall` fx (radius 2, height 30, life 0.25) around the target at 30 px, each ending in `burst` radius 10 and `ring` radius 16. | **Cluster bomb**: every shot scatters 3 bomblets around the target (at 30 px, angles `base + k*TAU/3`, 0.25 s later each, radius 16, damage `damage * 0.4`, fire). | heavy |
| 6 Inferno | The head becomes a dragon: horned iron head (two horn triangles), jaws (two plates) that open on a shot, eyes of fire (2 white-hot dots), a ring of heat haze; wings of heat: two translucent orange fans at the sides. While overdriving: barrel white-hot, flames pour from the vents (3 flames each), light radius bigger. | **Overdrive** every 12 s: `ring` radius 40 orange, `pillar` height 40 width 16, `Sfx.play("boss_roar")` (quiet pitch 1.5); in overdrive each shot spits a `line` of flame `burst`s. | **Inferno overdrive**: every 12.0 s the turret overheats for 3.0 s: it fires 4x as fast (`interval_mult` 0.25) with 60% damage per shot (`shot_mult` 0.6), range +20%, light radius x1.5. `charge` fills 0..1 over the 12 s; it is public so clients draw the glow. | blast_shot |

## Rules for the implementer
- Hooks from section 10 of `_CONVENTIONS.md`: `interval_mult` (overdrive), `shot_mult` (overdrive 0.6), `on_shot`: incendiary bleed, mortar splash (`StructureTiers.enemies_at(st, target_pos, 38)` minus target), fireball every 5th `_shots`, cluster bombs via `create_timer(0.25 * (k+1))` guarded by `is_instance_valid(st)`.
- `StructureTiers.cast(st, card_id, r_scale, tier_offset := 0)`: spell tier `maxi(1, st.tier + tier_offset)`; stats `Game.stats_of(Game.make_entry(card_id, t, Game.twist_for(card_id, t)))`, then `copy = true`; position is the target. Use `Spell.new().setup(d, target, st.global_position)` + `world.add_child` (the `setup` origin makes the shot fly from the turret). Cost: no mana.
- Overdrive: private `_od` seconds left; when `pace(st, "od", 12.0)` fires set `_od = 3.0`; while > 0, `range` check uses `data.range * 1.2`. Light: `st.light_radius = base * 1.5` and `_glow.texture_scale` update, restored after.
- Bomblets: positions fixed from the target at the moment of the shot.
- Constants: `EMBER_BLEED := 0.25`, `EMBER_MORTAR_R := 38.0`, `EMBER_MORTAR := 0.8`, `EMBER_SHELL_EVERY := 5`, `EMBER_CLUSTER := 0.4`, `EMBER_OD_T := 12.0`, `EMBER_OD_LEN := 3.0`, `EMBER_OD_RATE := 0.25`, `EMBER_OD_DMG := 0.6`.
- Draw: `StructureArt.draw_ember_turret(st, col)`; barrel angle from `aim`.
- Multiplayer: `charge`, `aim` public; `_od` is private; the drawing needs a public `overdrive: bool` set while it is above 0.

## How to test (`tools/tests/tier_ember_turret.gd`)
1. Incendiary: tier 2: after one shot the dummy keeps losing health for ~1.5 s; tier 1 just the hit.
2. Mortar: tier 3: a second dummy 33 px from the target loses health (outside the old 24 px); tier 2 not.
3. Fire shell: tier 4: the 5th shot makes a spell node with `data.id == "fireball"` and `copy == true`, tier = tier-2; shots 1-4 none.
4. Cluster: tier 5: dummies at 30 px around the target all take damage 0.3 s after a shot.
5. Inferno: tier 6: after 12 s `overdrive` is true for ~3 s and the shot count in that window is ~4x the normal; shots resume normal rate after.
6. Day/night: draw smoke at `night_level` 0 and 1.
