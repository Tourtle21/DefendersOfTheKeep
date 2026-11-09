extends CanvasLayer
## Chest draft: pick 1 of 3 cards. Picking a card you already own upgrades it.

var root_ctl: Control
var title: Label
var row: HBoxContainer

func _ready() -> void:
	layer = 7
	root_ctl = Control.new()
	root_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctl.mouse_filter = Control.MOUSE_FILTER_STOP     # no clicks through to the map
	root_ctl.visible = false
	add_child(root_ctl)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctl.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 18)
	root_ctl.add_child(box)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 5)
	box.add_child(title)
	row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	preload("res://ui/cards/menu_pad.gd").attach(root_ctl, Callable(), "", row)     # any controller: d-pad / left stick to move, A to take
	Game.draft_started.connect(_show)
	Game.deck_changed.connect(func(): root_ctl.visible = Game.draft_active)

func _show(options: Array) -> void:
	title.text = "Chest! Choose a card  (cards you own are upgraded)"
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	for i in options.size():
		var entry: String = options[i]
		var id := Game.entry_id(entry)
		var owned: int = Game.deck.get(id, 0)
		var wrap := Control.new()
		wrap.custom_minimum_size = CardView.SIZE * 1.5
		var view := CardView.new()
		view.setup(id, Game.entry_tier(entry), "NEW" if owned == 0 else "+1 copy", Game.entry_twist(entry))
		view.scale = Vector2(1.5, 1.5)
		view.focus_mode = Control.FOCUS_ALL
		view.pressed_down.connect(func(v): Game.take_draft_card(entry))
		wrap.add_child(view)
		row.add_child(wrap)
		view.flip_in(i * 0.1)
	root_ctl.visible = true
