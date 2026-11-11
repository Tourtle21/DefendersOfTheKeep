extends Area2D

var player: Node2D
var hovering = false
var _kit := ""

const KIT_FALLBACK := {
	"sword": ["Slash", "Whirlwind", "Slash Dash", "Blade Tempest"],
	"pickaxe": ["Mine", "Seismic Strike", "Dash-Mine", "Earthquake"],
}

const NET_SKIP := ["hovering"]
var bonus := 0                       # this weapon copy's tier bonus and twist (rolled when it appears)
var twist := ""
var fixed := false                   # a dropped copy keeps exactly what it had; a new one rolls
@export var item_type: String
@export var item_info: Resource

func _ready() -> void:
	add_to_group("pickup")
	add_to_group("net")
	$Sprite2D.texture = load(item_info.items[item_type]["texture"])
	$Sprite2D.region_enabled = true
	$Sprite2D.region_rect = Rect2(Vector2.ZERO, Vector2(32, 32))
	$Sprite2D.visible = true
	if item_info.items[item_type]["type"] == "item" and !fixed and bonus == 0 and twist == "":
		var e := Game.roll_weapon_entry(item_type)             # sometimes a higher tier or with a twist
		bonus = Game.weapon_bonus(e)
		twist = Game.entry_twist(e)
	if item_info.items[item_type]["type"] == "item" and owner == null:
		_life = WEAPON_LIFETIME                    # made while the game runs (not placed in the scene): it will vanish

## A weapon that lands on the ground (dropped, from a chest, a boss...) disappears if nobody picks it up, like coins
## do: it blinks for the last few seconds. The one placed in the scene at the start never vanishes.
const WEAPON_LIFETIME := 45.0
const BLINK_FROM := 6.0
var _life := -1.0

func _tick_life(delta: float) -> void:
	if _life < 0.0 or Rep.is_puppet(self):
		return
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	$Sprite2D.visible = !(_life < BLINK_FROM and int(Time.get_ticks_msec() / 150.0) % 2 == 0)

func entry() -> String:
	return Game.make_weapon_entry(item_type, bonus, twist)

## A weapon you have not unlocked cannot be picked up.
func _locked() -> bool:
	return item_info.items[item_type]["type"] == "item" and !Game.weapon_unlocked(item_type) and !Game.weapon_known(item_type)

## Pickup by any player (Net.interact_objects): player 1 too.
func pickup_by(pl) -> bool:
	if _locked():
		Game.announce.emit("%s is locked. Draw it at the end of a run to unlock it." % Fusion.display_name(item_type))
		$AnimationPlayer.play("invalid")
		return false
	var info = item_info.items[item_type]
	if info["type"] == "resource":
		Game.pick_up_resource(item_type, pl)
	else:
		Net.pickup_weapon(pl, entry())
	queue_free()
	return true

## What this weapon does, shown while you stand on it.
func kit_text() -> String:
	if _kit != "":
		return _kit
	var info = item_info.items[item_type]
	if info["type"] != "item":
		return ""
	var kit: Array = KIT_FALLBACK.get(item_type, [])
	if kit.is_empty():
		var inst = load(info["path"]).instantiate()
		kit = [inst.attack_name, inst.ability_name, inst.dash_name, inst.ultimate_name]
		inst.free()
	var tier: int = Game.weapon_tier_of(entry())
	var right: String = str(kit[1]) if tier >= 2 else "%s (tier 2)" % kit[1]
	var ult: String = str(kit[3]) if tier >= 3 else "%s (tier 3)" % kit[3]
	var tw := ("\n+ Added %s: %s" % [Game.TWISTS[twist][0], Game.TWISTS[twist][1]]) if twist != "" and Game.TWISTS.has(twist) else ""
	_kit = "%s (Tier %d)%s\nLeft: %s\nRight: %s\nShift: %s\nSpace: %s\nE: take (swaps if full)" % [
		Fusion.display_name(item_type) + " [" + Game.rarity_name(Game.weapon_rarity(item_type)) + "]", tier, tw, kit[0], right, kit[2], ult]
	return _kit

## The ring under a rare weapon: its colour is the weapon's rarity (fused weapons are rarer, legendary ones glow rainbow).
func _rarity() -> int:
	return Game.weapon_rarity(item_type) if item_info.items[item_type]["type"] == "item" else 0

func _process(delta: float) -> void:
	_tick_life(delta)
	if _rarity() >= 1:
		queue_redraw()

func _draw() -> void:
	if item_info.items[item_type]["type"] == "item" and _rarity() >= 1:
		var r := _rarity()
		var t := Time.get_ticks_msec() / 1000.0
		var col: Color = Color.from_hsv(fposmod(t * 0.6, 1.0), 0.55, 1.0) if r >= 6 else Game.rarity_color(r)
		var pulse := 0.5 + 0.5 * sin(t * 3.0)
		draw_arc(Vector2.ZERO, 11.0 + pulse, 0, TAU, 28, Color(col, 0.55 + 0.3 * pulse), 1.3 + 0.25 * r)
		draw_circle(Vector2.ZERO, 9.0, Color(col, 0.10 + 0.03 * r))
	if !hovering or item_info.items[item_type]["type"] != "item":
		return
	var lines := kit_text().split("\n")
	var box := Rect2(-46, -62, 92, 8 + lines.size() * 8)
	draw_rect(box, Color(0, 0, 0, 0.8))
	for i in lines.size():
		draw_string(ThemeDB.fallback_font, Vector2(-43, -55 + i * 8), lines[i], HORIZONTAL_ALIGNMENT_LEFT, 88, 6, Color(1, 0.95, 0.7) if i == 0 else Color(0.85, 0.9, 1.0))

func _on_body_entered(body: Node2D) -> void:
	if body.get("remote_controlled"):
		return                    # a co-op avatar or split-screen player 2 to 4 walking past must not make player 1's button pick this up
	hovering = true
	player = body
	modulate = Color(1.5, 1.5, 0.5)
	queue_redraw()

func _on_body_exited(body: Node2D) -> void:
	if Game.has_local_player(self):
		return
	hovering = false
	modulate = Color.WHITE
	queue_redraw()
