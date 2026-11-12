extends RefCounted
class_name StructureTiers
## What a building does at each tier (2 to 6), on top of the stacking "added" modifiers (Game.BUILD_TWISTS, Structure._apply_add).
## Structure calls the hooks below; each card is a few functions named <hook>_<card id>. Everything here runs on the host
## (a puppet structure never reaches it); visuals go through WeaponFx.spawn and Sfx.play, which are mirrored to clients.
## Designs: docs/card_tiers/<card id>.md, shared rules: docs/card_tiers/_CONVENTIONS.md

# ---------------------------------------------------------------- shared helpers

## The towers, walls and healers of cards/structure_tiers_c.gd (Crystal Pylon ... Phoenix Shrine) live in their own file.
const C = preload("res://cards/structure_tiers_c.gd")

static func _dead(e) -> bool:
	return !is_instance_valid(e) or e.get("dead") == true or float(e.get("health") if e.get("health") != null else 1.0) <= 0.0

static func _boss(e) -> bool:
	return is_instance_valid(e) and e.is_in_group("boss")

static func world_of(st) -> Node:
	return st.get_parent()

static func id_of(st) -> String:
	return String(st.data.get("id", ""))

## Enemies within `r` of the structure.
static func enemies(st, r: float) -> Array:
	return WeaponUtil.enemies_in_circle(st.get_tree(), st.global_position, r)

static func enemies_at(st, pos: Vector2, r: float) -> Array:
	return WeaponUtil.enemies_in_circle(st.get_tree(), pos, r)

## A slow that does not undo a stronger, longer one already on the enemy (a stun from a tier ability survives the steady chill).
static func keep_slow(e, mult: float, secs: float) -> void:
	if is_instance_valid(e) and e.has_method("apply_slow"):
		SpellTiers.keep_slow(e, mult, secs)

## The nearest enemy within `reach` that the building can see (night shroud), skipping `skip`.
static func nearest(st, reach: float, skip = null):
	var best = null
	var bd := INF
	for e in enemies(st, reach):
		if e == skip or !Game.defence_sees(e, st.global_position):
			continue
		var d: float = e.global_position.distance_to(st.global_position)
		if d < bd:
			bd = d
			best = e
	return best

## The enemy within `reach` with the most other enemies within `cluster` px (or null).
static func densest(st, reach: float, cluster := 30.0):
	var best = null
	var most := 0
	var near := enemies(st, reach)
	for a in near:
		var n := 0
		for b in near:
			if a.global_position.distance_to(b.global_position) <= cluster:
				n += 1
		if n > most:
			most = n
			best = a
	return best

## A named repeating clock on the structure: true once every `every` seconds.
static func pace(st, key: String, every: float, delta: float) -> bool:
	var t: float = float(st._timers.get(key, 0.0)) + delta
	if t >= every:
		st._timers[key] = t - every
		return true
	st._timers[key] = t
	return false

## Like `pace`, but the clock waits at full until `reset` is called (an ability that needs a victim does not waste its timer).
static func ready(st, key: String, every: float, delta: float) -> bool:
	var t: float = minf(every, float(st._timers.get(key, 0.0)) + delta)
	st._timers[key] = t
	return t >= every

static func reset(st, key: String) -> void:
	st._timers[key] = 0.0

## How far a clock has come (0..1), for the charge glow.
static func fill(st, key: String, every: float) -> float:
	return clampf(float(st._timers.get(key, 0.0)) / every, 0.0, 1.0)

## Positions of enemies that were inside `reach` at the last call and have died since. Enemies that merely walked out are dropped.
static func deaths(st, reach: float) -> Array:
	var out := []
	var here := {}
	for e in enemies(st, reach):
		here[e.get_instance_id()] = true
		st._seen[e.get_instance_id()] = e.global_position
	for id in st._seen.keys():
		var o = instance_from_id(id)
		if o != null and !_dead(o):
			if !here.has(id):
				st._seen.erase(id)
			continue
		out.append(st._seen[id])
		st._seen.erase(id)
	return out

## True exactly once each time hp falls below `frac` of max; re-armed when it has healed back above `frac + 0.1`.
static func threshold(st, key: String, frac: float) -> bool:
	var armed: bool = st._thr.get(key, true)
	if armed and st.hp < frac * st.max_hp:
		st._thr[key] = false
		return true
	if !armed and st.hp >= (frac + 0.1) * st.max_hp:
		st._thr[key] = true
	return false

## Run `fn` after `secs` seconds, unless the structure is gone by then. `fn` must not capture the structure itself (a freed capture is an engine error): pass it the world and the tree.
static func later(st, secs: float, fn: Callable) -> void:
	var id: int = st.get_instance_id()
	st.get_tree().create_timer(secs).timeout.connect(func():
		var o = instance_from_id(id)
		if o != null and is_instance_valid(o) and !o.is_queued_for_deletion():
			fn.call())

## A sound at most once per `gap` seconds per structure (so a pack of gnawers is not a drumroll).
static func sfx(st, name: String, gap := 0.5, pitch := 1.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var key := "sfx:" + name
	if now - float(st._timers.get(key, -10.0)) < gap:
		return
	st._timers[key] = now
	Sfx.play(name, 0.08, pitch)

## Damage, shove and stun everything within `r`; a ring and flying shards show it. `dmg` 0 only shoves. Bosses are shoved weakly, never stunned.
static func pulse(st, r: float, dmg: float, push_speed: float, stun: float, col: Color, elem := "") -> void:
	var world := world_of(st)
	WeaponFx.spawn(world, "ring", st.global_position, col, {"radius": r, "life": 0.3})
	WeaponFx.spawn(world, "shards", st.global_position, col, {"radius": r, "count": 8, "life": 0.35})
	for e in enemies(st, r):
		var dir: Vector2 = (e.global_position - st.global_position).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		if dmg > 0.0:
			e.spell_damage(dmg, elem, true)
		if _dead(e):
			continue
		if push_speed > 0.0 and e.has_method("push"):
			e.push(dir * push_speed, 0.15)
		if stun > 0.0 and !_boss(e) and e.has_method("apply_slow"):
			e.apply_slow(0.0, stun)
	st.fx_pulse = 0.0

## `n` projectiles evenly round the structure.
static func radial(st, n: int, dmg: float, col: Color, speed := 170.0, life := 0.5) -> void:
	var world := world_of(st)
	var base: float = SpellArt.jit(int(st.get_instance_id() % 97)) * TAU
	for i in n:
		WeaponProjectile.shoot(world, st.global_position, Vector2.from_angle(base + i * TAU / float(n)), speed, dmg, col, life, 0, 60.0)

## A jagged bolt of light from the structure to `target`, and the damage.
static func bolt(st, target, dmg: float, col: Color, elem := "") -> void:
	if !is_instance_valid(target):
		return
	var to: Vector2 = target.global_position - st.global_position
	WeaponFx.spawn(world_of(st), "bolt", st.global_position, col, {"dir": to.normalized(), "length": to.length(), "width": 3.0, "life": 0.18})
	target.spell_damage(dmg, elem)

## A patch of slowed ground under the structure (harmless to players).
static func slow_patch(st, r: float, secs: float, factor: float) -> void:
	WeaponUtil.patch(world_of(st), st.global_position, "slow", r, Color(st._color(), 0.28), secs, factor)

## Heal guards and other structures within `r`, never above their maximum.
static func mend(st, r: float, per_sec: float, delta: float) -> void:
	for g in st.get_tree().get_nodes_in_group("guard"):
		if is_instance_valid(g) and !g.get("downed") and g.global_position.distance_to(st.global_position) <= r and g.hp < g.max_hp:
			g.hp = minf(g.max_hp, g.hp + per_sec * delta)
	for o in st.get_tree().get_nodes_in_group("structure"):
		if o != st and is_instance_valid(o) and !o.is_queued_for_deletion() and o.global_position.distance_to(st.global_position) <= r and o.hp < o.max_hp:
			o.hp = minf(o.max_hp, o.hp + per_sec * delta)

## Cast a copy of a spell card at `at` (no mana, never a finale): the building borrows the spell's own tier abilities.
## The spell tier is the structure's tier plus `tier_offset` (at least 1). The copy flies from the building.
static func cast(st, card_id: String, at: Vector2, r_scale := 1.0, tier_offset := 0) -> void:
	var t := clampi(st.tier + tier_offset, 1, 6)
	var d: Dictionary = Game.stats_of(Game.make_entry(card_id, t, Game.twist_for(card_id, t)))
	d.copy = true
	d.tier = t
	d.adds = []
	d.twist = ""
	d.radius = float(d.radius) * r_scale
	var s := Spell.new()
	s.setup(d, at, st.global_position)
	world_of(st).add_child(s)

## The health of a player as 0..1 (the bar is 228 wide).
static func hp_frac(p) -> float:
	if p.remote_controlled:
		return p.remote_hp / 228.0
	var bar = p.get_parent().get_node_or_null("Hud/Control2/ColorRect/Health")
	if bar == null:
		return 1.0
	return bar.size.x / 228.0

## The colour of the light a building casts (a Sun Crown torch burns white-gold).
static func glow_color(st, base: Color) -> Color:
	if id_of(st) == "torch" and st.tier >= 6:
		return Color(1.0, 0.95, 0.7)
	return base

# ---------------------------------------------------------------- the hooks Structure calls
# Each dispatches on the card id and returns the neutral value for an id without a function.

## Every physics frame, after the kind's own work.
static func tick(st, delta: float) -> void:
	match id_of(st):
		"crystal_pylon", "storm_spire", "magma_wall", "venom_tower", "prism_tower", "healing_grove", "sunspire", "phoenix_shrine", "healing_lantern", "beacon_turret", "bonfire_wall", "spiked_sentry":
			C.tick(st, delta)
		"barricade":
			tick_barricade(st, delta)
		"spike_trap":
			tick_spike_trap(st, delta)
		"torch":
			tick_torch(st, delta)
		"sentry":
			tick_sentry(st, delta)
		"mender":
			tick_mender(st, delta)
		"iron_wall":
			tick_iron_wall(st, delta)
		"frost_totem":
			tick_frost_totem(st, delta)
		"ember_turret":
			tick_ember_turret(st, delta)
		"thorn_hedge":
			tick_thorn_hedge(st, delta)
		_:
			pass

## A gnawer chews a barricade-kind wall (called once per gnawing enemy, every 0.5 s).
static func on_gnaw(st, e) -> void:
	match id_of(st):
		"crystal_pylon", "storm_spire", "magma_wall", "venom_tower", "prism_tower", "healing_grove", "sunspire", "phoenix_shrine", "healing_lantern", "beacon_turret", "bonfire_wall", "spiked_sentry":
			C.on_gnaw(st, e)
		"iron_wall":
			on_gnaw_iron_wall(st, e)
		"thorn_hedge":
			on_gnaw_thorn_hedge(st, e)
		_:
			pass

## The multiplier on the damage a wall takes from one gnaw (1.0 normally; 0 while it is untouchable).
static func guard_mult(st) -> float:
	if st._invuln > 0.0:
		return 0.0
	var m := 1.0
	if id_of(st) == "iron_wall" and st.tier >= 2:                  # Iron Bulwark 2: plating
		m *= IRON_PLATE
	var aura := 0                                                  # Iron Bulwark 4: any structure near a tier 4+ bulwark takes less (two count at most)
	for o in st.get_tree().get_nodes_in_group("structure"):
		if aura < 2 and o != st and is_instance_valid(o) and !o.is_queued_for_deletion() and o.tier >= 4 and String(o.data.get("id", "")) == "iron_wall" and o.global_position.distance_to(st.global_position) <= IRON_AURA_R:
			aura += 1
	m *= pow(IRON_AURA, aura)
	return m

## Sentry family: a multiplier on the wait between shots.
static func interval_mult(st) -> float:
	match id_of(st):
		"crystal_pylon", "storm_spire", "magma_wall", "venom_tower", "prism_tower", "healing_grove", "sunspire", "phoenix_shrine", "healing_lantern", "beacon_turret", "bonfire_wall", "spiked_sentry":
			return C.interval_mult(st)
		"ember_turret":
			return EMBER_OD_RATE if st._od > 0.0 else 1.0
		_:
			return 1.0

## Sentry family: a multiplier on the damage of the direct hit.
static func shot_mult(st, target) -> float:
	match id_of(st):
		"crystal_pylon", "storm_spire", "magma_wall", "venom_tower", "prism_tower", "healing_grove", "sunspire", "phoenix_shrine", "healing_lantern", "beacon_turret", "bonfire_wall", "spiked_sentry":
			return C.shot_mult(st, target)
		"sentry":
			return shot_mult_sentry(st, target)
		"ember_turret":
			return EMBER_OD_DMG if st._od > 0.0 else 1.0
		_:
			return 1.0

## Sentry family: after the normal damage, slow, poison, twin and blast code of one shot (`shot_to`/`shot_t`/`aim` are set).
static func on_shot(st, target) -> void:
	match id_of(st):
		"crystal_pylon", "storm_spire", "magma_wall", "venom_tower", "prism_tower", "healing_grove", "sunspire", "phoenix_shrine", "healing_lantern", "beacon_turret", "bonfire_wall", "spiked_sentry":
			C.on_shot(st, target)
		"sentry":
			on_shot_sentry(st, target)
		"ember_turret":
			on_shot_ember_turret(st, target)
		_:
			pass

## Sentry family: true for a target the turret should shoot before any other (a marked enemy).
static func prefer(st, e) -> bool:
	match id_of(st):
		"sentry":
			return st.mark_on and e.get_instance_id() == st._mark_id
		_:
			return false

## Spike trap: after the enemies on the plate were hit (`hit` is that array).
static func on_trigger(st, hit: Array) -> void:
	match id_of(st):
		"spike_trap":
			on_trigger_spike_trap(st, hit)
		_:
			pass

## Spike trap: its last use was spent (the trap is freed right after).
static func on_last_use(st) -> void:
	match id_of(st):
		"spike_trap":
			on_last_use_spike_trap(st)
		_:
			pass

## Mender: a multiplier on the continuous heal for one player.
static func heal_mult(st, p) -> float:
	match id_of(st):
		"mender":
			return heal_mult_mender(st, p)
		_:
			return 1.0

## Mender: a multiplier on how much of its healing budget a heal uses up (the World Tree is generous).
static func budget_mult(st) -> float:
	match id_of(st):
		"crystal_pylon", "storm_spire", "magma_wall", "venom_tower", "prism_tower", "healing_grove", "sunspire", "phoenix_shrine", "healing_lantern", "beacon_turret", "bonfire_wall", "spiked_sentry":
			return C.budget_mult(st)
		_:
			return 1.0

## A freshly set up building (data is the tier's fresh card): the place for stats the plain card cannot express (a brighter light).
static func on_setup(st) -> void:
	match id_of(st):
		"crystal_pylon", "storm_spire", "magma_wall", "venom_tower", "prism_tower", "healing_grove", "sunspire", "phoenix_shrine", "healing_lantern", "beacon_turret", "bonfire_wall", "spiked_sentry":
			C.on_setup(st)
		_:
			pass

## The building has just gone up a tier (its stats are already the new tier's).
static func on_promote(st, new_tier: int) -> void:
	match id_of(st):
		"crystal_pylon", "storm_spire", "magma_wall", "venom_tower", "prism_tower", "healing_grove", "sunspire", "phoenix_shrine", "healing_lantern", "beacon_turret", "bonfire_wall", "spiked_sentry":
			C.on_promote(st, new_tier)
		"barricade":
			on_promote_barricade(st, new_tier)
		"torch":
			on_promote_torch(st, new_tier)
		"ember_turret":
			on_promote_ember_turret(st, new_tier)
		_:
			pass

## The building is going away (destroyed, spent, or removed). `hp <= 0` means enemies destroyed it.
static func on_expire(st) -> void:
	match id_of(st):
		"crystal_pylon", "storm_spire", "magma_wall", "venom_tower", "prism_tower", "healing_grove", "sunspire", "phoenix_shrine", "healing_lantern", "beacon_turret", "bonfire_wall", "spiked_sentry":
			C.on_expire(st)
		"thorn_hedge":
			on_expire_thorn_hedge(st)
		_:
			pass

# ---------------------------------------------------------------- Barricade
const BARR_SHOVE_T := 4.0
const BARR_STAKE_T := 3.0
const BARR_BALLISTA_T := 1.5
const BARR_BALLISTA_RANGE := 100.0
const BARR_REBUKE_R := 44.0
const BARR_WIND_R := 60.0
const WOOD := Color(0.65, 0.45, 0.25)
const PALE_WOOD := Color(0.9, 0.78, 0.55)
const WALL_GOLD := Color(1.0, 0.85, 0.4)

## A thin line of light from a building to a target (a bolt or arrow), and the damage.
static func shaft(st, target, dmg: float, col: Color, elem := "", width := 3.0) -> void:
	if !is_instance_valid(target):
		return
	var to: Vector2 = target.global_position - st.global_position
	WeaponFx.spawn(world_of(st), "line", st.global_position, col, {"dir": to.normalized(), "length": to.length(), "width": width, "life": 0.18})
	WeaponFx.spawn(world_of(st), "burst", target.global_position, col, {"radius": 8.0, "life": 0.2})
	target.spell_damage(dmg, elem)

static func tick_barricade(st, delta: float) -> void:
	var t: int = st.tier
	var thorns: float = float(st.data.get("thorns", 0.0))
	st.invuln_view = st._invuln > 0.0
	if t < 2:
		return
	var w := world_of(st)
	var pos: Vector2 = st.global_position
	# 2 Shove: the wall bucks and knocks its gnawers back (waits at full until somebody is there)
	if ready(st, "shove", BARR_SHOVE_T, delta):
		st.charge = 1.0
		if !enemies(st, st.radius + 14.0).is_empty():
			reset(st, "shove")
			pulse(st, st.radius + 14.0, 0.0, 220.0, 0.3, WOOD)
			sfx(st, "thump", 0.4)
	else:
		st.charge = fill(st, "shove", BARR_SHOVE_T)
	# 3 Stakes: the gnawer nearest the middle is skewered and left exposed
	if t >= 3 and ready(st, "stake", BARR_STAKE_T, delta):
		var victim = null
		var bd := INF
		for e in enemies(st, st.radius + 9.0):
			var d: float = e.global_position.distance_to(pos)
			if d < bd:
				bd = d
				victim = e
		if victim != null:
			reset(st, "stake")
			WeaponFx.spawn(w, "pillar", victim.global_position, PALE_WOOD, {"height": 28.0, "width": 6.0, "life": 0.3})
			WeaponFx.spawn(w, "burst", victim.global_position, WOOD, {"radius": 8.0, "life": 0.2})
			victim.spell_damage(thorns * 4.0, "pierce")
			if is_instance_valid(victim) and !_dead(victim):
				WeaponUtil.expose(victim, 1.5)
			sfx(st, "hit", 0.3)
	# 4 Ballista: shoots the nearest enemy it can see
	if t >= 4 and ready(st, "ballista", BARR_BALLISTA_T, delta):
		var target = nearest(st, BARR_BALLISTA_RANGE)
		if target != null:
			reset(st, "ballista")
			shaft(st, target, thorns * 0.8, PALE_WOOD, "pierce")
			sfx(st, "whoosh", 0.3)
	# 5 Rebuke: a shockwave each time it falls below 75%, 50%, 25%
	if t >= 5:
		for key in [["r75", 0.75], ["r50", 0.5], ["r25", 0.25]]:
			if threshold(st, key[0], key[1]):
				pulse(st, BARR_REBUKE_R, thorns * 3.0, 260.0, 0.5, WALL_GOLD)
				WeaponFx.spawn(w, "ripple", pos, Color(1.0, 0.95, 0.7), {"radius": BARR_REBUKE_R, "rings": 2, "life": 0.45})
				WeaponFx.spawn(w, "shards", pos, Color(1.0, 0.95, 0.7), {"radius": BARR_REBUKE_R, "count": 10, "life": 0.4})
				Sfx.play("big_hit")
	# 6 Second wind: once, it heals itself, shrugs everything off for a moment and bursts
	if t >= 6 and !st._wind_used and st.hp < 0.2 * st.max_hp:
		st._wind_used = true
		st.hp = st.max_hp * 0.6
		st._invuln = 3.0
		st.invuln_view = true
		pulse(st, BARR_WIND_R, thorns * 5.0, 320.0, 0.8, WALL_GOLD)
		WeaponFx.spawn(w, "flash", pos, Color(1.0, 0.95, 0.7), {"radius": 50.0, "life": 0.4})
		WeaponFx.spawn(w, "ripple", pos, WALL_GOLD, {"radius": 70.0, "rings": 3, "life": 0.6})
		Sfx.play("ultimate")

static func on_promote_barricade(st, _new_tier: int) -> void:
	st._wind_used = false
	st._thr.clear()

# ---------------------------------------------------------------- Spike Trap
const SPIKE_SNARE := 0.45
const SPIKE_SPRING_EVERY := 3
const SPIKE_SPRING_MULT := 4.0
const SPIKE_CALTROP_R := 1.35
const SPIKE_CHAIN_R := 1.6
const SPIKE_GASP_MULT := 12.0
const IRON := Color(0.75, 0.75, 0.8)

static func on_trigger_spike_trap(st, hit: Array) -> void:
	var t: int = st.tier
	if t < 2:
		return
	var w := world_of(st)
	var dmg: float = st.data.damage
	var shown := 0
	for e in hit:                                                  # 2 Snare: a real slow on whoever steps on it
		if !is_instance_valid(e) or _dead(e):
			continue
		keep_slow(e, SPIKE_SNARE, 1.0)
		if shown < 6:
			WeaponFx.spawn(w, "burst", e.global_position, IRON, {"radius": 10.0, "life": 0.2})
			shown += 1
	if t >= 3 and st._triggers % SPIKE_SPRING_EVERY == 0:          # 3 Spring: every third trigger the spikes shoot up
		pulse(st, st.radius * 1.4, dmg * SPIKE_SPRING_MULT, 200.0, 0.6, IRON, "pierce")
		WeaponFx.spawn(w, "ripple", st.global_position, IRON, {"radius": st.radius * 1.4, "rings": 2, "life": 0.45})
		Sfx.play("big_hit")
	if t >= 5:                                                     # 5 Barbed chain: whoever is near the plate is dragged on to it
		for e in enemies(st, st.radius * SPIKE_CHAIN_R):
			if e in hit or _dead(e):
				continue
			var d: Vector2 = st.global_position - e.global_position
			if d.length() < 1.0:
				continue
			if e.has_method("push"):
				e.push(d.normalized() * 260.0, 0.18)
			WeaponFx.spawn(w, "line", st.global_position, IRON, {"dir": -d.normalized(), "length": d.length(), "width": 2.0, "life": 0.2})
			WeaponFx.spawn(w, "burst", e.global_position, IRON, {"radius": 8.0, "life": 0.2})
			WeaponUtil.bleed(st.get_tree(), e, 3, dmg * 0.4)
		sfx(st, "whoosh", 0.3)

static func tick_spike_trap(st, delta: float) -> void:
	if st.tier >= 4 and st.uses > 0:                               # 4 Caltrop field: slow ground lies round the trap while it has uses
		if !st._timers.has("caltrop"):
			st._timers["caltrop"] = 3.4
		if pace(st, "caltrop", 3.5, delta):
			slow_patch(st, st.radius * SPIKE_CALTROP_R, 4.0, 0.6)
			WeaponFx.spawn(world_of(st), "motes", st.global_position, IRON, {"radius": st.radius * 1.3, "count": 4, "rise": 8.0, "life": 0.6})

static func on_last_use_spike_trap(st) -> void:
	if st.tier < 6:
		return
	var w := world_of(st)
	var r: float = st.radius * 2.2
	var pos: Vector2 = st.global_position
	WeaponFx.spawn(w, "flash", pos, Color(0.9, 0.92, 1.0), {"radius": r, "life": 0.4})
	WeaponFx.spawn(w, "ripple", pos, IRON, {"radius": r, "rings": 3, "life": 0.55})
	WeaponFx.spawn(w, "shards", pos, IRON, {"radius": r, "count": 16, "life": 0.45})
	WeaponFx.spawn(w, "pillar", pos, Color(1.0, 0.85, 0.4), {"height": 40.0, "width": 20.0, "life": 0.45})
	Sfx.play("ultimate")
	pulse(st, r, st.data.damage * SPIKE_GASP_MULT, 260.0, 1.0, Color(1.0, 0.85, 0.4), "pierce")
	slow_patch(st, r, 6.0, 0.4)

# ---------------------------------------------------------------- Torch
const TORCH_DMG := [0.0, 2.0, 3.0, 5.0, 8.0, 12.0]
const TORCH_FLAME_R := 26.0
const TORCH_FLAME_T := 3.0
const TORCH_EMBER_T := 2.0
const TORCH_SUN_T := 8.0
const TORCH_HEARTH := 1.5
const TORCH_ORB_SPEED := 1.4
const FLAME := Color(1.0, 0.45, 0.1)
const FLAME_MID := Color(1.0, 0.8, 0.3)

## Where orb `i` of a tier 5 torch is now (the drawing uses the same function).
static func orb_pos(st, i: int) -> Vector2:
	return st.global_position + Vector2.from_angle(st._age * TORCH_ORB_SPEED + i * TAU / 3.0) * st.light_radius * 0.45

static func tick_torch(st, delta: float) -> void:
	var t: int = st.tier
	st.lit = true
	if t < 2:
		return
	var dmg: float = TORCH_DMG[t - 1]
	var w := world_of(st)
	var pos: Vector2 = st.global_position
	# 2 Flame guard: it flares at an enemy that comes close
	if !st._timers.has("flame"):
		st._timers["flame"] = TORCH_FLAME_T                          # (ready from the start)
	if ready(st, "flame", TORCH_FLAME_T, delta) and !enemies(st, TORCH_FLAME_R).is_empty():
		reset(st, "flame")
		pulse(st, TORCH_FLAME_R, dmg, 140.0, 0.0, FLAME, "fire")
		WeaponFx.spawn(w, "burst", pos, FLAME_MID, {"radius": 16.0, "life": 0.25})
		sfx(st, "hit", 0.3)
	# 3 Ember flick: a burning ember at the nearest enemy in its light
	if t >= 3 and ready(st, "ember", TORCH_EMBER_T, delta):
		var target = nearest(st, st.light_radius)
		if target != null:
			reset(st, "ember")
			var dir: Vector2 = target.global_position - pos
			WeaponProjectile.shoot(w, pos + Vector2(0, -6), dir, 200.0, dmg * 0.8, FLAME_MID, 0.7, 0, 40.0)
			sfx(st, "whoosh", 0.3)
			var at: Vector2 = target.global_position
			later(st, minf(0.6, dir.length() / 200.0), func(): WeaponFx.spawn(w, "burst", at, FLAME, {"radius": 8.0, "life": 0.2}))
	# 4 Hearth: players inside the light recover
	if t >= 4:
		var warmed := []
		for p in st.get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and p.global_position.distance_to(pos) <= st.light_radius and p.needs_health():
				p.heal(TORCH_HEARTH * delta)
				warmed.append(p)
		if pace(st, "hearth", 2.0, delta):
			for p in warmed:
				WeaponFx.spawn(w, "motes", p.global_position, FLAME_MID, {"radius": 10.0, "count": 4, "rise": 14.0, "life": 0.7})
	# 5 Fire orbs: three flames circle the torch and burn what they touch
	if t >= 5 and pace(st, "orb", 0.5, delta):
		for i in 3:
			var op := orb_pos(st, i)
			var hit := false
			for e in enemies_at(st, op, 12.0):
				e.spell_damage(dmg * 0.6, "fire", true)
				hit = true
			if hit:
				WeaponFx.spawn(w, "burst", op, FLAME, {"radius": 8.0, "life": 0.2})
	# 6 Sunburst: every 8 s a flare of sunlight hurts, shoves and lights up everything in the light
	if t >= 6:
		if pace(st, "sun", TORCH_SUN_T, delta):
			var r: float = st.light_radius
			var in_light := enemies(st, r)
			pulse(st, r, dmg * 3.0, 220.0, 0.4, WALL_GOLD, "fire")
			for e in in_light:
				Game.light_up(e, 6.0)
			WeaponFx.spawn(w, "flash", pos, Color(1.0, 0.95, 0.7), {"radius": r * 0.8, "life": 0.4})
			WeaponFx.spawn(w, "ripple", pos, WALL_GOLD, {"radius": r, "rings": 3, "life": 0.6})
			WeaponFx.spawn(w, "star", pos, Color(1.0, 0.95, 0.7), {"radius": 24.0, "count": 12, "spin": 1.5, "life": 0.5})
			Sfx.play("ultimate", 0.05, 1.3)
		st.charge = fill(st, "sun", TORCH_SUN_T)

static func on_promote_torch(st, new_tier: int) -> void:
	if new_tier >= 6 and st._glow != null:
		st._glow.color = glow_color(st, st._glow.color)

# ---------------------------------------------------------------- Sentry
const SENTRY_PIERCE := 0.6
const SENTRY_PIERCE_LEN := 45.0
const SENTRY_FOCUS := 0.15
const SENTRY_FOCUS_MAX := 6
const SENTRY_VOLLEY_EVERY := 6
const SENTRY_EXEC := 3.0
const SENTRY_EXEC_AT := 0.25
const SENTRY_MARK_T := 8.0
const SENTRY_MARK_LEN := 6.0
const BOLT := Color(1.0, 0.95, 0.7)
const BRASS := Color(0.9, 0.8, 0.4)

static func shot_mult_sentry(st, target) -> float:
	var t: int = st.tier
	var m := 1.0
	if t >= 3:                                                     # 3 Focus fire: the same target again and again takes more
		var id: int = target.get_instance_id()
		if id != st._focus_id:
			st._focus_id = id
			st._focus_n = 0
		else:
			st._focus_n = mini(st._focus_n + 1, SENTRY_FOCUS_MAX)
		m *= 1.0 + SENTRY_FOCUS * st._focus_n
		st.charge = st._focus_n / float(SENTRY_FOCUS_MAX)
	st._timers["exec"] = 0.0
	if t >= 5 and float(target.health) <= SENTRY_EXEC_AT * float(target.max_health):     # 5 Executioner
		m *= SENTRY_EXEC
		st._timers["exec"] = 1.0
	return m

static func on_shot_sentry(st, target) -> void:
	var t: int = st.tier
	if t < 2 or !is_instance_valid(target):
		return
	var w := world_of(st)
	var pos: Vector2 = st.global_position
	var tp: Vector2 = target.global_position
	var to: Vector2 = tp - pos
	var dmg: float = st.data.damage
	# 2 Piercing bolt: the bolt flies on and hits what stands behind the target
	WeaponFx.spawn(w, "line", pos + Vector2(0, -5), BOLT, {"dir": to.normalized(), "length": to.length(), "width": 2.0, "life": 0.14})
	for e in WeaponUtil.enemies_in_line(st.get_tree(), tp, st.aim, SENTRY_PIERCE_LEN, 6.0):
		if e != target and !_dead(e):
			e.spell_damage(dmg * SENTRY_PIERCE, st.data.get("element", ""))
	WeaponFx.spawn(w, "burst", tp, BOLT, {"radius": 8.0 + 2.0 * st._focus_n if t >= 3 else 8.0, "life": 0.2})
	sfx(st, "whoosh", 0.25)
	if t >= 4 and st._shots % SENTRY_VOLLEY_EVERY == 0:             # 4 Volley: every sixth shot is a fan of five bolts
		for k in range(-2, 3):
			WeaponProjectile.shoot(w, pos + Vector2(0, -5), st.aim.rotated(k * 0.15), 320.0, dmg * 0.5, BRASS, 0.5, 0, 50.0)
		WeaponFx.spawn(w, "ring", pos + Vector2(0, -5) + st.aim * 8.0, BRASS, {"radius": 14.0, "life": 0.25})
		Sfx.play("big_hit")
	if float(st._timers.get("exec", 0.0)) > 0.0:
		WeaponFx.spawn(w, "flash", tp, Color(1.0, 0.45, 0.4), {"radius": 16.0, "life": 0.3})
		WeaponFx.spawn(w, "shards", tp, Color(1.0, 0.4, 0.35), {"radius": 16.0, "count": 6, "life": 0.3})
		Sfx.play("big_hit")

static func tick_sentry(st, delta: float) -> void:
	var t: int = st.tier
	if t >= 5 and pace(st, "look", 0.25, delta):                   # the executioner's eye glows when something is weak enough
		var weak := false
		for e in enemies(st, st.data.range):
			if float(e.health) <= SENTRY_EXEC_AT * float(e.max_health) and Game.defence_sees(e, st.global_position):
				weak = true
				break
		st.alert = weak
	if t >= 6:                                                      # 6 Hunter's mark: the toughest enemy in sight takes 40% more from everything
		var now := Time.get_ticks_msec() / 1000.0
		var m = instance_from_id(st._mark_id) if st._mark_id != 0 else null
		if m != null and is_instance_valid(m) and !_dead(m) and m.has_meta("marked_until") and float(m.get_meta("marked_until")) > now:
			st.mark_on = true
			st.mark_pos = m.global_position
		else:
			st.mark_on = false
		if pace(st, "mark", SENTRY_MARK_T, delta):
			var pick = null
			for e in enemies(st, st.data.range):
				if Game.defence_sees(e, st.global_position) and (pick == null or float(e.max_health) > float(pick.max_health)):
					pick = e
			if pick != null:
				pick.set_meta("marked_until", now + SENTRY_MARK_LEN)
				st._mark_id = pick.get_instance_id()
				st.mark_on = true
				st.mark_pos = pick.global_position
				var w := world_of(st)
				WeaponFx.spawn(w, "star", pick.global_position, Color(1.0, 0.3, 0.25), {"radius": 12.0, "count": 4, "spin": 1.2, "life": 0.5})
				var to: Vector2 = pick.global_position - st.global_position
				WeaponFx.spawn(w, "line", st.global_position + Vector2(0, -5), Color(1.0, 0.35, 0.3), {"dir": to.normalized(), "length": to.length(), "width": 1.0, "life": 0.4})
				Sfx.play("cast")

# ---------------------------------------------------------------- Mender Totem
const MENDER_BLESS_T := 6.0
const MENDER_MEND := 0.5
const MENDER_LIFELINE := 2.0
const MENDER_LIFELINE_AT := 0.4
const MENDER_LINK := 1.5
const MENDER_ANGEL_AT := 0.15
const MENDER_ANGEL_TO := 0.6
const MENDER_ANGEL_CD := 30.0
const SPIRIT := Color(0.4, 1.0, 0.5)

static func heal_mult_mender(st, p) -> float:
	if st.tier >= 4 and hp_frac(p) < MENDER_LIFELINE_AT:         # 4 Lifeline: the badly hurt are healed twice as fast
		return MENDER_LIFELINE
	return 1.0

## Guards and other buildings in the field that are hurt (what shared mending tends).
static func hurt_allies(st, r: float) -> Array:
	var out := []
	for g in st.get_tree().get_nodes_in_group("guard"):
		if is_instance_valid(g) and !g.get("downed") and g.global_position.distance_to(st.global_position) <= r and g.hp < g.max_hp:
			out.append(g)
	for o in st.get_tree().get_nodes_in_group("structure"):
		if o != st and is_instance_valid(o) and !o.is_queued_for_deletion() and o.global_position.distance_to(st.global_position) <= r and o.hp < o.max_hp:
			out.append(o)
	return out

static func tick_mender(st, delta: float) -> void:
	var t: int = st.tier
	if t < 2:
		return
	var w := world_of(st)
	var pos: Vector2 = st.global_position
	var heal: float = st.data.heal_per_sec
	var reach: float = st.radius * (MENDER_LINK if t >= 5 else 1.0)
	var hurt := []                                                 # players in reach that need healing
	for p in st.get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.global_position.distance_to(pos) <= reach and p.needs_health():
			hurt.append(p)
	var shown := []
	for p in hurt:
		if shown.size() < 4:
			shown.append(p.global_position)
	st.healed_pos = shown if t >= 5 else ([] if hurt.is_empty() else [pos])      # (tier 5 draws a beam to each)
	# 2 Blessing pulse: an instant heal every six seconds (it does not use the healing budget)
	var inside := hurt.filter(func(p): return p.global_position.distance_to(pos) <= st.radius)
	if ready(st, "bless", MENDER_BLESS_T, delta) and !inside.is_empty():
		reset(st, "bless")
		for p in inside:
			p.heal(heal)
		WeaponFx.spawn(w, "ring", pos, SPIRIT, {"radius": st.radius, "life": 0.4})
		WeaponFx.spawn(w, "motes", pos, SPIRIT, {"radius": st.radius, "count": 8, "rise": 22.0, "life": 0.7})
		Sfx.play("cast")
		st.fx_pulse = 0.0
	# 3 Shared mending: guards and buildings in the field mend at half the rate (no budget)
	if t >= 3:
		mend(st, st.radius, heal * MENDER_MEND, delta)
		if pace(st, "mendfx", 1.5, delta):
			for o in hurt_allies(st, st.radius):
				WeaponFx.spawn(w, "motes", o.global_position, SPIRIT, {"radius": 6.0, "count": 2, "rise": 10.0, "life": 0.5})
	# 4 Lifeline: confusion is cleansed at once
	if t >= 4:
		for p in st.get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and p.global_position.distance_to(pos) <= st.radius and p.get("confused_time") != null and p.confused_time > 0.0:
				p.confused_time = 0.0
				p.modulate = Color.WHITE
				WeaponFx.spawn(w, "star", p.global_position, Color(0.8, 1.0, 0.85), {"radius": 14.0, "count": 6, "spin": 1.0, "life": 0.4})
				Sfx.play("unlock")
	# 5 Spirit link: players just beyond the field are healed at half rate (and use half the budget)
	if t >= 5:
		var beam := pace(st, "beam", 0.25, delta)
		for p in hurt:
			var d: float = p.global_position.distance_to(pos)
			if d > st.radius:
				p.heal(heal * 0.5 * delta)
				st._healed += heal * 0.5 * delta * budget_mult(st)
				if beam:
					WeaponFx.spawn(w, "line", pos + Vector2(0, -8), SPIRIT, {"dir": (p.global_position - pos).normalized(), "length": d, "width": 1.5, "life": 0.15})
	# 6 Guardian angel: a player about to fall is saved (once per 30 s each)
	if t >= 6:
		var now: float = st._age
		for p in hurt:
			var f := hp_frac(p)
			var key: int = p.get_instance_id()
			if f < MENDER_ANGEL_AT and now - float(st._saved.get(key, -999.0)) >= MENDER_ANGEL_CD:
				st._saved[key] = now
				p.heal((MENDER_ANGEL_TO - f) * 228.0 * Game.hp_scale())
				p.shield_time = maxf(p.shield_time, 2.0)
				var pp: Vector2 = p.global_position
				WeaponFx.spawn(w, "pillar", pp, WALL_GOLD, {"height": 70.0, "width": 28.0, "life": 0.6})
				WeaponFx.spawn(w, "flash", pp, Color(1.0, 0.95, 0.7), {"radius": 40.0, "life": 0.4})
				WeaponFx.spawn(w, "star", pp, WALL_GOLD, {"radius": 36.0, "count": 8, "spin": 1.5, "life": 0.6})
				Sfx.play("ultimate")
				st.fx_pulse = 0.0

# ---------------------------------------------------------------- Iron Bulwark
const IRON_PLATE := 0.75
const IRON_AURA_R := 60.0
const IRON_AURA := 0.8
const IRON_SLAM_T := 5.0
const IRON_BELL_T := 12.0
const IRON_BELL_R := 90.0
const IRON_WHITE := Color(0.9, 0.93, 1.0)

static func on_gnaw_iron_wall(st, e) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if st.tier >= 2 and now - float(st._timers.get("sparkt", -9.0)) >= 0.4 and is_instance_valid(e):       # (a white spark on the side that was chewed)
		st._timers["sparkt"] = now
		var d: Vector2 = (e.global_position - st.global_position).normalized()
		WeaponFx.spawn(world_of(st), "burst", st.global_position + d * st.radius, IRON_WHITE, {"radius": 6.0, "life": 0.2})

static func tick_iron_wall(st, delta: float) -> void:
	var t: int = st.tier
	if t < 3:
		return
	var thorns: float = float(st.data.get("thorns", 0.0))
	var w := world_of(st)
	var pos: Vector2 = st.global_position
	# 3 Ram slam: the wall slams out at whoever is gnawing it
	if ready(st, "slam", IRON_SLAM_T, delta) and !enemies(st, st.radius + 16.0).is_empty():
		reset(st, "slam")
		pulse(st, st.radius + 16.0, thorns * 2.0, 200.0, 0.8, IRON_WHITE)
		WeaponFx.spawn(w, "shards", pos, IRON_WHITE, {"radius": 26.0, "count": 8, "life": 0.3})
		Sfx.play("thump")
	# 5 Deflect: enemy shots that reach the wall are thrown back
	if t >= 5:
		for sh in st.get_tree().get_nodes_in_group("enemy_shot"):
			if is_instance_valid(sh) and !sh.is_queued_for_deletion() and sh.global_position.distance_to(pos) <= st.radius + 6.0:
				var back: Vector2 = -sh.vel.normalized()
				WeaponProjectile.shoot(w, sh.global_position, back, 180.0, maxf(1.0, float(sh.damage) / 10.0), sh.tint, 1.0, 0, 40.0)
				WeaponFx.spawn(w, "line", sh.global_position, Color.WHITE, {"dir": back, "length": 28.0, "width": 2.0, "life": 0.15})
				WeaponFx.spawn(w, "burst", sh.global_position, IRON_WHITE, {"radius": 8.0, "life": 0.2})
				sh.queue_free()
				sfx(st, "hit", 0.2)
	# 6 Anvil bell: every 12 s the bell tolls
	if t >= 6:
		if pace(st, "bell", IRON_BELL_T, delta):
			pulse(st, IRON_BELL_R, thorns * 6.0, 320.0, 1.0, WALL_GOLD)
			WeaponFx.spawn(w, "flash", pos, Color(1.0, 0.95, 0.7), {"radius": IRON_BELL_R, "life": 0.4})
			WeaponFx.spawn(w, "ripple", pos, WALL_GOLD, {"radius": IRON_BELL_R, "rings": 3, "life": 0.6})
			WeaponFx.spawn(w, "shards", pos, WALL_GOLD, {"radius": IRON_BELL_R, "count": 14, "life": 0.5})
			Sfx.play("gong")
		st.charge = fill(st, "bell", IRON_BELL_T)

# ---------------------------------------------------------------- Frost Totem
const FT_DPS := [0.0, 1.0, 1.8, 3.0, 5.0, 8.0]
const FT_SPEAR_T := 2.5
const FT_BLIZZ_T := 15.0
const FT_ZERO_T := 20.0
const FT_NOVA_R := 36.0
const ICE := Color(0.6, 0.85, 1.0)
const SNOW := Color(0.95, 0.98, 1.0)

static func tick_frost_totem(st, delta: float) -> void:
	var t: int = st.tier
	if t < 2:
		return
	var dps: float = FT_DPS[t - 1]
	var w := world_of(st)
	var pos: Vector2 = st.global_position
	var inside := enemies(st, st.radius)
	# 2 Rime aura: the cold bites everything in the aura
	if pace(st, "bite", 0.5, delta):
		for e in inside:
			e.spell_damage(dps * 0.5, "ice", true)
	if pace(st, "bitefx", 1.0 / 3.0, delta) and !inside.is_empty():
		var e = inside[int(Time.get_ticks_msec() / 333) % inside.size()]
		if is_instance_valid(e):
			WeaponFx.spawn(w, "burst", e.global_position, SNOW, {"radius": 5.0, "life": 0.2})
	# 3 Ice spear: hurled at the nearest enemy in the aura, pierces two more
	if t >= 3 and ready(st, "spear", FT_SPEAR_T, delta):
		var target = nearest(st, st.radius)
		if target != null:
			reset(st, "spear")
			var dir: Vector2 = target.global_position - pos
			WeaponProjectile.shoot(w, pos + Vector2(0, -12), dir, 220.0, dps * 2.0, ICE, 0.7, 2, 40.0)
			WeaponFx.spawn(w, "line", pos + Vector2(0, -12), SNOW, {"dir": dir.normalized(), "length": 14.0, "width": 2.0, "life": 0.15})
			st.fx_pulse = 0.0
			Sfx.play("whoosh")
	# 4 Frostbitten: whoever stands in the aura takes 25% more from everything, and a moment after
	if t >= 4:
		var until := Time.get_ticks_msec() / 1000.0 + 2.5
		for e in inside:
			e.set_meta("chilled_until", until)
	# 5 Blizzard heart: every 15 s a blizzard is cast on the densest group in the aura
	if t >= 5 and ready(st, "blizzard", FT_BLIZZ_T, delta) and !inside.is_empty():
		reset(st, "blizzard")
		var dense = densest(st, st.radius)
		var at: Vector2 = dense.global_position if dense != null else pos
		cast(st, "blizzard", at, 0.8)
		WeaponFx.spawn(w, "ripple", pos, ICE, {"radius": 30.0, "rings": 2, "life": 0.5})
		Sfx.play("cast")
	if t >= 6:
		# 6 Winter's reign: whatever dies in the aura shatters in a frost nova
		for dp in deaths(st, st.radius):
			WeaponFx.spawn(w, "ripple", dp, ICE, {"radius": FT_NOVA_R, "rings": 2, "life": 0.4})
			WeaponFx.spawn(w, "shards", dp, SNOW, {"radius": FT_NOVA_R, "count": 8, "life": 0.35})
			for e in enemies_at(st, dp, FT_NOVA_R):
				e.spell_damage(dps * 3.0, "ice", true)
				if !_dead(e) and !_boss(e) and e.has_method("apply_slow"):
					e.apply_slow(0.0, 0.5)
		# ... and every 20 s absolute zero freezes everything in the aura
		if pace(st, "zero", FT_ZERO_T, delta):
			WeaponFx.spawn(w, "flash", pos, ICE, {"radius": st.radius, "life": 0.5})
			WeaponFx.spawn(w, "ripple", pos, SNOW, {"radius": st.radius, "rings": 3, "life": 0.7})
			WeaponFx.spawn(w, "shards", pos, SNOW, {"radius": st.radius, "count": 16, "life": 0.5})
			Sfx.play("ultimate")
			for e in enemies(st, st.radius):
				if !_boss(e) and e.has_method("apply_slow"):
					e.apply_slow(0.0, 1.5)
				WeaponUtil.expose(e, 2.5)
		st.charge = fill(st, "zero", FT_ZERO_T)

# ---------------------------------------------------------------- Ember Turret
const EMBER_BLEED := 0.25
const EMBER_MORTAR_R := 38.0
const EMBER_MORTAR := 0.8
const EMBER_SHELL_EVERY := 5
const EMBER_CLUSTER := 0.4
const EMBER_OD_T := 12.0
const EMBER_OD_LEN := 3.0
const EMBER_OD_RATE := 0.25
const EMBER_OD_DMG := 0.6
const EMBER := Color(1.0, 0.45, 0.15)
const EMBER_GLOW := Color(1.0, 0.75, 0.3)

static func on_shot_ember_turret(st, target) -> void:
	var t: int = st.tier
	if t < 2 or !is_instance_valid(target):
		return
	var w := world_of(st)
	var pos: Vector2 = st.global_position
	var tp: Vector2 = target.global_position
	var to: Vector2 = tp - pos
	var dir: Vector2 = to.normalized()
	var dmg: float = st.data.damage
	var burst: float = st.data.get("burst", 0.0)
	var tree: SceneTree = st.get_tree()
	# 2 Incendiary: whatever it hits catches fire
	WeaponUtil.bleed(tree, target, 3, dmg * EMBER_BLEED)
	WeaponFx.spawn(w, "burst", pos + Vector2(0, -5) + dir * 9.0, EMBER_GLOW, {"radius": 8.0, "life": 0.18})
	WeaponFx.spawn(w, "burst", tp, EMBER, {"radius": 12.0, "life": 0.22})
	sfx(st, "big_hit", 0.3)
	if st._od > 0.0:                                                # (overdrive: a line of flame to the target)
		for k in 3:
			WeaponFx.spawn(w, "burst", pos + to * (0.3 + 0.25 * k), EMBER_GLOW, {"radius": 6.0, "life": 0.2})
	# 3 Mortar: the blast is wider than the old splash
	if t >= 3:
		WeaponFx.spawn(w, "fall", tp, EMBER, {"radius": 3.0, "height": 40.0, "rise": 20.0, "life": 0.15})
		for e in enemies_at(st, tp, EMBER_MORTAR_R):
			if e != target and !_dead(e):
				e.spell_damage(burst * EMBER_MORTAR, "fire", true)
		later(st, 0.15, func():
			WeaponFx.spawn(w, "flash", tp, EMBER_GLOW, {"radius": 22.0, "life": 0.25})
			WeaponFx.spawn(w, "ripple", tp, EMBER, {"radius": EMBER_MORTAR_R, "rings": 1, "life": 0.35}))
	# 4 Fire shell: every fifth shot lobs a small Fireball
	if t >= 4:
		st.charge = float(st._shots % EMBER_SHELL_EVERY) / EMBER_SHELL_EVERY
		if st._shots % EMBER_SHELL_EVERY == 0:
			cast(st, "fireball", tp, 0.8, -2)
			WeaponFx.spawn(w, "ring", pos + Vector2(0, -5) + dir * 9.0, EMBER, {"radius": 16.0, "life": 0.25})
			Sfx.play("cast")
	# 5 Cluster bomb: three bomblets scatter round the target
	if t >= 5:
		var base: float = float(st._shots) * 2.1
		for k in 3:
			var bp: Vector2 = tp + Vector2.from_angle(base + k * TAU / 3.0) * 30.0
			later(st, 0.25 * k, func(): WeaponFx.spawn(w, "fall", bp, EMBER, {"radius": 2.0, "height": 30.0, "rise": 12.0, "life": 0.25}))
			later(st, 0.25 * (k + 1), func():
				for e in WeaponUtil.enemies_in_circle(tree, bp, 16.0):
					e.spell_damage(dmg * EMBER_CLUSTER, "fire", true)
				WeaponFx.spawn(w, "burst", bp, EMBER, {"radius": 10.0, "life": 0.2})
				WeaponFx.spawn(w, "ring", bp, EMBER_GLOW, {"radius": 16.0, "life": 0.2}))

static func tick_ember_turret(st, delta: float) -> void:
	if st.tier < 6:
		return
	# 6 Inferno overdrive: every 12 s it overheats for 3 s: four times the fire rate at 60% damage, longer reach, a bigger light
	if st._od > 0.0:
		st._od -= delta
		st.charge = 1.0
		if st._od <= 0.0:
			st._od = 0.0
			st.overdrive = false
			st.data.range = float(st._timers.get("rng0", st.data.range))
			st.light_radius = float(st._timers.get("lr0", st.light_radius))
			if st._glow != null:
				st._glow.texture_scale = maxf(0.1, st.light_radius * 2.0 / 128.0)
		return
	st.charge = fill(st, "od", EMBER_OD_T)
	if pace(st, "od", EMBER_OD_T, delta):
		st._od = EMBER_OD_LEN
		st.overdrive = true
		st._timers["rng0"] = float(st.data.range)
		st._timers["lr0"] = st.light_radius
		st.data.range = float(st.data.range) * 1.2
		st.light_radius *= 1.5
		if st._glow != null:
			st._glow.texture_scale = maxf(0.1, st.light_radius * 2.0 / 128.0)
		var w := world_of(st)
		WeaponFx.spawn(w, "ring", st.global_position, EMBER, {"radius": 40.0, "life": 0.4})
		WeaponFx.spawn(w, "pillar", st.global_position, EMBER, {"height": 40.0, "width": 16.0, "life": 0.5})
		Sfx.play("boss_roar", 0.05, 1.5)

static func on_promote_ember_turret(st, _new_tier: int) -> void:
	st._od = 0.0                                                    # (the new tier starts with its fresh range and light)
	st.overdrive = false
	st._timers.erase("rng0")
	st._timers.erase("lr0")

# ---------------------------------------------------------------- Thorn Hedge
const HEDGE_ENTANGLE := 0.3
const HEDGE_VOLLEY_T := 2.5
const HEDGE_VOLLEY_R := 90.0
const HEDGE_BRAMBLE_R := 2.2
const HEDGE_SAP := 1.5
const HEDGE_SAP_R := 50.0
const HEDGE_STORM_T := 8.0
const LEAF := Color(0.4, 0.75, 0.3)
const THORN := Color(0.85, 0.95, 0.5)
const SAP := Color(1.0, 0.9, 0.5)

static func on_gnaw_thorn_hedge(st, e) -> void:
	if st.tier >= 2 and is_instance_valid(e) and e.has_method("apply_slow"):          # 2 Entangle: the vines hold a gnawer fast
		keep_slow(e, HEDGE_ENTANGLE, 0.8)
		WeaponFx.spawn(world_of(st), "burst", e.global_position, LEAF, {"radius": 8.0, "life": 0.2})

static func tick_thorn_hedge(st, delta: float) -> void:
	var t: int = st.tier
	if t < 3:
		return
	var thorns: float = float(st.data.get("thorns", 0.0))
	var w := world_of(st)
	var pos: Vector2 = st.global_position
	# 3 Thorn volley: three thorns at the nearest enemy it can see
	if ready(st, "volley", HEDGE_VOLLEY_T, delta):
		var target = nearest(st, HEDGE_VOLLEY_R)
		if target != null:
			reset(st, "volley")
			var dir: Vector2 = target.global_position - pos
			for k in range(-1, 2):
				WeaponProjectile.shoot(w, pos + Vector2(0, -6), dir.rotated(k * 0.15), 260.0, thorns * 0.8, THORN, 0.6, 0, 40.0)
			Sfx.play("whoosh")
	# 4 Bramble field: the ground round the hedge is overgrown (slow)
	if t >= 4:
		if !st._timers.has("bramble"):
			st._timers["bramble"] = 4.9
		if pace(st, "bramble", 5.0, delta):
			slow_patch(st, st.radius * HEDGE_BRAMBLE_R, 6.0, 0.6)
			WeaponFx.spawn(w, "motes", pos, LEAF, {"radius": st.radius * 1.5, "count": 3, "rise": 6.0, "life": 0.6})
	# 5 Heart sap: players and guards near it recover
	if t >= 5:
		mend(st, HEDGE_SAP_R, HEDGE_SAP, delta)
		var warmed := []
		for p in st.get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and p.global_position.distance_to(pos) <= HEDGE_SAP_R and p.needs_health():
				p.heal(HEDGE_SAP * delta)
				warmed.append(p)
		if pace(st, "sapfx", 1.5, delta):
			for p in warmed:
				WeaponFx.spawn(w, "motes", p.global_position, SAP, {"radius": 8.0, "count": 4, "rise": 16.0, "life": 0.7})
	# 6 Thorn storm: every 8 s, twelve thorns in a ring
	if t >= 6 and ready(st, "storm", HEDGE_STORM_T, delta) and nearest(st, 80.0) != null:
		reset(st, "storm")
		radial(st, 12, thorns, THORN)
		WeaponFx.spawn(w, "ripple", pos, LEAF, {"radius": 50.0, "rings": 2, "life": 0.5})
		WeaponFx.spawn(w, "shards", pos, THORN, {"radius": 50.0, "count": 12, "life": 0.4})
		Sfx.play("big_hit")

## Rebirth (tier 6): a hedge destroyed by enemies leaves a seedling that grows in its place.
static func on_expire_thorn_hedge(st) -> void:
	if st.tier < 6 or st.hp > 0.0 or st.data.get("seedling", false):
		return
	var d: Dictionary = Game.stats_of(Game.make_entry("thorn_hedge", 1, ""))
	d.seedling = true
	var seed := Structure.new()
	seed.setup(d, st.position)
	var w := world_of(st)
	w.add_child.call_deferred(seed)
	WeaponFx.spawn(w, "star", st.global_position, WALL_GOLD, {"radius": 22.0, "count": 6, "spin": 1.0, "life": 0.6})
	WeaponFx.spawn(w, "motes", st.global_position, LEAF, {"radius": 14.0, "count": 12, "rise": 24.0, "life": 0.9})
