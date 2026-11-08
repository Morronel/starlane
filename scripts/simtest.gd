extends Node
## Dev-only headless gameplay check: godot --headless -- --simtest
## Fresh save -> hunt in Tessaly via lane + auto-attack -> payout -> trade ->
## stargate jump -> dock in the new system -> death/respawn.

var main: Node


func _ready() -> void:
	_run()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _fail(msg: String) -> void:
	print("SIMTEST FAIL: ", msg)
	get_tree().quit(1)


func _run() -> void:
	GameState.reset_game()
	main.restart_from_save()
	await _wait(0.5)
	var hunt: Dictionary = GameState.active_hunt()
	for m in GameState.missions:
		if m["kind"] == "hunt" and m["system"] == "tessaly":
			hunt = m
	if hunt.is_empty():
		return _fail("no local hunt offered")
	GameState.accept(hunt)
	var start_credits := GameState.credits
	main._launch()
	await _wait(1.0)
	var p: PlayerShip = main.player
	# ride the lane from the first gate and drop out at the beacon
	var f: Dictionary = main.lane.frame(0.0)
	p.global_transform = Transform3D(Basis.looking_at(f["fwd"], Vector3.UP), f["origin"] - f["fwd"] * 60.0)
	await _wait(0.2)
	if p.can_enter_lane().is_empty():
		return _fail("cannot enter lane at gate")
	p.enter_lane()
	GameInput.throttle = 1.0
	var t := 0.0
	while p.mode == PlayerShip.Mode.LANE:
		var ne: Dictionary = main.lane.next_exit(p.lane_s, p.lane_dir)
		if not ne.is_empty() and ne["name"] == "Beacon" and ne["dist"] < 400.0:
			p.exit_lane()
		await _wait(0.1)
		t += 0.1
		if t > 40.0:
			return _fail("lane ride never reached the beacon")
	print("dropped out ", int(p.global_position.distance_to(main.beacon_pos)), " m from beacon after ", t, " s, lane length ", int(main.lane.length))
	await _wait(0.5)
	print("enemies: ", get_tree().get_nodes_in_group("enemies").size(), " hunt needs ", hunt["left"])
	# auto-attack does the shooting; we just point the ship at each raider
	GameState.upgrades["laser"] = 4
	GameState.hull = 100000.0
	GameInput.set_auto_fire(true)
	var guard := 0.0
	while not get_tree().get_nodes_in_group("enemies").is_empty() and guard < 150.0:
		var e: Node3D = get_tree().get_nodes_in_group("enemies")[0]
		var pos := e.global_position + (p.global_position - e.global_position).normalized() * 250.0
		var aim: Vector3 = main.lead_point(pos, e, Combat.PLAYER_BOLT_SPEED)
		p.global_transform = Transform3D(Basis.looking_at(aim - pos, Vector3.UP), pos)
		p.velocity = Vector3.ZERO
		GameInput.throttle = 0.0
		await _wait(0.1)
		guard += 0.1
	GameInput.set_auto_fire(false)
	GameState.hull = 100.0
	print("kills: ", GameState.kills, " hunt: ", hunt["state"], " in ", guard, " s")
	if hunt["state"] != "done":
		return _fail("hunt not completed")
	# dock at the second station
	var st: Station = main.stations["verdant"]
	p.global_transform = Transform3D(Basis.looking_at(st.global_position - st.approach_point(), Vector3.UP), st.approach_point())
	await _wait(0.2)
	if p.can_dock() == null:
		return _fail("cannot dock")
	GameInput.queue_action()
	await _wait(5.5)
	if p.mode != PlayerShip.Mode.DOCKED:
		return _fail("did not dock")
	print("credits ", start_credits, " -> ", GameState.credits)
	if hunt["state"] == "done" or GameState.missions.has(hunt):
		return _fail("not paid")
	# market + shipyard + services through the menu code paths
	var bought := GameState.buy("verdant", "gel", 5)
	print("bought ", bought, " gel; best market: ", Galaxy.best_sell("gel")["name"])
	for tab in ["missions", "market", "shipyard", "services"]:
		main.menu._select(tab)
		await _wait(0.2)
	# jump to Corvan through the stargate
	main._launch()
	await _wait(1.0)
	var gate: Stargate = main.gates["corvan"]
	p.global_transform = Transform3D(Basis.looking_at(gate.global_position - gate.approach_point(), Vector3.UP), gate.approach_point())
	await _wait(0.2)
	if p.can_jump() == null:
		return _fail("cannot jump at gate")
	var charges := GameState.jump_charges
	main._on_jump_requested("corvan")
	await _wait(6.0)
	if GameState.system_id != "corvan" or p.mode != PlayerShip.Mode.FLIGHT:
		return _fail("jump failed: %s mode %d" % [GameState.system_id, p.mode])
	print("jumped to ", GameState.system_id, " charges ", charges, " -> ", GameState.jump_charges, " stations: ", main.stations.keys())
	# two-hop jump should be refused with 1 charge
	if GameState.jump_charges != charges - 1:
		return _fail("charge not consumed")
	var st2: Station = main.stations["lumen"]
	p.global_transform = Transform3D(Basis.looking_at(st2.global_position - st2.approach_point(), Vector3.UP), st2.approach_point())
	await _wait(0.2)
	GameInput.queue_action()
	await _wait(5.5)
	if p.mode != PlayerShip.Mode.DOCKED:
		return _fail("did not dock in corvan")
	var sold := GameState.sell("lumen", "gel")
	print("sold gel at Lumen for ", sold)
	GameState.refuel()
	print("refuelled: ", GameState.jump_charges, "/", GameState.max_jump_charges())
	# first-person + inverted toggles don't break flight
	Settings.first_person = true
	Settings.invert_pitch = true
	main._launch()
	await _wait(1.5)
	Settings.first_person = false
	Settings.invert_pitch = false
	# death and respawn
	GameState.hull = 1.0
	p.shield = 0.0
	p.take_damage(50.0)
	await _wait(5.0)
	if p.mode != PlayerShip.Mode.DOCKED:
		return _fail("no respawn after death")
	print("respawned at ", GameState.last_station, " in ", GameState.system_id)
	# save round trip
	GameState.save_game()
	if not GameState.load_game():
		return _fail("save did not load")
	print("SIMTEST PASS")
	get_tree().quit(0)
