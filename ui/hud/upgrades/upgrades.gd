extends CanvasLayer
var token_scene = preload("res://ui/hud/tokens/token.tscn")

var wave = 0
var token_flip_count = 1
var finished = false
var tokens_flipped = 0
var drawing = 0
var upgrading = false
var upgrades = 0


var enemies_flipped = []
var _idle := 0.0
const AUTO_AFTER := 15.0           # seconds without progress before the screen finishes a forced step for you
var _hint: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS          # the wave screen runs while the game is paused

## If the screen is waiting on something (flip a card, or pick an upgrade) and nothing happens for a while,
## do it for you, so the game can never sit there stuck.
func _process(delta: float) -> void:
	if !visible or $Control/Button.visible:
		_idle = 0.0
		return
	_idle += delta
	if _idle >= AUTO_AFTER:
		_idle = 0.0
		_auto_resolve()

func _auto_resolve() -> void:
	var kids: Array = $Control.get_node("Tokens").get_children()
	if upgrading and upgrades > 0 and !enemies_flipped.is_empty():
		var t = enemies_flipped[0]
		var node = kids[t.id]
		node.get_node("Level").text = str(int(node.get_node("Level").text) + 1)
		node.upgrade("level")
		return
	if !finished:
		for k in kids:
			if k.times_flipped == 0:
				pick_token(k.token.id)
				k.get_node("AnimationPlayer").play("flip")
				return

var enemy_tokens = [
	{
		"id": 0,
		"name": "blobbert",
		"level": 1,
		"amount": 2,
		"quadrent": 1,
		"description": "",
		"type": "enemy"
	},
	{
		"id": 1,
		"name": "goblin",
		"level": 1,
		"amount": 1,
		"quadrent": 1,
		"description": "",
		"type": "enemy"
	},
	{
		"id": 2,
		"name": "upgrade",
		"level": "",
		"amount": "",
		"quadrent": "",
		"description": "Forces you to upgrade all turned over enemies",
		"type": "upgrade"
	},
	{
		"id": 3,
		"name": "draw_two",
		"level": "",
		"amount": "",
		"quadrent": "",
		"description": "Forces you to flip over two more cards before continuing",
		"type": "upgrade"
	},
]
var total_tokens = len(enemy_tokens)

func create_tokens() -> void:
	_idle = 0.0
	if _hint == null:
		_hint = Label.new()
		_hint.position = Vector2(20, 120)
		_hint.add_theme_font_size_override("font_size", 16)
		_hint.add_theme_color_override("font_color", Color(1, 1, 0.8))
		_hint.add_theme_color_override("font_outline_color", Color.BLACK)
		_hint.add_theme_constant_override("outline_size", 4)
		$Control.add_child(_hint)
	_hint.text = "Flip one card to choose the wave. Draw Two: flip two more cards. Upgrade: click a red number on each flipped enemy. The Start button appears when you are done."
	$Control.get_node("Label").text = _title() + " (Choose 1)"
	for token in enemy_tokens:
		var token_instance = token_scene.instantiate()
		var panel_size = $Control.size - Vector2(400, 300)

		var rand_x = randi() % int(panel_size.x)
		var rand_y = randi() % int(panel_size.y)
		if rand_x < 70:
			rand_x = 70
		if rand_y < 170:
			rand_y = 170
		token_instance.position = Vector2(rand_x, rand_y)
		token_instance.token = token
		$Control.get_node("Tokens").add_child(token_instance)

## "Day wave 2" / "Night wave 3": asked from the world, so it matches the wave that is really coming.
func _title() -> String:
	var w = get_parent()
	return w.wave_title() if w != null and w.has_method("wave_title") else "Wave " + str(wave)

func upgrade(type, token_id) -> void:
	upgrades -= 1
	enemy_tokens[token_id][type] += 1
	if upgrades == 0:
		upgrading = false
		if (tokens_flipped >= token_flip_count or tokens_flipped >= total_tokens):
			finished = true
			toggle_start_button()

func pick_token(token_id) -> void:
	var token = enemy_tokens[token_id]
	tokens_flipped += 1
	if (drawing > 0):
		drawing -= 1
		$Control.get_node("Label").text = "Draw " + str(drawing) + " more to continue"
	
	if token.name == "upgrade":
		upgrading = true
				
	elif token.name == "draw_two":
		$Control.get_node("Label").text = "Draw 2 more to continue"
		tokens_flipped -= 2
		drawing = 2
	elif token.type == "enemy":
		enemies_flipped.push_back(token)
		if drawing == 0 and upgrading:
			for enemy in enemies_flipped:
				$Control.get_node("Tokens").get_children()[enemy.id].display_upgrades()
				$Control.get_node("Label").text = _title() + " (Choose enemy to upgrade)"
	elif upgrading and token.type != "enemy":
		tokens_flipped -= 1
	
	if (drawing == 0 and upgrading):
		upgrades = len(enemies_flipped)
		if len(enemies_flipped) > 0:
			for enemy_token in enemies_flipped:
				$Control.get_node("Tokens").get_child(enemy_token.id).display_upgrades()
				$Control.get_node("Label").text = _title() + " (Choose upgrades to enemies)"
		else:
			tokens_flipped -= 1
			$Control.get_node("Label").text = _title() + " (Flip enemy to upgrade)"
		
	if (tokens_flipped >= token_flip_count or tokens_flipped >= total_tokens):
		finished = true
		if (upgrading == false):
			toggle_start_button()

func toggle_start_button() -> void:
	$Control/Button.visible = !$Control/Button.visible


func _on_button_pressed() -> void:
	toggle_start_button()
	token_flip_count = 1
	finished = false
	tokens_flipped = 0
	upgrading = false
	for child in $Control.get_node("Tokens").get_children():
		child.queue_free()
	get_tree().paused = false
	get_parent().spawn_enemies(enemies_flipped)
	enemies_flipped = []
	visible = false
