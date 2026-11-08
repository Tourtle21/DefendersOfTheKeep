extends Node
## Autoload "Game": the one place that holds shared run state (pooled mana and
## resources, the card hand, upgrades). Kept in one spot, and spells go through
## cast(), so this can later become host-authoritative for multiplayer.

signal mana_changed
signal resources_changed
signal hand_changed
signal deck_changed
signal draft_started(options: Array)
signal run_ended(summary: Dictionary)
signal announce(text: String)
signal sector_unlocked(id: String)
signal keep_changed
signal ui_scale_changed
signal player_hurt
signal run_started
signal boss_fight(active: bool)
signal base_mode_changed(active: bool)
signal base_players_changed
signal nav_changed                # something solid appeared or went away: rebuild the navigation (world/nav_builder.gd)
signal net_synced                # a client received new host game state (Rep)

const HAND_SIZE := 5
const SPELL_SLOTS := 3        # the hand is drawn from two decks: 3 spell slots + 2 build slots
const BUILD_SLOTS := 2
const MAX_LEVEL := 6          # six tiers, one per place on the map
const DRAFT_SIZE := 3

# kind is handled in cards/spell.gd. "res" is a cost in pooled resources.
const CARDS := {
	"fireball": {
		"element": "fire",
		"name": "Fireball", "mana": 25, "res": {}, "kind": "fireball",
		"radius": 45.0, "damage": 5.0, "speed": 150.0,
		"desc": "Slow shot that blasts an area. Lead your target.",
	},
	"frost_ring": {
		"element": "ice",
		"name": "Frost Ring", "mana": 15, "res": {}, "kind": "frost_ring",
		"radius": 55.0, "duration": 6.0, "slow": 0.35, "speed": 220.0,
		"desc": "Slows enemies in the ring.",
	},
	"rejuvenation": {
		"name": "Rejuvenation", "mana": 20, "res": {"stick": 1}, "kind": "rejuvenation",
		"radius": 40.0, "duration": 8.0, "heal_per_sec": 14.0, "speed": 200.0,
		"desc": "Heals players standing inside.",
	},
	"gold_magnet": {
		"name": "Gold Magnet", "mana": 15, "res": {}, "kind": "magnet",
		"radius": 60.0, "duration": 0.5, "speed": 260.0,
		"desc": "Collects gold in the area into the keep.",
	},
	"sandstorm": {
		"element": "earth",
		"name": "Sandstorm", "mana": 20, "res": {"iron": 1}, "kind": "zone", "art": "sandstorm",
		"radius": 55.0, "duration": 6.0, "dps": 2.0, "slow": 0.5, "speed": 220.0, "color": Color(0.92, 0.75, 0.4),
		"desc": "Lingering storm: hurts and slows.",
	},
	"blizzard": {
		"element": "ice",
		"name": "Blizzard", "mana": 25, "res": {"frost": 1}, "kind": "zone", "art": "blizzard",
		"radius": 60.0, "duration": 5.0, "dps": 1.0, "slow": 0.2, "speed": 220.0, "color": Color(0.8, 0.95, 1.0),
		"desc": "Squall that nearly freezes enemies.",
	},
	"lava_pool": {
		"element": "fire",
		"name": "Lava Pool", "mana": 25, "res": {"ember": 1}, "kind": "zone", "art": "lava_pool",
		"radius": 45.0, "duration": 7.0, "dps": 6.0, "slow": 0.85, "speed": 200.0, "color": Color(1.0, 0.4, 0.1),
		"desc": "Burning pool, heavy damage over time.",
	},
	"poison_cloud": {
		"element": "poison",
		"name": "Poison Cloud", "mana": 20, "res": {"moss": 1}, "kind": "zone", "art": "poison_cloud",
		"radius": 62.0, "duration": 8.0, "dps": 3.0, "slow": 0.7, "speed": 210.0, "color": Color(0.5, 0.9, 0.3),
		"desc": "Wide toxic cloud.",
	},
	"crystal_spikes": {
		"element": "pierce",
		"name": "Crystal Spikes", "mana": 25, "res": {"gem": 1}, "kind": "spikes", "art": "crystal_spikes",
		"radius": 24.0, "damage": 5.0, "duration": 1.2, "speed": 200.0, "color": Color(0.8, 0.6, 1.0),
		"desc": "Three spikes erupt in a triangle.",
	},
	"aegis": {
		"name": "Aegis Ward", "mana": 20, "res": {"stone": 1}, "kind": "aegis",
		"radius": 40.0, "duration": 8.0, "speed": 240.0,
		"desc": "Blocks all damage inside.",
	},
	"barricade": {
		"name": "Barricade", "mana": 0, "res": {"stone": 3}, "kind": "build", "build": "barricade", "art": "barricade",
		"radius": 16.0, "hp": 24.0, "duration": 0.0, "speed": 260.0,
		"desc": "Solid wall. Enemies must chew through it.",
	},
	"spike_trap": {
		"name": "Spike Trap", "mana": 0, "res": {"stick": 3}, "kind": "build", "build": "spike_trap", "art": "spike_trap",
		"radius": 22.0, "damage": 2.0, "uses": 10, "slow": 0.6, "duration": 0.0, "speed": 260.0,
		"desc": "Hurts and slows whoever walks over it.",
	},
	"sentry": {
		"name": "Sentry", "mana": 0, "res": {"stone": 2, "stick": 2, "gold": 3}, "kind": "build", "build": "sentry", "art": "sentry",
		"radius": 12.0, "range": 110.0, "damage": 1.5, "duration": 45.0, "speed": 260.0,
		"desc": "Shoots the nearest enemy for a while.",
	},
	"mender": {
		"name": "Mender Totem", "mana": 0, "res": {"stone": 2, "gold": 2}, "kind": "build", "build": "mender", "art": "mender",
		"radius": 45.0, "heal_per_sec": 6.0, "duration": 60.0, "speed": 260.0,
		"desc": "Slowly heals players nearby.",
	},
	"iron_wall": {
		"name": "Iron Bulwark", "mana": 0, "res": {"iron": 2, "stone": 1}, "kind": "build", "build": "barricade", "art": "iron_wall",
		"radius": 18.0, "hp": 80.0, "duration": 0.0, "speed": 260.0, "color": Color(0.75, 0.78, 0.85),
		"desc": "Heavy iron wall. Very hard to break.",
	},
	"frost_totem": {
		"element": "ice",
		"name": "Frost Totem", "mana": 0, "res": {"frost": 2}, "kind": "build", "build": "totem", "art": "frost_totem",
		"radius": 55.0, "slow": 0.4, "duration": 50.0, "speed": 260.0, "color": Color(0.6, 0.85, 1.0),
		"desc": "Chills every enemy in range.",
	},
	"ember_turret": {
		"element": "fire",
		"name": "Ember Turret", "mana": 0, "res": {"ember": 2, "stick": 1}, "kind": "build", "build": "sentry", "art": "ember_turret",
		"radius": 12.0, "range": 120.0, "damage": 3.0, "interval": 1.0, "burst": 2.5, "duration": 40.0, "speed": 260.0, "color": Color(1.0, 0.45, 0.15),
		"desc": "Slow, hard-hitting fire bolts with a blast.",
	},
	"thorn_hedge": {
		"name": "Thorn Hedge", "mana": 0, "res": {"moss": 3}, "kind": "build", "build": "barricade", "art": "thorn_hedge",
		"radius": 18.0, "hp": 40.0, "thorns": 2.0, "duration": 0.0, "speed": 260.0, "color": Color(0.4, 0.75, 0.3),
		"desc": "Wall that hurts enemies chewing on it.",
	},
	"crystal_pylon": {
		"element": "pierce",
		"name": "Crystal Pylon", "mana": 0, "res": {"gem": 2, "gold": 3}, "kind": "build", "build": "sentry", "art": "crystal_pylon",
		"radius": 12.0, "range": 170.0, "damage": 2.5, "interval": 0.35, "duration": 40.0, "speed": 260.0, "color": Color(0.8, 0.6, 1.0),
		"desc": "Long-range rapid crystal shards.",
	},
	"guards": {
		"name": "Guards", "mana": 30, "res": {"gold": 2}, "kind": "guards",
		"radius": 20.0, "count": 3, "damage": 1.5, "duration": 15.0, "speed": 260.0,
		"desc": "Summons guards that fight nearby enemies.",
	},
	"charm": {
		"name": "Charm", "mana": 35, "res": {"gold": 3}, "kind": "charm",
		"radius": 50.0, "duration": 6.0, "speed": 240.0, "color": Color(0.5, 1.0, 0.7),
		"desc": "Enemies in the area fight for you briefly.",
	},
	"storm_spire": {
		"element": "ice",
		"name": "Storm Spire", "mana": 0, "res": {"iron": 2, "frost": 2}, "kind": "build", "build": "sentry", "art": "storm_spire",
		"radius": 12.0, "range": 130.0, "damage": 1.8, "interval": 0.5, "slow": 0.45, "duration": 45.0, "speed": 260.0, "color": Color(0.7, 0.85, 1.0),
		"desc": "Iron and frost: bolts that chill their target.",
	},
	"magma_wall": {
		"element": "fire",
		"name": "Magma Wall", "mana": 0, "res": {"iron": 2, "ember": 2}, "kind": "build", "build": "barricade", "art": "magma_wall",
		"radius": 18.0, "hp": 70.0, "thorns": 4.0, "duration": 0.0, "speed": 260.0, "color": Color(0.9, 0.4, 0.2),
		"desc": "Iron and ember: tough wall that scorches attackers.",
	},
	"venom_tower": {
		"element": "poison",
		"name": "Venom Tower", "mana": 0, "res": {"moss": 2, "ember": 2}, "kind": "build", "build": "sentry", "art": "venom_tower",
		"radius": 12.0, "range": 115.0, "damage": 1.0, "interval": 0.8, "poison": 4.0, "duration": 45.0, "speed": 260.0, "color": Color(0.55, 0.9, 0.25),
		"desc": "Moss and ember: poisoned shots burn over time.",
	},
	"prism_tower": {
		"name": "Prism Tower", "mana": 0, "res": {"gem": 2, "frost": 2, "ember": 2}, "kind": "build", "build": "sentry", "art": "prism_tower",
		"radius": 12.0, "range": 160.0, "damage": 4.0, "interval": 0.7, "burst": 3.0, "duration": 40.0, "speed": 260.0, "color": Color(1.0, 0.8, 1.0),
		"desc": "Gem, frost and ember: strong shots that splash.",
	},
	"healing_grove": {
		"name": "Healing Grove", "mana": 0, "res": {"moss": 2, "gem": 2}, "kind": "build", "build": "mender", "art": "healing_grove",
		"radius": 60.0, "heal_per_sec": 14.0, "duration": 60.0, "speed": 260.0, "color": Color(0.4, 1.0, 0.6),
		"desc": "Moss and gem: a wide, strong healing field.",
	},
}

const UPGRADES := {
	"max_mana": {"name": "Mana Well", "desc": "+25 max mana", "base": {"stone": 4, "gold": 4}},
	"regen": {"name": "Crystal Focus", "desc": "+1.5 mana per second", "base": {"stick": 4, "gold": 4}},
	"draw": {"name": "Quick Draw", "desc": "Draw cards faster", "base": {"stone": 2, "stick": 2, "gold": 3}},
}

# Variables the host does NOT send to clients (everything else public is synced by Rep).
const NET_SKIP := ["world", "meta", "save_path", "forced_height", "ui_scale", "in_base", "players_in_base", "carried", "card_aim_active"]
var recipe_log: Array = []              # recipes that became known during this end screen (shown to the player)
var crystal_state := "home"             # home, carried (enemy thief), dropped, player (see collectables/crystal/crystal.gd)
var crystal_pos := Vector2.ZERO
var crystal_exit := Vector2.ZERO        # where the thief is running to
var crystal_eta := 0.0                  # seconds until the thief reaches the edge
var world: Node2D                       # set by world.gd
var mana: float = 60.0
var resources := {"stone": 0, "stick": 0, "gold": 0}   # pooled, spent in the keep
var carried := {"stone": 0, "stick": 0, "gold": 0}     # held by explorers until deposited
var hand: Array = []
var deck := {}               # card id -> level, what this run can draw
var draft_active := false
var draft_options: Array = []
const KEEP_BASE := 150.0
var keep_hp := KEEP_BASE

# permanent skill tree bought with Shards (see core/skills.gd); levels saved in meta.skills
func skill_level(id: String) -> int:
	fix_meta()
	return int(meta.skills.get(id, 0))

const SKILL_COST_SCALE := 2.5
const MAX_PENDING := 12            # offers kept between runs until you unlock or convert them

func skill_cost(id: String) -> int:
	return int(round(Skills.TREE[id].cost * (skill_level(id) + 1) * SKILL_COST_SCALE))

func skill_available(id: String) -> bool:
	for r in Skills.TREE[id].req:
		if skill_level(r) < 1:
			return false
	return true

func buy_skill(id: String) -> bool:
	fix_meta()
	if !skill_available(id) or skill_level(id) >= Skills.TREE[id].max or meta.shards < skill_cost(id):
		return false
	meta.shards -= skill_cost(id)
	meta.skills[id] = skill_level(id) + 1
	save_meta()
	return true

## Total bonus of a kind from the skill tree (e.g. "spell_power" = 0.16 at two levels).
func bonus(key: String) -> float:
	var total := 0.0
	for id in Skills.TREE:
		var sk: Dictionary = Skills.TREE[id]
		if sk.key == key:
			total += sk.per * skill_level(id)
	return total

func keep_max() -> float:
	return KEEP_BASE + bonus("keep_hp")
var card_aim_active := false     # a card is selected or being dragged (turret clicks must not fire)
var unlocked_cards: Array = ["fireball", "frost_ring", "barricade", "spike_trap"]

# --- meta progression (saved between runs) ---
# weapons: three Tier 1 weapons are in the chest pool from the start; Shards add the rest
const STARTER_WEAPONS := []             # no weapon is free except the sword and pickaxe; everything else costs Shards
# every weapon must be unlocked once (reward draw or the codex) before it can appear in a run
# same price rule as cards: 16 x realm^1.5 (see unlock_price), by WEAPON_LEVEL
const WEAPON_UNLOCK_COSTS := {"spear": 16, "hammer": 16, "bow": 16, "daggers": 16, "whip": 45, "shield": 45, "staff": 83, "scimitar": 45, "frostglaive": 83, "emberflail": 128, "bogstaff": 179, "crystalwand": 235}
const FUSION_TIER_COSTS := {3: 60, 4: 140}      # tier 2 recipes are known from the start
const STARTER_CARDS := ["fireball", "frost_ring", "barricade", "spike_trap"]
var save_path := "user://save.json"
var meta := {"pending": [], "skills": {}, "card_tiers": {}, "weapons": [], "fusion_tiers": [], "start_weapon": "sword", "shards": 0, "unlocked": ["fireball", "frost_ring", "barricade", "spike_trap"], "best_wave": 0, "recipes_seen": [], "hints_seen": [], "hints_enabled": true}
var run_stats := {"kills": 0, "gold": 0, "waves": 0, "bosses": 0}

# the six sectors around the keep (centre angle in degrees, y down: 90 = south)
const SECTOR_ANGLES := {"s": 90.0, "se": 30.0, "ne": 330.0, "n": 270.0, "nw": 210.0, "sw": 150.0}
var sectors_unlocked: Array = ["s"]
const SECTOR_WEAPONS := {"se": "scimitar", "ne": "frostglaive", "n": "emberflail", "nw": "bogstaff", "sw": "crystalwand"}
const SECTOR_CARDS := {"se": ["sandstorm", "iron_wall"], "ne": ["blizzard", "frost_totem"], "n": ["lava_pool", "ember_turret"], "nw": ["poison_cloud", "thorn_hedge"], "sw": ["crystal_spikes", "crystal_pylon"]}
# build cards that need materials from two or more sectors: available once all are open
const COMBO_CARDS := {
	"storm_spire": ["se", "ne"], "magma_wall": ["se", "n"], "venom_tower": ["nw", "n"],
	"prism_tower": ["sw", "ne", "n"], "healing_grove": ["nw", "sw"],
}
var run_over := false
var upgrade_levels := {}
var players_in_base: Array = []
var _draw_time := 0.0

var in_base: bool:
	get: return players_in_base.size() > 0

var ui_scale := 1.0
var forced_height := 0      # tests: pretend the window has this pixel height

## Scale the whole 2D canvas with the window height so UI stays readable on big or
## high-DPI windows. The player's camera divides its zoom by ui_scale, so the world
## keeps the same framing and only the UI gets bigger.
func _update_ui_scale(px_height := -1) -> void:
	var win := get_window()
	var h: int = px_height if px_height > 0 else (forced_height if forced_height > 0 else win.size.y)
	var k: float = clamp(snappedf(h / 1000.0, 0.25), 1.0, 3.0)
	if !is_equal_approx(k, ui_scale):
		ui_scale = k
		win.content_scale_factor = k
		ui_scale_changed.emit()

func _ready() -> void:
	load_meta()
	_update_ui_scale()
	get_window().size_changed.connect(func(): _update_ui_scale())

func load_meta() -> void:
	if FileAccess.file_exists(save_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if parsed is Dictionary:
			for k in parsed:
				meta[k] = parsed[k]
	for id in STARTER_CARDS:
		if !(id in meta.unlocked):
			meta.unlocked.append(id)
	unlocked_cards = meta.unlocked.duplicate()

func save_meta() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta))

## Remember a fusion recipe once you have previewed or made it (shown in the Forge journal).
func note_recipe(key: String) -> void:
	if !meta.has("recipes_seen"):
		meta["recipes_seen"] = []
	if !(key in meta.recipes_seen):
		meta.recipes_seen.append(key)
		save_meta()

func record_kill() -> void:
	run_stats.kills += 1
	var mk := bonus("mana_kill")
	if mk > 0.0 and mana < max_mana():
		mana = minf(max_mana(), mana + mk)
		mana_changed.emit()

## Can the player pay this from what they are carrying (explorers spend carried loot)?
func carried_afford(cost: Dictionary, who = null) -> bool:
	var table: Dictionary = carried_of(who)
	for type in cost:
		if table.get(type, 0) < cost[type]:
			return false
	return true

## The loot table a player holds: a co-op avatar has its own, the local player uses `carried`.
func carried_of(who = null) -> Dictionary:
	if who != null and who.get("remote_controlled"):
		return who.carried
	return carried

func pay_carried(cost: Dictionary, who = null) -> bool:
	if !carried_afford(cost, who):
		return false
	var table: Dictionary = carried_of(who)
	for type in cost:
		table[type] -= cost[type]
	resources_changed.emit()
	return true

## Shards for this run: waves survived matter most, then kills and gold.
func shards_for_run() -> int:
	# every run pays 6 just for playing (a short first run is about 15: one new card or an upgrade),
	# then waves, kills, gold, bosses and realms opened add the rest
	var base: float = 6.0 + run_stats.waves * 1.5 + run_stats.kills * 0.1 + run_stats.gold / 20.0 + run_stats.bosses * 6.0 + (level_reached() - 1) * 4.0
	return int(base * (1.0 + bonus("shard_bonus")))

func end_run(reason: String) -> void:
	if run_over:
		return
	run_over = true
	var earned := shards_for_run()
	meta.shards += earned
	meta.best_wave = max(meta.best_wave, run_stats.waves)
	meta["best_level"] = maxi(int(meta.get("best_level", 1)), level_reached())
	save_meta()
	run_ended.emit({"reason": reason, "shards": earned, "stats": run_stats.duplicate(), "rewards": make_rewards()})

## Which sector a point belongs to, by its direction from the keep.
func sector_at(pos: Vector2) -> String:
	var a := rad_to_deg(pos.angle())
	var best := "s"
	var best_d := 999.0
	for id in SECTOR_ANGLES:
		var d := absf(wrapf(a - SECTOR_ANGLES[id], -180.0, 180.0))
		if d < best_d:
			best_d = d
			best = id
	return best

## Can the player walk out of the keep circle in this direction (radians)?
var _hit_stop := false

## A brief slow-motion beat on heavy hits.
func hit_stop(sec: float) -> void:
	if _hit_stop or get_tree().paused:
		return
	_hit_stop = true
	Engine.time_scale = 0.08
	await get_tree().create_timer(sec, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stop = false

func damage_keep(amount: float) -> void:
	if run_over:
		return
	keep_hp = max(0.0, keep_hp - amount * maxf(0.2, 1.0 - bonus("fortify")))
	keep_changed.emit()
	if keep_hp <= 0.0:
		end_run("The keep has fallen")

## Spend stone from the pool to mend the keep (only from inside it).
func repair_keep() -> bool:
	var cost := {"stone": 3}
	if !in_base or crystal_away() or keep_hp >= keep_max() or !can_afford(cost):
		return false
	pay(cost)
	keep_hp = min(keep_max(), keep_hp + 30.0 + bonus("repair"))
	keep_changed.emit()
	return true

func gate_open(angle_rad: float) -> bool:
	var deg := fposmod(rad_to_deg(angle_rad), 360.0)
	for id in sectors_unlocked:
		var d := absf(fposmod(deg - SECTOR_ANGLES[id] + 180.0, 360.0) - 180.0)
		if d <= 30.0:
			return true
	return false

func win_run() -> void:
	if run_over:
		return
	run_over = true
	var earned := shards_for_run() + 30
	meta.shards += earned
	meta.best_wave = max(meta.best_wave, run_stats.waves)
	meta["best_level"] = MAX_LEVEL
	save_meta()
	run_ended.emit({"reason": "VICTORY! The keep is saved", "shards": earned, "stats": run_stats.duplicate(), "rewards": make_rewards()})

## Older saves (or tests that swap `meta`) may lack newer keys.
func fix_meta() -> void:
	if !meta.has("skills"):
		meta["skills"] = {}
	if !meta.has("pending"):
		meta["pending"] = []
	if !meta.has("card_tiers"):
		meta["card_tiers"] = {}
	for k in ["weapons", "fusion_tiers"]:
		if !meta.has(k):
			meta[k] = []
	if !meta.has("start_weapon"):
		meta["start_weapon"] = "sword"

func start_weapon_id() -> String:
	fix_meta()
	return meta.start_weapon

## Tier 1 weapons that can drop from chests this run.
func weapon_pool() -> Array:
	fix_meta()
	var out: Array = STARTER_WEAPONS.duplicate()
	for id in meta.weapons:
		if !(id in out) and !(id in SECTOR_WEAPONS.values()):      # sector weapons have their own spawns
			out.append(id)
	for free in ["sword", "pickaxe"]:
		if !(free in out):
			out.append(free)           # the free tools are always in the chests
	return out

## Is this weapon unlocked (the starters, or bought/earned with Shards)?
func weapon_unlocked(id: String) -> bool:
	fix_meta()
	return id in ["sword", "pickaxe"] or id in STARTER_WEAPONS or id in meta.weapons

## Do you know how to make this weapon? A basic weapon is known once unlocked; a fused
## weapon is known (recipe shown) once both of its ingredients are known. It can only be
## made if its fusion tier is unlocked too (see fusion_tier_unlocked).
func weapon_known(id: String) -> bool:
	var parts: Array = Fusion.parts_of(id)
	if parts.size() != 2:
		return weapon_unlocked(id)
	return weapon_known(parts[0]) and weapon_known(parts[1])

## Weapons you may choose to start a run with: the sword, the starters and everything you have
## unlocked, including the realm weapons (Scimitar, Frost Glaive, Ember Flail, Bog Staff, Crystal Wand).
## Those are not in the chest pool, so starting with one is the only way to have it from the first minute.
func start_weapon_options() -> Array:
	fix_meta()
	var out: Array = ["sword", "pickaxe"] + STARTER_WEAPONS
	for id in meta.weapons:
		if !(id in out):
			out.append(id)
	return out

## Every fused weapon whose recipe you can see (both ingredients known).
func known_recipe_ids() -> Array:
	var out := []
	for key in Fusion.RECIPES:
		var rid: String = Fusion.RECIPES[key].id
		if weapon_known(rid):
			out.append(rid)
	return out

## Unlock a weapon and remember which recipes that revealed (the end screen lists them).
func _add_weapon(id: String) -> void:
	var before := known_recipe_ids()
	if !(id in meta.weapons):
		meta.weapons.append(id)
	for rid in known_recipe_ids():
		if !(rid in before):
			var parts: Array = Fusion.parts_of(rid)
			recipe_log.append("New recipe: %s = %s + %s" % [Fusion.display_name(rid), Fusion.display_name(parts[0]), Fusion.display_name(parts[1])])

func buy_weapon(id: String) -> bool:
	fix_meta()
	if id in meta.weapons or !WEAPON_UNLOCK_COSTS.has(id) or meta.shards < WEAPON_UNLOCK_COSTS[id]:
		return false
	meta.shards -= WEAPON_UNLOCK_COSTS[id]
	_add_weapon(id)
	_forget_pending("weapon", id)
	save_meta()
	return true

func _forget_pending(kind: String, id: String) -> void:
	for i in range(meta.pending.size() - 1, -1, -1):
		if meta.pending[i].kind == kind and meta.pending[i].id == id:
			meta.pending.remove_at(i)

func set_start_weapon(id: String) -> void:
	fix_meta()
	if id in start_weapon_options():
		meta.start_weapon = id
		save_meta()

# ---- Weapons: each copy has its own tier bonus and twist, written "id" or "id:bonus:twist".
# Tier = fusion tier + bonus (1 to 6). Bonus comes from a rare drop or from combining two
# identical copies at the Forge.
const WEAPON_TWISTS := ["bleed", "chill", "chain", "lifesteal", "thunder"]

static func weapon_bonus(e: String) -> int:
	return int(e.get_slice(":", 1)) if ":" in e else 0

static func make_weapon_entry(id: String, bonus: int, twist := "") -> String:
	if bonus <= 0 and twist == "":
		return id
	if twist == "":
		return "%s:%d" % [id, bonus]
	return "%s:%d:%s" % [id, bonus, twist]

func weapon_tier_of(e: String) -> int:
	return clampi(Fusion.tier_of(entry_id(e)) + weapon_bonus(e), 1, 6)

## The item dictionary the inventory and the player's hand use for one weapon copy.
func weapon_info(e: String) -> Dictionary:
	var items: Dictionary = load("res://world/item_info.tres").items
	var d: Dictionary = items[entry_id(e)].duplicate()
	d["id"] = entry_id(e)
	d["entry"] = e
	d["bonus"] = weapon_bonus(e)
	d["twist"] = entry_twist(e)
	return d

## A weapon's twist is fixed by its kind and tier, no chance involved: it gains the first
## at total tier 2, the next at tier 4 and the last at tier 6 (a ladder that starts at a
## different twist for each weapon).
func weapon_twist(id: String, tier: int) -> String:
	var rung := (clampi(tier, 1, 6)) / 2
	if rung < 1:
		return ""
	return WEAPON_TWISTS[(absi(id.hash()) + rung - 1) % WEAPON_TWISTS.size()]

## A weapon that drops in the world: usually plain, sometimes a higher tier (Rare Draws skill),
## and a tier 2+ weapon has its twist. Never past what the fusion tiers you own allow.
func roll_weapon_entry(id: String, lvl := -1) -> String:
	var ft: int = Fusion.tier_of(id)
	if lvl < 0:
		lvl = rare_level()
	var r := randf()
	var t := 1
	if r < RARE_P4[lvl]:
		t = 4
	elif r < RARE_P4[lvl] + RARE_P3[lvl]:
		t = 3
	elif r < RARE_P4[lvl] + RARE_P3[lvl] + RARE_P2[lvl]:
		t = 2
	var bonus := clampi(t - 1, 0, maxi(0, weapon_tier_cap() - ft))
	return make_weapon_entry(id, bonus, weapon_twist(id, ft + bonus))

## How far a weapon can be raised this run: 2 above the highest fusion tier you own
## (tier 2 recipes are free, so 4 at first; Tier 3 fusions give 5, Tier 4 fusions 6).
func weapon_tier_cap() -> int:
	fix_meta()
	var best := 2
	for t in meta.fusion_tiers:
		best = maxi(best, int(t))
	return mini(6, best + 2)

## Two identical copies (same weapon, same bonus) combine into one a tier higher.
## Returns the new entry, or "" if they cannot be combined.
func combine_weapons(a: String, b: String) -> String:
	if entry_id(a) != entry_id(b) or weapon_bonus(a) != weapon_bonus(b):
		return ""
	var nb := weapon_bonus(a) + 1
	if Fusion.tier_of(entry_id(a)) + nb > weapon_tier_cap() or Fusion.tier_of(entry_id(a)) + nb > 6:
		return ""
	return make_weapon_entry(entry_id(a), nb, weapon_twist(entry_id(a), Fusion.tier_of(entry_id(a)) + nb))

func combine_cost(a: String) -> Dictionary:
	return Fusion.AWAKEN_COSTS[clampi(weapon_tier_of(a), 1, 5)]

func fusion_tier_unlocked(tier: int) -> bool:
	fix_meta()
	return tier <= 2 or tier in meta.fusion_tiers

func buy_fusion_tier(tier: int) -> bool:
	fix_meta()
	if fusion_tier_unlocked(tier) or !FUSION_TIER_COSTS.has(tier) or meta.shards < FUSION_TIER_COSTS[tier]:
		return false
	# tiers unlock in order
	if tier > 3 and !fusion_tier_unlocked(tier - 1):
		return false
	meta.shards -= FUSION_TIER_COSTS[tier]
	meta.fusion_tiers.append(tier)
	save_meta()
	return true

## Shards to unlock a card at tier 1: double what upgrading a card into the same tier number costs
## (16, 45, 83, 128, 179, 235 for realms 1 to 6), so a new card is a bigger purchase than an upgrade.
func unlock_price(id: String) -> int:
	return int(round(16.0 * pow(card_level(id), 1.5)))

## A card you do not own can be bought straight from the collection once you have
## reached its realm (in any run); otherwise it only comes from reward draws.
func can_buy_card(id: String) -> bool:
	fix_meta()
	return !owns_card(id) and card_level(id) <= int(meta.get("best_level", 1))

func buy_unlock(id: String) -> bool:
	if !can_buy_card(id) or meta.shards < unlock_price(id):
		return false
	meta.shards -= unlock_price(id)
	meta.unlocked.append(id)
	meta.card_tiers[id] = 1
	_forget_pending("card", id)
	save_meta()
	return true

func restart_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func max_mana() -> float:
	return 100.0 + 25.0 * upgrade_levels.get("max_mana", 0) + bonus("mana_max")

func mana_regen() -> float:
	return 3.0 + 1.5 * upgrade_levels.get("regen", 0) + bonus("mana_regen")

func draw_interval() -> float:
	return max(1.5, (6.0 - 0.8 * upgrade_levels.get("draw", 0)) * (1.0 - bonus("draw_speed")))

func start_run() -> void:
	recipe_log = []
	keep_hp = keep_max()
	run_over = false
	run_stats = {"kills": 0, "gold": 0, "waves": 0, "bosses": 0}
	sectors_unlocked = ["s"]
	unlocked_cards = meta.unlocked.duplicate()
	mana = 60.0
	resources = {"stone": int(bonus("start_mats")), "stick": int(bonus("start_mats")), "gold": 0}
	carried = {"stone": 0, "stick": 0, "gold": 0}
	upgrade_levels = {}
	players_in_base = []
	fix_meta()
	deck = {}
	for id in ["fireball", "frost_ring", "barricade", "spike_trap"]:
		deck[id] = 1                       # every card starts a run at tier 1 and grows toward its unlocked tier
	draft_active = false
	hand = []
	for i in 3:
		add_to_hand(draw_card())
	deck_changed.emit()
	_draw_time = 0.0
	mana_changed.emit()
	resources_changed.emit()
	hand_changed.emit()
	run_started.emit()

func _process(delta: float) -> void:
	# The crystal only works while someone is in the keep.
	if !in_base or crystal_away():
		return
	if mana < max_mana():
		mana = min(max_mana(), mana + mana_regen() * delta)
		mana_changed.emit()
	if hand.size() < HAND_SIZE:
		_draw_time += delta
		if _draw_time >= draw_interval():
			_draw_time = 0.0
			add_to_hand(draw_card())
			hand_changed.emit()

func draw_progress() -> float:
	return clamp(_draw_time / draw_interval(), 0.0, 1.0)

## Is a player controlled on THIS machine inside the keep? (The keep works for everyone
## once anyone is inside, but each player's keep UI is only for the ones inside.)
func local_in_base() -> bool:
	for p in players_in_base:
		if is_instance_valid(p) and !p.remote_controlled:
			return true
	return false

func enter_base(player: Node) -> void:
	if player in players_in_base:
		return
	players_in_base.append(player)
	deposit(player)
	base_players_changed.emit()
	if players_in_base.size() == 1:
		base_mode_changed.emit(true)

func exit_base(player: Node) -> void:
	players_in_base.erase(player)
	base_players_changed.emit()
	if players_in_base.size() == 0:
		base_mode_changed.emit(false)

## `who` is the player that picked it up. Co-op avatars carry their own load; the local
## player uses the shared `carried` table. Either way it only reaches the keep's pool
## when that player enters a tower (see deposit).
func pick_up_resource(type: String, who = null) -> void:
	if type == "gold":
		run_stats.gold += 1
		Sfx.play("coin", 0.15)
		if randf() < bonus("gold_chance"):
			run_stats.gold += 1
			carried["gold"] = carried.get("gold", 0) + 1
	if who != null and who.remote_controlled:
		who.carried[type] = who.carried.get(type, 0) + 1
		return
	carried[type] = carried.get(type, 0) + 1
	# skill tree: a chance of one extra unit (stone/sticks, or the deeper realm resources)
	if type in ["stone", "stick"]:
		if randf() < bonus("yield_basic"):
			carried[type] += 1
	elif type != "gold":
		if randf() < bonus("yield_rare"):
			carried[type] += 1
	resources_changed.emit()

func add_resource(type: String, amount: int) -> void:
	if type == "gold":
		run_stats.gold += amount
	resources[type] = resources.get(type, 0) + amount
	resources_changed.emit()

func deposit(player = null) -> void:
	var load_table: Dictionary = carried if (player == null or !player.remote_controlled) else player.carried
	for type in load_table.keys():
		resources[type] = resources.get(type, 0) + load_table[type]
		load_table[type] = 0
	resources_changed.emit()

func can_afford(cost: Dictionary) -> bool:
	for type in cost:
		if resources.get(type, 0) < cost[type]:
			return false
	return true

func pay(cost: Dictionary) -> void:
	for type in cost:
		resources[type] -= cost[type]
	resources_changed.emit()

func can_cast(card_id: String) -> bool:
	if !in_base or crystal_away() or !(card_id in hand):
		return false
	var c: Dictionary = CARDS[entry_id(card_id)]
	return mana >= c.mana and can_afford(c.res)

## Cast a card from the hand at a world position. Returns true if it went off.
func cast(card_id: String, pos: Vector2, caster: Node = null) -> bool:
	if !can_cast(card_id) or world == null:
		return false
	var c: Dictionary = CARDS[entry_id(card_id)]
	Sfx.play("cast")
	mana -= c.mana
	pay(c.res)
	hand.remove_at(hand.find(card_id))
	var spell := Spell.new()
	spell.setup(stats_of(card_id), pos, crystal_position())
	world.add_child(spell)
	mana_changed.emit()
	hand_changed.emit()
	return true

## The crystal powers the keep: while it is away nothing in the base works.
func crystal_away() -> bool:
	return crystal_state != "home"

## A card in the hand is an "entry": "fireball" is tier 1, "fireball:2" is tier 2.
static func entry_id(e: String) -> String:
	return e.get_slice(":", 0)

static func entry_tier(e: String) -> int:
	return int(e.get_slice(":", 1)) if ":" in e else 1

## A twist changes how a card works (not just its numbers); "id:tier:twist".
static func entry_twist(e: String) -> String:
	return e.get_slice(":", 2) if e.count(":") >= 2 else ""

static func make_entry(id: String, tier: int, twist := "") -> String:
	if twist != "":
		return "%s:%d:%s" % [id, tier, twist]
	return id if tier <= 1 else "%s:%d" % [id, tier]

# Twists: spells, buildings and weapons gain one as part of upgrading (fixed per card and tier, see twist_for). [name, what it does]
const TWISTS := {
	"twin": ["Twin", "Casts a second time half a second later."],
	"aftermath": ["Aftermath", "Leaves a lingering patch on the ground."],
	"shrapnel": ["Shrapnel", "Bursts into fragments that fly outward."],
	"echo": ["Echo", "A wider second wave follows."],
	"wide": ["Wide", "40% bigger area, lasts longer."],
	"thorned": ["Thorned", "Hurts whatever chews on it."],
	"regrow": ["Regrowth", "Slowly mends itself."],
	"rearm": ["Rearm", "Regains a use every few seconds."],
	"venom": ["Venom", "Enemies it hits are poisoned."],
	"twin_shot": ["Twin Shot", "Fires at the two nearest enemies."],
	"frost_shot": ["Frost Shot", "Shots chill their target."],
	"blast_shot": ["Blast Shot", "Shots splash nearby enemies."],
	"wide_field": ["Wide Field", "40% bigger area."],
	"swift_heal": ["Swift Healing", "Heals 60% faster."],
	"deep_freeze": ["Deep Freeze", "Chills much harder."],
	"bleed": ["Bleeding", "Hits cause bleeding."],
	"chill": ["Chilling", "Hits slow the target."],
	"chain": ["Chain", "Hits arc to a nearby enemy."],
	"lifesteal": ["Vampiric", "Heals you a little with every hit."],
	"thunder": ["Thunder", "Every 4th hit blasts the area."],
}
const BUILD_TWISTS := {
	"barricade": ["thorned", "regrow"], "spike_trap": ["rearm", "venom"], "sentry": ["twin_shot", "frost_shot", "blast_shot"],
	"mender": ["wide_field", "swift_heal"], "totem": ["deep_freeze", "wide_field"],
}

func twist_pool(id: String) -> Array:
	var c: Dictionary = CARDS[id]
	if c.kind == "build":
		return BUILD_TWISTS.get(c.build, [])
	match c.kind:
		"fireball", "zone", "spikes":
			return ["twin", "aftermath", "shrapnel", "echo"]
		"frost_ring":
			return ["twin", "aftermath", "echo"]
	return ["twin", "wide"]

## The twist a card or building has at a tier. Fixed, never random: tier 2 gains the first
## twist of its list, tier 4 the second and tier 6 the third (if it has that many; a card with
## fewer keeps its last). It is part of the upgrade.
func twist_for(id: String, tier: int) -> String:
	var pool := twist_pool(id)
	var rung := clampi(tier, 1, 6) / 2
	if pool.is_empty() or rung < 1:
		return ""
	return pool[mini(rung - 1, pool.size() - 1)]

func is_build(id: String) -> bool:
	return CARDS[entry_id(id)].kind == "build"

## Chance of drawing a card above tier 1, by Rare Draws skill level (0 to 5).
# the last row (index 6) is only reached by the rainbow sheep, which pays better than any chest
const RARE_P2 := [0.0, 0.10, 0.15, 0.20, 0.25, 0.30, 0.38]
const RARE_P3 := [0.0, 0.0, 0.01, 0.03, 0.05, 0.08, 0.14]
const RARE_P4 := [0.0, 0.0, 0.0, 0.0, 0.01, 0.02, 0.05]

func rare_level() -> int:
	return clampi(int(bonus("rare_level")), 0, 5)

## Chests pay out better the deeper you are: they use the Rare Draws odds table at your Rare Draws
## level plus the realms you have opened (level 1 is already one step up, level 5 and 6 are the best row).
## `extra` lifts it further (the rainbow sheep adds 1, which reaches a row no chest does).
func chest_level(extra := 0) -> int:
	return clampi(mini(5, rare_level() + level_reached()) + extra, 0, 6)       # chests stop at row 5; only the sheep reaches row 6

## The tier a freshly drawn copy of this card comes in at (never above its unlocked tier).
func roll_card_tier(id: String, lvl := -1) -> int:
	if lvl < 0:
		lvl = rare_level()
	var r := randf()
	var t := 1
	if r < RARE_P4[lvl]:
		t = 4
	elif r < RARE_P4[lvl] + RARE_P3[lvl]:
		t = 3
	elif r < RARE_P4[lvl] + RARE_P3[lvl] + RARE_P2[lvl]:
		t = 2
	return mini(t, card_tier(id))

func stats_of(entry: String) -> Dictionary:
	var c := scaled(entry_id(entry), entry_tier(entry))
	c.twist = entry_twist(entry)
	return c

## Two identical cards (same card, same tier) combine into one of the next tier, as far as
## the tier you have unlocked for that card.
func can_merge(i: int, j: int) -> bool:
	if i == j or i < 0 or j < 0 or i >= hand.size() or j >= hand.size():
		return false
	if entry_id(hand[i]) != entry_id(hand[j]) or entry_tier(hand[i]) != entry_tier(hand[j]):
		return false
	return entry_tier(hand[i]) + 1 <= mini(MAX_LEVEL, card_tier(entry_id(hand[i])))

func merge_hand(i: int, j: int) -> bool:
	if !can_merge(i, j):
		if i != j and i >= 0 and j >= 0 and i < hand.size() and j < hand.size() and entry_id(hand[i]) == entry_id(hand[j]) and entry_tier(hand[i]) == entry_tier(hand[j]):
			announce.emit("Raise this card's unlocked tier in the collection to merge further.")
		return false
	var e: String = hand[i]
	var tw := twist_for(entry_id(e), entry_tier(e) + 1)                                         # the twist that tier comes with
	var merged := make_entry(entry_id(e), entry_tier(e) + 1, tw)
	hand.remove_at(maxi(i, j))
	hand.remove_at(mini(i, j))
	add_to_hand(merged)
	Sfx.play("unlock", 0.0)
	hand_changed.emit()
	return true

func hand_count(builds: bool) -> int:
	var n := 0
	for id in hand:
		if is_build(id) == builds:
			n += 1
	return n

## Draw from one of two decks (spells or buildings), whichever has an open slot in the
## hand, so a build-heavy or spell-heavy deck never starves the other kind. Within a deck,
## cards you can pay for right now come up three times as often.
func draw_card() -> String:
	var spells := []
	var builds := []
	for id in deck:
		(builds if is_build(id) else spells).append(id)
	var want_builds: bool
	if spells.is_empty():
		want_builds = true
	elif builds.is_empty():
		want_builds = false
	elif hand_count(false) < SPELL_SLOTS and hand_count(true) < BUILD_SLOTS:
		# both open: prefer the one that is further from full
		want_builds = float(hand_count(true)) / BUILD_SLOTS < float(hand_count(false)) / SPELL_SLOTS
	else:
		want_builds = hand_count(false) >= SPELL_SLOTS
	var pool: Array = builds if want_builds else spells
	var bag := []
	for id in pool:
		var w := (3 if can_afford(CARDS[id].res) else 1) * int(deck[id])        # deck[id] = copies of this card you hold
		var in_hand := 0
		for h in hand:
			if entry_id(h) == id:
				in_hand += 1
		if in_hand > 0:
			w = maxi(1, w - in_hand)    # a little variety: fewer draws of what you already hold
		for i in w:
			bag.append(id)
	var pick: String = bag.pick_random()
	var t := roll_card_tier(pick)
	return make_entry(pick, t, twist_for(pick, t))

## Add to the hand with spells first, then buildings.
func add_to_hand(id: String) -> void:
	hand.append(id)
	var sorted := []
	for id2 in hand:
		if !is_build(id2):
			sorted.append(id2)
	for id2 in hand:
		if is_build(id2):
			sorted.append(id2)
	hand = sorted

## (Cards carry their own tier now; deck[id] is how many copies you hold.)
func deck_level(_id: String) -> int:
	return 1

## Card stats with the run's level applied. Level 1 is the base card.
func stats(id: String) -> Dictionary:
	return scaled(id, deck_level(id))

## Card stats at a given tier/level (1-6). Used by casting, the collection screen
## and the upgrade comparison.
func scaled(id: String, level: int) -> Dictionary:
	var c: Dictionary = CARDS[id].duplicate()
	var k := level - 1
	# Power of one tier-N card: 1.1 x 2^(N-1), so it beats the N-1 doublings of cards that were merged to make
	# it (a tier 3 is worth about 4.4 tier 1s). The power is split between the stats by what the card does.
	var m := 1.0 if level <= 1 else 1.1 * pow(2.0, level - 1)
	var bk: String = c.get("build", "")
	var e := {"damage": 0.65, "dps": 0.65, "burst": 0.65, "radius": 0.25, "duration": 0.2, "heal_per_sec": 0.7, "hp": 1.0, "thorns": 0.5, "uses": 0.4, "range": 0.12}
	if bk == "sentry":
		e.damage = 0.55
		e.burst = 0.55
		c.interval = c.get("interval", 0.7) * pow(m, -0.45)        # fires faster too: total damage output ~ m
	elif bk == "spike_trap":
		e.damage = 0.6
	if c.kind == "charm":
		e.duration = 0.4
		e.radius = 0.2
	elif c.kind == "guards":
		e.damage = 0.5
		e.duration = 0.25
	if bk in ["barricade", "sentry"]:
		e.erase("radius")                                           # that radius is just the footprint
	for key in e:
		if !c.has(key):
			continue
		if key == "duration" and c.duration <= 0.0:
			continue
		c[key] = c[key] * pow(m, e[key])
	if c.has("uses"):
		c.uses = int(c.uses)
	if c.has("count"):
		c.count = c.count + 2 * k
	if c.has("slow"):
		c.slow = maxf(0.12, pow(c.slow, 1.0 + 0.35 * k))           # stronger chill with tier
	if c.kind == "build":
		var bp := 1.0 + bonus("build_power")
		for k2 in ["hp", "damage", "burst", "thorns", "heal_per_sec"]:
			if c.has(k2):
				c[k2] = c[k2] * bp
		if c.has("duration") and c.duration > 0.0:
			c.duration = c.duration * (1.0 + bonus("build_life"))
	else:
		var sp := 1.0 + bonus("spell_power")
		for k2 in ["damage", "dps", "heal_per_sec"]:
			if c.has(k2):
				c[k2] = c[k2] * sp
		c.radius = c.radius * (1.0 + bonus("spell_radius"))
	c.level = level
	c.id = id
	return c

## The numbers shown on a card at a tier: [{label, v (number), text}], in display order.
func card_numbers(id: String, level: int) -> Array:
	var c := scaled(id, level)
	var out := []
	if c.get("element", "") != "":
		out.append({"label": "Element", "v": 0.0, "text": String(c.element).capitalize(), "good": 0})
	if c.mana > 0:
		out.append({"label": "Mana", "v": float(c.mana), "text": "%d" % c.mana, "good": -1})
	for t in c.res:
		out.append({"label": "Cost: " + t, "v": float(c.res[t]), "text": "%d" % c.res[t], "good": -1})
	var defs := [
		["damage", "Damage", "%.1f", 1.0], ["dps", "Damage/sec", "%.1f", 1.0], ["burst", "Blast damage", "%.1f", 1.0],
		["thorns", "Thorns damage", "%.1f", 1.0], ["heal_per_sec", "Healing/sec", "%.1f", 1.0],
		["hp", "Health", "%d", 1.0], ["uses", "Uses", "%d", 1.0], ["count", "Guards", "%d", 1.0],
		["range", "Range", "%d", 1.0], ["duration", "Lasts (s)", "%.1f", 1.0], ["radius", "Radius", "%d", 1.0],
	]
	var skip_radius: bool = c.get("build", "") in ["barricade", "sentry"]
	var _unused := [
	]
	for d in defs:
		if c.has(d[0]) and (d[0] != "duration" or c.duration > 0.0) and !(d[0] == "radius" and skip_radius):
			out.append({"label": d[1], "v": float(c[d[0]]), "text": d[2] % c[d[0]], "good": 1})
	if c.has("slow"):
		out.append({"label": "Slows by", "v": (1.0 - c.slow) * 100.0, "text": "%d%%" % int((1.0 - c.slow) * 100.0), "good": 1})
	if c.has("interval"):
		out.append({"label": "Shots/sec", "v": 1.0 / c.interval, "text": "%.1f" % (1.0 / c.interval), "good": 1})
	elif c.get("build", "") == "sentry":
		out.append({"label": "Shots/sec", "v": 1.0 / 0.7, "text": "%.1f" % (1.0 / 0.7), "good": 1})
	return out

# ---------- permanent card tiers, Shard upgrades, end-of-run rewards ----------

func card_tier(id: String) -> int:
	fix_meta()
	return int(meta.card_tiers.get(id, 1))

func owns_card(id: String) -> bool:
	return id in meta.unlocked

## Upgrading tier n to n+1: 8, 23, 42, 64, 89 Shards (226 for a card from tier 1 to 6).
func card_upgrade_cost(id: String) -> int:
	return int(round(8.0 * pow(card_tier(id), 1.5)))

func upgrade_card(id: String) -> bool:
	fix_meta()
	if !owns_card(id) or card_tier(id) >= MAX_LEVEL or meta.shards < card_upgrade_cost(id):
		return false
	meta.shards -= card_upgrade_cost(id)
	meta.card_tiers[id] = card_tier(id) + 1
	save_meta()
	return true

func convert_value(tier: int, realm := 1) -> int:
	return 3 * tier + 2 * realm

## The sector a sector-resource card belongs to ("" for cards available everywhere).
func card_sector(id: String) -> String:
	for sec in SECTOR_CARDS:
		if id in SECTOR_CARDS[sec]:
			return sec
	return ""

## True if the sectors this card's materials come from are open in this run.
func card_available(id: String) -> bool:
	if COMBO_CARDS.has(id):
		for sec in COMBO_CARDS[id]:
			if !(sec in sectors_unlocked):
				return false
		return true
	var sec := card_sector(id)
	return sec == "" or sec in sectors_unlocked

# ---------- end-of-run rewards: one card per level reached, all kept ----------

const REALM_LEVEL := {"s": 1, "se": 2, "ne": 3, "n": 4, "nw": 5, "sw": 6}
# cards from the base realm that only appear a little deeper
const CARD_LEVEL_OVERRIDE := {"aegis": 2, "guards": 2, "sentry": 2, "charm": 3, "mender": 1}
const WEAPON_LEVEL := {"spear": 1, "hammer": 1, "bow": 1, "daggers": 1, "whip": 2, "shield": 2, "staff": 3, "scimitar": 2, "frostglaive": 3, "emberflail": 4, "bogstaff": 5, "crystalwand": 6}

## The realm level a card belongs to (1 grassland ... 6 crystal caverns). Combo
## buildings count as the deepest realm they need.
func card_level(id: String) -> int:
	if COMBO_CARDS.has(id):
		var lv := 1
		for sec in COMBO_CARDS[id]:
			lv = maxi(lv, REALM_LEVEL[sec])
		return lv
	var sec := card_sector(id)
	if sec != "":
		return REALM_LEVEL[sec]
	return CARD_LEVEL_OVERRIDE.get(id, 1)

## Deepest realm this run reached, 1 to 6 (the final level counts as 6).
func level_reached() -> int:
	return clampi(sectors_unlocked.size(), 1, MAX_LEVEL)

## You get one reward per level reached (1 to 6), from realms up to that level. A reward can
## never skip a tier: a card you do not own is offered at tier 1, a card you own is offered
## at exactly one tier above your current tier, and never above the level you reached (a
## level-3 run cannot raise anything past tier 3). Tier-ups apply at once; a brand-new
## card or weapon is an "offer" you pay Shards to unlock (or convert to Shards).
## Applies the rewards and returns
## [{kind, id, tier, realm, result: "offer"|"upgrade"|"converted"|"unlocked", shards, cost}].
func make_rewards() -> Array:
	fix_meta()
	var top := level_reached()
	var out := []
	var used := []
	# offers you have not acted on are kept (see meta.pending); drop any you got another way
	for i in range(meta.pending.size() - 1, -1, -1):
		var pe: Dictionary = meta.pending[i]
		if (pe.kind == "card" and owns_card(pe.id)) or (pe.kind == "weapon" and weapon_unlocked(pe.id)):
			meta.pending.remove_at(i)
	for pe in meta.pending:
		used.append(pe.id if pe.kind == "card" else "w:" + pe.id)
	for i in top:
		var entry := {"kind": "card", "id": "", "tier": 1, "realm": 1, "result": "", "shards": 0}
		var weapons := []
		for w in WEAPON_UNLOCK_COSTS:
			if !(w in meta.weapons) and !(("w:" + w) in used) and WEAPON_LEVEL[w] <= top:
				weapons.append(w)
		if weapons.size() > 0 and randf() < 0.2:
			entry.kind = "weapon"
			entry.id = weapons.pick_random()
			entry.realm = WEAPON_LEVEL[entry.id]
			entry.result = "offer"
			used.append("w:" + entry.id)
		else:
			var bag := []
			for id in CARDS:
				if id in used:
					continue
				var cl := card_level(id)
				if cl > top:
					continue
				var weight := 0
				if !owns_card(id):
					weight = 4 if cl == top else 3                     # something new, deeper realms favoured
				elif card_tier(id) < mini(MAX_LEVEL, top):
					weight = 3                                           # the next tier of something you own
				for k in weight:
					bag.append(id)
			if bag.is_empty():
				# nothing new and nothing to raise at this level: a spare is turned into Shards
				var shallow := []
				for id in CARDS:
					if card_level(id) <= top:
						shallow.append(id)
				entry.id = shallow.pick_random()
				entry.realm = card_level(entry.id)
				entry.tier = card_tier(entry.id) if owns_card(entry.id) else 1
				entry.result = "converted"
				entry.shards = convert_value(entry.tier, entry.realm)
			else:
				entry.id = bag.pick_random()
				entry.realm = card_level(entry.id)
				used.append(entry.id)
				if owns_card(entry.id):
					entry.tier = card_tier(entry.id) + 1
					entry.result = "upgrade"
					meta.card_tiers[entry.id] = entry.tier
				else:
					entry.tier = 1
					entry.result = "offer"
		if entry.result == "offer":
			entry.cost = unlock_cost(entry)
			if meta.pending.size() >= MAX_PENDING:
				entry.result = "converted"               # the vault is full: this one turns into Shards
				entry.shards = convert_value(1, int(entry.realm))
			else:
				meta.pending.append(entry)
		meta.shards += entry.shards
		out.append(entry)
	save_meta()
	return out

## Shards to unlock a new reward: weapons cost what the weapon shop charges, cards cost
## more the deeper their realm.
func unlock_cost(entry: Dictionary) -> int:
	if entry.kind == "weapon":
		return WEAPON_UNLOCK_COSTS.get(entry.id, 32)
	return unlock_price(entry.id)

## Pay Shards to take a new reward ("offer"). False if you cannot afford it.
func unlock_offer(entry: Dictionary) -> bool:
	fix_meta()
	if entry.result != "offer" or meta.shards < entry.cost:
		return false
	meta.shards -= entry.cost
	if entry.kind == "weapon":
		_add_weapon(entry.id)
	else:
		if !owns_card(entry.id):
			meta.unlocked.append(entry.id)
		meta.card_tiers[entry.id] = maxi(card_tier(entry.id), int(entry.tier))
	entry.result = "unlocked"
	_forget_pending(entry.kind, entry.id)
	save_meta()
	return true

## Turn an unclaimed offer into Shards instead (saving up for something else).
func convert_offer(entry: Dictionary) -> int:
	if entry.result != "offer":
		return 0
	entry.result = "converted"
	entry.shards = convert_value(int(entry.tier), int(entry.get("realm", 1)))
	meta.shards += entry.shards
	_forget_pending(entry.kind, entry.id)
	save_meta()
	return entry.shards

## Chest draft: three different cards from the unlocked pool (never ones already
## at max level). Picking one you own upgrades it; a new one joins the deck.
func start_draft(extra := 0) -> bool:
	if draft_active:
		return false
	var pool := []
	for id in unlocked_cards:
		pool.append(id)                              # a duplicate adds a copy to your hand and deck
	if pool.is_empty():
		return false
	pool.shuffle()
	draft_active = true
	draft_options = []
	for id in pool.slice(0, DRAFT_SIZE):
		var t := roll_card_tier(id, chest_level(extra))              # deeper runs offer higher tiers (never above what you unlocked)
		draft_options.append(make_entry(id, t, twist_for(id, t)))
	draft_started.emit(draft_options)
	return true

func take_draft_card(entry: String) -> void:
	if !draft_active:
		return
	var id := entry_id(entry)
	deck[id] = int(deck.get(id, 0)) + 1               # a new card joins the deck; a duplicate adds a copy (drawn more often)
	# the copy goes into your hand right away if there is room for its kind
	var slots_free: bool = hand_count(is_build(id)) < (BUILD_SLOTS if is_build(id) else SPELL_SLOTS)
	if slots_free:
		add_to_hand(entry)
		hand_changed.emit()
	draft_active = false
	draft_options = []
	deck_changed.emit()

## Spells are shot from the crystal, so aim and travel time matter.
func crystal_position() -> Vector2:
	if world == null:
		return Vector2.ZERO
	var crystal := world.get_node_or_null("Well/Crystal")
	return crystal.global_position if crystal else Vector2.ZERO

func flight_time(card_id: String, target: Vector2) -> float:
	return crystal_position().distance_to(target) / CARDS[entry_id(card_id)].speed

func upgrade_cost(id: String) -> Dictionary:
	var level: int = upgrade_levels.get(id, 0)
	var cost := {}
	for type in UPGRADES[id].base:
		cost[type] = UPGRADES[id].base[type] * (1 + level)
	return cost

func buy_upgrade(id: String) -> bool:
	if !in_base or crystal_away():
		return false
	var cost := upgrade_cost(id)
	if !can_afford(cost):
		return false
	pay(cost)
	upgrade_levels[id] = upgrade_levels.get(id, 0) + 1
	mana_changed.emit()
	return true
