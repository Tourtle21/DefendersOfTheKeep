extends CanvasLayer
## The forge for a local split-screen player (players 2 to 4). Stand at the anvil and press d-pad up. It shows the
## weapons you hold and the ones stored in the forge, grouped by type. LB / RB move, A picks a weapon (two of them),
## X forges (two different weapons fuse, two copies of the same one combine into the next tier), Y drops the weapon
## under the cursor into the forge or takes it out, B closes. Costs and unlocked tiers are the normal forge's.

const TierCard = preload("res://ui/cards/tier_card.gd")
const SHEETS := {"res://items/tools/sword/excalibur_.png": Vector2i(4, 4), "res://items/tools/pickaxe/pickaxe.png": Vector2i(2, 2)}

var pl: Node
var vp: SubViewport
var is_open := false
var cur := 0
var picks: Array = []
var _prev := {}
var _root: Control
var _row: HBoxContainer
var _info: Label
var _hint: Label
var _key := ""

func setup(player: Node, viewport: SubViewport) -> void:
	pl = player
	vp = viewport
	layer = 8
	custom_viewport = viewport
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.size = Vector2(viewport.size)
	_root.visible = false
	add_child(_root)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.1, 0.94)
	sb.border_color = Color(0.55, 0.45, 0.2)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var t := Label.new()
	t.text = "FORGE"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	v.add_child(t)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 8)
	v.add_child(_row)
	_info = Label.new()
	_info.custom_minimum_size = Vector2(300, 40)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 13)
	v.add_child(_info)
	_hint = Label.new()
	_hint.text = "LB/RB move  A pick  X forge  Y drop in / take out  B close"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	v.add_child(_hint)

func fit(area: Vector2) -> void:
	_root.size = area

func _edge(key: String, down: bool) -> bool:
	var was: bool = _prev.get(key, false)
	_prev[key] = down
	return down and !was

func _near_forge() -> bool:
	return pl.global_position.distance_to(Net.FORGE_POS) <= 50.0

func _slots() -> Array:
	return pl.weapon_slots

func _icon(id: String) -> Texture2D:
	var info: Dictionary = load("res://world/item_info.tres").items.get(id, {})
	if !info.has("texture"):
		return null
	var tex: Texture2D = load(info.texture)
	if SHEETS.has(info.texture):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(0, 0, tex.get_width() / SHEETS[info.texture].x, tex.get_height() / SHEETS[info.texture].y)
		return at
	return tex

func _cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in cost:
		parts.append("%d %s (have %d)" % [cost[k], k, Game.resources.get(k, 0)])
	return ", ".join(parts)

## Everything the forge can use, in display order (grouped by type, common first): held ones and stored ones.
func _items() -> Array:
	var out := []
	for i in _slots().size():
		out.append({"src": "held", "idx": i, "entry": _slots()[i], "id": Game.entry_id(_slots()[i])})
	for j in Game._forge_store.size():
		out.append({"src": "store", "idx": j, "entry": Game._forge_store[j], "id": Game.entry_id(Game._forge_store[j])})
	out.sort_custom(func(a, b):
		var ra: int = Game.weapon_rarity(a.id)
		var rb: int = Game.weapon_rarity(b.id)
		if ra != rb:
			return ra < rb
		if a.id != b.id:
			return Fusion.display_name(a.id) < Fusion.display_name(b.id)
		var ta: int = Game.weapon_tier_of(a.entry)
		var tb: int = Game.weapon_tier_of(b.entry)
		if ta != tb:
			return ta > tb
		return a.src == "held" and b.src != "held")
	return out

## What forging the two picked weapons would do: {"text", "ok", "kind", "result", ...}.
func preview() -> Dictionary:
	var items := _items()
	if picks.size() < 2 or picks[0] >= items.size() or picks[1] >= items.size():
		return {"text": "Pick two weapons.", "ok": false, "kind": "", "result": ""}
	var p: Dictionary = Game.forge_preview(items[picks[0]].entry, items[picks[1]].entry)
	if p.has("cost"):
		p["text"] = "%s\nCost: %s" % [p.text, _cost_text(p.cost)]
	return p

## Drop the weapon under the cursor into the forge, or take it out (when a hand slot is free).
func _toggle_store() -> void:
	var items := _items()
	if cur >= items.size():
		return
	var it: Dictionary = items[cur]
	if it.src == "held":
		if Game._forge_store.size() >= Game.FORGE_STORE_MAX:
			return
		_remove_held([it.idx])
		Game._forge_store.append(it.entry)
	elif _slots().size() < 3:
		Game._forge_store.remove_at(it.idx)
		Net.give_weapon(pl, it.entry)
	picks.clear()
	cur = clampi(cur, 0, maxi(0, _items().size() - 1))

## Take held weapons out of the hands by slot index and keep a sensible weapon equipped.
func _remove_held(indexes: Array) -> void:
	var idx := indexes.duplicate()
	idx.sort()
	idx.reverse()
	for i in idx:
		_slots().remove_at(i)
	if _slots().is_empty():
		pl.clear_item()
	else:
		pl.active_slot = clampi(int(pl.active_slot), 0, _slots().size() - 1)
		pl.equip_item(Game.weapon_info(_slots()[pl.active_slot]))

func _forge_picked() -> void:
	var items := _items()
	var p := preview()
	if !p.ok:
		return
	var a: Dictionary = items[picks[0]]
	var b: Dictionary = items[picks[1]]
	Game.pay(p.cost)
	if p.kind == "fuse":
		Game.note_recipe(p.key)
	var held := []
	var stored := []
	for it in [a, b]:
		if it.src == "held":
			held.append(it.idx)
		else:
			stored.append(it.idx)
	stored.sort()
	stored.reverse()
	for j in stored:
		Game._forge_store.remove_at(j)
	if !held.is_empty():
		_remove_held(held)
	if _slots().size() < 3:
		Net.give_weapon(pl, p.result)
	elif Game._forge_store.size() < Game.FORGE_STORE_MAX:
		Game._forge_store.append(p.result)
	picks.clear()
	cur = 0

func close() -> void:
	is_open = false
	_root.visible = false
	picks.clear()

## Called every physics frame with this player's controller.
func poll(dev: int) -> void:
	var up := _edge("up", Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP))
	var lb := _edge("lb", Input.is_joy_button_pressed(dev, JOY_BUTTON_LEFT_SHOULDER) or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT))
	var rb := _edge("rb", Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_SHOULDER) or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT))
	var a := _edge("a", Input.is_joy_button_pressed(dev, JOY_BUTTON_A))
	var b := _edge("b", Input.is_joy_button_pressed(dev, JOY_BUTTON_B))
	var x := _edge("x", Input.is_joy_button_pressed(dev, JOY_BUTTON_X))
	var y := _edge("y", Input.is_joy_button_pressed(dev, JOY_BUTTON_Y))
	if !is_open:
		if up and _near_forge() and !pl.is_in_tower and !pl.downed:
			is_open = true
			cur = 0
			picks.clear()
			_root.visible = true
			_prev["a"] = true            # the press that is held now must not also pick a weapon
			_refresh()
		return
	if !_near_forge() or pl.downed or pl.is_in_tower:
		close()
		return
	var n := _items().size()
	if n > 0:
		if lb: cur = wrapi(cur - 1, 0, n)
		if rb: cur = wrapi(cur + 1, 0, n)
	if a and n > 0:
		if cur in picks:
			picks.erase(cur)
		elif picks.size() < 2:
			picks.append(cur)
	if y:
		_toggle_store()
	if x and picks.size() == 2:
		_forge_picked()
	if b:
		close()
		return
	_refresh()

func _refresh() -> void:
	var items := _items()
	var key := str(items.map(func(it): return it.entry)) + str(cur) + str(picks) + str(Game.resources)
	if key == _key:
		return
	_key = key
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	var last_id := ""
	var group: HBoxContainer = null
	for n in items.size():
		var it: Dictionary = items[n]
		if it.id != last_id:
			last_id = it.id
			var box := VBoxContainer.new()
			var count := 0
			for o in items:
				if o.id == it.id:
					count += 1
			var head := Label.new()
			head.text = "%s  x%d" % [Fusion.display_name(it.id), count]
			head.add_theme_font_size_override("font_size", 12)
			head.add_theme_color_override("font_color", Game.rarity_color(Game.weapon_rarity(it.id)))
			box.add_child(head)
			group = HBoxContainer.new()
			group.add_theme_constant_override("separation", 4)
			box.add_child(group)
			_row.add_child(box)
		var card := TierCard.new()
		card.setup({"size": Vector2(78, 108), "title": "T%d" % Game.weapon_tier_of(it.entry), "icon": _icon(it.id), "tier": Game.weapon_tier_of(it.entry), "max_tier": 6,
			"accent": Game.rarity_color(Game.weapon_rarity(it.id)), "footer": "PICKED" if n in picks else ("HELD" if it.src == "held" else "STORED"),
			"footer_color": Color(0.5, 1, 0.55) if it.src == "held" else Color(0.6, 0.8, 1.0)})
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.focus_mode = Control.FOCUS_NONE
		card.set_selected(n == cur)
		group.add_child(card)
	if items.is_empty():
		var l := Label.new()
		l.text = "No weapons held or stored."
		_row.add_child(l)
	var p := preview()
	_info.text = p.text
	_info.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6) if p.ok else Color(1, 0.8, 0.5))
