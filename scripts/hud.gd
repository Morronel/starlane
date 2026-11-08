class_name Hud
extends Control
## Flight HUD drawn in screen space: crosshair, target brackets with lead pip,
## nav markers with off-screen arrows, status bars, lane info and messages.

var world: Node
var messages: Array = []   # {text, color, t}
var damage_flash := 0.0

const CY := Color(0.55, 0.88, 1.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.message.connect(push)


func push(text: String, color := Color(0.6, 0.9, 1.0)) -> void:
	messages.push_front({"text": text, "color": color, "t": 4.5})
	if messages.size() > 4:
		messages.pop_back()


var _label_rects: Array = []


## Reserve screen space for a label; false if it would overlap one already drawn.
func _claim(center: Vector2, text: String, fs: int) -> bool:
	var w := UiKit.body(600).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var r := Rect2(center - Vector2(w * 0.5 + 4, fs * 0.7), Vector2(w + 8, fs * 1.4))
	for o in _label_rects:
		if (o as Rect2).intersects(r):
			return false
	_label_rects.append(r)
	return true


func _process(delta: float) -> void:
	for m in messages:
		m["t"] -= delta
	messages = messages.filter(func(m): return m["t"] > 0.0)
	damage_flash = maxf(0.0, damage_flash - delta * 2.0)
	queue_redraw()


func _draw() -> void:
	var font := UiKit.body(600)
	var p: PlayerShip = world.player
	var cam: Camera3D = world.camera
	var center := size * 0.5
	_label_rects.clear()

	if damage_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.15, 0.1, damage_flash * 0.18))

	_messages(font)
	if p.mode == PlayerShip.Mode.DOCKED or p.mode == PlayerShip.Mode.DEAD:
		return
	if p.mode == PlayerShip.Mode.JUMPING:
		UiKit.text_c(self, UiKit.display(800, 6), Vector2(center.x, size.y * 0.3), "JUMP DRIVE ENGAGED", 30, Color(1, 1, 1, 0.9))
		return

	_bars(font, p)
	if Settings.first_person:
		_glass_hud(p)
	_destination(font, p, cam)
	_nav(font, p, cam)

	if p.mode == PlayerShip.Mode.LANE:
		_lane_info(font, p)
	else:
		# crosshair
		var c := Color(CY, 0.8)
		for a in [0.0, PI * 0.5, PI, PI * 1.5]:
			var d := Vector2(cos(a), sin(a))
			draw_line(center + d * 10, center + d * 22, c, 2.0, true)
		draw_circle(center, 2.0, c)
		_target(font, p, cam)

	# speed / throttle readout
	if not Settings.first_person:   # the cockpit screens show speed in 1st person
		var spd := "%d m/s" % int(p.speed)
		_text(font, Vector2(center.x, size.y - 38), spd, 26, Color(1, 1, 1, 0.9))
	if p.mode == PlayerShip.Mode.DOCKING:
		_text(font, Vector2(center.x, size.y * 0.3), "AUTOPILOT DOCKING", 28, Color(0.5, 1.0, 0.7))



## Head-up readout projected on the canopy in 1st person, so every hull
## (including the starter Sparrow) has speed, throttle, shield and hull right
## next to the crosshair, whatever its dashboard screens show.
func _glass_hud(p: PlayerShip) -> void:
	var c := size * 0.5
	var g := Color(0.45, 1.0, 0.7, 0.85)
	var dim := Color(g, 0.35)
	var f := UiKit.display(700, 1)
	# speed box, left of the crosshair
	var sx := c.x - 190.0
	var spd := str(int(p.speed))
	draw_rect(Rect2(sx - 62, c.y - 22, 124, 44), dim, false, 1.5)
	UiKit.text_c(self, f, Vector2(sx, c.y - 1), spd, 26, g, false)
	UiKit.text_c(self, UiKit.display(600), Vector2(sx, c.y + 34), "M/S", 12, dim, false)
	# throttle tape beside it
	var tx := sx - 80.0
	draw_rect(Rect2(tx, c.y - 40, 6, 80), dim, false, 1.0)
	var t := GameInput.throttle
	draw_rect(Rect2(tx, c.y + 40 - 80 * t, 6, 80 * t), g)
	# shield / hull arcs, right of the crosshair
	var hx := c.x + 190.0
	var ms := GameState.max_shield()
	var sh := p.shield / ms if ms > 0.0 else 0.0
	var hu := GameState.hull / GameState.max_hull()
	var hull_col := g if hu > 0.3 else Color(1.0, 0.35, 0.3, 0.9)
	draw_arc(Vector2(hx, c.y), 30, -PI * 0.75, PI * 0.75, 32, dim, 3.0, true)
	if sh > 0.0:
		draw_arc(Vector2(hx, c.y), 30, -PI * 0.75, -PI * 0.75 + PI * 1.5 * sh, 32, Color(0.45, 0.85, 1.0, 0.9), 3.0, true)
	draw_arc(Vector2(hx, c.y), 22, -PI * 0.75, PI * 0.75, 32, dim, 3.0, true)
	draw_arc(Vector2(hx, c.y), 22, -PI * 0.75, -PI * 0.75 + PI * 1.5 * hu, 32, hull_col, 3.0, true)
	UiKit.text_c(self, f, Vector2(hx, c.y), "%d" % int(hu * 100.0), 14, hull_col, false)
	UiKit.text_c(self, UiKit.display(600), Vector2(hx, c.y + 46), "SHD · HULL", 11, dim, false)
	# mode flags under the crosshair
	var flag := ""
	if p.mode == PlayerShip.Mode.LANE:
		flag = "LANE"
	if p.autopilot:
		flag = "AUTOPILOT" if flag == "" else flag + "  ·  AUTOPILOT"
	if p.boost_energy < 0.99 and GameInput.boost:
		flag = "BOOST" if flag == "" else flag + "  ·  BOOST"
	if flag != "":
		UiKit.text_c(self, f, Vector2(c.x, c.y + 70), flag, 13, g, false)


func _bars(font: Font, p: PlayerShip) -> void:
	var x := 24.0
	var y := 22.0
	var w := 230.0
	var ms := GameState.max_shield()
	_bar(Vector2(x, y), w, p.shield / ms if ms > 0.0 else 0.0, Color(0.35, 0.8, 1.0), "SHIELD" if ms > 0.0 else "NO SHIELD", font)
	_bar(Vector2(x, y + 30), w, GameState.hull / GameState.max_hull(), Color(1.0, 0.6, 0.25), "HULL", font)
	_bar(Vector2(x, y + 60), w, p.boost_energy, Color(0.85, 0.85, 1.0), "BOOST", font)
	var right := size.x - 100.0
	var cr := "%d cr" % GameState.credits
	draw_string(font, Vector2(right - font.get_string_size(cr, 0, -1, 24).x, 44), cr, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.9, 0.55))
	var cargo := "Cargo %d/%d" % [GameState.cargo_used(), GameState.cargo_capacity()]
	draw_string(font, Vector2(right - font.get_string_size(cargo, 0, -1, 18).x, 70), cargo, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.7))
	# jump charges
	var jx := right - 18.0 * GameState.max_jump_charges()
	draw_string(font, Vector2(jx - 52, 100), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(CY, 0.8))
	for i in GameState.max_jump_charges():
		var c := Vector2(jx + i * 18 + 6, 95)
		if i < GameState.jump_charges:
			draw_circle(c, 5.5, CY)
		else:
			draw_arc(c, 5.5, 0, TAU, 14, Color(CY, 0.4), 1.5, true)
	if GameInput.auto_fire:
		draw_string(UiKit.display(700), Vector2(24, 120), "AUTO-ATTACK ON", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.85, 0.4))
	if not GameInput.using_touch:
		var sec := GameState.installed("secondary")
		if not sec.is_empty():
			var kind: String = Items.GEAR[sec[0]]["ammo"]
			draw_string(font, Vector2(24, 144), "%s: %d  [C]" % [Items.GEAR[sec[0]]["name"], GameState.ammo.get(kind, 0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.8, 0.5, 0.85))
	var m := GameState.active_hunt(GameState.system_id)
	if not m.is_empty():
		var t := "Raiders left: %d" % m["left"]
		draw_string(font, Vector2(right - font.get_string_size(t, 0, -1, 18).x, 124), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.55, 0.45))


func _bar(pos: Vector2, w: float, v: float, col: Color, label: String, font: Font) -> void:
	draw_rect(Rect2(pos, Vector2(w, 12)), Color(col, 0.15))
	draw_rect(Rect2(pos, Vector2(w * clampf(v, 0, 1), 12)), Color(col, 0.85))
	draw_string(font, pos + Vector2(w + 8, 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(col, 0.9))


func _nav(font: Font, p: PlayerShip, cam: Camera3D) -> void:
	for st in get_tree().get_nodes_in_group("stations"):
		var s := st as Station
		_marker(font, cam, s.global_position, s.display_name, s.accent, p, "diamond")
	if p.mode == PlayerShip.Mode.FLIGHT and world.lane:
		for e in world.lane.exits:
			var pos: Vector3 = world.lane.curve.sample_baked(e["s"], true)
			if pos.distance_to(p.global_position) < 9000.0:
				_marker(font, cam, pos, "Lane: " + e["name"], Color(0.4, 0.9, 1.0), p, "ring")
		# nearest point on the lane: you can merge anywhere
		var c: Dictionary = world.lane.closest(p.global_position)
		if c["dist"] > SpaceLane.RADIUS and c["dist"] < 15000.0:
			_marker(font, cam, c["pos"], "Space lane", Color(0.4, 0.9, 1.0, 0.8), p, "ring")
	for l in get_tree().get_nodes_in_group("loot"):
		if l.global_position.distance_to(p.global_position) < 2500.0:
			_marker(font, cam, l.global_position, "", Color(0.45, 1.0, 0.6) if l.blueprint == "" else Color(0.85, 0.6, 1.0), p, "loot")
	for g in get_tree().get_nodes_in_group("stargates"):
		_marker(font, cam, g.global_position, g.display_name, Color(1.0, 0.85, 0.4), p, "gate")
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != p.target and e.global_position.distance_to(p.global_position) < 3500.0:
			_marker(font, cam, e.global_position, "", Color(1.0, 0.35, 0.3), p, "small")


func _marker(font: Font, cam: Camera3D, pos: Vector3, label: String, col: Color, p: PlayerShip, style: String) -> void:
	var dist := pos.distance_to(cam.global_position)
	var behind := cam.is_position_behind(pos)
	var sp := cam.unproject_position(pos)
	var margin := 60.0
	var rect := Rect2(Vector2(margin, margin), size - Vector2(margin, margin) * 2)
	var on_screen := not behind and rect.has_point(sp)
	if on_screen:
		match style:
			"diamond":
				var pts := PackedVector2Array([sp + Vector2(0, -12), sp + Vector2(12, 0), sp + Vector2(0, 12), sp + Vector2(-12, 0), sp + Vector2(0, -12)])
				draw_polyline(pts, col, 2.0, true)
			"ring", "gate":
				draw_arc(sp, 11, 0, TAU, 24, col, 2.0, true)
			"small":
				draw_rect(Rect2(sp - Vector2(7, 7), Vector2(14, 14)), Color(col, 0.8), false, 1.5)
			"loot":
				draw_polyline(PackedVector2Array([sp + Vector2(0, -7), sp + Vector2(7, 0), sp + Vector2(0, 7), sp + Vector2(-7, 0), sp + Vector2(0, -7)]), Color(col, 0.9), 1.5, true)
			"dest":
				var pu := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
				var r0 := 16.0 + pu * 4.0
				for k in 4:
					var a := PI * 0.5 * k + PI * 0.25
					var d := Vector2(cos(a), sin(a))
					var t := Vector2(-d.y, d.x)
					draw_polyline(PackedVector2Array([sp + d * r0 + t * 7, sp + d * (r0 - 7), sp + d * r0 - t * 7]), col, 2.5, true)
		if label != "" and _claim(sp + Vector2(0, -26), label, 16):
			_text(font, sp + Vector2(0, -26), label, 16, Color(col, 0.95))
			if _claim(sp + Vector2(0, 30), _fmt_dist(dist), 14):
				_text(font, sp + Vector2(0, 30), _fmt_dist(dist), 14, Color(1, 1, 1, 0.65))
	else:
		# arrow at the screen edge
		var c := size * 0.5
		var dir := sp - c
		if behind:
			dir = -dir
		if dir.length() < 0.01:
			dir = Vector2(0, 1)
		dir = dir.normalized()
		var r := Vector2(size.x * 0.5 - margin, size.y * 0.5 - margin)
		var t := minf(absf(r.x / dir.x) if absf(dir.x) > 0.001 else INF, absf(r.y / dir.y) if absf(dir.y) > 0.001 else INF)
		var ep := c + dir * t
		var perp := Vector2(-dir.y, dir.x)
		var sz := 9.0 if style == "small" or style == "loot" else (18.0 if style == "dest" else 13.0)
		draw_colored_polygon(PackedVector2Array([ep + dir * sz, ep - dir * sz * 0.6 + perp * sz * 0.8, ep - dir * sz * 0.6 - perp * sz * 0.8]), Color(col, 0.85))
		var lt := "%s %s" % [label, _fmt_dist(dist)]
		var lp := ep - dir * (44 if style == "dest" else 34)
		# keep edge labels on screen
		var lw := font.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		lp.x = clampf(lp.x, lw * 0.5 + 8, size.x - lw * 0.5 - 8)
		if label != "" and style != "ring" and _claim(lp, lt, 14):
			_text(font, lp, lt, 15 if style == "dest" else 14, Color(col, 0.95 if style == "dest" else 0.85))


func _target(font: Font, p: PlayerShip, cam: Camera3D) -> void:
	var t: Node3D = p.target
	if t == null or not is_instance_valid(t):
		return
	if cam.is_position_behind(t.global_position):
		_marker(font, cam, t.global_position, "TARGET", Color(1, 0.3, 0.25), p, "small")
		return
	var sp := cam.unproject_position(t.global_position)
	var dist := t.global_position.distance_to(p.global_position)
	var s := clampf(1800.0 / maxf(dist, 1.0), 14.0, 60.0)
	var col := Color(1.0, 0.35, 0.3)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var cp: Vector2 = sp + corner * s
		draw_line(cp, cp - Vector2(corner.x * s * 0.45, 0), col, 2.0)
		draw_line(cp, cp - Vector2(0, corner.y * s * 0.45), col, 2.0)
	# hp bar
	var hp_ratio: float = t.hp / t.max_hp
	draw_rect(Rect2(sp + Vector2(-s, s + 8), Vector2(2 * s, 5)), Color(col, 0.25))
	draw_rect(Rect2(sp + Vector2(-s, s + 8), Vector2(2 * s * hp_ratio, 5)), col)
	_text(font, sp + Vector2(0, s + 30), _fmt_dist(dist), 14, Color(1, 1, 1, 0.7))
	# lead indicator
	var lead: Vector3 = world.lead_point(p.global_position, t, Combat.PLAYER_BOLT_SPEED)
	if not cam.is_position_behind(lead):
		var lp := cam.unproject_position(lead)
		draw_arc(lp, 8, 0, TAU, 20, Color(1, 0.85, 0.4, 0.9), 2.0, true)
		draw_line(sp, lp, Color(1, 0.85, 0.4, 0.25), 1.0)


const DEST_COL := Color(1.0, 0.82, 0.35)


func _destination(font: Font, p: PlayerShip, cam: Camera3D) -> void:
	var t: Dictionary = world.dest_target()
	if t.is_empty():
		return
	var dist: float = p.global_position.distance_to(t["pos"])
	if p.mode != PlayerShip.Mode.LANE:
		_marker(font, cam, t["pos"], "DEST", DEST_COL, p, "dest")
	var tag := "AUTOPILOT" if p.autopilot else "DESTINATION"
	var line := "%s  ·  %s  ·  %s" % [tag, t["label"], _fmt_dist(dist)]
	var col := UiKit.GOOD if p.autopilot else DEST_COL
	_text(UiKit.display(600), Vector2(size.x * 0.5, 82), line, 15, Color(col, 0.95))


func _lane_info(font: Font, p: PlayerShip) -> void:
	var lane: SpaceLane = world.lane
	var ne := lane.next_exit(p.lane_s, p.lane_dir)
	var y := 128.0
	_text(font, Vector2(size.x * 0.5, y), "SPACE LANE", 18, Color(0.5, 0.9, 1.0, 0.8))
	if not ne.is_empty():
		var t := "Next exit: %s  %s" % [ne["name"], _fmt_dist(ne["dist"])]
		_text(font, Vector2(size.x * 0.5, y + 30), t, 24, Color(1, 1, 1))
	# lane progress strip
	var w := 420.0
	var x0 := size.x * 0.5 - w * 0.5
	var yy := y + 56
	draw_line(Vector2(x0, yy), Vector2(x0 + w, yy), Color(0.5, 0.9, 1.0, 0.4), 2.0)
	for e in lane.exits:
		var ex: float = x0 + w * e["s"] / lane.length
		draw_circle(Vector2(ex, yy), 5, Color(0.5, 0.9, 1.0))
		var idx: int = lane.exits.find(e)
		_text(font, Vector2(ex, yy + (18 if idx % 2 == 0 else 34)), e["name"].replace("Gate to ", "> "), 12, Color(1, 1, 1, 0.65))
	var dt: Dictionary = world.dest_target()
	if not dt.is_empty():
		var ds: float = lane.closest(dt["goal"])["s"]
		var dx: float = x0 + w * ds / lane.length
		draw_colored_polygon(PackedVector2Array([Vector2(dx, yy - 8), Vector2(dx + 8, yy), Vector2(dx, yy + 8), Vector2(dx - 8, yy)]), DEST_COL)
	var px: float = x0 + w * p.lane_s / lane.length
	draw_colored_polygon(PackedVector2Array([Vector2(px, yy - 4), Vector2(px - 6, yy - 14), Vector2(px + 6, yy - 14)]), Color(1, 0.9, 0.5))


func _messages(font: Font) -> void:
	var y := maxf(size.y * 0.3, 235.0)
	for m in messages:
		var a := clampf(m["t"], 0.0, 1.0)
		_text(font, Vector2(size.x * 0.5, y), m["text"], 22, Color(m["color"], a))
		y += 30


func _text(font: Font, center: Vector2, s: String, fs: int, col: Color) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# subtle shadow for readability over bright nebula
	draw_string(font, center + Vector2(-w * 0.5 + 1, fs * 0.35 + 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, col.a * 0.6))
	draw_string(font, center + Vector2(-w * 0.5, fs * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


static func _fmt_dist(d: float) -> String:
	if d >= 1000.0:
		return "%.1f km" % (d / 1000.0)
	return "%d m" % int(d)
