# Spiked Sentry (`spiked_sentry`, kind `build`/`sentry`, no element, FUSED spike_trap + sentry)

## Today
- A longer-range, tougher sentry whose shots splash: `range` 125, `damage` 2.4, default interval 0.7 s. Fixed twist `blast_shot` (kept: splash `0.8 x damage`). Instant shot line; generic sentry look.
- Adds (`BUILD_TWISTS.sentry`): t2 `twin_shot`, t3 `frost_shot`, t4 `rapid`, t5 `heavy`, t6 `blast_shot` (already fixed).
- Flavour: Spiked Sentry = spikes and caltrops: caltrop shots, a spike collar, barbed bolts, spike fields, a spooling gatling.

Palette: iron `Color(0.75,0.75,0.8)`, stone `Color(0.62,0.6,0.55)`, rust `Color(0.6,0.3,0.2)`, brass `Color(0.9,0.8,0.4)`, spike `Color(0.85,0.87,0.92)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Caltrop Shots | The head sits on a small spiked base: 6 short spikes (triangles, height 5) round the box; the barrel is a spiked tube (3 small triangles along it); a bag of caltrops on the side (circle r 3 with 4 tiny jacks sticking out). | Impact: `burst` radius 8 iron + 3 tiny jacks `motes` count 3 rise 4 at the target. `Sfx.play("hit")`. | **Caltrop shots**: each hit scatters caltrops under the target: a slow patch of radius 16 for 3 s (`slow_patch` at the target, factor 0.6; refreshed, at most 4 patches at once). | twin_shot |
| 3 Spike Collar | A full collar of 12 long iron spikes radiating out of the box (length 8, black outline, tips highlighted), turning very slowly; the tips glint. | Collar hit: `burst` radius 8 iron at each enemy hit; `ring` radius 30 at 0.3 s. | **Spike collar**: enemies within 30 px of the sentry take `damage * 0.8` piercing damage every 0.5 s and are pushed away (`push(dir*100, 0.12)`): rushers pay for reaching it. | frost_shot |
| 4 Barbed Bolts | The bolt is a barbed spear shown in the shot line (a `line` with 3 small barbs drawn at its end); the barrel has barb-shaped flanges; red rust stains. A bleeding enemy shows red drips (up to 8, drawn from the `bleed_pos` list). | Barb: `burst` radius 6 red-rust at the target; `Sfx.play("big_hit")`. | **Barbed bolts**: a hit enemy bleeds (`bleed` 4 ticks of `damage * 0.3`) and is pinned (`apply_slow(0.5, 2.0)`); a bolt hitting an already bleeding enemy deals +25% damage. | rapid |
| 5 Spike Field | A pressure ring of stone studs on the ground around the base (8 flat discs r 3 at 1.4 x radius, with tiny spike tips), the head has a drum magazine; every 6 s the studs raise slightly then fire (animation from `charge`). | Eruption: 3 spike strikes in a triangle under the densest group (like Crystal Spikes) with telegraph `ring` radius 14, `shards` count 6 iron; `Sfx.play("thump")`. | **Spike field**: every 6.0 s spikes erupt under the densest group in range: three `ground_strike`s (radius 14, delays 0.3/0.45/0.6, `damage * 3.0`, knock 100, stun 0.3) around it. | heavy |
| 6 Gatling | Barrel becomes a 3-barrel rotary gatling (three small tubes rotating around the axis: positions rotate by `spool * 12 * _age`), a brass drum, steam vents; the base is armoured with gold rivets. Spool bar: a small arc around the head filled by `charge`. | While spooled: continuous tracer lines (3 thin `line`s per shot, slightly spread), `ring` radius 14 muzzle flash each 3rd shot; `Sfx.play("hit")` rapid. | **Spool-up**: each consecutive shot at targets in range builds the spool (0..1 over 5 shots); at full spool the sentry fires 3 spikes per shot (each `damage * 0.5`, fan +-0.12) and 50% faster (`interval_mult` 0.5); the spool decays after 2 s without a target. | blast_shot |

## Rules for the implementer
- Hooks section 10: `on_shot`: caltrop patch (`_patches` list of patches ids, remove invalid; cap 4), barbed (bleed + pin; `shot_mult` 1.25 when the target is bleeding: track `_bleeding := {}` enemy -> time), spool (`_spool` 0..1 float, `+= 0.2` per shot, `-= delta*0.5` when idle > 2 s) with `interval_mult` 0.5 at `_spool >= 1.0`; extra spikes through `WeaponProjectile.shoot`.
- `tick_spiked_sentry(st, delta)`: collar `pace "collar" 0.5` -> `enemies(st, 30.0)` (tier >= 3); field `pace "field" 6.0` -> three `ground_strike` around `densest` (tier >= 5). Publish `charge = _spool` (tier 6) or `timer/6` (tier 5).
- Constants: `SSENT_CALTROP_R := 16.0`, `SSENT_COLLAR := 0.8`, `SSENT_COLLAR_R := 30.0`, `SSENT_BARB := 0.3`, `SSENT_FIELD_T := 6.0`, `SSENT_FIELD := 3.0`, `SSENT_SPOOL_SHOTS := 5`.
- Draw: `StructureArt.draw_spiked_sentry(st, col)`; bleeding enemies' drips via public `bleed_pos`.
- Multiplayer: `charge`, `aim`, `bleed_pos` public.

## How to test (`tools/tests/tier_spiked_sentry.gd`)
1. Caltrops: tier 2: after a shot a `slow` hazard with radius 16 exists at the dummy; tier 1 none.
2. Collar: tier 3: a dummy at 25 px (outside shot priority? place a second far dummy to keep shots going) loses health and is pushed; tier 2 not.
3. Barbed: tier 4: dummy bleeds (loses health between shots) and has `slow_mult <= 0.51`; the second shot deals ~1.25x.
4. Field: tier 5: three `ring` fx radius 14 within 6.3 s and 3x damage on a dummy cluster.
5. Gatling: tier 6: after 5 shots the shot rate doubles and 3 `projectile.gd` nodes per shot appear; 3 s idle returns to normal.
6. Cumulative.
