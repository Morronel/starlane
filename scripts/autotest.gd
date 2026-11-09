extends Node
## Dev-only scripted run that captures screenshots: godot -- --autotest=<dir>

var main: Node
var out_dir := ""
var cockpits_only := false


func _ready() -> void:
	_run()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


## One first-person shot per hull, near a station, with the yoke deflected.
func _cockpits() -> void:
	var p: PlayerShip = main.player
	Settings.first_person = true
	var i := 0
	for id in OS.get_environment("COCKPITS").split(",") if OS.get_environment("COCKPITS") != "" else ["sparrow", "wren", "kestrel", "mule", "corsair", "seraph"]:
		GameState.ship = id
		GameState._normalize_equip()
		GameState.hull = GameState.max_hull()
		p.refresh_ship()
		if p.mode != PlayerShip.Mode.FLIGHT:
			main._launch()
			await _wait(0.5)
		var st: Station = main.stations.values()[i % main.stations.size()]
		var sp: Vector3 = st.approach_point() + (st.approach_point() - st.global_position).normalized() * 1100.0 + Vector3(0, 120, 0)
		p.global_transform = Transform3D(Basis.looking_at(st.global_position - sp, Vector3.UP), sp)
		p.velocity = Vector3.ZERO
		GameInput.throttle = 0.15
		main.camera.snap()
		GameInput.touch_roll = 0.0 if i % 2 == 0 else 0.7
		GameInput.touch_stick = Vector2(0.0, 0.0) if i % 2 == 0 else Vector2(-0.3, 0.2)
		await _wait(0.7)
		await _shot("cockpit_%d_%s" % [i + 1, id])
		GameInput.touch_roll = 0.0
		GameInput.touch_stick = Vector2.ZERO
		i += 1
	Settings.first_person = false


func _run() -> void:
	if cockpits_only:
		GameState.reset_game()
		main.restart_from_save(true)
		await _wait(1.0)
		await _cockpits()
		get_tree().quit()
		return
	main.show_title()
	await _wait(1.2)
	await _shot("00_main_menu")
	main._enter_game(false)
	GameState.reset_game()
	GameState.credits = 60000
	GameState.parts = {"scrap": 9, "circuit": 3, "coil": 1, "crystal": 2}
	main.restart_from_save(true)
	await _wait(1.5)
	for m in GameState.missions:
		if m["kind"] == "hunt" and m["system"] == "tessaly":
			GameState.accept(m)
	main.menu._select("missions")
	await _wait(0.8)
	await _shot("01_contracts")
	main.menu._select("market")
	await _wait(0.8)
	main.menu._scroll.scroll_vertical = 420
	await _wait(0.3)
	await _shot("02_market_parts")
	main.menu._select("hangar")
	main.menu._inspect = "mule"
	main.menu._rebuild()
	await _wait(1.0)
	await _shot("03_hangar")
	main.menu._select("outfit")
	await _wait(0.8)
	await _shot("04_outfit")
	main.menu._select("workshop")
	await _wait(0.8)
	await _shot("05_workshop")
	main.menu._select("bar")
	await _wait(0.8)
	await _shot("05b_bar")

	# buy a gunship for the flight shots
	GameState.ship = "corsair"
	GameState._normalize_equip()
	GameState.equip["primary"] = ["plasma", "plasma", "pulse_2", "pulse_2"]
	GameState.equip["utility"] = ["shield_2", "armor_2", "tractor"]
	GameState.hull = GameState.max_hull()
	main.player.refresh_ship()
	main._launch()
	# head for the farthest station so the GPS has a route to call out
	var far_id := ""
	var far_d := 0.0
	for sid in main.stations:
		var dd: float = (main.stations[sid] as Node3D).global_position.distance_to(main.player.global_position)
		if dd > far_d:
			far_d = dd
			far_id = sid
	GameState.set_destination("station", far_id)
	GameInput.throttle = 0.5
	await _wait(2.5)
	await _shot("06_launch_destination")
	var p: PlayerShip = main.player
	# approaching a highway from the side: merge anywhere
	var hwy: SpaceLane = null
	var road: SpaceLane = null
	for t in main.net.tracks:
		if t.kind == "highway" and hwy == null:
			hwy = t
		if t.kind == "road" and road == null and t.length > 9000.0:
			road = t
	var f: Dictionary = hwy.frame(hwy.length * 0.35)
	var start: Vector3 = f["origin"] + f["right"] * 1400.0 + f["up"] * 250.0
	p.global_transform = Transform3D(Basis.looking_at((f["origin"] + f["fwd"] * 2500.0 - start).normalized(), Vector3.UP), start)
	main.camera.snap()
	await _wait(0.8)
	await _shot("07_highway_approach")
	# a wide view over the network from above an interchange
	var hub: Dictionary = main.net.nodes[0]
	var vp: Vector3 = hub["pos"] + Vector3(6000, 9000, 6000)
	p.global_transform = Transform3D(Basis.looking_at((hub["pos"] - vp).normalized(), Vector3.UP), vp)
	main.camera.snap()
	await _wait(0.8)
	await _shot("08_network_overview")
	p.global_transform = Transform3D(Basis.looking_at(f["fwd"], Vector3.UP), f["origin"])
	p.enter_lane(1, true, hwy)
	p.lane_speed = 3500.0
	GameInput.throttle = 1.0
	await _wait(2.5)
	await _shot("09_highway_ride")
	# close to a fork on the GPS route: lane sign, the GPS lane framed
	p.exit_lane()
	var fork := {}
	var dst: Node3D = main.stations[far_id]
	var gr: Array = main.net.plan(main.gates.values()[0].global_position, dst.global_position, p.top_speed())["rides"]
	for i in range(gr.size() - 1):
		var r: Dictionary = gr[i]
		if p.junction_options(r["track"], r["dir"]).size() >= 2:
			fork = r
			break
	if fork.is_empty():
		fork = {"track": hwy, "dir": 1}
	var ft: SpaceLane = fork["track"]
	var fd: int = fork["dir"]
	var fs: float = ft.length - 5200.0 if fd > 0 else 5200.0
	f = ft.frame(fs)
	p.global_transform = Transform3D(Basis.looking_at(f["fwd"] * fd, Vector3.UP), f["origin"])
	p.enter_lane(fd, true, ft)
	p.lane_s = fs
	p.lane_speed = 700.0
	GameInput.throttle = 0.0
	await _wait(1.0)
	await _shot("10_junction_gps")
	Settings.first_person = true
	main.camera.snap()
	p.lane_s = fs
	await _wait(1.0)
	await _shot("10b_junction_gps_cockpit")
	Settings.first_person = false
	main.camera.snap()
	p.exit_lane()
	# a road, leaning into a turn
	var sharp := 0.0
	var sharp_s := road.length * 0.5
	for i in int(road.length / 50.0):
		if road.curvature(i * 50.0).z > sharp:
			sharp = road.curvature(i * 50.0).z
			sharp_s = i * 50.0
	f = road.frame(maxf(sharp_s - 700.0, 0.0))
	p.global_transform = Transform3D(Basis.looking_at(f["fwd"], Vector3.UP), f["origin"])
	p.enter_lane(1, true, road)
	p.lane_speed = 900.0
	await _wait(1.0)
	await _shot("11_road_turn")
	main.toggle_autopilot()
	await _wait(1.5)
	await _shot("12_road_autopilot")
	p.set_autopilot(false)
	p.exit_lane()
	# a road seen from outside, with a highway behind it
	var rf: Dictionary = road.frame(road.length * 0.5)
	var rv: Vector3 = rf["origin"] + rf["right"] * 900.0 + rf["up"] * 300.0 - rf["fwd"] * 600.0
	p.global_transform = Transform3D(Basis.looking_at((rf["origin"] + rf["fwd"] * 1500.0 - rv).normalized(), Vector3.UP), rv)
	main.camera.snap()
	await _wait(0.8)
	await _shot("13_road_outside")
	# combat at the beacon with a missile in flight
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.size() > 0:
		var e: Node3D = enemies[0]
		var pos := e.global_position + Vector3(0, 30, 500)
		p.global_transform = Transform3D(Basis.looking_at(e.global_position - pos, Vector3.UP), pos)
		main.camera.snap()
		GameInput.set_auto_fire(true)
		await _wait(0.6)
		p.target = e
		p.fire_missile()
		await _wait(0.7)
		await _shot("14_combat_missile")
		GameInput.set_auto_fire(false)
	# salvage field
	var loots := get_tree().get_nodes_in_group("loot")
	if loots.size() > 0:
		var lp: Vector3 = loots[0].global_position + Vector3(140, 50, 180)
		p.global_transform = Transform3D(Basis.looking_at(loots[0].global_position - lp, Vector3.UP), lp)
		main.camera.snap()
		await _wait(0.8)
		await _shot("15_salvage_field")
	# maps
	main._open_map(false)
	main.star_map._set_tab("system")
	await _wait(0.6)
	await _shot("16_map_system")
	main.star_map._set_tab("galaxy")
	main.star_map.selected = "vesper"
	main.star_map._refresh()
	await _wait(0.4)
	await _shot("17_map_galaxy")
	main._close_overlay()
	# stargate
	var gate: Stargate = main.gates.values()[0]
	var ap := gate.approach_point() + (gate.approach_point() - gate.global_position).normalized() * 700.0
	p.global_transform = Transform3D(Basis.looking_at(gate.global_position - ap, Vector3.UP), ap)
	main.camera.snap()
	await _wait(1.0)
	await _shot("18_stargate")
	# first person near a station
	Settings.first_person = true
	var st: Station = main.stations.values()[2]
	var sp: Vector3 = st.approach_point() + (st.approach_point() - st.global_position).normalized() * 900.0
	p.global_transform = Transform3D(Basis.looking_at(st.global_position - sp, Vector3.UP), sp)
	main.camera.snap()
	await _wait(1.0)
	await _shot("19_first_person")
	# fresh pilot in the starter Sparrow, 1st person, flying out from the station
	GameState.reset_game()
	main.restart_from_save(true)
	await _wait(0.6)
	main._launch()
	GameInput.throttle = 0.6
	await _wait(2.5)
	await _shot("20_fp_sparrow_fresh")
	# highway from inside, 1st person
	var h2: SpaceLane = null
	for t in main.net.tracks:
		if t.kind == "highway" and h2 == null:
			h2 = t
	var hf: Dictionary = h2.frame(h2.length * 0.3)
	p.global_transform = Transform3D(Basis.looking_at(hf["fwd"], Vector3.UP), hf["origin"])
	p.enter_lane(1, true, h2)
	p.lane_speed = 3200.0
	GameInput.throttle = 1.0
	await _wait(2.5)
	await _shot("21_fp_highway")
	Settings.first_person = false
	await _wait(1.0)
	await _shot("22_highway_3rd")
	p.exit_lane()
	# settings, saves and dev menu
	Settings.dev_mode = true
	GameState.save_slot(1)
	main._open_settings()
	await _wait(0.5)
	await _shot("23_settings")
	main.settings_panel.saves.open()
	await _wait(0.5)
	await _shot("24_saves")
	main.settings_panel.saves.visible = false
	main.settings_panel.dev.open()
	await _wait(0.5)
	await _shot("25_dev_menu")
	main.settings_panel.dev.visible = false
	main._close_overlay()
	Settings.dev_mode = false
	GameState.delete_slot(1)
	get_tree().quit()
