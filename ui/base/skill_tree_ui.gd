extends CanvasLayer
class_name SkillTreeUi
## The permanent skill tree: five branches of skills bought with Shards. Lines connect a
## skill to what it needs. Hover a skill to read what it does (this level and the next,
## highlighted), click to buy a level.

const NODE := Vector2(138, 70)
const COL_W := 150.0
const ROW_H := 112.0
const BRANCH_W := 330.0
const TOP := 44.0

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
		margin.add_theme_constant_override("margin_" + side, 20)
	root_ctl.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)
	var top := HBoxContainer.new()
	outer.add_child(top)
	var title := Label.new()
	title.text = "Skill Tree"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	shards_label = Label.new()
	shards_label.add_theme_font_size_override("font_size", 20)
	shards_label.add_theme_color_override("font_color", Color("8fd8ff"))
	top.add_child(shards_label)
	var close := Button.new()
	close.text = "Back"
	close.custom_minimum_size = Vector2(110, 36)
	close.pressed.connect(func():
		root_ctl.visible = false
		closed.emit())
	top.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	tree = Control.new()
	tree.custom_minimum_size = Vector2(Skills.BRANCHES.size() * BRANCH_W, TOP + 4 * ROW_H + 10)
	tree.draw.connect(_draw_tree)
	scroll.add_child(tree)
	detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.custom_minimum_size = Vector2(0, 96)
	detail.add_theme_font_size_override("normal_font_size", 16)
	detail.add_theme_font_size_override("bold_font_size", 18)
	outer.add_child(detail)

func open() -> void:
	root_ctl.visible = true
	_refresh()

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
		var b: Button = _buttons.get(id)
		if b == null:
			b = Button.new()
			b.size = NODE
			b.position = _node_pos(id)
			b.clip_text = true
			b.mouse_entered.connect(func():
				_hover = id
				_show_detail(id))
			b.pressed.connect(func():
				if Game.buy_skill(id):
					Sfx.play("unlock", 0.0)
					_refresh())
			tree.add_child(b)
			_buttons[id] = b
		var lvl := Game.skill_level(id)
		var avail := Game.skill_available(id)
		var col: Color = Skills.BRANCHES[sk.branch].color
		b.text = "%s\n%d / %d" % [sk.name, lvl, sk.max]
		if lvl >= sk.max:
			b.text += "  MAX"
			b.modulate = Color(1.2, 1.1, 0.7)
		elif !avail:
			b.modulate = Color(0.45, 0.45, 0.5)
		elif Game.meta.shards >= Game.skill_cost(id):
			b.modulate = col.lightened(0.5)
		else:
			b.modulate = Color(0.8, 0.8, 0.85)
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
