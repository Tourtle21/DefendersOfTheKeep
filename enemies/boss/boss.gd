extends CharacterBody2D
class_name Boss
## A sector boss. One script, many bosses: size, colour, health and attack mix come
## from setup(). It sleeps until a player comes near, then cycles telegraphed attacks
## (slam ring, charge, summon). Below half health it enrages. Dying unlocks the next
## sector (see world/sector_manager.gd). Implements the same hit API as normal
## enemies (spell_damage, apply_slow, push) so every weapon works on it.

signal defeated(boss)

var boss_name := "Boss"
var sector_id := ""
var max_health := 60.0
var health := 60.0
var speed := 28.0
var color := Color(0.8, 0.5, 0.2)
var body_radius := 22.0
var attacks: Array = ["slam", "charge", "summon"]
var gold_drop := 12
var wake_distance := 240.0
var wake_wave := 3                 # stays asleep until this wave has started, so a run cannot be ended by wandering off
var _warned := false
var add_scene := "res://enemies/blobbert/blobbert.tscn"

var hit_radius := 22.0          # read by WeaponUtil so big targets are easy to hit
var slow_mult := 1.0
var slow_time := 0.0
var dead := false
var awake := false
var enraged := false
var is_taking_damage := false
var armor := 0.0
var resist := {}               # element -> multiplier (set per boss in sector_manager)

var _state := "idle"            # idle, chase, windup, charging
var _timer := 1.5
var _attack := ""
var _windup := 0.0
var _windup_total := 1.0
var _dir := Vector2.DOWN
var _hit_cd := 0.0
var _flash := 0.0
var _intro := 0.0
var _player
var _nav: NavigationAgent2D
var _nav_t := 0.0
var _unstick := Unstick.new()

func setup(p: Dictionary) -> void:
	for k in p:
		set(k, p[k])
	health = max_health
	hit_radius = body_radius

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	add_to_group("net")
	collision_layer = 2
	collision_mask = 1 | 4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius * 0.8
	shape.shape = circle
	add_child(shape)
	z_index = 3
	_nav = NavigationAgent2D.new()
	_nav.path_desired_distance = 8.0
	_nav.target_desired_distance = 12.0
	add_child(_nav)

## Direction toward the player along the navigation path (straight if there is none).
func _path_dir(to_player: Vector2, delta: float) -> Vector2:
	_nav_t -= delta
	if _nav_t <= 0.0:
		_nav_t = 0.25
		_nav.target_position = _player.global_position
	var next := _nav.get_next_path_position()
	if next.distance_to(global_position) < 3.0:
		return to_player.normalized()
	return (next - global_position).normalized()

# ---------- hit API shared with normal enemies ----------

func take_damage(_origin: Vector2) -> void:      # legacy sword/pickaxe hitboxes
	if is_taking_damage:
		return
	is_taking_damage = true              # the sword hitbox hits every frame it overlaps: one hit per swing window instead
	get_tree().create_timer(0.45).timeout.connect(func(): is_taking_damage = false)
	spell_damage(1.0)

func spell_damage(amount: float, element := "", _aoe := false) -> void:
	if dead:
		return
	var raw := amount
	if armor > 0.0 and element != "pierce":
		amount = maxf(amount - armor * (0.5 if element == "crush" else 1.0), amount * 0.25)
	if element != "" and resist.has(element):
		amount *= resist[element]
	var tint := Color.WHITE
	if amount < raw * 0.6:
		tint = Color(0.6, 0.65, 0.8)
	elif amount > raw * 1.3:
		tint = Color(1.0, 0.5, 0.15)
	DamageNumber.spawn(Game.world, global_position + Vector2(0, -body_radius - 10.0), amount, amount >= 4.0 or tint.g < 0.6, tint)
	health -= amount
	_flash = 0.15
	if !enraged and health <= max_health * 0.5:
		enraged = true
		speed *= 1.3
		Game.announce.emit("%s is enraged!" % boss_name)
	if health <= 0.0:
		_die()

func apply_slow(mult: float, time: float) -> void:
	slow_mult = max(0.5, mult)          # bosses can be slowed but never fully stunned
	slow_time = max(slow_time, min(time, 1.5))

func push(vel: Vector2, _time: float) -> void:
	velocity += vel * 0.12              # heavy: barely knocked back

# ---------- behaviour ----------

func _physics_process(delta: float) -> void:
	if dead:
		return
	_hit_cd = max(0.0, _hit_cd - delta)
	_flash = max(0.0, _flash - delta)
	if slow_time > 0.0:
		slow_time -= delta
		if slow_time <= 0.0:
			slow_mult = 1.0
	_player = null
	for pl in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(pl) and !pl.get("downed") and (_player == null or pl.global_position.distance_to(global_position) < _player.global_position.distance_to(global_position)):
			_player = pl
	if _player == null:
		return
	var to_player: Vector2 = _player.global_position - global_position
	if !awake:
		if true:                       # bosses do not sleep: it spawns with the run and comes for you
			awake = true
			var n: int = get_tree().get_nodes_in_group("player").size()
			if n > 1:
				max_health *= 1.0 + 0.6 * (n - 1)       # more players, tougher boss
				health = max_health
			_state = "intro"
			_intro = 1.3
			_timer = 1.0
			_player.shake(4.0, 0.5)
			Game.announce.emit("%s awakens!" % boss_name)
			Sfx.play("boss_roar", 0.02)
			Game.boss_fight.emit(true)
		queue_redraw()
		return
	match _state:
		"intro":
			velocity = Vector2.ZERO
			_intro -= delta
			if _intro <= 0.0:
				_state = "chase"
		"recover":
			velocity = Vector2.ZERO
		"chase":
			var dir := _path_dir(to_player, delta)
			velocity = _unstick.steer(dir, speed * slow_mult, delta)
			move_and_slide()
			_unstick.after_move(self, dir, speed * slow_mult, delta)
			_timer -= delta
			if _timer <= 0.0:
				_begin_attack()
		"windup":
			velocity = Vector2.ZERO
			_windup -= delta
			if _attack == "charge":
				_dir = to_player.normalized()
			if _windup <= 0.0:
				_do_attack()
		"charging":
			velocity = _dir * 230.0 * slow_mult
			move_and_slide()
			_windup -= delta
			_contact_damage(10.0)
			if get_slide_collision_count() > 0 and _windup < 0.45:
				_player.shake(3.0, 0.2)      # crashed into something solid: the charge ends
				_end_attack()
				return
			if _windup <= 0.0:
				_end_attack()
	if _state == "chase":
		_contact_damage(6.0)
	queue_redraw()

func _contact_damage(extra: float) -> void:
	if _hit_cd <= 0.0 and _player != null and _player.global_position.distance_to(global_position) < body_radius + extra:
		_hit_cd = 1.0
		_player.take_damage(global_position)

func _begin_attack() -> void:
	_attack = attacks.pick_random()
	_state = "windup"
	_windup_total = 0.9 if !enraged else 0.65
	_windup = _windup_total
	if _attack == "charge":
		_dir = (_player.global_position - global_position).normalized()

func _do_attack() -> void:
	match _attack:
		"slam":
			var r := body_radius * (2.6 if !enraged else 3.2)
			WeaponFx.spawn(get_parent(), "ring", global_position, color.lightened(0.3), {"radius": r, "life": 0.35})
			if _player != null and _player.global_position.distance_to(global_position) <= r:
				_player.take_damage(global_position)
			_player.shake(4.0, 0.25)
			_end_attack()
		"charge":
			_state = "charging"
			_windup = 0.55
		"summon":
			_summon()
			_end_attack()
		"volley":
			for i in (8 if !enraged else 12):
				EnemyProjectile.fire(get_parent(), global_position, Vector2.from_angle(i * TAU / (8.0 if !enraged else 12.0) + randf() * 0.15), 105.0)
			_end_attack()
		"quake":
			_quake()
		_:
			_end_attack()

func _quake() -> void:
	_state = "recover"
	for i in 3:
		var r := body_radius * (1.8 + 1.1 * i)
		WeaponFx.spawn(get_parent(), "ring", global_position, color.lightened(0.2), {"radius": r, "life": 0.3})
		if _player != null:
			var d: float = _player.global_position.distance_to(global_position)
			if d >= r - 12.0 and d <= r + 12.0:
				_player.take_damage(global_position)
		_player.shake(3.0, 0.15)
		await get_tree().create_timer(0.35).timeout
		if dead:
			return
	_end_attack()

func _summon() -> void:
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and !(e is Boss):
			alive += 1
	if alive > 8:
		return
	var scene: PackedScene = load(add_scene)
	for i in (3 if !enraged else 4):
		var add = scene.instantiate()
		add.level = 1
		add.position = global_position + Vector2.from_angle(randf() * TAU) * (body_radius + 20.0)
		get_parent().add_child(add)        # the Enemies-style parent expects the world above it

func _end_attack() -> void:
	_state = "chase"
	_timer = 2.4 if !enraged else 1.5

func _die() -> void:
	if dead:
		return
	dead = true
	Game.run_stats.bosses += 1
	var world := get_parent().get_parent() if get_parent().name == "Enemies" else get_parent()
	GoldCoin.spawn(world, global_position, gold_drop)
	# a boss always drops both a card chest and a weapon chest
	for i in 2:
		if i == 1 and Game.SECTOR_WEAPONS.has(sector_id) and Game.weapon_unlocked(Game.SECTOR_WEAPONS[sector_id]):
			# the sector's own weapon, guaranteed, instead of a random weapon chest
			var pick = load("res://collectables/collectable.tscn").instantiate()
			pick.item_type = Game.SECTOR_WEAPONS[sector_id]
			pick.position = global_position + Vector2(18, 26)
			world.add_child.call_deferred(pick)
			continue
		var chest := Chest.new()
		chest.kind = "card" if i == 0 else "weapon"
		chest.position = global_position + Vector2(-18 + 36 * i, 26)
		world.add_child.call_deferred(chest)
	if _player != null:
		_player.shake(6.0, 0.5)
	WeaponFx.spawn(world, "ring", global_position, color, {"radius": 90.0, "life": 0.7})
	Game.announce.emit("%s defeated!" % boss_name)
	Game.boss_fight.emit(false)
	defeated.emit(self)
	queue_free()

# ---------- looks ----------

func _draw() -> void:
	var c := color
	if enraged:
		c = c.lerp(Color(1, 0.2, 0.15), 0.4)
	if _flash > 0.0:
		c = c.lerp(Color.WHITE, 0.7)
	if !awake:
		c = c.darkened(0.35)
	var r := body_radius
	draw_circle(Vector2(0, r * 0.7), r * 0.9, Color(0, 0, 0, 0.25))             # shadow
	draw_circle(Vector2.ZERO, r + 2.0, Color.BLACK)
	draw_circle(Vector2.ZERO, r, c)
	draw_circle(Vector2(-r * 0.3, -r * 0.35), r * 0.45, c.lightened(0.25))
	# face
	var eye := Color(1, 0.9, 0.3) if awake else Color(0.3, 0.3, 0.3)
	draw_circle(Vector2(-r * 0.35, -r * 0.1), r * 0.16, eye)
	draw_circle(Vector2(r * 0.35, -r * 0.1), r * 0.16, eye)
	draw_line(Vector2(-r * 0.35, r * 0.35), Vector2(r * 0.35, r * 0.35), Color.BLACK, 2.0)
	# crown spikes
	for i in 5:
		var x := -r * 0.6 + i * r * 0.3
		draw_colored_polygon(PackedVector2Array([Vector2(x - 3, -r + 1), Vector2(x, -r - 8), Vector2(x + 3, -r + 1)]), Color("e8c040"))
	# telegraphs
	if _state == "intro":
		draw_arc(Vector2.ZERO, r * (1.5 + 3.0 * (1.0 - _intro / 1.3)), 0, TAU, 40, Color(1, 0.9, 0.5, _intro / 1.3), 3.0)
	if _state == "windup":
		var t := 1.0 - _windup / _windup_total
		if _attack == "slam":
			var rr := r * (2.6 if !enraged else 3.2)
			draw_arc(Vector2.ZERO, rr, 0, TAU, 40, Color(1, 0.3, 0.2, 0.9), 2.0)
			draw_circle(Vector2.ZERO, rr * t, Color(1, 0.3, 0.2, 0.2))
		elif _attack == "charge":
			draw_line(Vector2.ZERO, _dir * 140.0, Color(1, 0.3, 0.2, 0.5 + 0.4 * t), 4.0 + 6.0 * t)
		elif _attack == "summon":
			draw_arc(Vector2.ZERO, r + 12.0, 0, TAU * t, 24, Color(0.7, 0.4, 1.0), 3.0)
		elif _attack == "volley":
			for i in 8:
				var dv := Vector2.from_angle(i * TAU / 8.0)
				draw_line(dv * (r + 4.0), dv * (r + 14.0 + 16.0 * t), Color(0.6, 1.0, 0.3, 0.9), 2.0)
		elif _attack == "quake":
			draw_arc(Vector2.ZERO, r * 1.8, 0, TAU, 32, Color(1.0, 0.6, 0.2, 0.5 + 0.4 * t), 2.0)
			draw_arc(Vector2.ZERO, r * 4.0, 0, TAU, 40, Color(1.0, 0.6, 0.2, 0.25), 1.0)
	# weakness pips next to the name: filled = weak to it, ring = resists it
	if awake:
		var colors := {"fire": Color(1.0, 0.5, 0.15), "ice": Color(0.5, 0.9, 1.0), "poison": Color(0.55, 0.95, 0.3), "earth": Color(0.85, 0.7, 0.4), "pierce": Color(0.8, 0.5, 1.0)}
		var px := 38.0
		for el in resist:
			if colors.has(el):
				if resist[el] > 1.0:
					draw_circle(Vector2(px, -r - 31.0), 3.0, colors[el])
				else:
					draw_arc(Vector2(px, -r - 31.0), 2.8, 0, TAU, 10, colors[el], 1.2)
				px += 8.0
		if armor > 0.0:
			draw_rect(Rect2(px - 3, -r - 34.0, 6, 6), Color(0.75, 0.75, 0.8))
	# health bar
	if awake:
		var w := 70.0
		var bar := Rect2(-w / 2.0, -r - 22.0, w, 6.0)
		draw_rect(bar.grow(1.5), Color.BLACK)
		draw_rect(bar, Color(0.25, 0.05, 0.05))
		draw_rect(Rect2(bar.position, Vector2(w * clamp(health / max_health, 0.0, 1.0), 6.0)), Color(0.9, 0.2, 0.15))
		draw_string(ThemeDB.fallback_font, Vector2(-w / 2.0, -r - 28.0), boss_name, HORIZONTAL_ALIGNMENT_LEFT, w * 1.6, 9, Color.WHITE)
