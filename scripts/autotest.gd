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

	# buy a gunship for the flight shots
	GameState.ship = "corsair"
	GameState._normalize_equip()
	GameState.equip["primary"] = ["plasma", "plasma", "pulse_2", "pulse_2"]
	GameState.equip["utility"] = ["shield_2", "armor_2", "tractor"]
	GameState.hull = GameState.max_hull()
	main.player.refresh_ship()
	main._launch()
	GameInput.throttle = 0.5
	await _wait(2.5)
	await _shot("06_launch_destination")
	var p: PlayerShip = main.player
	# approaching the lane from the side: merge anywhere
	var f: Dictionary = main.lane.frame(main.lane.length * 0.25)
	var start: Vector3 = f["origin"] + f["right"] * 520.0 + f["up"] * 60.0
	p.global_transform = Transform3D(Basis.looking_at((f["origin"] + f["fwd"] * 900.0 - start).normalized(), Vector3.UP), start)
	main.camera.snap()
	await _wait(0.8)
	await _shot("07_lane_approach")
	p.enter_lane(1, true)
	GameInput.throttle = 1.0
	await _wait(3.0)
	await _shot("08_wide_lane")
	main.toggle_autopilot()
	await _wait(2.0)
	await _shot("09_lane_autopilot")
	p.set_autopilot(false)
	p.exit_lane()
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
		await _shot("10_combat_missile")
		GameInput.set_auto_fire(false)
	# salvage field
	var loots := get_tree().get_nodes_in_group("loot")
	if loots.size() > 0:
		var lp: Vector3 = loots[0].global_position + Vector3(140, 50, 180)
		p.global_transform = Transform3D(Basis.looking_at(loots[0].global_position - lp, Vector3.UP), lp)
		main.camera.snap()
		await _wait(0.8)
		await _shot("11_salvage_field")
	# maps
	main._open_map(false)
	main.star_map._set_tab("system")
	await _wait(0.6)
	await _shot("12_map_system")
	main.star_map._set_tab("galaxy")
	main.star_map.selected = "vesper"
	main.star_map._refresh()
	await _wait(0.4)
	await _shot("13_map_galaxy")
	main._close_overlay()
	# stargate
	var gate: Stargate = main.gates.values()[0]
	var ap := gate.approach_point() + (gate.approach_point() - gate.global_position).normalized() * 700.0
	p.global_transform = Transform3D(Basis.looking_at(gate.global_position - ap, Vector3.UP), ap)
	main.camera.snap()
	await _wait(1.0)
	await _shot("14_stargate")
	# first person near a station
	Settings.first_person = true
	var st: Station = main.stations.values()[2]
	var sp: Vector3 = st.approach_point() + (st.approach_point() - st.global_position).normalized() * 900.0
	p.global_transform = Transform3D(Basis.looking_at(st.global_position - sp, Vector3.UP), sp)
	main.camera.snap()
	await _wait(1.0)
	await _shot("15_first_person")
	Settings.first_person = false
	get_tree().quit()
