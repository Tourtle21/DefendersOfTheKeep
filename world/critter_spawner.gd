extends Node
class_name CritterSpawner
## Now and then a rainbow sheep appears somewhere in the open part of the map. At most one at
## a time; the first shows up about half a minute into a run.

var timer: Timer

func _ready() -> void:
	timer = Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_on_timeout)
	timer.start(30.0)

func _on_timeout() -> void:
	if get_tree().get_nodes_in_group("critter").is_empty():
		spawn_sheep()
	timer.start(randf_range(70.0, 120.0))

func spawn_sheep():
	var world: Node = Game.world
	if world == null:
		return null
	var id: String = Game.sectors_unlocked.pick_random()
	var angle := deg_to_rad(Game.SECTOR_ANGLES[id] + randf_range(-25.0, 25.0))
	var pos := Vector2.from_angle(angle) * randf_range(230.0, 650.0)
	var map: RID = world.get_world_2d().navigation_map
	if NavigationServer2D.map_get_iteration_id(map) > 0:
		pos = NavigationServer2D.map_get_closest_point(map, pos)      # never inside a tower or tree
	var sheep := RainbowSheep.new()
	sheep.position = pos
	world.add_child(sheep)
	Game.announce.emit("A rainbow sheep appeared! Catch it for loot before it runs off.")
	return sheep
