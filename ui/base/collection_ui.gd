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
var tab_id := "cards"
const TierCard = preload("res://ui/cards/tier_card.gd")
var grid_area: Control          # the spells column
var build_area: Control         # the buildings column
var _auto_refreshes := 0        # how many times the layout settling has redrawn the grid since it opened (capped: no endless redraw)
var _laid_out := Vector2.ZERO
var tier_row: HBoxContainer
var _focus_id := ""
var _views := {}
var viewed_tier := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 22
	add_to_group("tab_screen")
	var sc := UiKit.screen(self, "Card Collection", func():
		root_ctl.visible = false
		closed.emit(), "Click a card. Dark = locked. Gems = your tier.", "cards")
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
	var cols_box := HBoxContainer.new()                 # spells on the left, buildings on the right
	cols_box.add_theme_constant_override("separation", 14)
	left.add_child(cols_box)
	var mk := func(title: String) -> Control:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 6)
		cols_box.add_child(col)
		col.add_child(UiKit.heading(title, UiKit.FONT_HEAD))
		var area := Control.new()
		area.clip_contents = true
		area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		area.custom_minimum_size = Vector2(160, 160)       # (a fixed floor, so the cards inside never push the column bigger)
		area.resized.connect(func():              # the panel settles after first layout: redraw at its real size, a few times at most
			if root_ctl != null and root_ctl.visible and _auto_refreshes < 3 and (area.size - _laid_out).length() > 24.0:
				_auto_refreshes += 1
				_laid_out = area.size
				_refresh.call_deferred())
		col.add_child(area)
		return area
	grid_area = mk.call("SPELLS")
	build_area = mk.call("BUILDINGS")
	var side := UiKit.panel(UiKit.RESULT_BG)
	side.custom_minimum_size = Vector2(470, 0)
	side.size_flags_horizontal = Control.SIZE_SHRINK_END
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(side)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	side.add_child(sv)
	sv.add_child(UiKit.heading("Tiers  (click one to see it)"))
	tier_row = HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 6)
	sv.add_child(tier_row)
	detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_font_size_override("normal_font_size", UiKit.FONT_BODY)
	detail.add_theme_font_size_override("bold_font_size", UiKit.FONT_HEAD)
	sv.add_child(detail)
	action_row = HBoxContainer.new()
	sv.add_child(action_row)

func open() -> void:
	root_ctl.visible = true
	_auto_refreshes = 0
	_laid_out = Vector2.ZERO
	if selected == "":
		selected = Game.CARDS.keys()[0]
	await get_tree().process_frame
	_refresh()

func _refresh() -> void:
	shards_label.text = "Shards: %d" % Game.meta.shards
	for area in [grid_area, build_area]:
		for c in area.get_children():
			area.remove_child(c)
			c.queue_free()
	_views.clear()
	var ids: Array = Game.CARDS.keys().filter(func(id): return !Game.CARDS[id].get("fused", false))
	var order := {}
	for i in ids.size():
		order[ids[i]] = i
	ids.sort_custom(func(a, b):                    # common first, rare last, like the order they come up
		var ra: int = Game.card_rarity(a)
		var rb: int = Game.card_rarity(b)
		return ra < rb or (ra == rb and order[a] < order[b]))
	var spells: Array = ids.filter(func(id): return !Game.is_build(id))
	var builds: Array = ids.filter(func(id): return Game.is_build(id))
	var biggest := maxi(spells.size(), builds.size())          # both columns use the same card size
	_place(spells, grid_area, biggest)
	_place(builds, build_area, biggest)
	_show_detail()
	if _focus_id != "" and _views.has(_focus_id) and root_ctl.visible and get_viewport().gui_get_focus_owner() == null:
		_views[_focus_id].grab_focus.call_deferred()      # the cards were rebuilt: keep the controller's place

## Lay out `ids` as cards in `target` (one column of the collection), as big as fit without scrolling.
func _place(ids: Array, target: Control, size_for: int) -> void:
	var area: Vector2 = target.size if target.size.x > 100 else (get_viewport().get_visible_rect().size - Vector2(470, 190)) * Vector2(0.5, 1.0)
	area.y -= 16.0 * ceili(sqrt(size_for / 1.6))      # room for the gem row under each card
	var fit := UiKit.fit_cards(size_for, area, 0.6, 6.0, 132.0)
	var cols: int = fit.cols
	var csize: Vector2 = fit.size
	var k := csize.x / CardView.SIZE.x
	var gem_h := 16.0
	var cell := Vector2(csize.x, csize.y + gem_h)
	var off_x := maxf(0.0, (area.x - (cols * (cell.x + 6.0) - 6.0)) / 2.0)
	for n in ids.size():
		var id: String = ids[n]
		var owned: bool = Game.owns_card(id)
		var tier: int = Game.card_tier(id) if owned else 0
		var seen: bool = Game.is_seen(id)
		var view: Control
		if seen:
			view = CardView.new()
			view.setup(id, maxi(tier, 1))
			view.scale = Vector2(k, k)
			view.focus_mode = Control.FOCUS_ALL                  # controller: the d-pad moves between cards, A selects
			view.pressed_down.connect(func(_v):
				selected = id
				viewed_tier = -1
				_refresh())
		else:
			view = TierCard.new()                      # not met yet: a "?" card
			view.setup({"size": csize, "title": "???", "glyph": "?", "accent": UiKit.MUTED_DARK, "locked": true})
			view.pressed.connect(func(_c):
				selected = id
				viewed_tier = -1
				_refresh())
		var holder := Control.new()
		holder.custom_minimum_size = cell
		holder.size = cell
		holder.position = Vector2(off_x + (n % cols) * (cell.x + 6.0), (n / cols) * (cell.y + 6.0))
		holder.add_child(view)
		var gems := Label.new()
		gems.text = ("◆".repeat(tier) + "◇".repeat(Game.MAX_LEVEL - tier)) if seen else ""
		gems.position = Vector2(0, csize.y)
		gems.size = Vector2(csize.x, gem_h)
		gems.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gems.add_theme_font_size_override("font_size", UiKit.FONT_TINY)
		gems.add_theme_color_override("font_color", UiKit.GOLD if owned else UiKit.MUTED_DARK)
		if Game.upgrade_available(id):                    # the gems blink: this card can be upgraded
			var bt := gems.create_tween().set_loops()
			bt.tween_property(gems, "modulate:a", 0.25, 0.5)
			bt.tween_property(gems, "modulate:a", 1.0, 0.5)
		holder.add_child(gems)
		if id == selected:
			var frame := ReferenceRect.new()
			frame.border_color = UiKit.GOLD_BRIGHT
			frame.border_width = 3.0
			frame.editor_only = false
			frame.size = csize
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(frame)
		view.focus_entered.connect(func(): _focus_id = id)
		_views[id] = view
		target.add_child(holder)
		if view is CardView:
			view.set_state(false, owned)               # the card keeps its own dimming on hover (it resets modulate itself)

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
	for old in get_tree().get_nodes_in_group("spare_rows"):
		if is_instance_valid(old) and is_ancestor_of(old):
			old.queue_free()
	for c in action_row.get_children():
		action_row.remove_child(c)
		c.queue_free()
	for c in tier_row.get_children():
		tier_row.remove_child(c)
		c.queue_free()
	var id := selected
	var c: Dictionary = Game.CARDS[id]
	var owned: bool = Game.owns_card(id)
	if !Game.is_seen(id):
		detail.text = "[b]???[/b]\nNot found yet.\nGet it as a reward at the end of a run."
		return
	var owned_tier: int = Game.card_tier(id) if owned else 0
	if viewed_tier < 1 or viewed_tier > Game.MAX_LEVEL:
		viewed_tier = maxi(1, owned_tier)
	for t in range(1, Game.MAX_LEVEL + 1):
		var ok := t <= owned_tier
		var next_up: bool = t == owned_tier + 1 and Game.upgrade_available(id)      # drawn: can be bought now
		var tc := TierCard.new()
		tc.setup({"size": Vector2(62, 76), "title": "T%d" % t, "glyph": "T%d" % t if (ok or next_up) else "", "lock": !ok and !next_up, "locked": !ok and !next_up,
			"blink": next_up, "footer": ("%d" % Game.card_upgrade_cost(id)) if next_up else "",
			"accent": Game.rarity_color(Game.card_rarity(id)), "tooltip": "Tier %d%s" % [t, "" if ok else (" (upgrade available)" if next_up else " (locked: draw it at the end of a run)")]})
		tc.set_selected(t == viewed_tier)
		tc.pressed.connect(func(_c):
			viewed_tier = t
			_show_detail())
		tier_row.add_child(tc)
	var t := viewed_tier
	var txt := "[b]%s[/b]   tier [color=#ffd23a][b]%d[/b][/color]%s\n" % [c.name, t, "" if t <= owned_tier else "   [color=#ff9a7a](locked)[/color]"]
	txt += "[color=#c9d3f2]%s[/color]\n" % c.desc
	for ad in Game.adds_for(id, t, Game.twist_for(id, t)):
		if Game.TWISTS.has(ad):
			txt += "\n[b]Added[/b]  [color=#ffd23a]%s[/color]: %s\n" % [Game.TWISTS[ad][0], Game.TWISTS[ad][1]]
	txt += "\n" + _num_block(id, t, t + 1)
	if !owned:
		txt += "\n\n[color=#ff9a7a]Not unlocked yet.[/color]"
	detail.text = txt
	if owned:
		_add_spare_rows(id)
		var up := Button.new()
		if owned_tier >= Game.MAX_LEVEL:
			up.text = "Max tier"
			up.disabled = true
		else:
			if Game.upgrade_available(id):
				up.text = "Upgrade to tier %d  (%d shards)" % [owned_tier + 1, Game.card_upgrade_cost(id)]
				up.disabled = Game.meta.shards < Game.card_upgrade_cost(id)
			else:
				up.text = "Draw the tier %d card to upgrade" % (owned_tier + 1)
				up.disabled = true
			up.pressed.connect(func():
				if Game.upgrade_card(id):
					viewed_tier = -1
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
			buy.text = "Legendary: beat the whole game"
			buy.disabled = true
		else:
			buy.text = "Found: unlock it for shards"
			buy.disabled = true
		action_row.add_child(buy)

## Spare copies of this card waiting in the vault (from reward draws): merge, combine or sell them here.
func _add_spare_rows(id: String) -> void:
	var by_tier := {}
	for pe in Game.meta.pending:
		if pe.get("result", "") == "spare" and str(pe.id) == id and !by_tier.has(int(pe.tier)):
			by_tier[int(pe.tier)] = pe
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var head := UiKit.heading("Spare copies", UiKit.FONT_BODY)
	col.add_child(head)
	if by_tier.is_empty():
		var none := Label.new()
		none.text = "None yet. Duplicates you draw at the end of a run land here."
		none.add_theme_font_size_override("font_size", UiKit.FONT_SMALL)
		none.add_theme_color_override("font_color", UiKit.TEXT_DIM)
		col.add_child(none)
	for t in by_tier:
		var entry: Dictionary = by_tier[t]
		var n := 0
		for pe in Game.meta.pending:
			if pe.get("result", "") == "spare" and str(pe.id) == id and int(pe.tier) == t:
				n += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var l := Label.new()
		l.text = "T%d x%d" % [t, n]
		row.add_child(l)
		var merge := Button.new()
		merge.text = "Merge -> T%d" % (t + 1)
		merge.disabled = !Game.spare_can_merge(entry)
		merge.pressed.connect(func():
			if Game.spare_merge(entry):
				viewed_tier = -1
				_refresh())
		row.add_child(merge)
		if !Game.spare_pair(entry).is_empty() and t < Game.MAX_LEVEL:
			var comb := Button.new()
			comb.text = "Combine -> T%d" % (t + 1)
			comb.pressed.connect(func():
				if Game.spare_combine(entry):
					_refresh())
			row.add_child(comb)
		var sell := Button.new()
		sell.text = "Sell +%d" % Game.spare_sell_value(entry)
		sell.pressed.connect(func():
			Game.spare_sell(entry)
			_refresh())
		row.add_child(sell)
		col.add_child(row)
	action_row.get_parent().add_child(col)
	action_row.get_parent().move_child(col, action_row.get_index())
	col.add_to_group("spare_rows")
