extends Node2D
class_name Spell
## A cast card. It is shot from the crystal, flies to the target spot (the target
## outline is visible the whole time), and only then applies its effect, so enemies
## can walk out of the area while it is in flight.

var data: Dictionary
var radius := 40.0
var origin := Vector2.ZERO
var flight := 1.0           # seconds of travel
var effect_time := 1.0      # seconds the effect lasts after landing
var age := 0.0
var landed := false
var _tick := 0.0

func setup(card: Dictionary, target: Vector2, from: Vector2) -> void:
	data = card
	position = target
	origin = from
	if card.get("twist", "") == "wide":
		card = card.duplicate()
		card.radius = card.radius * 1.4
		if card.has("duration"):
			card.duration = card.duration * 1.3
		data = card
	radius = card.radius
	flight = max(0.15, from.distance_to(target) / card.speed)
	effect_time = 0.4 if card.kind == "fireball" else card.duration

func _ready() -> void:
	add_to_group("net")
	z_index = 10

## What a twist adds when the spell lands. The copies it makes carry no twist themselves.
func _apply_twist() -> void:
	var tw: String = data.get("twist", "")
	if tw == "" or tw == "wide":
		return
	var world := get_parent()
	var tree := get_tree()
	var pos := position
	var plain: Dictionary = data.duplicate()
	plain.twist = ""
	match tw:
		"twin":
			tree.create_timer(0.5).timeout.connect(func(): Spell.cast_copy(world, plain, pos))
		"echo":
			var d2: Dictionary = plain.duplicate()
			d2.radius = d2.radius * 1.4
			for key in ["damage", "dps"]:
				if d2.has(key):
					d2[key] = d2[key] * 0.6
			tree.create_timer(0.35).timeout.connect(func(): Spell.cast_copy(world, d2, pos))
		"aftermath":
			var kinds := {"fire": "burn", "poison": "burn", "pierce": "burn", "ice": "slow", "earth": "slow"}
			var hz: String = kinds.get(data.get("element", ""), "slow")
			WeaponUtil.patch(world, pos, hz, radius * 0.75, _color(), 4.0, 0.55)
		"shrapnel":
			var dmg: float = data.get("damage", data.get("dps", 2.0))
			for i in 6:
				WeaponProjectile.shoot(world, pos, Vector2.from_angle(i * TAU / 6.0), 150.0, dmg * 0.4, _color(), 0.5, 1, 60.0)

static func cast_copy(world: Node, d: Dictionary, pos: Vector2) -> void:
	if !is_instance_valid(world):
		return
	var s := Spell.new()
	s.setup(d, pos, pos)
	world.add_child(s)

func _in_radius(group: String) -> Array:
	var out := []
	var nodes: Array = get_tree().get_nodes_in_group(group)
	if group == "enemy":
		nodes = nodes + get_tree().get_nodes_in_group("critter")      # spells can hit the rainbow sheep too
	for n in nodes:
		if n.global_position.distance_to(global_position) <= radius:
			out.append(n)
	return out

func _physics_process(delta: float) -> void:
	age += delta
	if !landed:
		if age >= flight:
			landed = true
			_apply_twist()
			if data.kind == "fireball":
				for e in _in_radius("enemy"):
					e.spell_damage(data.damage, data.get("element", ""), true)
			elif data.kind == "spikes":
				for i in 3:
					var spot := position + Vector2.from_angle(i * TAU / 3.0 - PI / 2.0) * 22.0
					WeaponUtil.ground_strike(get_tree(), get_parent(), spot, radius, 0.3 + i * 0.15, data.damage, 160.0, data.color, 0.3, [], data.get("element", ""))
			elif data.kind == "build":
				var st := Structure.new()
				st.setup(data, position)
				get_parent().add_child(st)
				Structure.settle(get_tree(), st)
				queue_free()
				return
			elif data.kind == "guards":
				for i in int(data.count):
					var g := Guard.new()
					g.setup(data, position + Vector2.from_angle(i * TAU / data.count) * 10.0)
					get_parent().add_child(g)
				WeaponFx.spawn(get_parent(), "ring", position, Color(0.7, 0.85, 1.0), {"radius": radius, "life": 0.4})
				queue_free()
				return
			elif data.kind == "charm":
				for e in _in_radius("enemy"):
					if e.has_method("charm"):
						e.charm(data.duration)
				WeaponFx.spawn(get_parent(), "ring", position, Color(0.5, 1.0, 0.7), {"radius": radius, "life": 0.5})
				queue_free()
				return
			elif data.kind == "magnet":
				for g in _in_radius("gold"):
					g.collect_to_pool()
		queue_redraw()
		return
	match data.kind:
		"frost_ring":
			for e in _in_radius("enemy"):
				e.apply_slow(data.slow, 0.3)
		"zone":
			for e in _in_radius("enemy"):
				e.apply_slow(data.slow, 0.3)
			_tick += delta
			if _tick >= 0.5:
				_tick = 0.0
				for e in _in_radius("enemy"):
					e.spell_damage(data.dps * 0.5, data.get("element", ""), true)
		"rejuvenation":
			for p in _in_radius("player"):
				p.heal(data.heal_per_sec * delta)
		"aegis":
			for p in _in_radius("player"):
				p.shield_time = max(p.shield_time, 0.3)
	if age >= flight + effect_time:
		queue_free()
	queue_redraw()

func _color() -> Color:
	if data.has("color"):
		return data.color
	match data.kind:
		"fireball": return Color(1.0, 0.45, 0.1)
		"frost_ring": return Color(0.4, 0.8, 1.0)
		"rejuvenation": return Color(0.4, 1.0, 0.5)
		"magnet": return Color(1.0, 0.85, 0.25)
	return Color(0.7, 0.6, 1.0)

func _draw() -> void:
	var col := _color()
	if !landed:
		# target outline closes in as the shot approaches
		var t: float = age / flight
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(col, 0.9), 1.5)
		draw_circle(Vector2.ZERO, radius * t, Color(col, 0.2))
		# the shot itself, with a short trail
		var from_local := origin - position
		for i in 6:
			var tt: float = max(0.0, t - i * 0.03)
			draw_circle(from_local.lerp(Vector2.ZERO, tt), 3.0 - i * 0.4, Color(col, 0.9 - i * 0.14))
		return
	var since := age - flight
	if data.kind == "fireball":
		var fade: float = 1.0 - since / 0.4
		draw_circle(Vector2.ZERO, radius, Color(col, 0.6 * fade))
	else:
		var fade: float = clamp((effect_time - since) / 1.0, 0.0, 1.0)
		var pulse: float = 0.5 + 0.5 * sin(since * 4.0)
		draw_circle(Vector2.ZERO, radius, Color(col, (0.15 + 0.1 * pulse) * fade))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(col, 0.8 * fade), 1.5)
