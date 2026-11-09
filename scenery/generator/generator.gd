extends Area2D
class_name ResourceGenerator
## A resource generator found in every biome. It starts dormant: walk up and press
## interact to activate it (costs gold you are carrying). Once active it slowly makes
## that biome's resource into storage; press interact to collect everything at once.
## With nothing to collect, interact upgrades it (levels 1-5: faster and bigger storage).

const MAX_LEVEL := 5
const NET_SKIP := ["hovering"]

var resource := "stone"
var color := Color(0.7, 0.8, 1.0)
var level := 0                  # 0 = dormant
var stored := 0
var progress := 0.0
var hovering := false
var _age := 0.0
var flash := 0.0

func interval() -> float:
	return maxf(1.5, (9.0 - level) / (1.0 + Game.bonus("gen_speed")))

func capacity() -> int:
	return 8 + 6 * level

func activate_cost() -> Dictionary:
	return {"gold": 4}

func upgrade_cost() -> Dictionary:
	var n := level + 1
	return {"gold": 5 * n, resource: 2 * n}

func _ready() -> void:
	add_to_group("generator")
	add_to_group("net")
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(func(b): if b.is_in_group("player") and !b.get("remote_controlled"): hovering = true)
	body_exited.connect(func(_b): hovering = Game.has_local_player(self))
	z_index = 3

func _process(delta: float) -> void:
	_age += delta
	flash = maxf(0.0, flash - delta)
	if level > 0 and stored < capacity():
		progress += delta
		if progress >= interval():
			progress = 0.0
			stored += 1
	queue_redraw()

func _input(event: InputEvent) -> void:
	if hovering and event.is_action_pressed("interact") and !(Game.draft_active and Game.draft_owner_slot == 0) and !Game.menu_open():
		use()

## Activate, collect or upgrade, depending on the state. Returns what happened.
func use(who = null) -> String:
	if level == 0:
		if Game.pay_carried(activate_cost(), who):
			level = 1
			flash = 0.6
			Sfx.play("unlock", 0.0)
			Game.announce.emit("Generator active: it makes %s" % resource)
			return "activated"
		return "need_gold"
	if stored > 0:
		var table: Dictionary = Game.carried_of(who)
		table[resource] = table.get(resource, 0) + stored
		Game.resources_changed.emit()
		Sfx.play("coin", 0.1)
		stored = 0
		flash = 0.4
		return "collected"
	if level < MAX_LEVEL and Game.pay_carried(upgrade_cost(), who):
		level += 1
		flash = 0.6
		Sfx.play("unlock", 0.0)
		return "upgraded"
	return "nothing"

func _hint() -> String:
	if level == 0:
		return "E: activate (%s)" % _cost_text(activate_cost())
	if stored > 0:
		return "E: collect %d %s" % [stored, resource]
	if level < MAX_LEVEL:
		return "E: upgrade to %d (%s)" % [level + 1, _cost_text(upgrade_cost())]
	return "Fully upgraded"

func _cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in cost:
		parts.append("%d %s" % [cost[k], k])
	return ", ".join(parts)

func _draw() -> void:
	var active := level > 0
	var pulse := 0.5 + 0.5 * sin(_age * 3.0)
	var col := color if active else color.darkened(0.6)
	draw_circle(Vector2(0, 8), 13.0, Color(0, 0, 0, 0.3))
	# base plinth
	draw_rect(Rect2(-11, 0, 22, 8), Color.BLACK)
	draw_rect(Rect2(-10, 1, 20, 6), Color(0.35, 0.35, 0.42))
	# the crystal engine
	var h := 14.0 + 2.0 * level
	var pts := PackedVector2Array([Vector2(0, -h - 6), Vector2(7, -h * 0.4), Vector2(5, 1), Vector2(-5, 1), Vector2(-7, -h * 0.4)])
	draw_colored_polygon(pts, Color.BLACK)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(p * 0.82 + Vector2(0, -0.5))
	draw_colored_polygon(inner, col.lerp(Color.WHITE, 0.4 * flash / 0.6 + (0.15 * pulse if active else 0.0)))
	if active:
		draw_arc(Vector2(0, -h * 0.5), 12.0 + 2.0 * pulse, 0, TAU, 24, Color(color, 0.25 + 0.2 * pulse), 1.5)
		# progress ring around the base: next unit
		draw_arc(Vector2(0, 4), 14.0, -PI / 2.0, -PI / 2.0 + TAU * (progress / interval()), 24, Color(1, 1, 1, 0.5), 1.5)
		for i in level:
			draw_circle(Vector2((i - (level - 1) * 0.5) * 6.0, 14.0), 1.8, Color(1.0, 0.85, 0.3))
		if stored > 0:
			draw_string(ThemeDB.fallback_font, Vector2(-20, -h - 12), "%d/%d" % [stored, capacity()], HORIZONTAL_ALIGNMENT_CENTER, 40.0, 10, Color.WHITE)
	if hovering:
		draw_arc(Vector2.ZERO, 16.0, 0, TAU, 24, Color(1, 1, 0.5, 0.9), 1.5)
		var t := _hint()
		draw_string(ThemeDB.fallback_font, Vector2(-70, 24), t, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 9, Color(1, 1, 0.8))
