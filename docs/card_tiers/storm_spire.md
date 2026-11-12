# Storm Spire (`storm_spire`, kind `build`/`sentry`, element ice)

## Today
- Iron-and-frost sentry: `range` 130, `damage` 1.8, `interval` 0.5, `slow` 0.45: each bolt hits the nearest enemy and chills it (`apply_slow(0.45, 1.2)`). Shot is a pale instant line; generic sentry look in pale blue.
- Adds already (`BUILD_TWISTS.sentry`): t2 `twin_shot`, t3 `frost_shot` (already has slow, no change), t4 `rapid`, t5 `heavy`, t6 `blast_shot`.
- Flavour: Storm Spire = lightning: chain arcs, charged enemies, thunderclaps, skybolts, a tempest.

Palette: frost-blue `Color(0.7,0.85,1.0)` (card colour), bolt white `Color(0.95,0.97,1.0)`, storm `Color(0.35,0.45,0.75)`, spark yellow `Color(1.0,0.95,0.6)`, iron `Color(0.45,0.5,0.6)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Static | The head is a tall iron spire (triangle 6 wide, 16 high, iron with a lighter edge) topped by a glowing ball (r 3 white-blue); small static sparks (3 tiny `bolt`-like zig-zags, 4 px) crawl up the spire at random (`jit`, from `_age`). | The shot becomes a jagged `bolt` (`WeaponFx` kind `bolt`, width 3) from the spire tip to the target; chain arc `bolt` to the next. `Sfx.play("hit")`. | **Static chain**: each bolt jumps to the nearest other enemy within 45 px of the target for 50% damage (`bolt` between them); the second target is chilled too. | twin_shot |
| 3 Conductor | Two copper rings (arcs r 5 and 7 around the spire) and a lightning rod fin; a charge glow on the ball that pulses faster as charged enemies exist (public `charge` = fraction of enemies in range that are charged, 0..1). | Charged enemies carry a small yellow-white spark above them (drawn from the spire for up to 8 enemies: positions of the charged list); detonation `burst` radius 22 white + `ring` radius 30. `Sfx.play("big_hit")`. | **Conductor**: every hit charges the target for 2.5 s; a bolt that hits an already charged enemy discharges it: an explosion of radius 30 for `damage * 1.5` to everything around it and the charge ends. | frost_shot |
| 4 Thunderclap | A storm cloud hovers above the spire (3 overlapping dark soft circles r 8..12, alpha 0.35, sliding), the ball is brighter, a ring of 4 insulator discs on the base. | Thunderclap: `flash` radius 70 white-blue (0.2 s), `ripple` radius 70 rings 2, `bolt` x3 from the cloud to enemies hit; `Sfx.play("thump")`. | **Thunderclap**: every 6.0 s the spire cracks: everything within 70 px is hurt for `damage * 3.0` and stunned 0.5 s. | rapid |
| 5 Lightning Rod | Cables run from the spire to 4 stub rods on the ground (short lines + small rod caps at 1.8 x radius) that crackle; the cloud is larger and flickers white at each skybolt. | Skybolt: a long vertical `bolt` (length 120, from above) hitting the target, `flash` radius 26, `ring` radius 26; `Sfx.play("big_hit")`. | **Skybolt**: every 3.0 s lightning falls from the sky on a random enemy in range for `damage * 4.0` (+ stun 0.3); it always prefers the highest-health visible enemy. | heavy |
| 6 Tempest | A permanent small storm: swirling cloud ring (8 soft circles rotating around the spire at r 22), rain lines (14 falling lines, pale blue, `since`-based), the ball is a white-hot orb with 6 electric arcs (zig-zag lines) flickering around it, a faint dashed range ring. | Chain jumps up to 4: `bolt` per jump; the gale: `ripple` rings 1 every 2 s, `Sfx.play("whoosh")` throttled. | **Tempest**: bolts chain up to 4 times (each jump 50%, within 45 px of the last victim); and a gale slows every enemy in range to 70% (`apply_slow(0.7, 0.3)` each frame inside `range`). | blast_shot |

## Rules for the implementer
- Hooks per section 10: `on_shot`: static chain (nearest enemy to target within 45 px, not the target nor the twin_shot second target), conductor (`_charged := {}` enemy -> time left; discharge when hit again), skybolt `pace(st, "sky", 3.0)`, thunderclap `pace(st, "clap", 6.0)`. Tempest: chain loop up to 4 and a per-frame gale in `tick_storm_spire`.
- A discharge never triggers another discharge (set a flag while exploding).
- Keep all lightning damage `element ""` (ice only for the existing chill).
- `charge` for the conductor glow: compute from `_charged.size()` and enemies in range.
- Public `charged_pos: Array` (up to 8 Vector2) so clients can draw the sparks above charged enemies.
- Constants: `SPIRE_CHAIN := 0.5`, `SPIRE_CHAIN_R := 45.0`, `SPIRE_CHARGE_T := 2.5`, `SPIRE_DISCHARGE := 1.5`, `SPIRE_CLAP_T := 6.0`, `SPIRE_CLAP := 3.0`, `SPIRE_SKY_T := 3.0`, `SPIRE_SKY := 4.0`, `SPIRE_GALE := 0.7`.
- Draw: `StructureArt.draw_storm_spire(st, col)`.
- Multiplayer: bolts are `WeaponFx` events; `charged_pos`, `charge` public.

## How to test (`tools/tests/tier_storm_spire.gd`)
1. Chain: tier 2 dummies A (nearest) and B 35 px from A: B loses health with each shot and is slowed; tier 1 no.
2. Conductor: tier 3: the second shot at the same target triggers a `ring` fx radius 30 and a dummy 20 px away is hurt >= 1.5 x damage.
3. Clap: tier 4: after ~6 s a `flash` fx and all dummies within 70 px stunned (`slow_mult == 0`).
4. Skybolt: tier 5: a `bolt` fx of length ~120 within 3.2 s and a dummy hit for >= 4 x damage.
5. Tempest: tier 6: a dummy anywhere in range has `slow_mult <= 0.71`; a line of 5 dummies 30 px apart: one shot hits at least 4 of them.
6. Cumulative.
