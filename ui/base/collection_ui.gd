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

const UiKit = preload("res://ui/cards/ui_kit.gd")
var grid_area: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 22
	var sc := UiKit.screen(self, "Card Collection", func():
		root_ctl.visible = false
		closed.emit(), "Click a card to see its numbers. Dark cards are locked: buy them with Shards. Owned cards can be upgraded with Shards (each tier makes it stronger). The gems under a card show the tier you own.")
	root_ctl = sc.root
	shards_label = sc.right
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	sc.body.add_child(body)
	var left := UiKit.panel()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	grid_area = Control.new()
	grid_area.clip_contents = true
	left.add_child(grid_area)
	var side := UiKit.panel(Color(0.08, 0.08, 0.14))
	side.custom_minimum_size = Vector2(380, 0)
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(side)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	side.add_child(sv)
	sv.add_child(UiKit.heading("Selected card"))
	detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_font_size_override("normal_font_size", 15)
	detail.add_theme_font_size_override("bold_font_size", 19)
	sv.add_child(detail)
	action_row = HBoxContainer.new()
	sv.add_child(action_row)

func open() -> void:
	root_ctl.visible = true
	if selected == "":
		selected = Game.CARDS.keys()[0]
	_refresh()

func _refresh() -> void:
	shards_label.text = "Shards: %d" % Game.meta.shards
	for c in grid_area.get_children():
		grid_area.remove_child(c)
		c.queue_free()
	var ids: Array = Game.CARDS.keys()
	var area: Vector2 = get_viewport().get_visible_rect().size - Vector2(470, 190)
	var fit := UiKit.fit_cards(ids.size(), area - Vector2(0, 0), 0.6, 6.0, 96.0)
	var cols: int = fit.cols
	var csize: Vector2 = fit.size
	var k := csize.x / CardView.SIZE.x
	var gem_h := 16.0
	var cell := Vector2(csize.x, csize.y + gem_h)
	for n in ids.size():
		var id: String = ids[n]
		var owned: bool = Game.owns_card(id)
		var tier: int = Game.card_tier(id) if owned else 0
		var view := CardView.new()
		view.setup(id, maxi(tier, 1))
		view.scale = Vector2(k, k)
		var holder := Control.new()
		holder.custom_minimum_size = cell
		holder.size = cell
		holder.position = Vector2((n % cols) * (cell.x + 6.0), (n / cols) * (cell.y + 6.0))
		holder.add_child(view)
		view.modulate = Color.WHITE if owned else Color(0.4, 0.4, 0.45)
		var gems := Label.new()
		gems.text = "◆".repeat(tier) + "◇".repeat(Game.MAX_LEVEL - tier)
		gems.position = Vector2(0, csize.y)
		gems.size = Vector2(csize.x, gem_h)
		gems.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gems.add_theme_font_size_override("font_size", 10)
		gems.add_theme_color_override("font_color", Color(1, 0.85, 0.3) if owned else Color(0.5, 0.5, 0.55))
		holder.add_child(gems)
		if id == selected:
			var frame := ReferenceRect.new()
			frame.border_color = Color("ffd23a")
			frame.border_width = 3.0
			frame.editor_only = false
			frame.size = csize
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(frame)
		view.pressed_down.connect(func(_v):
			selected = id
			_refresh())
		grid_area.add_child(holder)
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
