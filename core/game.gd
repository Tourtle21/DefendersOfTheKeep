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
		"element": "fire", "night": true,
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
	"flare": {
		"element": "fire", "night": true,
		"name": "Flare", "mana": 20, "res": {"stick": 1}, "kind": "flare", "art": "flare",
		"radius": 85.0, "duration": 12.0, "dps": 1.0, "speed": 220.0, "color": Color(1.0, 0.9, 0.5),
		"desc": "A bright burst of light for a while. Enemies inside lose their shroud at night and burn a little.",
	},
	"meteor_shower": {
		"element": "fire", "night": true, "legendary": true,
		"name": "Meteor Shower", "mana": 60, "res": {}, "kind": "meteor", "art": "meteor_shower",
		"radius": 110.0, "damage": 14.0, "count": 10, "duration": 3.5, "speed": 170.0, "color": Color(1.0, 0.5, 0.15),
		"desc": "LEGENDARY. Meteors rain over a wide area and light it up.",
	},
	"stasis": {
		"legendary": true,
		"name": "Stasis Field", "mana": 50, "res": {}, "kind": "stasis", "art": "stasis",
		"radius": 130.0, "duration": 5.0, "speed": 240.0, "color": Color(0.75, 0.9, 1.0),
		"desc": "LEGENDARY. Freezes every enemy in the field in place and leaves them exposed.",
	},
	"sunspire": {
		"element": "fire", "night": true, "legendary": true, "light": 170.0,
		"name": "Sunspire", "mana": 0, "res": {"gold": 10, "stone": 4}, "kind": "build", "build": "sentry", "art": "sunspire",
		"radius": 14.0, "range": 200.0, "damage": 5.0, "interval": 0.5, "burst": 4.0, "duration": 90.0, "speed": 260.0, "color": Color(1.0, 0.92, 0.5),
		"desc": "LEGENDARY. A tower of daylight: a huge light and fast, fierce shots that never lose the dark.",
	},
	"phoenix_shrine": {
		"legendary": true, "night": true, "light": 90.0,
		"name": "Phoenix Shrine", "mana": 0, "res": {"gold": 8, "stone": 4}, "kind": "build", "build": "mender", "art": "phoenix_shrine",
		"radius": 95.0, "heal_per_sec": 24.0, "duration": 100.0, "speed": 260.0, "color": Color(1.0, 0.55, 0.2),
		"desc": "LEGENDARY. A burning shrine that heals everyone nearby fast and lights the area.",
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
		"element": "fire", "night": true,
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
		"radius": 22.0, "damage": 0.5, "uses": 10, "slow": 1.0, "duration": 0.0, "speed": 260.0,
		"desc": "Hurts and slows whoever walks over it.",
	},
	"torch": {
		"element": "fire", "night": true,
		"name": "Torch", "mana": 0, "res": {"stick": 2}, "kind": "build", "build": "torch", "art": "torch",
		"radius": 8.0, "hp": 10.0, "light": 85.0, "duration": 120.0, "speed": 260.0, "color": Color(1.0, 0.7, 0.25),
		"desc": "Lights the ground around it. At night, enemies in its light lose their shroud and your sentries and towers can see them.",
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
		"element": "fire", "night": true, "light": 55.0,
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
		"element": "pierce", "night": true, "light": 50.0,
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
	# --- fused cards: only made at the Card Fuser (FUSE_RECIPES), never drawn, offered or unlocked ---
	"frostfire": {
		"fused": true, "element": "fire", "night": true,
		"name": "Frostfire", "mana": 35, "res": {}, "kind": "fireball", "art": "frostfire",
		"radius": 55.0, "damage": 7.5, "speed": 160.0, "color": Color(0.7, 0.85, 1.0),
		"desc": "Fireball and Frost Ring fused: a bigger blast that leaves a lingering patch.",
	},
	"solar_burst": {
		"fused": true, "element": "fire", "night": true,
		"name": "Solar Burst", "mana": 40, "res": {}, "kind": "fireball", "art": "solar_burst",
		"radius": 70.0, "damage": 6.0, "speed": 170.0, "color": Color(1.0, 0.9, 0.5),
		"desc": "Fireball and Flare fused: a bright blast that bursts into fragments.",
	},
	"spiked_wall": {
		"fused": true,
		"name": "Spiked Wall", "mana": 0, "res": {"stone": 3, "stick": 2}, "kind": "build", "build": "barricade", "art": "spiked_wall",
		"radius": 18.0, "hp": 45.0, "thorns": 3.0, "duration": 0.0, "speed": 260.0, "color": Color(0.75, 0.7, 0.6),
		"desc": "Barricade and Spike Trap fused: a sturdy wall that bites back.",
	},
	"spiked_sentry": {
		"fused": true,
		"name": "Spiked Sentry", "mana": 0, "res": {"stone": 2, "stick": 3, "gold": 3}, "kind": "build", "build": "sentry", "art": "spiked_sentry",
		"radius": 12.0, "range": 125.0, "damage": 2.4, "duration": 55.0, "speed": 260.0,
		"desc": "Spike Trap and Sentry fused: a longer-lived sentry whose shots splash.",
	},
	"beacon_turret": {
		"fused": true, "element": "fire", "night": true, "light": 75.0,
		"name": "Beacon Turret", "mana": 0, "res": {"stone": 2, "stick": 3, "gold": 3}, "kind": "build", "build": "sentry", "art": "beacon_turret",
		"radius": 12.0, "range": 120.0, "damage": 2.2, "duration": 55.0, "speed": 260.0, "color": Color(1.0, 0.7, 0.25),
		"desc": "Torch and Sentry fused: a sentry that lights its surroundings and fires at two targets.",
	},
	"healing_lantern": {
		"fused": true, "night": true, "light": 70.0,
		"name": "Healing Lantern", "mana": 0, "res": {"stone": 2, "stick": 2, "gold": 2}, "kind": "build", "build": "mender", "art": "healing_lantern",
		"radius": 55.0, "heal_per_sec": 8.0, "duration": 70.0, "speed": 260.0, "color": Color(1.0, 0.85, 0.5),
		"desc": "Mender Totem and Torch fused: heals faster, and the light keeps the dark away.",
	},
	"bonfire_wall": {
		"fused": true, "element": "fire", "night": true, "light": 80.0,
		"name": "Bonfire Wall", "mana": 0, "res": {"stone": 3, "stick": 2}, "kind": "build", "build": "barricade", "art": "bonfire_wall",
		"radius": 18.0, "hp": 36.0, "thorns": 1.5, "duration": 0.0, "speed": 260.0, "color": Color(1.0, 0.55, 0.2),
		"desc": "Barricade and Torch fused: a wall that burns bright and mends itself.",
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
var draft_owner_slot := 0        # split screen: which local player opened the chest (0 = player 1, whose screen the draft normally uses)
var draft_options: Array = []
const KEEP_BASE := 150.0
var keep_hp := KEEP_BASE

# permanent skill tree bought with Shards (see core/skills.gd); levels saved in meta.skills
func skill_level(id: String) -> int:
	fix_meta()
	return int(meta.skills.get(id, 0))

const SKILL_COST_SCALE := 2.5
const SKILL_COST_CURVE := 1.8       # cost of level n+1 grows with (n+1)^1.8 (1, 3.5, 7.2, 12.1, 18 times the first level)
const MAX_PENDING := 12            # offers kept between runs until you unlock or convert them

func skill_cost(id: String) -> int:
	return int(round(Skills.TREE[id].cost * pow(skill_level(id) + 1, SKILL_COST_CURVE) * SKILL_COST_SCALE))      # each level costs clearly more than the last

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
var unlocked_cards: Array = ["fireball", "frost_ring", "barricade", "spike_trap", "torch"]

# --- night ---
# The world's clock sets night_level (0 = day, 1 = full night). In the dark, an enemy outside every light is
# "shrouded": it takes less damage and towers and sentries only see it up close. Light comes from players (a
# little), torches, flares, fire spells, glowing buildings and fire/crystal weapons.
var night_level := 0.0
var night_wave_now := false          # the wave that is currently walking in is a night wave
const SHROUD := 0.6                  # damage multiplier on a shrouded enemy
const NIGHT_SIGHT := 50.0            # how far defences see an unlit enemy in the dark
const PLAYER_LIGHT := 46.0

func is_dark() -> bool:
	return night_level >= 0.6

func player_light(p) -> float:
	var r := PLAYER_LIGHT
	var it = p.get("item")
	if it != null and it.get("light_radius") != null:
		r = maxf(r, float(it.light_radius))
	return r

## Is this point lit? (Always true in daylight.)
func lit_at(pos: Vector2) -> bool:
	if !is_dark():
		return true
	for n in get_tree().get_nodes_in_group("light"):
		if is_instance_valid(n) and !n.is_queued_for_deletion() and n.get("light_radius") != null and n.global_position.distance_to(pos) <= float(n.light_radius):
			return true
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.global_position.distance_to(pos) <= player_light(p):
			return true
	return false

## An enemy is lit if it stands in light or was hit by something bright a moment ago.
func is_lit(e: Node2D) -> bool:
	if !is_dark():
		return true
	if e.has_meta("lit_until") and float(e.get_meta("lit_until")) > Time.get_ticks_msec() / 1000.0:
		return true
	return lit_at(e.global_position)

func light_up(e: Node, secs: float) -> void:
	if is_instance_valid(e):
		e.set_meta("lit_until", Time.get_ticks_msec() / 1000.0 + secs)

## Can a tower or sentry at `from` target this enemy? In the dark only what is lit, or very close.
func defence_sees(e: Node2D, from: Vector2) -> bool:
	if !is_dark() or is_lit(e):
		return true
	return e.global_position.distance_to(from) <= NIGHT_SIGHT

# --- meta progression (saved between runs) ---
# weapons: three Tier 1 weapons are in the chest pool from the start; Shards add the rest
const STARTER_WEAPONS := []             # no weapon is free except the sword and pickaxe; everything else costs Shards
# every weapon must be unlocked once (reward draw or the codex) before it can appear in a run
# same price rule as cards: 16 x realm^1.5 (see unlock_price), by WEAPON_LEVEL
const WEAPON_UNLOCK_COSTS := {"torch": 16, "spear": 16, "hammer": 16, "bow": 45, "daggers": 45, "scimitar": 45, "whip": 83, "shield": 83, "frostglaive": 83, "staff": 128, "emberflail": 128, "bogstaff": 179, "crystalwand": 235}
const FUSION_TIER_COSTS := {3: 60, 4: 140}      # tier 2 recipes are known from the start
const STARTER_CARDS := ["fireball", "frost_ring", "barricade", "spike_trap", "torch"]       # the Torch is free: night comes in the first run
var save_path := "user://save.json"
var meta := {"pending": [], "skills": {}, "card_tiers": {}, "weapons": [], "fusion_tiers": [], "start_weapon": "sword", "shards": 0, "unlocked": ["fireball", "frost_ring", "barricade", "spike_trap", "torch"], "best_wave": 0, "recipes_seen": [], "hints_seen": [], "hints_enabled": true}
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
	# every run pays 6 just for playing, then 3 per wave (waves are big and 2 to 3 minutes apart); a short first run is about 15-20,
	# then waves, kills, gold, bosses and realms opened add the rest
	var base: float = 6.0 + run_stats.waves * 3.0 + run_stats.kills * 0.1 + run_stats.gold / 20.0 + run_stats.bosses * 6.0 + (level_reached() - 1) * 4.0
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
	run_ended.emit({"reason": "VICTORY! The keep is saved", "shards": earned, "stats": run_stats.duplicate(), "rewards": make_rewards(true)})

## Older saves (or tests that swap `meta`) may lack newer keys.
func fix_meta() -> void:
	if !meta.has("skills"):
		meta["skills"] = {}
	if !meta.has("pending"):
		meta["pending"] = []
	for i in range(meta.pending.size() - 1, -1, -1):
		if !(str(meta.pending[i].get("result", "offer")) in ["offer", "spare"]):
			meta.pending.remove_at(i)             # leftovers of offers already unlocked or sold (an old bug kept them forever)
	if !meta.has("card_tiers"):
		meta["card_tiers"] = {}
	for k in ["weapons", "fusion_tiers", "seen"]:
		if !meta.has(k):
			meta[k] = []
	if !meta.has("weapon_tiers"):
		meta["weapon_tiers"] = {}            # weapon id -> the highest tier you have drawn or found (the Forge cannot go past it)
	if !meta.has("tier_drawn"):
		meta["tier_drawn"] = {}              # card id -> the highest tier you have drawn at the end of a run
	if !meta.has("start_weapon"):
		meta["start_weapon"] = "sword"
	if meta.has("unlocked"):
		for id in STARTER_CARDS:
			if !(id in meta.unlocked):
				meta.unlocked.append(id)          # a save from before a starter card existed still gets it

## Have you met this card or weapon? Owned ones, anything offered at the end of a run (even if you converted it)
## and anything you picked up count. Unmet ones show as "?" and cannot be bought.
func is_seen(id: String) -> bool:
	fix_meta()
	if id in meta.seen or id in meta.weapons or ("unlocked" in meta and id in meta.unlocked) or id in ["sword", "pickaxe"]:
		return true
	for pe in meta.pending:
		if str(pe.get("id", "")) == id:
			return true
	return false

## What you have drawn at the end of a run but not used yet, for the Drawn Cards screen: offers waiting to be
## unlocked, spare copies waiting to be merged, and tier-ups waiting to be bought. Unlocking or upgrading removes them.
func waiting_draws() -> Array:
	fix_meta()
	var groups := {}
	for pe in meta.pending:
		var res: String = str(pe.get("result", "offer"))
		if res != "offer" and res != "spare":
			continue
		var key := "%s:%s:%s" % [pe.kind, pe.id, res]
		var g: Dictionary = groups.get(key, {"kind": str(pe.kind), "id": str(pe.id), "tier": 1, "count": 0, "result": res})
		g.count = int(g.count) + 1
		g.tier = maxi(int(g.tier), int(pe.get("tier", 1)))
		groups[key] = g
	for id in CARDS:
		if upgrade_available(id):
			groups["card:%s:upgrade" % id] = {"kind": "card", "id": id, "tier": card_tier(id) + 1, "count": 1, "result": "upgrade"}
	return groups.values()

func mark_seen(id: String) -> void:
	fix_meta()
	if !(id in meta.seen):
		meta.seen.append(id)

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
	if id in meta.weapons or !WEAPON_UNLOCK_COSTS.has(id) or meta.shards < WEAPON_UNLOCK_COSTS[id] or !is_seen(id):
		return false
	meta.shards -= WEAPON_UNLOCK_COSTS[id]
	_add_weapon(id)
	_forget_pending("weapon", id)
	save_meta()
	return true

func _forget_pending(kind: String, id: String) -> void:
	for i in range(meta.pending.size() - 1, -1, -1):
		# (the entry being acted on has already been marked "unlocked" / "converted" by now, so match on any state)
		if meta.pending[i].kind == kind and meta.pending[i].id == id and str(meta.pending[i].get("result", "offer")) in ["offer", "unlocked", "converted"]:
			meta.pending.remove_at(i)

func _drop_pending(entry: Dictionary) -> void:
	for i in range(meta.pending.size() - 1, -1, -1):
		if is_same(meta.pending[i], entry):
			meta.pending.remove_at(i)

# ---------- spare copies: a duplicate of a card you own ----------
# It waits in the vault. Merge it into your card (a copy of the SAME tier raises the card one tier, like merging in a
# run: 1 + 1 = 2, 2 + 2 = 3), combine two spares of the same card and tier into one spare a tier higher, or sell it.

func spare_sell_value(entry: Dictionary) -> int:
	return convert_value(int(entry.tier), int(entry.get("realm", 1)))

## A copy can be merged when it matches your card's tier and that tier is below what your deepest run has reached.
func spare_can_merge(entry: Dictionary) -> bool:
	fix_meta()
	return owns_card(str(entry.id)) and card_tier(str(entry.id)) == int(entry.tier) and int(entry.tier) < mini(MAX_LEVEL, int(meta.get("best_level", 1)))

func spare_merge(entry: Dictionary) -> bool:
	if entry.get("result", "") != "spare" or !spare_can_merge(entry):
		return false
	meta.card_tiers[str(entry.id)] = int(entry.tier) + 1
	entry.result = "merged"
	_drop_pending(entry)
	save_meta()
	return true

## Another waiting spare of the same card and tier, or {}.
func spare_pair(entry: Dictionary) -> Dictionary:
	for pe in meta.pending:
		if !is_same(pe, entry) and pe.get("result", "") == "spare" and pe.id == entry.id and int(pe.tier) == int(entry.tier):
			return pe
	return {}

func spare_combine(entry: Dictionary) -> bool:
	var other := spare_pair(entry)
	if other.is_empty() or int(entry.tier) >= MAX_LEVEL:
		return false
	_drop_pending(other)
	entry.tier = int(entry.tier) + 1
	save_meta()
	return true

func spare_sell(entry: Dictionary) -> int:
	if entry.get("result", "") != "spare":
		return 0
	entry.shards = spare_sell_value(entry)
	entry.result = "converted"
	meta.shards += int(entry.shards)
	_drop_pending(entry)
	save_meta()
	return int(entry.shards)

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
	var bonus := clampi(t - 1, 0, maxi(0, weapon_drop_cap() - ft))
	return make_weapon_entry(id, bonus, weapon_twist(id, ft + bonus))

## Highest tier a weapon can drop at: tier 1 until you buy Tier 3 fusions (then 2), Tier 4 fusions (3), and so on.
func weapon_drop_cap() -> int:
	fix_meta()
	var best := 2
	for t in meta.fusion_tiers:
		best = maxi(best, int(t))
	return mini(6, best - 1)

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
	if Fusion.tier_of(entry_id(a)) + nb > weapon_tier_unlocked(entry_id(a)):
		return ""                       # that tier has not been drawn yet
	return make_weapon_entry(entry_id(a), nb, weapon_twist(entry_id(a), Fusion.tier_of(entry_id(a)) + nb))

## The highest tier of this weapon you have unlocked: by drawing it at the end of a run or finding that tier in a run.
func weapon_tier_unlocked(id: String) -> int:
	fix_meta()
	return maxi(Fusion.tier_of(id), int(meta.weapon_tiers.get(id, 1)))

func note_weapon_tier(id: String, tier: int) -> void:
	fix_meta()
	if tier > weapon_tier_unlocked(id):
		meta.weapon_tiers[id] = mini(tier, 6)

## Would this combine be allowed except that its tier has not been drawn yet?
func combine_locked_by_draw(a: String) -> bool:
	var id := entry_id(a)
	var t := Fusion.tier_of(id) + weapon_bonus(a) + 1
	return t <= mini(6, weapon_tier_cap()) and t > weapon_tier_unlocked(id)

## What forging two weapon entries would do: {"text", "ok", "kind": "fuse" | "combine" | "", "result": the new entry}.
func forge_preview(ea: String, eb: String) -> Dictionary:
	var ida := entry_id(ea)
	var idb := entry_id(eb)
	if ida == idb:
		var res := combine_weapons(ea, eb)
		if res == "":
			if combine_locked_by_draw(ea):
				return {"text": "Tier %d is locked. Draw it at the end of a run." % (weapon_tier_of(ea) + 1), "ok": false, "kind": "combine", "result": ""}
			return {"text": "These cannot combine.", "ok": false, "kind": "combine", "result": ""}
		var cost: Dictionary = combine_cost(ea)
		return {"text": "%s: tier %d -> %d" % [Fusion.display_name(ida), weapon_tier_of(ea), weapon_tier_of(ea) + 1], "ok": can_afford(cost), "kind": "combine", "result": res, "cost": cost}
	var r := Fusion.recipe(ida, idb)
	if r.is_empty():
		return {"text": "These two do not fuse.", "ok": false, "kind": "fuse", "result": ""}
	if !fusion_tier_unlocked(r.tier):
		return {"text": "%s: locked (buy Tier %d fusions)." % [Fusion.display_name(r.id), r.tier], "ok": false, "kind": "fuse", "result": ""}
	var fcost: Dictionary = Fusion.cost(r.tier)
	return {"text": "%s (Tier %d)" % [Fusion.display_name(r.id), r.tier], "ok": can_afford(fcost), "kind": "fuse", "cost": fcost,
		"result": make_weapon_entry(r.id, 0, weapon_twist(r.id, r.tier)), "key": Fusion.key(ida, idb)}

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
	return !owns_card(id) and !is_legendary_card(id) and is_seen(id)

func buy_unlock(id: String) -> bool:
	if !can_buy_card(id) or meta.shards < unlock_price(id):
		return false
	meta.shards -= unlock_price(id)
	meta.unlocked.append(id)
	meta.card_tiers[id] = 1
	_forget_pending("card", id)
	save_meta()
	return true

var _menu_done := false             # the start screen shows once per launch
var _forge_store: Array = []        # weapon entries dropped into the forge: the whole team can use them there (host side)
const FORGE_STORE_MAX := 9
var _local_devices: Array = []      # split screen: slot -> controller id (-1 = keyboard and mouse); empty = a normal single-player game

func restart_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func max_mana() -> float:
	return 100.0 + 25.0 * upgrade_levels.get("max_mana", 0) + bonus("mana_max")

## How many players are in this game: you, co-op friends over LAN and local split-screen players.
func player_count() -> int:
	return maxi(1, get_tree().get_nodes_in_group("player").size())

## 1.0 for one player, growing by `per` for every extra player (LAN or split screen). Waves, bosses and the shared
## mana pool all use it, so a team of four faces roughly four players' worth of enemies.
func team_scale(per: float) -> float:
	return 1.0 + per * float(player_count() - 1)

func mana_regen() -> float:
	return (3.0 + 1.5 * upgrade_levels.get("regen", 0) + bonus("mana_regen")) * team_scale(0.35)      # one shared mana pool, more people casting from it

func draw_interval() -> float:
	return max(1.5, (6.0 - 0.8 * upgrade_levels.get("draw", 0)) * (1.0 - bonus("draw_speed")))

func start_run() -> void:
	_forge_store = []
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
	for id in STARTER_CARDS:
		if id in meta.unlocked:
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

## --- towers: while you are inside one you can jump to any other lit tower ---

## A tower is lit (usable) when its turret says it is online: sector open, visible, crystal home.
func tower_online(t: Node) -> bool:
	for c in t.get_children():
		if c.has_method("online"):
			return c.online()
	return false

func all_towers() -> Array:
	var out := []
	if world == null:
		return out
	for c in world.get_children():
		if c is StaticBody2D and c.name.begins_with("Tower"):
			out.append(c)
	return out

## The lit tower nearest to a world point within `radius`, or null.
func tower_at(pos: Vector2, radius: float, skip: Node = null):
	var best = null
	for t in all_towers():
		if t == skip or !tower_online(t):
			continue
		var d: float = t.global_position.distance_to(pos)
		if d <= radius and (best == null or d < best.global_position.distance_to(pos)):
			best = t
	return best

## The player inside this tower, or null. A tower holds one person at a time.
func tower_occupant(tower: Node):
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.is_in_tower and current_tower(p) == tower:
			return p
	return null

## Is someone other than `who` inside this tower?
func tower_taken(tower: Node, who: Node) -> bool:
	var occ = tower_occupant(tower)
	return occ != null and occ != who

func current_tower(player: Node):
	var best = null
	for t in all_towers():
		var d: float = t.global_position.distance_to(player.global_position)
		if d <= 60.0 and (best == null or d < best.global_position.distance_to(player.global_position)):
			best = t
	return best

## Move a player from the tower they are in to another lit one. `visuals` toggles the doors and interior (local player).
func teleport_to_tower(player: Node, target: Node, visuals := true) -> bool:
	if player == null or target == null or !player.is_in_tower or !tower_online(target):
		return false
	var cur = current_tower(player)
	if cur == target:
		return false
	if tower_taken(target, player):
		announce.emit("That tower is already in use.")
		return false
	if visuals:
		if cur != null:
			cur.get_node("EnterArea").teleport_leave()
		target.get_node("EnterArea").teleport_arrive(player)
	else:
		player.global_position = target.global_position - Vector2(0, 10)
	WeaponFx.spawn(world, "ring", target.global_position, Color(0.7, 0.9, 1.0), {"radius": 22.0, "life": 0.35})
	Sfx.play("unlock", 0.0)
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
	"blaze": ["Blaze", "Enemies standing in its light burn."],
	"bleed": ["Bleeding", "Hits cause bleeding."],
	"chill": ["Chilling", "Hits slow the target."],
	"chain": ["Chain", "Hits arc to a nearby enemy."],
	"lifesteal": ["Vampiric", "Heals you a little with every hit."],
	"thunder": ["Thunder", "Every 4th hit blasts the area."],
}
const BUILD_TWISTS := {
	"barricade": ["thorned", "regrow"], "spike_trap": ["rearm", "venom"], "sentry": ["twin_shot", "frost_shot", "blast_shot"],
	"mender": ["wide_field", "swift_heal"], "totem": ["deep_freeze", "wide_field"], "torch": ["wide_field", "blaze"],
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

## Card Fuser recipes: two different cards of the same tier become one fused card of that tier, which comes with a fixed twist.
## key = the two card ids sorted and joined with "+"; the cost is gold.
const FUSE_RECIPES := {
	"fireball+frost_ring": {"result": "frostfire", "twist": "aftermath"},
	"fireball+flare": {"result": "solar_burst", "twist": "shrapnel"},
	"barricade+spike_trap": {"result": "spiked_wall", "twist": "thorned"},
	"sentry+spike_trap": {"result": "spiked_sentry", "twist": "blast_shot"},
	"sentry+torch": {"result": "beacon_turret", "twist": "twin_shot"},
	"mender+torch": {"result": "healing_lantern", "twist": "swift_heal"},
	"barricade+torch": {"result": "bonfire_wall", "twist": "regrow"},
}

static func fuse_key(a: String, b: String) -> String:
	var x := entry_id(a)
	var y := entry_id(b)
	return "%s+%s" % ([x, y] if x < y else [y, x])

func fuse_cost(tier: int) -> Dictionary:
	return {"gold": 4 * tier}

## What fusing hand cards i and j would do: {ok, reason, result (entry), cost}. "reason" says why not when ok is false.
## `cards` and `have` default to this machine's hand and resources; a LAN client passes the ones from the snapshot.
func fuse_preview(i: int, j: int, cards: Array = hand, have: Dictionary = resources) -> Dictionary:
	if i == j or i < 0 or j < 0 or i >= cards.size() or j >= cards.size():
		return {"ok": false, "reason": "Pick two different cards."}
	var r: Dictionary = FUSE_RECIPES.get(fuse_key(cards[i], cards[j]), {})
	if r.is_empty():
		return {"ok": false, "reason": "These two do not fuse."}
	if entry_tier(cards[i]) != entry_tier(cards[j]):
		return {"ok": false, "reason": "Both cards must be the same tier."}
	var t := entry_tier(cards[i])
	var cost := fuse_cost(t)
	var out := {"ok": true, "reason": "", "result": make_entry(r.result, t, r.twist), "cost": cost}
	if int(have.get("gold", 0)) < int(cost.gold):
		out.ok = false
		out.reason = "Needs %d gold in the keep." % cost.gold
	return out

func fuse_hand(i: int, j: int) -> bool:
	var p := fuse_preview(i, j)
	if !p.ok:
		return false
	pay(p.cost)
	hand.remove_at(maxi(i, j))
	hand.remove_at(mini(i, j))
	add_to_hand(p.result)
	Sfx.play("unlock", 0.0)
	hand_changed.emit()
	return true

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
		if night_level >= 0.35 and CARDS[id].get("night", false):
			w *= 3                                                              # at night, cards that make light come up much more often
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
	var e := {"light": 0.25, "damage": 0.65, "dps": 0.65, "burst": 0.65, "radius": 0.25, "duration": 0.2, "heal_per_sec": 0.7, "hp": 1.0, "thorns": 0.5, "uses": 0.4, "range": 0.12}
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
	if bk in ["barricade", "sentry", "torch"]:
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
		["hp", "Health", "%d", 1.0], ["uses", "Uses", "%d", 1.0], ["count", "Meteors" if c.kind == "meteor" else "Guards", "%d", 1.0],
		["range", "Range", "%d", 1.0], ["light", "Light radius", "%d", 1.0], ["duration", "Lasts (s)", "%.1f", 1.0], ["radius", "Radius", "%d", 1.0],
	]
	var skip_radius: bool = c.get("build", "") in ["barricade", "sentry", "torch"]
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
	return int(round(8.0 * pow(card_tier(id), 1.5) * (2.0 if is_legendary_card(id) else 1.0)))        # legendary cards cost double to raise

## Has the next tier of this card been drawn (so it may be bought with Shards)?
func upgrade_available(id: String) -> bool:
	fix_meta()
	return owns_card(id) and card_tier(id) < MAX_LEVEL and int(meta.tier_drawn.get(id, 1)) >= card_tier(id) + 1

func upgrade_card(id: String) -> bool:
	fix_meta()
	if !upgrade_available(id) or meta.shards < card_upgrade_cost(id):
		return false
	meta.shards -= card_upgrade_cost(id)
	meta.card_tiers[id] = card_tier(id) + 1
	save_meta()
	return true

func convert_value(tier: int, realm := 1) -> int:
	return 3 * tier + 2 * realm

## What converting a waiting offer pays (a legendary is worth much more than an ordinary card).
func offer_convert_value(entry: Dictionary) -> int:
	return LEGENDARY_CONVERT if entry.get("legendary", false) else convert_value(int(entry.get("tier", 1)), int(entry.get("realm", 1)))

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
# Legendary cards and weapons cannot be bought or drawn from rewards. Beating the whole game unlocks one of them.
const LEGENDARY_CARDS := ["meteor_shower", "stasis", "sunspire", "phoenix_shrine"]
const LEGENDARY_WEAPONS := ["dawnbringer", "voidreaver"]
# Reward cards at the end of a run, by the realms you opened. None unless you got past the first wave.
const REWARD_COUNT := {1: 1, 2: 3, 3: 5, 4: 6, 5: 7, 6: 8}
const WIN_REWARD_COUNT := 10
const CARD_LEVEL_OVERRIDE := {"meteor_shower": 6, "stasis": 6, "sunspire": 6, "phoenix_shrine": 6, "aegis": 2, "guards": 2, "sentry": 2, "charm": 3, "mender": 1}
# about three new weapons per level so you learn them a few at a time (the realm weapons keep their own realm)
const WEAPON_LEVEL := {"torch": 1, "spear": 1, "hammer": 1, "bow": 2, "daggers": 2, "scimitar": 2, "whip": 3, "shield": 3, "frostglaive": 3, "staff": 4, "emberflail": 4, "bogstaff": 5, "crystalwand": 6}

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
## [{kind, id, tier, realm, result: "offer"|"upgrade"|"spare"|"converted"|"unlocked", shards, cost}].
# ---------- rarity ----------
# Cards and weapons have a rarity that comes from where they are found: realm 1 is Common, then Uncommon, Rare,
# Epic, Mythic and Ancient for realms 2 to 6, and Legendary for the legendary cards and weapons. A fused weapon is one
# step rarer than the rarest weapon it is made from. Raising a card's tier never changes its rarity.
const RARITIES := [
	{"name": "Common", "color": Color("c8ccd8")},
	{"name": "Uncommon", "color": Color("5fe07a")},
	{"name": "Rare", "color": Color("5aa8ff")},
	{"name": "Epic", "color": Color("b066ff")},
	{"name": "Mythic", "color": Color("ff5a5a")},
	{"name": "Ancient", "color": Color("ff9a30")},
	{"name": "Legendary", "color": Color("ffe14a")},
]

func card_rarity(id: String) -> int:
	if is_legendary_card(id):
		return 6
	return clampi(card_level(id) - 1, 0, 5)

func weapon_rarity(id: String) -> int:
	if id in LEGENDARY_WEAPONS:
		return 6
	var parts: Array = Fusion.parts_of(id)
	if parts.size() == 2:
		return mini(5, maxi(weapon_rarity(parts[0]), weapon_rarity(parts[1])) + 1)
	if id in ["sword", "pickaxe"]:
		return 0
	return clampi(WEAPON_LEVEL.get(id, 1) - 1, 0, 5)

func rarity_of(kind: String, id: String) -> int:
	return card_rarity(id) if kind == "card" else weapon_rarity(id)

func rarity_name(r: int) -> String:
	return RARITIES[clampi(r, 0, 6)].name

func rarity_color(r: int) -> Color:
	return RARITIES[clampi(r, 0, 6)].color

## Damage multiplier of a weapon: +35% for every fusion tier above 1, +20% per bonus tier, and legendary weapons hit 50% harder.
func weapon_power(id: String, bonus: int) -> float:
	return (1.0 + 0.2 * bonus) * (1.0 + 0.35 * (Fusion.tier_of(id) - 1)) * (1.5 if id in LEGENDARY_WEAPONS else 1.0)

func is_legendary_card(id: String) -> bool:
	return CARDS.has(id) and CARDS[id].get("legendary", false)

## How many reward cards this run earns: none unless you got past the first wave (the second wave has
## started), then 1 / 3 / 5 / 6 / 7 / 8 by the realms you opened, and 10 for beating the whole game.
func reward_count(won := false) -> int:
	if won:
		return WIN_REWARD_COUNT
	if run_stats.waves < 2:
		return 0
	return REWARD_COUNT[level_reached()]

const LEGENDARY_PRICE := 400          # Shards to unlock a legendary you earned (it is kept until you do, or convert it)
const LEGENDARY_CONVERT := 150

## Beating the whole game earns a legendary card or weapon you do not have yet (a random one). It is an offer like any new
## unlock: it costs LEGENDARY_PRICE Shards, stays in your vault until you unlock or convert it, and never expires. Once every
## legendary is owned or waiting, it is worth Shards instead. Returns the reward entry.
func grant_legendary() -> Dictionary:
	fix_meta()
	var waiting := []
	for pe in meta.pending:
		waiting.append(str(pe.id))
	var left := []
	for id in LEGENDARY_CARDS:
		if !owns_card(id) and !(id in waiting):
			left.append({"kind": "card", "id": id})
	for id in LEGENDARY_WEAPONS:
		if !(id in meta.weapons) and !(id in waiting):
			left.append({"kind": "weapon", "id": id})
	if left.is_empty():
		meta.shards += 80
		return {"kind": "card", "id": LEGENDARY_CARDS.pick_random(), "tier": 1, "realm": 6, "result": "converted", "shards": 80, "legendary": true}
	var pick: Dictionary = left.pick_random()
	mark_seen(str(pick.id))
	var entry := {"kind": pick.kind, "id": pick.id, "tier": 1, "realm": 6, "result": "offer", "shards": 0, "legendary": true, "cost": LEGENDARY_PRICE}
	meta.pending.append(entry)                  # kept for good: it does not count against the vault limit
	return entry

func make_rewards(won := false) -> Array:
	fix_meta()
	var top := 6 if won else level_reached()
	var out := []
	var used := []
	# offers you have not acted on are kept (see meta.pending); drop any you got another way
	for i in range(meta.pending.size() - 1, -1, -1):
		var pe: Dictionary = meta.pending[i]
		if pe.get("result", "offer") == "offer" and ((pe.kind == "card" and owns_card(pe.id)) or (pe.kind == "weapon" and weapon_unlocked(pe.id))):
			meta.pending.remove_at(i)
	for pe in meta.pending:
		if pe.get("result", "offer") == "offer":
			used.append(pe.id if pe.kind == "card" else "w:" + pe.id)
	for i in reward_count(won):
		var entry := {"kind": "card", "id": "", "tier": 1, "realm": 1, "result": "", "shards": 0}
		var weapons := []
		for w in WEAPON_UNLOCK_COSTS:
			if !(w in meta.weapons) and !(("w:" + w) in used) and WEAPON_LEVEL[w] <= top:
				weapons.append(w)
		var tier_ups := []
		var owned_ids: Array = meta.weapons + ["sword", "pickaxe"]
		for key in Fusion.RECIPES:                          # fused weapons you can make also have higher tiers to draw
			var rid: String = Fusion.RECIPES[key].id
			if weapon_known(rid) and fusion_tier_unlocked(int(Fusion.RECIPES[key].tier)):
				owned_ids.append(rid)
		for w in owned_ids:
			var nt := weapon_tier_unlocked(w) + 1
			if nt <= 6 and nt <= top + 1 and !(("wt:" + w) in used):
				tier_ups.append(w)
		if (weapons.size() > 0 or tier_ups.size() > 0) and randf() < 0.3:
			entry.kind = "weapon"
			var from_new: bool = weapons.size() > 0 and (tier_ups.is_empty() or randf() < 0.6)
			if from_new:
				entry.id = weapons.pick_random()
				entry.realm = WEAPON_LEVEL[entry.id]
				entry.result = "offer"
				used.append("w:" + entry.id)
			else:
				entry.id = tier_ups.pick_random()
				entry.realm = WEAPON_LEVEL.get(entry.id, 1)
				entry.tier = weapon_tier_unlocked(entry.id) + 1
				entry.result = "tierup"                 # a higher tier of a weapon you own: the Forge can now take it that far
				note_weapon_tier(entry.id, int(entry.tier))
				used.append("wt:" + entry.id)
		else:
			var bag := []
			for id in CARDS:
				if id in used or CARDS[id].get("fused", false) or (is_legendary_card(id) and !owns_card(id)):
					continue                       # a legendary card cannot be offered before you have won
				var cl := card_level(id)
				if cl > top:
					continue
				var weight := 0
				if !owns_card(id):
					weight = 4 if cl == top else 3                     # something new, deeper realms favoured
				elif card_tier(id) < mini(MAX_LEVEL, top) and int(meta.tier_drawn.get(id, 1)) <= card_tier(id):
					weight = 3                                           # the next tier of something you own (not one you already drew)
				for k in weight:
					bag.append(id)
			if bag.is_empty():
				# nothing new and nothing to raise at this level: a spare is turned into Shards
				var shallow := []
				for id in CARDS:
					if card_level(id) <= top and !CARDS[id].get("fused", false) and !(is_legendary_card(id) and !owns_card(id)):
						shallow.append(id)
				entry.id = shallow.pick_random()
				entry.realm = card_level(entry.id)
				entry.tier = card_tier(entry.id) if owns_card(entry.id) else 1
				if owns_card(entry.id):
					entry.result = "spare"              # a copy of a card you own: merge it, combine it, or sell it (kept in the vault)
				else:
					entry.result = "converted"
					entry.shards = convert_value(entry.tier, entry.realm)
			else:
				entry.id = bag.pick_random()
				entry.realm = card_level(entry.id)
				used.append(entry.id)
				if owns_card(entry.id):
					entry.tier = card_tier(entry.id) + 1
					entry.result = "upgrade"                        # drawn, not applied: you pay Shards for it (collection or the reward card)
					meta.tier_drawn[entry.id] = maxi(int(meta.tier_drawn.get(entry.id, 1)), int(entry.tier))
				else:
					entry.tier = 1
					entry.result = "offer"
		if entry.result == "spare":
			if meta.pending.size() >= MAX_PENDING:
				entry.result = "converted"               # the vault is full: this copy is sold
				entry.shards = convert_value(int(entry.tier), int(entry.realm))
			else:
				meta.pending.append(entry)
		if entry.result == "offer":
			mark_seen(str(entry.id))
			entry.cost = unlock_cost(entry)
			if meta.pending.size() >= MAX_PENDING:
				entry.result = "converted"               # the vault is full: this one turns into Shards
				entry.shards = convert_value(1, int(entry.realm))
			else:
				meta.pending.append(entry)
		meta.shards += entry.shards
		out.append(entry)
	if won:
		out.append(grant_legendary())              # beating the whole game always unlocks a legendary
	save_meta()
	return out

## Shards to unlock a new reward: weapons cost what the weapon shop charges, cards cost
## more the deeper their realm.
func unlock_cost(entry: Dictionary) -> int:
	if entry.get("legendary", false):
		return LEGENDARY_PRICE
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
	entry.shards = offer_convert_value(entry)
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
