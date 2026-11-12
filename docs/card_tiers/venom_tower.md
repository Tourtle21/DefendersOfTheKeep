# Venom Tower (`venom_tower`, kind `build`/`sentry`, element poison)

## Today
- Poison sentry: `range` 115, `damage` 1.0, `interval` 0.8, `poison` 4.0: each shot hurts and poisons (`bleed` 4 ticks of `poison * 0.25`). Generic sentry look in green.
- Adds already (`BUILD_TWISTS.sentry`): t2 `twin_shot`, t3 `frost_shot`, t4 `rapid`, t5 `heavy`, t6 `blast_shot`.
- Flavour: Venom Tower = disease: stacking toxin, spore pods, acid, contagion, a plague cloud.

Palette: venom `Color(0.55,0.9,0.25)` (card colour), deep `Color(0.2,0.45,0.15)`, spore `Color(0.8,1.0,0.5)`, rot `Color(0.55,0.3,0.6)`, bone `Color(0.9,0.88,0.75)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Toxin Stacks | A bulbous tank on the tower (circle r 6 deep green with a glass highlight and bubbling dots rising in it), a fang-shaped nozzle (small triangle pointing to `aim`), a hose line from tank to nozzle. | Venom dart: `line` (green, width 2) + `burst` radius 8 spore; stack markers: 1..5 green pips drawn over the target's position (from `stack_pos`, see rules). `Sfx.play("hit")`. | **Toxin stacks**: every hit adds a stack (max 5, 6 s) to the target; the poison damage per tick is `poison * 0.25 * (1 + 0.3 * stacks)`, so a focused enemy melts. | twin_shot |
| 3 Spore Pods | Mushroom pods sprout round the base (3 small caps with spots, spore dots floating up), the tank is bigger with a purple-green swirl. | Pod burst on death: `ripple` radius 30 rings 2 spore, `motes` count 10 rise 24; a small cloud appears. `Sfx.play("thump")`. | **Spore pods**: a poisoned enemy that dies within range releases a small poison cloud (`cast(st, "poison_cloud", 0.45, -2)` copy at its last position, 3 s). At most 1 per second. | frost_shot |
| 4 Acid Spit | The nozzle is a double barrel; acid drips on the ground around the base (4 small green puddle circles, alpha 0.3), the hose is ribbed; a drip animation under the nozzle. | Acid glob: a slow green `WeaponProjectile` (speed 140) arc landing with `ring` radius 22 acid + `burst` radius 14; `Sfx.play("cast")`. | **Acid spit**: every 4.0 s it lobs an acid glob at the densest group in range: `ground_strike(radius 22, delay 0.5, damage * 3.0, knock 40, venom, 0.0, [], "poison")` and leaves a slow patch (`slow_patch(st at target, 22, 5.0, 0.6)`, harmless to players). | rapid |
| 5 Contagion | Thin green threads (alpha 0.3) join poisoned enemies to each other (drawn from the `stack_pos` list), the tank glows sickly purple-green, the tower has a bone-white fang ring around the top. | Spread: `line` green from carrier to victim, `burst` radius 8; `Sfx.play("whoosh")` throttled. | **Contagion**: every 1.0 s each enemy with 2 or more stacks poisons ONE other enemy within 35 px (gives it 1 stack and the poison dot). | heavy |
| 6 Plague Spire | The tower grows crooked and tall: a swollen tank (r 8) pulsing with rot purple, cracks leaking spore dots, 3 hanging pods, a halo of spores (12 dots orbiting at 22 px), the base wreathed in a mist disc alpha 0.1. | **Plague cloud** cast: `flash` radius 40 spore, `ripple` rings 3, `Sfx.play("ultimate")` quiet. | **Plague spire**: every 15.0 s it vomits a Poison Cloud on the densest group in range (`cast(st, "poison_cloud", 0.9, -1)` at that enemy, a cloud one tier below the tower with the cloud's own tier abilities). | blast_shot |

## Rules for the implementer
- Hooks section 10: `on_shot`: stacks (`_stacks := {}` enemy -> [n, time left]); additional bleed on top: `bleed(tree, e, 4, poison * 0.25 * 0.3 * n)` (extra DoT proportional to stacks) rather than touching the base bleed. `tick_venom_tower(st, delta)`: deaths among poisoned enemies (`StructureTiers.deaths(st, data.range)`, only those that were in `_stacks`), acid `pace "acid" 4.0` (`densest(st, data.range)`), contagion `pace "spread" 1.0`, plague `pace "plague" 15.0`. Public `stack_pos: Array` of `[Vector2, n]` entries (max 8) for the drawn pips/threads.
- Spore cloud and plague cloud use `StructureTiers.cast`, so they respect the poison cloud's own implementation (tier abilities included). Spore pods use `tier_offset -2`.
- Constants: `VENOM_STACKS := 5`, `VENOM_STACK_BONUS := 0.3`, `VENOM_ACID_T := 4.0`, `VENOM_ACID := 3.0`, `VENOM_SPREAD_R := 35.0`, `VENOM_PLAGUE_T := 15.0`.
- Draw: `StructureArt.draw_venom_tower(st, col)`.
- Multiplayer: `stack_pos`, `aim` public.

## How to test (`tools/tests/tier_venom_tower.gd`)
1. Stacks: tier 2: 5 shots on one dummy: total damage over 5 s noticeably higher than tier 1 (>= +40%).
2. Pods: tier 3: dummy with health 3 poisoned dies in range: a spell with `data.id == "poison_cloud"` and `copy == true` appears; tier 2 none.
3. Acid: tier 4 cluster of 3 dummies: `ring` fx radius 22 within 4.2 s, a `slow` hazard exists, all three hurt.
4. Contagion: tier 5: dummy B 30 px from poisoned A (2 stacks) gets health loss without being shot (target A only: B is out of the nearest-first rule? make B farther than A from tower).
5. Plague: tier 6: within 15.2 s a poison cloud spell node appears at the cluster.
6. Cumulative.
