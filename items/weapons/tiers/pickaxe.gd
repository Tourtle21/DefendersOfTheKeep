extends RefCounted
## Pickaxe tiers (docs/weapon_tiers/pickaxe.md): 2 Shatter, 3 Heavy Mine, 4 Rubble Trail, 5 Aftershocks, 6 Rockfall. Common: brown dust, cracks and
## falling rocks; every new thing either breaks more rocks or shoves enemies. A Tool: the animation hitbox does the basic damage.

const STONE := Color(0.72, 0.55, 0.35)
const DUST := Color(0.90, 0.78, 0.55)
const SPARK := Color(1.0, 0.90, 0.50)
const ROCK := Color(0.45, 0.42, 0.40)
const DEBRIS_R := 1.6
const DEBRIS_MULT := 0.5
const HEAVY_EVERY := 3
const TRAIL_PATCHES := 3
const AFTERSHOCKS := [[0.5, 0.7], [1.0, 0.5]]
const ROCKS := 4
const ROCK_MULT := 1.25
const NAMES := ["", "Pickaxe", "Shatter", "Heavy Mine", "Rubble Trail", "Aftershocks", "Rockfall"]

static func palette() -> Array:
	return [STONE, DUST, SPARK]

static func equip(w) -> void:
	w._st = {"swings": 0, "last_ms": -1000, "flash_until": 0.0, "ult_id": 0}

static func tick(w, _delta: float) -> void:
	if w.tier < 2:
		return
	var left: float = float(w._st.get("flash_until", 0.0)) - Time.get_ticks_msec() / 1000.0
	w.modulate = Color(1, 1, 1).lerp(Color(1.6, 1.45, 1.0), clampf(left / 0.1, 0.0, 1.0))

static func attack(w) -> void:
	var now := Time.get_ticks_msec()
	if now - int(w._st.get("last_ms", -1000)) < 250:
		return
	w._st.last_ms = now
	w._st.swings = int(w._st.get("swings", 0)) + 1
	if w.tier < 2:
		return
	_swing_riders(w, w.tier >= 3 and int(w._st.swings) % HEAVY_EVERY == 0)

static func _swing_riders(w, heavy: bool) -> void:
	if !await WeaponTiers.pause(w, 0.12):
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, dir, 26.0 * w.area(), 60.0):
		w.fx("shards", e.global_position, DUST, {"radius": 12.0, "count": 2, "life": 0.25})
	for b in w.get_tree().get_nodes_in_group("breakable"):       # Shatter: the head flashes on every rock it breaks
		if is_instance_valid(b) and b.global_position.distance_to(o + dir * 18.0) <= 20.0:
			w.fx("burst", b.global_position, SPARK, {"radius": 8.0, "life": 0.2})
			w._st.flash_until = Time.get_ticks_msec() / 1000.0 + 0.1
	if heavy:
		var at: Vector2 = o + dir * 20.0
		w.fx("shock", at, DUST, {"radius": 30.0 * w.area(), "thick": 4.0, "life": 0.3, "col2": SPARK})
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), at, 30.0 * w.area()):
			WeaponUtil.hit(e, WeaponTiers.H(w), at, 140.0, 0.0, "", true)
		for i in 2:
			WeaponUtil.hit_breakables(w.get_tree(), at, 30.0 * w.area())
		Sfx.play("thump", 0.1)

static func strike_r(w) -> float:
	return 24.0 * w.area() * (1.0 + 0.25 * maxi(0, w.tier - 2))

## Tier 2 Shatter: Seismic Strike throws debris in a wider ring (the core is hit by the strike itself, 0.5 s after the click).
static func ability(w) -> void:
	if w.tier < 2:
		return
	_debris(w, w._st.get("strike_c", w.player.global_position))

static func _debris(w, c: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.5):
		return
	var r: float = strike_r(w)
	w.fx("crack", c, ROCK, {"radius": r * 1.3, "count": 4, "life": 0.6})
	w.fx("shards", c, STONE, {"radius": r * DEBRIS_R, "count": 6, "life": 0.4})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), c, r * DEBRIS_R):
		if e.global_position.distance_to(c) > r:
			WeaponUtil.hit(e, WeaponTiers.H(w) * DEBRIS_MULT, c, 100.0, 0.0, "", true)

## Tier 4 Rubble Trail: the dash line is a dusty streak that leaves slowing rubble and shoves what it passes.
static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	w.fx("streak", o, DUST, {"dir": dir, "length": 72.0, "width": 7.0, "life": 0.3, "col2": SPARK})
	for i in TRAIL_PATCHES:
		WeaponUtil.patch(w.game_world(), o + dir * (18.0 * float(i + 1)), "slow", 14.0, Color(STONE, 0.5), 2.5, 0.6)
	var side := dir.orthogonal()
	for e in WeaponUtil.enemies_in_line(w.get_tree(), o, dir, 72.0, 12.0):
		var s: float = signf((e.global_position - o).dot(side))
		e.push(side * (s if s != 0.0 else 1.0) * 120.0, 0.15)
	w.fx("motes", o + dir * 36.0, DUST, {"radius": 14.0, "count": 6, "rise": 14.0, "life": 0.5})

static func ultimate(w) -> void:
	w._st.ult_id = int(w._st.get("ult_id", 0)) + 1
	var o: Vector2 = w.player.global_position
	var er: float = 150.0 * w.area()
	w.fx("sigil", o, STONE, {"radius": 60.0, "count": 6, "spin": 1.2, "life": 0.25, "col2": SPARK})
	if w.tier >= 5:
		_aftershocks(w, int(w._st.ult_id), o, er)

static func _aftershocks(w, my: int, o: Vector2, er: float) -> void:
	for a in AFTERSHOCKS:
		_aftershock(w, my, o, er * float(a[1]), 0.6 + float(a[0]))
	if w.tier >= 6:
		_rockfall(w, my, o, er, 0.6 + 1.7)

static func _aftershock(w, my: int, o: Vector2, r: float, at: float) -> void:
	if !await WeaponTiers.pause(w, at - 0.35):           # the ring shows first
		return
	w.fx("shock", o, STONE, {"radius": r, "thick": 5.0, "life": 0.35, "col2": SPARK})
	w.fx("crack", o, ROCK, {"radius": r, "count": 8, "life": 1.0})
	if !await WeaponTiers.pause(w, 0.35) or int(w._st.ult_id) != my:
		return
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, r):
		WeaponUtil.hit(e, WeaponTiers.H(w) * 0.5, o, 0.0, 0.0, "", true)
		WeaponUtil.stun(e, 0.6)
	for i in 2:
		WeaponUtil.hit_breakables(w.get_tree(), o, r)
	w.player.shake(2.0, 0.15)

## FINALE Rockfall: four boulders crash down on enemies in the quake (random points if there are none).
static func _rockfall(w, my: int, o: Vector2, er: float, at: float) -> void:
	if !await WeaponTiers.pause(w, at):
		return
	if int(w._st.ult_id) != my:
		return
	var targets: Array = []
	for e in WeaponUtil.random_enemies(w.get_tree(), o, er, ROCKS):
		targets.append(e.global_position)
	while targets.size() < ROCKS:
		targets.append(o + Vector2.from_angle(float(targets.size()) * TAU / float(ROCKS) + 0.6) * er * 0.5)
	for p in targets:
		w.fx("fall", p, ROCK, {"radius": 5.0, "height": 70.0, "rise": 14.0, "life": 0.4, "core": SPARK})
		_boulder(w, p)
	Sfx.play("big_hit", 0.05)
	w.player.shake(4.5, 0.3)

static func _boulder(w, p: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.4):
		return
	w.fx("flash", p, SPARK, {"radius": 20.0, "life": 0.25})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), p, 14.0):
		WeaponUtil.hit(e, WeaponTiers.H(w) * ROCK_MULT, p, 200.0, 0.0, "", true)
	Sfx.play("big_hit", 0.05)
