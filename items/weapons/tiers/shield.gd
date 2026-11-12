extends RefCounted
## Shield tiers (docs/weapon_tiers/shield.md): 2 Reflection, 3 Shield Slam, 4 Ram, 5 Citadel, 6 Aegis Eternal.
## Rare: everything is conditional. The Shield asks you to read incoming attacks; the upgrades make the payoffs of the parry bigger rather than wider.

const BLUE := Color(0.50, 0.70, 1.0)
const GOLD := Color(1.0, 0.90, 0.40)
const WHITE := Color(0.95, 0.97, 1.0)
const SHADOW := Color(0.20, 0.30, 0.55)
const SLAM_EVERY := 3
const RETAL_BASHES := 3
const RETAL_MULT := 1.5
const RAM_MULT := 0.8
const NOVA_MULT := 1.5
const FINALE_MULT := 1.2
const FINISHER_EVERY := 6
const NAMES := ["", "Shield", "Reflection", "Shield Slam", "Ram", "Citadel", "Aegis Eternal"]

static func palette() -> Array:
	return [BLUE, GOLD, WHITE]

static func equip(w) -> void:
	w._st = {"bashes": 0, "mult": 1.0, "retal": 0, "retal_until": 0.0, "bastion_until": 0.0, "ult_id": 0}

## The aura shows the parry window (state2) and the Retaliation dots (state); the Citadel eats shots that come within 40 px.
static func tick(w, _delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if w._aura != null and is_instance_valid(w._aura):
		w._aura.state2 = 1.0 if w.player.parry_time > 0.0 else 0.0
		if float(w._st.get("retal_until", 0.0)) < now:
			w._st.retal = 0
		w._aura.state = float(w._st.get("retal", 0))
	if w.tier >= 5 and float(w._st.get("bastion_until", 0.0)) > now:
		for sh in w.get_tree().get_nodes_in_group("enemy_shot"):
			if is_instance_valid(sh) and !sh.is_queued_for_deletion() and sh.global_position.distance_to(w.player.global_position) <= 40.0:
				w.fx("burst", sh.global_position, BLUE, {"radius": 8.0, "life": 0.2})
				sh.queue_free()

static func on_hit(w, e, _dmg: float) -> void:
	if w.tier < 2 or !is_instance_valid(e) or w.verb() != "attack":
		return
	w.fx("shards", e.global_position, BLUE, {"radius": 12.0, "count": 3, "life": 0.25})

## Before the bash: Retaliation makes it hit harder.
static func pre_attack(w) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	w._st.mult = 1.0
	if w.tier >= 4 and int(w._st.get("retal", 0)) > 0 and float(w._st.get("retal_until", 0.0)) > now:
		w._st.mult = RETAL_MULT
		w._st.retal = int(w._st.retal) - 1

static func attack(w) -> void:
	w._st.bashes = int(w._st.get("bashes", 0)) + 1
	var n: int = int(w._st.bashes)
	var o: Vector2 = w.player.global_position
	if w.tier >= 3 and n % SLAM_EVERY == 0:
		var at: Vector2 = o + w.aim * 24.0
		w.fx("cone", o, BLUE, {"radius": 34.0, "dir": w.aim, "half_angle": 1.0, "life": 0.25, "col2": WHITE})
		w.fx("shock", at, GOLD, {"radius": 20.0, "thick": 4.0, "life": 0.3, "col2": WHITE})
		for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, w.aim, 34.0, 57.0):
			WeaponUtil.hit(e, WeaponTiers.H(w), o, 360.0, 0.9, "", true)
	if w.tier >= 6 and n % FINISHER_EVERY == 0:
		_counter(w)

static func _counter(w) -> void:
	if !await WeaponTiers.pause(w, 0.12):
		return
	var o: Vector2 = w.player.global_position
	w.fx("streak", o, WHITE, {"dir": w.aim, "length": 50.0, "width": 5.0, "life": 0.25, "col2": GOLD})
	for e in WeaponUtil.enemies_in_line(w.get_tree(), o, w.aim, 50.0, 10.0):
		WeaponUtil.hit(e, WeaponTiers.H(w), o, 200.0, 0.0, "", true)

## Runs inside the parry's shockwave (shield.gd _on_parry).
static func parry(w, from: Vector2) -> void:
	if w.tier < 2:
		return
	var o: Vector2 = w.player.global_position
	w.fx("ripple", o, GOLD, {"radius": 56.0, "rings": 2, "life": 0.5})
	w.fx("star", o, WHITE, {"radius": 24.0, "count": 6, "spin": 1.5, "life": 0.4})
	for sh in w.get_tree().get_nodes_in_group("enemy_shot"):          # Reflection: shots near you go back
		if is_instance_valid(sh) and sh.global_position.distance_to(o) <= 80.0:
			EnemyProjectile.reflect(sh)
			w.fx("burst", sh.global_position, GOLD, {"radius": 8.0, "life": 0.2})
	if w.tier >= 4:                                                    # Retaliation
		var attacker = WeaponUtil.nearest(w.get_tree(), from, 40.0)
		if attacker != null:
			WeaponUtil.expose(attacker, 3.0)
		w._st.retal = RETAL_BASHES
		w._st.retal_until = Time.get_ticks_msec() / 1000.0 + 4.0

## Tier 4 Ram: the charge carries enemies along and ends in a shock.
static func dash(w) -> void:
	if w.tier < 4:
		return
	w.fx("streak", w.player.global_position, BLUE, {"dir": w.aim, "length": 55.0, "width": 10.0, "life": 0.3, "col2": WHITE})
	_ram_end(w)

static func dash_hit(w, e) -> void:
	if w.tier >= 4 and is_instance_valid(e):
		e.push(w.aim * 260.0, 0.2)

static func _ram_end(w) -> void:
	if !await WeaponTiers.pause(w, 0.24):
		return
	var p: Vector2 = w.player.global_position
	w.fx("shock", p, BLUE, {"radius": 36.0, "thick": 5.0, "life": 0.35, "col2": WHITE})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), p, 36.0):
		WeaponUtil.hit(e, WeaponTiers.H(w) * RAM_MULT, p, 0.0, 0.0, "", true)
		WeaponUtil.stun(e, 0.8)

static func ultimate(w) -> void:
	w._st.ult_id = int(w._st.get("ult_id", 0)) + 1
	w.fx("sigil", w.player.global_position, BLUE, {"radius": 46.0, "count": 6, "spin": 1.5, "life": 0.25, "col2": WHITE})
	if w.tier >= 6:
		_finale(w, int(w._st.ult_id))

## FINALE Aegis Eternal: when the five seconds end the shield bursts.
static func _finale(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 5.0) or int(w._st.ult_id) != my:
		return
	var o: Vector2 = w.player.global_position
	w.fx("flash", o, GOLD, {"radius": 80.0, "life": 0.4})
	w.fx("shards", o, BLUE, {"radius": 90.0, "count": 12, "life": 0.5})
	w.fx("ripple", o, WHITE, {"radius": 90.0, "rings": 3, "life": 0.6})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 80.0):
		WeaponUtil.hit(e, WeaponTiers.H(w) * FINALE_MULT, o, 360.0, 0.0, "", true)
		WeaponUtil.stun(e, 1.0)
	w.player.shield_time = maxf(w.player.shield_time, 0.6)
	w.player.shake(5.5, 0.4)
	Sfx.play("big_hit", 0.05)
	Sfx.play("ultimate", 0.02)

## The rim glows white while the parry window is open; gold dots count the Retaliation bashes left.
static func aura(a, c) -> void:
	var ang: float = a.aim.rotated(a.swing).angle()
	if a.state2 > 0.5:
		c.draw_arc(Vector2.ZERO, 14.0, ang - 1.2, ang + 1.2, 14, Color(WHITE, 0.9), 1.5)
		c.draw_arc(Vector2.ZERO, 14.0, ang - 1.2, ang + 1.2, 14, Color(WHITE, 0.25), 5.0)
	for i in int(a.state):
		c.draw_circle(Vector2.from_angle(ang - 0.5 + 0.5 * float(i)) * 18.0, 1.1, Color(GOLD, 0.95))
