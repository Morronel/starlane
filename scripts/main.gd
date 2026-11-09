extends Node3D
## Builds the current star system and runs the game loop:
## dock -> trade / take a contract -> lane -> fight -> upgrade -> jump to the next system.

var env: SpaceEnv
var camera: ChaseCam
var cockpit: Cockpit
var player: PlayerShip
var net: RoadNet
var combat: Combat
var stations := {}
var gates := {}            # link system id -> Stargate
var beacon_pos := Vector3.ZERO
var field_center := Vector3.ZERO
var rocks: Array = []      # {pos, r}
var world_root: Node3D
var _side := Vector3.RIGHT
var _wonder: Node3D
var site_pos := Vector3.ZERO   # 0.13: a safe spot in front of the wonder (surveys, salvage)

var hud: Hud
var touch: TouchControls
var menu: StationMenu
var star_map: StarMap
var settings_panel: SettingsPanel
var title: TitleMenu
var fade: ColorRect
var sfx: Sfx
var road: RoadEvents

var _ambient_timer := 0.0
var _combat_hold := 0.0
var _respawning := false
var _jumping := false
var _last_target: Node3D
var _alarm_t := 0.0
var _near_t := 0.0
var near_road := {}       # closest road / highway point, refreshed 4x a second
var near_highway := {}
var _ap_plan := {}
var _ap_plan_t := 0.0
var _ap_plan_goal := Vector3.INF
var gps := {}             # turn-by-turn route to the destination: {rides, leave}
var _gps_t := 0.0
var _gps_chimed := -1


func _ready() -> void:
	sfx = Sfx.new()
	add_child(sfx)

	camera = ChaseCam.new()
	add_child(camera)
	camera.make_current()

	env = SpaceEnv.new()
	add_child(env)
	env.setup(camera)

	combat = Combat.new()
	combat.world = self
	add_child(combat)

	player = PlayerShip.new()
	player.world = self
	add_child(player)
	player.died.connect(_on_player_died)
	player.docked.connect(_on_docked)
	player.lane_changed.connect(func(on): sfx.lane(on))
	camera.target = player
	cockpit = Cockpit.new()
	cockpit.player = player
	cockpit.world = self
	camera.add_child(cockpit)

	road = RoadEvents.new()
	road.main = self
	add_child(road)

	_build_ui()
	GameInput.auto_fire_changed.connect(_on_auto_fire)
	GameInput.radio_pressed.connect(_radio)
	GameInput.photo_pressed.connect(_photo)
	GameInput.action2_pressed.connect(_action2)
	GameInput.map_pressed.connect(_toggle_map)
	GameInput.autopilot_pressed.connect(toggle_autopilot)
	GameState.mission_completed.connect(func(): sfx.play("mission_complete", -2.0))

	restart_from_save(true)
	var dev_run := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest=") or arg.begins_with("--cockpits=") or arg == "--simtest":
			dev_run = true
	if not dev_run:
		show_title()

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest=") or arg.begins_with("--cockpits="):
			var t: Node = load("res://scripts/autotest.gd").new()
			t.set("main", self)
			t.set("out_dir", arg.substr(11))
			t.set("cockpits_only", arg.begins_with("--cockpits="))
			add_child(t)
		elif arg == "--simtest":
			var s: Node = load("res://scripts/simtest.gd").new()
			s.set("main", self)
			add_child(s)


## Main menu over the orbiting station view (the game behind it is docked).
func show_title() -> void:
	if player.mode != PlayerShip.Mode.DOCKED:
		if player.mode != PlayerShip.Mode.DEAD:
			GameState.save_game()
		restart_from_save()
	menu.visible = false
	touch.reset()
	title.open()


func _enter_game(reload: bool, first := false) -> void:
	title.visible = false
	if reload:
		restart_from_save(first)
	else:
		_show_menu(player.dock_station, [])


## (Re)start docked at the saved station.
func restart_from_save(first := false) -> void:
	title.visible = false
	load_system(GameState.system_id)
	player.refresh_ship()
	player.autopilot = false
	var st: Station = stations.get(GameState.last_station, stations.values()[0])
	player.global_transform = st.undock_transform()
	player.dock_station = st
	player.mode = PlayerShip.Mode.DOCKED
	player.model.visible = false
	camera.global_position = st.global_position + Vector3(300, 120, -300)
	camera.look_at(st.global_position)
	var notes := ["Welcome aboard, pilot. Take a contract, trade cargo, then LAUNCH."] if first and GameState.kills == 0 else []
	_show_menu(st, notes)


# --- World -----------------------------------------------------------------------

func load_system(id: String) -> void:
	GameState.system_id = id
	GameState.visited[id] = true
	var sysd: Dictionary = Galaxy.SYSTEMS[id]
	if world_root:
		remove_child(world_root)
		world_root.queue_free()
	combat.clear_all()
	stations.clear()
	gates.clear()
	rocks.clear()
	world_root = Node3D.new()
	world_root.name = "System_" + id
	add_child(world_root)
	env.apply_system(sysd["sky"])
	_build_system(id, sysd)
	sfx.flight_pitch = 0.94 + fmod(float(sysd["sky"]["seed"]) * 0.37, 0.12)
	road.reset_system(id, _wonder)
	player.net = net
	player.lane = null
	_ambient_timer = 0.0
	_spawn_ambient_raiders()
	_spawn_mission_props()


func _build_system(id: String, sysd: Dictionary) -> void:
	## A system ~70 km across: one one-way highway loop with an exit ramp and an
	## entry ramp for every station, stargate and the beacon (see below).
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var sky: Dictionary = sysd["sky"]
	var up := Vector3.UP
	var rot := rng.randf() * TAU
	var R := rng.randf_range(30000.0, 35000.0)
	var at := func(ang: float, r: float, y: float) -> Vector3:
		return Vector3(cos(ang) * r, y, sin(ang) * r)
	var gold := Color(1.0, 0.85, 0.45)

	net = RoadNet.new()
	net.name = "RoadNet"
	world_root.add_child(net)
	net.set_palette(sky)

	# 0.10 "roads for humans": ONE one-way highway loop around the system.
	# Every station, stargate and the beacon sits on its own exit ramp that
	# peels off the loop at a gentle angle, and an entry ramp brings you back
	# on a little further along. Every fork is "stay on" or "take the exit".
	var wob := rng.randf() * TAU
	var yph := rng.randf() * TAU
	var ring := func(th: float) -> Vector3:
		var rr: float = R * (1.0 + 0.035 * sin(3.0 * th + wob))
		return Vector3(cos(th) * rr, 1300.0 * sin(2.0 * th + yph), sin(th) * rr)
	var ring_tan := func(th: float) -> Vector3:
		return ((ring.call(th + 0.0005) as Vector3) - (ring.call(th - 0.0005) as Vector3)).normalized()
	var radial := func(th: float) -> Vector3:
		return Vector3(cos(th), 0.0, sin(th))
	var sdefs: Array = sysd["stations"]
	var links: Array = sysd["links"]
	var pois := []   # {kind, def/link, side}
	for i in sdefs.size():
		pois.append({"kind": "station", "def": sdefs[i], "side": -1.0 if i % 2 == 0 else 1.0})
	for l in links:
		pois.append({"kind": "gate", "link": l, "side": 1.0})
	pois.append({"kind": "beacon", "side": 1.0})
	# shuffle so gates and stations mix around the loop
	for i in range(pois.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = pois[i]
		pois[i] = pois[j]
		pois[j] = tmp
	var N := pois.size()
	var span := TAU / N
	var ramp_arc := minf(11000.0, R * span * 0.38)
	var dth := ramp_arc / R
	var off := 5200.0
	var loop_nodes := []   # [{node, th}] in loop order
	var exit_no := 0
	var ramps := []        # [{je, jn, poi_node, th, out, dir_in}]
	for i in N:
		var th: float = rot + i * span + rng.randf_range(-0.06, 0.06)
		var poi: Dictionary = pois[i]
		var out: Vector3 = (radial.call(th) as Vector3) * float(poi["side"])
		var T: Vector3 = ring_tan.call(th)
		var P: Vector3 = (ring.call(th) as Vector3) + out * off
		var dir_in: Vector3 = (T * cos(deg_to_rad(40.0)) + out * sin(deg_to_rad(40.0))).normalized()
		var name := ""
		var color := gold
		match poi["kind"]:
			"station":
				var sp: Vector3 = P + dir_in * 2200.0 + up * rng.randf_range(-100.0, 100.0)
				var st := _make_station(poi["def"], sp, (P - sp).normalized(), i * 0.6)
				name = st.display_name
				color = st.accent
			"gate":
				var lk: String = poi["link"]
				var gp: Vector3 = P + dir_in * 2600.0 + up * 150.0
				var sg := Stargate.new()
				sg.link = lk
				sg.display_name = "Gate: " + Galaxy.SYSTEMS[lk]["name"]
				sg.color = (Galaxy.SYSTEMS[lk]["sky"]["c"] as Color).lerp(Color(1, 0.9, 0.6), 0.4)
				world_root.add_child(sg)
				sg.global_transform = Transform3D(Basis.looking_at((P - gp).normalized(), up), gp)
				sg.build()
				gates[lk] = sg
				name = "Gate to " + Galaxy.SYSTEMS[lk]["name"]
			"beacon":
				beacon_pos = P + dir_in * 3000.0 - up * 300.0
				_side = dir_in.cross(up).normalized()
				name = "Beacon"
				color = Color(0.7, 0.5, 1.0)
		exit_no += 1
		var pn := net.add_node(name, P, "poi", color)
		var je := net.add_node("Exit %d" % exit_no, ring.call(th - dth), "exit", gold)
		var jn := net.add_node("%s on-ramp" % name, ring.call(th + dth), "merge", gold)
		loop_nodes.append({"node": je, "th": th - dth})
		loop_nodes.append({"node": jn, "th": th + dth})
		ramps.append({"je": je, "jn": jn, "pn": pn, "th": th, "out": out, "dir_in": dir_in, "no": exit_no})
	# the loop, segment by segment, sampled straight off the ring curve so it
	# runs smooth through every junction
	for i in loop_nodes.size():
		var a: Dictionary = loop_nodes[i]
		var b: Dictionary = loop_nodes[(i + 1) % loop_nodes.size()]
		var th0: float = a["th"]
		var th1: float = b["th"]
		while th1 <= th0:
			th1 += TAU
		var n := maxi(8, int((th1 - th0) * R / 600.0))
		var pts := []
		for k in n + 1:
			pts.append(ring.call(lerpf(th0, th1, float(k) / n)))
		net.add_track_pts(a["node"], b["node"], "highway", pts, "loop", true, rng)
	# ramps: off the loop at 10 degrees, into the destination at 40 degrees;
	# back on from the destination, merging at 10 degrees
	var ten := deg_to_rad(10.0)
	for r in ramps:
		var th: float = r["th"]
		var out: Vector3 = r["out"]
		var pe: Vector3 = ring.call(th - dth)
		var pnn: Vector3 = ring.call(th + dth)
		var P: Vector3 = net.nodes[r["pn"]]["pos"]
		var te: Vector3 = ring_tan.call(th - dth)
		var oe: Vector3 = (radial.call(th - dth) as Vector3) * signf(out.dot(radial.call(th)))
		var ta: Vector3 = (te * cos(ten) + oe * sin(ten)).normalized()
		net.add_track_pts(r["je"], r["pn"], "road", net.ramp_pts(pe, P, ta, r["dir_in"]), "exit", true, rng, r["no"])
		var tn: Vector3 = ring_tan.call(th + dth)
		var on: Vector3 = (radial.call(th + dth) as Vector3) * signf(out.dot(radial.call(th)))
		var T: Vector3 = ring_tan.call(th)
		var t0: Vector3 = (T * cos(ten) - out * sin(ten)).normalized()
		var t1: Vector3 = (tn * cos(ten) - on * sin(ten)).normalized()
		net.add_track_pts(r["pn"], r["jn"], "road", net.ramp_pts(P, pnn, t0, t1), "entry", true, rng)
	net.build_nodes(sky)

	# 0.12: the system's wonder, just outside the loop between two exits
	_wonder = null
	if sysd.has("wonder"):
		var thw := rot + span * 0.5
		var wpos: Vector3 = (ring.call(thw) as Vector3) + (radial.call(thw) as Vector3) * 11000.0 + up * 1800.0
		var sk: Dictionary = sysd["sky"]
		_wonder = Wonders.build(sysd["wonder"]["kind"], sk["c"], sk["b"], hash(id) + 7)
		world_root.add_child(_wonder)
		_wonder.global_position = wpos
		_wonder.rotate_y(rng.randf() * TAU)
		site_pos = wpos + ((ring.call(thw) as Vector3) - wpos).normalized() * 5000.0

	var bea := MeshInstance3D.new()
	bea.mesh = Models.beacon(Color(0.7, 0.5, 1.0))
	world_root.add_child(bea)
	var bout := _side.cross(up).normalized() * -1.0
	bea.global_position = beacon_pos - bout * 200.0
	field_center = beacon_pos + bout * 2200.0
	_build_asteroids(field_center, rng)
	# salvage drifting in the field
	for i in 16:
		var lp := field_center + Vector3(rng.randfn() * 1000.0, rng.randfn() * 250.0, rng.randfn() * 1000.0)
		spawn_loot(lp, Loot.salvage_drop(rng), true)


func spawn_loot(pos: Vector3, contents: Dictionary, drift := false) -> void:
	var l := Loot.new()
	world_root.add_child(l)
	l.setup(self, pos, contents, drift)


func _make_station(def: Dictionary, pos: Vector3, facing: Vector3, roll: float) -> Station:
	var s := Station.new()
	s.station_id = def["id"]
	s.display_name = def["name"]
	s.kind = def["kind"]
	s.accent = def["accent"]
	s.variant = def["variant"]
	world_root.add_child(s)
	s.global_transform = Transform3D(Basis.looking_at(facing, Vector3.UP).rotated(facing, roll), pos)
	s.build()
	stations[s.station_id] = s
	return s


func _build_asteroids(center: Vector3, rng: RandomNumberGenerator) -> void:
	var variants: Array[ArrayMesh] = []
	var tint: Color = (Galaxy.SYSTEMS[GameState.system_id]["sky"]["p2"] as Color).lerp(Color(0.5, 0.45, 0.4), 0.6)
	for i in 4:
		var mb := MeshBuilder.new()
		mb.rock("hull", 1.0, tint.lerp(Color(0.62, 0.55, 0.46), rng.randf()), rng)
		variants.append(mb.build({"hull": MeshBuilder.rock_material()}))
	var per := [[], [], [], []]
	for i in 420:
		var p := center + Vector3(rng.randfn() * 1300.0, rng.randfn() * 380.0, rng.randfn() * 1300.0)
		if not net.closest(p, 500.0).is_empty():
			continue
		var r := pow(rng.randf(), 3.0) * 80.0 + 5.0
		rocks.append({"pos": p, "r": r * 0.9})
		var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3.ONE * r)
		per[i % 4].append(Transform3D(basis, p))
	for k in 4:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = variants[k]
		mm.instance_count = per[k].size()
		for j in per[k].size():
			mm.set_instance_transform(j, per[k][j])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		world_root.add_child(mmi)


func asteroid_push(ship: Node3D) -> void:
	for r in rocks:
		var d: Vector3 = ship.global_position - r["pos"]
		var min_d: float = r["r"] + 3.0
		if d.length_squared() < min_d * min_d:
			var n := d.normalized()
			ship.global_position = r["pos"] + n * min_d
			var hit_speed: float = -ship.velocity.dot(n)
			if hit_speed > 0.0:
				ship.velocity += n * hit_speed * 1.4
				if hit_speed > 25.0:
					ship.take_damage(hit_speed * 0.3)
					shake(0.6)
				ship.speed = ship.velocity.length()


# --- Enemies ---------------------------------------------------------------------

func _spawn_raider(pos: Vector3, elite := false) -> void:
	var r := Raider.new()
	world_root.add_child(r)
	r.setup(self, pos, elite)


func _spawn_ambient_raiders() -> void:
	var threat: int = Galaxy.SYSTEMS[GameState.system_id]["threat"]
	for i in 1 + threat:
		_spawn_raider(beacon_pos + _side * (600.0 + i * 140.0) + Vector3(0, 60 * i, 0), threat >= 3 and i == 0)


## 0.13: black boxes for salvage contracts in this system.
func _spawn_mission_props() -> void:
	for m in GameState.missions:
		if m["kind"] == "salvage" and m["state"] == "active" and m["system"] == GameState.system_id:
			var have := false
			for l in get_tree().get_nodes_in_group("loot"):
				if l.mission_id == m["id"]:
					have = true
			if not have:
				spawn_loot(site_pos + Vector3(randf_range(-200, 200), randf_range(-80, 80), randf_range(-200, 200)), {"mission": m["id"], "parts": {"scrap": 2}}, true)


func _spawn_mission_wave(m: Dictionary) -> void:
	var n: int = m["left"] - get_tree().get_nodes_in_group("enemies").size()
	var centre := beacon_pos
	if m.has("site") and stations.has(m["site"]):
		centre = (stations[m["site"]] as Station).global_position + (stations[m["site"]] as Station).global_transform.basis.x * 1200.0
	for i in maxi(n, 0):
		var p := centre + _side * randf_range(500, 1000) + Vector3(randf_range(-300, 300), randf_range(-150, 150), randf_range(-300, 300))
		_spawn_raider(p, i == 0)
	m["spawned"] = true


func pick_target(p: PlayerShip) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	var fwd := -p.global_transform.basis.z
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: Vector3 = e.global_position - p.global_position
		var dist := d.length()
		if dist > 3000.0:
			continue
		var ang := rad_to_deg(fwd.angle_to(d))
		if ang > 50.0:
			continue
		var score := ang * 40.0 + dist
		if score < best_score:
			best_score = score
			best = e
	return best


func lead_point(origin: Vector3, t: Node3D, bolt_speed: float) -> Vector3:
	var v: Vector3 = t.velocity
	var p := t.global_position
	var aim := p
	for i in 2:
		var time := origin.distance_to(aim) / bolt_speed
		aim = p + v * time
	return aim


# --- UI ----------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	hud = Hud.new()
	hud.world = self
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	layer.add_child(hud)
	touch = TouchControls.new()
	touch.process_mode = Node.PROCESS_MODE_PAUSABLE
	layer.add_child(touch)
	touch.map_tapped.connect(_toggle_map)
	touch.autopilot_tapped.connect(toggle_autopilot)
	touch.settings_tapped.connect(_open_settings)
	touch.radio_tapped.connect(_radio)
	touch.photo_tapped.connect(_photo)
	touch.action2_tapped.connect(_action2)
	menu = StationMenu.new()
	menu.world = self
	menu.visible = false
	layer.add_child(menu)
	menu.launch_pressed.connect(_launch)
	menu.map_pressed.connect(func(): _open_map(false))
	menu.settings_pressed.connect(_open_settings)
	star_map = StarMap.new()
	star_map.world = self
	star_map.visible = false
	layer.add_child(star_map)
	star_map.closed.connect(_close_overlay)
	star_map.jump_requested.connect(_on_jump_requested)
	star_map.autopilot_requested.connect(func():
		_close_overlay()
		toggle_autopilot())
	title = TitleMenu.new()
	title.world = self
	title.visible = false
	layer.add_child(title)
	title.continue_pressed.connect(func(): _enter_game(false))
	title.loaded.connect(func(): _enter_game(true))
	title.new_game_pressed.connect(func():
		GameState.reset_game()
		GameState.save_game()
		_enter_game(true, true))
	title.settings_pressed.connect(_open_settings)
	settings_panel = SettingsPanel.new()
	settings_panel.world = self
	settings_panel.visible = false
	layer.add_child(settings_panel)
	settings_panel.closed.connect(_close_overlay)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)


func _toggle_map() -> void:
	if star_map.visible:
		_close_overlay()
	elif not settings_panel.visible and not _jumping:
		_open_map(false)


func _open_map(jump_mode: bool) -> void:
	touch.reset()
	star_map.open(jump_mode)
	get_tree().paused = player.mode != PlayerShip.Mode.DOCKED


func _open_settings() -> void:
	touch.reset()
	settings_panel.open()
	get_tree().paused = player.mode != PlayerShip.Mode.DOCKED


func _close_overlay() -> void:
	star_map.visible = false
	settings_panel.visible = false
	get_tree().paused = false
	if menu.visible:
		menu._rebuild()   # credits/ship may have changed in the dev menu


func shake(a: float) -> void:
	camera.shake(a)


func flash_damage() -> void:
	hud.damage_flash = 1.0


func sfx_laser(team: int, pos: Vector3) -> void:
	sfx.laser(team, player.global_position.distance_to(pos))


func sfx_boom(pos: Vector3, big := false) -> void:
	sfx.boom(player.global_position.distance_to(pos), big)


func _process(delta: float) -> void:
	env.set_dust_velocity(player.velocity)
	if not GameState.trip.is_empty() and (player.mode == PlayerShip.Mode.FLIGHT or player.mode == PlayerShip.Mode.LANE):
		GameState.trip["dist"] = float(GameState.trip.get("dist", 0.0)) + player.speed * delta
	var flying := player.mode == PlayerShip.Mode.FLIGHT or player.mode == PlayerShip.Mode.LANE
	sfx.engine(player.speed / player.top_speed(), flying or player.mode == PlayerShip.Mode.JUMPING)
	# combat music while raiders are actually fighting us (with a hold so it doesn't flap)
	_combat_hold -= delta
	if flying:
		if player.shield_delay > 1.0:
			_combat_hold = maxf(_combat_hold, 6.0)
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.engaged() and e.global_position.distance_to(player.global_position) < 2600.0:
				_combat_hold = 8.0
				break
	if player.mode == PlayerShip.Mode.DOCKED:
		_combat_hold = 0.0
		sfx.music("bar" if menu.visible and menu._tab == "bar" else "station")
	else:
		sfx.music("combat" if _combat_hold > 0.0 else "flight")
	touch.visible = flying and not star_map.visible and not settings_panel.visible
	hud.visible = not menu.visible and not star_map.visible and not settings_panel.visible and not title.visible
	net.set_intensity(player.lane if player.mode == PlayerShip.Mode.LANE else null)
	_near_t -= delta
	if _near_t <= 0.0:
		_near_t = 0.25
		near_road = net.closest(player.global_position, INF, "road")
		near_highway = net.closest(player.global_position, INF, "highway")

	# target lock blip
	if player.target != _last_target:
		_last_target = player.target
		if _last_target:
			sfx.play("target_lock", -8.0)
	# low hull alarm
	_alarm_t -= delta
	if flying and GameState.hull < 25.0 and _alarm_t <= 0.0:
		_alarm_t = 3.0
		sfx.play("alarm", -8.0)

	# context action: enter lane / exit lane / dock / jump
	var label := ""
	var col := Color(0.3, 0.9, 1.0)
	var act := ""
	if player.mode == PlayerShip.Mode.LANE and player.exit_ahead() and not player.autopilot:
		var j: Dictionary = player.junction
		var eo: Dictionary = j["options"][j["exit"]]
		if j["armed"]:
			label = "STAY ON"
			col = Color(1.0, 0.85, 0.5)
		else:
			label = "TAKE EXIT %d" % eo["track"].exit_no
			col = Color(0.45, 1.0, 0.6)
		act = "arm"
	elif player.mode == PlayerShip.Mode.LANE:
		var near: Dictionary = player.lane.nearest_entry(player.global_position)
		if not near.is_empty() and near["dist"] < 900.0:
			label = "EXIT: " + near["name"]
		else:
			label = "DROP OUT"
		act = "exit"
		col = Color(0.7, 0.55, 1.0)
	elif player.mode == PlayerShip.Mode.FLIGHT:
		var st := player.can_dock()
		var sg := player.can_jump()
		if st:
			label = "DOCK"
			act = "dock"
			col = Color(0.4, 1.0, 0.6)
		elif sg:
			label = "JUMP"
			act = "jump"
			col = Color(1.0, 0.85, 0.4)
		elif not player.can_enter_lane().is_empty():
			label = "ENTER " + SpaceLane.KINDS[player.can_enter_lane()["track"].kind]["label"]
			act = "lane"
	touch.action_label = label
	var off: Dictionary = road.offer() if flying else {}
	touch.action2_label = off.get("label", "")
	touch.action2_color = off.get("color", Color(0.55, 1.0, 0.75))
	if not GameInput.using_touch and touch.action2_label != "":
		touch.action2_label += "  [V]"
	touch.photo_ready = flying and not road.photo_target().is_empty()
	touch.radio_name = Sfx.RADIO[clampi(Settings.radio, 0, Sfx.RADIO.size() - 1)]["name"]
	touch.autopilot_on = player.autopilot
	touch.autopilot_ready = not GameState.destination.is_empty()
	var sec := GameState.installed("secondary")
	touch.missile_ammo = -1 if sec.is_empty() else GameState.ammo.get(Items.GEAR[sec[0]]["ammo"], 0)
	touch.action_color = col
	if not GameInput.using_touch and label != "":
		touch.action_label = label + "  [T]"
	if GameInput.consume_action():
		match act:
			"arm":
				player.toggle_exit()
				sfx.play("ui_tab", -3.0, 1.2 if player.junction.get("armed", false) else 0.9)
			"exit":
				player.exit_lane()
			"dock":
				player.start_docking(player.can_dock())
				sfx.ui("open")
			"lane":
				player.enter_lane()
				sfx.play("lane_merge", -4.0)
			"jump":
				_open_map(true)

	# mission waves and ambient raiders
	var m := GameState.active_hunt(GameState.system_id)
	if not m.is_empty() and not m.get("spawned", false):
		_spawn_mission_wave(m)
	_ambient_timer += delta
	if _ambient_timer > 60.0:
		_ambient_timer = 0.0
		var threat: int = Galaxy.SYSTEMS[GameState.system_id]["threat"]
		if get_tree().get_nodes_in_group("enemies").size() < 1 + threat and player.global_position.distance_to(beacon_pos) > 3000.0:
			_spawn_ambient_raiders()


# --- Autopilot ------------------------------------------------------------------------

func toggle_autopilot() -> void:
	if player.autopilot:
		player.set_autopilot(false, "Autopilot disengaged")
		return
	if player.mode != PlayerShip.Mode.FLIGHT and player.mode != PlayerShip.Mode.LANE:
		return
	var info := GameState.destination_info()
	if info.is_empty():
		GameState.message.emit("Pick a destination on the star map first", Color(1.0, 0.85, 0.4))
		sfx.ui("error")
		_open_map(false)
		return
	player.set_autopilot(true, "Autopilot engaged: " + info["label"])


func on_autopilot_changed(on: bool, why: String) -> void:
	sfx.play("autopilot_on" if on else "autopilot_off", -3.0)
	if why != "":
		GameState.message.emit(why, Color(0.55, 1.0, 0.75) if on else Color(0.75, 0.85, 1.0))


## Where the destination is in this system: {pos, station, gate, beacon, label} or {}.
func dest_target() -> Dictionary:
	var info := GameState.destination_info()
	if info.is_empty():
		return {}
	if info["system"] != GameState.system_id:
		var route := Galaxy.path(GameState.system_id, info["system"])
		if route.size() < 2 or not gates.has(route[1]):
			return {}
		var g: Stargate = gates[route[1]]
		return {"pos": g.global_position, "goal": g.approach_point(), "gate": g, "label": "%s (via %s)" % [info["label"], g.display_name.replace("Gate: ", "")], "final": info}
	if info["station"] != "" and stations.has(info["station"]):
		var st: Station = stations[info["station"]]
		return {"pos": st.global_position, "goal": _station_goal(st), "station": st, "label": info["label"], "final": info}
	if info.get("site", "") == "wonder":
		return {"pos": site_pos, "goal": site_pos, "site": true, "label": info["label"], "final": info}
	return {"pos": beacon_pos, "goal": beacon_pos, "beacon": true, "label": info["label"], "final": info}


func _station_goal(st: Station) -> Vector3:
	var bay := (st.approach_point() - st.global_position).normalized()
	var rel := player.global_position - st.global_position
	if rel.length() < 2200.0 and rel.normalized().dot(bay) < 0.35:
		# behind or beside the station: swing around it first
		var perp := rel - bay * rel.dot(bay)
		if perp.length() < 1.0:
			perp = st.global_transform.basis.x
		return st.global_position + perp.normalized() * 480.0 + bay * 160.0
	return st.approach_point()


func _physics_process(delta: float) -> void:
	if player.autopilot and not _jumping:
		_autopilot_plan()
	_update_gps(delta)


func _autopilot_plan() -> void:
	if player.mode != PlayerShip.Mode.FLIGHT and player.mode != PlayerShip.Mode.LANE:
		return
	var t := dest_target()
	if t.is_empty():
		player.set_autopilot(false, "Destination cleared: autopilot off")
		return
	var goal: Vector3 = t["goal"]
	var slow := true
	if player.mode == PlayerShip.Mode.FLIGHT:
		if t.has("station") and player.can_dock() == t["station"]:
			player.set_autopilot(false, "")
			player.start_docking(t["station"])
			sfx.ui("open")
			return
		if t.has("gate") and player.can_jump() == t["gate"]:
			var dest: String = t["final"]["system"]
			var h := Galaxy.hops(GameState.system_id, dest)
			if GameState.jump_charges >= h:
				_on_jump_requested(dest)
			elif GameState.jump_charges >= 1:
				_on_jump_requested((t["gate"] as Stargate).link)
			else:
				player.set_autopilot(false, "Autopilot stopped: no jump charges. Refuel at a station.")
			return
		if t.has("beacon") and player.global_position.distance_to(beacon_pos) < 900.0:
			player.set_autopilot(false, "Arrived at the beacon. Weapons free!")
			return
		if t.has("site") and player.global_position.distance_to(site_pos) < 700.0:
			player.set_autopilot(false, "Arrived at %s. Look around!" % t["label"])
			return
		# ride the network when it's faster: replan twice a second
		_ap_plan_t -= get_physics_process_delta_time()
		var pgoal: Vector3 = t["pos"]
		if _ap_plan.is_empty() or _ap_plan_t <= 0.0 or _ap_plan_goal.distance_to(pgoal) > 50.0:
			_ap_plan = net.plan(player.global_position, pgoal, player.top_speed())
			_ap_plan_t = 0.5
			_ap_plan_goal = pgoal
		var rides: Array = _ap_plan["rides"]
		if rides.size() == 1:
			# a last hop shorter than a couple of seconds at road speed isn't
			# worth merging for (and would bounce in and out at the exit)
			var rl: Dictionary = rides[0]
			var cl := (rl["track"] as SpaceLane).closest(player.global_position)
			if absf(float(rl["exit_s"]) - float(cl["s"])) < 2500.0:
				rides = []
		if not rides.is_empty():
			var r0: Dictionary = rides[0]
			var tr: SpaceLane = r0["track"]
			var c := tr.closest(player.global_position)
			if c["dist"] < tr.radius * 0.7:
				player.enter_lane(r0["dir"], true, tr)
				player.ap_route = rides
				_ap_plan_t = 1.0
				sfx.play("lane_merge", -4.0)
				return
			var s_aim := clampf(c["s"] + r0["dir"] * minf(c["dist"] * 0.6, 1500.0), 0.0, tr.length)
			goal = tr.curve.sample_baked(s_aim, true)
			slow = false
	else:
		_ap_plan_t -= get_physics_process_delta_time()
		if _ap_plan_t <= 0.0 or player.ap_route.is_empty() or player.ap_route[0]["track"] != player.lane:
			_ap_plan_t = 1.0
			var top := player.top_speed()
			var pg: Vector3 = t["pos"]
			var on := net.plan(player.global_position, pg, top, player.lane, player.lane_s, player.lane_dir)
			var off := net.plan(player.global_position, pg, top)
			if off["cost"] + 4.0 < on["cost"]:
				player.exit_lane()
				_ap_plan = off
				_ap_plan_t = 0.5
				return
			player.ap_route = on["rides"]
	player.ap_goal = goal
	player.ap_arrive_slow = slow


# --- GPS --------------------------------------------------------------------------
# The same planner the autopilot uses, run twice a second for the pilot: which
# road to join, which lane to hold at each junction, where to get off. It
# reroutes on its own when you take a different branch.

func _update_gps(delta: float) -> void:
	var flying := player.mode == PlayerShip.Mode.FLIGHT or player.mode == PlayerShip.Mode.LANE
	var t := dest_target() if flying and not _jumping else {}
	if t.is_empty():
		gps = {}
		player.gps_exit = -1
		return
	_gps_t -= delta
	var lane_mode := player.mode == PlayerShip.Mode.LANE
	if player.autopilot:
		gps = {"rides": player.ap_route if lane_mode else _ap_plan.get("rides", [])}
	elif _gps_t <= 0.0 or gps.is_empty() or (lane_mode and (gps["rides"].is_empty() or gps["rides"][0]["track"] != player.lane)) \
			or (not lane_mode and gps.get("lane", false)):
		_gps_t = 0.5
		var top := player.top_speed()
		var pg: Vector3 = t["pos"]
		if lane_mode:
			var on := net.plan(player.global_position, pg, top, player.lane, player.lane_s, player.lane_dir)
			var off := net.plan(player.global_position, pg, top)
			gps = {"rides": on["rides"], "lane": true, "leave": off["cost"] + 4.0 < on["cost"] or on["rides"].is_empty()}
		else:
			var rides: Array = net.plan(player.global_position, pg, top)["rides"]
			if rides.size() == 1:
				var cl := (rides[0]["track"] as SpaceLane).closest(player.global_position)
				if absf(float(rides[0]["exit_s"]) - float(cl["s"])) < 2500.0:
					rides = []
			gps = {"rides": rides}
	gps["target"] = t
	player.gps_exit = -1
	for r in gps.get("rides", []):
		if (r["track"] as SpaceLane).role == "exit":
			player.gps_exit = (r["track"] as SpaceLane).node_a
			break
	# chime a few seconds before a junction where the route turns
	if lane_mode:
		var g := gps_info()
		if g.get("junction", -1) >= 0 and g["bands"] > 1 and g["dist"] < maxf(2500.0, player.lane_speed * 4.0):
			if _gps_chimed != g["junction"]:
				_gps_chimed = g["junction"]
				sfx.play("ui_tab", -2.0, 1.35)
				if not player.autopilot:
					GameState.message.emit(g["text"], Color(0.78, 0.58, 1.0))
		elif g.get("junction", -1) < 0:
			_gps_chimed = -1


## What the GPS says right now:
## {icon (left/right/straight/stop/exit/join/fly), text, dist, then,
##  junction (node id or -1), band (lane to hold, -1), bands, join (Vector3)}
func gps_info() -> Dictionary:
	if gps.is_empty() or not gps.has("target"):
		return {}
	var t: Dictionary = gps["target"]
	var rides: Array = gps["rides"]
	var label: String = t["label"]
	var out := {"junction": -1, "band": -1, "bands": 0, "then": ""}
	if player.mode != PlayerShip.Mode.LANE:
		if rides.is_empty():
			out.merge({"icon": "fly", "text": "Fly direct to " + label, "dist": player.global_position.distance_to(t["pos"])}, true)
			return out
		var r0: Dictionary = rides[0]
		var tr: SpaceLane = r0["track"]
		var jp: Vector3 = tr.curve.sample_baked(float(r0["enter_s"]), true)
		var toward := net.node_name(net.end_node(tr, r0["dir"])) if rides.size() > 1 or absf(float(r0["exit_s"]) - (tr.length if r0["dir"] > 0 else 0.0)) < 5.0 else label
		out.merge({"icon": "join", "text": "Join the %s toward %s" % [tr.kind.to_upper(), toward], "dist": player.global_position.distance_to(jp), "join": jp,
			"then": _gps_step_text(rides, 1, label)}, true)
		return out
	var lane := player.lane
	var dir := player.lane_dir
	var endp: float = lane.length if dir > 0 else 0.0
	if gps.get("leave", false) or rides.is_empty() or rides[0]["track"] != lane:
		out.merge({"icon": "exit", "text": "Leave the %s now" % lane.kind, "dist": 0.0, "then": "fly to " + label}, true)
		return out
	var r0: Dictionary = rides[0]
	if lane.oneway:
		return _gps_loop(out, rides, label, t)
	if rides.size() == 1 and absf(float(r0["exit_s"]) - endp) > 5.0:
		out.merge({"icon": "exit", "text": "Leave the %s" % lane.kind, "dist": maxf(0.0, (float(r0["exit_s"]) - player.lane_s) * dir), "then": "fly to " + label}, true)
		return out
	var n := net.end_node(lane, dir)
	var opts := player.junction_options(lane, dir)
	out["junction"] = n
	out["bands"] = opts.size()
	out["dist"] = absf(endp - player.lane_s)
	var want := -1
	for i in opts.size():
		if rides.size() > 1 and opts[i]["track"] == rides[1]["track"] and opts[i]["dir"] == rides[1]["dir"]:
			want = i
		elif rides.size() == 1 and opts[i].get("stop", false):
			want = i
	out["band"] = want
	var at := net.node_name(n)
	if want < 0:
		out.merge({"icon": "stop", "text": "Get off at " + at, "then": "fly to " + label}, true)
		return out
	var o: Dictionary = opts[want]
	if o.get("stop", false):
		out.merge({"icon": "stop", "text": ("Keep RIGHT and stop at " if opts.size() > 1 else "Stop at ") + at, "then": "fly to " + label if t.get("station") == null else "dock at " + label}, true)
		return out
	var lanes_word := _lane_word(want, opts.size())
	var kind_word := "Highway" if o["kind"] == "highway" else "Road"
	# arrow and words always say the same thing: at a fork both name the lane
	# to hold (lanes are ordered left to right, so a branch that bends right
	# can still be the LEFT lane); with a single way on, both follow the bend
	var nb := opts.size()
	if nb > 1:
		out["icon"] = "left" if want == 0 else ("right" if want == nb - 1 else "straight")
	else:
		out["icon"] = "straight" if absf(o["turn"]) < 12.0 else ("right" if o["turn"] > 0.0 else "left")
		lanes_word = {"straight": "Carry on", "left": "Bear left", "right": "Bear right"}[out["icon"]]
	out["text"] = "%s: %s to %s" % [lanes_word, kind_word, o["name"]]
	out["then"] = _gps_step_text(rides, 2, label)
	return out


## GPS on the loop network: "stay on, your exit is Exit 3" / "take Exit 3" /
## "stop at Cinder Post". Only ever one simple instruction.
func _gps_loop(out: Dictionary, rides: Array, label: String, t: Dictionary) -> Dictionary:
	var lane := player.lane
	var r0: Dictionary = rides[0]
	var endp: float = lane.length
	if lane.role == "exit":
		if rides.size() == 1 and absf(float(r0["exit_s"]) - endp) > 5.0:
			out.merge({"icon": "exit", "text": "Leave the ramp", "dist": maxf(0.0, float(r0["exit_s"]) - player.lane_s), "then": "fly to " + label}, true)
		else:
			out.merge({"icon": "stop", "text": "Ramp ends at " + net.node_name(lane.node_b), "dist": endp - player.lane_s,
				"then": "dock at " + label if t.get("station") != null else "fly to " + label}, true)
		return out
	# distance along the route to the exit ramp we want
	var d := 0.0
	var ramp: SpaceLane = null
	for i in rides.size():
		var tr: SpaceLane = rides[i]["track"]
		if tr.role == "exit":
			ramp = tr
			break
		d += (tr.length - player.lane_s) if i == 0 else tr.length
	if ramp == null:
		if rides.size() >= 1 and absf(float(rides[-1]["exit_s"]) - (rides[-1]["track"] as SpaceLane).length) > 5.0:
			out.merge({"icon": "exit", "text": "Drop out of the highway", "dist": maxf(0.0, d - ((rides[-1]["track"] as SpaceLane).length - float(rides[-1]["exit_s"]))), "then": "fly to " + label}, true)
		else:
			out.merge({"icon": "exit", "text": "Leave the %s now" % lane.kind, "dist": 0.0, "then": "fly to " + label}, true)
		return out
	var nx := net.next_exit(lane, player.lane_s)
	var j: Dictionary = player.junction
	var dest := net.node_name(ramp.node_b)
	if not nx.is_empty() and nx["node"] == ramp.node_a:
		var armed: bool = j.get("armed", false) and j.get("node", -1) == ramp.node_a
		out.merge({"icon": "exit" if armed else "right", "text": "Take EXIT %d: %s" % [ramp.exit_no, dest], "dist": d,
			"then": ("armed, the ramp is yours" if armed else "tap TAKE EXIT") if not player.autopilot else "then dock"}, true)
		out["junction"] = ramp.node_a
	else:
		out.merge({"icon": "straight", "text": "Stay on the highway: EXIT %d for %s" % [ramp.exit_no, dest], "dist": d,
			"then": "next exit is %d" % nx["exit_no"] if not nx.is_empty() else ""}, true)
	return out


func _lane_word(i: int, nb: int) -> String:
	if nb <= 1:
		return ""
	if i == 0:
		return "Keep LEFT"
	if i == nb - 1:
		return "Keep RIGHT"
	if nb == 3:
		return "Keep MIDDLE"
	return "Lane %d of %d" % [i + 1, nb]


## Short text for the step after the next one.
func _gps_step_text(rides: Array, i: int, label: String) -> String:
	if i >= rides.size():
		return "then arrive at " + label
	var r: Dictionary = rides[i]
	var tr: SpaceLane = r["track"]
	var opts := player.junction_options(rides[i - 1]["track"], rides[i - 1]["dir"]) if i > 0 else []
	for k in opts.size():
		if opts[k]["track"] == tr and opts[k]["dir"] == r["dir"]:
			var w := _lane_word(k, opts.size())
			return "then %s at %s" % [w.to_lower() if w != "" else "carry on", net.node_name(net.end_node(rides[i - 1]["track"], rides[i - 1]["dir"]))]
	return "then the %s toward %s" % [tr.kind, net.node_name(net.end_node(tr, r["dir"]))]


# --- Stargate jumps -------------------------------------------------------------------

func _on_jump_requested(dest: String) -> void:
	var route := Galaxy.path(GameState.system_id, dest)
	var hops := route.size() - 1
	if hops <= 0 or hops > GameState.jump_charges:
		return
	_close_overlay()
	var gate := player.can_jump()
	if gate == null:
		return
	_jumping = true
	road.set_cruise(false)
	if player.mode == PlayerShip.Mode.LANE:
		player.exit_lane()
	player.mode = PlayerShip.Mode.JUMPING
	touch.reset()
	GameState.jump_charges -= hops
	sfx.play("jump", 0.0)
	GameState.message.emit("Jumping to %s..." % Galaxy.SYSTEMS[dest]["name"], Color(1.0, 0.85, 0.4))
	# fly into the membrane while it charges
	var start := player.global_transform
	var tw := create_tween().set_parallel(true)
	tw.tween_method(gate.set_charge, 0.0, 1.0, 2.6)
	tw.tween_property(camera, "warp", 1.0, 2.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_jump_from = start
	_jump_gate = gate
	tw.tween_method(_jump_fly, 0.0, 1.0, 2.6)
	tw.tween_property(fade, "color", Color(1, 1, 1, 1), 0.35).set_delay(2.35)
	await tw.finished
	camera.shake(1.2)
	var from: String = route[route.size() - 2]
	load_system(dest)
	var arrive: Stargate = gates.get(from, gates.values()[0])
	arrive.set_charge(1.0)
	player.global_transform = arrive.arrival_transform()
	player.velocity = -player.global_transform.basis.z * 200.0
	player.speed = 200.0
	camera.snap()
	player.mode = PlayerShip.Mode.FLIGHT
	GameState.save_game()
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(fade, "color", Color(1, 1, 1, 0), 1.2)
	tw2.tween_property(camera, "warp", 0.0, 1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw2.tween_method(arrive.set_charge, 1.0, 0.0, 2.0)
	_jumping = false
	GameState.message.emit("Arrived in %s" % Galaxy.SYSTEMS[dest]["name"], Color(1.0, 0.9, 0.6))
	await get_tree().create_timer(1.5).timeout
	GameState.message.emit(Galaxy.SYSTEMS[dest]["desc"], Color(0.75, 0.85, 1.0))
	fade.color = Color(0, 0, 0, fade.color.a)


var _jump_from := Transform3D()
var _jump_gate: Stargate


func _jump_fly(t: float) -> void:
	var target := _jump_gate.global_position
	var pos := _jump_from.origin.lerp(target, t * t)
	player.global_transform = Transform3D(Basis.looking_at((target - _jump_from.origin).normalized(), Vector3.UP), pos)
	player.speed = 80.0 + t * 900.0


# --- 0.12 radio, photos, road offers ------------------------------------------------

func _radio() -> void:
	GameState.message.emit(sfx.next_radio(), Color(0.85, 0.75, 1.0))


func _photo() -> void:
	if player.mode == PlayerShip.Mode.FLIGHT or player.mode == PlayerShip.Mode.LANE:
		road.take_photo()


func _action2() -> void:
	if player.mode == PlayerShip.Mode.FLIGHT or player.mode == PlayerShip.Mode.LANE:
		if not road.offer().is_empty():
			road.take_offer()


func _on_auto_fire(on: bool) -> void:
	sfx.play("autofire_on" if on else "autofire_off", -2.0)
	GameState.message.emit("Auto-attack " + ("ON" if on else "OFF"), Color(1.0, 0.85, 0.4))


# --- Flow ------------------------------------------------------------------------

func _on_docked(st: Station) -> void:
	player.autopilot = false
	road.set_cruise(false)
	var notes := GameState.turn_in(st.station_id)
	var trip_note := _trip_summary(st)
	if trip_note != "":
		notes.push_front(trip_note)
	GameState.remember_prices(GameState.system_id)
	sfx.play("dock_clamp", -2.0)
	if not notes.is_empty():
		sfx.play("mission_complete", -3.0)
	GameState.save_game()
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.5)
	tw.tween_callback(func(): _show_menu(st, notes))
	tw.tween_property(fade, "color:a", 0.0, 0.6)


## Trip log on arrival: how far, how long, what the hold is worth here.
func _trip_summary(st: Station) -> String:
	var tr: Dictionary = GameState.trip
	if tr.is_empty():
		return ""
	GameState.trip = {}
	var secs := Economy.clock - float(tr.get("t0", Economy.clock))
	var km := float(tr.get("dist", 0.0)) / 1000.0
	if km < 1.0:
		return ""
	GameState.lifetime["km"] = float(GameState.lifetime.get("km", 0.0)) + km
	var line := "%.1f km in %d:%02d" % [km, int(secs) / 60, int(secs) % 60]
	var paid := GameState.cargo_paid()
	if paid > 0:
		var worth := GameState.hold_value_at(st.station_id)
		var gain := worth - paid
		var per_min := gain / maxf(secs / 60.0, 0.5)
		line += "  ·  hold paid %s cr, worth %s cr here: %s%s cr if you sell (%s%s cr/min)" % [StationMenu._fmt(paid), StationMenu._fmt(worth),
			"+" if gain >= 0 else "-", StationMenu._fmt(absi(gain)), "+" if gain >= 0 else "-", StationMenu._fmt(absi(int(per_min)))]
	var earned := GameState.credits - int(tr.get("cr0", GameState.credits))
	if earned != 0:
		line += "  ·  credits since launch %s%s" % ["+" if earned > 0 else "-", StationMenu._fmt(absi(earned))]
	return "TRIP|" + line


func _show_menu(st: Station, notes: Array) -> void:
	touch.reset()
	menu.open(st, notes)


func _launch() -> void:
	var st: Station = player.dock_station
	if st == null:
		st = stations[GameState.last_station]
	GameState.save_game()
	sfx.play("launch", -2.0)
	var tw0 := create_tween()
	tw0.tween_property(menu, "modulate:a", 0.0, 0.25)
	await tw0.finished
	menu.visible = false
	menu.modulate.a = 1.0
	var tw := create_tween()
	fade.color = Color(0, 0, 0, 1)
	player.undock(st)
	GameState.start_trip()
	_spawn_mission_props()
	camera.snap()
	tw.tween_property(fade, "color:a", 0.0, 0.7)
	GameState.message.emit("Cleared for departure. Fly safe.", Color(0.6, 1.0, 0.75))


func _on_player_died() -> void:
	if _respawning:
		return
	_respawning = true
	road.set_cruise(false)
	combat.explosion(player.global_position, 1.6)
	GameState.message.emit("SHIP DESTROYED", Color(1, 0.3, 0.25))
	await get_tree().create_timer(2.5).timeout
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.8)
	await tw.finished
	GameState.on_player_destroyed()
	if GameState.system_id != Galaxy.system_of(GameState.last_station) or not stations.has(GameState.last_station):
		load_system(Galaxy.system_of(GameState.last_station))
	var st: Station = stations[GameState.last_station]
	player.dock_station = st
	player.global_transform = st.undock_transform()
	player.mode = PlayerShip.Mode.DOCKED
	player.autopilot = false
	player.shield = GameState.max_shield()
	GameState.save_game()
	_show_menu(st, ["Your ship was destroyed. Insurance covered a new hull. Cargo lost, 10% of credits deducted."])
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.8)
	_respawning = false
