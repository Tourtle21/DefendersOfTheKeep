extends CanvasLayer
## The forge for a local split-screen player (players 2 to 4). Stand at the anvil and press d-pad up: LB / RB move,
## A picks a weapon (two of them), X forges (two different weapons fuse, two copies of the same one combine into the
## next tier), B closes. The costs and the unlocked tiers are exactly the ones the normal forge screen uses.

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
	_hint.text = "LB/RB move   A pick   X forge   B close"
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

## What forging the two picked weapons would do: {"text", "ok", "kind": "fuse" | "combine"}.
func preview() -> Dictionary:
	var slots := _slots()
	if picks.size() < 2:
		return {"text": "Pick two weapons.", "ok": false, "kind": ""}
	var ea: String = slots[picks[0]]
	var eb: String = slots[picks[1]]
	var ida := Game.entry_id(ea)
	var idb := Game.entry_id(eb)
	if ida == idb:
		var res := Game.combine_weapons(ea, eb)
		if res == "":
			if Game.combine_locked_by_draw(ea):
				return {"text": "Tier %d is locked. Draw it at the end of a run." % (Game.weapon_tier_of(ea) + 1), "ok": false, "kind": "combine"}
			return {"text": "These cannot combine.", "ok": false, "kind": "combine"}
		var cost: Dictionary = Game.combine_cost(ea)
		return {"text": "%s: tier %d -> %d\\nCost: %s" % [Fusion.display_name(ida), Game.weapon_tier_of(ea), Game.weapon_tier_of(ea) + 1, _cost_text(cost)], "ok": Game.can_afford(cost), "kind": "combine"}
	var r := Fusion.recipe(ida, idb)
	if r.is_empty():
		return {"text": "These two do not fuse.", "ok": false, "kind": "fuse"}
	if !Game.fusion_tier_unlocked(r.tier):
		return {"text": "%s: locked (buy Tier %d fusions)." % [Fusion.display_name(r.id), r.tier], "ok": false, "kind": "fuse"}
	var fcost: Dictionary = Fusion.cost(r.tier)
	return {"text": "%s (Tier %d)\\nCost: %s" % [Fusion.display_name(r.id), r.tier, _cost_text(fcost)], "ok": Game.can_afford(fcost), "kind": "fuse"}

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
	var n := _slots().size()
	if n > 0:
		if lb: cur = wrapi(cur - 1, 0, n)
		if rb: cur = wrapi(cur + 1, 0, n)
	if a and n > 0:
		if cur in picks:
			picks.erase(cur)
		elif picks.size() < 2:
			picks.append(cur)
	if x and picks.size() == 2:
		var p := preview()
		if p.ok:
			if p.kind == "combine":
				Net._combine(pl, picks[0], picks[1])
			else:
				Net._fuse(pl, picks[0], picks[1])
			picks.clear()
			cur = 0
	if b:
		close()
		return
	_refresh()

func _refresh() -> void:
	var slots := _slots()
	var key := str(slots) + str(cur) + str(picks) + str(Game.resources)
	if key == _key:
		return
	_key = key
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	for i in slots.size():
		var id := Game.entry_id(slots[i])
		var card := TierCard.new()
		card.setup({"size": Vector2(96, 134), "title": Fusion.display_name(id), "icon": _icon(id), "tier": Game.weapon_tier_of(slots[i]), "max_tier": 6,
			"accent": Game.rarity_color(Game.weapon_rarity(id)), "footer": "PICKED" if i in picks else ""})
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.focus_mode = Control.FOCUS_NONE
		card.set_selected(i == cur)
		_row.add_child(card)
	if slots.is_empty():
		var l := Label.new()
		l.text = "You carry no weapons."
		_row.add_child(l)
	var p := preview()
	_info.text = p.text
	_info.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6) if p.ok else Color(1, 0.8, 0.5))
