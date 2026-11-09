extends CanvasLayer
## Forge screen: pick two weapons you carry, see the result, pay gold, fuse.

var root_ctl: Control
var list_box: HBoxContainer
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
	lv.add_child(UiKit.heading("1. Your weapons"))
	list_box = HBoxContainer.new()
	list_box.add_theme_constant_override("separation", 12)
	lv.add_child(list_box)
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

func _refresh() -> void:
	for c in list_box.get_children():
		list_box.remove_child(c)
		c.queue_free()
	_slot_cards.clear()
	var slots = _hud().item_slots.get_children()
	for i in slots.size():
		if !slots[i].has_item:
			continue
		var id: String = _item_id(slots[i].current_item)
		var entry: String = _entry_of(slots[i].current_item)
		var tw: String = Game.entry_twist(entry)
		var b := TierCard.new()
		var lines := []
		if tw != "" and Game.TWISTS.has(tw):
			lines.append("* " + Game.TWISTS[tw][0])
		b.setup({"size": Vector2(150, 210), "title": Fusion.display_name(id), "icon": _icon_of(slots[i].current_item.texture),
			"tier": Game.weapon_tier_of(entry), "max_tier": 6, "lines": lines,
			"accent": Game.rarity_color(Game.weapon_rarity(id)), "footer": "PICKED" if i in selected else ""})
		b.set_selected(i in selected)
		b.pressed.connect(func(_c): _toggle(i))
		b.focus_entered.connect(func(): _focus_slot = i)
		_slot_cards[i] = b
		list_box.add_child(b)
	_refresh_recipes()
	_update_info()
	if _focus_slot >= 0 and _slot_cards.has(_focus_slot) and root_ctl.visible and get_viewport().gui_get_focus_owner() == null:
		_slot_cards[_focus_slot].grab_focus.call_deferred()      # keep the controller's place after the cards rebuild

## slot index of a carried weapon by id, skipping `not_slot`
func _slot_of(id: String, not_slot := -1) -> int:
	var slots = _hud().item_slots.get_children()
	for i in slots.size():
		if i != not_slot and slots[i].has_item and _item_id(slots[i].current_item) == id:
			return i
	return -1

func _icon_for(id: String) -> Texture2D:
	var items: Dictionary = load("res://world/item_info.tres").items
	if items.has(id) and items[id].has("texture"):
		return _icon_of(items[id].texture)
	return null

## highest tier of a carried copy of this weapon, 0 if you do not carry it
func _carried_tier(id: String) -> int:
	var best := 0
	var slots = _hud().item_slots.get_children()
	for i in slots.size():
		if slots[i].has_item and _item_id(slots[i].current_item) == id:
			best = maxi(best, Game.weapon_tier_of(_entry_of(slots[i].current_item)))
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

## One card per carried weapon: two copies of the same tier combine into the next tier (T1 + T1 = T2).
func _add_combines() -> void:
	var slots = _hud().item_slots.get_children()
	var seen := {}
	for i in slots.size():
		if !slots[i].has_item:
			continue
		var e: String = _entry_of(slots[i].current_item)
		var id := Game.entry_id(e)
		var k := "%s:%d" % [id, Game.weapon_bonus(e)]
		if seen.has(k):
			continue
		seen[k] = true
		var j := -1
		for m in slots.size():
			if m != i and slots[m].has_item and _item_id(slots[m].current_item) == id and Game.weapon_bonus(_entry_of(slots[m].current_item)) == Game.weapon_bonus(e):
				j = m
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
	var slots = _hud().item_slots.get_children()
	var ids := []
	for i in selected:
		ids.append(_item_id(slots[i].current_item))
	return ids

func _entries() -> Array:
	var slots = _hud().item_slots.get_children()
	var out := []
	for i in selected:
		out.append(_entry_of(slots[i].current_item))
	return out

func _cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in cost:
		parts.append("%d %s (have %d)" % [cost[k], k, Game.resources.get(k, 0)])
	return ", ".join(parts)

func _update_info() -> void:
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

## Real numbers for the weapon now and one tier up (green). Each tier of bonus gives +20%
## damage and -8% cooldowns.
func _weapon_numbers(info: Dictionary, bonus: int) -> String:
	var inst = load(info["path"]).instantiate()
	var cds := [["Attack", inst.attack_cooldown, inst.attack_name], ["Ability (T2)", inst.ability_cooldown, inst.ability_name],
		["Dash", inst.dash_cooldown, inst.dash_name], ["Ultimate (T3)", inst.ultimate_cooldown, inst.ultimate_name]]
	inst.free()
	var r: int = Game.weapon_rarity(str(info.id))
	var fz: float = pow(0.95, Fusion.tier_of(str(info.id)) - 1)
	var lines := ["[color=#%s][b]%s[/b][/color] weapon" % [Game.rarity_color(r).to_html(false), Game.rarity_name(r)], "Damage  [color=#ffd23a][b]x%.1f[/b][/color]  ->  [color=#6df08a][b]x%.1f[/b][/color]" % [Game.weapon_power(str(info.id), bonus), Game.weapon_power(str(info.id), bonus + 1)]]
	for c in cds:
		if c[2] == "":
			continue
		lines.append("%s: %s  [color=#ffd23a][b]%.2fs[/b][/color]  ->  [color=#6df08a][b]%.2fs[/b][/color]" % [c[0], c[2], c[1] * fz * pow(0.92, bonus), c[1] * fz * pow(0.92, bonus + 1)])
	return "\n".join(lines)

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
	var hud = _hud()
	var picked := selected.duplicate()
	picked.sort()
	picked.reverse()
	for i in picked:
		hud.remove_slot(i)
	var new_info := Game.weapon_info(result)
	var player = get_tree().get_first_node_in_group("player")
	if hud.equip_item(new_info):
		player.equip_item(new_info)
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
	var hud = _hud()
	var gone := selected.duplicate()
	gone.sort()
	gone.reverse()                 # remove the higher slot first so the other index stays valid
	for i in gone:
		hud.remove_slot(i)
	var new_info := Game.weapon_info(Game.make_weapon_entry(r.id, 0, Game.weapon_twist(r.id, r.tier)))
	var player = get_tree().get_first_node_in_group("player")
	if hud.equip_item(new_info):
		player.equip_item(new_info)
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
