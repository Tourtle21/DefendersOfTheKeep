extends RefCounted
## The forge's weapon list, shared by every screen that shows it (the split-screen player's forge and the LAN client's):
## the weapons you hold and the ones stored in the forge, grouped by type, common first. Keeping this in one place is
## what makes both screens look and behave the same.

const TierCard = preload("res://ui/cards/tier_card.gd")
const UiKit = preload("res://ui/cards/ui_kit.gd")
const SHEETS := {"res://items/tools/sword/excalibur_.png": Vector2i(4, 4), "res://items/tools/pickaxe/pickaxe.png": Vector2i(2, 2)}

## held / stored are arrays of weapon entries. Returns [{src: "held"|"store", idx, entry, id}] in display order.
static func items(held: Array, stored: Array) -> Array:
	var out := []
	for i in held.size():
		out.append({"src": "held", "idx": i, "entry": held[i], "id": Game.entry_id(held[i])})
	for j in stored.size():
		out.append({"src": "store", "idx": j, "entry": stored[j], "id": Game.entry_id(stored[j])})
	out.sort_custom(func(a, b):
		if a.src != b.src:
			return a.src == "held"                      # your hands first, then the forge's storage
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
		return false)
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

## Fill `parent` with two areas side by side: "IN YOUR HANDS" and "IN THE FORGE", each with one box per weapon type and a
## card per copy. `on_click` (optional) is called with the card's position in `list` when a card is clicked with the mouse.
static func build(parent: Container, list: Array, picks: Array, cur: int, card_size: Vector2, on_click := Callable()) -> void:
	for c in parent.get_children():
		parent.remove_child(c)
		c.queue_free()
	var held_n := 0
	for o in list:
		if o.src == "held":
			held_n += 1
	for src in ["held", "store"]:
		var area := PanelContainer.new()
		var held: bool = src == "held"
		area.add_theme_stylebox_override("panel", UiKit.style(Color(0.07, 0.12, 0.09) if held else Color(0.07, 0.09, 0.15),
			Color(0.35, 0.7, 0.4) if held else Color(0.4, 0.55, 0.85), 6.0))
		var av := VBoxContainer.new()
		av.add_theme_constant_override("separation", 3)
		area.add_child(av)
		var title := Label.new()
		title.text = ("IN YOUR HANDS  %d / 3" % held_n) if held else "IN THE FORGE  %d / %d" % [list.size() - held_n, Game.FORGE_STORE_MAX]
		title.add_theme_font_size_override("font_size", 12)
		title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6) if held else Color(0.65, 0.8, 1.0))
		av.add_child(title)
		var groups := HBoxContainer.new()
		groups.add_theme_constant_override("separation", 8)
		av.add_child(groups)
		var count := 0
		var last_id := ""
		var group: HBoxContainer = null
		for n in list.size():
			var it: Dictionary = list[n]
			if it.src != src:
				continue
			count += 1
			if it.id != last_id:
				last_id = it.id
				var box := VBoxContainer.new()
				var copies := 0
				for o in list:
					if o.id == it.id and o.src == src:
						copies += 1
				var head := Label.new()
				head.text = "%s  x%d" % [Fusion.display_name(it.id), copies]
				head.add_theme_font_size_override("font_size", 12)
				head.add_theme_color_override("font_color", Game.rarity_color(Game.weapon_rarity(it.id)))
				box.add_child(head)
				group = HBoxContainer.new()
				group.add_theme_constant_override("separation", 4)
				box.add_child(group)
				groups.add_child(box)
			var card = TierCard.new()
			card.setup({"size": card_size, "title": "T%d" % Game.weapon_tier_of(it.entry), "icon": icon(it.id), "tier": Game.weapon_tier_of(it.entry), "max_tier": 6,
				"accent": Game.rarity_color(Game.weapon_rarity(it.id)), "footer": "PICKED" if n in picks else ("HELD" if held else "STORED"),
				"footer_color": Color(0.5, 1, 0.55) if held else Color(0.6, 0.8, 1.0)})
			card.focus_mode = Control.FOCUS_NONE
			card.set_selected(n == cur or n in picks)
			if on_click.is_valid():
				var pos := n
				card.pressed.connect(func(_c): on_click.call(pos))
			else:
				card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			group.add_child(card)
		if count == 0:
			var none := Label.new()
			none.text = "Nothing in your hands" if held else "Nothing stored"
			none.add_theme_font_size_override("font_size", 11)
			none.add_theme_color_override("font_color", Color(0.6, 0.62, 0.7))
			groups.add_child(none)
		parent.add_child(area)
