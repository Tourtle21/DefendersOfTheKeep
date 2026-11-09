extends RefCounted
## The forge's weapon list, shared by every screen that shows it (the split-screen player's forge and the LAN client's):
## the weapons you hold and the ones stored in the forge, grouped by type, common first. Keeping this in one place is
## what makes both screens look and behave the same.

const TierCard = preload("res://ui/cards/tier_card.gd")
const SHEETS := {"res://items/tools/sword/excalibur_.png": Vector2i(4, 4), "res://items/tools/pickaxe/pickaxe.png": Vector2i(2, 2)}

## held / stored are arrays of weapon entries. Returns [{src: "held"|"store", idx, entry, id}] in display order.
static func items(held: Array, stored: Array) -> Array:
	var out := []
	for i in held.size():
		out.append({"src": "held", "idx": i, "entry": held[i], "id": Game.entry_id(held[i])})
	for j in stored.size():
		out.append({"src": "store", "idx": j, "entry": stored[j], "id": Game.entry_id(stored[j])})
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

static func icon(id: String) -> Texture2D:
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

static func cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in cost:
		parts.append("%d %s (have %d)" % [cost[k], k, Game.resources.get(k, 0)])
	return ", ".join(parts)

## "text" for the picked pair, with the cost.
static func preview(list: Array, picks: Array) -> Dictionary:
	if picks.size() < 2 or picks[0] >= list.size() or picks[1] >= list.size():
		return {"text": "Pick two weapons.", "ok": false, "kind": "", "result": ""}
	var p: Dictionary = Game.forge_preview(list[picks[0]].entry, list[picks[1]].entry)
	if p.has("cost"):
		p["text"] = "%s\\nCost: %s" % [p.text, cost_text(p.cost)]
	return p

## Fill `parent` with one box per weapon type, each with a card per copy. `on_click` (optional) is called with the
## card's position in `list` when a card is clicked with the mouse.
static func build(parent: Container, list: Array, picks: Array, cur: int, card_size: Vector2, on_click := Callable()) -> void:
	for c in parent.get_children():
		parent.remove_child(c)
		c.queue_free()
	var last_id := ""
	var group: HBoxContainer = null
	for n in list.size():
		var it: Dictionary = list[n]
		if it.id != last_id:
			last_id = it.id
			var box := VBoxContainer.new()
			var count := 0
			for o in list:
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
			parent.add_child(box)
		var card = TierCard.new()
		card.setup({"size": card_size, "title": "T%d" % Game.weapon_tier_of(it.entry), "icon": icon(it.id), "tier": Game.weapon_tier_of(it.entry), "max_tier": 6,
			"accent": Game.rarity_color(Game.weapon_rarity(it.id)), "footer": "PICKED" if n in picks else ("HELD" if it.src == "held" else "STORED"),
			"footer_color": Color(0.5, 1, 0.55) if it.src == "held" else Color(0.6, 0.8, 1.0)})
		card.focus_mode = Control.FOCUS_NONE
		card.set_selected(n == cur or n in picks)
		if on_click.is_valid():
			var pos := n
			card.pressed.connect(func(_c): on_click.call(pos))
		else:
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(card)
