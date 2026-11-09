extends CanvasLayer
## Card Fuser screen: pick two cards from your hand, see the hybrid, pay gold, fuse.
## The rules are Game.fuse_preview / Game.fuse_hand.

const UiKit = preload("res://ui/cards/ui_kit.gd")

var root_ctl: Control
var hand_box: HBoxContainer
var info_label: Label
var result_box: HBoxContainer
var fuse_button: Button
var recipes_label: RichTextLabel
var selected: Array = []        # hand indexes
var is_open := false

func _ready() -> void:
	add_to_group("card_fuse_ui")
	layer = 8
	var sc := UiKit.screen(self, "Card Fuser", close, "Pick two different cards of the same tier.")
	root_ctl = sc.root
	sc.right.text = ""
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	sc.body.add_child(top)
	var left := UiKit.panel()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	left.add_child(lv)
	lv.add_child(UiKit.heading("1. Your hand"))
	var lift_room := Control.new()                  # (a picked card is lifted: leave room so it does not cover the heading)
	lift_room.custom_minimum_size = Vector2(0, 14)
	lv.add_child(lift_room)
	hand_box = HBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 10)
	lv.add_child(hand_box)
	var right := UiKit.panel(Color(0.08, 0.08, 0.14))
	right.custom_minimum_size = Vector2(430, 0)
	top.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	right.add_child(rv)
	rv.add_child(UiKit.heading("2. Result"))
	result_box = HBoxContainer.new()
	result_box.custom_minimum_size = Vector2(0, 170)
	rv.add_child(result_box)
	info_label = Label.new()
	info_label.custom_minimum_size = Vector2(400, 50)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_font_size_override("font_size", 15)
	rv.add_child(info_label)
	rv.add_child(UiKit.heading("3. Fuse"))
	fuse_button = Button.new()
	fuse_button.text = "Fuse"
	fuse_button.custom_minimum_size = Vector2(150, 44)
	fuse_button.pressed.connect(fuse)
	rv.add_child(fuse_button)
	var bottom := UiKit.panel()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.body.add_child(bottom)
	var bv := VBoxContainer.new()
	bottom.add_child(bv)
	bv.add_child(UiKit.heading("Recipes"))
	recipes_label = RichTextLabel.new()
	recipes_label.bbcode_enabled = true
	recipes_label.fit_content = true
	recipes_label.add_theme_font_size_override("normal_font_size", 14)
	bv.add_child(recipes_label)
	Game.hand_changed.connect(func(): if is_open: _refresh())

func open() -> void:
	selected = []
	is_open = true
	root_ctl.visible = true
	_refresh()

func close() -> void:
	is_open = false
	root_ctl.visible = false

func _toggle(i: int) -> void:
	if i in selected:
		selected.erase(i)
	else:
		if selected.size() >= 2:
			selected.pop_front()
		selected.append(i)
	_refresh()

func _card(entry: String, mark: bool) -> CardView:
	var v := CardView.new()
	v.setup(Game.entry_id(entry), Game.entry_tier(entry), "", Game.entry_twist(entry))
	v.ready.connect(func(): v.set_state(mark, true))
	return v

func _refresh() -> void:
	for c in hand_box.get_children():
		hand_box.remove_child(c)
		c.queue_free()
	selected = selected.filter(func(i): return i < Game.hand.size())
	for i in Game.hand.size():
		var v := _card(Game.hand[i], i in selected)
		var idx := i
		v.pressed_down.connect(func(_v): _toggle(idx))
		hand_box.add_child(v)
	for c in result_box.get_children():
		result_box.remove_child(c)
		c.queue_free()
	if selected.size() == 2:
		var p: Dictionary = Game.fuse_preview(selected[0], selected[1])
		if p.has("result"):
			result_box.add_child(_card(p.result, false))
		info_label.text = ("Costs %d gold." % p.cost.gold) if p.ok else p.reason
		if p.ok:
			info_label.text += "  Gold in the keep: %d" % Game.resources.get("gold", 0)
		fuse_button.disabled = !p.ok
	else:
		info_label.text = "Pick two cards from your hand."
		fuse_button.disabled = true
	var lines := []
	for key in Game.FUSE_RECIPES:
		var parts: PackedStringArray = key.split("+")
		var r: Dictionary = Game.FUSE_RECIPES[key]
		lines.append("%s + %s = [b]%s[/b]  (%s)" % [Game.CARDS[parts[0]].name, Game.CARDS[parts[1]].name, Game.CARDS[r.result].name, Game.CARDS[r.result].desc.get_slice(": ", 1)])
	recipes_label.text = "\n".join(lines)

func fuse() -> void:
	if selected.size() == 2 and Game.fuse_hand(selected[0], selected[1]):
		selected = []
		_refresh()
