class_name CockpitScreen
extends Control
## One cockpit display, drawn into a small SubViewport that is mapped onto a
## quad in the cabin. Modes: radar, status, nav, weapons, cargo.

var mode := "radar"
var accent := Color(0.4, 0.9, 1.0)
var player: PlayerShip
var world: Node
var holo := false   # transparent background (hologram projector)

const RADAR_RANGE := 4000.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var s := size
	if not holo:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.01, 0.02, 0.035))
		# scanlines and a soft frame
		var line := Color(accent, 0.05)
		for y in range(0, int(s.y), 4):
			draw_line(Vector2(0, y), Vector2(s.x, y), line, 1.0)
		draw_rect(Rect2(Vector2(3, 3), s - Vector2(6, 6)), Color(accent, 0.35), false, 2.0)
	match mode:
		"radar":
			_radar(s)
		"status":
			_status(s)
		"nav":
			_nav(s)
		"weapons":
			_weapons(s)
		"cargo":
			_cargo(s)
	if GameState.hull < GameState.max_hull() * 0.3 and fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.4:
		draw_rect(Rect2(Vector2(3, 3), s - Vector2(6, 6)), Color(1.0, 0.2, 0.15, 0.8), false, 4.0)


func _title(t: String, s: Vector2) -> void:
	draw_string(UiKit.display(700, 2), Vector2(12, 26), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(accent, 0.85))


func _radar(s: Vector2) -> void:
	var c := Vector2(s.x * 0.5, s.y * 0.54)
	var r := minf(s.x, s.y) * 0.42
	for k in [1.0, 0.66, 0.33]:
		draw_arc(c, r * k, 0, TAU, 48, Color(accent, 0.22 if k < 1.0 else 0.5), 1.5, true)
	draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(accent, 0.15), 1.0)
	draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(accent, 0.15), 1.0)
	# rotating sweep
	var a := fmod(Time.get_ticks_msec() / 1000.0 * 2.2, TAU)
	for i in 10:
		var aa := a - i * 0.06
		draw_line(c, c + Vector2(cos(aa), sin(aa)) * r, Color(accent, 0.25 * (1.0 - i / 10.0)), 2.0)
	var inv := player.global_transform.affine_inverse()
	for st in get_tree().get_nodes_in_group("stations"):
		_blip(inv, (st as Node3D).global_position, c, r, Color(0.9, 0.95, 1.0), "sq")
	for g in get_tree().get_nodes_in_group("stargates"):
		_blip(inv, (g as Node3D).global_position, c, r, Color(0.75, 0.5, 1.0), "sq")
	for l in get_tree().get_nodes_in_group("loot"):
		_blip(inv, (l as Node3D).global_position, c, r, Color(0.4, 1.0, 0.6), "dot")
	for e in get_tree().get_nodes_in_group("enemies"):
		_blip(inv, (e as Node3D).global_position, c, r, Color(1.0, 0.3, 0.25), "tri")
	if world and world.has_method("dest_target"):
		var d: Dictionary = world.dest_target()
		if not d.is_empty():
			_blip(inv, d["pos"], c, r, Color(1.0, 0.8, 0.3), "dest")
	# own ship
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(5, 5), c + Vector2(-5, 5)]), accent)
	_title("RADAR 4 KM", s)


func _blip(inv: Transform3D, wpos: Vector3, c: Vector2, r: float, col: Color, kind: String) -> void:
	var l := inv * wpos
	var p := Vector2(l.x, l.z) / RADAR_RANGE * r
	var edge := p.length() > r
	if edge:
		if kind == "dot":
			return
		p = p.normalized() * r
	var q := c + p
	var above := l.y > 150.0
	var below := l.y < -150.0
	match kind:
		"sq":
			draw_rect(Rect2(q - Vector2(3.5, 3.5), Vector2(7, 7)), col if not edge else Color(col, 0.5))
		"dot":
			draw_circle(q, 2.5, col)
		"tri":
			draw_colored_polygon(PackedVector2Array([q + Vector2(0, -5), q + Vector2(4.5, 4), q + Vector2(-4.5, 4)]), col)
		"dest":
			draw_arc(q, 6.0, 0, TAU, 16, col, 2.0, true)
			draw_circle(q, 2.0, col)
	if above or below:
		draw_line(q, q + Vector2(0, -6 if above else 6), Color(col, 0.7), 1.5)


func _bar(pos: Vector2, w: float, h: float, frac: float, col: Color, label: String) -> void:
	var font := UiKit.display(700, 1)
	draw_string(font, pos + Vector2(0, -6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(col, 0.85))
	draw_rect(Rect2(pos, Vector2(w, h)), Color(col, 0.15))
	var segs := 12
	var sw := w / segs
	for i in segs:
		if float(i) / segs < clampf(frac, 0.0, 1.0):
			draw_rect(Rect2(pos + Vector2(i * sw + 1, 1), Vector2(sw - 2, h - 2)), col)


func _status(s: Vector2) -> void:
	var font := UiKit.display(800, 1)
	var spd := str(int(player.speed))
	draw_string(font, Vector2(14, 70), spd, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(1, 1, 1, 0.95))
	draw_string(UiKit.display(600), Vector2(18 + font.get_string_size(spd, 0, -1, 44).x, 70), "M/S", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(accent, 0.8))
	var flag := ""
	if player.mode == PlayerShip.Mode.LANE:
		flag = "LANE"
	if player.autopilot:
		flag = "AUTO" if flag == "" else flag + " · AUTO"
	if flag != "":
		var fw := UiKit.display(700).get_string_size(flag, 0, -1, 14).x
		draw_string(UiKit.display(700), Vector2(s.x - fw - 14, 26), flag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 1.0, 0.7))
	var ms := GameState.max_shield()
	var bw := s.x - 28.0
	_bar(Vector2(14, 104), bw, 14, player.shield / ms if ms > 0.0 else 0.0, Color(0.35, 0.8, 1.0), "SHIELD")
	_bar(Vector2(14, 142), bw, 14, GameState.hull / GameState.max_hull(), Color(1.0, 0.6, 0.25), "HULL")
	_bar(Vector2(14, 180), bw, 10, player.boost_energy, Color(0.85, 0.85, 1.0), "BOOST")
	# throttle tape
	var t := GameInput.throttle
	draw_rect(Rect2(s.x - 22, 40, 8, 40), Color(accent, 0.15))
	draw_rect(Rect2(s.x - 22, 40 + 40 * (1.0 - t), 8, 40 * t), Color(accent, 0.8))


func _nav(s: Vector2) -> void:
	_title("NAV", s)
	var font := UiKit.body(600)
	var d: Dictionary = world.dest_target() if world and world.has_method("dest_target") else {}
	if d.is_empty():
		UiKit.text_c(self, UiKit.display(700), Vector2(s.x * 0.5, s.y * 0.45), "NO COURSE", 22, Color(accent, 0.6), false)
		UiKit.text_c(self, font, Vector2(s.x * 0.5, s.y * 0.66), "Set one on the star map", 15, Color(1, 1, 1, 0.45), false)
		return
	var label: String = d["label"]
	if label.length() > 26:
		label = label.substr(0, 25) + "…"
	UiKit.text_c(self, font, Vector2(s.x * 0.5, 52), label, 17, Color(1, 0.9, 0.6), false)
	var pos: Vector3 = d["pos"]
	var dist := player.global_position.distance_to(pos)
	var ds := "%.1f km" % (dist / 1000.0) if dist >= 1000.0 else "%d m" % int(dist)
	UiKit.text_c(self, UiKit.display(800), Vector2(s.x * 0.5, s.y - 28), ds, 26, Color(1, 1, 1, 0.95), false)
	# heading arrow: where the destination sits relative to the nose
	var l := player.global_transform.affine_inverse() * pos
	var dir := Vector2(l.x, l.y)
	var c := Vector2(s.x * 0.5, s.y * 0.53)
	draw_arc(c, 38, 0, TAU, 32, Color(accent, 0.3), 2.0, true)
	if l.z < 0.0 and dir.length() < -l.z * 0.12:
		draw_arc(c, 10, 0, TAU, 16, Color(0.5, 1.0, 0.7), 3.0, true)
		draw_circle(c, 3, Color(0.5, 1.0, 0.7))
	else:
		if dir.length() < 0.001:
			dir = Vector2(0, -1)
		var a := Vector2(dir.x, -dir.y).normalized()
		var tip := c + a * 34.0
		var side := Vector2(-a.y, a.x)
		draw_colored_polygon(PackedVector2Array([tip, tip - a * 18 + side * 10, tip - a * 18 - side * 10]), Color(1.0, 0.8, 0.3))
		if l.z > 0.0:
			UiKit.text_c(self, UiKit.display(700), c, "BEHIND", 11, Color(1, 1, 1, 0.6), false)


func _weapons(s: Vector2) -> void:
	_title("WEAPONS", s)
	var font := UiKit.body(600)
	var guns: Array = GameState.equip.get("primary", [])
	var y := 52.0
	for i in guns.size():
		var id: String = guns[i]
		if id == "":
			draw_string(font, Vector2(14, y), "— empty —", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.3))
		else:
			var w: Dictionary = Items.GEAR[id]
			var cd: float = player.weapon_cd[i] if i < player.weapon_cd.size() else 0.0
			var ready := 1.0 - clampf(cd / float(w["cd"]), 0.0, 1.0)
			var col: Color = w["color"]
			col = Color(minf(col.r, 1.0), minf(col.g, 1.0), minf(col.b, 1.0))
			draw_rect(Rect2(14, y - 12, 10, 10), col if ready >= 1.0 else Color(col, 0.3))
			var nm: String = w["name"]
			if nm.length() > 20:
				nm = nm.substr(0, 19) + "…"
			draw_string(font, Vector2(32, y), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.85))
			draw_rect(Rect2(s.x - 70, y - 10, 56 * ready, 6), Color(accent, 0.8))
		y += 28.0
	var sec: Array = GameState.equip.get("secondary", [])
	var msl := ""
	for id in sec:
		if id != "":
			msl = Items.GEAR[id]["name"]
	if msl != "":
		var ammo_id: String = ""
		for id in sec:
			if id != "":
				ammo_id = Items.GEAR[id].get("ammo", "")
		var n: int = GameState.ammo.get(ammo_id, 0)
		draw_string(UiKit.display(700), Vector2(14, s.y - 16), "MSL  %d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.8, 0.45))
	var tgt := player.target
	if tgt and is_instance_valid(tgt):
		var dist := int(player.global_position.distance_to(tgt.global_position))
		var t := "LOCK %d m" % dist
		var tw := UiKit.display(700).get_string_size(t, 0, -1, 14).x
		draw_string(UiKit.display(700), Vector2(s.x - tw - 14, s.y - 16), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.35, 0.3))


func _cargo(s: Vector2) -> void:
	_title("HOLD", s)
	var used := GameState.cargo_used()
	var cap := maxi(1, GameState.cargo_capacity())
	var font := UiKit.display(800)
	UiKit.text_c(self, font, Vector2(s.x * 0.5, s.y * 0.42), "%d / %d" % [used, cap], 30, Color(1, 1, 1, 0.95), false)
	var cols := 10
	var cell := (s.x - 28.0) / cols
	var filled := int(round(float(used) / cap * cols * 2))
	for i in cols * 2:
		var x := 14.0 + (i % cols) * cell
		var y := s.y * 0.6 + floorf(i / float(cols)) * 22.0
		draw_rect(Rect2(x + 1, y, cell - 3, 18), Color(1.0, 0.75, 0.3) if i < filled else Color(accent, 0.15))
	draw_string(UiKit.body(600), Vector2(14, s.y - 12), "%d cr" % GameState.credits, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.9, 0.55))
