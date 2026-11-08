extends PointLight2D
class_name GlowLight
## A soft light that only shows at night (it follows Game.night_level), so torches, flares and fire
## spells cut a bright hole in the darkness and cost nothing in daylight. Attach it to any node.

static var _tex: GradientTexture2D

static func soft_texture() -> GradientTexture2D:
	if _tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_tex = GradientTexture2D.new()
		_tex.gradient = g
		_tex.fill = GradientTexture2D.FILL_RADIAL
		_tex.fill_from = Vector2(0.5, 0.5)
		_tex.fill_to = Vector2(1.0, 0.5)
		_tex.width = 128
		_tex.height = 128
	return _tex

var base_energy := 0.55

## Adds a glow of `radius` world pixels to `node` (returns it so the caller can change it later).
static func attach(node: Node, radius: float, color := Color(1.0, 0.85, 0.55), energy := 0.55) -> GlowLight:
	var l := GlowLight.new()
	l.texture = soft_texture()
	l.texture_scale = maxf(0.1, radius * 2.0 / 128.0)
	l.color = color
	l.base_energy = energy
	l.energy = 0.0
	l.shadow_enabled = false
	node.add_child(l)
	return l

func _process(_delta: float) -> void:
	energy = base_energy * Game.night_level
