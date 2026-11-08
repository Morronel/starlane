extends Node3D
## Builds the current star system and runs the game loop:
## dock -> trade / take a contract -> lane -> fight -> upgrade -> jump to the next system.

var env: SpaceEnv
var camera: ChaseCam
var player: PlayerShip
var lane: SpaceLane
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
var fade: ColorRect
var sfx: Sfx

var _ambient_timer := 0.0
var _respawning := false
var _jumping := false
var _last_target: Node3D
var _alarm_t := 0.0


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

	_build_ui()
	GameInput.auto_fire_changed.connect(_on_auto_fire)
	GameInput.map_pressed.connect(_toggle_map)
	GameState.mission_completed.connect(func(): sfx.play("mission_complete", -2.0))

	restart_from_save(true)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest="):
			var t: Node = load("res://scripts/autotest.gd").new()
			t.set("main", self)
			t.set("out_dir", arg.substr(11))
			add_child(t)
		elif arg == "--simtest":
			var s: Node = load("res://scripts/simtest.gd").new()
			s.set("main", self)
			add_child(s)


## (Re)start docked at the saved station.
func restart_from_save(first := false) -> void:
	load_system(GameState.system_id)
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
	for b in combat.bolts:
		b["node"].visible = false
		combat.pool.append(b["node"])
	combat.bolts.clear()
	stations.clear()
	gates.clear()
	rocks.clear()
	world_root = Node3D.new()
	world_root.name = "System_" + id
	add_child(world_root)
	env.apply_system(sysd["sky"])
	_build_system(id, sysd)
	player.lane = lane
	_ambient_timer = 0.0
	_spawn_ambient_raiders()


func _build_system(id: String, sysd: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var yaw := rng.randf() * TAU
	var ab := Vector3(cos(yaw), rng.randf_range(-0.08, 0.08), sin(yaw)).normalized()
	var up := Vector3.UP
	var side := ab.cross(up).normalized()
	_side = side
	var D := rng.randf_range(11500.0, 13000.0)
	var at := func(x: float, y: float, z: float) -> Vector3:
		return ab * x + up * y + side * z

	var sdefs: Array = sysd["stations"]
	var a_pos: Vector3 = at.call(0.0, 0.0, 0.0)
	var b_pos: Vector3 = at.call(D, rng.randf_range(-400, 600), rng.randf_range(-600, 600))
	var a := _make_station(sdefs[0], a_pos, (b_pos - a_pos).normalized(), 0.0)
	var b := _make_station(sdefs[1], b_pos, (a_pos - b_pos).normalized(), 0.6)

	var gate_a := a_pos + (b_pos - a_pos).normalized() * 1600.0
	var gate_b := b_pos + (a_pos - b_pos).normalized() * 1600.0
	beacon_pos = at.call(D * 0.5, -300.0, 2300.0)
	var links: Array = sysd["links"]
	var sg_exit := [at.call(D * 0.27, 250.0, -1000.0), at.call(D * 0.73, -200.0, -1000.0)]

	lane = SpaceLane.new()
	world_root.add_child(lane)
	var exits := [{"name": a.display_name, "pos": gate_a, "color": a.accent}]
	var pts := [gate_a, gate_a + (b_pos - a_pos).normalized() * 400.0]
	for i in links.size():
		if i == 1:
			pts.append(beacon_pos)
			exits.append({"name": "Beacon", "pos": beacon_pos, "color": Color(0.7, 0.5, 1.0)})
		pts.append(sg_exit[i])
		exits.append({"name": "Gate to " + Galaxy.SYSTEMS[links[i]]["name"], "pos": sg_exit[i], "color": Color(1.0, 0.85, 0.4)})
	pts.append(gate_b + (a_pos - b_pos).normalized() * 400.0)
	pts.append(gate_b)
	exits.append({"name": b.display_name, "pos": gate_b, "color": b.accent})
	lane.build(pts, exits)

	for i in links.size():
		var sg := Stargate.new()
		sg.link = links[i]
		sg.display_name = "Gate: " + Galaxy.SYSTEMS[links[i]]["name"]
		sg.color = (Galaxy.SYSTEMS[links[i]]["sky"]["c"] as Color).lerp(Color(1, 0.9, 0.6), 0.4)
		world_root.add_child(sg)
		var gp: Vector3 = sg_exit[i] - side * 1400.0 + up * 150.0
		sg.global_transform = Transform3D(Basis.looking_at((sg_exit[i] - gp).normalized(), up), gp)
		sg.build()
		gates[links[i]] = sg

	var bea := MeshInstance3D.new()
	bea.mesh = Models.beacon(Color(0.7, 0.5, 1.0))
	world_root.add_child(bea)
	bea.global_position = beacon_pos + side * 200.0
	field_center = beacon_pos + side * 1200.0
	_build_asteroids(field_center, rng)


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
	for i in 280:
		var p := center + Vector3(rng.randfn() * 800.0, rng.randfn() * 240.0, rng.randfn() * 800.0)
		if lane.curve.get_closest_point(p).distance_to(p) < 200.0:
			continue
		var r := pow(rng.randf(), 3.0) * 60.0 + 4.0
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
	sfx.music("station" if player.mode == PlayerShip.Mode.DOCKED else "flight")
	touch.visible = flying and not star_map.visible and not settings_panel.visible
	hud.visible = not menu.visible and not star_map.visible and not settings_panel.visible
	lane.lane_mat.set_shader_parameter("intensity", 0.7 if player.mode == PlayerShip.Mode.LANE else 1.0)

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
		var near := lane.nearest_entry(player.global_position)
		if not near.is_empty() and near["dist"] < 600.0:
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
			label = "ENTER LANE"
			act = "lane"
	touch.action_label = label
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
	player.shield = GameState.max_shield()
	GameState.save_game()
	_show_menu(st, ["Your ship was destroyed. Insurance covered a new hull. Cargo lost, 10% of credits deducted."])
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.8)
	_respawning = false
