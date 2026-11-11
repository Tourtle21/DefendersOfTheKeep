extends CanvasLayer
class_name MainMenu
## Start screen: your permanent unlocks (cards, weapons, skills, shards) and a Play button that starts the run.
## Shown once per launch; restarting a run goes straight back into the game.

const UiKit = preload("res://ui/cards/ui_kit.gd")
const LocalLobby = preload("res://ui/base/local_lobby.gd")
const DrawsUi = preload("res://ui/base/draws_ui.gd")
var root_ctl: Control
var skills: SkillTreeUi
var codex: CodexUi
var collection: CollectionUi
var lobby
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
	dim.color = Color(UiKit.BG, 1)
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
	title.add_theme_font_size_override("font_size", UiKit.FONT_HUGE)
	box.add_child(title)
	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", UiKit.FONT_BODY)
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
	var cards_label := Label.new()
	cards_label.text = "Start with two spells and two buildings (the rest you find in chests):"
	cards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cards_label.add_theme_font_size_override("font_size", UiKit.FONT_SMALL)
	box.add_child(cards_label)
	_card_pickers(box)
	var play := Button.new()
	play.text = "Play game"
	play.custom_minimum_size = Vector2(0, 56)
	play.add_theme_font_size_override("font_size", UiKit.FONT_BIG)
	play.pressed.connect(func():
		Game._local_devices = []                  # a normal single-player game
		_play())
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
	lobby = LocalLobby.new()
	add_child(lobby)
	lobby.started.connect(func():
		get_parent().start_split_screen()          # the world was built before the players picked their controllers
		_play())
	_button(box, "Local co-op (2-4 players, split screen)", func(): lobby.open())
	_button(box, "Collection", func(): collection.open())      # tabs along the bottom switch between them
	_button(box, "Quit", func():
		Game.save_meta()
		get_tree().quit())
	var hint := Label.new()
	hint.text = "In game: P for the pause menu (co-op host / join), H for controls."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	box.add_child(hint)
	preload("res://ui/cards/menu_pad.gd").attach(root_ctl, Callable(), "", null, play)       # controller: Play is focused first
	_refresh()

var _pickers: Array = []            # four OptionButtons: spell, spell, building, building

## Four dropdowns of the cards you own. Choosing a card another dropdown has already taken swaps them.
func _card_pickers(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var chosen: Array = Game.start_cards()
	_pickers.clear()
	for k in 4:
		var build: bool = k >= 2
		var options: Array = Game.start_card_options(build)
		var pick := OptionButton.new()
		pick.tooltip_text = "Building" if build else "Spell"
		pick.custom_minimum_size = Vector2(120, 0)
		for id in options:
			pick.add_item(str(Game.CARDS[id].name))
			pick.set_item_metadata(pick.item_count - 1, id)
		pick.selected = maxi(0, options.find(chosen[k]))
		pick.item_selected.connect(func(_i): _card_picked(k))
		row.add_child(pick)
		_pickers.append(pick)

func _picker_id(pick: OptionButton) -> String:
	return str(pick.get_item_metadata(pick.selected)) if pick.selected >= 0 else ""

func _card_picked(changed: int) -> void:
	var pair: Array = [0, 1] if changed < 2 else [2, 3]
	var other: int = pair[1] if pair[0] == changed else pair[0]
	if _picker_id(_pickers[other]) == _picker_id(_pickers[changed]):
		# the same card twice would be one card: move the other dropdown to a different one
		var taken := _picker_id(_pickers[changed])
		for i in _pickers[other].item_count:
			if str(_pickers[other].get_item_metadata(i)) != taken:
				_pickers[other].selected = i
				break
	Game.set_start_cards([_picker_id(_pickers[0]), _picker_id(_pickers[1])], [_picker_id(_pickers[2]), _picker_id(_pickers[3])])

func _button(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.pressed.connect(cb)
	parent.add_child(b)

func _refresh() -> void:
	stats_label.text = "Shards: %d     Cards unlocked: %d / %d     Best wave: %d" % [Game.meta.shards, Game.meta.unlocked.size(), Game.CARDS.keys().filter(func(id): return !Game.CARDS[id].get("fused", false)).size(), Game.meta.best_wave]

func _play() -> void:
	Game._menu_done = true
	Music._update()                             # the music starts now, not while the menu is up
	get_tree().paused = false
	queue_free()
