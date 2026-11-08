extends Area2D
class_name GoldCoin
## Dropped by enemies. Walk over it to carry it home; it disappears after a few
## seconds. The Gold Magnet card collects coins in an area straight into the keep.

const LIFETIME := 10.0
var time_left := LIFETIME

static func spawn(world: Node, pos: Vector2, count: int) -> void:
	for i in count:
		var coin := GoldCoin.new()
		coin.position = pos + Vector2(randf_range(-9, 9), randf_range(-9, 9))
		world.add_child.call_deferred(coin)   # deaths happen inside physics callbacks

func _ready() -> void:
	add_to_group("gold")
	add_to_group("net")
	collision_layer = 0
	collision_mask = 1          # players
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	z_index = 3

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		Game.pick_up_resource("gold", body)
		queue_free()

func collect_to_pool() -> void:
	Game.add_resource("gold", 1)
	queue_free()

func _process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if time_left < 3.0 and int(t * 6.0) % 2 == 0:
		return        # blink when about to vanish
	var w: float = max(0.25, absf(cos(t * 4.0)))     # spinning coin
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(w, 1.0))
	draw_circle(Vector2.ZERO, 5.5, Color.BLACK)
	draw_circle(Vector2.ZERO, 4.5, Color("c98a10"))
	draw_circle(Vector2.ZERO, 3.4, Color("ffd23a"))
	draw_circle(Vector2(-1, -1), 1.2, Color("fff1a8"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
