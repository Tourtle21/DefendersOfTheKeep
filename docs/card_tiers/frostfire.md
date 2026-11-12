# Frostfire (`frostfire`, kind `fireball`, element fire, night, FUSED fireball + frost_ring)

## Today
- A Fireball variant: `radius` 55, `damage` 7.5, mana 35, pale blue colour `Color(0.7,0.85,1.0)`; same flight and blast code as the Fireball (`spell.gd` kind `fireball`). Fixed twist `aftermath` (kept) so it always leaves a patch (fire element -> a burn patch that also burns players, existing behaviour).
- Adds from the fireball pool: t2 `wide`, t3 `twin`, t4 `aftermath` (already fixed), t5 `burn`, t6 `shrapnel`.
- It does NOT use the Fireball card's tier abilities (`fireball.md`: concussion, bullseye...). It has its own ice-and-fire ones below, but shares the same code hooks (`land_frostfire` in `SpellTiers`, `draw_frostfire` in `SpellArt`; the common blast loop helper `SpellTiers.blast_fireball(s, tier)` takes the card id and applies only that id's abilities).

Palette: ice `Color(0.7,0.85,1.0)` (card colour), fire `Color(1.0,0.5,0.15)`, steam `Color(0.9,0.93,1.0)`, violet blend `Color(0.75,0.6,1.0)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Thermal Shock | Flight: the shot is two intertwined orbs (an ice orb and a flame orb of r 3.5 spiralling round each other, 6 px apart, with a blue and an orange trail). Landing disc: left half blue, right half orange (two half-disc fills split by a wavy line), a steam wisp (3 white arcs) rising at the seam. | `ring` radius r blue, `burst` radius 0.7 r orange, `Sfx.play("big_hit")`. | **Thermal shock**: the blast chills everything it hits (`apply_slow(0.5, 2.0)`), and enemies that were ALREADY slowed when it hit (slow_mult < 1) take +30% damage (the contrast cracks them). | wide |
| 3 Frost and Flame | The two orbs gain long spiral tails; when landing, 8 small glyphs (4 snowflakes, 4 flames) orbit the disc edge alternating (angular speed 1 rad/s). | 8 projectiles fly out in alternating colours: ice bolts (blue, slow 0.6 for 1.5 s, see rules) and flame bolts (orange, `bleed`). `Sfx.play("whoosh")`. | **Frost and flame bolts**: the blast throws 8 bolts outward at equal angles, alternately ice and fire, each `damage * 0.3`; ice bolts chill, fire bolts burn (3 ticks of `damage * 0.1`). | twin |
| 4 Steam | A steam cloud: 8 soft white circles (r 8..14, alpha 0.18) rolling over the disc for 3 s, condensation droplets; a thin ring of frost crystals at the left half and embers at the right half. | The steam: `ripple` radius r rings 2 steam colour, `motes` count 12 rise 20 white; `Sfx.play("whoosh")`. | **Thermal fracture**: every enemy in the blast is marked fractured for 4 s: they take +25% damage from every source (`chilled_until` mark of `Game.mark_mult`, 1.25), and a steam patch slows (`WeaponUtil.patch(world, pos, "slow", r * 0.9, steam, 4.0, 0.6)`). | aftermath |
| 5 Helix | Two spirals (a blue and an orange arc, 270 degrees each, radius 0.5 r and 0.8 r) wind around the disc rotating opposite ways for 1.2 s; the disc centre shows a yin-yang-like swirl of the two colours. | After 0.4 s a **frost wave**: `ripple` radius 1.3 r blue; after 0.8 s a **fire wave**: `ripple` radius 1.3 r orange, `flash` radius r; `Sfx.play("big_hit")` each. | **Helix**: two extra waves follow the blast, radius 1.3 r: first frost (stun 0.6 s, `damage * 0.4`), then fire (`damage * 0.6` and knockback 120). `effect_time` is 1.2 s. | burn |
| 6 Frostfire Nova | The impact is a binary star: a blue and an orange sun orbiting each other (r 7 each, 12 px apart) over the landing for 1.6 s, with 16 rays in both colours, a violet halo; the flight leaves a long dual-colour comet tail. | **Finale**: `flash` radius 1.5 r violet-white, `ripple` radius 2.2 r rings 4 (alternating colours), `shards` count 16 blue + `shards` count 16 orange, `Sfx.play("ultimate")`; `LightSource` radius 2.5 r 4 s. | **Nova (FINALE)**: a cold-hot supernova: everything within 2.0 r is frozen 1.0 s, set ablaze (`bleed` 5 ticks of `damage * 0.15`), knocked outward (push 220) and takes `damage * 1.0`. Skipped when `data.copy`. | shrapnel |

## Rules for the implementer
- `SpellTiers.land_frostfire(s, tier)`; the damage loop in `spell.gd` for kind `fireball` calls `SpellTiers.blast_fireball(s, tier)` (see `fireball.md`): for id `frostfire` it applies thermal shock instead of concussion/bullseye. Order inside the loop: read `slowed := e.slow_mult < 1.0` BEFORE applying this spell's chill, multiply damage by 1.3 if slowed, then damage, then `apply_slow(0.5, 2.0)`.
- Bolts: `WeaponProjectile.shoot(world, pos, Vector2.from_angle(k * TAU / 8), 170.0, dmg, colour, 0.5, 0, 60.0, extra)`; ice bolts chill: `WeaponProjectile` has no chill field, so spawn ice bolts with `bleed_ticks = 0` and apply the chill via a tiny follow-up: simplest is to give `WeaponProjectile` an optional `slow_mult := 1.0` / `slow_secs := 0.0` pair (2 lines in `_physics_process` after the hit: `if slow_secs > 0.0: e.apply_slow(slow_mult, slow_secs)`), used through `extra = {"slow_mult": 0.6, "slow_secs": 1.5}`; fire bolts use the existing `bleed_ticks`/`bleed_dmg` fields.
- Helix waves: `tick_frostfire` with `_wave := 0` and thresholds on `since` (0.4, 0.8); `effect_time = 1.2` for tier >= 5 (`SpellTiers.effect_time`). Stun via `apply_slow(0.0, 0.6)`.
- Steam patch uses `slow` kind (harmless to players). The fixed `aftermath` still adds its own burn patch (existing).
- Constants: `FF_SHOCK := 1.3`, `FF_CHILL := 0.5`, `FF_BOLT := 0.3`, `FF_FRACTURE_T := 4.0`, `FF_HELIX := [0.4, 0.6]`, `FF_NOVA_R := 2.0`.
- Multiplayer: nothing special.

## How to test (`tools/tests/tier_frostfire.gd`)
1. Shock: tier 2: an already slowed dummy (`apply_slow(0.5, 5)`) takes ~1.3 x the damage of a normal one; both are `slow_mult <= 0.51` afterwards; tier 1 chills nobody.
2. Bolts: tier 3: 8 `projectile.gd` nodes right after landing; those with colour blue and orange alternate; a hit ice-bolt dummy is slowed.
3. Fracture: tier 4: `spell_damage(10)` on a hit dummy loses 12.5; a `slow` hazard exists.
4. Helix: tier 5: fx scan sees two `ripple` fx with radius ~1.3 r at about 0.4 and 0.8 s; a dummy at 1.2 r is stunned then hurt.
5. Nova: tier 6: `flash` fx and a dummy at 1.8 r frozen + bleeding; `copy = true` skips it.
6. Draw smoke.
