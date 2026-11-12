# Spiked Wall (`spiked_wall`, kind `build`/`barricade`, no element, FUSED barricade + spike_trap)

## Today
- A sturdy wall that bites back: `radius` 18, `hp` 45, `thorns` 3 (hurts every chewing enemy each 0.5 s). Stone-wood colour `Color(0.75,0.7,0.6)`, drawn with the generic barricade look plus spikes. Fixed twist `thorned` (kept).
- Adds (`BUILD_TWISTS.barricade`): t2 `thorned`, t3 `regrow`, t4 `tough`, t5 `thorns_plus`, t6 `last_stand`.
- Flavour: Spiked Wall = a wall of spikes: a spike strip, spear thrusts, impaling, spike volleys, a porcupine.
- Shares the barricade hooks (`on_gnaw`, `tick`, `guard_mult`) of `barricade.md`; abilities here are keyed on `data.id == "spiked_wall"` and are different from the wooden Barricade's.

Palette: stone-wood `Color(0.75,0.7,0.6)`, iron spike `Color(0.8,0.82,0.88)`, dark `Color(0.3,0.28,0.25)`, blood-rust `Color(0.6,0.25,0.2)`, gold tip `Color(1.0,0.85,0.4)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Spike Strip | A strip of iron spikes lies in front of the wall: 8 short upward-pointing triangles (height 5) along the bottom outside, and the wall face has two angled spike rows (diagonals); the face reads as stone-wood with iron bands. | Strip hit: `burst` radius 6 iron on enemies in the strip, throttled. | **Spike strip**: enemies within `radius + 20` of the wall (not just chewing) take `thorns * 0.4` piercing damage every 0.5 s and are slowed to 70% (`apply_slow(0.7, 0.6)`). | thorned |
| 3 Spear Thrust | Spear shafts hide in 3 slots in the wall face; when thrusting they slide out 14 px (animation from `fx_pulse`: out for 0.25 s), long iron heads, wood shafts; a pressure lever on the side. | Thrust: 3 `line` fx (iron, length 24, width 3, life 0.2) from the face in the aimed direction, `burst` radius 8 on contact; `Sfx.play("hit")`. | **Spear thrust**: every 2.0 s the wall thrusts spears at enemies in front (within `radius + 24`): `thorns * 2.0` piercing damage and a short knock (push 120). Needs at least one enemy in reach to fire. | regrow |
| 4 Impaler | The spikes become long curved lances angled outward (8 spears, length 12, rust-dark tips), hung with small trophies (3 tiny bone rectangles); rust stains on the face. | Impale: `pillar` height 24 width 6 iron at the victim + `shards` count 4 radius 14; `Sfx.play("big_hit")`. | **Impaler**: each gnaw tick has a 30% chance to impale the chewer: stunned 1.0 s, 4 ticks of bleed (`thorns * 0.3`). | tough |
| 5 Spike Volley | A launch rack on top: 5 short barrels/slots with spikes ready (5 triangles standing up in a fan), a spring coil drawn at the base. | Volley: 5 spikes flying in a fan toward the target (WeaponProjectile, iron), `Sfx.play("whoosh")`. | **Spike volley**: every 3.0 s it fires 5 spikes in a fan (+-0.3 rad) at the nearest visible enemy within 110 px: `thorns * 0.8` each, pierce 1. | thorns_plus |
| 6 Porcupine | The wall is bristling: 14 spikes of different lengths all over it and along the top (gold tips), glowing rune lines, a ring of 8 detached spike orbs at 1.5 x radius floating (gold). Below 50% hp the spikes extend (each +3 px) and glow red. | **Burst of spikes**: `shards` count 16 radius 60 iron, `ripple` radius 60 rings 2, `Sfx.play("big_hit")`. | **Porcupine**: below 50% hp its thorns double (`thorns *= 2` while below, restored when healed above 60%) and at 75%, 50% and 25% (`threshold`) it fires 16 spikes in a ring (`radial(st, 16, thorns * 1.0, iron)`). | last_stand |

## Rules for the implementer
- `tick_spiked_wall(st, delta)`: strip `pace "strip" 0.5` (`enemies(st, radius + 20)`); thrust `pace "thrust" 2.0` (hold when nobody in `radius + 24`); volley `pace "volley" 3.0` (nearest visible within 110); porcupine thresholds `p75`, `p50`, `p25` and the thorns doubling: apply by `data.thorns` multiply once on crossing (`_porc := false/true`), never compounding (store `_base_thorns`).
- `on_gnaw_spiked_wall(st, e)`: impale 30% (`randf()`; host only), skipped if `e` already stunned (`slow_mult == 0`).
- Spear thrust direction: toward the nearest enemy in reach (publish `aim`), `fx_pulse` public.
- Constants: `SWALL_STRIP := 0.4`, `SWALL_STRIP_SLOW := 0.7`, `SWALL_THRUST_T := 2.0`, `SWALL_THRUST := 2.0`, `SWALL_IMPALE := 0.3`, `SWALL_VOLLEY_T := 3.0`, `SWALL_VOLLEY := 0.8`.
- Draw: `StructureArt.draw_spiked_wall(st, col)`.
- Multiplayer: `aim`, `fx_pulse` public.

## How to test (`tools/tests/tier_spiked_wall.gd`)
1. Strip: tier 2: a dummy at `radius + 15` (not chewing) loses health and is slowed (`slow_mult <= 0.71`); tier 1 neither.
2. Thrust: tier 3: dummy in reach takes a `thorns*2` step every 2 s and is pushed; `line` fx seen.
3. Impale: tier 4: over 40 gnaw ticks about 30% (+-15%) impale events (`slow_mult == 0` samples with a stun of ~1 s).
4. Volley: tier 5: 5 `projectile.gd` nodes every 3 s toward a dummy at 100 px.
5. Porcupine: tier 6: `hp = 0.7 * max_hp` -> 16 projectiles; `hp = 0.45` -> thorns doubled and 16 more.
6. Cumulative.
