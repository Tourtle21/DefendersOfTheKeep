extends SceneTree
## Draws the pixel-art sheets for the ten enemies that used to share the goblin and blob art.
##   Godot --headless --path . --script res://tools/make_enemy_art.gd
## Blob family: 2x2 frames of 12x14 (frames 0-3 walk, 3 is the idle pose), see enemies/brute etc.
## Goblin family: 3x4 frames of 19x19 (0 idle, 1-4 attack, 5-11 walk).
## Writes enemies/<name>/<name>.png and a 6x preview to user://enemy_preview.png.

const OUT := Color(0.07, 0.05, 0.09)
const CLEAR := Color(0, 0, 0, 0)

var img: Image
var ox := 0
var oy := 0
var fw := 12
var fh := 14

func p(x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= fw or y >= fh:
		return
	img.set_pixel(ox + x, oy + y, c)

func r(x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in h:
		for i in w:
			p(x + i, y + j, c)

## Outline every frame in a dark colour so the sprites read against grass.
func outline() -> void:
	var src := img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.0:
				continue
			var fx := x % fw
			var fy := y % fh
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= img.get_width() or ny >= img.get_height():
					continue
				if int(nx / fw) != int(x / fw) or int(ny / fh) != int(y / fh):
					continue                         # never bleed into the next frame
				if src.get_pixel(nx, ny).a > 0.5:
					img.set_pixel(x, y, OUT)
					break

func begin(frame_w: int, frame_h: int, cols: int, rows: int) -> void:
	fw = frame_w
	fh = frame_h
	img = Image.create(frame_w * cols, frame_h * rows, false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)

func at(index: int, cols: int) -> void:
	ox = (index % cols) * fw
	oy = (index / cols) * fh

func save(path: String) -> void:
	outline()
	img.save_png(path)
	print("wrote ", path)

# ------------------------------------------------------------------ blob family (12 x 14)

func brute(f: int) -> void:
	var skin := Color(0.55, 0.32, 0.72)
	var dark := Color(0.38, 0.2, 0.52)
	var fist := Color(0.78, 0.55, 0.9)
	var swing: int = [0, 1, 0, -1][f]
	r(1, 4, 10, 7, skin)                       # torso
	r(1, 4, 10, 1, fist.darkened(0.15))         # shoulders
	r(1, 9, 10, 1, dark)                        # belt
	r(5, 9, 2, 1, Color(0.95, 0.8, 0.3))        # buckle
	r(4, 1, 4, 4, skin.lightened(0.12))         # head
	p(4, 1, dark); p(7, 1, dark)                # little horns
	p(5, 2, Color(1, 0.9, 0.2)); p(7, 2, Color(1, 0.9, 0.2))   # eyes
	r(5, 4, 2, 1, dark)                         # jaw
	r(0, 5 + swing, 2, 4, fist)                 # fists
	r(10, 5 - swing, 2, 4, fist)
	r(3, 11, 2, 2 + (1 if f % 2 == 0 else 0), dark)     # legs
	r(7, 11, 2, 2 + (1 if f % 2 == 1 else 0), dark)

func scarab(f: int) -> void:
	var shell := Color(0.92, 0.92, 0.88)        # light so the sector tint colours it
	var seam := Color(0.6, 0.6, 0.55)
	var leg := Color(0.55, 0.55, 0.5)
	r(2, 4, 8, 7, shell)
	r(3, 3, 6, 1, shell)
	r(3, 11, 6, 1, shell.darkened(0.15))
	r(5, 3, 2, 9, seam)                         # wing seam
	r(1, 5, 1, 1, shell); r(10, 5, 1, 1, shell)
	r(4, 1, 4, 3, shell.darkened(0.2))          # head
	p(3, 0, leg); p(8, 0, leg); p(3, 1, leg); p(8, 1, leg)   # antennae
	p(4, 2, Color(0.9, 0.1, 0.1)); p(7, 2, Color(0.9, 0.1, 0.1))
	for i in 3:                                  # three legs a side, stepping
		var s := 1 if (f + i) % 2 == 0 else 0
		r(0 + s, 5 + i * 2, 2, 1, leg)
		r(10 - s, 5 + i * 2, 2, 1, leg)
	p(2, 6, seam); p(9, 8, seam)                # shell spots

func splitter(f: int) -> void:
	var jelly := Color(0.45, 0.75, 1.0, 0.9)
	var light := Color(0.8, 0.95, 1.0, 0.95)
	var nuc := Color(0.15, 0.3, 0.7)
	var sq: int = [0, 1, 0, -1][f]                   # squash and stretch
	var widths := [4, 6, 8, 10, 10, 10, 10, 10, 9, 8, 6]
	for i in widths.size():
		var w: int = widths[i] + (sq if i > 3 and i < 9 else 0)
		r(6 - w / 2, 3 + i - (1 if sq > 0 else 0), w, 1, jelly)
	r(3, 5, 2, 2, light); p(3, 4, light)         # shine
	r(3, 8, 2, 2, nuc); r(7, 9, 2, 2, nuc)       # two nuclei, it will split in two
	p(5, 6, nuc.lightened(0.3)); p(6, 7, nuc.lightened(0.3))   # the crack where it splits
	r(2, 12, 8, 1, jelly.darkened(0.2))

func golem(f: int) -> void:
	var stone := Color(0.72, 0.62, 0.42)
	var hi := Color(0.85, 0.76, 0.55)
	var lo := Color(0.5, 0.42, 0.28)
	var moss := Color(0.35, 0.6, 0.25)
	var step: int = [0, 1, 0, 1][f]
	r(1, 3, 10, 8, stone)
	r(1, 3, 10, 1, hi)
	r(1, 10, 10, 1, lo)
	r(2, 6, 3, 1, lo); r(7, 8, 3, 1, lo); r(5, 4, 1, 3, lo)       # chiselled cracks
	r(2, 1, 8, 3, stone); r(2, 1, 8, 1, hi)                       # head block
	p(3, 2, Color(1, 0.75, 0.2)); p(8, 2, Color(1, 0.75, 0.2))    # glowing eyes
	p(3, 3, Color(1, 0.75, 0.2).darkened(0.3)); p(8, 3, Color(1, 0.75, 0.2).darkened(0.3))
	r(0, 4, 2, 6 + step, stone.darkened(0.08)); r(10, 4, 2, 6 + (1 - step), stone.darkened(0.08))   # arms
	r(0, 9 + step, 2, 2, lo); r(10, 9 + (1 - step), 2, 2, lo)     # fists
	r(2, 3, 2, 1, moss); r(8, 7, 2, 2, moss); p(6, 10, moss)      # moss
	r(3, 11, 2, 2 + step, lo); r(7, 11, 2, 2 + (1 - step), lo)    # stubby legs

func bog_lurker(f: int) -> void:
	var slime := Color(0.33, 0.55, 0.22)
	var deep := Color(0.2, 0.36, 0.14)
	var mud := Color(0.42, 0.3, 0.18)
	var wob: int = [0, 1, 0, 1][f]
	var widths := [4, 7, 9, 10, 10, 10, 9]
	for i in widths.size():
		r(6 - widths[i] / 2, 6 + i, widths[i], 1, slime if i % 3 != 2 else deep)
	r(1, 12, 10, 2, mud)                                          # half sunk in the bog
	r(3, 3 - wob, 1, 4 + wob, deep); r(8, 3, 1, 4, deep)          # eye stalks
	r(2, 1 - wob, 3, 3, Color(1.0, 0.95, 0.4)); r(7, 1, 3, 3, Color(1.0, 0.95, 0.4))
	p(3, 2 - wob, Color(0.1, 0.1, 0.1)); p(8, 2, Color(0.1, 0.1, 0.1))
	r(2, 8, 8, 2, Color(0.12, 0.08, 0.1))                          # wide mouth
	for t in [3, 5, 7]:
		p(t, 8, Color(0.95, 0.95, 0.85))
	p(2, 11, slime); p(9, 12, slime)                               # drips

func crystal_guard(f: int) -> void:
	var lite := Color(0.8, 0.62, 1.0)
	var mid := Color(0.58, 0.38, 0.9)
	var dark := Color(0.38, 0.22, 0.65)
	var core := Color(1.0, 0.85, 1.0)
	var pulse: int = [0, 1, 0, 1][f]
	var widths := [2, 4, 6, 8, 10, 10, 8, 6, 4, 2]
	for i in widths.size():
		var w: int = widths[i]
		var x0 := 6 - w / 2
		r(x0, 2 + i, w / 2, 1, lite if i < 5 else mid)               # lit facet on the left
		r(x0 + w / 2, 2 + i, w - w / 2, 1, mid if i < 5 else dark)
	r(1, 5, 2, 3, mid); p(1, 4, lite); r(9, 5, 2, 3, dark); p(10, 4, mid)   # shoulder shards
	r(5, 6, 2, 2 + pulse, core)                                    # glowing core
	p(4, 7, core.darkened(0.3)); p(7, 7, core.darkened(0.3))
	r(4, 12, 1, 2 - pulse + 1, dark); r(7, 12, 1, 1 + pulse + 1, dark)       # little feet

# ------------------------------------------------------------------ goblin family (19 x 19)

## A simple biped. cfg gives the colours and shapes; pose says where the limbs are.
func biped(cfg: Dictionary, f: int) -> void:
	var skin: Color = cfg.skin
	var dark: Color = cfg.dark
	var lean: int = cfg.get("lean", 0)
	var walk := f >= 5
	var phase := (f - 5) if walk else 0
	var bob := 1 if (walk and phase % 2 == 1) else 0
	var atk := (f - 1) if (f >= 1 and f <= 4) else -1
	var head_w: int = cfg.get("head_w", 7)
	var hx := 9 - head_w / 2 + lean
	var top := 3 + bob
	# legs
	var fwd := phase % 4 < 2
	var lh: int = cfg.get("leg_h", 4)
	r(7 + (1 if fwd and walk else 0), 14, 2, lh - (1 if walk and !fwd else 0), dark)
	r(10 - (1 if fwd and walk else 0), 14, 2, lh - (1 if walk and fwd else 0), dark)
	r(7 + (1 if fwd and walk else 0), 14 + lh - 1, 3, 1, cfg.get("foot", dark.darkened(0.2)))
	r(10 - (1 if fwd and walk else 0), 14 + lh - 1, 3, 1, cfg.get("foot", dark.darkened(0.2)))
	# body
	var bw: int = cfg.get("body_w", 5)
	r(9 - bw / 2 + lean, 8 + bob, bw, 6, skin)
	if cfg.has("belly"):
		r(9 - bw / 2 + 1 + lean, 10 + bob, bw - 2, 3, cfg.belly)
	# head
	r(hx, top, head_w, 6, skin.lightened(0.08))
	if cfg.has("ears"):
		r(hx - 2, top + 1, 2, 2, skin); r(hx + head_w, top + 1, 2, 2, skin)
		p(hx - 2, top, skin); p(hx + head_w + 1, top, skin)
	var eye: Color = cfg.get("eye", Color(1, 0.95, 0.3))
	p(hx + 1 + (1 if lean > 0 else 0), top + 2, eye); p(hx + head_w - 2 + (1 if lean > 0 else 0), top + 2, eye)
	# arms
	var arm_c: Color = cfg.get("arm", skin)
	var swing: int = [0, 1, 0, -1, 0, 1, 0][maxi(0, phase)] if walk else 0
	r(9 - bw / 2 - 2 + lean, 9 + bob + swing, 2, 4, arm_c)
	match atk:
		-1: r(9 + bw / 2 + 1 + lean, 9 + bob - swing, 2, 4, arm_c)
		0: r(9 + bw / 2 + 1 + lean, 5, 2, 4, arm_c)                  # winding up
		1: r(9 + bw / 2 + 1 + lean, 3, 2, 5, arm_c)
		2: r(9 + bw / 2 + 1 + lean, 8, 5, 2, arm_c)                  # swing out front
		3: r(9 + bw / 2 + 1 + lean, 11, 4, 2, arm_c)
	if cfg.has("extra"):
		call(cfg.extra, f, hx, top, bob, atk)

func runner_extra(f: int, hx: int, top: int, bob: int, atk: int) -> void:
	var scarf := Color(0.9, 0.15, 0.15)
	var flutter: int = [0, 1, 2, 1][f % 4]
	r(hx - 3, top + 5, 4, 1, scarf); r(hx - 5 - flutter, top + 6 + (1 if flutter == 1 else 0), 3, 1, scarf)
	r(hx + 5, top - 1, 1, 2, Color(0.6, 0.35, 0.15))           # pointy ear tuft
	p(hx + 2, top + 3, Color(0.2, 0.1, 0.05)); p(hx + 3, top + 3, Color(0.2, 0.1, 0.05))   # grim line

func spitter_extra(f: int, hx: int, top: int, bob: int, atk: int) -> void:
	var goo := Color(0.85, 1.0, 0.3)
	r(hx + 1, top + 3, 5, 2, Color(0.1, 0.18, 0.08))           # open mouth
	var drip: int = [0, 1, 2, 1][f % 4]
	p(hx + 3, top + 5 + drip, goo); p(hx + 2, top + 5, goo)
	r(hx - 1, top + 3, 1, 2, Color(0.4, 0.75, 0.3)); r(hx + 7, top + 3, 1, 2, Color(0.4, 0.75, 0.3))   # puffed cheeks
	p(9, 11 + bob, Color(0.7, 0.9, 0.3)); p(10, 12 + bob, Color(0.7, 0.9, 0.3))                     # warts

func ember_extra(f: int, hx: int, top: int, bob: int, atk: int) -> void:
	var fire := [Color(1, 0.85, 0.2), Color(1, 0.55, 0.1), Color(0.9, 0.25, 0.1)]
	var fl := f % 3
	r(hx - 1, top - 2, 1, 3, Color(0.25, 0.08, 0.05)); r(hx + 7, top - 2, 1, 3, Color(0.25, 0.08, 0.05))   # horns
	var tx := 5
	r(tx, 12 + bob, 2, 1, Color(0.55, 0.15, 0.1))                                                          # tail
	r(tx - 2, 10 + bob - fl % 2, 2, 3, fire[(fl + 1) % 3]); r(tx - 1, 9 + bob - fl, 1, 2, fire[fl])       # tail flame
	p(tx - 1, 8 + bob - fl, fire[0])
	p(hx + 3, top + 4, Color(0.2, 0.05, 0.02)); p(hx + 4, top + 4, Color(0.2, 0.05, 0.02))              # fangs / grin

func frost_extra(f: int, hx: int, top: int, bob: int, atk: int) -> void:
	var ice := Color(0.85, 0.97, 1.0)
	var mid := Color(0.55, 0.8, 1.0)
	r(hx + 1, top - 3, 1, 3, ice); r(hx + 3, top - 4, 1, 4, ice); r(hx + 5, top - 3, 1, 3, ice)   # ice crown
	p(hx + 3, top - 5, Color.WHITE)
	r(hx + 1, top + 4, 5, 1, mid)                                                                    # frosty beard
	var tw := f % 3
	p(3 + tw, 6 + bob, Color.WHITE); p(15 - tw, 10, ice)                                              # drifting snow

func bakes() -> void:
	# ---- blob family
	var blobs := {"brute": "brute", "scarab": "scarab", "splitter": "splitter", "golem": "golem", "bog_lurker": "bog_lurker", "crystal_guard": "crystal_guard"}
	for name in blobs:
		begin(12, 14, 2, 2)
		for f in 4:
			at(f, 2)
			call(blobs[name], f)
		save("res://enemies/%s/%s.png" % [name, name])
	# ---- goblin family
	var gobs := {
		"runner": {"skin": Color(0.9, 0.55, 0.25), "dark": Color(0.55, 0.3, 0.12), "body_w": 4, "head_w": 6, "lean": 2, "leg_h": 5, "ears": true, "eye": Color(1, 1, 0.5), "extra": "runner_extra", "belly": Color(0.98, 0.8, 0.5)},
		"spitter": {"skin": Color(0.45, 0.78, 0.32), "dark": Color(0.25, 0.45, 0.18), "body_w": 7, "head_w": 8, "lean": -1, "leg_h": 3, "eye": Color(1, 0.9, 0.2), "extra": "spitter_extra", "belly": Color(0.7, 0.9, 0.4)},
		"ember_imp": {"skin": Color(0.9, 0.3, 0.15), "dark": Color(0.5, 0.12, 0.08), "body_w": 5, "head_w": 7, "leg_h": 4, "ears": true, "eye": Color(1, 0.95, 0.4), "extra": "ember_extra", "belly": Color(1, 0.6, 0.2)},
		"frost_imp": {"skin": Color(0.55, 0.78, 0.95), "dark": Color(0.3, 0.5, 0.75), "body_w": 5, "head_w": 7, "leg_h": 4, "ears": true, "eye": Color(0.15, 0.2, 0.6), "extra": "frost_extra", "belly": Color(0.92, 0.98, 1.0)},
	}
	for name in gobs:
		begin(19, 19, 3, 4)
		for f in 12:
			at(f, 3)
			biped(gobs[name], f)
		save("res://enemies/%s/%s.png" % [name, name])

func _initialize() -> void:
	bakes()
	# preview: every sheet side by side, 6x
	var names := ["brute", "scarab", "splitter", "golem", "bog_lurker", "crystal_guard", "runner", "spitter", "ember_imp", "frost_imp"]
	var sheets := []
	var total_w := 0
	var max_h := 0
	for n in names:
		var im := Image.load_from_file(ProjectSettings.globalize_path("res://enemies/%s/%s.png" % [n, n]))
		sheets.append(im)
		total_w += im.get_width() + 4
		max_h = maxi(max_h, im.get_height())
	var sheet := Image.create(total_w, max_h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.35, 0.55, 0.3))
	var x := 0
	for im in sheets:
		sheet.blend_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i(x, 0))
		x += im.get_width() + 4
	sheet.resize(total_w * 6, max_h * 6, Image.INTERPOLATE_NEAREST)
	sheet.save_png("user://enemy_preview.png")
	quit()
