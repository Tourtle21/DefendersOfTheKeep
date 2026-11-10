extends CanvasLayer
## Forge screen: pick two weapons you carry, see the result, pay gold, fuse.

var root_ctl: Control
var list_box: Container          # the weapons in your hands
var store_box: Container         # the weapons stored in the forge
var held_title: Label
var store_title: Label
var store_btn: Button
var take_btn: Button
var info_label: Label
var fuse_button: Button
var awaken_button: Button
var journal: Label
var numbers: RichTextLabel
var recipes_box: HFlowContainer
var _focus_slot := -1
var _slot_cards := {}
var selected: Array = []        # slot indexes into the hud item slots

const UiKit = preload("res://ui/cards/ui_kit.gd")
const TierCard = preload("res://ui/cards/tier_card.gd")

func _ready() -> void:
	add_to_group("forge_ui")
	layer = 8
	_setup_merge_hint()
	var sc := UiKit.screen(self, "Forge", func(): root_ctl.visible = false,
		"Pick two weapons, then press the button.")
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
	lv.add_child(UiKit.heading("1. Pick two weapons"))
	var held_panel := UiKit.panel(Color(0.07, 0.12, 0.09), Color(0.35, 0.7, 0.4), 8.0)      # what is in your hands
	lv.add_child(held_panel)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 4)
	held_panel.add_child(hv)
	held_title = Label.new()
	held_title.add_theme_font_size_override("font_size", 16)
	held_title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
	hv.add_child(held_title)
	list_box = HFlowContainer.new()
	list_box.add_theme_constant_override("h_separation", 14)
	list_box.add_theme_constant_override("v_separation", 8)
	hv.add_child(list_box)
	var store_panel := UiKit.panel(Color(0.07, 0.09, 0.15), Color(0.4, 0.55, 0.85), 8.0)    # what is stored in the forge
	lv.add_child(store_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	store_panel.add_child(sv)
	store_title = Label.new()
	store_title.add_theme_font_size_override("font_size", 16)
	store_title.add_theme_color_override("font_color", Color(0.65, 0.8, 1.0))
	sv.add_child(store_title)
	store_box = HFlowContainer.new()
	store_box.add_theme_constant_override("h_separation", 14)
	store_box.add_theme_constant_override("v_separation", 8)
	sv.add_child(store_box)
	var right := UiKit.panel(Color(0.08, 0.08, 0.14))
	right.custom_minimum_size = Vector2(430, 0)
	top.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	right.add_child(rv)
	rv.add_child(UiKit.heading("2. Result"))
	info_label = Label.new()
	info_label.custom_minimum_size = Vector2(400, 60)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_font_size_override("font_size", 15)
	rv.add_child(info_label)
	numbers = RichTextLabel.new()
	numbers.bbcode_enabled = true
	numbers.fit_content = true
	numbers.add_theme_font_size_override("normal_font_size", 14)
	numbers.add_theme_font_size_override("bold_font_size", 14)
	rv.add_child(numbers)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(spacer)
	rv.add_child(UiKit.heading("3. Forge it"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	rv.add_child(row)
	fuse_button = Button.new()
	fuse_button.text = "Fuse"
	fuse_button.custom_minimum_size = Vector2(150, 44)
	fuse_button.pressed.connect(fuse)
	row.add_child(fuse_button)
	store_btn = Button.new()
	store_btn.text = "Drop into forge"
	store_btn.custom_minimum_size = Vector2(160, 44)
	store_btn.tooltip_text = "Leave the picked weapon in the forge so you do not have to carry it. Take it out or fuse it any time."
	store_btn.pressed.connect(_store_selected)
	row.add_child(store_btn)
	take_btn = Button.new()
	take_btn.text = "Take out"
	take_btn.custom_minimum_size = Vector2(130, 44)
	take_btn.pressed.connect(_take_selected)
	row.add_child(take_btn)
	awaken_button = Button.new()
	awaken_button.text = "Combine copies"
	awaken_button.custom_minimum_size = Vector2(200, 44)
	awaken_button.pressed.connect(awaken)
	row.add_child(awaken_button)
	journal = Label.new()          # kept for the recipe notes; the recipe cards below show the same thing
	journal.visible = false
	rv.add_child(journal)
	var bottom := UiKit.panel()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.body.add_child(bottom)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	bottom.add_child(bv)
	bv.add_child(UiKit.heading("Recipes you know"))
	var legend := Label.new()
	legend.text = "Green: click to forge     Yellow: need more     Grey: missing weapon"
	legend.add_theme_font_size_override("font_size", 13)
	legend.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	bv.add_child(legend)
	recipes_box = HFlowContainer.new()
	recipes_box.add_theme_constant_override("h_separation", 8)
	recipes_box.add_theme_constant_override("v_separation", 8)
	bv.add_child(recipes_box)

func _hud():
	return get_parent().get_node("Hud")

## ---- Merge on the spot: two weapons in your hands that fuse or combine can be merged anywhere, no forge trip ----
var _merge_clock := 0.0
var _merge_now := {}

func _setup_merge_hint() -> void:
	pass          # (the hint is drawn by the weapon slots widget on player 1's HUD; the F key is registered by Pad)

## The weapons in your hands as entries, in slot order: [{slot, entry}]
func _held_entries() -> Array:
	var out := []
	var slots = _hud().item_slots.get_children()
	for i in slots.size():
		if slots[i].has_item:
			out.append({"slot": i, "entry": _entry_of(slots[i].current_item)})
	return out

func _merge_options() -> Dictionary:
	var held := _held_entries()
	var m := Game.held_merge(held.map(func(h): return h.entry))
	if !m.is_empty():
		m["slot_a"] = held[m.a].slot
		m["slot_b"] = held[m.b].slot
	return m

func _process(delta: float) -> void:
	_merge_clock -= delta
	if _merge_clock > 0.0:
		return
	_merge_clock = 0.2
	var widget = _hud().slots_widget
	if widget == null:
		return
	var p = get_tree().get_first_node_in_group("player")
	if p == null or root_ctl.visible or Game.menu_open() or Game.local_in_base() or p.get("is_in_tower") or (Game.draft_active and Game.draft_owner_slot == 0):
		widget.hint = ""
		_merge_now = {}
		return
	_merge_now = _merge_options()
	if _merge_now.is_empty():
		widget.hint = ""
		return
	widget.hint = "%s: merge  %s  [%s]%s" % ["D-pad down" if Pad.using_pad else "F", _merge_now.text, Game.cost_line(_merge_now.cost), "" if _merge_now.ok else "  (not enough in the keep)"]
	widget.hint_ok = _merge_now.ok

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("merge_weapons") and !root_ctl.visible and !Game.menu_open():
		quick_merge()

## Merge the two held weapons the hint shows. Returns true if it happened.
func quick_merge() -> bool:
	var p = get_tree().get_first_node_in_group("player")
	if p == null or Game.local_in_base() or p.get("is_in_tower"):
		return false
	var m := _merge_options()
	if m.is_empty() or !m.ok:
		return false
	selected = [m.slot_a, m.slot_b]
	var es := _entries()
	if Game.entry_id(es[0]) == Game.entry_id(es[1]):
		awaken()
	else:
		fuse()
	selected = []
	_merge_clock = 0.0
	return true

func _item_id(info: Dictionary) -> String:
	if info.has("id"):
		return info.id
	var info_res = _hud().item_slots.get_child(0).item_info
	return info_res.items.find_key(info)

func _entry_of(info: Dictionary) -> String:
	return info.get("entry", _item_id(info))

func open() -> void:
	_refresh_journal()
	selected = []
	_refresh()
	root_ctl.visible = true

## Everything the forge can use: the weapons you hold (key 0-2) and the ones stored in the forge (key 100 and up).
func _all_items() -> Array:
	var out := []
	var slots = _hud().item_slots.get_children()
	for i in slots.size():
		if slots[i].has_item:
			out.append({"key": i, "entry": _entry_of(slots[i].current_item), "id": _item_id(slots[i].current_item), "held": true})
	for j in Game._forge_store.size():
		out.append({"key": 100 + j, "entry": Game._forge_store[j], "id": Game.entry_id(Game._forge_store[j]), "held": false})
	return out

func _item_for(key: int) -> Dictionary:
	for it in _all_items():
		if it.key == key:
			return it
	return {}

func _refresh() -> void:
	_slot_cards.clear()
	var held := []
	var stored := []
	for it in _all_items():
		(held if it.held else stored).append(it)
	held_title.text = "IN YOUR HANDS  (%d / 3)" % held.size()
	store_title.text = "IN THE FORGE  (%d / %d)  -  stays here for the whole team" % [stored.size(), Game.FORGE_STORE_MAX]
	_fill(list_box, held, "Nothing in your hands.")
	_fill(store_box, stored, "Nothing stored. Pick a weapon and press \"Drop into forge\".")
	_refresh_recipes()
	_update_info()
	if _focus_slot >= 0 and _slot_cards.has(_focus_slot) and root_ctl.visible and get_viewport().gui_get_focus_owner() == null:
		_slot_cards[_focus_slot].grab_focus.call_deferred()      # keep the controller's place after the cards rebuild

## One area of the forge screen: its weapons grouped by type, common first, a card per copy.
func _fill(box_parent: Container, items: Array, empty_text: String) -> void:
	for c in box_parent.get_children():
		box_parent.remove_child(c)
		c.queue_free()
	if items.is_empty():
		var l := Label.new()
		l.text = empty_text
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
		box_parent.add_child(l)
		return
	var groups := {}
	for it in items:
		if !groups.has(it.id):
			groups[it.id] = []
		groups[it.id].append(it)
	var ids: Array = groups.keys()
	ids.sort_custom(func(a, b):                      # common first, like every other screen
		var ra: int = Game.weapon_rarity(a)
		var rb: int = Game.weapon_rarity(b)
		return ra < rb or (ra == rb and Fusion.display_name(a) < Fusion.display_name(b)))
	for id in ids:
		var copies: Array = groups[id]
		copies.sort_custom(func(a, b): return Game.weapon_tier_of(a.entry) > Game.weapon_tier_of(b.entry))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		var head := Label.new()
		head.text = "%s  x%d" % [Fusion.display_name(id), copies.size()]
		head.add_theme_font_size_override("font_size", 15)
		head.add_theme_color_override("font_color", Game.rarity_color(Game.weapon_rarity(id)))
		box.add_child(head)
		var cards := HBoxContainer.new()
		cards.add_theme_constant_override("separation", 6)
		box.add_child(cards)
		for it in copies:
			var key: int = it.key
			var entry: String = it.entry
			var tw: String = Game.entry_twist(entry)
			var lines := []
			if tw != "" and Game.TWISTS.has(tw):
				lines.append("* " + Game.TWISTS[tw][0])
			var foot := "PICKED" if key in selected else ("HELD" if it.held else "STORED")
			var b := TierCard.new()
			b.setup({"size": Vector2(100, 140), "title": "T%d" % Game.weapon_tier_of(entry), "icon": _icon_for(id),
				"tier": Game.weapon_tier_of(entry), "max_tier": 6, "lines": lines,
				"accent": Game.rarity_color(Game.weapon_rarity(id)), "footer": foot, "footer_color": Color(0.5, 1, 0.55) if it.held else Color(0.6, 0.8, 1.0)})
			b.set_selected(key in selected)
			b.pressed.connect(func(_c): _toggle(key))
			b.focus_entered.connect(func(): _focus_slot = key)
			_slot_cards[key] = b
			cards.add_child(b)
		box_parent.add_child(box)


## key of a weapon by id among everything the forge can use (held or stored), skipping `not_key`
func _slot_of(id: String, not_key := -1) -> int:
	for it in _all_items():
		if it.key != not_key and it.id == id:
			return it.key
	return -1

func _icon_for(id: String) -> Texture2D:
	var items: Dictionary = load("res://world/item_info.tres").items
	if items.has(id) and items[id].has("texture"):
		return _icon_of(items[id].texture)
	return null

## highest tier of a copy of this weapon you hold or have stored, 0 if none
func _carried_tier(id: String) -> int:
	var best := 0
	for it in _all_items():
		if it.id == id:
			best = maxi(best, Game.weapon_tier_of(it.entry))
	return best

func _chip(id: String, tier_text: String) -> Control:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var tr := TextureRect.new()
	tr.texture = _icon_for(id)
	tr.custom_minimum_size = Vector2(48, 48)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tr)
	var l := Label.new()
	l.text = "%s\n%s" % [Fusion.display_name(id), tier_text]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 12)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	return v

## One card per weapon you hold or have stored: two copies of the same tier combine into the next tier (T1 + T1 = T2).
func _add_combines() -> void:
	var all := _all_items()
	var seen := {}
	for it in all:
		var e: String = it.entry
		var id: String = it.id
		var i: int = it.key
		var k := "%s:%d" % [id, Game.weapon_bonus(e)]
		if seen.has(k):
			continue
		seen[k] = true
		var j := -1
		for other in all:
			if other.key != i and other.id == id and Game.weapon_bonus(other.entry) == Game.weapon_bonus(e):
				j = other.key
				break
		var t := Game.weapon_tier_of(e)
		var res := Game.combine_weapons(e, e)
		var ok := j >= 0 and res != "" and Game.can_afford(Game.combine_cost(e))
		var rb := Button.new()
		rb.custom_minimum_size = Vector2(330, 100)
		rb.modulate = Color(0.5, 1.0, 0.5) if ok else (Color(1, 1, 0.5) if j >= 0 else Color(0.65, 0.65, 0.65))
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(_chip(id, "Tier %d" % t))
		var plus := Label.new()
		plus.text = "+"
		h.add_child(plus)
		h.add_child(_chip(id, "Tier %d%s" % [t, "" if j >= 0 else " (need a 2nd)"]))
		var arrow := Label.new()
		arrow.text = "->"
		h.add_child(arrow)
		var by_draw: bool = res == "" and Game.combine_locked_by_draw(e)
		h.add_child(_chip(id, ("Tier %d" % (t + 1)) if res != "" else ("Tier %d locked" % (t + 1) if by_draw else "max for now")))
		rb.add_child(h)
		if j >= 0:
			rb.pressed.connect(func():
				selected = [i, j]
				_refresh()
				if ok:
					awaken())
		else:
			rb.disabled = true
		recipes_box.add_child(rb)

func _refresh_recipes() -> void:
	for c in recipes_box.get_children():
		recipes_box.remove_child(c)
		c.queue_free()
	_add_combines()
	for key in Fusion.RECIPES:
		var r: Dictionary = Fusion.RECIPES[key]
		if !Game.weapon_known(r.id):
			continue
		var p: PackedStringArray = key.split("+")
		var a := _slot_of(p[0])
		var b := _slot_of(p[1], a)
		var carry := a >= 0 and b >= 0
		var ok := carry and Game.fusion_tier_unlocked(r.tier) and Game.can_afford(Fusion.cost(r.tier))
		var rb := Button.new()
		rb.custom_minimum_size = Vector2(330, 100)
		rb.modulate = Color(0.5, 1.0, 0.5) if ok else (Color(1, 1, 0.5) if carry else Color(0.65, 0.65, 0.65))
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ta := _carried_tier(p[0])
		var tb := _carried_tier(p[1])
		h.add_child(_chip(p[0], ("T%d carried" % ta) if ta > 0 else "not carried"))
		var plus := Label.new()
		plus.text = "+"
		h.add_child(plus)
		h.add_child(_chip(p[1], ("T%d carried" % tb) if tb > 0 else "not carried"))
		var arrow := Label.new()
		arrow.text = "->"
		h.add_child(arrow)
		var lock := "" if Game.fusion_tier_unlocked(r.tier) else " (locked)"
		h.add_child(_chip(r.id, "Tier %d%s" % [r.tier, lock]))
		rb.add_child(h)
		if carry:
			rb.pressed.connect(func():
				selected = [a, b]
				_refresh()
				if ok:
					fuse())
		else:
			rb.disabled = true
		recipes_box.add_child(rb)

## Recipes you have discovered (previewed or fused) are listed; the rest stay hidden.
func _refresh_journal() -> void:
	var seen: Array = Game.meta.get("recipes_seen", [])
	var lines := ["Recipes you know (unlock weapons to reveal more)"]
	for tier in [2, 3, 4]:
		var hidden := 0
		for key in Fusion.RECIPES:
			var r: Dictionary = Fusion.RECIPES[key]
			if r.tier != tier:
				continue
			if Game.weapon_known(r.id):
				var p: PackedStringArray = key.split("+")
				var locked := "" if Game.fusion_tier_unlocked(tier) else "  (needs Tier %d fusions)" % tier
				lines.append("T%d  %s + %s = %s%s" % [tier, Fusion.display_name(p[0]), Fusion.display_name(p[1]), Fusion.display_name(r.id), locked])
			else:
				hidden += 1
		if hidden > 0:
			lines.append("T%d  %d more recipes: unlock their ingredients" % [tier, hidden])
	journal.text = "\n".join(lines)

func _toggle(i: int) -> void:
	if i in selected:
		selected.erase(i)
	elif selected.size() < 2:
		selected.append(i)
	else:
		selected = [selected[1], i]
	_refresh()

func _selected_ids() -> Array:
	var ids := []
	for k in selected:
		ids.append(_item_for(k).get("id", ""))
	return ids

func _entries() -> Array:
	var out := []
	for k in selected:
		out.append(_item_for(k).get("entry", ""))
	return out

## Take the picked weapons away (held ones leave the slots, stored ones leave the forge).
## Returns true if one of them was the weapon in your hand.
func _consume_selected() -> bool:
	var hud = _hud()
	var was_active := false
	var held := []
	var stored := []
	for k in selected:
		if k >= 100:
			stored.append(k - 100)
		else:
			held.append(k)
	stored.sort()
	stored.reverse()
	for j in stored:
		Game._forge_store.remove_at(j)
	held.sort()
	held.reverse()                 # remove the higher slot first so the other index stays valid
	var slots = hud.item_slots.get_children()
	for i in held:
		if slots[i].is_active:
			was_active = true
		hud.remove_slot(i)
	return was_active

## The new weapon goes into your hands if there is room, otherwise it waits in the forge.
func _place_result(entry: String, was_active: bool) -> void:
	var hud = _hud()
	var player = get_tree().get_first_node_in_group("player")
	var info := Game.weapon_info(entry)
	if hud.equip_item(info):
		player.equip_item(info)
	else:
		if Game._forge_store.size() < Game.FORGE_STORE_MAX:
			Game._forge_store.append(entry)
		if was_active:
			_equip_any()

## After the weapon in your hand left, pick up another one you still hold (or none).
func _equip_any() -> void:
	var hud = _hud()
	var player = get_tree().get_first_node_in_group("player")
	var slots = hud.item_slots.get_children()
	for i in slots.size():
		if slots[i].has_item:
			if hud.active_item_slot != -1 and hud.active_item_slot != i:
				slots[hud.active_item_slot].toggle_active()
			if !slots[i].is_active:
				slots[i].toggle_active()
			hud.active_item_slot = i
			player.equip_item(slots[i].current_item)
			return
	player.clear_item()

func _store_selected() -> void:
	if selected.size() != 1 or selected[0] >= 100 or Game._forge_store.size() >= Game.FORGE_STORE_MAX:
		return
	var it := _item_for(selected[0])
	var was_active := _consume_selected()
	Game._forge_store.append(it.entry)
	if was_active:
		_equip_any()
	Sfx.play("unlock", 0.0)
	selected = []
	_refresh()

func _take_selected() -> void:
	if selected.size() != 1 or selected[0] < 100:
		return
	var it := _item_for(selected[0])
	var hud = _hud()
	var player = get_tree().get_first_node_in_group("player")
	var info := Game.weapon_info(it.entry)
	Game._forge_store.remove_at(selected[0] - 100)
	if hud.equip_item(info):
		player.equip_item(info)
	else:
		Game._forge_store.append(it.entry)          # no free hand slot: it stays in the forge
	selected = []
	_refresh()

func _cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in cost:
		parts.append("%d %s (have %d)" % [cost[k], k, Game.resources.get(k, 0)])
	return ", ".join(parts)

func _update_info() -> void:
	store_btn.disabled = !(selected.size() == 1 and selected[0] < 100 and Game._forge_store.size() < Game.FORGE_STORE_MAX)
	var free := false
	for sl in _hud().item_slots.get_children():
		if !sl.has_item:
			free = true
	take_btn.disabled = !(selected.size() == 1 and selected[0] >= 100 and free)
	numbers.text = ""
	fuse_button.disabled = true
	awaken_button.disabled = true
	awaken_button.visible = false
	if selected.size() == 1:
		var e: String = _entries()[0]
		var id := Game.entry_id(e)
		info_label.text = "Now pick a second weapon."
		return
	if selected.size() < 2:
		info_label.text = "Pick two weapons."
		return
	var es := _entries()
	var ids := _selected_ids()
	if ids[0] == ids[1]:
		_info_combine(es[0], es[1])
		return
	var r := Fusion.recipe(ids[0], ids[1])
	if r.is_empty():
		info_label.text = "These two cannot fuse."
		return
	Game.note_recipe(Fusion.key(ids[0], ids[1]))
	_refresh_journal()
	if !Game.fusion_tier_unlocked(r.tier):
		info_label.text = "%s: locked (buy Tier %d fusions)." % [Fusion.display_name(r.id), r.tier]
		return
	var cost: Dictionary = Fusion.cost(r.tier)
	info_label.text = "%s  (Tier %d)\nCost: %s" % [Fusion.display_name(r.id), r.tier, _cost_text(cost)]
	fuse_button.disabled = !Game.can_afford(cost)
	fuse_button.text = "Fuse"

## Two identical copies of the same tier combine into one a tier higher (needs the materials).
func _info_combine(a: String, b: String) -> void:
	awaken_button.visible = true
	if Game.weapon_bonus(a) != Game.weapon_bonus(b):
		info_label.text = "Tiers differ (%d and %d). Pick matching tiers." % [Game.weapon_tier_of(a), Game.weapon_tier_of(b)]
		return
	var id := Game.entry_id(a)
	var result := Game.combine_weapons(a, b)
	var t := Game.weapon_tier_of(a)
	if result == "":
		if t >= 6:
			info_label.text = "Max tier."
		elif Game.combine_locked_by_draw(a):
			info_label.text = "Tier %d locked.\nDraw it at the end of a run." % (t + 1)
		else:
			info_label.text = "Tier %d is the limit for now." % t
		return
	var cost: Dictionary = Game.combine_cost(a)
	var gained: String = Game.weapon_twist(id, t + 1)
	var twist_note: String = ("  Gains the twist: " + Game.TWISTS[gained][0]) if gained != "" and Game.TWISTS.has(gained) else ""
	info_label.text = "%s: tier %d -> %d%s\nCost: %s" % [Fusion.display_name(id), t, t + 1, twist_note, _cost_text(cost)]
	awaken_button.disabled = !Game.can_afford(cost)
	awaken_button.text = "Combine into tier %d" % (t + 1)
	numbers.text = _weapon_numbers(Game.weapon_info(a), Game.weapon_bonus(a))

func _weapon_numbers(info: Dictionary, bonus: int) -> String:
	return preload("res://ui/forge/forge_layout.gd").numbers_text(info, bonus)

## Combine two identical copies.
func awaken() -> void:
	if selected.size() != 2:
		return
	var es := _entries()
	var result := Game.combine_weapons(es[0], es[1])
	var cost: Dictionary = Game.combine_cost(es[0]) if result != "" else {}
	if result == "" or !Game.can_afford(cost):
		return
	Game.pay(cost)
	var was_active := _consume_selected()
	_place_result(result, was_active)
	Sfx.play("unlock", 0.0)
	selected = []
	_refresh()

func fuse() -> void:
	if selected.size() < 2:
		return
	var ids := _selected_ids()
	var r := Fusion.recipe(ids[0], ids[1])
	if r.is_empty():
		return
	var cost: Dictionary = Fusion.cost(r.tier)
	if !Game.fusion_tier_unlocked(r.tier) or !Game.can_afford(cost):
		return
	Game.pay(cost)
	var was_active := _consume_selected()
	_place_result(Game.make_weapon_entry(r.id, 0, Game.weapon_twist(r.id, r.tier)), was_active)
	root_ctl.visible = false
	selected = []

## Tools like the sword and pickaxe use sprite sheets: show just the first frame.
const SHEETS := {"res://items/tools/sword/excalibur_.png": Vector2i(4, 4), "res://items/tools/pickaxe/pickaxe.png": Vector2i(2, 2)}

func _icon_of(path: String) -> Texture2D:
	var tex: Texture2D = load(path)
	if SHEETS.has(path):
		var grid: Vector2i = SHEETS[path]
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(0, 0, tex.get_width() / grid.x, tex.get_height() / grid.y)
		return at
	return tex
