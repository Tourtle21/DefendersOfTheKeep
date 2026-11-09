extends CanvasLayer
## Chest draft: pick 1 of 3 cards. Picking a card you already own upgrades it.

var root_ctl: Control
var title: Label
var row: HBoxContainer
var hand_row: HBoxContainer
var hand_title: Label

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
	hand_title = Label.new()                       # the cards you hold now, with how many of each, and a Combine button for pairs
	hand_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hand_title.add_theme_font_size_override("font_size", 16)
	hand_title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	box.add_child(hand_title)
	hand_row = HBoxContainer.new()
	hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_row.add_theme_constant_override("separation", 14)
	box.add_child(hand_row)
	Game.hand_changed.connect(func():
		if root_ctl.visible:
			_refresh_hand())
	preload("res://ui/cards/menu_pad.gd").attach(root_ctl, Callable(), "", row)     # any controller: d-pad / left stick to move, A to take
	Game.draft_started.connect(_show)
	Game.deck_changed.connect(func(): root_ctl.visible = Game.draft_active and Game.draft_owner_slot == 0)

func _show(options: Array) -> void:
	if Game.draft_owner_slot > 0:
		return                       # a local player 2 to 4 opened it: their own view shows it (ui/base/local_draft_ui.gd)
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
	_refresh_hand()
	root_ctl.visible = true

## Your hand, one card per kind with x2 / x3 when you hold copies; two of the same card and tier can be combined right here
## (that needs the next tier unlocked in the Collection).
func _refresh_hand() -> void:
	for c in hand_row.get_children():
		hand_row.remove_child(c)
		c.queue_free()
	hand_title.text = "Your cards" + ("  (two of the same card combine into the next tier)" if !Game.hand.is_empty() else "")
	for g in Game.hand_groups():
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 4)
		var wrap := Control.new()
		wrap.custom_minimum_size = CardView.SIZE * 0.8
		var view := CardView.new()
		view.setup(Game.entry_id(g.entry), Game.entry_tier(g.entry), ("x%d" % g.count) if g.count > 1 else "", Game.entry_twist(g.entry))
		view.scale = Vector2(0.8, 0.8)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(view)
		col.add_child(wrap)
		if g.count > 1:
			var b := Button.new()
			var can: bool = Game.can_merge(g.i, g.j)
			b.text = ("Combine -> T%d" % (Game.entry_tier(g.entry) + 1)) if can else "Next tier locked"
			b.disabled = !can
			b.tooltip_text = "" if can else "Unlock this card's next tier in the Collection to combine them."
			var i: int = g.i
			var j: int = g.j
			b.pressed.connect(func(): Game.merge_hand(i, j))
			col.add_child(b)
		hand_row.add_child(col)
