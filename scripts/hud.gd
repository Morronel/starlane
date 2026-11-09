class_name Hud
extends Control
## Flight HUD drawn in screen space: crosshair, target brackets with lead pip,
## nav markers with off-screen arrows, status bars, lane info and messages.

var world: Node
var messages: Array = []   # {text, color, t}
var damage_flash := 0.0

const CY := Color(0.55, 0.88, 1.0)
const ROAD := Color(0.5, 0.88, 1.0)
const HWY := Color(1.0, 0.8, 0.42)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.message.connect(push)


## 0.11 declutter: at most two toasts, newest on top; a repeat just refreshes.
func push(text: String, color := Color(0.6, 0.9, 1.0)) -> void:
	for m in messages:
		if m["text"] == text:
			m["t"] = 3.5
			return
	messages.push_front({"text": text, "color": color, "t": 3.5})
	if messages.size() > 2:
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
	_news(font)
	_road(font, p, cam)
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
		flag = SpaceLane.KINDS[p.lane.kind]["label"]
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
	if p.mode == PlayerShip.Mode.FLIGHT and world.net:
		for nd in world.net.nodes:
			if nd["kind"] == "poi":
				continue
			if (nd["pos"] as Vector3).distance_to(p.global_position) < 14000.0:
				_marker(font, cam, nd["pos"], nd["name"], HWY if nd["kind"] == "hub" else ROAD, p, "ring")
		# nearest point on a road and on a highway: you can merge anywhere
		for pair in [[world.near_road, "Road", ROAD], [world.near_highway, "Highway", HWY]]:
			var c: Dictionary = pair[0]
			if not c.is_empty() and c["dist"] > (c["track"] as SpaceLane).radius and c["dist"] < 16000.0:
				_marker(font, cam, c["pos"], pair[1], Color(pair[2], 0.85), p, "track")
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
			"track":
				draw_line(sp + Vector2(-14, 0), sp + Vector2(14, 0), col, 3.0, true)
				draw_arc(sp, 7, 0, TAU, 16, col, 1.5, true)
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
const GPS_COL := Color(0.78, 0.58, 1.0)   # route colour: GPS panel, the lane to hold, where to join


func _destination(font: Font, p: PlayerShip, cam: Camera3D) -> void:
	var t: Dictionary = world.dest_target()
	if t.is_empty():
		return
	var dist: float = p.global_position.distance_to(t["pos"])
	if p.mode != PlayerShip.Mode.LANE:
		_marker(font, cam, t["pos"], "DEST", DEST_COL, p, "dest")
	var g: Dictionary = world.gps_info()
	if g.is_empty():
		var line := "%s  ·  %s  ·  %s" % ["AUTOPILOT" if p.autopilot else "DESTINATION", t["label"], _fmt_dist(dist)]
		_text(UiKit.display(600), Vector2(size.x * 0.5, 82), line, 15, Color(UiKit.GOOD if p.autopilot else DEST_COL, 0.95))
		return
	if g.has("join") and p.mode != PlayerShip.Mode.LANE:
		_marker(font, cam, g["join"], "JOIN", GPS_COL, p, "dest")
	_gps_panel(font, p, g, t, dist)


## GPS strip at the top: the next manoeuvre with a big arrow, how far it is,
## and the step after it.
func _gps_panel(font: Font, p: PlayerShip, g: Dictionary, t: Dictionary, dist: float) -> void:
	var w := 600.0
	var r := Rect2(size.x * 0.5 - w * 0.5, 72, w, 66)
	var col := UiKit.GOOD if p.autopilot else GPS_COL
	draw_rect(r, Color(0.02, 0.05, 0.09, 0.72))
	draw_rect(r, Color(col, 0.55), false, 1.5)
	draw_rect(Rect2(r.position, Vector2(70, r.size.y)), Color(col, 0.16))
	_gps_icon(r.position + Vector2(35, 33), g["icon"], col)
	var f := UiKit.display(700, 1)
	var ds: String = _fmt_dist(g["dist"]) if g["dist"] > 1.0 else "NOW"
	var dw := f.get_string_size(ds, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	draw_string(f, Vector2(r.end.x - 14 - dw, r.position.y + 30), ds, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.95))
	var tx := r.position.x + 84
	var max_w := r.size.x - 84 - dw - 28
	draw_string(font, Vector2(tx, r.position.y + 28), g["text"], HORIZONTAL_ALIGNMENT_LEFT, max_w, 18, Color(1, 1, 1, 0.95))
	var sub: String = g["then"]
	var tail := "%s%s  ·  %s" % ["AUTOPILOT  ·  " if p.autopilot else "", t["label"], _fmt_dist(dist)]
	var tf := UiKit.display(600)
	var tw := minf(tf.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, (r.end.x - tx) * 0.5)
	draw_string(tf, Vector2(tx, r.position.y + 52), tail, HORIZONTAL_ALIGNMENT_LEFT, tw, 12, Color(col, 0.9))
	if sub != "":
		var sx := tx + tw + 18
		draw_string(font, Vector2(sx, r.position.y + 52), sub, HORIZONTAL_ALIGNMENT_LEFT, r.end.x - 14 - sx, 13, Color(1, 1, 1, 0.55))


func _gps_icon(c: Vector2, icon: String, col: Color) -> void:
	var w := 6.0
	match icon:
		"left", "right":
			var sx := -1.0 if icon == "left" else 1.0
			var a := c + Vector2(-sx * 6, 20)
			var b := c + Vector2(-sx * 6, -2)
			var tip := c + Vector2(sx * 14, -16)
			draw_polyline(PackedVector2Array([a, b, tip]), col, w, true)
			var d := (tip - b).normalized()
			var pp := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([tip + d * 10, tip + pp * 9, tip - pp * 9]), col)
		"straight", "join":
			draw_line(c + Vector2(0, 20), c + Vector2(0, -8), col, w, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -22), c + Vector2(-10, -8), c + Vector2(10, -8)]), col)
			if icon == "join":
				draw_arc(c, 24, 0, TAU, 28, Color(col, 0.6), 2.0, true)
		"exit":
			draw_line(c + Vector2(-8, 20), c + Vector2(-8, -4), col, w, true)
			draw_line(c + Vector2(-8, -4), c + Vector2(10, -16), col, w, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(18, -22), c + Vector2(4, -20), c + Vector2(12, -8)]), col)
		"stop":
			draw_arc(c, 18, 0, TAU, 28, col, 4.0, true)
			draw_rect(Rect2(c - Vector2(7, 7), Vector2(14, 14)), col)
		_:
			draw_circle(c, 7, col)
			draw_arc(c, 20, 0, TAU, 28, Color(col, 0.6), 2.0, true)


func _lane_info(font: Font, p: PlayerShip) -> void:
	var lane: SpaceLane = p.lane
	if lane == null:
		return
	var hw := lane.kind == "highway"
	var col := HWY if hw else ROAD
	var sp: Dictionary = lane.spec()
	var y := 162.0 if not world.gps.is_empty() else 122.0
	var cx := size.x * 0.5
	var end_s: float = lane.length if p.lane_dir > 0 else 0.0
	var where: String = world.net.node_name(world.net.end_node(lane, p.lane_dir))
	var title := "GRAND HIGHWAY" if hw else "ROAD"
	var line := "%s  %s" % [where, _fmt_dist(absf(end_s - p.lane_s))]
	if lane.oneway:
		match lane.role:
			"loop":
				title = "HIGHWAY LOOP"
				var nx: Dictionary = world.net.next_exit(lane, p.lane_s)
				if not nx.is_empty():
					line = "Next: EXIT %d  %s  ·  %s" % [nx["exit_no"], nx["name"], _fmt_dist(nx["dist"])]
			"exit":
				title = "EXIT %d RAMP" % lane.exit_no
			"entry":
				title = "ON-RAMP"
				line = "Merging onto the highway loop  ·  %s" % _fmt_dist(absf(end_s - p.lane_s))
	_text(UiKit.display(700, 4), Vector2(cx, y), title, 18, Color(col, 0.9))
	_text(font, Vector2(cx, y + 28), line, 22, Color(1, 1, 1))
	# speed tier strip: free flight | road | highway, with a pip for our speed
	var w := 360.0
	var x0 := cx - w * 0.5
	var yy := y + 54.0
	var vmax := 5600.0
	var tiers := [[0.0, 320.0, Color(1, 1, 1, 0.35)], [320.0, 1300.0, ROAD], [1300.0, vmax, HWY]]
	for t in tiers:
		var a: float = x0 + w * sqrt(t[0] / vmax)
		var b: float = x0 + w * sqrt(t[1] / vmax)
		draw_line(Vector2(a + 2, yy), Vector2(b - 2, yy), Color(t[2], 0.45), 4.0)
	var px: float = x0 + w * sqrt(clampf(p.speed, 0.0, vmax) / vmax)
	draw_colored_polygon(PackedVector2Array([Vector2(px, yy - 4), Vector2(px - 6, yy - 14), Vector2(px + 6, yy - 14)]), Color(1, 0.95, 0.7))
	if lane.oneway:
		_exit_sign(font, p, Vector2(170.0, 214.0))
	else:
		_junction(font, p, Vector2(170.0, 200.0))
		_drift_gauge(p, lane, Vector2(cx, size.y - 130.0))


## 0.10: the next exit as a green motorway sign with a countdown in seconds,
## and whether you'll take it (armed by you or by the GPS) or stay on.
func _exit_sign(font: Font, p: PlayerShip, c: Vector2) -> void:
	var j: Dictionary = p.junction
	if j.is_empty() or j.get("exit", -1) < 0:
		return
	var o: Dictionary = j["options"][j["exit"]]
	var ramp: SpaceLane = o["track"]
	var armed: bool = j["armed"]
	var secs: float = j["dist"] / maxf(p.lane_speed, 1.0)
	var w := 250.0
	var r := Rect2(c.x - w * 0.5, c.y, w, 96)
	var green := Color(0.1, 0.42, 0.24)
	draw_rect(r, Color(green, 0.88 if armed else 0.6))
	draw_rect(r, Color(1, 1, 1, 0.9 if armed else 0.45), false, 2.0)
	UiKit.text_c(self, UiKit.display(800, 2), r.position + Vector2(w * 0.5, 24), "EXIT %d" % ramp.exit_no, 20, Color(1, 1, 1), false)
	UiKit.text_c(self, UiKit.display(600), r.position + Vector2(w * 0.5, 50), o["name"].to_upper(), 14, Color(1, 1, 1, 0.95), false)
	UiKit.text_c(self, UiKit.display(700), r.position + Vector2(w * 0.5, 78), "%d s" % int(ceil(secs)), 18, Color(1.0, 0.9, 0.55), false)
	var msg := "TAKING THIS EXIT" if armed else "STAYING ON"
	UiKit.text_c(self, UiKit.display(700, 2), Vector2(c.x, r.end.y + 20), msg, 13, Color(0.55, 1.0, 0.7) if armed else Color(1, 1, 1, 0.7), false)
	if not p.autopilot:
		_text(font, Vector2(c.x, r.end.y + 42), "tap STAY ON" if armed else "tap TAKE EXIT", 12, Color(1, 1, 1, 0.45))


## Upcoming junction as a lane sign: one box per lane, left to right as the
## lanes lie in the tube, each with an arrow for its turn. The lane you're in
## is lit, the one the GPS wants is framed in gold.
func _junction(font: Font, p: PlayerShip, c: Vector2) -> void:
	var j: Dictionary = p.junction
	if j.is_empty():
		return
	var title := "%s  %s" % [j["name"].to_upper(), _fmt_dist(j["dist"])]
	_text(UiKit.display(600), c, title, 14, Color(1, 1, 1, 0.8))
	var opts: Array = j["options"]
	var nb := opts.size()
	if nb == 0:
		_text(font, c + Vector2(0, 40), "End of the road", 16, Color(1, 1, 1, 0.75))
		return
	var g: Dictionary = world.gps_info()
	var gps_band: int = g.get("band", -1) if g.get("junction", -1) == j["node"] else -1
	var bw := 62.0
	var bh := 72.0
	var x0 := c.x - bw * nb * 0.5
	var y0 := c.y + 16.0
	for i in nb:
		var o: Dictionary = opts[i]
		var picked: bool = i == j["pick"]
		var r := Rect2(x0 + i * bw + 3, y0, bw - 6, bh)
		var oc: Color = HWY if o["kind"] == "highway" else (DEST_COL if o.get("stop", false) else ROAD)
		draw_rect(r, Color(oc, 0.28 if picked else 0.07))
		draw_rect(r, Color(oc, 0.9 if picked else 0.3), false, 2.0 if picked else 1.0)
		if i == gps_band:
			draw_rect(r.grow(4), GPS_COL, false, 3.0)
		var ac := Color(oc, 1.0 if picked else 0.5)
		var cc := r.get_center() + Vector2(0, -4)
		if o.get("stop", false):
			draw_rect(Rect2(cc - Vector2(9, 9), Vector2(18, 18)), ac)
			UiKit.text_c(self, UiKit.display(700), cc + Vector2(0, 26), "STOP", 10, ac, false)
		else:
			var a := deg_to_rad(float(o["turn"]))
			var d := Vector2(sin(a), -cos(a))
			var base := cc + Vector2(0, 18)
			var mid := cc + Vector2(0, 2)
			var tip := mid + d * 16.0
			draw_polyline(PackedVector2Array([base, mid, tip]), ac, 5.0 if o["kind"] == "highway" else 3.0, true)
			var pp := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([tip + d * 9.0, tip + pp * 7.0, tip - pp * 7.0]), ac)
			UiKit.text_c(self, UiKit.display(700), cc + Vector2(0, 28), "HWY" if o["kind"] == "highway" else "ROAD", 10, ac, false)
	var pk: int = j["pick"]
	if pk >= 0:
		var o: Dictionary = opts[pk]
		var lab: String = ("Stop at " + j["name"]) if o.get("stop", false) else "%s to %s" % ["Highway" if o["kind"] == "highway" else "Road", o["name"]]
		_text(font, Vector2(c.x, y0 + bh + 22), lab, 17, Color(1, 1, 1, 0.95))
	if not p.autopilot and nb > 1:
		_text(font, Vector2(c.x, y0 + bh + 44), "slide left / right in the tube to pick a lane", 12, Color(1, 1, 1, 0.45))


## Cross-section of the tube: where we are inside it and how hard the turn
## pushes us outward. Red when we're close to being thrown off.
func _drift_gauge(p: PlayerShip, lane: SpaceLane, c: Vector2) -> void:
	var r := 46.0
	var off := Vector2(p.lane_offset.x * p.lane_dir, -p.lane_offset.y) / lane.radius
	var danger := clampf((off.length() - 0.6) / 0.35, 0.0, 1.0)
	var ring_col := Color(1, 1, 1, 0.3).lerp(Color(1.0, 0.3, 0.25, 0.9), danger)
	draw_circle(c, r, Color(0, 0, 0, 0.25))
	draw_arc(c, r, 0, TAU, 40, ring_col, 2.0 + danger * 2.0, true)
	var push := Vector2(p.drift_push.x * p.lane_dir, -p.drift_push.y) / float(lane.spec()["steer"])
	var dot := c + off * r
	if push.length() > 0.05:
		var pc := Color(1.0, 0.75, 0.3, 0.9) if push.length() < 0.9 else Color(1.0, 0.3, 0.25, 0.95)
		var tip := dot + push.limit_length(1.6) * r * 0.6
		draw_line(dot, tip, pc, 2.5, true)
		var d := (tip - dot).normalized()
		draw_colored_polygon(PackedVector2Array([tip + d * 6.0, tip + Vector2(-d.y, d.x) * 4.0, tip - Vector2(-d.y, d.x) * 4.0]), pc)
	var j: Dictionary = p.junction
	if not j.is_empty() and j["bands"] > 1:
		var nb: int = j["bands"]
		var g: Dictionary = world.gps_info()
		var gb: int = g.get("band", -1) if g.get("junction", -1) == j["node"] else -1
		var bw := 2.0 * PlayerShip.BAND_WIDTH * r / nb
		for i in nb:
			var x := c.x - PlayerShip.BAND_WIDTH * r + i * bw
			if i == gb:
				draw_rect(Rect2(x, c.y - r * 0.55, bw, r * 1.1), Color(GPS_COL, 0.3))
			if i > 0:
				draw_line(Vector2(x, c.y - r * 0.55), Vector2(x, c.y + r * 0.55), Color(1, 1, 1, 0.35), 1.5)
	draw_circle(dot, 5.0, Color(0.6, 1.0, 0.75))
	UiKit.text_c(self, UiKit.display(600), c + Vector2(0, r + 16), "TURN PUSH" if push.length() > 0.2 else "IN THE TUBE", 11, Color(1, 1, 1, 0.55), false)


## 0.12: road events - the event card, ion-storm static, the photo flash,
## the cruise badge and a marker for wherever the event wants you.
func _road(font: Font, p: PlayerShip, cam: Camera3D) -> void:
	var road: RoadEvents = world.road
	if road.storm_t > 0.0:
		var a := clampf(road.storm_t, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.45, 0.3, 0.9, 0.07 * a))
		var t := Time.get_ticks_msec() * 0.001
		for i in 14:
			var y := fmod(i * 97.0 + t * 380.0 * (1.0 + i % 3), size.y)
			draw_line(Vector2(0, y), Vector2(size.x, y + sin(t * 3.0 + i) * 6.0), Color(0.75, 0.6, 1.0, 0.06 * a), 2.0)
		UiKit.text_c(self, UiKit.display(700, 3), Vector2(size.x * 0.5, 146), "ION STORM  ·  LANES AT HALF SPEED  ·  %d s" % int(road.storm_t), 14, Color(0.8, 0.7, 1.0, 0.85), false)
	if road.photo_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, road.photo_flash * 0.6))
		var fr := Rect2(size * 0.5 - Vector2(260, 150), Vector2(520, 300))
		draw_rect(fr, Color(1, 1, 1, road.photo_flash), false, 3.0)
	if road.cruise:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		UiKit.text_c(self, UiKit.display(800, 4), Vector2(size.x * 0.5, size.y - 70), "CRUISE  x3", 18, Color(0.55, 1.0, 0.75, 0.6 + pulse * 0.35), false)
	var mk := road.marker()
	if not mk.is_empty():
		_marker(font, cam, mk["pos"], mk["label"], Color(0.5, 1.0, 0.7), p, "dest")
	var ev: Dictionary = road.ev
	if ev.has("title") and ev.get("phase", "") in ["offer", "toll", "scan"]:
		var w := 560.0
		var r := Rect2(size.x * 0.5 - w * 0.5, 160, w, 86)
		var col: Color = ev.get("color", Color(0.75, 0.85, 1.0))
		draw_rect(r, Color(0.02, 0.04, 0.08, 0.78))
		draw_rect(r, Color(col, 0.7), false, 2.0)
		draw_rect(Rect2(r.position, Vector2(5, r.size.y)), col)
		UiKit.text_c(self, UiKit.display(800, 3), Vector2(r.get_center().x, r.position.y + 18), str(ev["title"]), 16, col, false)
		var body: String = ev.get("text", "")
		var lines := _wrap(font, body, 15, w - 40)
		for i in mini(lines.size(), 3):
			_text(font, Vector2(r.get_center().x, r.position.y + 40 + i * 18), lines[i], 15, Color(1, 1, 1, 0.85))
		var tleft: float = ev.get("t", 0.0)
		var tmax := 22.0 if ev["phase"] == "offer" else (12.0 if ev["phase"] == "toll" else 5.0)
		draw_rect(Rect2(r.position.x + 5, r.end.y - 4, (r.size.x - 5) * clampf(tleft / tmax, 0.0, 1.0), 4), Color(col, 0.8))


func _wrap(font: Font, text: String, fs: int, w: float) -> Array:
	var out := []
	var cur := ""
	for word in text.split(" "):
		var t := word if cur == "" else cur + " " + word
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = t
	if cur != "":
		out.append(cur)
	return out


## News ticker: the latest galactic headline for a few seconds, low and small.
func _news(font: Font) -> void:
	if Economy.news.is_empty():
		return
	var n: Dictionary = Economy.news[0]
	var age: float = Economy.clock - float(n["time"])
	if age > 14.0:
		return
	var a := clampf(minf(age * 2.0, (14.0 - age) * 0.5), 0.0, 1.0)
	var txt := "NEWS  ·  " + str(n["text"])
	var y := size.y - 104.0
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_rect(Rect2(size.x * 0.5 - w * 0.5 - 12, y - 14, w + 24, 26), Color(0.02, 0.04, 0.08, 0.55 * a))
	_text(font, Vector2(size.x * 0.5, y), txt, 15, Color(n.get("color", Color(1, 0.85, 0.5)), 0.9 * a))


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
