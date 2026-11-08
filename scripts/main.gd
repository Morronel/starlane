extends Node3D
## Builds the Tessaly system and runs the game loop:
## dock -> trade / take a mission -> lane -> fight -> upgrade.

var env: SpaceEnv
var camera: ChaseCam
var player: PlayerShip
var lane: SpaceLane
var combat: Combat
var stations := {}
var beacon_pos := Vector3.ZERO
var rocks: Array = []   # {pos, r}

var hud: Hud
var touch: TouchControls
var menu: StationMenu
var fade: ColorRect
var sfx: Sfx

var _ambient_timer := 0.0
var _respawning := false


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

	_build_system()

	player = PlayerShip.new()
	player.world = self
	player.lane = lane
	add_child(player)
	player.died.connect(_on_player_died)
	player.docked.connect(_on_docked)
	player.lane_changed.connect(func(on): sfx.lane(on))
	camera.target = player

	_build_ui()
	_spawn_ambient_raiders()

	# start docked at Halcyon Yard
	var st: Station = stations["halcyon"]
	player.global_transform = st.undock_transform()
	player.dock_station = st
	player.mode = PlayerShip.Mode.DOCKED
	player.model.visible = false
	camera.global_position = st.global_position + Vector3(300, 120, -300)
	camera.look_at(st.global_position)
	_show_menu(st, ["Welcome to the Tessaly system, pilot.", "Take a contract, trade cargo, then LAUNCH."])

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


# --- World -----------------------------------------------------------------------

func _build_system() -> void:
	var a_pos := Vector3.ZERO
	var b_pos := Vector3(3200, 500, -9200)
	var ab := (b_pos - a_pos).normalized()

	var a := Station.new()
	a.station_id = "halcyon"
	a.display_name = "Halcyon Yard"
	a.accent = Color(0.25, 0.85, 1.0)
	a.variant = 0
	add_child(a)
	a.global_transform = Transform3D(Basis.looking_at(ab, Vector3.UP), a_pos)
	a.build()
	stations["halcyon"] = a

	var b := Station.new()
	b.station_id = "verdant"
	b.display_name = "Verdant Spire"
	b.accent = Color(1.0, 0.65, 0.25)
	b.variant = 1
	add_child(b)
	b.global_transform = Transform3D(Basis.looking_at(-ab, Vector3.UP).rotated(-ab, 0.6), b_pos)
	b.build()
	stations["verdant"] = b

	var gate_a := a_pos + ab * 650.0
	var gate_b := b_pos - ab * 650.0
	var side := ab.cross(Vector3.UP).normalized()
	beacon_pos = (gate_a + gate_b) * 0.5 + side * 1400.0 + Vector3(0, -250, 0)
	var c1 := gate_a.lerp(beacon_pos, 0.5) + side * 300.0 + Vector3(0, 200, 0)
	var c2 := beacon_pos.lerp(gate_b, 0.5) + side * 250.0 + Vector3(0, -150, 0)

	lane = SpaceLane.new()
	add_child(lane)
	lane.build([gate_a, gate_a + ab * 300.0, c1, beacon_pos, c2, gate_b - ab * 300.0, gate_b], [
		{"name": "Halcyon Gate", "pos": gate_a, "color": a.accent},
		{"name": "Kessler Beacon", "pos": beacon_pos, "color": Color(0.7, 0.5, 1.0)},
		{"name": "Verdant Gate", "pos": gate_b, "color": b.accent},
	])

	var bea := MeshInstance3D.new()
	bea.mesh = Models.beacon(Color(0.7, 0.5, 1.0))
	add_child(bea)
	bea.global_position = beacon_pos + side * 160.0

	_build_asteroids(beacon_pos + side * 700.0)


func _build_asteroids(center: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var variants: Array[ArrayMesh] = []
	for i in 4:
		var mb := MeshBuilder.new()
		mb.rock("hull", 1.0, Color(0.5, 0.44, 0.38).lerp(Color(0.62, 0.55, 0.46), rng.randf()), rng)
		variants.append(mb.build({"hull": MeshBuilder.rock_material()}))
	var per := []
	for i in 4:
		per.append([])
	for i in 260:
		var p := center + Vector3(rng.randfn() * 700.0, rng.randfn() * 220.0, rng.randfn() * 700.0)
		var close := lane.curve.get_closest_point(p)
		if close.distance_to(p) < 120.0:
			continue
		var r := pow(rng.randf(), 3.0) * 55.0 + 4.0
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
		add_child(mmi)


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
	add_child(r)
	r.setup(self, pos, elite)


func _spawn_ambient_raiders() -> void:
	var side: Vector3 = (stations["verdant"].global_position - stations["halcyon"].global_position).normalized().cross(Vector3.UP)
	for i in 2:
		_spawn_raider(beacon_pos + side * (500.0 + i * 120.0) + Vector3(0, 60 * i, 0))


func _spawn_mission_wave(m: Dictionary) -> void:
	var side: Vector3 = (stations["verdant"].global_position - stations["halcyon"].global_position).normalized().cross(Vector3.UP)
	var n: int = m["left"] - get_tree().get_nodes_in_group("enemies").size()
	for i in maxi(n, 0):
		var p := beacon_pos + side * randf_range(400, 900) + Vector3(randf_range(-300, 300), randf_range(-150, 150), randf_range(-300, 300))
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
	add_child(layer)
	hud = Hud.new()
	hud.world = self
	layer.add_child(hud)
	touch = TouchControls.new()
	layer.add_child(touch)
	menu = StationMenu.new()
	menu.visible = false
	layer.add_child(menu)
	menu.launch_pressed.connect(_launch)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)


func shake(a: float) -> void:
	camera.shake(a)


func flash_damage() -> void:
	hud.damage_flash = 1.0
	sfx.hit()


func sfx_laser(team: int, _pos: Vector3) -> void:
	sfx.laser(team, player.global_position.distance_to(_pos))


func sfx_boom(pos: Vector3) -> void:
	sfx.boom(player.global_position.distance_to(pos))


func _process(delta: float) -> void:
	env.set_dust_velocity(player.velocity)
	sfx.engine(player.speed / player.top_speed(), player.mode == PlayerShip.Mode.FLIGHT or player.mode == PlayerShip.Mode.LANE)
	touch.visible = (player.mode == PlayerShip.Mode.FLIGHT or player.mode == PlayerShip.Mode.LANE)
	lane.lane_mat.set_shader_parameter("intensity", 0.7 if player.mode == PlayerShip.Mode.LANE else 1.0)

	# context action: enter lane / exit lane / dock
	var label := ""
	var col := Color(0.3, 0.9, 1.0)
	var act := ""
	if player.mode == PlayerShip.Mode.LANE:
		var ne := lane.next_exit(player.lane_s, player.lane_dir)
		var near := lane.nearest_entry(player.global_position)
		if not near.is_empty() and near["dist"] < 450.0:
			label = "EXIT: " + near["name"]
		else:
			label = "DROP OUT"
		act = "exit"
		col = Color(0.7, 0.55, 1.0)
	elif player.mode == PlayerShip.Mode.FLIGHT:
		var st := player.can_dock()
		if st:
			label = "DOCK"
			act = "dock"
			col = Color(0.4, 1.0, 0.6)
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
				sfx.ui()
			"lane":
				player.enter_lane()

	# mission waves and ambient raiders
	var m := GameState.active_hunt()
	if not m.is_empty() and not m.get("spawned", false):
		_spawn_mission_wave(m)
	_ambient_timer += delta
	if _ambient_timer > 60.0:
		_ambient_timer = 0.0
		if get_tree().get_nodes_in_group("enemies").size() < 2 and player.global_position.distance_to(beacon_pos) > 3000.0:
			_spawn_ambient_raiders()


# --- Flow ------------------------------------------------------------------------

func _on_docked(st: Station) -> void:
	var notes := GameState.turn_in(st.station_id)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.5)
	tw.tween_callback(func(): _show_menu(st, notes))
	tw.tween_property(fade, "color:a", 0.0, 0.6)


func _show_menu(st: Station, notes: Array) -> void:
	touch.reset()
	menu.open(st, notes)
	sfx.ui()


func _launch() -> void:
	var st: Station = player.dock_station
	if st == null:
		st = stations[GameState.last_station]
	menu.visible = false
	var tw := create_tween()
	fade.color.a = 1.0
	player.undock(st)
	camera.snap()
	tw.tween_property(fade, "color:a", 0.0, 0.7)
	GameState.message.emit("Cleared for departure. Fly safe.", Color(0.6, 1.0, 0.75))
	sfx.ui()


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
	var st: Station = stations[GameState.last_station]
	player.dock_station = st
	player.global_transform = st.undock_transform()
	player.mode = PlayerShip.Mode.DOCKED
	player.shield = GameState.max_shield()
	_show_menu(st, ["Your ship was destroyed. Insurance covered a new hull.", "Cargo lost, 10% of credits deducted."])
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.8)
	_respawning = false
