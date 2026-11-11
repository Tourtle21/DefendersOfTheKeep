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
var caster = null           # who cast it: a Flare follows that player's aim
var landed := false
var _tick := 0.0
var light_radius := 0.0     # > 0 once a bright spell (flare, fire zone) has landed: it is a light source (group "light")
var _glow: GlowLight

func setup(card: Dictionary, target: Vector2, from: Vector2) -> void:
	data = card
	position = target
	origin = from
	card = _with_numeric_adds(card)
	data = card
	radius = card.radius
	flight = 0.1 if card.kind == "flare" else max(0.15, from.distance_to(target) / card.speed)         # a Flare is just there, at your aim
	effect_time = 0.4 if card.kind == "fireball" else card.get("duration", 0.3)

func _ready() -> void:
	add_to_group("net")
	z_index = 10
	if data.get("night", false) and data.kind in ["fireball", "flare", "zone", "meteor"] and data.get("element", "") == "fire":
		_glow = GlowLight.attach(self, 34.0, Color(1.0, 0.7, 0.3), 0.9)       # a fire spell glows in flight too

## The additions that only change the numbers (wider, longer, stronger), applied once when the spell is made.
static func _with_numeric_adds(card: Dictionary) -> Dictionary:
	var adds: Array = card.get("adds", [card.get("twist", "")])
	var any := false
	for a in ["wide", "lingers", "potent", "swift_heal", "deep_freeze"]:
		any = any or (a in adds)
	if !any:
		return card
	var c: Dictionary = card.duplicate()
	if "wide" in adds:
		c.radius = c.radius * 1.4
		if c.has("duration"):
			c.duration = c.duration * 1.3
	if "lingers" in adds and c.has("duration"):
		c.duration = c.duration * 1.5
	if "potent" in adds:
		for key in ["damage", "dps", "burst", "heal_per_sec"]:
			if c.has(key):
				c[key] = c[key] * 1.25
	if "swift_heal" in adds and c.has("heal_per_sec"):
		c.heal_per_sec = c.heal_per_sec * 1.6
	if "deep_freeze" in adds and c.has("slow"):
		c.slow = maxf(0.12, pow(c.slow, 1.8))
	return c

## What an addition does when the spell lands. The copies it makes carry no twist themselves.
func _apply_twist() -> void:
	var adds: Array = data.get("adds", [data.get("twist", "")])
	var world := get_parent()
	var tree := get_tree()
	var pos := position
	var plain: Dictionary = data.duplicate()
	plain.twist = ""
	plain.adds = []
	for tw in adds:
		_apply_add(String(tw), world, tree, pos, plain)

func _apply_add(tw: String, world: Node, tree: SceneTree, pos: Vector2, plain: Dictionary) -> void:
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
		"burn":
			for e in _in_radius("enemy"):
				WeaponUtil.bleed(tree, e, 4, maxf(0.5, data.get("damage", data.get("dps", 2.0)) * 0.25))
		"refund":
			Game.mana = minf(Game.max_mana(), Game.mana + float(data.get("mana", 0)) * 0.3)
			Game.mana_changed.emit()
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
	if data.kind == "flare" and caster != null and is_instance_valid(caster) and caster.has_method("aim_point"):
		position = caster.aim_point()                 # the Flare follows your aimer (the cursor, or the stick), so you can sweep it around
	if !landed:
		if age >= flight:
			landed = true
			_apply_twist()
			if data.get("night", false) and data.kind in ["flare", "zone"] and data.get("element", "") == "fire":
				light_radius = radius                      # the landed spell is a light source until it ends
				add_to_group("light")
				if _glow != null:
					_glow.texture_scale = maxf(0.1, radius * 2.0 / 128.0)
					_glow.base_energy = 0.65
			if data.kind == "fireball":
				LightSource.spawn(get_parent(), position, radius * 1.6, 2.0, Color(1.0, 0.7, 0.3))      # the blast lights the area for a moment
				for e in _in_radius("enemy"):
					e.spell_damage(data.damage, data.get("element", ""), true)
			elif data.kind == "meteor":
				LightSource.spawn(get_parent(), position, radius * 1.4, data.duration + 1.0, Color(1.0, 0.7, 0.3))
				WeaponUtil.rain(get_tree(), get_parent(), position, radius, int(data.get("count", 10)), data.duration, data.damage, 26.0, _color())
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
		"stasis":
			for e in _in_radius("enemy"):
				if e.has_method("apply_slow"):
					e.apply_slow(0.0, 0.3)                       # held still
				WeaponUtil.expose(e, 0.4)
		"flare":
			_tick += delta
			if _tick >= 0.5:
				_tick = 0.0
				for e in _in_radius("enemy"):
					e.spell_damage(data.dps * 0.5, "fire", true)
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
	var tier := int(data.get("tier", 1))
	var col := _color().lerp(Color(1.0, 0.92, 0.5), 0.1 * (tier - 1))          # a higher tier tints toward gold
	if landed and tier >= 2:
		for i in tier - 1:                                                      # and gets one more ring inside the area for each tier
			draw_arc(Vector2.ZERO, radius * (1.0 - 0.14 * (i + 1)), 0, TAU, 40, Color(col, 0.35), 1.0)
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
