extends Node2D
class_name DamageNumber
## Floating combat text: rises and fades. Big hits are larger and gold.
const UiKit = preload("res://ui/cards/ui_kit.gd")

var text := ""
var color := UiKit.WHITE
var font_size := 9
var age := 0.0
const LIFE := 0.75

static func spawn(world: Node, pos: Vector2, amount: float, big := false, tint := UiKit.WHITE) -> void:
	if world == null:
		return
	if Rep.hosting():
		Rep.event("dmg", [pos, amount, big, tint])
	var n := DamageNumber.new()
	n.text = str(snapped(amount, 0.1)).trim_suffix(".0")
	n.position = pos + Vector2(randf_range(-6.0, 6.0), 0.0)
	n.color = UiKit.GOLD_BRIGHT if big else UiKit.WHITE
	if tint != UiKit.WHITE:
		n.color = tint
	n.font_size = 13 if big else 9
	world.add_child.call_deferred(n)

func _ready() -> void:
	add_to_group("net_local")      # mirrored to clients as a Rep event
	z_as_relative = false
	z_index = 30

func _process(delta: float) -> void:
	age += delta
	position.y -= 24.0 * delta
	if age >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var a: float = 1.0 - age / LIFE
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(UiKit.BLACK, a))
	draw_string(f, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(color, a))
