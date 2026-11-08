extends CanvasLayer
## "You fell" countdown: shown while the local player is out of the fight (see Player.fall / respawn).

var _label: Label
var _bar: ColorRect
var _fill: ColorRect

func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.position.y = 120
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	_label.visible = false
	add_child(_label)
	_bar = ColorRect.new()
	_bar.color = Color(0, 0, 0, 0.6)
	_bar.size = Vector2(300, 10)
	_bar.visible = false
	add_child(_bar)
	_fill = ColorRect.new()
	_fill.color = Color(1.0, 0.8, 0.3)
	_fill.size = Vector2(300, 10)
	_bar.add_child(_fill)

func _process(_delta: float) -> void:
	var p = get_parent().get_node_or_null("Player")
	var down: bool = p != null and p.downed
	_label.visible = down
	_bar.visible = down
	if !down:
		return
	_label.text = "You fell!  Back in %d" % ceili(p.respawn_left)
	var vp := get_viewport().get_visible_rect().size
	_bar.position = Vector2(vp.x / 2.0 - 150.0, 180.0)
	_fill.size.x = 300.0 * clampf(1.0 - p.respawn_left / p.RESPAWN_TIME, 0.0, 1.0)
