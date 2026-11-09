extends CanvasLayer
class_name CodexUi
## Weapon codex: every weapon in the game with its tier, element, moves and cooldown
## numbers, how to get it (chest pool, sector drop or fusion recipe), and what awakening
## adds. Weapons you have not met yet show as ???.

const UiKit = preload("res://ui/cards/ui_kit.gd")
const TierCard = preload("res://ui/cards/tier_card.gd")
signal closed

var root_ctl: Control
var grid_area: Control
var detail: RichTextLabel
var selected := "spear"
var viewed_tier := -1             # the tier whose stats are shown (-1 = the weapon's own first tier)
var tier_row: HBoxContainer
var action_row: HBoxContainer
var shards_label: Label
var _info: ItemInfo

const ELEMENT_NOTE := {
	"": "Physical. No special strengths.",
	"pierce": "Piercing: ignores armor and shields. Best against armored enemies.",
	"crush": "Crushing: breaks armor (armor counts half).",
	"fire": "Fire: burns frost imps, bog lurkers and the Frost Wyrm and Bog Mother. Fire-proof enemies shrug it off.",
	"ice": "Ice: freezes ember imps and the Sand Colossus and Magma Titan. Frost enemies resist it.",
	"poison": "Poison: strong against most things, but bog creatures are immune.",
	"earth": "Earth: shatters crystal guards and the Crystal Warden. Golems resist it.",
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 22
	_info = load("res://world/item_info.tres")
	var sc := UiKit.screen(self, "Weapon Codex", func():
		root_ctl.visible = false
		closed.emit(), "Click a weapon. Grey = locked.")
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
	grid_area = Control.new()                       # the cards are placed to exactly fill this area
	grid_area.clip_contents = true
	left.add_child(grid_area)
	var side := UiKit.panel(Color(0.08, 0.08, 0.14))
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
	detail.add_theme_font_size_override("normal_font_size", 14)
	detail.add_theme_font_size_override("bold_font_size", 17)
	sv.add_child(detail)
	action_row = HBoxContainer.new()
	sv.add_child(action_row)

func open() -> void:
	root_ctl.visible = true
	await get_tree().process_frame
	_refresh()

func _weapon_ids() -> Array:
	var out := []
	for id in _info.items:
		if _info.items[id].type == "item" and !(id in ["sword", "pickaxe"]):
			out.append(id)
	out.sort_custom(func(a, b): return Fusion.tier_of(a) < Fusion.tier_of(b) or (Fusion.tier_of(a) == Fusion.tier_of(b) and a < b))
	return out

## Known = in the chest pool, a sector weapon, or a recipe you have discovered.
func _known(id: String) -> bool:
	if Fusion.tier_of(id) == 1:
		return Game.weapon_unlocked(id) or Game.is_seen(id)      # a weapon is a "?" until you have been offered or held it
	return Game.weapon_known(id)       # a recipe is shown only once you have unlocked both ingredients

func _refresh() -> void:
	shards_label.text = "Shards: %d" % Game.meta.shards
	for c in grid_area.get_children():
		grid_area.remove_child(c)
		c.queue_free()
	var ids := _weapon_ids()
	var area := grid_area.size if grid_area.size.x > 100 else get_viewport().get_visible_rect().size - Vector2(480, 200)
	var fit := UiKit.fit_cards(ids.size(), area, 0.72, 8.0, 130.0)
	var cols: int = fit.cols
	var csize: Vector2 = fit.size
	var off_x := maxf(0.0, (area.x - (cols * (csize.x + 8.0) - 8.0)) / 2.0)
	for n in ids.size():
		var id: String = ids[n]
		var known := _known(id)
		var locked: bool = known and (Game.WEAPON_UNLOCK_COSTS.has(id) or id in Game.LEGENDARY_WEAPONS) and !Game.weapon_unlocked(id)
		var card := TierCard.new()
		var lines := []
		if known:
			var inst = load(_info.items[id].path).instantiate()
			if inst.attack_name != "":
				lines.append(str(inst.attack_name).split(" (")[0])
			inst.free()
		card.setup({"size": csize, "title": Fusion.display_name(id) if known else "???", "icon": load(_info.items[id].texture) if known else null,
			"glyph": "?" if !known else "", "tier": Fusion.tier_of(id), "max_tier": 6, "lines": lines, "locked": locked,
			"accent": Game.rarity_color(Game.weapon_rarity(id)) if known else Color(0.4, 0.4, 0.5),
			"footer": ("%d shards" % Game.WEAPON_UNLOCK_COSTS[id]) if locked and Game.WEAPON_UNLOCK_COSTS.has(id) else ""})
		card.position = Vector2(off_x + (n % cols) * (csize.x + 8.0), (n / cols) * (csize.y + 8.0))
		card.set_selected(id == selected)
		card.pressed.connect(func(_c):
			selected = id
			viewed_tier = -1
			_refresh())
		grid_area.add_child(card)
	_show_detail(selected)

func _where(id: String) -> String:
	if id in Game.LEGENDARY_WEAPONS:
		return ("Unlocked. " if Game.weapon_unlocked(id) else "LOCKED. LEGENDARY: beat the whole game to earn it, then unlock it with %d Shards. " % Game.LEGENDARY_PRICE) + "Hits 50% harder than a normal weapon."
	var parts := Fusion.parts_of(id)
	if parts.size() == 2:
		var need := ""
		if !Game.fusion_tier_unlocked(Fusion.tier_of(id)):
			need = " Needs Tier %d fusions (%d Shards, in the shop)." % [Fusion.tier_of(id), Game.FUSION_TIER_COSTS.get(Fusion.tier_of(id), 0)]
		return "Fuse %s + %s at the Forge (%s).%s" % [Fusion.display_name(parts[0]), Fusion.display_name(parts[1]), _cost_text(Fusion.cost(Fusion.tier_of(id))), need]
	for sec in Game.SECTOR_WEAPONS:
		if Game.SECTOR_WEAPONS[sec] == id:
			var state := "Unlocked. " if Game.weapon_unlocked(id) else "LOCKED. Unlock for %d Shards (here or in a reward draw). " % Game.WEAPON_UNLOCK_COSTS[id]
			return state + "It lies in the %s sector and its boss drops it." % sec.to_upper()
	if id in Game.STARTER_WEAPONS:
		return "Chest weapon (in the pool from the start)."
	if Game.WEAPON_UNLOCK_COSTS.has(id):
		var owned: bool = Game.weapon_unlocked(id)
		var sector: String = ""
		for sec in Game.SECTOR_WEAPONS:
			if Game.SECTOR_WEAPONS[sec] == id: sector = sec
		var where := ("Once unlocked it lies in the %s sector and its boss drops it." % sector.to_upper()) if sector != "" else "Once unlocked it can drop from chests."
		return ("Unlocked. " if owned else "LOCKED. Unlock for %d Shards (here or in a reward draw). " % Game.WEAPON_UNLOCK_COSTS[id]) + where
	return ""

func _cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in cost:
		parts.append("%d %s" % [cost[k], k])
	return ", ".join(parts)

func _tier_unlocked(id: String, t: int) -> bool:
	var owned: bool = Game.weapon_unlocked(id) if Fusion.tier_of(id) == 1 else Game.fusion_tier_unlocked(Fusion.tier_of(id))
	return owned and t <= Game.weapon_tier_cap()

func _show_detail(id: String) -> void:
	for c in action_row.get_children():
		action_row.remove_child(c)
		c.queue_free()
	for c in tier_row.get_children():
		tier_row.remove_child(c)
		c.queue_free()
	if Game.WEAPON_UNLOCK_COSTS.has(id) and !Game.weapon_unlocked(id) and Game.is_seen(id):
		var b := Button.new()
		b.text = "Unlock for %d Shards  (you have %d)" % [Game.WEAPON_UNLOCK_COSTS[id], Game.meta.shards]
		b.disabled = Game.meta.shards < Game.WEAPON_UNLOCK_COSTS[id]
		b.pressed.connect(func():
			if Game.buy_weapon(id):
				_refresh())
		action_row.add_child(b)
	if !_known(id):
		detail.text = "[b]???[/b]\nNot found yet.\n" + ("Get it as a reward at the end of a run." if Fusion.tier_of(id) == 1 else "Fuse the right two weapons at the Forge to discover it.")
		return
	var base := Fusion.tier_of(id)
	if viewed_tier < base or viewed_tier > 6:
		viewed_tier = base
	for t in range(base, 7):
		var ok := _tier_unlocked(id, t)
		var tc := TierCard.new()
		tc.setup({"size": Vector2(62, 76), "title": "T%d" % t, "glyph": "" if !ok else "T%d" % t, "lock": !ok, "locked": !ok,
			"accent": Game.rarity_color(Game.weapon_rarity(id)), "footer": "", "tooltip": "Tier %d%s" % [t, "" if ok else " (locked)"]})
		tc.set_selected(t == viewed_tier)
		tc.pressed.connect(func(_c):
			viewed_tier = t
			_show_detail(id))
		tier_row.add_child(tc)
	var info: Dictionary = _info.items[id]
	var inst = load(info.path).instantiate()
	var t := viewed_tier
	var bonus := t - base
	var fz: float = pow(0.95, base - 1) * pow(0.92, bonus)
	var tier_ok := _tier_unlocked(id, t)
	var txt := "[b]%s[/b]   tier [color=#ffd23a][b]%d[/b][/color]%s\n" % [Fusion.display_name(id), t, "" if tier_ok else "   [color=#ff9a7a](locked)[/color]"]
	txt += "[color=#c9d3f2]%s[/color]\n\n" % _where(id)
	txt += "[b]Element[/b]  %s\n" % (String(inst.element).capitalize() if inst.element != "" else "Physical")
	txt += "Damage  [color=#ffd23a][b]x%.1f[/b][/color]\n\n" % Game.weapon_power(id, bonus)
	var moves := [["Left click", inst.attack_name, inst.attack_cooldown, 1], ["Shift", inst.dash_name, inst.dash_cooldown, 1],
		["Right click", inst.ability_name, inst.ability_cooldown, 2], ["Space", inst.ultimate_name, inst.ultimate_cooldown, 3]]
	for m in moves:
		if m[1] == "":
			continue
		if t >= m[3]:
			txt += "%s: %s  [color=#ffd23a][b]%.2fs[/b][/color]\n" % [m[0], m[1], m[2] * fz]
		else:
			txt += "[color=#7a7f95]%s: %s  (unlocks at tier %d)[/color]\n" % [m[0], m[1], m[3]]
	inst.free()
	var tw: String = Game.weapon_twist(id, t)
	if tw != "" and Game.TWISTS.has(tw):
		txt += "\n[b]Twist[/b]  [color=#ffd23a]%s[/color]: %s\n" % [Game.TWISTS[tw][0], Game.TWISTS[tw][1]]
	txt += "\n[color=#c9d3f2]%s[/color]\n" % Fusion.TIER_TEXT.get(t, "")
	if t > base:
		txt += "To reach it: %s\n" % _cost_text(Fusion.AWAKEN_COSTS[t - 1])
	detail.text = txt
