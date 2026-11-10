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
		p["text"] = "%s\nCost: %s" % [p.text, cost_text(p.cost)]
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

## Real numbers for the weapon now and one tier up (green). Each tier of bonus gives +20% damage and -8% cooldowns.
## Shared by player 1's forge and every other forge screen.
static func numbers_text(info: Dictionary, bonus: int) -> String:
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

## One recipe card in player 1's look: two ingredients, an arrow, the result.
static func _chip(id: String, tier_text: String, icon_px: float, font: int) -> Control:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var tr := TextureRect.new()
	tr.texture = icon(id)
	tr.custom_minimum_size = Vector2(icon_px, icon_px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tr)
	var l := Label.new()
	l.text = "%s\n%s" % [Fusion.display_name(id), tier_text]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	return v

static func _recipe_card(a: Array, b: Array, c: Array, state: int, size: Vector2, icon_px: float, font: int) -> Button:
	var rb := Button.new()
	rb.custom_minimum_size = size
	rb.focus_mode = Control.FOCUS_NONE
	rb.modulate = [Color(0.65, 0.65, 0.65), Color(1, 1, 0.5), Color(0.5, 1.0, 0.5)][state]       # grey: missing, yellow: need more, green: ready
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_chip(a[0], a[1], icon_px, font))
	var plus := Label.new()
	plus.text = "+"
	h.add_child(plus)
	h.add_child(_chip(b[0], b[1], icon_px, font))
	var arrow := Label.new()
	arrow.text = "->"
	h.add_child(arrow)
	h.add_child(_chip(c[0], c[1], icon_px, font))
	rb.add_child(h)
	return rb

## The recipes you know, over the weapons in `list` (held and stored): matching pairs that combine into the next tier first,
## then every fusion. Green = ready to forge, yellow = need more, grey = missing a weapon. `on_pick(a_pos, b_pos)` makes a card clickable.
static func recipes(parent: Container, list: Array, card_size := Vector2(330, 100), icon_px := 48.0, font := 12, on_pick := Callable()) -> void:
	for c in parent.get_children():
		parent.remove_child(c)
		c.queue_free()
	var tier_of_id := func(id: String) -> int:
		var best := 0
		for it in list:
			if it.id == id:
				best = maxi(best, Game.weapon_tier_of(it.entry))
		return best
	var seen := {}
	for n in list.size():
		var it: Dictionary = list[n]
		var k := "%s:%d" % [it.id, Game.weapon_bonus(it.entry)]
		if seen.has(k):
			continue
		seen[k] = true
		var j := -1
		for m in list.size():
			if m != n and list[m].id == it.id and Game.weapon_bonus(list[m].entry) == Game.weapon_bonus(it.entry):
				j = m
				break
		var t := Game.weapon_tier_of(it.entry)
		var res := Game.combine_weapons(it.entry, it.entry)
		var ok: bool = j >= 0 and res != "" and Game.can_afford(Game.combine_cost(it.entry))
		var by_draw: bool = res == "" and Game.combine_locked_by_draw(it.entry)
		var card := _recipe_card([it.id, "Tier %d" % t], [it.id, "Tier %d%s" % [t, "" if j >= 0 else " (need a 2nd)"]],
			[it.id, ("Tier %d" % (t + 1)) if res != "" else ("Tier %d locked" % (t + 1) if by_draw else "max for now")], 2 if ok else (1 if j >= 0 else 0), card_size, icon_px, font)
		if j >= 0 and on_pick.is_valid():
			var a_pos := n
			var b_pos := j
			card.pressed.connect(func(): on_pick.call(a_pos, b_pos))
		elif j < 0:
			card.disabled = true
		parent.add_child(card)
	for key in Fusion.RECIPES:
		var r: Dictionary = Fusion.RECIPES[key]
		if !Game.weapon_known(r.id):
			continue
		var pr: PackedStringArray = key.split("+")
		var a := -1
		var b := -1
		for n in list.size():
			if a < 0 and list[n].id == pr[0]:
				a = n
		for n in list.size():
			if b < 0 and n != a and list[n].id == pr[1]:
				b = n
		var carry: bool = a >= 0 and b >= 0
		var ok2: bool = carry and Game.fusion_tier_unlocked(r.tier) and Game.can_afford(Fusion.cost(r.tier))
		var ta: int = tier_of_id.call(pr[0])
		var tb: int = tier_of_id.call(pr[1])
		var card2 := _recipe_card([pr[0], ("T%d carried" % ta) if ta > 0 else "not carried"], [pr[1], ("T%d carried" % tb) if tb > 0 else "not carried"],
			[r.id, "Tier %d%s" % [r.tier, "" if Game.fusion_tier_unlocked(r.tier) else " (locked)"]], 2 if ok2 else (1 if carry else 0), card_size, icon_px, font)
		if carry and on_pick.is_valid():
			var a2 := a
			var b2 := b
			card2.pressed.connect(func(): on_pick.call(a2, b2))
		elif !carry:
			card2.disabled = true
		parent.add_child(card2)
