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
	add_child(preload("res://ui/hud/respawn_ui.gd").new())
	_banner = preload("res://ui/hud/wave_banner.gd").new()
	add_child(_banner)
	if DisplayServer.get_name() != "headless":
		Engine.time_scale = GAME_SPEED
	add_child(preload("res://ui/base/base_ui.gd").new())
	add_child(preload("res://ui/base/draft_ui.gd").new())
	add_child(preload("res://ui/base/run_end_ui.gd").new())
	add_child(preload("res://ui/base/help_ui.gd").new())
	add_child(preload("res://ui/base/pause_ui.gd").new())
	add_child(preload("res://ui/base/hints.gd").new())
	add_child(preload("res://ui/base/lobby_ui.gd").new())
	if !Game._menu_done and !Net.active and Net.cmd_join == "" and !Net.wants_host() and DisplayServer.get_name() != "headless":
		add_child(preload("res://ui/base/main_menu.gd").new())
	for tower_name in ["Tower", "Tower2", "Tower5", "Tower6", "Tower7", "Tower8"]:
		get_node(tower_name).add_child(preload("res://scenery/tower/turret.gd").new())
	add_child(preload("res://world/sector_manager.gd").new())
	if !(Net.cmd_join != "" and !Net.active):
		add_child(CritterSpawner.new())
	add_child(preload("res://ui/forge/forge_ui.gd").new())
	add_child(preload("res://scenery/forge/forge.gd").new())
	add_child(preload("res://ui/forge/card_fuse_ui.gd").new())
	add_child(preload("res://scenery/card_fuser/card_fuser.gd").new())
	add_child(preload("res://world/chest_spawner.gd").new())
	start_split_screen()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	Input.set_custom_mouse_cursor(cursor_path, 0, Vector2(16, 16))
	$Player/PointLight2D.energy = 0
	night_wave = false
	$SpawnTimer.wait_time = FIRST_WAVE_AT          # setup time before the first (day) wave
	$SpawnTimer.start()
	await $SpawnTimer.timeout
	if len($Enemies.get_children()) == 0:
		$Well.return_crystal()
	_begin_wave()
	
var _split_started := false

## Local split screen: the players chose their controllers in the lobby (Game._local_devices). Called when the world is
## built (tests, restarts) and again by the main menu when the lobby starts a game, since the world exists before that.
func start_split_screen() -> void:
	if _split_started or Game._local_devices.size() < 2 or Net.active:
		return
	_split_started = true
	var lp := preload("res://world/local_players.gd").new()
	add_child(lp)
	lp.setup(Game._local_devices.size())
	var split := preload("res://world/split_screen.gd").new()
	add_child(split)
	split.setup(Game._local_devices.size(), lp)

# ---- day, night and the waves ----
# One cycle is 5 minutes: a long day, a slow dusk, a night, a dawn. There is one wave in the day and one in the
# night, well apart, so there is time to set up. The clock only runs while the game is not paused.
const NIGHT_DARKNESS := 1.0        # how much of the day the night takes away (1 = pitch black); lights add back the same amount
const WAVE_SIZE := 2.0             # waves come about three times less often than they used to, so each one is bigger
const FIRST_BOSS_WAVE := 3          # King Blobbert shows up when this wave starts
const CYCLE := 260.0
const FIRST_WAVE_AT := 40.0        # setup time before the first wave, in seconds
const DAY_WAVE_AT := 35.0          # when in the cycle (seconds) each wave spawns
const NIGHT_WAVE_AT := 152.0
const DUSK_AT := 130.0             # darkness starts to rise (over 44 s), full night from 174
const DAWN_AT := 226.0             # and fades again (over 40 s)
var clock := 0.0
var _banner
const GAME_SPEED := 0.8           # the whole game runs a little slower than real time (not in headless tests)
const CLEAR_PATIENCE := 90.0      # the next wave waits this long past its time for the last one to be beaten
var night_wave := false            # the wave being set up now is a night wave
var _last_cycle_t := 0.0

## How dark it is at a clock time: 0 in full day, 1 in full night.
static func night_for(c: float) -> float:
	var t := fposmod(c, CYCLE)
	if t < DUSK_AT:
		return 0.0
	if t < DUSK_AT + 44.0:
		return smoothstep(0.0, 1.0, (t - DUSK_AT) / 44.0)
	if t < DAWN_AT:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (t - DAWN_AT) / 40.0)

## Seconds until the clock next reaches `event_at`, never less than 40.
func seconds_until(event_at: float) -> float:
	return maxf(40.0, fposmod(event_at - clock, CYCLE))

## "Day wave 2" / "Night wave 3": the wave that is about to come.
func wave_title() -> String:
	return "%s wave %d" % ["Night" if night_wave else "Day", Game.run_stats.waves + 1]

func _process(delta: float) -> void:
	clock += delta
	var t := fposmod(clock, CYCLE)
	Game.night_level = night_for(clock)
	$Daylight.color = Color(1.0, 0.95, 0.75)               # takes less blue away: night is a dark blue, not black
	$Daylight.energy = Game.night_level * NIGHT_DARKNESS
	$Player/PointLight2D.energy = Game.night_level * 0.55          # the player's own light is a gentle circle, not a spotlight
	_hide_t -= delta
	if _hide_t <= 0.0:
		_hide_t = 0.1
		_hide_unlit_enemies()
	if _last_cycle_t < DUSK_AT and t >= DUSK_AT:
		Game.announce.emit("Night falls: enemies in the dark take less damage. Bring light!")
	elif _last_cycle_t < DAWN_AT and t >= DAWN_AT:
		Game.announce.emit("Dawn is breaking.")
	_last_cycle_t = t

var _hide_t := 0.0

## At night an enemy outside every light cannot be seen (torches, flares, fire and your own small light reveal it).
func _hide_unlit_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if !is_instance_valid(e) or e.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		e.visible = Game.is_lit(e)

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
	var factor := WAVE_SIZE * Game.team_scale(0.75)        # every group grows with the number of players (LAN and split screen)
	var bonus := int(w * 0.5) + (Game.sectors_unlocked.size() - 1)
	var level_bonus := int(w / 3.0)
	var plan := []
	if night_wave:
		factor *= 1.5                  # a night wave is a bigger one
		level_bonus += 1
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

## The wave draw plays itself (no card screen): the account of what happened is part of the wave banner.
func _begin_wave() -> void:
	var r: Dictionary = $Upgrades.auto_pick()
	spawn_enemies(r.enemies, r.lines)

func _wave_alive() -> int:
	var n := 0
	for e in $Enemies.get_children():
		if is_instance_valid(e) and !e.is_queued_for_deletion() and !(e is Boss):
			n += 1
	return n

func spawn_enemies(enemies, draw_lines := []) -> void:
	Game.run_stats.waves += 1
	if Game.run_stats.waves == FIRST_BOSS_WAVE:
		for b in get_tree().get_nodes_in_group("boss"):
			if b.sector_id == "s" and !b.awake:
				b.arrive()
	var plan := wave_plan(enemies)
	var total := 0
	for e in plan:
		total += e.amount
	Game.night_wave_now = night_wave
	var head := "%s wave %d" % ["Night" if night_wave else "Day", Game.run_stats.waves]
	var lines: Array = draw_lines.duplicate()
	lines.append("%d enemies from %d direction(s)%s" % [total, Game.sectors_unlocked.size(), " (shrouded until lit)" if night_wave else ""])
	_banner.show_wave(head.to_upper() + " STARTS", lines)
	Game.announce.emit("%s starts: %d enemies. %s" % [head, total, " / ".join(draw_lines)])
	Sfx.play("wave_horn")
	for enemy in plan:
		for i in enemy.amount:
			var scene = load("res://enemies/" + enemy.name + "/" + enemy.name + ".tscn")
			var enemy_scene = scene.instantiate()
			enemy_scene.level = enemy.level
			enemy_scene.position = _spawn_position()
			$Enemies.add_child(enemy_scene)
	
	night_wave = !night_wave                       # the next wave is the other kind, a long while from now
	$SpawnTimer.wait_time = seconds_until(NIGHT_WAVE_AT if night_wave else DAY_WAVE_AT)
	$SpawnTimer.start()
	await $SpawnTimer.timeout
	# never start the next wave on top of the last one: wait for it to be beaten (up to a limit)
	var waited := 0.0
	while is_inside_tree() and waited < CLEAR_PATIENCE and _wave_alive() > 0:
		await get_tree().create_timer(1.0).timeout
		waited += 1.0
	if !is_inside_tree() or Game.run_over:
		return
	if waited >= CLEAR_PATIENCE:
		Game.announce.emit("The last wave is dragging on: the next one is coming anyway!")
	_begin_wave()
	
	

## The sword lying at the start is replaced by the weapon chosen in the Shard shop.
func _apply_start_weapon() -> void:
	var id: String = Game.start_weapon_id()
	var c = get_node_or_null("Collectable")
	if c == null or id == "sword" or !(id in Game.start_weapon_options()):
		return
	c.item_type = id
	c.get_node("Sprite2D").texture = load(c.item_info.items[id]["texture"])
