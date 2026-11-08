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

func entry() -> String:
	return Game.make_weapon_entry(item_type, bonus, twist)

func _input(event: InputEvent) -> void:
	if hovering and event.is_action_pressed("interact"):
		if item_info.items[item_type]["type"] == "resource":
			# resources are carried and pooled in the keep (see core/game.gd)
			Game.pick_up_resource(item_type)
			queue_free()
			return
		var winfo: Dictionary = Game.weapon_info(entry())
		if player.get_parent().get_node("Hud").equip_item(winfo):
			if (item_info.items[item_type]["type"] == "item" and player.get_parent() != null):
				player.equip_item(winfo)
			queue_free()
		else:
			var info: Dictionary = winfo
			if info["type"] == "item":
				# every slot is full: swap with the active weapon and drop the old one here
				var old = player.get_parent().get_node("Hud").swap_active(info)
				if old != null:
					player.equip_item(info)
					var old_entry: String = old.get("entry", "")
					if old_entry == "":
						var found = item_info.items.find_key(old)
						old_entry = found if found != null else ""
					if old_entry != "":
						var pick = load("res://collectables/collectable.tscn").instantiate()
						pick.item_type = Game.entry_id(old_entry)
						pick.bonus = Game.weapon_bonus(old_entry)
						pick.twist = Game.entry_twist(old_entry)
						pick.fixed = true
						pick.position = player.global_position + Vector2(0, 18)
						player.get_parent().add_child.call_deferred(pick)
					queue_free()
					return
			$AnimationPlayer.play("invalid")
			
## Pickup by a co-op avatar (the local keyboard path is _input above).
func pickup_by(pl) -> bool:
	var info = item_info.items[item_type]
	if info["type"] == "resource":
		Game.pick_up_resource(item_type, pl)
	else:
		Net.give_weapon(pl, entry())
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
	var tw := ("\n* %s: %s" % [Game.TWISTS[twist][0], Game.TWISTS[twist][1]]) if twist != "" and Game.TWISTS.has(twist) else ""
	_kit = "%s (Tier %d)%s\nLeft: %s\nRight: %s\nShift: %s\nSpace: %s\nEnter: take (swaps if full)" % [
		Fusion.display_name(item_type), tier, tw, kit[0], right, kit[2], ult]
	return _kit

func _draw() -> void:
	if !hovering or item_info.items[item_type]["type"] != "item":
		return
	var lines := kit_text().split("\n")
	var box := Rect2(-46, -62, 92, 8 + lines.size() * 8)
	draw_rect(box, Color(0, 0, 0, 0.8))
	for i in lines.size():
		draw_string(ThemeDB.fallback_font, Vector2(-43, -55 + i * 8), lines[i], HORIZONTAL_ALIGNMENT_LEFT, 88, 6, Color(1, 0.95, 0.7) if i == 0 else Color(0.85, 0.9, 1.0))

func _on_body_entered(body: Node2D) -> void:
	hovering = true
	player = body
	modulate = Color(1.5, 1.5, 0.5)
	queue_redraw()

func _on_body_exited(body: Node2D) -> void:
	hovering = false
	modulate = Color.WHITE
	queue_redraw()
