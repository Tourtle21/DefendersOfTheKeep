extends CanvasLayer
class_name CollectionUi
## Permanent card collection: every card with its tier (1-6). Click a card to see
## its real numbers at this tier next to the next tier (changes highlighted) and
## spend Shards to upgrade it. Locked cards can be bought with Shards too.

var root_ctl: Control
var grid: GridContainer
var detail: RichTextLabel
var action_row: HBoxContainer
var shards_label: Label
var selected := ""
signal closed

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 22
	root_ctl = Control.new()
	root_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctl.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ctl.visible = false
	add_child(root_ctl)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.08, 0.96)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctl.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	root_ctl.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)
	var top := HBoxContainer.new()
	outer.add_child(top)
	var title := Label.new()
	title.text = "Card Collection"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	shards_label = Label.new()
	shards_label.add_theme_font_size_override("font_size", 20)
	shards_label.add_theme_color_override("font_color", Color("8fd8ff"))
	top.add_child(shards_label)
	var close := Button.new()
	close.text = "Back"
	close.custom_minimum_size = Vector2(110, 36)
	close.pressed.connect(func():
		root_ctl.visible = false
		closed.emit())
	top.add_child(close)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	outer.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(330, 0)
	side.add_theme_constant_override("separation", 10)
	body.add_child(side)
	detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.fit_content = true
	detail.add_theme_font_size_override("normal_font_size", 16)
	detail.add_theme_font_size_override("bold_font_size", 20)
	side.add_child(detail)
	action_row = HBoxContainer.new()
	side.add_child(action_row)

func open() -> void:
	root_ctl.visible = true
	if selected == "":
		selected = Game.CARDS.keys()[0]
	_refresh()

func _refresh() -> void:
	shards_label.text = "Shards: %d" % Game.meta.shards
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	for id in Game.CARDS:
		var owned: bool = Game.owns_card(id)
		var view := CardView.new()
		view.setup(id, Game.card_tier(id) if owned else 1)
		var holder := Control.new()
		holder.custom_minimum_size = CardView.SIZE
		holder.add_child(view)
		holder.modulate = Color.WHITE if owned else Color(0.4, 0.4, 0.45)
		if id == selected:
			var frame := ReferenceRect.new()
			frame.border_color = Color("ffd23a")
			frame.border_width = 3.0
			frame.editor_only = false
			frame.size = CardView.SIZE
			holder.add_child(frame)
		view.pressed_down.connect(func(_v):
			selected = id
			_refresh())
		grid.add_child(holder)
	_show_detail()

func _num_block(id: String, tier: int, next_tier: int) -> String:
	var cur := Game.card_numbers(id, tier)
	var nxt := Game.card_numbers(id, next_tier) if next_tier > tier else []
	var lines := []
	for i in cur.size():
		var line := "%s  [color=#ffd23a][b]%s[/b][/color]" % [cur[i].label, cur[i].text]
		if i < nxt.size() and nxt[i].text != cur[i].text:
			var better: bool = (nxt[i].v - cur[i].v) * cur[i].good >= 0.0
			line += "  ->  [color=%s][b]%s[/b][/color]" % ["#6df08a" if better else "#ff9a7a", nxt[i].text]
		lines.append(line)
	return "\n".join(lines)

func _show_detail() -> void:
	for c in action_row.get_children():
		action_row.remove_child(c)
		c.queue_free()
	var id := selected
	var c: Dictionary = Game.CARDS[id]
	var owned: bool = Game.owns_card(id)
	var tier := Game.card_tier(id) if owned else 1
	var t := "[b]%s[/b]\n" % c.name
	t += "[color=#c9d3f2]%s[/color]\n\n" % c.desc
	if owned:
		t += "Unlocked tier [color=#ffd23a][b]%d[/b][/color] of %d. In a run this card starts at tier 1 and can be raised (chest duplicates, merging buildings) up to tier %d." % [tier, Game.MAX_LEVEL, tier]
		if tier < Game.MAX_LEVEL:
			t += "   (next tier shown in green)"
		t += "\n\n" + _num_block(id, tier, tier + 1)
	else:
		t += "[color=#ff9a7a]Not unlocked.[/color] Tier 1 shown.\n\n" + _num_block(id, 1, 1)
	detail.text = t
	if owned:
		var up := Button.new()
		if tier >= Game.MAX_LEVEL:
			up.text = "Max tier"
			up.disabled = true
		else:
			up.text = "Upgrade to tier %d  (%d shards)" % [tier + 1, Game.card_upgrade_cost(id)]
			up.disabled = Game.meta.shards < Game.card_upgrade_cost(id)
			up.pressed.connect(func():
				if Game.upgrade_card(id):
					_refresh())
		action_row.add_child(up)
	else:
		var buy := Button.new()
		if Game.can_buy_card(id):
			buy.text = "Unlock (%d shards)" % Game.unlock_price(id)
			buy.disabled = Game.meta.shards < Game.unlock_price(id)
			buy.pressed.connect(func():
				if Game.buy_unlock(id):
					_refresh())
		elif Game.is_legendary_card(id):
			buy.text = "Legendary: beat the whole game to unlock one"
			buy.disabled = true
		else:
			buy.text = "Reach level %d, or find it in a reward draw" % Game.card_level(id)
			buy.disabled = true
		action_row.add_child(buy)
