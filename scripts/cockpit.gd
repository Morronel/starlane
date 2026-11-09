class_name Cockpit
extends Node3D
## 3D first-person cabin, parented to the camera. Every hull type gets its own
## canopy shape, colours, control yoke and screen layout. The yoke follows the
## pilot's stick, the throttle lever follows the throttle, the screens show live
## data and the cabin light reacts to gunfire, damage and low hull.

var player: PlayerShip
var world: Node

var _built := ""
var _cfg := {}
var _yoke: Node3D
var _yoke_home := Vector3.ZERO
var _lever: Node3D
var _light: OmniLight3D
var _alarm: OmniLight3D
var _viewports: Array = []
var _yoke_in := Vector3.ZERO     # smoothed pitch, yaw, roll
var _sway := Vector3.ZERO
var _accel_lag := 0.0
var _last_speed := 0.0
var _flash := 0.0
var _last_cd: Array = []
var _last_hull := -1.0
var _hit := 0.0

# camera-space layout shared by all cabins
const LIP := Vector2(-0.24, -0.8)                 # dash lip (y, z)
const FACE_DIR := Vector3(0, -0.92, 0.39)         # down the dash face, toward the pilot
const YOKE_POS := Vector3(0, -0.35, -0.5)

static var _mats := {}


## Cabin definitions. Window outlines are camera-space points (x, y) on a
## canopy that sits ~1.7-2 m ahead and wraps toward the pilot at the sides.
static func config(id: String) -> Dictionary:
	match id:
		"wren":
			return {"outline": _round_rect(2.05, -0.6, 0.86, 0.7, 8), "z": -1.95, "wrap": 0.38, "arch": 0.1,
				"frame_r": 0.022, "shell": Color(0.62, 0.58, 0.5), "frame": Color(0.36, 0.27, 0.2),
				"panel": Color(0.2, 0.17, 0.15), "accent": Color(0.35, 0.95, 1.0), "yoke": "butterfly",
				"struts": [[Vector2(-1.2, 0.86), Vector3(-0.8, 1.5, -0.3)], [Vector2(1.2, 0.86), Vector3(0.8, 1.5, -0.3)]],
				"screens": [["radar", -0.46, 0.035, 0.32, 0.2], ["nav", 0.46, 0.035, 0.32, 0.2]],
				"extras": ["hud_strip"]}
		"kestrel":
			return {"outline": [Vector2(-1.45, -0.6), Vector2(-1.6, 0.1), Vector2(-0.95, 0.74), Vector2(0, 0.92), Vector2(0.95, 0.74), Vector2(1.6, 0.1), Vector2(1.45, -0.6)],
				"z": -1.75, "wrap": 0.3, "arch": 0.0, "frame_r": 0.035,
				"shell": Color(0.33, 0.36, 0.41), "frame": Color(0.2, 0.22, 0.26), "panel": Color(0.11, 0.12, 0.14),
				"accent": Color(1.0, 0.36, 0.22), "yoke": "twin",
				"struts": [[Vector2(-0.95, 0.74), Vector3(-0.55, 1.4, -0.35)], [Vector2(0.95, 0.74), Vector3(0.55, 1.4, -0.35)]],
				"screens": [["radar", -0.46, 0.035, 0.3, 0.2], ["weapons", 0.46, 0.035, 0.3, 0.2], ["status", 0.0, 0.03, 0.22, 0.12]],
				"extras": ["combiner", "red_stripe"]}
		"mule":
			return {"outline": [Vector2(-1.85, -0.62), Vector2(-1.9, 0.98), Vector2(1.9, 0.98), Vector2(1.85, -0.62)],
				"z": -1.8, "wrap": 0.12, "arch": 0.0, "frame_r": 0.05,
				"shell": Color(0.46, 0.42, 0.33), "frame": Color(0.78, 0.62, 0.26), "panel": Color(0.17, 0.17, 0.16),
				"accent": Color(1.0, 0.72, 0.25), "yoke": "wheel",
				"mullions": [[Vector2(-0.8, -0.62), Vector2(-0.8, 0.98)], [Vector2(0.8, -0.62), Vector2(0.8, 0.98)], [Vector2(-1.88, 0.55), Vector2(-0.8, 0.55)], [Vector2(0.8, 0.55), Vector2(1.88, 0.55)]],
				"screens": [["radar", -0.47, 0.035, 0.32, 0.2], ["cargo", 0.47, 0.035, 0.32, 0.2], ["status", -0.88, 0.035, 0.26, 0.17], ["nav", 0.88, 0.035, 0.26, 0.17]],
				"extras": ["hazard", "overhead"]}
		"corsair":
			return {"outline": [Vector2(-1.65, -0.42), Vector2(-1.8, 0.08), Vector2(-1.3, 0.4), Vector2(0, 0.48), Vector2(1.3, 0.4), Vector2(1.8, 0.08), Vector2(1.65, -0.42)],
				"z": -1.7, "wrap": 0.22, "arch": 0.0, "frame_r": 0.07,
				"shell": Color(0.24, 0.25, 0.28), "frame": Color(0.14, 0.14, 0.16), "panel": Color(0.09, 0.09, 0.1),
				"accent": Color(1.0, 0.5, 0.15), "yoke": "heavy",
				"screens": [["radar", -0.46, 0.035, 0.3, 0.2], ["weapons", 0.46, 0.035, 0.3, 0.2], ["status", 0.0, 0.03, 0.22, 0.12]],
				"extras": ["armor", "alarm_lights"]}
		"seraph":
			return {"outline": _ellipse(1.8, 0.72, 0.22, 18), "z": -1.9, "wrap": 0.45, "arch": 0.2,
				"frame_r": 0.018, "shell": Color(0.6, 0.62, 0.68), "frame": Color(0.85, 0.68, 0.32),
				"panel": Color(0.15, 0.13, 0.2), "accent": Color(0.78, 0.55, 1.0), "yoke": "crescent",
				"struts": [[Vector2(0, 0.94), Vector3(0, 1.45, -0.25)]],
				"screens": [["status", -0.46, 0.035, 0.3, 0.2], ["nav", 0.46, 0.035, 0.3, 0.2]],
				"extras": ["holo", "gold_lip"]}
		_:  # sparrow
			return {"outline": _ellipse(1.4, 0.72, 0.22, 14), "z": -1.7, "wrap": 0.25, "arch": 0.15,
				"frame_r": 0.028, "shell": Color(0.24, 0.29, 0.35), "frame": Color(0.5, 0.56, 0.63),
				"panel": Color(0.12, 0.14, 0.17), "accent": Color(0.3, 0.85, 1.0), "yoke": "u",
				"struts": [[Vector2(0, 0.94), Vector3(0, 1.35, -0.2)]],
				"screens": [["radar", -0.45, 0.035, 0.3, 0.2], ["status", 0.45, 0.035, 0.3, 0.2]],
				"extras": []}


static func _ellipse(rx: float, ry: float, cy: float, n: int) -> Array:
	var out := []
	for i in n:
		var a := PI * 0.5 + TAU * float(i) / n
		out.append(Vector2(cos(a) * rx, cy + sin(a) * ry))
	return out


static func _round_rect(hw: float, y0: float, y1: float, r: float, n: int) -> Array:
	# wide panoramic shape: flat bottom, rounded upper corners
	var out := [Vector2(-hw, y0)]
	for i in n + 1:
		var a := PI - PI * 0.5 * float(i) / n
		out.append(Vector2(-hw + r + cos(a) * r, y1 - r + sin(a) * r))
	for i in n + 1:
		var a := PI * 0.5 - PI * 0.5 * float(i) / n
		out.append(Vector2(hw - r + cos(a) * r, y1 - r + sin(a) * r))
	out.append(Vector2(hw, y0))
	return out


# --- materials -------------------------------------------------------------

static func _cabin_mat() -> StandardMaterial3D:
	if not _mats.has("cabin"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		# the cabin sits in full sunlight half a metre from the lens: keep it
		# dark and matte so it frames the view instead of blooming over it
		m.albedo_color = Color(0.68, 0.68, 0.7)
		m.roughness = 0.82
		m.metallic = 0.12
		m.metallic_specular = 0.3
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats["cabin"] = m
	return _mats["cabin"]


static func _blink_mat() -> ShaderMaterial:
	if not _mats.has("blink"):
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
uniform float energy = 1.25;
void fragment() {
	// vertex alpha carries a per-light phase; a few lights blink, most glow steadily
	float ph = COLOR.a * 6.2831;
	float rate = 0.6 + fract(COLOR.a * 13.0) * 2.5;
	float on = COLOR.a > 0.55 ? step(-0.2, sin(TIME * rate + ph * 5.0)) : 0.85 + 0.15 * sin(TIME * 0.7 + ph * 3.0);
	ALBEDO = COLOR.rgb * energy * mix(0.12, 1.0, on);
}
"""
		var m := ShaderMaterial.new()
		m.shader = sh
		_mats["blink"] = m
	return _mats["blink"]


static func _glass_mat(col: Color) -> StandardMaterial3D:
	var key := "glass_%s" % col
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = col
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.disable_fog = true
		_mats[key] = m
	return _mats[key]


static func _materials() -> Dictionary:
	return {"cabin": _cabin_mat(), "glow": MeshBuilder.glow_material(1.3), "dim": MeshBuilder.glow_material(0.7), "blink": _blink_mat()}


# --- lifecycle ---------------------------------------------------------------

func _ready() -> void:
	visible = false


func active() -> bool:
	if player == null or not Settings.first_person:
		return false
	return player.mode == PlayerShip.Mode.FLIGHT or player.mode == PlayerShip.Mode.LANE or player.mode == PlayerShip.Mode.JUMPING


func _process(delta: float) -> void:
	var on := active()
	if on != visible:
		visible = on
		for sv in _viewports:
			(sv as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if not on:
		return
	if _built != GameState.ship or _trinket_built != GameState.trinket:
		build(GameState.ship)
	_animate(delta)


func build(id: String) -> void:
	for c in get_children():
		c.queue_free()
	_viewports.clear()
	_built = id
	_cfg = config(Items.SHIPS.get(id, {}).get("cockpit", id))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var b := MeshBuilder.new()
	_canopy(b)
	_dash(b, rng)
	for ex in _cfg["extras"]:
		_extra(b, ex, rng)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build(_materials())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	for s in _cfg["screens"]:
		_screen(s[0], s[1], s[2], s[3], s[4])
	_build_yoke()
	_build_lever()
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 0.25, -0.35)
	_light.omni_range = 2.6
	_light.light_energy = 0.45
	_light.light_color = (_cfg["accent"] as Color).lerp(Color.WHITE, 0.5)
	_light.shadow_enabled = false
	add_child(_light)
	_alarm = OmniLight3D.new()
	_alarm.position = Vector3(0, 0.6, -0.9)
	_alarm.omni_range = 2.4
	_alarm.light_energy = 0.0
	_alarm.light_color = Color(1.0, 0.15, 0.1)
	add_child(_alarm)
	_last_cd.clear()
	_last_hull = GameState.hull
	_trinket()


## 0.14: a little something on the dash.
var _trinket_node: Node3D
var _trinket_built := ""


func _trinket() -> void:
	_trinket_built = GameState.trinket
	if GameState.trinket == "":
		return
	var b := MeshBuilder.new()
	var base := Vector3(0.62, LIP.x + 0.02, LIP.y - 0.04)
	match GameState.trinket:
		"bobble":
			b.cyl("cabin", base, base + Vector3(0, 0.05, 0), 0.025, 0.02, 8, Color(0.9, 0.9, 0.95))
			b.box("cabin", base + Vector3(0, 0.075, 0), Vector3(0.05, 0.05, 0.045), Color(0.95, 0.95, 1.0))
			b.box("glow", base + Vector3(0, 0.078, -0.024), Vector3(0.035, 0.022, 0.004), Color(0.3, 0.7, 1.0))
		"dice":
			b.box("cabin", base + Vector3(-0.02, 0.0, 0), Vector3(0.035, 0.035, 0.035), Color(1.0, 0.95, 0.95), Basis(Vector3.UP, 0.4))
			b.box("cabin", base + Vector3(0.025, 0.006, 0.01), Vector3(0.035, 0.035, 0.035), Color(1.0, 0.4, 0.5), Basis(Vector3.UP, -0.3))
		"plant":
			b.cyl("cabin", base, base + Vector3(0, 0.035, 0), 0.025, 0.03, 8, Color(0.75, 0.45, 0.3))
			for k in 5:
				var a := TAU * k / 5.0
				b.cyl("cabin", base + Vector3(0, 0.035, 0), base + Vector3(cos(a) * 0.035, 0.09, sin(a) * 0.035), 0.008, 0.002, 4, Color(0.3, 0.85, 0.4))
		"cat":
			b.box("cabin", base + Vector3(0, 0.03, 0), Vector3(0.05, 0.06, 0.04), Color(1.0, 1.0, 0.95))
			b.box("cabin", base + Vector3(0, 0.075, 0), Vector3(0.055, 0.045, 0.04), Color(1.0, 1.0, 0.95))
			b.box("glow", base + Vector3(0, 0.03, -0.021), Vector3(0.02, 0.02, 0.004), Color(1.0, 0.75, 0.2))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build(_materials())
	add_child(mi)
	_trinket_node = mi


# --- geometry ------------------------------------------------------------------

func _pt(v: Vector2) -> Vector3:
	## outline point -> camera space: wraps toward the pilot at the sides and
	## (for bubble canopies) arches over the head at the top.
	var z: float = _cfg["z"] + float(_cfg["wrap"]) * absf(v.x) + float(_cfg["arch"]) * maxf(v.y, 0.0)
	return Vector3(v.x, v.y, z)


func _canopy(b: MeshBuilder) -> void:
	# subdivide long edges so the wrap/arch bends them instead of leaving
	# straight chords that cut across the view
	var src: Array = _cfg["outline"]
	var outline := []
	var corner := []
	for i in src.size():
		var a: Vector2 = src[i]
		var c: Vector2 = src[(i + 1) % src.size()]
		var steps := maxi(1, ceili(a.distance_to(c) / 0.3))
		for k in steps:
			outline.append(a.lerp(c, float(k) / steps))
			corner.append(k == 0)
	var shell: Color = _cfg["shell"]
	var frame: Color = _cfg["frame"]
	var fr: float = _cfg["frame_r"]
	var n := outline.size()
	var inner := []
	var flange := []
	var outer := []
	for v in outline:
		var p := _pt(v)
		inner.append(p)
		flange.append(Vector3(p.x * 1.07, p.y * 1.07 + 0.03, p.z + 0.04))
		outer.append(Vector3(p.x * 3.6, p.y * 3.6, p.z * 0.28))
	for i in n:
		var j := (i + 1) % n
		var mid: Vector3 = (inner[i] + inner[j]) * 0.5
		var away := mid * 2.5   # faces point back toward the pilot
		b.quad("cabin", inner[i], inner[j], flange[j], flange[i], frame, away)
		var dark := shell.darkened(0.12 if (inner[i] as Vector3).y < 0.0 else 0.0)
		b.quad("cabin", flange[i], flange[j], outer[j], outer[i], dark, away)
		# panel seams on the walls
		var s0: Vector3 = flange[i].lerp(outer[i], 0.18)
		var s1: Vector3 = flange[j].lerp(outer[j], 0.18)
		b.cyl("cabin", s0, s1, 0.008, 0.008, 4, shell.darkened(0.35), false)
		b.cyl("cabin", inner[i], inner[j], fr, fr, 6, frame.lightened(0.08))
		if corner[i]:
			b.box("cabin", inner[i], Vector3.ONE * fr * 2.6, frame.darkened(0.15))
	for s in _cfg.get("struts", []):
		var a := _pt(s[0])
		b.cyl("cabin", a, s[1], fr * 1.3, fr * 1.6, 6, frame)
	for m in _cfg.get("mullions", []):
		b.cyl("cabin", _pt(m[0]), _pt(m[1]), fr * 0.8, fr * 0.8, 6, frame.darkened(0.1))


func face(x: float, t: float) -> Vector3:
	return Vector3(x, LIP.x, LIP.y) + FACE_DIR.normalized() * t


func _face_basis() -> Basis:
	var down := FACE_DIR.normalized()
	var nrm := Vector3.RIGHT.cross(down) * -1.0
	return Basis(Vector3.RIGHT, -down, nrm)


func _dash(b: MeshBuilder, rng: RandomNumberGenerator) -> void:
	var panel: Color = _cfg["panel"]
	var shell: Color = _cfg["shell"]
	var accent: Color = _cfg["accent"]
	var w := 2.1
	var lip_l := Vector3(-w, LIP.x, LIP.y)
	var lip_r := Vector3(w, LIP.x, LIP.y)
	var down := FACE_DIR.normalized()
	var bot_l := lip_l + down * 0.95
	var bot_r := lip_r + down * 0.95
	var away := Vector3(0, -2.0, -3.0)
	# glare shield running out to the canopy base
	var zf: float = _cfg["z"] + 0.2
	b.quad("cabin", lip_l, lip_r, Vector3(w * 1.4, -0.62, zf), Vector3(-w * 1.4, -0.62, zf), shell.darkened(0.45), Vector3(0, -3, -1))
	# instrument face
	b.quad("cabin", lip_l, lip_r, bot_r, bot_l, panel, away)
	# rolled lip with an accent light strip
	b.cyl("cabin", lip_l + Vector3(0, 0.012, 0), lip_r + Vector3(0, 0.012, 0), 0.028, 0.028, 6, shell.darkened(0.25))
	b.box("dim", face(0, 0.012) + _face_basis().z * 0.006, Vector3(2.2, 0.003, 0.003), accent.darkened(0.2), _face_basis())
	# side consoles
	for sx in [-1.0, 1.0]:
		var cpos := Vector3(sx * 0.82, -0.5, -0.55)
		b.box("cabin", cpos, Vector3(0.42, 0.24, 0.62), panel.lightened(0.04))
		b.box("cabin", cpos + Vector3(0, 0.125, 0), Vector3(0.4, 0.012, 0.6), shell.darkened(0.2))
		# button grid
		for r in 3:
			for k in 4:
				var bp := cpos + Vector3(-0.12 + k * 0.08, 0.135, -0.18 + r * 0.09)
				_light_box(b, bp, Vector3(0.035, 0.01, 0.03), rng, accent)
	# row of indicator lights under the lip, outboard of the screens
	for sx in [-1.0, 1.0]:
		for k in 7:
			var x: float = sx * (0.7 + k * 0.075)
			_light_box(b, face(x, 0.07) + _face_basis().z * 0.004, Vector3(0.032, 0.022, 0.006), rng, accent, _face_basis())
	# toggle switches between the screens
	for k in 5:
		var x := -0.12 + k * 0.06
		var sp := face(x, 0.26) + _face_basis().z * 0.01
		b.box("cabin", sp, Vector3(0.022, 0.04, 0.02), Color(0.7, 0.72, 0.75), _face_basis() * Basis(Vector3.RIGHT, 0.5))
		_light_box(b, face(x, 0.3) + _face_basis().z * 0.004, Vector3(0.016, 0.01, 0.004), rng, accent, _face_basis())


func _light_box(b: MeshBuilder, pos: Vector3, size: Vector3, rng: RandomNumberGenerator, accent: Color, basis := Basis.IDENTITY) -> void:
	var palette := [accent, accent, Color(0.4, 1.0, 0.5), Color(1.0, 0.7, 0.25), Color(1.0, 0.25, 0.2), Color(0.85, 0.9, 1.0)]
	var col: Color = palette[rng.randi() % palette.size()]
	col.a = rng.randf()
	if rng.randf() < 0.25:
		col = Color(0.12, 0.13, 0.15, 0.0)   # unlit button
		b.box("cabin", pos, size, col, basis)
		return
	b.box("blink", pos, size, col, basis)


func _screen(mode: String, x: float, t: float, w: float, h: float) -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(320, int(320.0 * h / w))
	sv.disable_3d = true
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var scr := CockpitScreen.new()
	scr.mode = mode
	scr.accent = _cfg["accent"]
	scr.player = player
	scr.world = world
	scr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sv.add_child(scr)
	add_child(sv)
	scr.size = Vector2(sv.size)
	_viewports.append(sv)
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = sv.get_texture()
	m.disable_fog = true
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fb := _face_basis()
	var center := face(x, t + h * 0.5)
	mi.transform = Transform3D(fb, center + fb.z * 0.012)
	add_child(mi)
	# bezel
	var bz := MeshBuilder.new()
	bz.box("cabin", center + fb.z * 0.004, Vector3(w + 0.03, h + 0.03, 0.012), Color(0.05, 0.05, 0.06), fb)
	bz.box("glow", center + fb.z * 0.006 - fb.y * (h * 0.5 + 0.009), Vector3(w * 0.3, 0.004, 0.006), (_cfg["accent"] as Color).darkened(0.2), fb)
	var bmi := MeshInstance3D.new()
	bmi.mesh = bz.build(_materials())
	add_child(bmi)


func _extra(b: MeshBuilder, ex: String, rng: RandomNumberGenerator) -> void:
	var accent: Color = _cfg["accent"]
	var fb := _face_basis()
	match ex:
		"hud_strip":
			# wren: thin glowing heading tape along the canopy base
			b.box("glow", Vector3(0, -0.46, -1.6), Vector3(1.6, 0.008, 0.008), accent.darkened(0.4))
			for k in 17:
				var x := -0.8 + k * 0.1
				b.box("glow", Vector3(x, -0.44 if k % 4 else -0.425, -1.6), Vector3(0.006, 0.03 if k % 4 else 0.06, 0.006), accent.darkened(0.4))
		"combiner":
			# kestrel: head-up display glass on a bracket above the dash
			var gp := Vector3(0, -0.13, -0.86)
			for sx in [-1.0, 1.0]:
				b.cyl("cabin", Vector3(sx * 0.14, LIP.x, -0.84), gp + Vector3(sx * 0.14, 0.09, -0.02), 0.008, 0.008, 4, Color(0.2, 0.2, 0.22))
			var glass := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(0.27, 0.17)
			glass.mesh = qm
			glass.material_override = _glass_mat(Color(0.15, 0.5, 0.3, 0.05))
			glass.transform = Transform3D(Basis(Vector3.RIGHT, -0.25), gp)
			add_child(glass)
			var ring := MeshBuilder.new()
			ring.torus("glow", Vector3.ZERO, 0.035, 0.0018, 24, 3, Color(0.3, 1.0, 0.45), Basis(Vector3.RIGHT, PI * 0.5))
			for a in 4:
				var d := Vector2(cos(a * PI * 0.5), sin(a * PI * 0.5))
				ring.box("glow", Vector3(d.x, d.y, 0) * 0.05, Vector3(0.02 if a % 2 == 0 else 0.003, 0.003 if a % 2 == 0 else 0.02, 0.002), Color(0.3, 1.0, 0.45))
			var rmi := MeshInstance3D.new()
			rmi.mesh = ring.build(_materials())
			rmi.transform = Transform3D(Basis(Vector3.RIGHT, -0.25), gp + Vector3(0, 0.0, 0.002))
			add_child(rmi)
		"red_stripe":
			for sx in [-1.0, 1.0]:
				b.box("cabin", Vector3(sx * 1.3, -0.3, -0.95), Vector3(0.9, 0.04, 0.02), Color(0.7, 0.16, 0.12), Basis(Vector3.UP, sx * 0.6))
		"hazard":
			# mule: yellow/black hazard stripes on the lip and a heavy grab bar
			for k in 28:
				var x := -1.4 + k * 0.1
				b.box("cabin", face(x, -0.012) + fb.z * 0.03, Vector3(0.05, 0.018, 0.008), Color(0.95, 0.75, 0.15) if k % 2 == 0 else Color(0.06, 0.06, 0.06), fb * Basis(Vector3.FORWARD, 0.6))
		"overhead":
			# mule: overhead switch panel hanging from the roof
			var op := Vector3(0, 0.86, -1.42)
			b.box("cabin", op, Vector3(1.3, 0.16, 0.5), Color(0.2, 0.2, 0.19))
			b.box("cabin", op + Vector3(0, -0.085, 0), Vector3(1.26, 0.01, 0.46), Color(0.12, 0.12, 0.12))
			for r in 2:
				for k in 12:
					_light_box(b, op + Vector3(-0.55 + k * 0.1, -0.095, -0.12 + r * 0.14), Vector3(0.05, 0.012, 0.05), rng, accent)
			for sx in [-1.0, 1.0]:
				b.cyl("cabin", op + Vector3(sx * 0.6, 0.08, 0), op + Vector3(sx * 0.6, 0.6, 0.1), 0.03, 0.03, 6, _cfg["frame"])
		"armor":
			# corsair: armoured louvres over the top of the slit and rivets on the frame
			for k in 4:
				var y := 0.62 + k * 0.17
				b.box("cabin", Vector3(0, y, -1.55 + k * 0.12), Vector3(5.2, 0.07, 0.3), Color(0.18, 0.18, 0.2).lightened(k * 0.03), Basis(Vector3.RIGHT, 0.35))
			for v in _cfg["outline"]:
				var p := _pt(v)
				b.box("cabin", p * Vector3(1.04, 1.06, 1.0) + Vector3(0, 0, 0.03), Vector3(0.03, 0.03, 0.03), Color(0.45, 0.42, 0.38))
		"alarm_lights":
			for sx in [-1.0, 1.0]:
				var c := Color(1.0, 0.2, 0.1, 0.9)
				b.cyl("blink", Vector3(sx * 1.25, 0.5, -1.45), Vector3(sx * 1.25, 0.56, -1.45), 0.035, 0.03, 8, c)
		"holo":
			# seraph: projector disc with a floating holographic radar above the dash
			var hp := Vector3(0, -0.24, -0.82)
			b.cyl("cabin", hp + Vector3(0, -0.01, 0), hp + Vector3(0, 0.012, 0), 0.07, 0.06, 16, Color(0.85, 0.72, 0.4))
			b.cyl("glow", hp + Vector3(0, 0.012, 0), hp + Vector3(0, 0.016, 0), 0.05, 0.05, 16, accent)
			var sv := SubViewport.new()
			sv.size = Vector2i(256, 256)
			sv.disable_3d = true
			sv.transparent_bg = true
			var scr := CockpitScreen.new()
			scr.mode = "radar"
			scr.holo = true
			scr.accent = accent
			scr.player = player
			scr.world = world
			sv.add_child(scr)
			add_child(sv)
			scr.size = Vector2(256, 256)
			_viewports.append(sv)
			var q := QuadMesh.new()
			q.size = Vector2(0.2, 0.2)
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.albedo_texture = sv.get_texture()
			m.albedo_color = Color(0.8, 0.8, 0.8, 0.7)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.disable_fog = true
			var mi := MeshInstance3D.new()
			mi.name = "Holo"
			mi.mesh = q
			mi.material_override = m
			mi.transform = Transform3D(Basis(Vector3.RIGHT, -0.35), hp + Vector3(0, 0.12, 0))
			add_child(mi)
			var cone := MeshInstance3D.new()
			var cm := MeshBuilder.new()
			cm.cyl("glow", hp + Vector3(0, 0.016, 0), hp + Vector3(0, 0.12, 0), 0.04, 0.1, 16, accent.darkened(0.6), false)
			cone.mesh = cm.build({"glow": _glass_mat(Color(accent.darkened(0.5), 0.06))})
			add_child(cone)
		"gold_lip":
			b.cyl("cabin", Vector3(-2.1, LIP.x + 0.035, LIP.y), Vector3(2.1, LIP.x + 0.035, LIP.y), 0.008, 0.008, 6, Color(0.9, 0.74, 0.38))


func _build_yoke() -> void:
	var kind: String = _cfg["yoke"]
	var accent: Color = _cfg["accent"]
	var grip := Color(0.16, 0.16, 0.18)
	var metal: Color = (_cfg["frame"] as Color).lerp(Color(0.5, 0.52, 0.55), 0.5)
	var b := MeshBuilder.new()
	# column (into the dash) is static; the yoke itself pivots
	var col := MeshBuilder.new()
	col.cyl("cabin", YOKE_POS + Vector3(0, -0.02, -0.06), face(0, 0.3), 0.022, 0.03, 8, metal.darkened(0.3))
	col.cyl("cabin", face(0, 0.3) + Vector3(0, 0, 0.02), face(0, 0.3), 0.06, 0.07, 10, Color(0.06, 0.06, 0.07))
	var cmi := MeshInstance3D.new()
	cmi.mesh = col.build(_materials())
	add_child(cmi)
	match kind:
		"wheel":
			b.torus("cabin", Vector3.ZERO, 0.21, 0.018, 28, 6, grip, Basis(Vector3.RIGHT, PI * 0.5))
			for a in [PI * 0.5 + 0.0, PI * 0.5 + TAU / 3.0, PI * 0.5 + TAU * 2.0 / 3.0]:
				b.cyl("cabin", Vector3.ZERO, Vector3(cos(a), -sin(a), 0) * 0.2, 0.012, 0.01, 6, metal)
			b.cyl("cabin", Vector3(0, 0, -0.03), Vector3(0, 0, 0.02), 0.05, 0.045, 12, metal.darkened(0.2))
			b.cyl("glow", Vector3(0, 0, 0.02), Vector3(0, 0, 0.024), 0.03, 0.03, 12, accent)
			b.box("blink", Vector3(0, 0.205, 0.0), Vector3(0.03, 0.02, 0.03), Color(accent, 0.3))
		"butterfly":
			b.cyl("cabin", Vector3(-0.15, 0, 0), Vector3(0.15, 0, 0), 0.018, 0.018, 8, metal)
			for sx in [-1.0, 1.0]:
				b.cyl("cabin", Vector3(sx * 0.15, 0, 0), Vector3(sx * 0.21, 0.17, 0.01), 0.022, 0.026, 8, grip)
				b.box("glow", Vector3(sx * 0.21, 0.185, 0.012), Vector3(0.025, 0.012, 0.02), accent)
			b.box("cabin", Vector3(0, 0, 0.005), Vector3(0.1, 0.05, 0.04), metal.darkened(0.2))
			b.box("blink", Vector3(0, 0.0, 0.028), Vector3(0.04, 0.012, 0.004), Color(accent, 0.2))
		"twin":
			b.cyl("cabin", Vector3(-0.17, -0.02, 0), Vector3(0.17, -0.02, 0), 0.02, 0.02, 8, metal)
			for sx in [-1.0, 1.0]:
				b.cyl("cabin", Vector3(sx * 0.17, -0.04, 0.0), Vector3(sx * 0.15, 0.12, 0.03), 0.026, 0.022, 8, grip)
				b.box("cabin", Vector3(sx * 0.15, 0.13, 0.03), Vector3(0.04, 0.025, 0.04), metal.darkened(0.2))
				b.box("blink", Vector3(sx * 0.15, 0.145, 0.03), Vector3(0.018, 0.008, 0.018), Color(1.0, 0.25, 0.2, 0.3))
				b.box("glow", Vector3(sx * 0.13, 0.09, 0.05), Vector3(0.01, 0.03, 0.01), Color(1.0, 0.5, 0.2))
			b.box("cabin", Vector3(0, -0.02, 0.0), Vector3(0.12, 0.06, 0.05), metal.darkened(0.25))
		"heavy":
			b.box("cabin", Vector3(0, -0.01, 0), Vector3(0.44, 0.05, 0.06), metal.darkened(0.3))
			b.box("cabin", Vector3(0, 0.0, 0.0), Vector3(0.14, 0.09, 0.08), Color(0.2, 0.2, 0.22))
			for sx in [-1.0, 1.0]:
				b.cyl("cabin", Vector3(sx * 0.22, -0.03, 0), Vector3(sx * 0.22, 0.14, 0.02), 0.032, 0.03, 8, grip)
				b.box("cabin", Vector3(sx * 0.22, 0.16, 0.02), Vector3(0.07, 0.03, 0.06), Color(0.25, 0.24, 0.24))
				b.box("glow", Vector3(sx * 0.22, 0.178, 0.02), Vector3(0.03, 0.006, 0.03), Color(1.0, 0.45, 0.12))
			b.box("blink", Vector3(0, 0.0, 0.042), Vector3(0.08, 0.02, 0.004), Color(1.0, 0.3, 0.1, 0.25))
		"crescent":
			var pts := []
			for i in 13:
				var a := deg_to_rad(200.0 + i * 140.0 / 12.0)
				pts.append(Vector3(cos(a) * 0.2, sin(a) * 0.2 + 0.2, 0))
			for i in pts.size() - 1:
				b.cyl("cabin", pts[i], pts[i + 1], 0.016, 0.016, 6, Color(0.92, 0.93, 0.95))
				b.cyl("glow", pts[i] + Vector3(0, 0.0, 0.016), pts[i + 1] + Vector3(0, 0.0, 0.016), 0.004, 0.004, 4, accent)
			b.cyl("cabin", Vector3(0, 0, -0.02), Vector3(0, 0, 0.02), 0.04, 0.035, 12, Color(0.88, 0.72, 0.38))
			for sx in [-1.0, 1.0]:
				b.cyl("cabin", Vector3(sx * 0.188, 0.13, 0), Vector3(sx * 0.2, 0.2, 0.0), 0.022, 0.02, 8, Color(0.2, 0.18, 0.24))
		_:  # "u"
			b.cyl("cabin", Vector3(-0.16, -0.03, 0), Vector3(0.16, -0.03, 0), 0.018, 0.018, 8, metal)
			for sx in [-1.0, 1.0]:
				b.cyl("cabin", Vector3(sx * 0.16, -0.03, 0), Vector3(sx * 0.17, 0.14, 0.01), 0.024, 0.024, 8, grip)
				b.box("cabin", Vector3(sx * 0.17, 0.15, 0.01), Vector3(0.04, 0.022, 0.04), metal.darkened(0.2))
				b.box("glow", Vector3(sx * 0.17, 0.163, 0.01), Vector3(0.018, 0.005, 0.018), accent)
			b.box("cabin", Vector3(0, -0.03, 0), Vector3(0.08, 0.05, 0.05), metal.darkened(0.25))
			b.box("blink", Vector3(0, -0.03, 0.027), Vector3(0.03, 0.01, 0.004), Color(accent, 0.15))
	_yoke = Node3D.new()
	_yoke_home = YOKE_POS
	_yoke.position = YOKE_POS
	var mi := MeshInstance3D.new()
	mi.mesh = b.build(_materials())
	_yoke.add_child(mi)
	add_child(_yoke)


func _build_lever() -> void:
	var accent: Color = _cfg["accent"]
	var base := Vector3(-0.72, -0.37, -0.5)
	var slot := MeshBuilder.new()
	slot.box("cabin", base, Vector3(0.06, 0.012, 0.24), Color(0.04, 0.04, 0.05))
	for k in 5:
		slot.box("glow", base + Vector3(0.045, 0.004, -0.1 + k * 0.05), Vector3(0.02, 0.004, 0.006), accent.darkened(0.3))
	var smi := MeshInstance3D.new()
	smi.mesh = slot.build(_materials())
	add_child(smi)
	var lb := MeshBuilder.new()
	lb.cyl("cabin", Vector3.ZERO, Vector3(0, 0.13, 0), 0.01, 0.01, 6, Color(0.55, 0.57, 0.6))
	lb.box("cabin", Vector3(0, 0.15, 0), Vector3(0.07, 0.045, 0.05), Color(0.1, 0.1, 0.11))
	lb.box("glow", Vector3(0, 0.174, 0.0), Vector3(0.05, 0.004, 0.03), accent)
	_lever = Node3D.new()
	_lever.position = base
	var lmi := MeshInstance3D.new()
	lmi.mesh = lb.build(_materials())
	_lever.add_child(lmi)
	add_child(_lever)


# --- animation -----------------------------------------------------------------

func _animate(delta: float) -> void:
	var want := Vector3.ZERO   # pitch (up +), yaw (right +), roll (right +)
	if player.autopilot and player.mode == PlayerShip.Mode.FLIGHT:
		var tm := maxf(GameState.turn_mult(), 0.01)
		want = Vector3(player.ang_vel.x / (1.5 * tm), -player.ang_vel.y / (1.15 * tm), -player.ang_vel.z / (2.4 * tm))
	else:
		want = Vector3(GameInput.stick.y, GameInput.stick.x, GameInput.roll)
	want = want.clamp(-Vector3.ONE, Vector3.ONE)
	_yoke_in = _yoke_in.lerp(want, 1.0 - exp(-delta * 9.0))
	if _yoke:
		# roll turns the wheel, yaw adds a little twist, pitch pulls/pushes the column
		_yoke.rotation = Vector3(-_yoke_in.x * 0.12, -_yoke_in.y * 0.12, -(_yoke_in.z * 0.75 + _yoke_in.y * 0.35))
		_yoke.position = _yoke_home + Vector3(0, -_yoke_in.x * 0.015, _yoke_in.x * 0.06)
	if _lever:
		_lever.rotation.x = lerpf(0.55, -0.55, GameInput.throttle)
	# head sway: the cabin lags a hair behind fast turns and shakes under boost
	var sway_t := Vector3(-player.ang_vel.x * 0.012, -player.ang_vel.y * 0.012, -player.ang_vel.z * 0.01)
	_sway = _sway.lerp(sway_t, 1.0 - exp(-delta * 6.0))
	# no random shake: the cabin only eases back a few millimetres under
	# acceleration and drifts forward when braking, all low-pass filtered
	var acc := (player.speed - _last_speed) / maxf(delta, 0.001)
	_last_speed = player.speed
	_accel_lag = lerpf(_accel_lag, clampf(acc * 0.000012, -0.008, 0.008), 1.0 - exp(-delta * 2.5))
	rotation = Vector3(_sway.x, _sway.y, _sway.z)
	position = Vector3(0, 0, _accel_lag - _sway.x * 0.02)
	# muzzle flash, hits, alarm
	var cds: Array = player.weapon_cd
	for i in cds.size():
		if i < _last_cd.size() and float(cds[i]) > float(_last_cd[i]) + 0.02:
			_flash = 1.0
	_last_cd = cds.duplicate()
	if _last_hull >= 0.0 and GameState.hull < _last_hull - 0.01:
		_hit = 1.0
	_last_hull = GameState.hull
	_flash = maxf(0.0, _flash - delta * 9.0)
	_hit = maxf(0.0, _hit - delta * 2.5)
	if _light:
		var base_col: Color = (_cfg["accent"] as Color).lerp(Color.WHITE, 0.5)
		_light.light_color = base_col.lerp(Color(1.0, 0.85, 0.6), _flash)
		_light.light_energy = 0.45 + _flash * 1.2
	if _alarm:
		var low := GameState.hull < GameState.max_hull() * 0.3
		var pulse := 0.0
		if low:
			pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 7.0)
		_alarm.light_energy = maxf(pulse * 1.4, _hit * 2.5)


func near_plane() -> float:
	return 0.04
