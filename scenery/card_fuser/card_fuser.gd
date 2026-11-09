extends Area2D
## The Card Fuser: the keep's second station, opposite the Forge. Stand next to it and press interact to fuse
## two different spell or building cards from the hand into one hybrid (costs gold from the keep's pool).
## Opens ui/forge/card_fuse_ui.gd. Rules live in Game.fuse_preview / Game.fuse_hand, LAN clients use Net.card_fuse.

var hovering := false

func _ready() -> void:
	add_to_group("net")
	position = Net.CARD_FUSER_POS
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(func(b): if b.is_in_group("player") and !b.get("remote_controlled"): hovering = true)
	body_exited.connect(func(_b): hovering = Game.has_local_player(self))
	z_index = 2

func _input(event: InputEvent) -> void:
	if hovering and event.is_action_pressed("interact") and !(Game.draft_active and Game.draft_owner_slot == 0):
		var ui = get_tree().get_first_node_in_group("card_fuse_ui")
		if ui:
			ui.open()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	# a stone table with a glowing rune circle
	draw_rect(Rect2(-12, 0, 24, 9), Color.BLACK)
	draw_rect(Rect2(-11, 1, 22, 7), Color("6b5f78"))
	draw_rect(Rect2(-13, -6, 26, 8), Color.BLACK)
	draw_rect(Rect2(-12, -5, 24, 6), Color("9a8cb0"))
	draw_rect(Rect2(-12, -5, 24, 2), Color("cfc4e0"))
	# two small cards that drift together over the table
	var k := 0.5 + 0.5 * sin(t * 2.5)
	draw_rect(Rect2(-8 - k * 2.0, -14, 6, 8), Color(1.0, 0.85, 0.4))
	draw_rect(Rect2(2 + k * 2.0, -14, 6, 8), Color(0.55, 0.85, 1.0))
	draw_circle(Vector2(0, -10), 1.5 + k, Color(0.8, 0.6, 1.0, 0.4 + 0.4 * k))
	if hovering:
		draw_arc(Vector2.ZERO, 20.0, 0, TAU, 24, Color(0.9, 0.8, 1, 0.9), 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(-30, -20), "Card Fuser (Space)", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.95, 0.9, 1.0))
