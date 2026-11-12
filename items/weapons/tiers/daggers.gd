extends RefCounted
## Twin Daggers tiers (docs/weapon_tiers/daggers.md): 2 Fan of Knives, 3 Flurry, 4 Phantom Step, 5 Shadow Clones, 6 Thousand Cuts.
## Uncommon: speed and trickery on the exposed state; each tier adds a fast, small, many-hit thing.

const STEEL := Color(0.85, 0.90, 1.0)
const SHADOW := Color(0.45, 0.30, 0.70)
const BLOOD := Color(1.0, 0.30, 0.30)
const SILVER := Color(0.95, 0.97, 1.0)
const FLURRY_EVERY := 3
const FLURRY_MULT := 0.5
const PHANTOM_T := 0.6
const PHANTOM_MULT := 0.8
const CLONE_N := 2
const CLONE_EVERY := 0.6
const CLONE_MULT := 0.5
const FINALE_HITS := 6
const FINALE_MULT := 0.35
const FINALE_MAX := 8
const FINISHER_EVERY := 6
const NAMES := ["", "Twin Daggers", "Fan of Knives", "Flurry", "Phantom Step", "Shadow Clones", "Thousand Cuts"]

static func palette() -> Array:
	return [STEEL, SHADOW, SILVER]

static func equip(w) -> void:
	w._st = {"slashes": 0, "motes_t": 0.0, "ult_id": 0}

## Tier 2: exposed enemies near you show violet motes (an effect, never node meta drawn on clients).
static func tick(w, delta: float) -> void:
	if w.tier < 2:
		return
	w._st.motes_t = float(w._st.get("motes_t", 0.0)) - delta
	if float(w._st.motes_t) > 0.0:
		return
	w._st.motes_t = 0.5
	var n := 0
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), w.player.global_position, 120.0):
		if n >= 4:
			break
		if WeaponUtil.is_exposed(e):
			n += 1
			w.fx("motes", e.global_position + Vector2(0, -8), SHADOW, {"radius": 6.0, "count": 2, "rise": 6.0, "life": 0.5})

## A backstab (the old attack hit an exposed enemy for 3x) throws a cut.
static func on_hit(w, e, dmg: float) -> void:
	if w.tier < 2 or !is_instance_valid(e) or w.verb() != "attack":
		return
	if dmg >= WeaponTiers.H(w) * 2.9:
		w.fx("cut", e.global_position, BLOOD, {"radius": 12.0, "spin": 0.3, "life": 0.3})

static func attack(w) -> void:
	w._st.slashes = int(w._st.get("slashes", 0)) + 1
	var n: int = int(w._st.slashes)
	if w.tier >= 3 and n % FLURRY_EVERY == 0:
		_flurry(w)
	if w.tier >= 6 and n % FINISHER_EVERY == 0:
		var o: Vector2 = w.player.global_position
		for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, w.aim, 28.0, 55.0):
			w.fx("cut", e.global_position, SILVER, {"radius": 20.0, "spin": 0.5, "life": 0.35})
			WeaponUtil.hit(e, WeaponTiers.H(w), o, 60.0, 0.0, "", true)
			if is_instance_valid(e):
				WeaponUtil.expose(e, 1.0)

## Tier 3 Flurry: two more cuts follow the slash, 0.1 s apart.
static func _flurry(w) -> void:
	for i in 2:
		if !await WeaponTiers.pause(w, 0.1):
			return
		var o: Vector2 = w.player.global_position
		w.fx("slash", o, STEEL, {"radius": 26.0, "dir": w.aim.rotated(0.35 if i == 0 else -0.35), "half_angle": 0.7, "thick": 4.0, "life": 0.15, "col2": SHADOW})
		for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, w.aim, 28.0, 55.0):
			WeaponUtil.hit(e, WeaponTiers.H(w) * FLURRY_MULT, o, 40.0)

## Tier 4 Phantom Step: a phantom stays at the start point and strikes when it vanishes.
static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	w.fx("streak", o, SHADOW, {"dir": w.aim, "length": 44.0, "width": 6.0, "life": 0.3, "col2": SILVER})
	w.fx("orbit", o, SHADOW, {"radius": 8.0, "count": 2, "spin": 6.0, "shape": "blade", "life": PHANTOM_T})
	_phantom(w, o)

static func _phantom(w, o: Vector2) -> void:
	if !await WeaponTiers.pause(w, PHANTOM_T):
		return
	var n := 0
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 26.0):
		WeaponUtil.hit(e, WeaponTiers.H(w) * PHANTOM_MULT, o, 40.0, 0.0, "", true)
		if is_instance_valid(e):
			WeaponUtil.expose(e, 2.0)
			if n < 3:
				n += 1
				w.fx("cut", e.global_position, SHADOW, {"radius": 12.0, "life": 0.3})
	w.fx("burst", o, SHADOW, {"radius": 14.0, "life": 0.25})

static func ultimate(w) -> void:
	w._st.ult_id = int(w._st.get("ult_id", 0)) + 1
	var my: int = w._st.ult_id
	w.fx("sigil", w.player.global_position, SHADOW, {"radius": 90.0, "count": 6, "spin": 1.2, "life": 0.25, "col2": SILVER})
	if w.tier >= 5:
		_clones(w, my)

## Tier 5 Shadow Clones: two clones circle you for the six seconds of the mark and throw knives at exposed enemies.
## Tier 6 FINALE Thousand Cuts when the mark ends.
static func _clones(w, my: int) -> void:
	var t := 0.0
	var next_orbit := 0.0
	var next_throw := CLONE_EVERY
	while t < 6.0:
		if !await WeaponTiers.pause(w, 0.1) or int(w._st.ult_id) != my:
			return
		t += 0.1
		if t >= next_orbit:
			next_orbit += 0.5
			w.fx("orbit", w.player.global_position, SHADOW, {"radius": 18.0, "count": CLONE_N, "spin": 4.0, "shape": "blade", "life": 0.6})
		if t >= next_throw - 0.001:
			next_throw += CLONE_EVERY
			_throws(w)
	if w.tier >= 6:
		_finale(w, my)

static func _throws(w) -> void:
	var o: Vector2 = w.player.global_position
	var hit: Array = []
	for i in CLONE_N:
		var best = null
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 120.0):
			if WeaponUtil.is_exposed(e) and !(e in hit) and (best == null or e.global_position.distance_to(o) < best.global_position.distance_to(o)):
				best = e
		if best == null:
			return
		hit.append(best)
		w.fx("bolt", o, SHADOW, {"dir": (best.global_position - o).normalized(), "length": o.distance_to(best.global_position), "width": 1.0, "life": 0.15})
		WeaponUtil.hit(best, WeaponTiers.H(w) * CLONE_MULT, o, 0.0, 0.0, "", false, true)
		if is_instance_valid(best):
			WeaponUtil.expose(best, 2.0)

static func _finale(w, my: int) -> void:
	var o: Vector2 = w.player.global_position
	var targets: Array = []
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 150.0):
		if WeaponUtil.is_exposed(e):
			targets.append(e)
	targets.sort_custom(func(a, b): return a.global_position.distance_to(o) < b.global_position.distance_to(o))
	targets = targets.slice(0, FINALE_MAX)
	w.player.shake(4.0, 0.3)
	Sfx.play("big_hit", 0.05)
	for i in FINALE_HITS:
		w._claim()
		for k in targets.size():
			var e = targets[k]
			if !is_instance_valid(e) or e.is_queued_for_deletion():
				continue
			WeaponUtil.hit(e, WeaponTiers.H(w) * FINALE_MULT, o, 0.0, 0.0, "", true, true)
			if i % 2 == 1 and k < 5:
				w.fx("cut", e.global_position, SILVER, {"radius": 14.0, "spin": float(i) * 0.4, "life": 0.25})
		if i < FINALE_HITS - 1 and !await WeaponTiers.pause(w, 0.1):
			return
	for e in targets:
		if is_instance_valid(e):
			w.fx("burst", e.global_position, SILVER, {"radius": 12.0, "life": 0.25})
	w.fx("flash", o, SHADOW, {"radius": 18.0, "life": 0.2})
