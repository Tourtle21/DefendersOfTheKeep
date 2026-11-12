extends Node2D
class_name WeaponAura
## The look of an equipped weapon of tier 2 and up, drawn around the player from synced variables only (so LAN clients see it too):
## 2 a twinkle at the tip, 3 a tip glow, 4 motes around the head, 5 more motes + a swing ghost + a trail, 6 a halo ring + a tip star.
## A weapon module adds its own picture through `kind` and `state` (WeaponTiers.run's `aura(a, c)`).
## Host: follows the owner each frame. Clients: a puppet that redraws from these variables.

const MOTE_CAP := [4, 5, 6, 8, 10, 12, 16]

var wid := ""
var tier := 1
var rar := 0
var aim := Vector2.RIGHT
var swing := 0.0
var reach := 11.0
var kind := "hand"
var state := 0.0
var state2 := 0.0
var data := {}              # free synced extras of a weapon module (gate positions, holes, counts): plain numbers, vectors, arrays
var col := Color.WHITE
var hot := Color.WHITE
var core := Color.WHITE
var light := false
var _age := 0.0
var _owner = null
var _trail := []

static func attach(w) -> void:
	if w.tier < 2 or w.player == null:
		return
	var a := WeaponAura.new()
	a.wid = w.weapon_id
	a.tier = w.tier
	a.rar = Game.weapon_rarity(w.weapon_id)
	a.reach = w.reach if "reach" in w else 12.0
	var pal := WeaponArt.palette(w.weapon_id)
	a.col = pal[0]
	a.hot = pal[1]
	a.core = pal[2]
	a.light = float(w.get("light_radius")) > 0.0 if w.get("light_radius") != null else false
	a._owner = w
	a.position = w.player.global_position
	w.game_world().add_child(a)
	w._aura = a

func _ready() -> void:
	add_to_group("net")
	z_as_relative = false
	z_index = 6

func _process(delta: float) -> void:
	_age += delta
	if _owner == null or !is_instance_valid(_owner) or !_owner.is_inside_tree() or !is_instance_valid(_owner.player):
		queue_free()
		return
	global_position = _owner.player.global_position + Vector2(0, -3)
	aim = _owner.aim
	swing = float(_owner.get("swing_offset")) if _owner.get("swing_offset") != null else 0.0
	_sample()
	queue_redraw()

func net_tick(_delta: float) -> void:
	_sample()
	queue_redraw()

func _tip() -> Vector2:
	return aim.rotated(swing) * (reach + 9.0)

func _sample() -> void:
	if tier < 5:
		return
	_trail.append([_age, _tip()])
	while _trail.size() > 0 and _age - _trail[0][0] > 0.4:
		_trail.pop_front()

static func jit(i: int, salt: float) -> float:
	return fposmod(sin(float(i) * 12.9898 + salt * 78.233) * 43758.5453, 1.0)

func motes() -> int:
	var n := 2 + rar / 3
	var m := n if tier == 4 else (n * 2 if tier == 5 else (n * 3 if tier >= 6 else 0))
	return mini(m, MOTE_CAP[clampi(rar, 0, 6)])

func _draw() -> void:
	if tier < 2:
		return
	var tip := _tip()
	var head := aim.rotated(swing) * reach
	# tier 5+: swing ghost and tip trail first (under the rest)
	if tier >= 5:
		for i in _trail.size():
			var f: float = float(i) / float(maxi(_trail.size(), 1))
			if i % 2 == 0:
				draw_circle(_trail[i][1], 1.0 + f, Color(col, 0.35 * f))
		if absf(swing) > 0.05:
			for k in 3:
				var d := aim.rotated(swing - 0.25 * float(k + 1) * signf(swing))
				draw_line(d * 7.0, d * (reach + 9.0), Color(col, [0.35, 0.2, 0.1][k]), 1.5)
	if tier >= 6:
		for i in 18:
			var a := _age * 0.6 * TAU + float(i) * TAU / 18.0
			draw_circle(head + Vector2.from_angle(a) * (reach + 9.0), 0.8, Color(core, 0.5))
		if light:
			draw_circle(head, reach + 9.0, Color(hot, 0.07))
	if tier >= 3:
		draw_circle(tip, 3.5, Color(col, 0.12 + 0.08 * sin(_age * 3.0)))
	if tier >= 4:
		for i in motes():
			var a2 := _age * 1.1 * TAU + float(i) * TAU / float(maxi(motes(), 1))
			draw_circle(head + Vector2.from_angle(a2) * 7.0, 0.9, Color(hot, 0.9))
	# the twinkle: a white 4-point star at the tip every 1.6 s, for 0.25 s
	var since := fposmod(_age + jit(wid.hash(), 1.0), 1.6)
	if since < 0.25:
		var s := 1.0 - since / 0.25
		var r := 3.0 * s + 1.0
		draw_line(tip + Vector2(-r, 0), tip + Vector2(r, 0), Color(1, 1, 1, s), 1.0)
		draw_line(tip + Vector2(0, -r), tip + Vector2(0, r), Color(1, 1, 1, s), 1.0)
	if tier >= 6:
		var pulse := 0.5 + 0.5 * sin(_age * TAU / 0.5)
		var rs := 2.0 + 1.5 * pulse
		for k in 4:
			var d2 := Vector2.from_angle(float(k) * PI / 2.0 + PI / 4.0)
			draw_line(tip, tip + d2 * rs, Color(1, 0.95, 0.7, 0.9), 1.0)
	var m = WeaponTiers.mod(wid)
	if m != null and WeaponTiers.has_fn(wid, "aura"):
		m.aura(self, self)
