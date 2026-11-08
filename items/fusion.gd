extends RefCounted
class_name Fusion
## Weapon fusion: two weapons of the same tier make a stronger, re-learned weapon
## at the Forge. Only listed recipes exist (discovering them is part of the game).
## Tier 3 needs two tier-2 weapons, and so on.

# key = the two ingredient ids sorted alphabetically and joined by "+"
const RECIPES := {
	"hammer+spear": {"id": "lance", "tier": 2},
	"bow+staff": {"id": "warpbow", "tier": 2},
	"daggers+whip": {"id": "chainfangs", "tier": 2},
	"hammer+shield": {"id": "bulwark", "tier": 2},
	"shield+sword": {"id": "knightblade", "tier": 2},
	"hammer+pickaxe": {"id": "quakepick", "tier": 2},
	"staff+whip": {"id": "tempest", "tier": 2},
	"daggers+spear": {"id": "rapier", "tier": 2},
	"staff+sword": {"id": "spellblade", "tier": 2},
	"scimitar+shield": {"id": "sultanguard", "tier": 2},
	"frostglaive+spear": {"id": "rimelance", "tier": 2},
	"emberflail+hammer": {"id": "magmamaul", "tier": 2},
	"bogstaff+staff": {"id": "witchstaff", "tier": 2},
	"crystalwand+staff": {"id": "prismstaff", "tier": 2},
	"tempest+warpbow": {"id": "stormbow", "tier": 3},
	"bulwark+knightblade": {"id": "juggernaut", "tier": 3},
	"lance+rapier": {"id": "dragoonpike", "tier": 3},
	"chainfangs+spellblade": {"id": "soulreaper", "tier": 3},
	"bulwark+quakepick": {"id": "earthshaker", "tier": 3},
	"spellblade+tempest": {"id": "starfall", "tier": 3},
	"earthshaker+juggernaut": {"id": "worldbreaker", "tier": 4},
}

const NAMES := {
	"sword": "Sword", "pickaxe": "Pickaxe", "spear": "Spear", "hammer": "Hammer",
	"bow": "Bow", "torch": "Torch", "dawnbringer": "Dawnbringer", "voidreaver": "Voidreaver", "daggers": "Twin Daggers", "whip": "Whip", "shield": "Shield", "staff": "Staff",
	"lance": "Siege Lance", "warpbow": "Warp Bow", "chainfangs": "Chain Fangs",
	"bulwark": "Bulwark Maul", "knightblade": "Knight's Blade", "quakepick": "Quake Pick",
	"tempest": "Tempest Lash", "rapier": "Rapier", "spellblade": "Spellblade",
	"scimitar": "Scimitar", "frostglaive": "Frost Glaive", "emberflail": "Ember Flail", "bogstaff": "Bog Staff", "crystalwand": "Crystal Wand",
	"sultanguard": "Sultan's Guard", "rimelance": "Rimelance", "magmamaul": "Magma Maul", "witchstaff": "Witch Staff", "prismstaff": "Prismatic Staff",
	"stormbow": "Stormcaller Bow", "juggernaut": "Juggernaut",
	"dragoonpike": "Dragoon Pike", "soulreaper": "Soulreaper", "earthshaker": "Earthshaker",
	"starfall": "Starfall", "worldbreaker": "Worldbreaker",
}

const TIER_ABILITY := {
	"lance": "Charge (hold)", "warpbow": "Warp Arrow", "chainfangs": "Grapple",
	"bulwark": "Brace (hold)", "knightblade": "Riposte", "quakepick": "Fissure",
	"tempest": "Thunderclap", "rapier": "Fleche", "spellblade": "Blade Storm",
	"sultanguard": "Riposte Wave", "rimelance": "Glaive Throw", "magmamaul": "Magma Slam", "witchstaff": "Hex", "prismstaff": "Prism Beam",
	"stormbow": "Storm Warp", "juggernaut": "Fortress (hold)",
	"dragoonpike": "Charge + chain lunges", "soulreaper": "Grapple (exposes group)", "earthshaker": "Triple Fissure",
	"starfall": "Blade Storm (charges)", "worldbreaker": "Fortress + eruptions",
}

static func key(a: String, b: String) -> String:
	var l := [a, b]
	l.sort()
	return "+".join(l)

static func recipe(a: String, b: String) -> Dictionary:
	return RECIPES.get(key(a, b), {})

static func tier_of(id: String) -> int:
	for k in RECIPES:
		if RECIPES[k].id == id:
			return RECIPES[k].tier
	return 1

static func parts_of(id: String) -> Array:
	for k in RECIPES:
		if RECIPES[k].id == id:
			return k.split("+")
	return []

static func cost(tier: int) -> Dictionary:
	var c := {"gold": [0, 0, 10, 25, 50][clampi(tier, 0, 4)]}
	if tier >= 3:
		c["iron"] = 6 * (tier - 2)      # sector resources are needed for the higher tiers
	if tier >= 4:
		c["gem"] = 4
	return c

static func display_name(id: String) -> String:
	return NAMES.get(id, id.capitalize())

## Awakening at the Forge: +1 tier on the weapon you hold (max 6) for gold and
## materials. Each step needs a resource from further out, so the deepest tiers
## need the farthest sectors.
const AWAKEN_COSTS := {
	1: {"gold": 6, "stone": 3},
	2: {"gold": 10, "stick": 4},
	3: {"gold": 15, "iron": 4},
	4: {"gold": 20, "frost": 4, "ember": 4},
	5: {"gold": 30, "moss": 4, "gem": 4},
}

## What a tier unlocks, for UI text.
const TIER_TEXT := {
	1: "Attack and dash attack",
	2: "Unlocks the right-click ability",
	3: "Unlocks the ultimate (Space)",
	4: "Awakened: +20% damage, -8% cooldowns",
	5: "Awakened: +40% damage, -16% cooldowns",
	6: "Awakened: +60% damage, -24% cooldowns",
}
