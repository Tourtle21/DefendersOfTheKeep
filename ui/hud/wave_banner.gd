extends CanvasLayer
## Big centre-screen announcement when a wave begins: the title, then what the card draw did.
## (Clients get the same news as a normal banner line through Game.announce.)

var _title: Label
var _body: Label
var _tween: Tween

func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_title = _make_label(46, 0.0)
	_body = _make_label(18, 70.0)
	add_child(_title)
	add_child(_body)

func _make_label(font: int, y: float) -> Label:
	var l := Label.new()
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l.offset_left = -480
	l.offset_right = 480
	l.offset_top = 150 + y
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10 if font > 30 else 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	l.pivot_offset = Vector2(480, 30)
	return l

func show_wave(title: String, lines: Array) -> void:
	_title.text = title
	_body.text = "\n".join(lines)
	if _tween:
		_tween.kill()
	_title.scale = Vector2(1.6, 1.6)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_title, "modulate:a", 1.0, 0.2)
	_tween.tween_property(_title, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_body, "modulate:a", 1.0, 0.4).set_delay(0.3)
	_tween.chain().tween_interval(5.5)
	_tween.chain().set_parallel(true)
	_tween.tween_property(_title, "modulate:a", 0.0, 1.0)
	_tween.tween_property(_body, "modulate:a", 0.0, 1.0)
