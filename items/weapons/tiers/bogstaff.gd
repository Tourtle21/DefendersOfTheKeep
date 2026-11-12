extends RefCounted
## Bog Staff tiers (docs/weapon_tiers/bogstaff.md): 2 Festering, 3 Spore Pods, 4 Bog Beasts, 5 Miasma, 6 Swamp Lord.
## Mythic: ROT. Every poison hit adds a Rot stack to the enemy (meta "wt_rot" = {n, until}, max 5, gone 6 s after the last stack). Rot is visible as green bubbles
## (WeaponFx motes, count = stacks), poison ticks deal +10% per stack (WeaponUtil.rot_mult), and a fifth stack makes the enemy BURST into spores that rot its
## neighbours: bursts chain through a crowd, raise beasts, and the ultimate turns you into the swamp. The helpers rot_add / rot_stacks / rot_burst are public
## (the Witch Staff reuses Rot). Players are never hurt by anything here: the mud is a `slow` patch.

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const GREEN := Color(0.50, 0.85, 0.30)
const MUD := Color(0.25, 0.30, 0.12)
const SPORE := Color(0.80, 0.95, 0.40)
const ROT := Color(0.50, 0.30, 0.55)
const BS_ROT_MAX := 5
const BS_ROT_DECAY := 6.0
const BS_BURST_R := 36.0
const BS_BURST_MULT := 0.8
const BS_POD_EVERY := 3
const BS_BEASTS_MAX := 2
const BS_FOG_SECS := 8.0
const BS_LORD_SECS := 10.0
const BS_BLOOM_MULT := 0.8
const BS_FINISHER_EVERY := 6
const BS_LIGHT_BONUS := [0, 5, 10, 15, 20, 30]
const NAMES := ["", "Bog Staff", "Festering", "Spore Pods", "Bog Beasts", "Miasma", "Swamp Lord"]

static func palette() -> Array:
	return [GREEN, SPORE, ROT]

static func now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func equip(w) -> void:
	w._st = {"globs": 0, "pod": false, "ult_id": 0, "bubble": 0.0, "motes": 0.0, "lord_until": 0.0, "mud": 0.0, "lash": 0.0, "depth": 0}
	WeaponTiers.light_bonus(w, BS_LIGHT_BONUS)

static func lord(w) -> bool:
	return now() < float(w._st.get("lord_until", 0.0))

# ---- Rot ----
static func rot_stacks(e) -> int:
	if !Kit.alive(e) or !e.has_meta("wt_rot"):
		return 0
	var r = e.get_meta("wt_rot")
	if r is Dictionary and float(r.get("until", 0.0)) > now():
		return int(r.get("n", 0))
	return 0

## Adds `n` stacks. At the fifth stack (tier 3+) the enemy bursts.
static func rot_add(w, e, n: int) -> void:
	if !Kit.alive(e) or w.tier < 2:
		return
	var total := mini(BS_ROT_MAX, rot_stacks(e) + n)
	e.set_meta("wt_rot", {"n": total, "until": now() + BS_ROT_DECAY})
	if total >= BS_ROT_MAX and w.tier >= 3 and int(w._st.get("depth", 0)) < 3:
		e.set_meta("wt_rot", {"n": 0, "until": 0.0})
		w._st.depth = int(w._st.depth) + 1
		rot_burst(w, e)
		w._st.depth = int(w._st.depth) - 1

## The spore burst: a cloud of r 36 that hurts and rots everything inside (and tier 4 raises a beast).
static func rot_burst(w, e) -> void:
	var at: Vector2 = e.global_position
	w.fx("burst", at, SPORE, {"radius": BS_BURST_R * 0.6, "life": 0.25})
	w.fx("motes", at, SPORE, {"radius": BS_BURST_R * 0.8, "count": 10, "rise": 14.0, "life": 0.6})
	w.fx("shards", at, GREEN, {"radius": BS_BURST_R, "count": 6, "life": 0.3})
	for o in WeaponUtil.enemies_in_circle(w.get_tree(), at, BS_BURST_R):
		if o == e:
			continue
		WeaponUtil.hit(o, WeaponTiers.H(w) * BS_BURST_MULT, at, 0.0, 0.0, "", true, true)
		rot_add(w, o, 2)
	if w.tier >= 4:
		_beast(w, at)

## A bog beast crawls toward the nearest enemy (at most 2 alive, 4 during Swamp Lord).
static func _beast(w, at: Vector2) -> void:
	var cap := 4 if lord(w) else BS_BEASTS_MAX
	var pid: int = w.player.get_instance_id()
	var alive_n := 0
	for n in w.get_tree().get_nodes_in_group("net"):
		if n is WeaponProjectile and n.owner_id == pid and n.style == "glob" and n.size >= 2.4:
			alive_n += 1
	if alive_n >= cap:
		return
	var tgt = WeaponUtil.nearest(w.get_tree(), at, 160.0)
	var d: Vector2 = (tgt.global_position - at).normalized() if tgt != null else w.aim
	WeaponProjectile.shoot(w.game_world(), at + d * 6.0, d, 110.0, WeaponTiers.H(w), GREEN, 1.6, 0, 60.0, {"style": "glob", "size": 2.4, "homing": 0.6, "burst_r": 28.0, "burst_mult": 0.5, "wobble": 6.0, "owner_id": pid, "trail": 4})

## A hit of the staff rots; a kill raises a beast (tier 4+).
static func on_hit(w, e, _dmg: float) -> void:
	if w.tier < 2 or !is_instance_valid(e):
		return
	if float(e.health) <= 0.0:                                         # a kill (the enemy is already leaving the tree)
		if w.tier >= 4:
			_beast(w, e.global_position)
		return
	if w.verb() == "attack":
		w.fx("burst", e.global_position, SPORE, {"radius": 8.0, "life": 0.2})
	rot_add(w, e, 1)

# ---- every frame: bubbles, motes, the Swamp Lord ----
static func tick(w, delta: float) -> void:
	if w.tier < 2:
		return
	var t := now()
	w._st.bubble = float(w._st.bubble) + delta
	if float(w._st.bubble) >= 0.4:                                   # two spore motes rise from the staff top
		w._st.bubble = 0.0
		w.fx("motes", w.player.global_position + w.aim * (w.reach + 6.0), SPORE, {"radius": 3.0, "count": 2, "rise": 10.0, "life": 0.5})
	w._st.motes = float(w._st.motes) + delta
	if float(w._st.motes) >= 0.5:                                    # Rot bubbles over up to six rotting enemies near you
		w._st.motes = 0.0
		var shown := 0
		for e in w.get_tree().get_nodes_in_group("enemy"):
			if shown >= 6:
				break
			var n := rot_stacks(e)
			if n > 0 and e.global_position.distance_to(w.player.global_position) < 240.0:
				shown += 1
				w.fx("motes", e.global_position + Vector2(0, -12), GREEN, {"radius": 4.0, "count": n, "rise": 8.0, "life": 0.5})
	if lord(w):
		if t - float(w._st.mud) >= 1.0:                              # the mud follows you
			w._st.mud = t
			WeaponUtil.patch(w.game_world(), w.player.global_position, "slow", 60.0, Color(0.25, 0.30, 0.12, 0.5), 1.2, 0.5)
		if t - float(w._st.lash) >= 1.0:
			w._st.lash = t
			_lash(w)

## Six great tendrils lash the six enemies with the most Rot.
static func _lash(w) -> void:
	w._claim()
	var list := []
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), w.player.global_position, 160.0):
		if rot_stacks(e) > 0:
			list.append(e)
	list.sort_custom(func(a, b): return rot_stacks(a) > rot_stacks(b))
	for e in list.slice(0, 6):
		var at: Vector2 = e.global_position
		w.fx("bolt", at + Vector2(0, 70), GREEN, {"dir": Vector2.UP, "length": 70.0, "width": 4.0, "life": 0.3})
		WeaponUtil.hit(e, WeaponTiers.H(w), at, 0.0, 0.0, "", true, true)
		WeaponUtil.stun(e, 0.4)

# ---- attack ----
static func pre_attack(w) -> void:
	w._st.globs = int(w._st.globs) + 1
	w._st.pod = w.tier >= 3 and (lord(w) or int(w._st.globs) % BS_POD_EVERY == 0)

static func attack(w) -> void:
	if w.tier >= 6 and int(w._st.globs) % BS_FINISHER_EVERY == 0:
		var o: Vector2 = w.player.global_position
		var dir: Vector2 = w.aim
		w.fx("cone", o, SPORE, {"radius": 60.0, "dir": dir, "half_angle": 0.5, "life": 0.3, "col2": GREEN})
		w.fx("motes", o + dir * 30.0, SPORE, {"radius": 22.0, "count": 12, "rise": 6.0, "life": 0.5})
		for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, dir, 60.0, rad_to_deg(0.5)):
			WeaponUtil.hit(e, WeaponTiers.H(w) * 0.6, o, 40.0, 0.0, "", true, true)
			rot_add(w, e, 2)

# ---- ability: Mire ----
static func ability(w) -> void:
	if w.tier < 2:
		return
	_mire(w, w.cursor_target(110.0))

static func _mire(w, c: Vector2) -> void:
	var h := WeaponTiers.H(w)
	w.fx("ripple", c, GREEN, {"radius": 44.0, "rings": 2, "life": 0.5})
	w.fx("motes", c, SPORE, {"radius": 38.0, "count": 10, "rise": 20.0, "life": 0.8})
	if w.tier >= 3:                                                  # three spore pods around the centre
		var rot_hit := func(e): rot_add(w, e, 1)
		for k in 3:
			var p: Vector2 = c + Vector2.from_angle(float(k) * TAU / 3.0 + 0.5) * 28.0
			w.fx("motes", p, SPORE, {"radius": 12.0, "count": 6, "rise": 14.0, "life": 0.7})
			WeaponUtil.ground_strike(w.get_tree(), w.game_world(), p, 14.0, 0.6, h * 0.6, 0.0, GREEN, 0.0, [], "", rot_hit)
	for k in 6:
		if !await WeaponTiers.pause(w, 1.0):
			return
		if k < 4:                                                    # the mud ticks: 2 Rot a second for 4 s
			for e in WeaponUtil.enemies_in_circle(w.get_tree(), c, 44.0):
				rot_add(w, e, 2)
		if w.tier >= 4:                                              # mud hands grab the enemy nearest the centre
			var near = WeaponUtil.nearest(w.get_tree(), c, 44.0)
			if near != null:
				var at: Vector2 = near.global_position
				w.fx("bolt", at + Vector2(0, 30), GREEN, {"dir": Vector2.UP, "length": 30.0, "width": 3.0, "life": 0.3})
				WeaponUtil.hit(near, h * 0.5, at, 0.0, 0.0, "", true, true)
				WeaponUtil.stun(near, 0.5)
				rot_add(w, near, 2)

# ---- dash: Mud Trail ----
static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	var from: Vector2 = o - w.aim * 50.0                               # the old hop has already blinked 50 px
	for k in 3:
		WeaponUtil.patch(w.game_world(), from.lerp(o, float(k + 1) / 4.0), "slow", 16.0, Color(0.25, 0.30, 0.12, 0.6), 3.0, 0.5)
	w.fx("streak", from, GREEN, {"dir": w.aim, "length": 50.0, "width": 6.0, "life": 0.25, "col2": SPORE})
	w.fx("burst", o, SPORE, {"radius": 22.0, "life": 0.25})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 30.0):
		WeaponUtil.hit(e, WeaponTiers.H(w) * 0.8, o, 60.0, 0.0, "", true, true)
		rot_add(w, e, 2)

# ---- ultimate: Swamp Swell, Miasma, Swamp Lord ----
static func pre_ultimate(w) -> void:
	w._st.ult_id = int(w._st.ult_id) + 1

static func ultimate(w) -> void:
	var my: int = w._st.ult_id
	var o: Vector2 = w.player.global_position
	if w.tier >= 3:
		w.fx("sigil", o, SPORE, {"radius": 100.0, "count": 6, "spin": 1.5, "life": 0.3, "col2": GREEN})
	if w.tier >= 5:
		_miasma(w, my, o)
	if w.tier >= 6:
		_swamp_lord(w, my)

## Tier 5: 8 s of toxic fog (r 125): a Rot a second on everything inside and +20% damage taken from every source.
static func _miasma(w, my: int, o: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.3) or int(w._st.ult_id) != my:
		return
	var t := 0.0
	while t < BS_FOG_SECS:
		w.fx("vortex", o, GREEN, {"radius": 125.0, "count": 3, "spin": 2.0, "life": 0.8})
		w.fx("motes", o, SPORE, {"radius": 120.0, "count": 14, "rise": 16.0, "life": 0.8})
		for k in 2:
			for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 125.0):
				if k == 0:
					rot_add(w, e, 1)
				e.set_meta("toxic_until", now() + 2.0)
			if !await WeaponTiers.pause(w, 0.4) or int(w._st.ult_id) != my:
				return
		t += 0.8

## FINALE + TRANSFORMATION Swamp Lord (10 s): every glob a pod, the mud follows you, tendrils lash, a final Rot Bloom.
static func _swamp_lord(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 4.3) or int(w._st.ult_id) != my:
		return
	w._st.lord_until = now() + BS_LORD_SECS
	w.fx("flash", w.player.global_position, GREEN, {"radius": 30.0, "life": 0.3})
	Sfx.play("ultimate", 0.05, 0.8)
	if !await WeaponTiers.pause(w, BS_LORD_SECS) or int(w._st.ult_id) != my:
		return
	var o: Vector2 = w.player.global_position
	w.fx("flash", o, SPORE, {"radius": 60.0, "life": 0.4})
	w.fx("ripple", o, GREEN, {"radius": 140.0, "rings": 3, "life": 0.7})
	w.player.shake(6.0, 0.35)
	Sfx.play("ultimate", 0.05)
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 140.0):
		if rot_stacks(e) > 0:
			WeaponUtil.hit(e, WeaponTiers.H(w) * BS_BLOOM_MULT, o, 0.0, 0.0, "", true, true)
			w.fx("burst", e.global_position, SPORE, {"radius": 16.0, "life": 0.3})
			e.set_meta("wt_rot", {"n": 0, "until": 0.0})
