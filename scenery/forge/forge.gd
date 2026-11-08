extends Area2D
## The Forge: stand next to it and press interact to fuse two of your weapons
## (costs gold from the keep's pool). Opens ui/forge/forge_ui.gd.

var hovering := false

func _ready() -> void:
	add_to_group("net")
	position = Vector2(-62, 22)
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(func(b): if b.is_in_group("player"): hovering = true)
	body_exited.connect(func(b): if b.is_in_group("player"): hovering = false)
	z_index = 2

func _input(event: InputEvent) -> void:
	if hovering and event.is_action_pressed("interact") and !Game.draft_active:
		var ui = get_tree().get_first_node_in_group("forge_ui")
		if ui:
			ui.open()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	# anvil
	draw_rect(Rect2(-9, 2, 18, 5), Color.BLACK)
	draw_rect(Rect2(-8, 3, 16, 3), Color("5c6670"))
	draw_rect(Rect2(-12, -5, 24, 8), Color.BLACK)
	draw_rect(Rect2(-11, -4, 22, 6), Color("8f9db0"))
	draw_rect(Rect2(-11, -4, 22, 2), Color("c8d0d8"))
	draw_rect(Rect2(-14, -3, 5, 3), Color("8f9db0"))
	# embers
	var glow := 0.5 + 0.5 * sin(t * 4.0)
	draw_circle(Vector2(0, -8 - glow * 3), 1.5, Color(1.0, 0.55, 0.15, 0.4 + 0.4 * glow))
	if hovering:
		draw_arc(Vector2.ZERO, 20.0, 0, TAU, 24, Color(1, 1, 0.5, 0.9), 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(-18, -14), "Forge (Space)", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.95, 0.6))
