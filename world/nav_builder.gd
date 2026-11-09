extends Node
class_name NavBuilder
## Keeps ONE navigation polygon for the whole map, carved around everything solid, so
## enemies and bosses path around towers, the Well, trees, rocks and barricades instead
## of walking into them. Anything solid joins the group "nav_obstacle" and calls
## Game.nav_changed when it appears or goes away; the polygon is rebuilt (off the main
## thread, after a short pause so a burst of changes bakes once).
##
## Why a baked polygon and not a navigation tile per cell: one region instead of thousands,
## and a rebuild costs a few milliseconds whatever the map size.

const YARD_RADIUS := 130.0     # the keep yard (players stop at 120)
const AGENT_RADIUS := 6.0     # obstacles are grown by this much (enemies are small)

var region: NavigationRegion2D
var bakes := 0
var _dirty := false
var _timer := 0.0
var _baking := false

func _ready() -> void:
	add_to_group("net_local")          # host-side helper: clients do not path
	region = NavigationRegion2D.new()
	add_child(region)
	Game.nav_changed.connect(func():
		_dirty = true
		_timer = 0.4)
	Game.sector_unlocked.connect(func(_id): rebuild_now())          # a new sector joins the walkable map
	rebuild_now()

func _process(delta: float) -> void:
	if _dirty and !_baking:
		_timer -= delta
		if _timer <= 0.0:
			_dirty = false
			_bake_async()

## The playable ground, and only that: the keep yard plus the cone of every sector that is open. The grey locked ground is
## not part of the map, so no enemy ever plans a route across it (see Game.in_playable for the same area).
func _walkable() -> Array:
	var yard := PackedVector2Array()
	for i in 32:
		yard.append(Vector2.from_angle(i * TAU / 32.0) * YARD_RADIUS)
	var areas: Array = [yard]
	for id in Game.sectors_unlocked:
		var rot := deg_to_rad(Game.SECTOR_ANGLES[id] - 90.0)
		var cone := PackedVector2Array()
		for p in Game.SECTOR_OUTLINE:
			cone.append(p.rotated(rot))
		var merged: Array = []
		var current: PackedVector2Array = cone
		for a in areas:
			var u := Geometry2D.merge_polygons(a, current)
			if u.size() == 1:
				current = u[0]                       # overlapping: one bigger area
			else:
				merged.append(a)                     # separate: keep it as it is
		merged.append(current)
		areas = merged
	return areas

func _source() -> NavigationMeshSourceGeometryData2D:
	var src := NavigationMeshSourceGeometryData2D.new()
	for area in _walkable():
		src.add_traversable_outline(area)
	for n in get_tree().get_nodes_in_group("nav_obstacle"):
		if !is_instance_valid(n) or n.is_queued_for_deletion() or n.is_in_group("puppet"):
			continue
		for cs in n.get_children():
			if cs is CollisionShape2D and !cs.disabled:
				var pts := _polygon(cs)
				if pts.size() >= 3:
					src.add_obstruction_outline(pts)
	return src

func _poly() -> NavigationPolygon:
	var p := NavigationPolygon.new()
	p.agent_radius = AGENT_RADIUS
	return p

## Bake right now (startup, tests).
func rebuild_now() -> void:
	var p := _poly()
	NavigationServer2D.bake_from_source_geometry_data(p, _source())
	region.navigation_polygon = p
	bakes += 1

func _bake_async() -> void:
	_baking = true
	var p := _poly()
	NavigationServer2D.bake_from_source_geometry_data_async(p, _source(), _on_baked.bind(p))

func _on_baked(p: NavigationPolygon) -> void:
	region.navigation_polygon = p
	bakes += 1
	_baking = false

## The shape's footprint in world coordinates.
func _polygon(cs: CollisionShape2D) -> PackedVector2Array:
	var local := PackedVector2Array()
	var s: Shape2D = cs.shape
	if s is RectangleShape2D:
		var h: Vector2 = s.size / 2.0
		local = PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])
	elif s is CircleShape2D:
		for i in 10:
			local.append(Vector2.from_angle(i * TAU / 10.0) * s.radius)
	elif s is CapsuleShape2D:
		var hh: float = s.height / 2.0
		local = PackedVector2Array([Vector2(-s.radius, -hh), Vector2(s.radius, -hh), Vector2(s.radius, hh), Vector2(-s.radius, hh)])
	else:
		return local
	var out := PackedVector2Array()
	var xf := cs.global_transform
	for p in local:
		out.append(xf * p)
	return out
