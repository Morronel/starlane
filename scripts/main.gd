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

var hud: Hud
var touch: TouchControls
var menu: StationMenu
var star_map: StarMap
var settings_panel: SettingsPanel
var title: TitleMenu
var fade: ColorRect
var sfx: Sfx

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

	_build_ui()
	GameInput.auto_fire_changed.connect(_on_auto_fire)
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
	player.net = net
	player.lane = null
	_ambient_timer = 0.0
	_spawn_ambient_raiders()


func _build_system(id: String, sysd: Dictionary) -> void:
	## A graph-shaped system ~70 km across. Four interchanges on a ring plus a
	## core interchange are joined by grand highways. Stations, stargates, the
	## beacon and a few crossroads hang off them on plenty of small roads.
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

	# interchanges
	var hubs := []
	var hub_ang := []
	for i in 4:
		var a := rot + i * TAU / 4.0 + rng.randf_range(-0.22, 0.22)
		hub_ang.append(a)
		hubs.append(net.add_node(["Alpha", "Beta", "Gamma", "Delta"][i] + " Interchange", at.call(a, R * rng.randf_range(0.88, 1.06), rng.randf_range(-1600.0, 1600.0)), "hub", gold))
	var core := net.add_node("Core Interchange", at.call(rng.randf() * TAU, R * rng.randf_range(0.05, 0.18), rng.randf_range(-700.0, 700.0)), "hub", gold)
	var all_hubs := hubs + [core]

	# points of interest: stations in three sectors, the beacon in the fourth,
	# stargates out beyond the ring
	var sdefs: Array = sysd["stations"]
	var links: Array = sysd["links"]
	var pois := []   # {node, pos (of the thing), away}
	var placed: Array = []
	for nd in net.nodes:
		placed.append(nd["pos"])
	var free_spot := func(ang: float, r0: float, r1: float, y: float) -> Vector3:
		var best := Vector3.ZERO
		var best_d := -1.0
		for k in 12:
			var cand: Vector3 = at.call(ang + rng.randf_range(-0.3, 0.3), rng.randf_range(r0, r1), y)
			var md := INF
			for q in placed:
				md = minf(md, (q as Vector3).distance_to(cand))
			if md > best_d:
				best_d = md
				best = cand
			if md > 12000.0:
				break
		placed.append(best)
		return best
	var station_nodes := []
	for i in sdefs.size():
		var a: float = rot + (i + 0.5) * TAU / 4.0
		var tp: Vector3 = free_spot.call(a, R * 0.42, R * 0.7, rng.randf_range(-900.0, 900.0))
		var outward := Vector3(tp.x, 0, tp.z).normalized()
		var away := outward.rotated(up, PI * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0)).lerp(outward, 0.3).normalized()
		var spos := tp + away * 2000.0 + up * rng.randf_range(-200.0, 200.0)
		var st := _make_station(sdefs[i], spos, (tp - spos).normalized(), i * 0.6)
		var n := net.add_node(st.display_name, tp, "poi", st.accent)
		station_nodes.append(n)
		pois.append(n)
	# beacon + asteroid field
	var ba: float = rot + 3.5 * TAU / 4.0
	var bt: Vector3 = free_spot.call(ba, R * 0.45, R * 0.7, rng.randf_range(-600.0, 600.0))
	var bout := Vector3(bt.x, 0, bt.z).normalized()
	beacon_pos = bt + bout * 3000.0 - up * 300.0
	_side = bout.cross(up).normalized()
	var beacon_node := net.add_node("Beacon", bt, "poi", Color(0.7, 0.5, 1.0))
	pois.append(beacon_node)
	# stargates
	for i in links.size():
		var ga: float = hub_ang[i] + 0.4 + rng.randf_range(-0.1, 0.1)
		var gt: Vector3 = free_spot.call(ga, R * 1.22, R * 1.32, rng.randf_range(-1200.0, 1200.0))
		var gout := Vector3(gt.x, 0, gt.z).normalized()
		var gp: Vector3 = gt + gout * 2600.0 + up * 150.0
		var sg := Stargate.new()
		sg.link = links[i]
		sg.display_name = "Gate: " + Galaxy.SYSTEMS[links[i]]["name"]
		sg.color = (Galaxy.SYSTEMS[links[i]]["sky"]["c"] as Color).lerp(Color(1, 0.9, 0.6), 0.4)
		world_root.add_child(sg)
		sg.global_transform = Transform3D(Basis.looking_at((gt - gp).normalized(), up), gp)
		sg.build()
		gates[links[i]] = sg
		pois.append(net.add_node("Gate to " + Galaxy.SYSTEMS[links[i]]["name"], gt, "poi", gold))
	# crossroads
	var crosses := []
	for i in 4:
		var cp: Vector3 = free_spot.call(rng.randf() * TAU, R * 0.3, R * 0.95, rng.randf_range(-1200.0, 1200.0))
		crosses.append(net.add_node("Crossroads %s" % ["K", "M", "R", "V"][i], cp, "cross", Color(0.5, 0.85, 1.0)))

	# grand highways: the ring, plus three spokes through the core
	for i in 4:
		var a: int = hubs[i]
		var b: int = hubs[(i + 1) % 4]
		var mid: Vector3 = ((net.nodes[a]["pos"] as Vector3) + (net.nodes[b]["pos"] as Vector3)) * 0.5
		var flat := Vector3(mid.x, 0, mid.z)
		net.add_track(a, b, "highway", rng, flat.normalized() * maxf(0.0, R - flat.length()) * 0.85)
	var skip := rng.randi() % 4
	for i in 4:
		if i != skip:
			net.add_track(hubs[i], core, "highway", rng)

	# small roads: everything to its nearest interchange and to its neighbours
	var nearest := func(n: int, pool: Array, k: int) -> Array:
		var p0: Vector3 = net.nodes[n]["pos"]
		var cand := pool.filter(func(m): return m != n)
		cand.sort_custom(func(x, y): return p0.distance_to(net.nodes[x]["pos"]) < p0.distance_to(net.nodes[y]["pos"]))
		return cand.slice(0, k)
	var road := func(a: int, b: int) -> void:
		if a == b or net.has_edge(a, b):
			return
		if (net.nodes[a]["pos"] as Vector3).distance_to(net.nodes[b]["pos"]) > 42000.0:
			return
		net.add_track(a, b, "road", rng)
	for n in pois:
		for h in nearest.call(n, all_hubs, 1):
			road.call(n, h)
	for n in station_nodes + [beacon_node]:
		for m in nearest.call(n, station_nodes + [beacon_node] + crosses, 1):
			road.call(n, m)
	for c in crosses:
		for m in nearest.call(c, pois + crosses + all_hubs, 3):
			road.call(c, m)
	net.build_nodes(sky)

	var bea := MeshInstance3D.new()
	bea.mesh = Models.beacon(Color(0.7, 0.5, 1.0))
	world_root.add_child(bea)
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


func _spawn_mission_wave(m: Dictionary) -> void:
	var n: int = m["left"] - get_tree().get_nodes_in_group("enemies").size()
	for i in maxi(n, 0):
		var p := beacon_pos + _side * randf_range(500, 1000) + Vector3(randf_range(-300, 300), randf_range(-150, 150), randf_range(-300, 300))
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
		sfx.music("station")
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
	if player.mode == PlayerShip.Mode.LANE:
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
	touch.autopilot_on = player.autopilot
	touch.autopilot_ready = not GameState.destination.is_empty()
	var sec := GameState.installed("secondary")
	touch.missile_ammo = -1 if sec.is_empty() else GameState.ammo.get(Items.GEAR[sec[0]]["ammo"], 0)
	touch.action_color = col
	if not GameInput.using_touch and label != "":
		touch.action_label = label + "  [T]"
	if GameInput.consume_action():
		match act:
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


func _on_auto_fire(on: bool) -> void:
	sfx.play("autofire_on" if on else "autofire_off", -2.0)
	GameState.message.emit("Auto-attack " + ("ON" if on else "OFF"), Color(1.0, 0.85, 0.4))


# --- Flow ------------------------------------------------------------------------

func _on_docked(st: Station) -> void:
	player.autopilot = false
	var notes := GameState.turn_in(st.station_id)
	sfx.play("dock_clamp", -2.0)
	if not notes.is_empty():
		sfx.play("mission_complete", -3.0)
	GameState.save_game()
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.5)
	tw.tween_callback(func(): _show_menu(st, notes))
	tw.tween_property(fade, "color:a", 0.0, 0.6)


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
	camera.snap()
	tw.tween_property(fade, "color:a", 0.0, 0.7)
	GameState.message.emit("Cleared for departure. Fly safe.", Color(0.6, 1.0, 0.75))


func _on_player_died() -> void:
	if _respawning:
		return
	_respawning = true
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
