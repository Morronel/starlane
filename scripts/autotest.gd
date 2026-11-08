extends Node
## Dev-only scripted run that captures screenshots: godot -- --autotest=<dir>

var main: Node
var out_dir := ""


func _ready() -> void:
	_run()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _run() -> void:
	GameState.reset_game()
	main.restart_from_save(true)
	await _wait(1.5)
	await _shot("01_menu_contracts")
	main.menu._select("market")
	await _wait(0.8)
	await _shot("02_menu_market")
	main.menu._select("shipyard")
	await _wait(0.8)
	await _shot("03_menu_shipyard")
	main._launch()
	GameInput.throttle = 0.5
	await _wait(2.5)
	await _shot("04_launch")
	var p: PlayerShip = main.player
	var f: Dictionary = main.lane.frame(0.0)
	p.global_transform = Transform3D(Basis.looking_at(f["fwd"], Vector3.UP), f["origin"] - f["fwd"] * 300.0 + Vector3(0, 40, 0))
	main.camera.snap()
	await _wait(0.6)
	await _shot("05_lane_gate")
	p.enter_lane()
	GameInput.throttle = 1.0
	await _wait(3.0)
	await _shot("06_lane")
	p.exit_lane()
	# combat at the beacon
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.size() > 0:
		var e: Node3D = enemies[0]
		var pos := e.global_position + Vector3(0, 30, 400)
		p.global_transform = Transform3D(Basis.looking_at(e.global_position - pos, Vector3.UP), pos)
		main.camera.snap()
		GameInput.set_auto_fire(true)
		await _wait(1.5)
		await _shot("07_combat_auto")
		GameInput.set_auto_fire(false)
	# stargate
	var gate: Stargate = main.gates.values()[0]
	var ap := gate.approach_point() + (gate.approach_point() - gate.global_position).normalized() * 500.0
	p.global_transform = Transform3D(Basis.looking_at(gate.global_position - ap, Vector3.UP), ap)
	main.camera.snap()
	await _wait(1.0)
	await _shot("08_stargate")
	# maps
	main._open_map(false)
	main.star_map._set_tab("system")
	await _wait(0.6)
	await _shot("09_map_system")
	main.star_map._set_tab("galaxy")
	main.star_map.selected = "elysia"
	main.star_map._refresh()
	await _wait(0.4)
	await _shot("10_map_galaxy")
	main._close_overlay()
	main._open_settings()
	await _wait(0.5)
	await _shot("11_settings")
	main._close_overlay()
	# jump
	p.global_transform = Transform3D(Basis.looking_at(gate.global_position - gate.approach_point(), Vector3.UP), gate.approach_point())
	main.camera.snap()
	await _wait(0.3)
	main._on_jump_requested(gate.link)
	await _wait(1.8)
	await _shot("12_jump_charge")
	await _wait(3.0)
	await _shot("13_arrival")
	# first-person
	Settings.first_person = true
	var st: Station = main.stations.values()[1]
	var sp: Vector3 = st.approach_point() + (st.approach_point() - st.global_position).normalized() * 900.0
	p.global_transform = Transform3D(Basis.looking_at(st.global_position - sp, Vector3.UP), sp)
	main.camera.snap()
	await _wait(1.0)
	await _shot("14_first_person")
	Settings.first_person = false
	await _wait(0.2)
	p.global_transform = Transform3D(Basis.looking_at(st.global_position - sp, Vector3.UP), sp)
	main.camera.snap()
	await _wait(1.0)
	await _shot("15_new_system_station")
	get_tree().quit()
