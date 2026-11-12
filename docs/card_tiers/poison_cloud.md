# Poison Cloud (`poison_cloud`, kind `zone`, element poison)

## Today
- A green zone of `radius` 62 (the widest of the four zones) for 8 s: slow 0.7, `dps` 3.0 per second (ticks 0.5 s). Flat green disc with rim.
- Adds already (zone pool): t2 `wide`, t3 `aftermath`, t4 `lingers`, t5 `echo`, t6 `shrapnel`.
- Flavour: gas, spores, infection that spreads from enemy to enemy.

Palette: toxic `Color(0.5,0.9,0.3)`, deep `Color(0.2,0.45,0.15)`, spore `Color(0.8,1.0,0.5)`, purple rot `Color(0.55,0.3,0.6)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Weakening Toxin | Drifting wisps: 6 curling smoke strands (3-point polylines, width 3, alpha 0.25) rotating slowly at 0.3..0.8 r; 16 spore dots (r 1.5, spore colour) floating up and out (`fposmod(since*0.3 + jit(i),1)`), a skull-free hazard glyph: a small three-blade trefoil at the centre (3 arcs 100 degrees, radius 7, rotating slowly). | Afflicted enemies show a green `burst` radius 6 when first marked. | **Weakening toxin**: enemies inside are weakened: they take +20% damage from every source (`e.set_meta("toxic_until", now + 1.0)` refreshed each tick; `Enemy.apply_traits` multiplies by 1.2 while the meta is in the future). Works for the whole team's damage. | wide |
| 3 Infection | Faint thread lines between neighbouring infected enemies are drawn as `line` fx (see below); the cloud gets a dirty purple second layer: inner disc 0.65 r in purple rot alpha 0.12; the trefoil becomes a biohazard-like ring of 3 circles. | Each spread: `line` green width 2 life 0.25 from carrier to victim, `burst` radius 8. | **Infection**: an enemy that has stood in the cloud for 1.5 s becomes a carrier for 5 s (`_carriers` enemy -> time left): it poisons every other enemy within 34 px for `dps * 0.5` per second (ticks 0.5 s, aoe) wherever it walks, even outside the cloud. | aftermath |
| 4 Choking Fumes | Thicker cloud: 7 soft circles (r 10..18, alpha 0.14) rolling through, a darker ring at the rim (second arc 0.95 r, deep green), droplets rise. A cough marker: small `!`-free green puff above the victim. | Cough: `burst` radius 12 spore + `motes` count 6 rise 14; `Sfx.play("hit")`. | **Choking fumes**: every 2.0 s one random enemy inside coughs: stunned 0.8 s (`apply_slow(0, 0.8)`) and takes `dps * 2`. | lingers |
| 5 Spore Pods | Mushrooms: 3 spore pods grow at fixed spots (0.35 r, angles from `jit`): stalk rect + cap semi-circle polygon (deep green cap with spore-coloured dots), swelling over 2.5 s then bursting into a puff, replaced by a new one growing (cycle 2.5 s, offset per pod). The cloud has a green aura glow. | Burst: `ripple` radius 28 rings 2 spore, `motes` count 10 rise 24, `Sfx.play("thump")`. | **Spore pods**: three pods ripen in turn (every 2.5 s one bursts): everything within 28 px of the pod takes `dps * 4`, is poisoned (`WeaponUtil.bleed(tree, e, 4, dps * 0.4)`) and is shoved outward `push(90)`. | echo |
| 6 Plague | A rolling plague cloud: spore swarm doubles (32 dots), plague-lights (6 purple glows flickering), green/purple gradient fill with a dashed outer ring; at the centre a large rotating three-armed biohazard sigil (3 thick arcs radius 14 + 3 circles). | **Finale**: `flash` radius 1.3 r spore, `ripple` radius 1.5 r rings 3, `motes` count 20 radius 1.2 r rise 40, `Sfx.play("ultimate")`. Plague deaths: `burst` radius 16 and a mini cloud. | **Plague (FINALE)**: when the cloud ends every enemy within 1.3 r is plagued for 6 s: `bleed` 8 ticks of `dps * 0.5`, and a plagued enemy that dies releases a small poison cloud (a `copy` cast of this card: radius 0.45 r, 3 s, `Spell.cast_copy(world, small, pos)`) at most 6 per cast. Skipped when `data.copy` (and the little clouds are copies so they cannot plague again). | shrapnel |

## Rules for the implementer
- `enemies/enemy.gd`, `apply_traits()`: right after the `slow_mult` line add `if has_meta("toxic_until") and get_meta("toxic_until") > Time.get_ticks_msec() / 1000.0: a *= 1.2`. Constant `TOXIC_BONUS := 1.2` in `SpellTiers`; the multiplier is read in enemy.gd through `Game.TOXIC_BONUS` (add the const to `core/game.gd`) so there is one source. Bosses ignore it (their `spell_damage` does not call `apply_traits`).
- `SpellTiers.tick_poison_cloud(s, tier, delta)` after the base zone tick. Private: `_time_in := {}`, `_carriers := {}`, `_plagued := {}` (enemy -> true), `_plague_clouds := 0`, `_finale_done`.
- Infection tick every 0.5 s: for each carrier still valid, `WeaponUtil.enemies_in_circle(tree, carrier.global_position, 34)` minus the carrier, damage `dps * 0.25` (that is `dps * 0.5` per second), `element "poison"`, aoe true.
- Pods: pod i bursts when `fposmod(since - i * (2.5 / 3.0), 2.5) < delta` after the first full 2.5 s; use `pace(s, "pod" + str(i), 2.5)` with a start offset. Pod positions `Vector2.from_angle(jit(i, 5.0) * TAU) * radius * 0.35`. Drawing: growth `g = fposmod(since - i * 0.83, 2.5) / 2.5`, same formula on host and client.
- Plague death tracking: keep `_plagued` enemies; use `SpellTiers.deaths` variant over the plagued list (they may be outside the cloud): iterate the list each tick and detect invalid/dead. The small cloud dict: `var small = data.duplicate(); small.radius = radius * 0.45; small.duration = 3.0; small.copy = true; small.adds = []; small.twist = ""`. The small clouds spawn into `get_parent()`.
- Finale at `since >= effect_time - 0.05`.
- Constants: `POISON_INFECT_T := 1.5`, `POISON_CARRIER_T := 5.0`, `POISON_CARRIER_R := 34.0`, `POISON_COUGH := 2.0`, `POISON_POD := 2.5`, `POISON_PLAGUE_MAX := 6`.
- Multiplayer: pods derive from `since`; weakness is host-only meta (the damage is computed on the host).

## How to test (`tools/tests/tier_poison_cloud.gd`)
1. Toxin: tier 2 dummy inside: 10 damage dealt via `spell_damage(10)` from outside the spell loses >= 11.9 health; at tier 1 exactly 10.
2. Infection: tier 3, dummy A inside, dummy B 25 px away but outside the cloud (cloud centre far): after 2 s B has lost health; at tier 2 not.
3. Choking: tier 4: over 5 s at least one sample with `slow_mult == 0` for a lone dummy; tier 3 none.
4. Pods: tier 5: `ring` fx of life ~0.25.. count >= 3 in 6 s; a dummy at pod position takes >= `dps*4`.
5. Plague: tier 6 end: dummy within 1.3 r bleeds 8 ticks; kill it: a new spell node with `data.copy == true` and radius ~0.45 r exists; copy cast never plagues.
6. Draw smoke at all tiers.
