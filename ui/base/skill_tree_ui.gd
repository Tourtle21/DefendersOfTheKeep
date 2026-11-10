extends CanvasLayer
class_name SkillTreeUi
## The permanent skill tree: five branches of skills bought with Shards. Lines connect a
## skill to what it needs. Hover a skill to read what it does (this level and the next,
## highlighted), click to buy a level.

const UiKit = preload("res://ui/cards/ui_kit.gd")
var tab_id := "skills"
const TierCard = preload("res://ui/cards/tier_card.gd")
const TOP := 40.0
var NODE := Vector2(138, 70)       # recomputed to fit the screen
var COL_W := 150.0
var ROW_H := 112.0
var BRANCH_W := 330.0

signal closed

var root_ctl: Control
var tree: Control
var detail: RichTextLabel
var shards_label: Label
var _buttons := {}
var _hover := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 22
	add_to_group("tab_screen")
	var sc := UiKit.screen(self, "Skill Tree", func():
		root_ctl.visible = false
		closed.emit(), "Click a card to buy a level. Gold frame = you can afford it.", "skills")
	root_ctl = sc.root
	shards_label = sc.right
	var area := UiKit.panel(UiKit.PANEL, UiKit.BORDER, 8.0)
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.body.add_child(area)
	tree = Control.new()
	tree.clip_contents = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.draw.connect(_draw_tree)
	tree.resized.connect(func():                     # the window can change size after the tree was laid out
		if root_ctl != null and root_ctl.visible:
			_layout()
			_refresh())
	area.add_child(tree)
	var dp := UiKit.panel(UiKit.RESULT_BG, UiKit.BORDER, 8.0)
	sc.body.add_child(dp)
	detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.custom_minimum_size = Vector2(0, 76)
	detail.add_theme_font_size_override("normal_font_size", UiKit.FONT_BODY)
	detail.add_theme_font_size_override("bold_font_size", UiKit.FONT_HEAD)
	dp.add_child(detail)

func open() -> void:
	root_ctl.visible = true
	await get_tree().process_frame
	_layout()
	_refresh()

## Fit the five branches to the window: no scrolling.
func _layout() -> void:
	var a: Vector2 = tree.size if tree.size.y > 100 else get_viewport().get_visible_rect().size - Vector2(48, 260)
	BRANCH_W = a.x / Skills.BRANCHES.size()
	COL_W = (BRANCH_W - 20.0) / 2.0
	NODE = Vector2(COL_W - 8.0, 0)
	ROW_H = (a.y - TOP) / 4.0
	NODE.y = ROW_H - 10.0
	NODE.x = minf(NODE.x, NODE.y * 0.95)

func _node_pos(id: String) -> Vector2:
	var sk: Dictionary = Skills.TREE[id]
	var b: int = Skills.BRANCHES.keys().find(sk.branch)
	return Vector2(b * BRANCH_W + 10.0 + sk.pos[0] * COL_W, TOP + sk.pos[1] * ROW_H)

func _draw_tree() -> void:
	var font := ThemeDB.fallback_font
	var i := 0
	for b in Skills.BRANCHES:
		var col: Color = Skills.BRANCHES[b].color
		tree.draw_string(font, Vector2(i * BRANCH_W + 10, 24), Skills.BRANCHES[b].name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
		tree.draw_line(Vector2(i * BRANCH_W + 10, 32), Vector2(i * BRANCH_W + BRANCH_W - 30, 32), Color(col, 0.5), 2.0)
		i += 1
	for id in Skills.TREE:
		var sk: Dictionary = Skills.TREE[id]
		var col: Color = Skills.BRANCHES[sk.branch].color
		for r in sk.req:
			var a := _node_pos(r) + Vector2(NODE.x / 2.0, NODE.y)
			var c := _node_pos(id) + Vector2(NODE.x / 2.0, 0)
			var live: bool = Game.skill_level(r) >= 1
			tree.draw_line(a, c, Color(col, 0.9 if live else 0.25), 3.0 if live else 2.0)

func _refresh() -> void:
	shards_label.text = "Shards: %d" % Game.meta.shards
	for id in Skills.TREE:
		var sk: Dictionary = Skills.TREE[id]
		var b = _buttons.get(id)
		var lvl := Game.skill_level(id)
		var avail := Game.skill_available(id)
		var col: Color = Skills.BRANCHES[sk.branch].color
		var can: bool = avail and lvl < sk.max and Game.meta.shards >= Game.skill_cost(id)
		var foot := "MAX" if lvl >= sk.max else ("Locked" if !avail else "%d shards" % Game.skill_cost(id))
		var fcol := UiKit.CURSOR if lvl >= sk.max else (UiKit.MUTED if !avail else (UiKit.GOOD if can else UiKit.KEEP_FILL))
		if b == null:
			b = TierCard.new()
			b.mouse_entered.connect(func():
				_hover = id
				_show_detail(id))
			b.pressed.connect(func(_c):
				if Game.buy_skill(id):
					Sfx.play("unlock", 0.0)
					_refresh())
			tree.add_child(b)
			_buttons[id] = b
		var lines := []
		lines.append(Skills.effect_text(id, lvl) if lvl > 0 else "-")
		if lvl < sk.max:
			var nx: String = Skills.effect_text(id, lvl + 1)
			lines.append(nx if nx.begins_with("+") else "+" + nx)
		b.setup({"size": NODE, "title": sk.name, "glyph": "%d/%d" % [lvl, sk.max], "tier": lvl, "max_tier": sk.max, "lines": lines,
			"accent": col if avail else UiKit.MUTED_DARK, "locked": false, "footer": foot, "footer_color": fcol})
		b.modulate = UiKit.WHITE if avail else UiKit.MUTED
		b.position = _node_pos(id)
		b.set_selected(can)
	tree.queue_redraw()
	_show_detail(_hover if _hover != "" else Skills.TREE.keys()[0])

func _show_detail(id: String) -> void:
	var sk: Dictionary = Skills.TREE[id]
	var lvl := Game.skill_level(id)
	var t := "[b]%s[/b]   level %d of %d\n" % [sk.name, lvl, sk.max]
	t += "Now: [color=#ffd23a][b]%s[/b][/color]" % (Skills.effect_text(id, lvl) if lvl > 0 else "nothing yet")
	if lvl < sk.max:
		t += "     Next: [color=#6df08a][b]%s[/b][/color]" % Skills.effect_text(id, lvl + 1)
		if !Game.skill_available(id):
			var need := []
			for r in sk.req:
				if Game.skill_level(r) < 1:
					need.append(Skills.TREE[r].name)
			t += "\n[color=#ff9a7a]Locked: needs %s first.[/color]" % " and ".join(need)
		else:
			t += "\nCost: [b]%d[/b] Shards%s" % [Game.skill_cost(id), "" if Game.meta.shards >= Game.skill_cost(id) else "  [color=#ff9a7a](not enough)[/color]"]
	detail.text = t
