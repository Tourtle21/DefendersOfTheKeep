extends RefCounted
## Small helpers shared by the tier modules of the fused weapons (items/weapons/tiers/*.gd): tethers, pulls, executions, a segment test.
## Everything visible goes through WeaponFx (mirrored to LAN clients); nothing here keeps state of its own.

static func alive(e) -> bool:
	return e != null and is_instance_valid(e) and !e.is_queued_for_deletion()

static func is_boss(e) -> bool:
	return alive(e) and e.is_in_group("boss")

## Pulls `e` toward `to` at `speed` px/s for `secs` (a boss only feels 40% of it).
static func pull(e, to: Vector2, speed: float, secs: float) -> void:
	if !alive(e):
		return
	var d: Vector2 = to - e.global_position
	if d.length() < 2.0:
		return
	if is_boss(e):
		speed *= 0.4
	e.push(d.normalized() * minf(speed, d.length() / maxf(secs, 0.05)), secs)

## Shoves `e` away from `from`.
static func shove(e, from: Vector2, speed: float, secs: float) -> void:
	if !alive(e):
		return
	if is_boss(e):
		speed *= 0.4
	e.push((e.global_position - from).normalized() * speed, secs)

## Kills `e` outright when it is at or below `frac` of its health (never a boss). True when it did.
static func execute(e, frac: float) -> bool:
	if !alive(e) or is_boss(e):
		return false
	if float(e.health) <= float(e.max_health) * frac:
		e.spell_damage(float(e.health) + 1.0, "", false)
		return true
	return false

static func line(w, from: Vector2, to: Vector2, col: Color, width := 2.0, life := 0.2) -> void:
	var d := to - from
	if d.length() < 1.0:
		return
	w.fx("line", from, col, {"dir": d.normalized(), "length": d.length(), "width": width, "life": life})

static func bolt(w, from: Vector2, to: Vector2, col: Color, width := 1.5, life := 0.18) -> void:
	var d := to - from
	if d.length() < 1.0:
		return
	w.fx("bolt", from, col, {"dir": d.normalized(), "length": d.length(), "width": width, "life": life})

## A tether between the holder and `target` that is redrawn for `secs` (a line follows both ends).
static func tether(w, target, secs: float, col: Color, width := 2.0) -> void:
	var n := int(secs / 0.15)
	for i in n:
		if !WeaponTiers.alive(w) or !alive(target):
			return
		line(w, w.player.global_position, target.global_position, col, width, 0.2)
		if !await WeaponTiers.pause(w, 0.15):
			return

## Enemies within r of the segment a-b.
static func near_segment(tree: SceneTree, a: Vector2, b: Vector2, r: float) -> Array:
	var out := []
	for e in tree.get_nodes_in_group("enemy"):
		if alive(e) and Geometry2D.get_closest_point_to_segment(e.global_position, a, b).distance_to(e.global_position) <= r + float(e.get("hit_radius") if e.get("hit_radius") != null else 0.0):
			out.append(e)
	return out

## The `n` nearest enemies to pos within r.
static func nearest_n(tree: SceneTree, pos: Vector2, r: float, n: int) -> Array:
	var all := WeaponUtil.enemies_in_circle(tree, pos, r)
	all.sort_custom(func(a, b): return a.global_position.distance_to(pos) < b.global_position.distance_to(pos))
	return all.slice(0, n)

## Waits until the old coroutine verb has stopped adding to `list` (or `max_secs` passed). Returns the final size.
static func settle(w, list: Array, want: int, max_secs: float) -> int:
	var last := -1
	var still := 0.0
	var t := 0.0
	while t < max_secs:
		if !await WeaponTiers.pause(w, 0.1):
			return -1
		t += 0.1
		if list.size() == last:
			still += 0.1
		else:
			still = 0.0
			last = list.size()
		if last >= want or still >= 0.35:
			break
	return list.size()
