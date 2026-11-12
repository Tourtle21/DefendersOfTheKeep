# Card tiers 2 to 6: shared conventions (read this first, every card file refers to it)

Goal: every spell and building looks better, attacks flashier and gains a real ability at each tier 2 to 6, on top of
the stackable "added" modifiers that already exist (`Game.SPELL_TWISTS` / `BUILD_TWISTS`, applied in `Spell._apply_add`
and `Structure._apply_add`). The reference is Guards (`cards/guard.gd`): one look + one new move per tier, all kept.

## 1. Where the code goes (one place per concern, so 40 cards do not collide)

New files (the implementer creates them with the first card that needs them; each per-card function is independent):

| File | class_name | Holds |
|---|---|---|
| `cards/spell_art.gd` | `SpellArt` | `static func draw(s: Spell, since: float, col: Color)` dispatching on `s.data.id` to `draw_<card_id>(s, since, col)`; `draw_flight(s, t, col)` to `flight_<card_id>(s, t, col)` for the unlanded shot; helpers `jit`, `flame`, `crystal`, `flake` (below) |
| `cards/spell_tiers.gd` | `SpellTiers` | `static func on_land(s: Spell)` dispatching to `land_<card_id>(s, tier)`; `static func tick(s: Spell, delta: float)` to `tick_<card_id>(s, tier, delta)`; the constants of every spell ability |
| `cards/structure_art.gd` | `StructureArt` | `static func draw(st: Structure, col: Color) -> bool` dispatching on `st.data.id` to `draw_<card_id>(st, col)`; returns false when the id has no own drawing so the old per-kind drawing runs (partial rollout is safe) |
| `cards/structure_tiers.gd` | `StructureTiers` | `tick_<card_id>(st, delta)`, `on_shot_<card_id>(st, target)`, `on_promote_<card_id>(st, new_tier)`, `on_expire_<card_id>(st)`, `on_gnaw_<card_id>(st, enemy)` dispatchers and the constants of every building ability |

Hook points (written once, by whoever implements the first card; they all become no-ops for ids without a function):

- `cards/spell.gd`
  - `_physics_process`, in the `if !landed:` branch right after `_apply_twist()`: `SpellTiers.on_land(self)`.
  - at the end of the landed `match data.kind` block (just before `if age >= flight + effect_time`): `SpellTiers.tick(self, delta)`.
  - `setup()`: `effect_time` may be raised by a tier (`SpellTiers.effect_time(self)` returns the longer value or the old one).
  - `_draw()`: the unlanded branch calls `SpellArt.draw_flight(self, t, col)` after the old shot; the landed branch calls `SpellArt.draw(self, since, col)` after the old fill. The old fill and the old "one extra ring per tier" stay (they are a card-wide "added at tier" cue) but their alpha should be lowered by 30% when `SpellArt.has_body(id)` is true so new art is not drowned.
  - `_apply_twist()`: put `plain.copy = true` in the dict used for twin/echo copies. Copies still get tier art and tier ticks, but every ability marked FINALE in a card file must skip when `data.get("copy", false)`.
- `cards/structure.gd`
  - `_draw()`: replace the `match kind:` body by `if !StructureArt.draw(self, col): match kind: ...` (old code kept as fallback). `_draw_tier()` (progress bar, tier pips) and the tier-5 ring stay.
  - `_physics_process`: after the `match kind:` block add `StructureTiers.tick(self, delta)`.
  - sentry branch, right after the damage lines: `StructureTiers.on_shot(self, best)`; barricade gnaw loop: `StructureTiers.on_gnaw(self, e)`; `promote()`: `StructureTiers.on_promote(self, tier)`; `_expire()`: `StructureTiers.on_expire(self)`.
- `items/weapons/fx.gd`: add the new one-shot kinds in section 3 (all plain `draw_*`). Every card file only uses these kinds plus the old `ring / burst / arc / line`.

Dispatch is `match String(s.data.get("id", ""))`. A fused card has its own id and may call its parent's function with
different parameters (documented in its file). `data.id` is set by `Game.scaled`; `data.tier` (spells) is set by `Game.stats_of`;
structures use their `tier` var (`data.level` equals it).

## 2. Drawing rules (multiplayer-safe, cheap, readable)

- `_draw` runs every frame on clients as well, from synced vars only. Use `age`/`_age` (they tick locally on puppets) and
  `since = age - flight` for time; never `randf()` inside `_draw`.
- Deterministic randomness: `SpellArt.jit(i: int, salt := 0.0) -> float` = `fposmod(sin(i * 12.9898 + salt * 78.233) * 43758.5453, 1.0)`
  (0..1). Use it for particle angles/offsets so every machine draws the same picture. Particles move as a function of `since`
  (`p = fposmod(since * speed + jit(i), 1.0)` loops them).
- Budget: at most about 60 `draw_*` calls per spell/structure per frame (arcs with 24 to 40 points count as one). Fill alphas
  stay at or below 0.35 so enemies remain visible through a zone; outlines up to 0.9.
- Colour: take the card colour `col` (already gold-tinted by tier) and derive with `lightened/darkened/lerp`. Palette per card
  is given in the card file as hex-like `Color(r, g, b)` triples. Black 1px outlines on solid shapes (as `structure.gd` does).
- Tier cue cards already have: spells tint toward gold and get one more inner ring per tier; structures tint toward gold, show
  tier pips above, and from tier 5 a pulsing ring. Keep those; the new art sits on top.
- Night: fire cards that are `night` already create light (`LightSource.spawn`, `GlowLight`, group `light`). Higher tiers of those
  may use a bigger/longer `LightSource.spawn`; give the number in the card file.

## 3. New one-shot kinds for `WeaponFx` (added once in `items/weapons/fx.gd`)

All params are plain numbers/colours/vectors (so `Rep.ser_ok` mirrors them). New vars on WeaponFx: `count := 8`, `spin := 0.0`, `height := 40.0`, `rise := 30.0`, `rings := 3`. The old `radius/dir/length/width/life/half_angle` stay. `t = age / life`, `fade = 1 - t`.

| kind | params | look |
|---|---|---|
| `flash` | `radius` | a filled disc of `color` at alpha `0.7*fade^2`, radius `radius*(0.6+0.6*t)`, plus a white core disc `0.4*radius*fade`; the "boom" frame |
| `ripple` | `radius`, `rings` | `rings` expanding rings, each delayed by `0.18/rings*life`, radius `radius * u` where `u` is that ring's own 0..1 progress, alpha `0.9*(1-u)`, width 2 |
| `shards` | `radius`, `count`, `spin` | `count` thin triangles (length 6..10, tip outward) flying from the centre out to `radius`, starting angle `spin`, fading; the "ice/crystal/debris" burst |
| `pillar` | `height`, `width` | a vertical column rising from the point: polygon from `(-w/2,0)..(w/2,0)` to `(-w*0.3,-h)..(w*0.3,-h)` of `color` alpha `0.5*fade`, a white inner strip half as wide, and a flash disc at its base |
| `motes` | `radius`, `count`, `rise` | `count` small circles (r 1.5) starting inside `radius` and drifting up by `rise` px while fading, deterministic from index; healing leaves, embers, sparks, snow |
| `star` | `radius`, `count`, `spin` | an `count`-pointed star outline (alternating `radius` and `0.45*radius`) rotating by `spin*t`, alpha `0.9*fade`; blessing / holy / rune flashes |
| `fall` | `radius` (head size), `height` (default 90), `rise` (sideways offset, default 40) | an object falling to the point from `(-rise, -height)` to `(0,0)` over `life` (ease-in): bright head (circle r=`radius`, white core) with a 12-dot tail along the path, fading dots; then the matching impact is a separate `flash`/`ring`. Use with `life` equal to the telegraph delay |
| `bolt` | `dir`, `length`, `width` | a jagged lightning line from the point along `dir`: 7 segments with deterministic sideways offsets +-`length*0.08`, white core line over a `color` glow line, alpha `fade` |

Sounds: `Sfx.play` takes only existing names: `hit, big_hit, cast, ultimate, unlock, whoosh, thump, boss_roar, chest, coin, gong`. Use `cast` for small
tier-up casts, `big_hit` for impacts, `thump` for heavy slams, `ultimate` for tier 6 finales, `whoosh` for fast moves.

## 4. Numbers

- Stats already scale with tier (`Game.scaled`; power per tier `1.1*2^(t-1)`). Abilities are expressed as fractions of the card's own scaled
  stat (`data.damage`, `data.dps`, `data.heal_per_sec`, `data.hp`, `data.radius`, `data.duration`) so they scale for free.
  Where a card has no such stat (frost ring has no damage) the file gives a small per-tier table kept in `SpellTiers` / `StructureTiers`.
- Rule of thumb: all abilities of a tier together add at most +50% of the card's damage/healing output at tier 6 over what the
  stats alone give (the point is control, reach, shape and spectacle, not a second damage curve). A spell's tier-6 FINALE may add
  one burst of up to 100% of its damage once.
- Bosses: `Boss.apply_slow` never stuns and `push` is weak; code must always call `e.has_method("charm")`, `has_method("push")`
  etc. before using control effects, and treat `e.is_in_group("boss")` as immune to hard control (charm / stasis / conversion).
- Enemy lists: always use `WeaponUtil.enemies_in_circle(tree, pos, r)` (it includes critters and hit radii) or `s._in_radius("enemy")`.
- A kill check is `!is_instance_valid(e) or e.get("dead") == true or e.health <= 0.0` after the damage call.
- Every `await` / `create_timer` callback must start with `if !is_instance_valid(self): return` (the spell/structure may be freed).

## 5. Multiplayer checklist (the same for every card; each file only lists what is special)

1. No new node types: spells and structures are already group `net`. Extra world objects are `Hazard.new()` (via `WeaponUtil.patch`),
   `WeaponProjectile.shoot`, `LightSource.spawn`, `Guard` — all already replicated.
2. Host-only state in `_private` vars (`_pulses`, `_finale_done`, `_charges`). Anything that changes how the card is DRAWN must be a
   public var (so clients see it) or derivable from `tier`, `age`, `landed`, `hp`, `uses`, `adds`.
3. One-shot effects through `WeaponFx.spawn` / `Sfx.play` only (mirrored). Never call `Sfx`/`Fx` from `_draw`.
4. Clients never run `SpellTiers.on_land/tick` or `StructureTiers.tick/on_*`: they sit inside code paths that already stop on puppets
   (`_physics_process` is off on puppets). Do not add a new `_process` that mutates state.
5. After adding a new world object type run `tools/tests/net_coverage.gd`.

## 6. Test style (every card file lists 3 to 6 checks; the implementer turns them into `tools/tests/tier_<card_id>.gd`)

Copy the skeleton of `tools/tests/guards.gd`: `extends SceneTree`, `wait()`, `ok()` printing `PASS ...` / `FAIL ...`, `game = root.get_node("Game")`,
`game.save_path = "user://tier_<id>_save.json"`, `_menu_done = true`, instance `res://world/world.tscn`, stop `SpawnTimer`, park the player at (0, 600).
- Spell: `var d = game.stats_of(game.make_entry("<id>", t, game.twist_for("<id>", t)))`, then `var s = load("res://cards/spell.gd").new(); s.setup(d, pos, pos); world.add_child(s)`, `await wait(...)`.
  Dummy enemies: `load("res://enemies/blobbert/blobbert.tscn")` with `max_health = health = 99999.0` and `set_physics_process(false)` when they must stand still; damage dealt = `99999.0 - e.health`.
- Structure: `var st = load("res://cards/structure.gd").new(); st.setup(game.stats_of(game.make_entry(id, t, game.twist_for(id, t))), pos); world.add_child(st)`.
- Count effects by scanning `world.get_children()` for nodes whose `get_script().resource_path` ends with `fx.gd` and reading `.kind` (fx nodes live `life` seconds, so sample every 0.05 s and collect the set of kinds seen).
- Never name `Spell`, `Structure`, `SpellTiers` ... in the test file as a type (autoload-dependent): use `load("res://...").new()` and call statics through the loaded script object (`load("res://cards/spell_tiers.gd").land_x(...)` is fine).
- Each tier test also asserts "tier N keeps what tier N-1 had" (the earlier behaviour still fires) and "tier 1 does not have it".
- Draw smoke test: for every tier call `s.queue_redraw()` and `await wait(0.1)` while landed; the test fails if the engine logs a script error (the implementer watches the console output for `SCRIPT ERROR`).

## 7. File template used by every card file

`# <Name>` / `## Today (3 lines)` / `## Tier table` (ART, ATTACK/EFFECT visuals, ABILITY, Already added) / `## Rules for the implementer` / `## How to test`.
Tier 1 is the baseline and unchanged. Tier names are display flavour for the codex/tooltip only (optional: `Game.TIER_NAMES[id][tier]`), the code needs no names.

## 8. Shared helpers (write once in `spell_tiers.gd` / `structure_tiers.gd`, every card file may use them by name)

- `SpellTiers.deaths(s: Spell, reach := -1.0) -> Array`: positions (Vector2) of enemies that were inside `reach` (default `s.radius`) at the last call and have died since (invalid, `dead == true` or `health <= 0`). Keeps `s._seen` (Dictionary enemy -> last position, private). Call once per tick; enemies that merely walked out are dropped silently.
- `SpellTiers.random_enemies(s: Spell, n: int, reach := -1.0) -> Array`: up to `n` distinct random enemies inside `reach`.
- `SpellTiers.densest(s: Spell, reach: float, cluster := 30.0)`: the enemy within `reach` that has the most other enemies within `cluster` px (or null).
- `SpellTiers.pace(s, key: String, every: float, delta: float) -> bool`: private timer by key; true once per `every` seconds (`s._timers[key]`).
- `SpellTiers.near(tree, pos, r)`: `WeaponUtil.enemies_in_circle`.
- `StructureTiers.deaths(st, reach)`, `StructureTiers.pace(st, key, every, delta)`, `StructureTiers.nearest(st, reach, skip := null)`, `StructureTiers.enemies(st, reach)` — same semantics for structures (`st._timers`, `st._seen`).
- `SpellArt.heart(c: CanvasItem, p: Vector2, size: float, col: Color)`, `SpellArt.flake(c, p, r, col, branches := 2)`, `SpellArt.flame(c, base: Vector2, h: float, w: float, col: Color, phase: float)` (a teardrop polygon swaying with phase), `SpellArt.crystal(c, p, h, col)` (hex prism), `SpellArt.dashed_arc(c, centre, r, from, to, col, dashes)`, `SpellArt.jit(i, salt)`. Structures use the same `SpellArt` helpers (`SpellArt.flame(st, ...)`).
- Hazard patches: `WeaponUtil.patch(world, pos, kind, radius, colour, secs, factor)` with kind `slow` is harmless to players (only slows them via `Hazard.slow_at`); kind `burn` HURTS PLAYERS standing in it (30 damage per second). Only the existing `aftermath` addition makes burn patches; new abilities must use `slow`, ground strikes or projectiles instead.
- Per-enemy marks: use `e.set_meta("tier_xxx", value)` for temporary flags; if a flag changes an enemy rule (like a damage multiplier) the change is made once inside `enemy.gd` (`apply_traits`) and documented in the card file.

## 9. Structure primitives (written once in `cards/structure_tiers.gd`; building files reuse them by name)

Structure variables added to `cards/structure.gd` (all private/host-only unless said):
- `StructureTiers.guard_mult(st) -> float` (1.0 by default; per-card factors such as plating and auras multiply in; 0.0 while `_invuln > 0`) multiplies the gnaw damage a barricade takes: `hp -= (1.0 or 4.0) * StructureTiers.guard_mult(self)`; `_invuln := 0.0` seconds during which the barricade takes none (decremented in `_physics_process`).
- `_timers := {}` and `_seen := {}` for `pace` / `deaths`; `_thr := {}` for `threshold`; `_fx_t := 0.0`.
- PUBLIC (so clients can draw): `charge := 0.0` (0..1, an ability about to fire: telegraph glow), `aim := Vector2.ZERO` (direction of the last shot / turret facing, for drawing the barrel), `lit := false` (a flame/torch is burning), `fx_pulse := 0.0` (seconds since the last ability pulse, ticks up; the draw flashes while < 0.3). Put any other drawing state in these or derive it from `tier`, `hp`, `uses`, `_age`.

Helpers (static, first argument is the structure):
- `StructureTiers.enemies(st, r)` enemies within `r` (uses `WeaponUtil.enemies_in_circle`).
- `StructureTiers.pulse(st, r, dmg, push_speed, stun, col, elem := "")`: `WeaponFx.spawn(world, "ring", pos, col, {"radius": r, "life": 0.3})` + `shards` count 8, damages every enemy in `r` (`spell_damage(dmg, elem, true)`), pushes them away (`push(dir * push_speed, 0.15)`) and stuns (`apply_slow(0.0, stun)` when `stun > 0`), sets `st.fx_pulse = 0.0`.
- `StructureTiers.radial(st, n, dmg, col, speed := 170.0, life := 0.5)`: `n` `WeaponProjectile.shoot` evenly round the structure.
- `StructureTiers.bolt(st, target, dmg, col, elem := "")`: `WeaponFx.spawn(world, "bolt", pos, col, {"dir": to, "length": dist, "width": 3.0, "life": 0.18})` + damage.
- `StructureTiers.threshold(st, key, frac) -> bool`: true exactly once each time `hp` crosses below `frac * max_hp`; re-armed when `hp >= (frac + 0.1) * max_hp` (healing).
- `StructureTiers.slow_patch(st, r, secs, factor)`: `WeaponUtil.patch(world, pos, "slow", r, col, secs, factor)` (harmless to players).
- `StructureTiers.mend(st, r, per_sec, delta)`: heals guards and structures (`hp`) within `r`, never above `max_hp`.
- `StructureTiers.cast(st, card_id, r_scale := 1.0, tier_offset := 0)` (spell tier = `maxi(1, st.tier + tier_offset)`): casts a copy of a spell card at the structure: `Spell.cast_copy(world, d, pos)` with `d = Game.scaled(card_id, tier)` plus `copy = true`, `tier = st.tier`, `adds = []`, `twist = ""` and `d.radius *= r_scale`. Lets buildings borrow spell abilities (lava pool, frost ring...).
- Structure tier ladders always keep earlier abilities; `tier` is the structure's own tier (its `promote()` adds one).
- "Darkness": a sentry only fires at what it sees (`Game.defence_sees`); abilities that hit "all enemies in range" ignore the shroud unless the card file says otherwise.

## 10. Sentry-family hooks (turrets: sentry, ember_turret, crystal_pylon, storm_spire, venom_tower, prism_tower, sunspire and the fused spiked_sentry, beacon_turret)

All nine share `Structure`'s `"sentry"` branch. Three hooks are added there once (each dispatches on `data.id` and returns the neutral value for ids without a function):
- `StructureTiers.interval_mult(st) -> float` (default 1.0) multiplies the wait between shots: `if _tick >= data.get("interval", 0.7) * StructureTiers.interval_mult(self):`.
- `StructureTiers.shot_mult(st, target) -> float` (default 1.0) multiplies the damage of the direct hit: `best.spell_damage(data.damage * StructureTiers.shot_mult(self, best), ...)`.
- `StructureTiers.on_shot(st, target)` runs after the normal damage/slow/poison/twin/blast code; `shot_to`/`shot_t` are already set, `st.aim = (target.pos - st.pos).normalized()` is set by the shared code (PUBLIC `aim` var, so clients can draw barrels).
- The shared `_draw` line (`draw_line` for the shot) is replaced by each card's own `draw_<id>` which uses `shot_t`, `shot_to` (public already) and `aim`.
- A `_shots` counter (private int) counts shots per structure; "every Nth shot" abilities use it (`_shots % N == 0`).
- Targeting always respects `Game.defence_sees(e, global_position)` unless the card file says otherwise.
- Fused cards and the elemental sentries still get the generic additions from `BUILD_TWISTS.sentry` (twin_shot, frost_shot, rapid, heavy, blast_shot) in this order; abilities must not duplicate them.

## 11. Shared cross-card pieces (create once, whoever needs them first)

- `Game.mark_mult(e: Node) -> float` in `core/game.gd`: product of the active damage marks on an enemy (each is a meta holding a `Time.get_ticks_msec()/1000.0` deadline): `toxic_until` 1.2 (Poison Cloud), `brittle_until` 1.5 (Stasis), `marked_until` 1.4 (Sentry hunter's mark), `chilled_until` 1.25 (Frost Totem), plus any a later card file adds. `Enemy.apply_traits` multiplies the damage by it. Bosses ignore marks. Constants live in `Game.MARKS := {"toxic_until": 1.2, ...}` so numbers are in one place.
- Group `enemy_shot` on `EnemyProjectile` (`add_to_group("enemy_shot")` in its `_ready`), used by Aegis, Stasis, Iron Bulwark and others to catch/reflect shots.
- `StructureTiers.densest(st, reach, cluster := 30.0)` mirrors `SpellTiers.densest`.
- `StructureTiers.cast(st, card_id, r_scale)` as described in section 9; the copy it creates carries `copy = true` (no FINALE) and the structure's tier.
- Player hp fraction: `StructureTiers.hp_frac(p)`; heal to a fraction: `p.heal(delta_frac * 228.0 * Game.hp_scale())` (the bar is 228 wide; `Player.heal` divides by `hp_scale`).
- Tier-up flash: `Structure.promote()` already rings gold; each building may add its own reveal in `on_promote_<id>(st, new_tier)` (e.g. `star`), but must not change stats there.
