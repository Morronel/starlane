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
	await get_tree().create_timer(sec).timeout


func _run() -> void:
	await _wait(1.5)
	await _shot("01_docked_menu")
	main._launch()
	GameInput.throttle = 0.5
	await _wait(2.5)
	await _shot("02_launch")
	# turn a bit to see the station
	GameInput.touch_stick = Vector2(0.6, 0.2)
	await _wait(1.6)
	GameInput.touch_stick = Vector2.ZERO
	await _wait(0.6)
	await _shot("03_flight")
	# into the lane at Halcyon Gate
	var p: PlayerShip = main.player
	var f: Dictionary = main.lane.frame(0.0)
	p.global_transform = Transform3D(Basis.looking_at(f["fwd"], Vector3.UP), f["origin"] - f["fwd"] * 100.0)
	await _wait(0.3)
	p.enter_lane()
	GameInput.throttle = 1.0
	await _wait(3.0)
	await _shot("04_lane")
	GameInput.touch_stick = Vector2(0.8, 0.0)
	await _wait(1.0)
	GameInput.touch_stick = Vector2.ZERO
	await _shot("05_lane_steer")
	p.exit_lane()
	# combat: place near raiders
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.size() > 0:
		var e: Node3D = enemies[0]
		p.global_transform = Transform3D(Basis.looking_at(e.global_position - (e.global_position + Vector3(0, 30, 400)), Vector3.UP), e.global_position + Vector3(0, 30, 400))
		main.camera.snap()
		GameInput.throttle = 0.3
		GameInput.touch_fire = true
		await _wait(1.2)
		await _shot("06_combat")
		await _wait(2.0)
		await _shot("07_combat2")
		GameInput.touch_fire = false
	# view of the planet / sun
	p.global_transform = Transform3D(Basis.looking_at(Vector3(0.55, -0.1, -0.8), Vector3.UP), Vector3(-500, 400, 900))
	main.camera.snap()
	await _wait(1.0)
	await _shot("08_vista")
	p.global_transform = Transform3D(Basis.looking_at(Vector3(-0.45, 0.2, -0.85), Vector3.UP), Vector3(-500, 400, 900))
	main.camera.snap()
	await _wait(1.0)
	await _shot("09_sun")
	# docking approach
	var st: Station = main.stations["verdant"]
	p.global_transform = Transform3D(Basis.looking_at(st.global_position - st.approach_point(), Vector3.UP), st.approach_point() + (st.approach_point() - st.global_position).normalized() * 150.0)
	main.camera.snap()
	await _wait(1.0)
	await _shot("10_verdant")
	GameInput.queue_action()
	await _wait(5.5)
	await _shot("11_docked_verdant")
	get_tree().quit()
