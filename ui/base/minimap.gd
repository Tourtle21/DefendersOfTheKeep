extends Control
## Radar for the keep: the whole hex of sectors around the keep, with enemies,
## bosses, chests and the player as dots. Shown while someone is in the keep.

const SM := preload("res://world/sector_manager.gd")
const RANGE := 1150.0           # world units from the keep to the edge of the map

func _init() -> void:
	custom_minimum_size = Vector2(220, 220)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()

func _map(p: Vector2) -> Vector2:
	return size / 2.0 + p / RANGE * (size.x / 2.0)

func _draw() -> void:
	var half := size.x / 2.0
	draw_circle(size / 2.0, half + 2.0, Color(0, 0, 0, 0.55))
	# the six sectors as wedges; locked ones are grey
	for id in Game.SECTOR_ANGLES:
		var c: float = Game.SECTOR_ANGLES[id]
		var unlocked: bool = id in Game.sectors_unlocked
		var col := Color(0.35, 0.8, 0.3, 0.55)
		if id != "s":
			col = SM.SECTORS[id].ground
			col.a = 0.7
		if !unlocked:
			col = Color(0.4, 0.4, 0.4, 0.35)
		var pts := PackedVector2Array([size / 2.0])
		for i in 13:
			var a := deg_to_rad(c - 30.0 + 60.0 * i / 12.0)
			pts.append(size / 2.0 + Vector2.from_angle(a) * half)
		draw_colored_polygon(pts, col)
		var label_pos := size / 2.0 + Vector2.from_angle(deg_to_rad(c)) * half * 0.62
		draw_circle(label_pos, 2.0, Color(1, 1, 1, 0.5) if unlocked else Color(0, 0, 0, 0.5))
	draw_arc(size / 2.0, half, 0, TAU, 48, Color(1, 1, 1, 0.6), 1.5)
	draw_circle(size / 2.0, 4.0, Color(0.7, 0.4, 1.0))                  # the keep
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and !e.is_in_group("boss") and !(e.has_method("is_queued_for_deletion") and e.is_queued_for_deletion()):
			draw_circle(_map(e.global_position), 1.6, Color(1.0, 0.25, 0.2))
	for b in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(b):
			var bp := _map(b.global_position)
			draw_circle(bp, 5.0, Color.BLACK)
			draw_circle(bp, 3.8, Color(0.9, 0.3, 1.0) if b.awake else Color(0.6, 0.35, 0.7))
	for c in get_tree().get_nodes_in_group("chest"):
		var cp := _map(c.global_position)
		var col2 := Color(0.5, 0.7, 1.0) if c.kind == "weapon" else Color(1.0, 0.85, 0.3)
		draw_rect(Rect2(cp - Vector2(2.5, 2.5), Vector2(5, 5)), col2)
	# resource generators in open sectors (ringed when there is something to collect), and structures
	for g in get_tree().get_nodes_in_group("generator"):
		if !is_instance_valid(g) or !g.is_visible_in_tree():
			continue
		var gp := _map(g.global_position)
		var gc: Color = g.color if g.level > 0 else Color(0.6, 0.6, 0.65)
		draw_colored_polygon(PackedVector2Array([gp + Vector2(0, -3.5), gp + Vector2(3.5, 0), gp + Vector2(0, 3.5), gp + Vector2(-3.5, 0)]), gc)
		if g.stored > 0:
			draw_arc(gp, 5.5, 0, TAU, 12, Color(1, 1, 0.6, 0.9), 1.2)
	for st in get_tree().get_nodes_in_group("structure"):
		if is_instance_valid(st):
			draw_circle(_map(st.global_position), 1.3, Color(0.5, 1.0, 0.55))
	for c in get_tree().get_nodes_in_group("critter"):      # the rainbow sheep
		if is_instance_valid(c):
			draw_circle(_map(c.global_position), 3.2, Color.from_hsv(fmod(Time.get_ticks_msec() / 800.0, 1.0), 0.8, 1.0))
	if Game.crystal_away():             # the crystal (and where the thief is heading)
		var cp := _map(Game.crystal_pos)
		var cc := Color(1.0, 0.35, 0.3) if Game.crystal_state == "carried" else Color(0.85, 0.55, 1.0)
		draw_colored_polygon(PackedVector2Array([cp + Vector2(0, -5), cp + Vector2(4, 0), cp + Vector2(0, 5), cp + Vector2(-4, 0)]), cc)
		if Game.crystal_state == "carried":
			var xp := _map(Game.crystal_exit)
			draw_line(xp + Vector2(-3, -3), xp + Vector2(3, 3), cc, 1.5)
			draw_line(xp + Vector2(-3, 3), xp + Vector2(3, -3), cc, 1.5)
	for p in get_tree().get_nodes_in_group("player"):
		draw_circle(_map(p.global_position), 3.0, Color.WHITE)
