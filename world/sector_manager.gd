extends Node2D
class_name SectorManager
## Builds and runs the six sectors around the keep. Each sector has its own look
## (ground colours, tinted props), a resource, native enemies and a boss at its far
## end. Beating a boss unlocks the next sector: its grey cover disappears and the
## keep gate opens. After the sixth, the final boss comes for the keep.

# the cone every sector is built from (same outline as the grey covers in world.tscn)
const OUTLINE := [Vector2(-61, 106), Vector2(-750, 1299), Vector2(750, 1299), Vector2(61, 105),
	Vector2(58, 107), Vector2(53, 110), Vector2(46, 113), Vector2(40, 115), Vector2(31, 118), Vector2(22, 120),
	Vector2(14, 121), Vector2(3, 122), Vector2(-2, 122), Vector2(-16, 121), Vector2(-27, 119), Vector2(-41, 115),
	Vector2(-53, 110)]

const COVERS := {"s": "Polygon2D", "sw": "Polygon2D2", "nw": "Polygon2D3", "n": "Polygon2D4", "ne": "Polygon2D5", "se": "Polygon2D6"}
const NEXT := {"s": "se", "se": "ne", "ne": "n", "n": "nw", "nw": "sw", "sw": "final"}

const SECTORS := {
	"s": {"name": "Grassland", "resource": "", "tint": Color.WHITE,
		"boss": {"boss_name": "King Blobbert", "max_health": 40.0, "speed": 24.0, "color": Color(0.3, 0.8, 0.35), "body_radius": 20.0, "attacks": ["bounce", "bramble", "vine_sweep"], "dmg_mult": 1.0, "gold_drop": 10}},
	"se": {"tree_shift": [-70.0, 0.55, 1.0], "natives": [["golem", 2], ["scarab", 3], ["spitter", 1]], "hazard": {"kind": "slow", "factor": 0.5, "color": Color(0.75, 0.6, 0.3, 0.55), "count": 8, "radius": 36.0}, "name": "Scorched Desert", "resource": "iron", "ground": Color(0.93, 0.8, 0.5), "speckle": Color(0.82, 0.66, 0.36), "tint": Color(1.0, 0.88, 0.55), "native": Color(1.0, 0.75, 0.3),
		"boss": {"resist": {"ice": 1.6, "earth": 0.4}, "boss_name": "Sand Colossus", "max_health": 70.0, "speed": 26.0, "color": Color(0.85, 0.65, 0.3), "body_radius": 24.0, "attacks": ["sand_spiral", "quicksand", "scarab_fan"], "dmg_mult": 1.2, "gold_drop": 14}},
	"ne": {"tree_shift": [95.0, 0.3, 1.15], "natives": [["frost_imp", 3], ["splitter", 2], ["runner", 1]], "hazard": {"kind": "slow", "factor": 0.6, "color": Color(0.9, 0.95, 1.0, 0.5), "count": 8, "radius": 34.0}, "name": "Frozen Tundra", "resource": "frost", "ground": Color(0.88, 0.94, 1.0), "speckle": Color(0.68, 0.8, 0.95), "tint": Color(0.8, 0.92, 1.1), "native": Color(0.6, 0.85, 1.2),
		"boss": {"resist": {"fire": 1.6, "ice": 0.4}, "boss_name": "Frost Wyrm", "max_health": 95.0, "speed": 30.0, "color": Color(0.55, 0.8, 1.0), "body_radius": 24.0, "attacks": ["ice_lance", "blizzard", "frost_nova"], "dmg_mult": 1.4, "gold_drop": 16}},
	"n": {"tree_shift": [-95.0, 0.35, 0.55], "natives": [["ember_imp", 3], ["brute", 2], ["scarab", 2]], "hazard": {"kind": "burn", "color": Color(1.0, 0.3, 0.1, 0.5), "count": 7, "radius": 30.0}, "name": "Ember Wastes", "resource": "ember", "ground": Color(0.24, 0.11, 0.1), "speckle": Color(0.65, 0.2, 0.1), "tint": Color(1.0, 0.55, 0.4), "native": Color(1.3, 0.5, 0.3),
		"boss": {"resist": {"ice": 1.6, "fire": 0.4}, "boss_name": "Magma Titan", "max_health": 125.0, "speed": 26.0, "color": Color(0.9, 0.35, 0.15), "body_radius": 28.0, "attacks": ["meteor_rain", "lava_spokes", "fire_wave"], "dmg_mult": 1.65, "gold_drop": 18}},
	"nw": {"tree_shift": [25.0, 0.6, 0.65], "natives": [["bog_lurker", 2], ["spitter", 3], ["splitter", 1]], "hazard": {"kind": "slow", "factor": 0.45, "color": Color(0.25, 0.3, 0.15, 0.6), "count": 9, "radius": 38.0}, "name": "Murky Swamp", "resource": "moss", "ground": Color(0.2, 0.3, 0.2), "speckle": Color(0.13, 0.2, 0.11), "tint": Color(0.6, 0.8, 0.5), "native": Color(0.6, 0.9, 0.5),
		"boss": {"resist": {"fire": 1.6, "poison": 0.3}, "boss_name": "Bog Mother", "max_health": 150.0, "speed": 24.0, "color": Color(0.4, 0.55, 0.25), "body_radius": 26.0, "attacks": ["poison_pools", "tongue_lash", "mire_grasp"], "dmg_mult": 1.9, "gold_drop": 20}},
	"sw": {"tree_shift": [125.0, 0.7, 0.95], "natives": [["crystal_guard", 2], ["runner", 2], ["spitter", 2], ["brute", 1]], "hazard": {"kind": "heal", "color": Color(0.7, 0.5, 1.0, 0.45), "count": 5, "radius": 30.0}, "name": "Crystal Caverns", "resource": "gem", "ground": Color(0.27, 0.2, 0.4), "speckle": Color(0.5, 0.35, 0.7), "tint": Color(0.85, 0.7, 1.1), "native": Color(0.9, 0.6, 1.2),
		"boss": {"armor": 1.5, "resist": {"earth": 1.6}, "boss_name": "Crystal Warden", "max_health": 180.0, "speed": 28.0, "color": Color(0.6, 0.4, 0.9), "body_radius": 28.0, "attacks": ["prism_beams", "shard_trail", "facet_burst"], "dmg_mult": 2.2, "gold_drop": 22}},
}

var world: Node
var _bosses := {}
var _containers := {}      # sector id -> Node2D holding its ground, props and hazards

func _ready() -> void:
	world = get_parent()
	for id in SECTORS:
		_build(id)

func _rot(id: String) -> float:
	return deg_to_rad(Game.SECTOR_ANGLES[id] - 90.0)

func _ground_texture(base: Color, speckle: Color) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(base)
	for i in 160:
		var c := speckle.lerp(base, randf() * 0.5)
		img.set_pixel(randi() % 64, randi() % 64, c)
	return ImageTexture.create_from_image(img)

func _build(id: String) -> void:
	var def: Dictionary = SECTORS[id]
	var rot := _rot(id)
	if id != "s":
		# everything in a locked sector sleeps (no processing, not drawn) until it unlocks
		var box := Node2D.new()
		box.name = "Sector_" + id
		box.visible = false
		box.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(box)
		_containers[id] = box
		var ground := Polygon2D.new()
		ground.polygon = PackedVector2Array(OUTLINE)
		ground.uv = PackedVector2Array(OUTLINE)
		ground.texture = _ground_texture(def.ground, def.speckle)
		ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ground.rotation = rot
		ground.z_index = -1
		box.add_child(ground)
		_scatter_props(id, def, rot, box)
		_scatter_hazards(def, rot, box)
		_place_generator(id, def, rot, box)
	if id == "s":
		# the grassland has a stone generator and a stick generator, hidden somewhere in the sector each game
		for kind in [["stone", Color(0.75, 0.78, 0.85)], ["stick", Color(0.65, 0.5, 0.3)]]:
			var home := ResourceGenerator.new()
			home.resource = kind[0]
			home.color = kind[1]
			home.position = _random_spot(rot, 240.0, 850.0)
			add_child(home)
	var boss := Boss.new()
	var params: Dictionary = def.boss.duplicate()
	params["sector_id"] = id
	params["sprite_path"] = "res://enemies/boss/art/%s.png" % id
	boss.setup(params)
	boss.position = Vector2(0, 1050).rotated(rot)
	boss.defeated.connect(_on_boss_defeated.bind(id))
	add_child(boss)
	boss.set_dormant(true)         # every boss waits for its sector's fifth wave (world.gd calls arrive()); until then it is not in the world
	_bosses[id] = boss

## One resource generator per biome, somewhere in the sector (different every game: you have to find it).
func _place_generator(id: String, def: Dictionary, rot: float, box: Node) -> void:
	var gen := ResourceGenerator.new()
	gen.resource = def.resource
	gen.color = def.get("native", Color(0.8, 0.9, 1.0))
	gen.position = _random_spot(rot, 260.0, 900.0)
	box.add_child(gen)

var _gen_spots: Array = []            # where generators already are (in world space), so two never sit on top of each other

## A random point in a sector's cone, `min_d` to `max_d` units from the keep along its axis, away from other generators
## and from the boss at the far end. (`rot` turns the grassland-shaped cone to the sector.)
func _random_spot(rot: float, min_d: float, max_d: float) -> Vector2:
	var best := Vector2.ZERO
	for attempt in 30:
		var angle := randf_range(-0.42, 0.42)
		var pos: Vector2 = (Vector2(0, 1).rotated(angle) * randf_range(min_d, max_d)).rotated(rot)
		best = pos
		var clear := true
		for other in _gen_spots:
			if other.distance_to(pos) < 160.0:
				clear = false
		if clear:
			break
	_gen_spots.append(best)
	return best

func _scatter_props(id: String, def: Dictionary, rot: float, box: Node) -> void:
	var specs := [
		["res://collectables/rock/medium_rock.tscn", def.resource, def.tint.lerp(Color(0.8, 0.6, 0.5), 0.4), 10],
		["res://collectables/rock/small_rocks.tscn", "stone", def.tint, 6],
		["res://collectables/tree/tree.tscn", "stick", Color.WHITE, 10],
	]
	for spec in specs:
		var scene: PackedScene = load(spec[0])
		for i in spec[3]:
			var p: Node = scene.instantiate()
			if spec[0].ends_with("tree.tscn"):
				_recolor_tree(p, def.tree_shift)
			p.drop_type = spec[1]
			# tint the sprites themselves (the root's modulate gets reset by the shake animation)
			for sp in p.find_children("*", "Sprite2D", true, false):
				sp.modulate = spec[2]
			p.position = (Vector2(0, 1).rotated(randf_range(-0.45, 0.45)) * randf_range(260.0, 1000.0)).rotated(rot)
			box.add_child(p)

var _tree_cache := {}

## Hue-shift the tree sprite so each biome has its own kind of tree.
func _recolor_tree(p: Node, shift: Array) -> void:
	var sp: Sprite2D = p.get_node("Sprite2D")
	var key := str(shift)
	if !_tree_cache.has(key):
		var img: Image = sp.texture.get_image()
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0 and c.s > 0.15:        # leave the black outline and trunk-neutral pixels alone
					c.h = fposmod(c.h + shift[0] / 360.0, 1.0)
					c.s = clamp(c.s * shift[1], 0.0, 1.0)
					c.v = clamp(c.v * shift[2], 0.0, 1.0)
					img.set_pixel(x, y, c)
		_tree_cache[key] = ImageTexture.create_from_image(img)
	sp.texture = _tree_cache[key]

func _scatter_hazards(def: Dictionary, rot: float, box: Node) -> void:
	var hz: Dictionary = def.hazard
	for i in hz.count:
		var h := Hazard.new()
		h.kind = hz.kind
		h.factor = hz.get("factor", 0.5)
		h.radius = hz.radius * randf_range(0.8, 1.25)
		h.color = hz.color
		h.position = (Vector2(0, 1).rotated(randf_range(-0.45, 0.45)) * randf_range(300.0, 950.0)).rotated(rot)
		box.add_child(h)

func _spawn_natives(id: String) -> void:
	var def: Dictionary = SECTORS[id]
	for entry in def.natives:
		var scene: PackedScene = load("res://enemies/%s/%s.tscn" % [entry[0], entry[0]])
		for i in entry[1]:
			var e = scene.instantiate()
			e.level = 1
			if entry[0] == "scarab":
				e.tint = def.native
			e.position = (Vector2(0, 1).rotated(randf_range(-0.35, 0.35)) * randf_range(550.0, 900.0)).rotated(_rot(id))
			add_child(e)

## Each sector's own weapon lies somewhere inside it once the sector opens (its boss drops it too).
func _spawn_weapon_pickup(id: String) -> void:
	if !Game.SECTOR_WEAPONS.has(id) or !Game.weapon_unlocked(Game.SECTOR_WEAPONS[id]):
		return                      # a sector weapon only appears once you have unlocked it
	var pick = load("res://collectables/collectable.tscn").instantiate()
	pick.item_type = Game.SECTOR_WEAPONS[id]
	pick.position = (Vector2(0, 1).rotated(randf_range(-0.3, 0.3)) * randf_range(330.0, 560.0)).rotated(_rot(id))
	add_child(pick)

func unlock(id: String) -> void:
	if id in Game.sectors_unlocked:
		return
	Game.sectors_unlocked.append(id)
	_wake(id)
	var cover = world.get_node("CanvasLayer").get_node_or_null(COVERS[id])
	if cover:
		cover.visible = false
	Game.announce.emit("New area unlocked: %s" % SECTORS[id].name)
	for child in world.get_children():          # the tower on this sector's edge comes online
		if str(child.scene_file_path).ends_with("tower.tscn") and Game.sector_at(child.position) == id:
			child.visible = true
	for cid in Game.SECTOR_CARDS.get(id, []):
		if !(cid in Game.unlocked_cards):
			Game.unlocked_cards.append(cid)      # drafted from chests from now on, this run
	for cid in Game.COMBO_CARDS:
		if Game.card_available(cid) and !(cid in Game.unlocked_cards):
			Game.unlocked_cards.append(cid)
			Game.announce.emit("New combo building: %s" % Game.CARDS[cid].name)
	Game.sector_unlocked.emit(id)
	Sfx.play("unlock", 0.0)
	_spawn_natives(id)
	_spawn_weapon_pickup(id)

## A newly unlocked sector comes to life: ground, props, hazards and its boss.
func _wake(id: String) -> void:
	if _containers.has(id):
		_containers[id].visible = true
		_containers[id].process_mode = Node.PROCESS_MODE_INHERIT
	# (its boss stays away until the sector's fifth wave starts: world.gd _boss_arrives)

func _on_boss_defeated(_boss, id: String) -> void:
	var nxt: String = NEXT[id]
	if nxt == "final":
		_spawn_final_boss()
	else:
		unlock(nxt)

func _spawn_final_boss() -> void:
	Game.announce.emit("The Devourer comes for the keep!")
	var boss := Boss.new()
	boss.setup({"boss_name": "The Devourer", "sector_id": "final", "max_health": 260.0, "speed": 32.0,
		"color": Color(0.35, 0.1, 0.45), "body_radius": 34.0, "attacks": ["slam", "charge", "summon", "volley", "quake"],
		"gold_drop": 30, "wake_distance": 9999.0, "wake_wave": 0, "dmg_mult": 2.6, "sprite_path": "res://enemies/boss/art/final.png"})
	boss.position = Vector2(0, -70)
	boss.defeated.connect(func(_b): Game.win_run())
	add_child.call_deferred(boss)
