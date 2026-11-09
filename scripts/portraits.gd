class_name Portraits
extends RefCounted
## 0.13: procedural faces for bartenders, regulars, hired pilots and wanted
## posters. Same seed, same face.

const SKINS := [Color(0.98, 0.82, 0.68), Color(0.87, 0.66, 0.5), Color(0.68, 0.47, 0.33), Color(0.45, 0.3, 0.2),
	Color(0.62, 0.8, 0.95), Color(0.65, 0.9, 0.7), Color(0.85, 0.7, 0.95), Color(0.95, 0.72, 0.72)]
const HAIRS := [Color(0.12, 0.1, 0.1), Color(0.45, 0.28, 0.15), Color(0.85, 0.7, 0.4), Color(0.9, 0.9, 0.92),
	Color(0.9, 0.35, 0.3), Color(0.35, 0.75, 1.0), Color(0.8, 0.45, 0.95), Color(0.4, 0.95, 0.6)]


static func draw(ci: CanvasItem, r: Rect2, seed_val: int, bg := Color(0.08, 0.13, 0.2)) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y)
	ci.draw_rect(r, bg)
	ci.draw_circle(c + Vector2(0, s * 0.05), s * 0.46, Color(bg.lightened(0.12), 1.0))
	var skin: Color = SKINS[rng.randi() % SKINS.size()]
	var hair: Color = HAIRS[rng.randi() % HAIRS.size()]
	var shirt := Color.from_hsv(rng.randf(), 0.45, 0.55)
	# shoulders
	_ellipse(ci, c + Vector2(0, s * 0.52), Vector2(s * 0.42, s * 0.22), shirt)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.07, s * 0.18), Vector2(s * 0.14, s * 0.14)), skin.darkened(0.1))
	# ears / alien ears
	var ear := rng.randi() % 4
	var hw := s * rng.randf_range(0.2, 0.25)
	var hh := s * rng.randf_range(0.26, 0.31)
	if ear == 3:
		for sx in [-1.0, 1.0]:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(sx * hw * 0.8, -hh * 0.1), c + Vector2(sx * hw * 1.9, -hh * 0.7), c + Vector2(sx * hw * 0.9, hh * 0.25)]), skin.darkened(0.08))
	else:
		for sx in [-1.0, 1.0]:
			_ellipse(ci, c + Vector2(sx * hw, 0), Vector2(s * 0.05, s * 0.07), skin.darkened(0.08))
	# head
	_ellipse(ci, c, Vector2(hw, hh), skin)
	# hair styles
	match rng.randi() % 6:
		0:
			_ellipse(ci, c + Vector2(0, -hh * 0.62), Vector2(hw * 1.05, hh * 0.5), hair)
		1:
			for k in 7:
				var a := PI + PI * k / 6.0
				ci.draw_circle(c + Vector2(cos(a) * hw, sin(a) * hh * 0.9), s * 0.07, hair)
		2:
			ci.draw_rect(Rect2(c + Vector2(-hw * 0.25, -hh * 1.25), Vector2(hw * 0.5, hh * 0.6)), hair)
		3:
			_ellipse(ci, c + Vector2(0, -hh * 0.55), Vector2(hw * 1.1, hh * 0.55), hair)
			ci.draw_rect(Rect2(c + Vector2(-hw * 1.1, -hh * 0.5), Vector2(hw * 0.35, hh * 1.3)), hair)
			ci.draw_rect(Rect2(c + Vector2(hw * 0.75, -hh * 0.5), Vector2(hw * 0.35, hh * 1.3)), hair)
		4:
			pass   # bald and proud
		5:
			# cap
			_ellipse(ci, c + Vector2(0, -hh * 0.7), Vector2(hw * 1.05, hh * 0.42), shirt.darkened(0.3))
			ci.draw_rect(Rect2(c + Vector2(-hw * 0.2, -hh * 0.62), Vector2(hw * 1.5, hh * 0.13)), shirt.darkened(0.4))
	# eyes
	var ey := c.y - hh * 0.08
	var ex := hw * 0.42
	var eye_kind := rng.randi() % 4
	for sx in [-1.0, 1.0]:
		var e := Vector2(c.x + sx * ex, ey)
		match eye_kind:
			0:
				ci.draw_circle(e, s * 0.032, Color(1, 1, 1))
				ci.draw_circle(e + Vector2(0, s * 0.006), s * 0.018, Color(0.1, 0.1, 0.15))
			1:
				ci.draw_line(e - Vector2(s * 0.03, 0), e + Vector2(s * 0.03, 0), Color(0.1, 0.08, 0.08), 2.5, true)
			2:
				ci.draw_circle(e, s * 0.028, Color(0.1, 0.1, 0.15))
			3:
				_ellipse(ci, e, Vector2(s * 0.04, s * 0.028), Color(0.95, 0.95, 0.6))
				ci.draw_line(e - Vector2(0, s * 0.02), e + Vector2(0, s * 0.02), Color(0.1, 0.1, 0.1), 2.0)
	# brows
	if rng.randf() < 0.7:
		for sx in [-1.0, 1.0]:
			var b := Vector2(c.x + sx * ex, ey - s * 0.055)
			ci.draw_line(b - Vector2(s * 0.035, rng.randf_range(-0.01, 0.01) * s), b + Vector2(s * 0.035, 0), hair.darkened(0.2), 2.5, true)
	# mouth
	var my := c.y + hh * 0.48
	match rng.randi() % 4:
		0:
			ci.draw_arc(Vector2(c.x, my - s * 0.03), s * 0.06, PI * 0.15, PI * 0.85, 10, Color(0.35, 0.12, 0.12), 2.5, true)
		1:
			ci.draw_line(Vector2(c.x - s * 0.05, my), Vector2(c.x + s * 0.05, my), Color(0.35, 0.12, 0.12), 2.5, true)
		2:
			_ellipse(ci, Vector2(c.x, my), Vector2(s * 0.035, s * 0.025), Color(0.35, 0.1, 0.12))
		3:
			ci.draw_arc(Vector2(c.x + s * 0.02, my - s * 0.02), s * 0.05, PI * 0.1, PI * 0.7, 10, Color(0.35, 0.12, 0.12), 2.5, true)
	# extras: beard, goggles, cyber eye, earring, antenna
	var extra := rng.randi() % 7
	match extra:
		0:
			_ellipse(ci, Vector2(c.x, my + s * 0.03), Vector2(hw * 0.75, hh * 0.32), hair)
			ci.draw_line(Vector2(c.x - s * 0.04, my - s * 0.005), Vector2(c.x + s * 0.04, my - s * 0.005), Color(0.3, 0.1, 0.1), 2.0)
		1:
			for sx in [-1.0, 1.0]:
				ci.draw_arc(Vector2(c.x + sx * ex, ey), s * 0.055, 0, TAU, 16, Color(0.75, 0.6, 0.3), 3.0, true)
			ci.draw_line(Vector2(c.x - ex - s * 0.055, ey), Vector2(c.x - hw, ey - s * 0.01), Color(0.3, 0.25, 0.2), 3.0)
			ci.draw_line(Vector2(c.x + ex + s * 0.055, ey), Vector2(c.x + hw, ey - s * 0.01), Color(0.3, 0.25, 0.2), 3.0)
		2:
			ci.draw_circle(Vector2(c.x + ex, ey), s * 0.045, Color(0.2, 0.22, 0.25))
			ci.draw_circle(Vector2(c.x + ex, ey), s * 0.022, Color(1.0, 0.25, 0.2))
		3:
			ci.draw_circle(Vector2(c.x - hw - s * 0.01, c.y + s * 0.06), s * 0.015, Color(1.0, 0.85, 0.3))
		4:
			for sx in [-1.0, 1.0]:
				ci.draw_line(Vector2(c.x + sx * hw * 0.4, c.y - hh * 0.9), Vector2(c.x + sx * hw * 0.8, c.y - hh * 1.5), skin.darkened(0.3), 2.5, true)
				ci.draw_circle(Vector2(c.x + sx * hw * 0.8, c.y - hh * 1.5), s * 0.025, Color(1.0, 0.8, 0.3))
	# cheeks
	if rng.randf() < 0.5:
		for sx in [-1.0, 1.0]:
			ci.draw_circle(Vector2(c.x + sx * hw * 0.62, c.y + hh * 0.22), s * 0.03, Color(1.0, 0.45, 0.45, 0.25))


static func _ellipse(ci: CanvasItem, c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts, col)


## A Control that shows one portrait.
static func control(seed_val: int, sz := Vector2(96, 96), bg := Color(0.08, 0.13, 0.2)) -> Control:
	var c := Control.new()
	c.custom_minimum_size = sz
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.draw.connect(func(): Portraits.draw(c, Rect2(Vector2.ZERO, c.size), seed_val, bg))
	return c
