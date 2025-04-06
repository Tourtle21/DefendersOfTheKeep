extends Node2D

var cursor_path = load("res://ui/cursors/aim_cursor.png")
var pointer_path = load("res://ui/cursors/pointer.png")
@export var spawn_area_size: int = 700
@export var spawn_center: Vector2 = Vector2.ZERO
@export var item_info: Resource
var counter = 0
var time = 0
var spawn_min_speed = 30
var spawn_max_speed = 60
	
func _ready() -> void:
	randomize()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	Input.set_custom_mouse_cursor(cursor_path, 0, Vector2(16, 16))
	$Player/PointLight2D.energy = 0
	$SpawnTimer.wait_time = randf_range(spawn_min_speed, spawn_max_speed)
	$SpawnTimer.start()
	await $SpawnTimer.timeout
	Input.set_custom_mouse_cursor(pointer_path, 0, Vector2(0, 0))
	if len($Enemies.get_children()) == 0:
		$Well.return_crystal()
	get_tree().paused = true
	$Upgrades.visible = true
	$Upgrades.create_tokens()
	
func _process(delta: float) -> void:
	if $DaylightTimer.time_left < 10 and (time == 1 or time == 3):
		var light
		if (time == 1):
			light = 1 - $DaylightTimer.time_left / 10
		elif (time == 3):
			light = $DaylightTimer.time_left / 10
		$Daylight.energy = light
		$Player/PointLight2D.energy = light
	if $DaylightTimer.time_left == 0:
		$DaylightTimer.start()
		if (time == 3):
			time = 0
		else:
			time += 1
	

func spawn_enemies(enemies) -> void:
	Input.set_custom_mouse_cursor(cursor_path, 0, Vector2(16, 16))
	for enemy in enemies:
		for i in enemy.amount:
			var scene = load("res://enemies/" + enemy.name + "/" + enemy.name + ".tscn")
			var enemy_scene = scene.instantiate()
			var random_x = randi_range(-spawn_area_size, spawn_area_size)
			var y = 1300
			enemy_scene.level = enemy.level
			enemy_scene.position = Vector2(random_x, y)
			$Enemies.add_child(enemy_scene)
	
	$SpawnTimer.wait_time = randf_range(spawn_min_speed, spawn_max_speed)
	$SpawnTimer.start()
	await $SpawnTimer.timeout
	Input.set_custom_mouse_cursor(pointer_path, 0, Vector2(0, 0))
	get_tree().paused = true
	$Upgrades.visible = true
	$Upgrades.create_tokens()
	
	
