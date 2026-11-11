extends RefCounted
## ONE weapon card: a CardView in weapon mode, so it is laid out exactly like spell and building cards (frame, art window, name
## banner, text box, tier badge top-right), in the weapon frame with a thin rarity-coloured line inside it. Every screen that
## shows a weapon as a card (the end-of-run rewards, the Drawn tab, the weapon codex, the Forge) builds it here. A screen passes only
## what is special about it (lines, a footer, a locked look) in `extra`, which overrides the defaults.

const UiKit = preload("res://ui/cards/ui_kit.gd")

## The weapon's icon (the sword and pickaxe are sprite sheets: UiKit.weapon_icon shows their first frame), or null.
static func icon(id: String) -> Texture2D:
	var info: Dictionary = load("res://world/item_info.tres").items.get(id, {})
	return UiKit.weapon_icon(str(info.texture)) if info.has("texture") else null

static func make(id: String, tier: int, size: Vector2, extra := {}) -> CardView:
	var data := {"title": Fusion.display_name(id), "icon": icon(id), "accent": Game.rarity_color(Game.weapon_rarity(id))}
	data.merge(extra, true)
	var card := CardView.new()
	card.setup_weapon(id, tier, data, size)
	return card
