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
	if Net.cmd_join != "" and !Net.active:
		# launched with `-- join=ADDRESS`: this process is a co-op client, not a host
		_start_client.call_deferred(Net.cmd_join)
		return
	randomize()
	if Net.wants_host() and !Net.active:
		Net.host_game()
		Net.lobby = true      # wait in the lobby until the host presses Start
	Game.world = self
	for child in get_children():
		if child.scene_file_path.ends_with("tower.tscn") or child.name == "Well":
			child.add_to_group("nav_obstacle")
	for child in get_children():        # script-less static scenery (the six towers) is replicated too
		if child.scene_file_path.ends_with("tower.tscn") or child.name == "PressurePlate" or child.name == "Well":
			child.add_to_group("net")
	if REMOVE_LAKE:
		_remove_lake()
	Game.start_run()
	_apply_start_weapon()
	$GrassTilemap.navigation_enabled = false          # replaced by one carved navigation polygon
	add_child(NavBuilder.new())
	if Net.active and Net.is_host:
		Net.respawn_avatars.call_deferred()
	add_child(preload("res://ui/hud/ability_hud.gd").new())
	add_child(preload("res://ui/base/crystal_alert.gd").new())
	add_child(preload("res://ui/base/base_ui.gd").new())
	add_child(preload("res://ui/base/draft_ui.gd").new())
	add_child(preload("res://ui/base/run_end_ui.gd").new())
	add_child(preload("res://ui/base/help_ui.gd").new())
	add_child(preload("res://ui/base/pause_ui.gd").new())
	add_child(preload("res://ui/base/hints.gd").new())
	add_child(preload("res://ui/base/lobby_ui.gd").new())
	for tower_name in ["Tower", "Tower2", "Tower5", "Tower6", "Tower7", "Tower8"]:
		get_node(tower_name).add_child(preload("res://scenery/tower/turret.gd").new())
	add_child(preload("res://world/sector_manager.gd").new())
	if !(Net.cmd_join != "" and !Net.active):
		add_child(CritterSpawner.new())
	add_child(preload("res://ui/forge/forge_ui.gd").new())
	add_child(preload("res://scenery/forge/forge.gd").new())
	add_child(preload("res://world/chest_spawner.gd").new())
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	Input.set_custom_mouse_cursor(cursor_path, 0, Vector2(16, 16))
	$Player/PointLight2D.energy = 0
	$SpawnTimer.wait_time = randf_range(spawn_min_speed, spawn_max_speed)
	$SpawnTimer.start()
	await $SpawnTimer.timeout
	Input.set_custom_mouse_cursor(pointer_path, 0, Vector2(0, 0))
	if len($Enemies.get_children()) == 0:
		$Well.return_crystal()
	get_tree().paused = !Net.active          # in co-op the game keeps running (friends are playing)
	$Upgrades.visible = true
	$Upgrades.create_tokens()
	if Net.active:
		_coop_auto_pick()
	
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
	

## The little lake in the yard was just for fun and got in the way (pathing, tests, space
## for biome features). It is turned into grass at start; set false to bring it back.
const REMOVE_LAKE := true

func _remove_lake() -> void:
	var layer: TileMapLayer = $GrassTilemap
	for c in layer.get_used_cells():
		if !(layer.get_cell_atlas_coords(c) in GRASS_TILES):
			layer.set_cell(c, layer.get_cell_source_id(c), GRASS_TILES[0])

# Tiles that are solid grass. Anything else on the tilemap is water or an edge tile.
const GRASS_TILES := [Vector2i(3, 4), Vector2i(4, 4)]

## Where a wave enemy appears: a random unlocked sector, at its far end. The south
## sector uses a real grass tile; the others use the sector cone geometry.
func _start_client(address: String) -> void:
	Net.joined.connect(func(): get_tree().change_scene_to_file("res://net/client_view.tscn"), CONNECT_ONE_SHOT)
	Net.join_game(address)

func _spawn_position() -> Vector2:
	var id: String = Game.sectors_unlocked.pick_random()
	if id != "s":
		var rot := deg_to_rad(Game.SECTOR_ANGLES[id] - 90.0)
		return Vector2(randf_range(-320.0, 320.0), randf_range(1080.0, 1200.0)).rotated(rot)
	var layer: TileMapLayer = $GrassTilemap
	for i in 60:
		var p := Vector2(randi_range(-spawn_area_size, spawn_area_size), randi_range(1180, 1270))
		var atlas := layer.get_cell_atlas_coords(layer.local_to_map(layer.to_local(p)))
		if atlas in GRASS_TILES:
			return p
	return Vector2(0, 1240)

## The wave the player picked, made harder by how far into the run we are:
## more enemies, higher levels, a spread across every unlocked sector, and new
## enemy types (brutes every third wave, runners from wave 4, spitters from wave 5, splitters from wave 6).
func wave_plan(picked: Array) -> Array:
	var w: int = Game.run_stats.waves
	var players: int = max(1, get_tree().get_nodes_in_group("player").size())
	var factor := 1.0 + 0.6 * (players - 1)        # every group grows with the number of players
	var bonus := int(w * 0.5) + (Game.sectors_unlocked.size() - 1)
	var level_bonus := int(w / 3.0)
	var plan := []
	for e in picked:
		plan.append({"name": e.name, "amount": int(ceil((e.amount + bonus) * factor)), "level": e.level + level_bonus})
	if w >= 3 and w % 3 == 0:
		plan.append({"name": "brute", "amount": int(ceil(int(w / 3.0) * factor)), "level": 1})
	if w >= 4:
		plan.append({"name": "runner", "amount": int(ceil(int(w / 2.0) * factor)), "level": 1})
	if w >= 5:
		plan.append({"name": "spitter", "amount": int(ceil(int(w / 4.0) * factor)), "level": 1})
	if w >= 6:
		plan.append({"name": "splitter", "amount": int(ceil(int(w / 3.0) * factor)), "level": 1})
	# each opened biome sends its own kind: golems, frost and ember imps, bog lurkers, crystal guards
	var biome_enemy := {"se": "golem", "ne": "frost_imp", "n": "ember_imp", "nw": "bog_lurker", "sw": "crystal_guard"}
	if w >= 2:
		for sec in Game.sectors_unlocked:
			if biome_enemy.has(sec):
				plan.append({"name": biome_enemy[sec], "amount": int(ceil((1 + w / 4.0) * factor)), "level": 1})
	return plan

func spawn_enemies(enemies) -> void:
	Game.run_stats.waves += 1
	var plan := wave_plan(enemies)
	var total := 0
	for e in plan:
		total += e.amount
	Game.announce.emit("Wave %d: %d enemies from %d direction(s)" % [Game.run_stats.waves, total, Game.sectors_unlocked.size()])
	# the pause between waves shrinks as the run goes on
	spawn_min_speed = max(15.0, 30.0 - Game.run_stats.waves * 1.5)
	spawn_max_speed = max(30.0, 60.0 - Game.run_stats.waves * 2.0)
	Input.set_custom_mouse_cursor(cursor_path, 0, Vector2(16, 16))
	for enemy in plan:
		for i in enemy.amount:
			var scene = load("res://enemies/" + enemy.name + "/" + enemy.name + ".tscn")
			var enemy_scene = scene.instantiate()
			enemy_scene.level = enemy.level
			enemy_scene.position = _spawn_position()
			$Enemies.add_child(enemy_scene)
	
	$SpawnTimer.wait_time = randf_range(spawn_min_speed, spawn_max_speed)
	$SpawnTimer.start()
	await $SpawnTimer.timeout
	Input.set_custom_mouse_cursor(pointer_path, 0, Vector2(0, 0))
	get_tree().paused = true
	$Upgrades.visible = true
	$Upgrades.create_tokens()
	
	

## Co-op: the wave-choice screen does not freeze the game, and picks for you after a while.
func _coop_auto_pick() -> void:
	await get_tree().create_timer(12.0).timeout
	if is_inside_tree() and $Upgrades.visible:
		$Upgrades.pick_token(0)
		$Upgrades._on_button_pressed()

## The sword lying at the start is replaced by the weapon chosen in the Shard shop.
func _apply_start_weapon() -> void:
	var id: String = Game.start_weapon_id()
	var c = get_node_or_null("Collectable")
	if c == null or id == "sword" or !(id in Game.start_weapon_options()):
		return
	c.item_type = id
	c.get_node("Sprite2D").texture = load(c.item_info.items[id]["texture"])
