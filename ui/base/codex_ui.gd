extends CanvasLayer
class_name CodexUi
## Weapon codex: every weapon in the game with its tier, element, moves and cooldown
## numbers, how to get it (chest pool, sector drop or fusion recipe), and what awakening
## adds. Weapons you have not met yet show as ???.

signal closed

var root_ctl: Control
var grid: GridContainer
var detail: RichTextLabel
var selected := "spear"
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
	root_ctl = Control.new()
	root_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctl.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ctl.visible = false
	add_child(root_ctl)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.08, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctl.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	root_ctl.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)
	var top := HBoxContainer.new()
	outer.add_child(top)
	var title := Label.new()
	title.text = "Weapon Codex"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close := Button.new()
	close.text = "Back"
	close.custom_minimum_size = Vector2(110, 36)
	close.pressed.connect(func():
		root_ctl.visible = false
		closed.emit())
	top.add_child(close)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	outer.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	body.add_child(side)
	detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.custom_minimum_size = Vector2(430, 0)
	detail.fit_content = true
	detail.add_theme_font_size_override("normal_font_size", 15)
	detail.add_theme_font_size_override("bold_font_size", 18)
	side.add_child(detail)
	action_row = HBoxContainer.new()
	side.add_child(action_row)

func open() -> void:
	root_ctl.visible = true
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
		return true                    # basic weapons are always listed (locked ones can be unlocked here)
	return Game.weapon_known(id)       # a recipe is shown only once you have unlocked both ingredients

func _refresh() -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	for id in _weapon_ids():
		var known := _known(id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(120, 78)
		b.text = "%s\nT%d" % [Fusion.display_name(id) if known else "???", Fusion.tier_of(id)]
		if known:
			b.icon = load(_info.items[id].texture)
			b.expand_icon = false
			b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		if known and (Game.WEAPON_UNLOCK_COSTS.has(id) or id in Game.LEGENDARY_WEAPONS) and !Game.weapon_unlocked(id):
			b.modulate = Color(0.5, 0.5, 0.58)          # locked
			b.text += "  (locked)"
		if id == selected:
			b.modulate = Color(1.2, 1.2, 0.7)
		b.pressed.connect(func():
			selected = id
			_refresh())
		grid.add_child(b)
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

func _show_detail(id: String) -> void:
	for c in action_row.get_children():
		action_row.remove_child(c)
		c.queue_free()
	if Game.WEAPON_UNLOCK_COSTS.has(id) and !Game.weapon_unlocked(id):
		var b := Button.new()
		b.text = "Unlock %s (%d Shards, you have %d)" % [Fusion.display_name(id), Game.WEAPON_UNLOCK_COSTS[id], Game.meta.shards]
		b.disabled = Game.meta.shards < Game.WEAPON_UNLOCK_COSTS[id]
		b.pressed.connect(func():
			if Game.buy_weapon(id):
				_refresh())
		action_row.add_child(b)
	if !_known(id):
		detail.text = "[b]???[/b]\nFuse the right two weapons at the Forge to discover this recipe."
		return
	var info: Dictionary = _info.items[id]
	var inst = load(info.path).instantiate()
	var t := "[b]%s[/b]   tier [color=#ffd23a][b]%d[/b][/color] of 6\n" % [Fusion.display_name(id), Fusion.tier_of(id)]
	t += "[color=#c9d3f2]%s[/color]\n\n" % _where(id)
	t += "[b]Element[/b]  %s\n[color=#c9d3f2]%s[/color]\n\n" % [String(inst.element).capitalize() if inst.element != "" else "Physical", ELEMENT_NOTE.get(inst.element, "")]
	var moves := [["Left click", inst.attack_name, inst.attack_cooldown, 1], ["Shift", inst.dash_name, inst.dash_cooldown, 1],
		["Right click", inst.ability_name, inst.ability_cooldown, 2], ["Space", inst.ultimate_name, inst.ultimate_cooldown, 3]]
	for m in moves:
		if m[1] == "":
			continue
		var gate := "" if Fusion.tier_of(id) >= m[3] else "  [color=#ff9a7a](needs tier %d)[/color]" % m[3]
		t += "%s: %s  [color=#ffd23a][b]%.2fs[/b][/color] cooldown%s\n" % [m[0], m[1], m[2], gate]
	inst.free()
	t += "\n[b]Awakening[/b] (Forge): each level +20% damage, -8% cooldowns, up to tier 6.\n"
	var tier := Fusion.tier_of(id)
	while tier < 6:
		t += "T%d -> T%d: %s\n" % [tier, tier + 1, _cost_text(Fusion.AWAKEN_COSTS[tier])]
		tier += 1
	detail.text = t
