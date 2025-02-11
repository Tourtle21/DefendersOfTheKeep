extends Node2D

var cursor_path = load("res://ui/cursors/aim_cursor.png")
@onready var blobby_scene := preload("res://enemies/blobbert/blobbert.tscn")
@onready var goblin_scene := preload("res://enemies/goblin/goblin.tscn")
@export var spawn_area_size: int = 150
@export var spawn_center: Vector2 = Vector2.ZERO
var counter = 0
	
func _ready() -> void:
	randomize()
	Input.set_custom_mouse_cursor(cursor_path, 0, Vector2(16, 16))
	$SpawnTimer.start()
	await $SpawnTimer.timeout
	spawn_enemy()

func spawn_enemy() -> void:
	var instance
	if counter % 2 == 0:
		instance = blobby_scene.instantiate()
	else:
		instance = goblin_scene.instantiate()
	counter += 1
 # Generate random spawn coordinates within the square boundary
	var random_x = randi_range(-spawn_area_size, spawn_area_size)
	var random_y = randi_range(-spawn_area_size, spawn_area_size)
	var spawn_position = spawn_center + Vector2(random_x, random_y)

	add_child(instance)
	instance.position = spawn_position

	# Reduce timer wait time by 10% and restart it
	$SpawnTimer.wait_time *= 0.9
	$SpawnTimer.start()
	await $SpawnTimer.timeout
	spawn_enemy()
	
	
