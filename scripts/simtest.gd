extends Node
## Dev-only headless gameplay check: godot --headless -- --simtest
## Accepts the hunt, flies the lane to Kessler Beacon, kills the raiders,
## docks at Verdant Spire and checks that the reward was paid.

var main: Node


func _ready() -> void:
	_run()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _fail(msg: String) -> void:
	print("SIMTEST FAIL: ", msg)
	get_tree().quit(1)


func _run() -> void:
	await _wait(0.5)
	var hunt: Dictionary = {}
	for m in GameState.missions_for("halcyon"):
		if m["kind"] == "hunt":
			hunt = m
	GameState.accept(hunt)
	var start_credits := GameState.credits
	main._launch()
	var p: PlayerShip = main.player
	await _wait(0.5)
	# fly into the gate and ride the lane
	var f: Dictionary = main.lane.frame(0.0)
	p.global_transform = Transform3D(Basis.looking_at(f["fwd"], Vector3.UP), f["origin"] - f["fwd"] * 50.0)
	await _wait(0.2)
	if main.player.can_enter_lane().is_empty():
		return _fail("cannot enter lane at gate")
	p.enter_lane()
	GameInput.throttle = 1.0
	var t := 0.0
	while p.mode == PlayerShip.Mode.LANE:
		var ne: Dictionary = main.lane.next_exit(p.lane_s, p.lane_dir)
		if not ne.is_empty() and ne["name"] == "Kessler Beacon" and ne["dist"] < 300.0:
			p.exit_lane()
		await _wait(0.1)
		t += 0.1
		if t > 30.0:
			return _fail("lane ride never reached the beacon")
	print("dropped out near beacon: ", p.global_position.distance_to(main.beacon_pos), " m after ", t, " s")
	await _wait(0.5)
	var enemies := get_tree().get_nodes_in_group("enemies")
	print("enemies: ", enemies.size(), " hunt left: ", hunt["left"])
	# kill them with the real weapon path: point at each, hold fire
	GameState.upgrades["laser"] = 4
	GameState.hull = 100000.0
	var guard := 0.0
	while not get_tree().get_nodes_in_group("enemies").is_empty() and guard < 120.0:
		var e: Node3D = get_tree().get_nodes_in_group("enemies")[0]
		var aim: Vector3 = main.lead_point(p.global_position, e, Combat.PLAYER_BOLT_SPEED)
		var pos := e.global_position + (p.global_position - e.global_position).normalized() * 250.0
		p.global_transform = Transform3D(Basis.looking_at(aim - pos, Vector3.UP), pos)
		p.velocity = Vector3.ZERO
		GameInput.throttle = 0.0
		GameInput.touch_fire = true
		await _wait(0.1)
		guard += 0.1
	GameInput.touch_fire = false
	GameState.hull = 100.0
	print("kills: ", GameState.kills, " hunt state: ", hunt["state"], " after ", guard, " s")
	if hunt["state"] != "done":
		return _fail("hunt not completed")
	# dock at Verdant
	var st: Station = main.stations["verdant"]
	p.global_transform = Transform3D(Basis.looking_at(st.global_position - st.approach_point(), Vector3.UP), st.approach_point())
	await _wait(0.2)
	if main.player.can_dock() == null:
		return _fail("cannot dock")
	GameInput.queue_action()
	await _wait(5.5)
	if p.mode != PlayerShip.Mode.DOCKED:
		return _fail("did not dock")
	print("credits: ", start_credits, " -> ", GameState.credits, " hunt: ", hunt["state"])
	if hunt["state"] != "paid":
		return _fail("not paid")
	# trade round trip
	var bought := GameState.buy("verdant", "gel", 999)
	var gain := GameState.sell("halcyon", "gel")
	print("trade: bought ", bought, " gel, sold for ", gain)
	# death and respawn
	main._launch()
	await _wait(0.5)
	GameState.hull = 1.0
	p.shield = 0.0
	p.take_damage(50.0)
	await _wait(5.0)
	if p.mode != PlayerShip.Mode.DOCKED:
		return _fail("no respawn after death")
	print("SIMTEST PASS")
	get_tree().quit(0)
