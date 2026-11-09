extends CanvasLayer
class_name MainMenu
## Start screen: your permanent unlocks (cards, weapons, skills, shards) and a Play button that starts the run.
## Shown once per launch; restarting a run goes straight back into the game.

const UiKit = preload("res://ui/cards/ui_kit.gd")
const DrawsUi = preload("res://ui/base/draws_ui.gd")
var root_ctl: Control
var skills: SkillTreeUi
var codex: CodexUi
var collection: CollectionUi
var draws
var stats_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 21      # under the collection, codex and skill screens (layer 22) so they open on top
	get_tree().paused = true
	root_ctl = Control.new()
	root_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctl.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ctl.theme = UiKit.make_theme()
	add_child(root_ctl)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.08, 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctl.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctl.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(420, 0)
	center.add_child(box)
	var title := Label.new()
	title.text = "Defenders of the Keep"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	box.add_child(title)
	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 16)
	box.add_child(stats_label)
	var start_row := HBoxContainer.new()                    # which weapon the next run starts with
	start_row.alignment = BoxContainer.ALIGNMENT_CENTER
	start_row.add_theme_constant_override("separation", 10)
	box.add_child(start_row)
	var start_label := Label.new()
	start_label.text = "Start with:"
	start_row.add_child(start_label)
	var start_opt := OptionButton.new()
	var options: Array = Game.start_weapon_options()
	for o in options:
		start_opt.add_item(Fusion.display_name(String(o)))
	start_opt.selected = maxi(0, options.find(Game.meta.start_weapon))
	start_opt.item_selected.connect(func(i: int): Game.set_start_weapon(options[i]))
	start_row.add_child(start_opt)
	var play := Button.new()
	play.text = "Play game"
	play.custom_minimum_size = Vector2(0, 56)
	play.add_theme_font_size_override("font_size", 24)
	play.pressed.connect(_play)
	box.add_child(play)
	collection = CollectionUi.new()
	add_child(collection)
	collection.closed.connect(_refresh)
	skills = SkillTreeUi.new()
	add_child(skills)
	skills.closed.connect(_refresh)
	codex = CodexUi.new()
	add_child(codex)
	draws = DrawsUi.new()
	add_child(draws)
	_button(box, "Collection", func(): collection.open())      # tabs along the bottom switch between them
	_button(box, "Quit", func():
		Game.save_meta()
		get_tree().quit())
	var hint := Label.new()
	hint.text = "In game: P for the pause menu (co-op host / join), H for controls."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.65, 0.7, 0.85))
	box.add_child(hint)
	_refresh()

func _button(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.pressed.connect(cb)
	parent.add_child(b)

func _refresh() -> void:
	stats_label.text = "Shards: %d     Cards unlocked: %d / %d     Best wave: %d" % [Game.meta.shards, Game.meta.unlocked.size(), Game.CARDS.size(), Game.meta.best_wave]

func _play() -> void:
	Game._menu_done = true
	get_tree().paused = false
	queue_free()
