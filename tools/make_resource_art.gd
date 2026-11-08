extends SceneTree
## Tinted copies of the stone icon for each sector resource.
## Run:  Godot --path . --headless --script res://tools/make_resource_art.gd
const TINTS := {
	"iron": Color(0.75, 0.55, 0.5), "frost": Color(0.6, 0.85, 1.2), "ember": Color(1.3, 0.55, 0.25),
	"moss": Color(0.55, 0.95, 0.45), "gem": Color(0.95, 0.6, 1.2),
}
func _initialize() -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path("res://collectables/rock/stone.png"))
	src.convert(Image.FORMAT_RGBA8)
	for id in TINTS:
		var img := src.duplicate() as Image
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0:
					img.set_pixel(x, y, Color(clamp(c.r * TINTS[id].r, 0, 1), clamp(c.g * TINTS[id].g, 0, 1), clamp(c.b * TINTS[id].b, 0, 1), c.a))
		img.save_png(ProjectSettings.globalize_path("res://collectables/sector/%s.png" % id))
	print("resource art written")
	quit()
