extends CanvasLayer
## Host's co-op lobby: shown while Net.lobby is true (host started with `-- host`).
## Lists who has joined; waves start when the host presses Start.

var panel: PanelContainer
var roster: Label

func _ready() -> void:
	layer = 18
	if Net.lobby:
		get_parent().get_node("SpawnTimer").paused = true
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.14, 0.92)
	style.border_color = Color(0.5, 0.8, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 90
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(380, 0)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Co-op lobby (port %d)" % Net.PORT
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	roster = Label.new()
	box.add_child(roster)
	var start := Button.new()
	start.text = "Start game"
	start.custom_minimum_size = Vector2(0, 40)
	start.pressed.connect(func(): Net.start_game())
	box.add_child(start)
	var hint := Label.new()
	hint.text = "Friends join with:  Godot --path . -- join=<your address> -- name=<their name>"
	hint.add_theme_font_size_override("font_size", 11)
	box.add_child(hint)

func _process(_delta: float) -> void:
	panel.visible = Net.lobby and Net.is_host
	if panel.visible:
		var lines := ["Host"]
		for id in Net.names:
			lines.append(Net.names[id])
		roster.text = "Players (%d):  %s" % [lines.size(), ", ".join(lines)]
