extends Area2D
class_name Chest
## A loot chest that appears somewhere on the map for a limited time. Walk up and
## press interact to open it and draft a card. The player in the keep can see it
## from the wide view (a beam marks it) and call it out.

const LIFETIME := 60.0
const NET_SKIP := ["hovering", "opened"]
var time_left := LIFETIME
var hovering := false
var opened := false
var boost := 0          # extra odds steps (a chest dropped by the rainbow sheep is better)
var kind := "card"      # "card" = pick-1-of-3 draft, "weapon" = drops a weapon


func label() -> String:
	return "Weapon chest" if kind == "weapon" else "Card chest"

## Returns true if the chest was used up.
func _open() -> bool:
	Sfx.play("chest")
	if kind == "weapon":
		var pickup = load("res://collectables/collectable.tscn").instantiate()
		pickup.item_type = Game.weapon_pool().pick_random()
		var rolled := Game.roll_weapon_entry(pickup.item_type, Game.chest_level(boost))     # better tiers the deeper you are
		pickup.bonus = Game.weapon_bonus(rolled)
		pickup.twist = Game.entry_twist(rolled)
		pickup.fixed = true
		pickup.position = position
		get_parent().add_child.call_deferred(pickup)
		return true
	return Game.start_draft(boost)

func _ready() -> void:
	add_to_group("chest")
	add_to_group("net")
	collision_layer = 0
	collision_mask = 1          # players
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(func(b): if b.is_in_group("player") and !b.get("remote_controlled"): hovering = true)
	body_exited.connect(func(_b): hovering = Game.has_local_player(self))
	z_index = 3

func _process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		queue_free()
		return
	queue_redraw()

func open_now() -> void:   # used by tests
	if _open():
		opened = true
		queue_free()

func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var blink := time_left < 10.0 and int(t * 4.0) % 2 == 0
	var a := 0.4 if blink else 1.0
	var lid_col := Color(0.35, 0.5, 0.85) if kind == "weapon" else Color(0.72, 0.47, 0.22)
	var beam_col := Color(0.5, 0.7, 1.0) if kind == "weapon" else Color(1, 0.85, 0.3)
	# beam so it can be spotted from the wide view
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	draw_line(Vector2(0, -8), Vector2(0, -46), Color(beam_col, 0.35 + 0.25 * pulse), 3.0)
	draw_circle(Vector2(0, -50), 3.0 + pulse, Color(beam_col.lightened(0.3), a))
	# the chest
	draw_circle(Vector2(0, 7), 9.0, Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-9, -3, 18, 11), Color("000000"))
	draw_rect(Rect2(-8, -2, 16, 9), Color(0.55, 0.35, 0.17, a))
	draw_rect(Rect2(-9, -9, 18, 7), Color("000000"))
	draw_rect(Rect2(-8, -8, 16, 5), Color(lid_col, a))
	draw_rect(Rect2(-8, -4, 16, 2), Color(0.9, 0.7, 0.25, a))      # gold band
	draw_rect(Rect2(-2, -5, 4, 6), Color(0.95, 0.8, 0.3, a))       # lock
	draw_rect(Rect2(-1, -3, 2, 2), Color("000000"))
	if hovering:
		draw_arc(Vector2(0, 0), 14.0, 0, TAU, 24, Color(1, 1, 0.5, 0.9), 1.5)
