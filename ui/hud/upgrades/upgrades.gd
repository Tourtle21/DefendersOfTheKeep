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
	wave += 1
	$Control.get_node("Label").text = "Wave " + str(wave) + " (Choose 1)"
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
				$Control.get_node("Label").text = "Wave " + str(wave) + " (Choose enemy to upgrade)"
	elif upgrading and token.type != "enemy":
		tokens_flipped -= 1
	
	if (drawing == 0 and upgrading):
		upgrades = len(enemies_flipped)
		if len(enemies_flipped) > 0:
			for enemy_token in enemies_flipped:
				$Control.get_node("Tokens").get_child(enemy_token.id).display_upgrades()
				$Control.get_node("Label").text = "Wave " + str(wave) + " (Choose upgrades to enemies)"
		else:
			tokens_flipped -= 1
			$Control.get_node("Label").text = "Wave " + str(wave) + " (Flip enemy to upgrade)"
		
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
	wave += 1
	for child in $Control.get_node("Tokens").get_children():
		child.queue_free()
	get_tree().paused = false
	get_parent().spawn_enemies(enemies_flipped)
	enemies_flipped = []
	visible = false
