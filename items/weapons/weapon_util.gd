extends RefCounted
class_name WeaponUtil
## Shared hit-detection helpers for weapons and abilities (geometry only, no scenes).

static func _alive(e) -> bool:       # untyped on purpose: callers may hold an already-freed enemy
	return is_instance_valid(e) and !e.is_queued_for_deletion()

static func _radius(e: Node) -> float:
	return e.hit_radius if "hit_radius" in e else 0.0

static func enemies_in_circle(tree: SceneTree, pos: Vector2, r: float) -> Array:
	var out := []
	for e in tree.get_nodes_in_group("enemy") + tree.get_nodes_in_group("critter"):
		if _alive(e) and e.global_position.distance_to(pos) <= r + _radius(e):
			out.append(e)
	return out

static func enemies_in_arc(tree: SceneTree, pos: Vector2, dir: Vector2, r: float, half_deg: float) -> Array:
	var out := []
	for e in enemies_in_circle(tree, pos, r):
		var rel: Vector2 = e.global_position - pos
		if rel.length() < 3.0 or absf(rad_to_deg(dir.angle_to(rel))) <= half_deg:
			out.append(e)
	return out

static func enemies_in_line(tree: SceneTree, pos: Vector2, dir: Vector2, length: float, width: float) -> Array:
	var out := []
	for e in tree.get_nodes_in_group("enemy"):
		if !_alive(e):
			continue
		var rel: Vector2 = e.global_position - pos
		if rel.dot(dir) >= -4.0 and rel.dot(dir) <= length and absf(rel.cross(dir)) <= width + _radius(e):
			out.append(e)
	return out

## Damage multiplier of the weapon in hand (Forge awakenings, tiers 4-6).
static var power := 1.0
## Element of the weapon in hand (enemies resist or fear elements).
static var element := ""
## Twist of the weapon in hand: extra effects on every hit.
static var twist := ""
## True while a glowing weapon is in hand: its hits light the enemy (see Game.light_up).
static var lit := false
static var _twist_hits := 0

## Damage an enemy; optional knockback impulse and stun (seconds).
static var _hit_frame := -1
static var _hit_targets := 0

static func hit(e: Node, dmg: float, from: Vector2, knock := 0.0, stun := 0.0, elem := "", aoe := false) -> void:
	if !_alive(e):
		return
	if lit:
		Game.light_up(e, 2.0)          # a glowing weapon lights what it hits
	# one attack hitting several enemies in the same frame counts as an area attack
	var frame := Engine.get_physics_frames()
	if frame != _hit_frame:
		_hit_frame = frame
		_hit_targets = 0
	_hit_targets += 1
	if _hit_targets >= 2:
		aoe = true
	var dir: Vector2 = (e.global_position - from).normalized()
	if dmg >= 5.0:
		Game.hit_stop(0.06)
	if "hit_from" in e:
		e.hit_from = from
	e.spell_damage(dmg * power, elem if elem != "" else element, aoe)
	if twist != "":
		_apply_twist(e, dmg * power)
	if !_alive(e):
		return
	if knock > 0.0:
		e.push(dir * knock, 0.12)
	if stun > 0.0:
		e.apply_slow(0.0, stun)

static func _apply_twist(e: Node, dmg: float) -> void:
	if !_alive(e):
		return
	var tree := e.get_tree()
	match twist:
		"bleed":
			bleed(tree, e, 3, dmg * 0.25)
		"chill":
			e.apply_slow(0.55, 1.5)
		"chain":
			var best = null
			for o in tree.get_nodes_in_group("enemy"):
				if o != e and _alive(o) and o.global_position.distance_to(e.global_position) <= 55.0 and (best == null or o.global_position.distance_to(e.global_position) < best.global_position.distance_to(e.global_position)):
					best = o
			if best != null:
				best.spell_damage(dmg * 0.4)
				WeaponFx.spawn(Game.world, "burst", best.global_position, Color(0.7, 0.8, 1.0), {"radius": 8.0, "life": 0.2})
		"lifesteal":
			for p in tree.get_nodes_in_group("player"):
				if is_instance_valid(p) and !p.get("remote_controlled"):
					p.heal(dmg * 0.06)
					break
		"thunder":
			_twist_hits += 1
			if _twist_hits % 4 == 0:
				WeaponFx.spawn(Game.world, "ring", e.global_position, Color(1.0, 0.95, 0.5), {"radius": 32.0, "life": 0.3})
				for o in enemies_in_circle(tree, e.global_position, 32.0):
					if o != e:
						o.spell_damage(dmg * 0.6, "", true)

## Hit trees and rocks. types limits by drop type ("stick" trees, "stone" rocks).
static func hit_breakables(tree: SceneTree, pos: Vector2, r: float, types: Array = []) -> void:
	for b in tree.get_nodes_in_group("breakable"):
		if !_alive(b) or b.global_position.distance_to(pos) > r:
			continue
		if types.is_empty() or b.drop_type in types:
			b.take_damage(pos)

## "Exposed" enemies take extra damage from some weapons. Stunned enemies count.
static func expose(e: Node, secs: float) -> void:
	e.set_meta("exposed_until", Time.get_ticks_msec() / 1000.0 + secs)

static func is_exposed(e: Node) -> bool:
	if e.get("slow_mult") != null and e.slow_mult <= 0.0 and e.slow_time > 0.0:
		return true
	return e.has_meta("exposed_until") and e.get_meta("exposed_until") > Time.get_ticks_msec() / 1000.0

static func clear_exposed(e: Node) -> void:
	if e.has_meta("exposed_until"):
		e.remove_meta("exposed_until")

## Telegraphed strike on the ground: a ring shows where it will land, then it hits.
static func ground_strike(tree: SceneTree, world: Node, center: Vector2, radius: float, delay: float, dmg: float, knock: float, color: Color, stun := 0.0, breakable_types: Array = [], elem := "", on_hit := Callable()) -> void:
	WeaponFx.spawn(world, "ring", center, color, {"radius": radius, "life": delay})
	await tree.create_timer(delay).timeout
	for e in enemies_in_circle(tree, center, radius):
		hit(e, dmg, center, knock, stun, elem, true)
		if on_hit.is_valid() and _alive(e):
			on_hit.call(e)                       # (e.g. mark the enemy that was hit)
	if !breakable_types.is_empty():
		hit_breakables(tree, center, radius, breakable_types)
	WeaponFx.spawn(world, "ring", center, color.lightened(0.3), {"radius": radius * 1.1, "life": 0.25})

## Repeated rings around the player (follows the player between pulses).
static func pulses(tree: SceneTree, world: Node, player: Node, dmg: float, radius: float, knock: float, stun: float, count: int, interval: float, color: Color) -> void:
	for i in count:
		if !is_instance_valid(player):
			return
		var pos: Vector2 = player.global_position
		WeaponFx.spawn(world, "ring", pos, color, {"radius": radius, "life": 0.25})
		for e in enemies_in_circle(tree, pos, radius):
			hit(e, dmg, pos, knock, stun, "", true)
		player.shake(1.5, 0.1)
		await tree.create_timer(interval).timeout

## Many telegraphed strikes scattered around a point over a duration.
static func rain(tree: SceneTree, world: Node, center: Vector2, radius: float, count: int, duration: float, dmg: float, strike_r: float, color: Color, stun := 0.0) -> void:
	for i in count:
		var p := center + Vector2.from_angle(randf() * TAU) * randf_range(0.0, radius)
		ground_strike(tree, world, p, strike_r, 0.45, dmg, 140.0, color, stun)
		await tree.create_timer(duration / count).timeout

## Damage over time: `ticks` hits of `dmg`, half a second apart.
static func bleed(tree: SceneTree, e: Node, ticks: int, dmg: float) -> void:
	for i in ticks:
		await tree.create_timer(0.5).timeout
		if !_alive(e):
			return
		e.spell_damage(dmg * power, element, false)

## A temporary patch on the ground (kind: "burn", "slow" or "heal"). Uses world/hazard.gd.
static func patch(world: Node, pos: Vector2, kind: String, radius: float, color: Color, secs: float, factor := 0.5) -> void:
	var h := Hazard.new()
	h.kind = kind
	h.radius = radius
	h.color = color
	h.factor = factor
	h.lifetime = secs
	h.position = pos
	world.add_child.call_deferred(h)
