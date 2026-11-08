class_name UiKit
extends RefCounted
## Shared fonts, colors, theme and vector icons for the UI.

const ACCENT := Color(0.45, 0.85, 1.0)
const GOLD := Color(1.0, 0.86, 0.45)
const GOOD := Color(0.45, 1.0, 0.65)
const BAD := Color(1.0, 0.42, 0.38)
const PANEL := Color(0.03, 0.05, 0.09, 0.86)
const TEXT_DIM := Color(0.68, 0.75, 0.86)

static var _fonts := {}


static func _font(file: String, weight: int, spacing := 0) -> Font:
	var key := "%s_%d_%d" % [file, weight, spacing]
	if not _fonts.has(key):
		var base: FontFile = load("res://assets/fonts/" + file)
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		if spacing != 0:
			fv.spacing_glyph = spacing
		_fonts[key] = fv
	return _fonts[key]


## Orbitron: headings, numbers, buttons.
static func display(weight := 700, spacing := 0) -> Font:
	return _font("Orbitron.ttf", weight, spacing)


## Exo 2: body text.
static func body(weight := 500) -> Font:
	return _font("Exo2.ttf", weight)


static func box(bg: Color, border: Color, radius := 6, border_w := 1, margin := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.7
	s.content_margin_bottom = margin * 0.7
	s.anti_aliasing = true
	return s


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = body(500)
	t.default_font_size = 22
	t.set_stylebox("panel", "PanelContainer", box(PANEL, Color(ACCENT, 0.35)))
	t.set_stylebox("panel", "Panel", box(PANEL, Color(ACCENT, 0.35)))
	t.set_font("font", "Button", display(600))
	t.set_font_size("font_size", "Button", 18)
	t.set_stylebox("normal", "Button", box(Color(0.08, 0.16, 0.26, 0.95), Color(ACCENT, 0.55), 4, 1, 16))
	t.set_stylebox("hover", "Button", box(Color(0.12, 0.24, 0.38, 0.95), Color(ACCENT, 0.9), 4, 1, 16))
	t.set_stylebox("pressed", "Button", box(Color(0.2, 0.42, 0.6, 0.98), Color(1, 1, 1, 0.9), 4, 2, 16))
	t.set_stylebox("hover_pressed", "Button", box(Color(0.2, 0.42, 0.6, 0.98), Color(1, 1, 1, 0.9), 4, 2, 16))
	t.set_stylebox("disabled", "Button", box(Color(0.06, 0.08, 0.11, 0.8), Color(0.3, 0.35, 0.4, 0.4), 4, 1, 16))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color(0.92, 0.97, 1.0))
	t.set_color("font_disabled_color", "Button", Color(0.42, 0.47, 0.52))
	t.set_color("font_color", "Label", Color(0.92, 0.96, 1.0))
	var grab := StyleBoxFlat.new()
	grab.bg_color = ACCENT
	grab.set_corner_radius_all(10)
	t.set_stylebox("slider", "HSlider", box(Color(0.1, 0.15, 0.22), Color(ACCENT, 0.4), 6, 1, 4))
	t.set_stylebox("grabber_area", "HSlider", box(Color(ACCENT, 0.6), Color(ACCENT, 0.0), 6, 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(Color(ACCENT, 0.8), Color(ACCENT, 0.0), 6, 0, 4))
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	return t


static func pop(c: Control) -> void:
	## Satisfying press feedback: quick squash and elastic return.
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(0.94, 0.94), 0.05)
	tw.tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# --- vector icons ------------------------------------------------------------

static func icon(ci: CanvasItem, name: String, c: Vector2, s: float, col: Color, w := 2.0) -> void:
	match name:
		"target":
			ci.draw_arc(c, s * 0.42, 0, TAU, 32, col, w, true)
			ci.draw_arc(c, s * 0.18, 0, TAU, 20, col, w, true)
			for a in [0.0, PI * 0.5, PI, PI * 1.5]:
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(c + d * s * 0.3, c + d * s * 0.55, col, w, true)
		"crate":
			var r := Rect2(c - Vector2(s, s) * 0.38, Vector2(s, s) * 0.76)
			ci.draw_rect(r, col, false, w)
			ci.draw_line(r.position, r.end, col, w, true)
			ci.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), col, w, true)
		"ship":
			var pts := PackedVector2Array([c + Vector2(0, -s * 0.45), c + Vector2(s * 0.4, s * 0.38), c + Vector2(0, s * 0.2), c + Vector2(-s * 0.4, s * 0.38), c + Vector2(0, -s * 0.45)])
			ci.draw_polyline(pts, col, w, true)
		"shield":
			var pts := PackedVector2Array([c + Vector2(0, -s * 0.45), c + Vector2(s * 0.38, -s * 0.3), c + Vector2(s * 0.32, s * 0.1), c + Vector2(0, s * 0.45), c + Vector2(-s * 0.32, s * 0.1), c + Vector2(-s * 0.38, -s * 0.3), c + Vector2(0, -s * 0.45)])
			ci.draw_polyline(pts, col, w, true)
			ci.draw_line(c + Vector2(0, -s * 0.18), c + Vector2(0, s * 0.18), col, w, true)
			ci.draw_line(c + Vector2(-s * 0.16, 0), c + Vector2(s * 0.16, 0), col, w, true)
		"map":
			var nodes := [c + Vector2(-s * 0.35, s * 0.2), c + Vector2(-s * 0.05, -s * 0.32), c + Vector2(s * 0.35, -s * 0.1), c + Vector2(s * 0.15, s * 0.35)]
			for i in nodes.size():
				ci.draw_line(nodes[i], nodes[(i + 1) % nodes.size()], Color(col, 0.6), w * 0.7, true)
			for n in nodes:
				ci.draw_circle(n, s * 0.08, col)
		"gear":
			ci.draw_arc(c, s * 0.2, 0, TAU, 20, col, w, true)
			for k in 8:
				var a := TAU * k / 8.0
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(c + d * s * 0.28, c + d * s * 0.45, col, w * 1.6, true)
			ci.draw_arc(c, s * 0.32, 0, TAU, 28, col, w, true)
		"jump":
			ci.draw_arc(c, s * 0.4, 0, TAU, 32, col, w, true)
			ci.draw_arc(c, s * 0.22, 0, TAU, 24, Color(col, 0.6), w, true)
			ci.draw_circle(c, s * 0.08, col)
		"close":
			ci.draw_line(c + Vector2(-s, -s) * 0.3, c + Vector2(s, s) * 0.3, col, w * 1.3, true)
			ci.draw_line(c + Vector2(s, -s) * 0.3, c + Vector2(-s, s) * 0.3, col, w * 1.3, true)
		"wrench":
			ci.draw_line(c + Vector2(-s * 0.3, s * 0.3), c + Vector2(s * 0.12, -s * 0.12), col, w * 1.8, true)
			ci.draw_arc(c + Vector2(s * 0.2, -s * 0.2), s * 0.17, PI * 0.9, PI * 2.6, 16, col, w * 1.4, true)
		"launch":
			ci.draw_line(c + Vector2(0, s * 0.4), c + Vector2(0, -s * 0.35), col, w * 1.4, true)
			ci.draw_line(c + Vector2(-s * 0.25, -s * 0.1), c + Vector2(0, -s * 0.38), col, w * 1.4, true)
			ci.draw_line(c + Vector2(s * 0.25, -s * 0.1), c + Vector2(0, -s * 0.38), col, w * 1.4, true)
		"bolt":
			var pts := PackedVector2Array([c + Vector2(s * 0.08, -s * 0.45), c + Vector2(-s * 0.22, s * 0.05), c + Vector2(s * 0.02, s * 0.05),
				c + Vector2(-s * 0.08, s * 0.45), c + Vector2(s * 0.24, -s * 0.08), c + Vector2(0, -s * 0.08), c + Vector2(s * 0.08, -s * 0.45)])
			ci.draw_polyline(pts, col, w, true)
		"blueprint":
			var r := Rect2(c - Vector2(s, s) * 0.38, Vector2(s, s) * 0.76)
			ci.draw_rect(r, col, false, w)
			for k in range(1, 3):
				var x := r.position.x + r.size.x * k / 3.0
				ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(col, 0.4), 1.0)
				var y := r.position.y + r.size.y * k / 3.0
				ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(col, 0.4), 1.0)
			ci.draw_arc(c, s * 0.16, 0, TAU, 16, col, w, true)
		"hangar":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.45, s * 0.4), c + Vector2(-s * 0.45, -s * 0.1), c + Vector2(0, -s * 0.42),
				c + Vector2(s * 0.45, -s * 0.1), c + Vector2(s * 0.45, s * 0.4)]), col, w, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(0, -s * 0.12), c + Vector2(s * 0.2, s * 0.3), c + Vector2(0, s * 0.2), c + Vector2(-s * 0.2, s * 0.3), c + Vector2(0, -s * 0.12)]), col, w, true)
		_:
			ci.draw_circle(c, s * 0.2, col)


## Text centered at a point.
static func text_c(ci: CanvasItem, font: Font, center: Vector2, s: String, fs: int, col: Color, shadow := true) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := center + Vector2(-w * 0.5, fs * 0.36)
	if shadow:
		ci.draw_string(font, pos + Vector2(1, 1.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, col.a * 0.6))
	ci.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## A Button that plays a click and pops when pressed.
static func button(text: String, min_size := Vector2(0, 56), font_size := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(func(): pop(b))
	return b
