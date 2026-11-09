extends CanvasLayer
## Drawn Cards: every card, weapon and tier-up you have drawn at the end of a run, across all runs,
## with how many times each came up. Opens from the start menu and the end-of-run screen.

const UiKit = preload("res://ui/cards/ui_kit.gd")
var tab_id := "draws"
const TierCard = preload("res://ui/cards/tier_card.gd")

signal closed

var root_ctl: Control
var grid_area: Control
var stats_label: Label
var empty_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 22
	add_to_group("tab_screen")
	var sc := UiKit.screen(self, "Drawn Cards", func():
		root_ctl.visible = false
		closed.emit(), "Drawn but not used yet. A card leaves once you unlock it or apply its upgrade.", "draws")
	root_ctl = sc.root
	stats_label = sc.right
	var panel := UiKit.panel()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.body.add_child(panel)
	grid_area = Control.new()
	grid_area.clip_contents = true
	grid_area.resized.connect(func():
		if root_ctl != null and root_ctl.visible:
			_refresh.call_deferred())
	panel.add_child(grid_area)
	empty_label = Label.new()
	empty_label.text = "Nothing waiting.\nEverything you drew has been unlocked or upgraded."
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.add_theme_font_size_override("font_size", 20)
	empty_label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.85))
	empty_label.set_anchors_preset(Control.PRESET_CENTER)
	empty_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	empty_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	grid_area.add_child(empty_label)

func open() -> void:
	root_ctl.visible = true
	await get_tree().process_frame
	_refresh()

func _refresh() -> void:
	Game.fix_meta()
	for c in grid_area.get_children():
		if c != empty_label:
			grid_area.remove_child(c)
			c.queue_free()
	var items: Array = Game.waiting_draws()
	var total := 0
	for h in items:
		total += int(h.count)
	stats_label.text = "%d waiting" % total
	empty_label.visible = items.is_empty()
	if items.is_empty():
		return
	items.sort_custom(func(a, b):                  # the way they come up: common first, rare last
		var ra: int = Game.rarity_of(str(a.kind), str(a.id))
		var rb: int = Game.rarity_of(str(b.kind), str(b.id))
		if ra != rb:
			return ra < rb
		if a.kind != b.kind:
			return a.kind == "card"
		if a.id != b.id:
			return str(a.id) < str(b.id)
		return str(a.result) < str(b.result))
	var area := grid_area.size if grid_area.size.x > 100 else get_viewport().get_visible_rect().size - Vector2(60, 200)
	var gem_h := 18.0
	area.y -= gem_h * ceilf(sqrt(items.size() / 1.6))
	var fit := UiKit.fit_cards(items.size(), area, 0.6, 8.0, 132.0)
	var cols: int = fit.cols
	var csize: Vector2 = fit.size
	var cell := Vector2(csize.x, csize.y + gem_h)
	var off_x := maxf(0.0, (area.x - (cols * (cell.x + 8.0) - 8.0)) / 2.0)
	var info: Dictionary = load("res://world/item_info.tres").items
	for n in items.size():
		var h: Dictionary = items[n]
		var id := str(h.id)
		var holder := Control.new()
		holder.custom_minimum_size = cell
		holder.size = cell
		holder.position = Vector2(off_x + (n % cols) * (cell.x + 8.0), (n / cols) * (cell.y + 8.0))
		if h.kind == "card" and Game.CARDS.has(id):
			var view := CardView.new()
			view.setup(id, int(h.tier))
			view.scale = Vector2.ONE * (csize.x / CardView.SIZE.x)
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(view)
		elif info.has(id):
			var wc := TierCard.new()
			wc.setup({"size": csize, "title": Fusion.display_name(id), "icon": _icon_of(str(info[id].texture)), "tier": int(h.tier), "max_tier": 6,
				"accent": Game.rarity_color(Game.weapon_rarity(id)), "footer": "WEAPON"})
			wc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(wc)
		var count := Label.new()
		var tag: String = {"offer": "Unlock", "spare": "Spare", "upgrade": "Upgrade T%d" % int(h.tier)}.get(str(h.result), "")
		count.text = ("%s x%d" % [tag, int(h.count)]) if int(h.count) > 1 else tag
		count.position = Vector2(0, csize.y)
		count.size = Vector2(csize.x, gem_h)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.add_theme_font_size_override("font_size", 14)
		count.add_theme_color_override("font_color", Color(1, 0.88, 0.4))
		holder.add_child(count)
		grid_area.add_child(holder)

## Sword and pickaxe use sprite sheets: show their first frame.
const SHEETS := {"res://items/tools/sword/excalibur_.png": Vector2i(4, 4), "res://items/tools/pickaxe/pickaxe.png": Vector2i(2, 2)}

func _icon_of(path: String) -> Texture2D:
	var tex: Texture2D = load(path)
	if SHEETS.has(path):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(0, 0, tex.get_width() / SHEETS[path].x, tex.get_height() / SHEETS[path].y)
		return at
	return tex
