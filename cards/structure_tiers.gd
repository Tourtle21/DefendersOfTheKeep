extends RefCounted
class_name StructureTiers
## What a building does at each tier (2 to 6), on top of the stacking "added" modifiers (Game.BUILD_TWISTS, Structure._apply_add).
## Structure calls the hooks below; each card is a few functions named <hook>_<card id>. Everything here runs on the host
## (a puppet structure never reaches it); visuals go through WeaponFx.spawn and Sfx.play, which are mirrored to clients.
## Designs: docs/card_tiers/<card id>.md, shared rules: docs/card_tiers/_CONVENTIONS.md

# ---------------------------------------------------------------- shared helpers

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

# ---------------------------------------------------------------- the hooks Structure calls
# Each dispatches on the card id and returns the neutral value for an id without a function.

## Every physics frame, after the kind's own work.
static func tick(st, delta: float) -> void:
	match id_of(st):
		_:
			pass

## A gnawer chews a barricade-kind wall (called once per gnawing enemy, every 0.5 s).
static func on_gnaw(st, e) -> void:
	match id_of(st):
		_:
			pass

## The multiplier on the damage a wall takes from one gnaw (1.0 normally; 0 while it is untouchable).
static func guard_mult(st) -> float:
	if st._invuln > 0.0:
		return 0.0
	var m := 1.0
	match id_of(st):
		_:
			pass
	return m

## Sentry family: a multiplier on the wait between shots.
static func interval_mult(st) -> float:
	match id_of(st):
		_:
			return 1.0

## Sentry family: a multiplier on the damage of the direct hit.
static func shot_mult(st, target) -> float:
	match id_of(st):
		_:
			return 1.0

## Sentry family: after the normal damage, slow, poison, twin and blast code of one shot (`shot_to`/`shot_t`/`aim` are set).
static func on_shot(st, target) -> void:
	match id_of(st):
		_:
			pass

## Spike trap: after the enemies on the plate were hit (`hit` is that array).
static func on_trigger(st, hit: Array) -> void:
	match id_of(st):
		_:
			pass

## Spike trap: its last use was spent (the trap is freed right after).
static func on_last_use(st) -> void:
	match id_of(st):
		_:
			pass

## Mender: a multiplier on the continuous heal for one player.
static func heal_mult(st, p) -> float:
	match id_of(st):
		_:
			return 1.0

## The building has just gone up a tier (its stats are already the new tier's).
static func on_promote(st, new_tier: int) -> void:
	match id_of(st):
		_:
			pass

## The building is going away (destroyed, spent, or removed). `hp <= 0` means enemies destroyed it.
static func on_expire(st) -> void:
	match id_of(st):
		_:
			pass
