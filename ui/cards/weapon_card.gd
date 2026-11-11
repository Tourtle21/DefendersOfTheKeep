extends RefCounted
## ONE weapon card. Every screen that shows a weapon as a card (the end-of-run rewards, the Drawn tab, the weapon codex, the
## Forge) builds it here, so a weapon always looks the same: the card layout spells and buildings use (frame, art window, name
## banner, text box, tier badge top-right "T2"), in the weapon frame, with a thin rarity-coloured line inside it. A screen passes only what is special about it (a footer, lines, a locked look) in `extra`,
## which overrides the defaults.

const FRAME := "res://ui/cards/frame_weapon.png"          # chamfered corners and a steel border: spells are rounded, buildings brick
const TierCard = preload("res://ui/cards/tier_card.gd")
const UiKit = preload("res://ui/cards/ui_kit.gd")

## The weapon's icon (the sword and pickaxe are sprite sheets: UiKit.weapon_icon shows their first frame), or null.
static func icon(id: String) -> Texture2D:
	var info: Dictionary = load("res://world/item_info.tres").items.get(id, {})
	return UiKit.weapon_icon(str(info.texture)) if info.has("texture") else null

static func make(id: String, tier: int, size: Vector2, extra := {}) -> TierCard:
	var data := {"size": size, "title": Fusion.display_name(id), "icon": icon(id), "tier": tier,
		"frame": FRAME, "accent": Game.rarity_color(Game.weapon_rarity(id))}
	data.merge(extra, true)
	var card := TierCard.new()
	card.setup(data)
	return card
