extends RefCounted
class_name Skills
## The permanent skill tree, bought with Shards. Five branches; a skill unlocks once
## everything in its "req" has at least one level. Each level of a skill adds `per` to
## its bonus `key` (read with Game.bonus(key)); cost of the next level = cost * (level + 1).
## pos = [column, row] in the tree screen.

const BRANCHES := {
	"keep": {"name": "Keep", "color": Color(0.85, 0.6, 0.35)},
	"magic": {"name": "Magic", "color": Color(0.5, 0.65, 1.0)},
	"warrior": {"name": "Warrior", "color": Color(1.0, 0.5, 0.45)},
	"economy": {"name": "Economy", "color": Color(1.0, 0.85, 0.3)},
	"builder": {"name": "Builder", "color": Color(0.55, 0.9, 0.5)},
}

# fmt: "n" = plain number, "p" = percent (value * 100)
const TREE := {
	"keep_hp": {"name": "Stronger Keep", "branch": "keep", "pos": [0.5, 0], "req": [], "max": 5, "cost": 6, "key": "keep_hp", "per": 15.0, "fmt": "n", "unit": " keep HP"},
	"fortify": {"name": "Fortify", "branch": "keep", "pos": [0, 1], "req": ["keep_hp"], "max": 4, "cost": 8, "key": "fortify", "per": 0.05, "fmt": "p", "unit": " less keep damage"},
	"repair": {"name": "Masonry", "branch": "keep", "pos": [1, 1], "req": ["keep_hp"], "max": 3, "cost": 7, "key": "repair", "per": 10.0, "fmt": "n", "unit": " extra HP per repair"},
	"mana_pool": {"name": "Deep Well", "branch": "magic", "pos": [0.5, 0], "req": [], "max": 5, "cost": 5, "key": "mana_max", "per": 10.0, "fmt": "n", "unit": " max mana"},
	"mana_regen": {"name": "Focus", "branch": "magic", "pos": [0, 1], "req": ["mana_pool"], "max": 5, "cost": 6, "key": "mana_regen", "per": 0.4, "fmt": "n", "unit": " mana/sec"},
	"spell_radius": {"name": "Wide Casting", "branch": "magic", "pos": [1, 1], "req": ["mana_pool"], "max": 5, "cost": 6, "key": "spell_radius", "per": 0.05, "fmt": "p", "unit": " spell radius"},
	"spell_power": {"name": "Arcane Power", "branch": "magic", "pos": [0, 2], "req": ["mana_regen"], "max": 5, "cost": 8, "key": "spell_power", "per": 0.08, "fmt": "p", "unit": " spell damage and healing"},
	"draw_speed": {"name": "Quick Hands", "branch": "magic", "pos": [1, 2], "req": ["spell_radius"], "max": 4, "cost": 8, "key": "draw_speed", "per": 0.08, "fmt": "p", "unit": " faster card draw"},
	"weapon_dmg": {"name": "Sharpened Steel", "branch": "warrior", "pos": [0.5, 0], "req": [], "max": 5, "cost": 6, "key": "weapon_dmg", "per": 0.06, "fmt": "p", "unit": " weapon damage"},
	"weapon_cd": {"name": "Swift Strikes", "branch": "warrior", "pos": [0, 1], "req": ["weapon_dmg"], "max": 5, "cost": 7, "key": "weapon_cd", "per": 0.03, "fmt": "p", "unit": " shorter cooldowns"},
	"move_speed": {"name": "Fleet Foot", "branch": "warrior", "pos": [1, 1], "req": ["weapon_dmg"], "max": 5, "cost": 6, "key": "move_speed", "per": 0.03, "fmt": "p", "unit": " move speed"},
	"ult_cd": {"name": "Ultimate Focus", "branch": "warrior", "pos": [0, 2], "req": ["weapon_cd"], "max": 4, "cost": 8, "key": "ult_cd", "per": 0.05, "fmt": "p", "unit": " shorter ultimate cooldown"},
	"gold_find": {"name": "Lucky Coins", "branch": "economy", "pos": [0.5, 0], "req": [], "max": 5, "cost": 6, "key": "gold_chance", "per": 0.1, "fmt": "p", "unit": " chance of bonus gold"},
	"start_mats": {"name": "Supply Cache", "branch": "economy", "pos": [0, 1], "req": ["gold_find"], "max": 4, "cost": 5, "key": "start_mats", "per": 3.0, "fmt": "n", "unit": " stone and sticks at start"},
	"chest_rate": {"name": "Treasure Sense", "branch": "economy", "pos": [1, 1], "req": ["gold_find"], "max": 5, "cost": 6, "key": "chest_rate", "per": 0.06, "fmt": "p", "unit": " more frequent chests"},
	"shard_bonus": {"name": "Soul Harvest", "branch": "economy", "pos": [1, 2], "req": ["start_mats", "chest_rate"], "max": 5, "cost": 10, "key": "shard_bonus", "per": 0.08, "fmt": "p", "unit": " Shards per run"},
	"prospector": {"name": "Prospector", "branch": "economy", "pos": [0, 2], "req": ["start_mats"], "max": 5, "cost": 6, "key": "yield_basic", "per": 0.1, "fmt": "p", "unit": " chance of extra stone and sticks"},
	"deep_veins": {"name": "Deep Veins", "branch": "economy", "pos": [0, 3], "req": ["prospector"], "max": 5, "cost": 9, "key": "yield_rare", "per": 0.12, "fmt": "p", "unit": " chance of extra iron, frost, ember, moss, gems"},
	"overclock": {"name": "Overclock", "branch": "economy", "pos": [1, 3], "req": ["deep_veins", "shard_bonus"], "max": 4, "cost": 9, "key": "gen_speed", "per": 0.15, "fmt": "p", "unit": " faster resource generators"},
	"rare_draw": {"name": "Rare Draws", "branch": "magic", "pos": [1, 3], "req": ["draw_speed"], "max": 5, "cost": 10, "key": "rare_level", "per": 1.0, "fmt": "rare", "unit": ""},
	"mana_kill": {"name": "Soul Siphon", "branch": "magic", "pos": [0, 3], "req": ["spell_power"], "max": 4, "cost": 9, "key": "mana_kill", "per": 0.5, "fmt": "n", "unit": " mana per kill"},
	"dash_cd": {"name": "Nimble Dash", "branch": "warrior", "pos": [1, 2], "req": ["move_speed"], "max": 4, "cost": 7, "key": "dash_cd", "per": 0.07, "fmt": "p", "unit": " shorter dash cooldown"},
	"turret_ammo": {"name": "Arsenal", "branch": "keep", "pos": [0.5, 2], "req": ["fortify", "repair"], "max": 4, "cost": 8, "key": "turret_ammo", "per": 4.0, "fmt": "n", "unit": " turret ammo"},
	"build_hp": {"name": "Sturdy Builds", "branch": "builder", "pos": [0.5, 0], "req": [], "max": 5, "cost": 6, "key": "build_power", "per": 0.1, "fmt": "p", "unit": " structure health and damage"},
	"build_life": {"name": "Lasting Craft", "branch": "builder", "pos": [0, 1], "req": ["build_hp"], "max": 5, "cost": 6, "key": "build_life", "per": 0.12, "fmt": "p", "unit": " structure duration"},
	"build_cap": {"name": "Master Builder", "branch": "builder", "pos": [1, 1], "req": ["build_hp"], "max": 3, "cost": 10, "key": "build_cap", "per": 2.0, "fmt": "n", "unit": " max structures"},
}

const RARE_TEXT := ["no higher tiers", "10% tier 2", "15% tier 2, 1% tier 3", "20% tier 2, 3% tier 3", "25% tier 2, 5% tier 3, 1% tier 4", "30% tier 2, 8% tier 3, 2% tier 4"]

static func effect_text(id: String, level: int) -> String:
	var s: Dictionary = TREE[id]
	if s.fmt == "rare":
		return "Cards you draw can come in higher: " + RARE_TEXT[clampi(level, 0, 5)]
	var v: float = s.per * level
	if s.fmt == "p":
		return "+%d%%%s" % [int(round(v * 100.0)), s.unit]
	if v == int(v):
		return "+%d%s" % [int(v), s.unit]
	return "+%.1f%s" % [v, s.unit]
