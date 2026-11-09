extends CanvasLayer
## The always-on HUD of a local split-screen player (players 2 to 4), laid out like player 1's (ui/hud/hud.tscn and
## ui/base/base_ui.gd): what you carry and the keep's pool top-left, the keep bar top-centre, the health bar top-right,
## the announcement banner and a red flash when you are hit.

const NAME_COLORS := [Color(1, 0.85, 0.3), Color(0.5, 0.85, 1.0), Color(0.6, 1.0, 0.5), Color(1.0, 0.6, 0.9)]

var pl: Node
var slot := 1
var root: Control
var info: Label
var keep_bar: ProgressBar
var keep_lbl: Label
var hp_fill: ColorRect
var banner: Label
var wave_label: Label
var flash: ColorRect

func setup(player: Node, viewport: SubViewport, slot_index: int) -> void:
	pl = player
	slot = slot_index
	layer = 5
	custom_viewport = viewport
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(viewport.size)
	add_child(root)
	info = Label.new()
	info.position = Vector2(12, 10)
	info.add_theme_font_size_override("font_size", 18)
	root.add_child(info)
	flash = ColorRect.new()
	flash.color = Color(0.9, 0.05, 0.05, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)
	if pl.has_signal("hurt"):
		pl.hurt.connect(func():
			flash.color.a = 0.35
			create_tween().tween_property(flash, "color:a", 0.0, 0.4))
	keep_bar = ProgressBar.new()
	keep_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	keep_bar.offset_left = -170
	keep_bar.offset_right = 170
	keep_bar.offset_top = 38
	keep_bar.offset_bottom = 58
	keep_bar.show_percentage = false
	keep_bar.modulate = Color(1.0, 0.55, 0.45)
	keep_lbl = Label.new()
	keep_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	keep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keep_lbl.add_theme_font_size_override("font_size", 13)
	keep_bar.add_child(keep_lbl)
	root.add_child(keep_bar)
	# the health bar: the same black frame and red fill as player 1's
	var frame := ColorRect.new()
	frame.color = Color.BLACK
	frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	frame.offset_left = -250
	frame.offset_right = -16
	frame.offset_top = 16
	frame.offset_bottom = 43
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	hp_fill = ColorRect.new()
	hp_fill.color = Color(1, 0.14902, 0, 1)
	hp_fill.position = Vector2(3, 3)
	hp_fill.size = Vector2(228, 21)
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(hp_fill)
	var tag := Label.new()
	tag.text = "PLAYER %d" % (slot + 1)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tag.offset_left = -250
	tag.offset_right = -16
	tag.offset_top = 44
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", NAME_COLORS[slot])
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	tag.add_theme_constant_override("outline_size", 4)
	root.add_child(tag)
	wave_label = Label.new()
	wave_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	wave_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	wave_label.add_theme_font_size_override("font_size", 14)
	wave_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	wave_label.add_theme_color_override("font_outline_color", Color.BLACK)
	wave_label.add_theme_constant_override("outline_size", 4)
	wave_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wave_label)
	banner = Label.new()
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner.offset_top = 70
	banner.offset_left = -300
	banner.offset_right = 300
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.add_theme_font_size_override("font_size", 22)
	banner.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.add_theme_constant_override("outline_size", 6)
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner)
	Game.announce.connect(func(text):
		banner.text = text
		var tw := create_tween()
		tw.tween_property(banner, "modulate:a", 1.0, 0.2)
		tw.tween_interval(3.0)
		tw.tween_property(banner, "modulate:a", 0.0, 0.8))

func fit(area: Vector2) -> void:
	root.size = area
	# a narrow view (a half or quarter of the window) cannot hold the resource line, the keep bar and the health bar side by side:
	# the line wraps in the space left of the health bar and the keep bar moves down under it
	var narrow: bool = area.x < 900.0
	info.add_theme_font_size_override("font_size", 14 if narrow else 18)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if narrow else TextServer.AUTOWRAP_OFF
	info.custom_minimum_size.x = (area.x - 280.0) if narrow else 0.0
	info.reset_size()                                   # (a wrapping label keeps its old height until it is told to resize)
	keep_bar.offset_top = 52.0 if narrow else 38.0
	wave_label.position.y = 74.0 if narrow else 62.0
	keep_bar.offset_bottom = 70.0 if narrow else 58.0
	banner.offset_top = 80.0 if narrow else 70.0

func _process(_delta: float) -> void:
	wave_label.text = Game.wave_timer_text()
	if !is_instance_valid(pl):
		return
	var carry := []
	var keep := []
	for k in Game.resources:
		if Game.resources[k] > 0 or k in ["stone", "stick", "gold"]:
			keep.append("%d %s" % [Game.resources[k], k])
	var kinds: Array = ["stone", "stick", "gold"]           # (player 1 always lists these three, even at zero)
	for k in pl.carried:
		if !(k in kinds):
			kinds.append(k)
	for k in kinds:
		var n: int = int(pl.carried.get(k, 0))
		if n > 0 or k in ["stone", "stick", "gold"]:
			carry.append("%d %s" % [n, k])
	var line := "Carrying: %s     Keep: %s" % [", ".join(carry), ", ".join(keep)]
	if line != info.text:
		info.text = line
		info.reset_size()
	keep_bar.max_value = Game.keep_max()
	keep_bar.value = Game.keep_hp
	keep_lbl.text = "Keep %d / %d" % [Game.keep_hp, Game.keep_max()]
	hp_fill.size.x = clampf(pl.remote_hp, 0.0, 228.0)
