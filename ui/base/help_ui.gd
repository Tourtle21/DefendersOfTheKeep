extends CanvasLayer
## Controls cheat sheet. Shown for a few seconds at the start of a run; press H to toggle.

var panel: Control

const TEXT := """DEFENDERS OF THE KEEP        (H to hide / show this)

MOVE: WASD          INTERACT: E (pick up, tower, chest, Forge)
SWITCH WEAPON: Q          PAUSE / OPTIONS: P

OUTSIDE THE KEEP
  Left click ........ basic attack
  Right click ....... weapon ability (tier 2)  } tap = cast at the cursor
  Shift ............. dash attack          } hold 1 second = show aim
  Space ............. ultimate (tier 3)    } release = cast, Esc = cancel
  Weapon tiers go to 6: fuse different weapons, or combine two identical copies (same tier) at the Forge.
  Cards, buildings and weapons can come in higher tiers and gain a twist at tier 2, 4 and 6 that changes how they work.
  (Hammer slam, Lance charge and Bulwark brace: hold to charge, release to fire)

INSIDE A TOWER (the keep)
  Drag a card onto the map: it flies from the crystal, so lead moving enemies.
  Spell cards cost mana. Build cards (walls, traps, sentries, totems) cost materials
  and stay on the map; two of the same kind and tier placed side by side merge into the next tier.
  Your hand is drawn from two decks: 3 spell slots and 2 build slots.
  Mana and card draws only run while someone is inside. Spend resources on upgrades.
  The wide view and the radar (top right) show enemies, bosses and chests.

COUNTERS (every enemy has a weakness)
  Armored (brutes, golems, crystal guards): weak hits barely hurt, use heavy hits or piercing.
  Fast (runners): slow them (frost, traps, spikes) and they take extra damage.
  Swarms (scarabs, splitters and their minis, marked with a cluster of dots): area attacks
  (fireball, zones, cleaves, pulses, spike traps) deal +50%.
  Imps: frost imps burn, ember imps freeze; bog lurkers regrow, so burst them or use fire.
  Pips over enemies: filled dot = weak to that element, ring = resists it, grey square = armored,
  plus = fears slows. Orange numbers = weak to it, grey = resisted. Bosses have weaknesses too.

CONTROLLER
  Outside: left stick walk, right stick aim, RT attack, X ability, LT dash, Y ultimate, LB / RB switch weapon, A pick up / enter tower / interact,
  Start pause.
  In a tower: A leave, right stick moves the cursor, LB / RB pick a card, RT place it (or jump to a lit tower),
  B put it back.   Menus: d-pad move, A press, B back, LB / RB switch tabs.

THE LOOP
  Gather stone and sticks, kill enemies for gold, open chests (cards or weapons).
  Resource generators (one per biome) make that biome's resource: E to activate with
  carried gold, collect everything stored, or upgrade (5 levels).
  Walk into a tower to deposit what you carry. The Forge (anvil in the yard)
  fuses two weapons of the same tier into a new one for gold.
  Defeat each sector's boss to open the next sector. Beat all six, then the final boss.
  If you fall you are out for 30 seconds, then back at the keep. The run ends when the keep falls or the crystal is stolen: you earn Shards and reward cards (if you got past the first wave)."""

func _ready() -> void:
	layer = 6          # under the menus (forge 8, run end 20, collection/codex/skills 22)
	panel = Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center)
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(22)
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	var label := Label.new()
	label.text = TEXT
	label.add_theme_font_size_override("font_size", 15)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	await get_tree().create_timer(9.0).timeout
	if is_inside_tree():
		panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and !event.echo and event.physical_keycode == KEY_H:
		panel.visible = !panel.visible
