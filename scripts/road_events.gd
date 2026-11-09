class_name RoadEvents
extends Node
## 0.12 "The road": things that happen between stations. Distress calls,
## drifting cargo, customs scans, ion storms, pirate stops (threat 2+, unless
## you fly as a peaceful trader), comets - plus the cruise drive, the radio
## and postcards of each system's wonder.

const CRUISE_SCALE := 3.0

var main: Node
var timer := 75.0
var ev := {}               # the current event, {} when the road is quiet
var storm_t := 0.0
var cruise := false
var wonder: Node3D
var wonder_def := {}
var comet: Node3D
var comet_vel := Vector3.ZERO
var comet_t := 0.0
var photo_flash := 0.0
var _rng := RandomNumberGenerator.new()
var _hauler: Node3D


func _ready() -> void:
	_rng.randomize()
	process_mode = Node.PROCESS_MODE_PAUSABLE


## Called when a system is (re)built.
func reset_system(sid: String, wonder_node: Node3D) -> void:
	ev = {}
	storm_t = 0.0
	set_cruise(false)
	timer = _rng.randf_range(45.0, 80.0)
	comet = null
	_hauler = null
	wonder = wonder_node
	wonder_def = Galaxy.SYSTEMS[sid].get("wonder", {})


func _player() -> PlayerShip:
	return main.player


func _threat() -> int:
	return Galaxy.SYSTEMS[GameState.system_id]["threat"]


func _process(delta: float) -> void:
	var p := _player()
	photo_flash = maxf(0.0, photo_flash - delta * 3.0)
	if wonder and wonder_def.get("kind", "") == "lighthouse":
		var beam := wonder.get_node_or_null("Beam")
		if beam:
			wonder.rotate_y(delta * TAU / 7.0)
	if comet:
		comet.global_position += comet_vel * delta
		comet_t -= delta
		if comet_t <= 0.0:
			comet.queue_free()
			comet = null
	var on_road := p.mode == PlayerShip.Mode.LANE or p.mode == PlayerShip.Mode.FLIGHT
	if not on_road:
		set_cruise(false)
		return
	# ion storm
	if storm_t > 0.0:
		storm_t -= delta
		if storm_t <= 0.0:
			GameState.message.emit("The ion storm has passed. Full speed ahead.", Color(0.6, 1.0, 0.8))
	p.speed_mult = (0.55 if storm_t > 0.0 else 1.0) * (1.15 if GameState.is_rested() else 1.0)
	_update_cruise()
	if ev.is_empty():
		if p.mode == PlayerShip.Mode.LANE or p.speed > 150.0:
			timer -= delta
		if timer <= 0.0:
			timer = _rng.randf_range(70.0, 140.0)
			_roll()
	else:
		_update_event(delta)


# --- cruise drive --------------------------------------------------------------------

## Cruise compresses time on the open highway loop (x3), and drops out by
## itself before your exit, for events and when anyone starts shooting.
func cruise_available() -> bool:
	var p := _player()
	if p.mode != PlayerShip.Mode.LANE or p.lane == null or p.lane.role != "loop":
		return false
	if storm_t > 0.0 or ev.get("blocks_cruise", false):
		return false
	if main._combat_hold > 0.0:
		return false
	var nx: Dictionary = main.net.next_exit(p.lane, p.lane_s)
	if not nx.is_empty() and (p.exit_choice == 1 or (p.exit_choice == -1 and p.gps_exit == nx["node"])) and nx["dist"] < 3500.0 + p.lane_speed * 2.0:
		return false
	return true


func set_cruise(on: bool) -> void:
	if on == cruise:
		return
	cruise = on
	Engine.time_scale = CRUISE_SCALE if on else 1.0
	if main and main.sfx:
		main.sfx.play("cruise_on" if on else "lane_exit", -6.0, 1.0 if on else 1.4)


func toggle_cruise() -> void:
	if cruise:
		set_cruise(false)
		GameState.message.emit("Cruise off", Color(0.75, 0.85, 1.0))
	elif cruise_available():
		set_cruise(true)
		GameState.message.emit("CRUISE x3: sit back, it drops out before your exit", Color(0.55, 1.0, 0.75))


func _update_cruise() -> void:
	if cruise and not cruise_available():
		set_cruise(false)
		GameState.message.emit("Cruise disengaged", Color(1.0, 0.85, 0.45))


# --- events --------------------------------------------------------------------------

func _cargo_value() -> int:
	var v := 0
	for g in GameState.cargo:
		v += int(GameState.cargo[g]) * int(Economy.GOODS[g]["base"])
	return v


func _illegal_cargo() -> Dictionary:
	var out := {}
	for g in GameState.cargo:
		if Economy.GOODS[g].get("illegal", false) and int(GameState.cargo[g]) > 0:
			out[g] = int(GameState.cargo[g])
	return out


func _roll() -> void:
	var p := _player()
	var lane := p.mode == PlayerShip.Mode.LANE
	var threat := _threat()
	var pool := []
	if lane:
		pool.append(["distress", 3.0])
		pool.append(["derelict", 3.0])
	if threat <= 1 and lane:
		pool.append(["customs", 5.0 if not _illegal_cargo().is_empty() else 1.0])
	pool.append(["storm", 1.5])
	if comet == null:
		pool.append(["comet", 1.5])
	if threat >= 2 and lane and not Settings.peaceful_trader and not GameState.has_licence("comet"):
		pool.append(["pirates", 1.5 * (threat - 1) * (1.6 if _cargo_value() > 4000 else 1.0)])
	var total := 0.0
	for e in pool:
		total += e[1]
	var r := _rng.randf() * total
	for e in pool:
		r -= e[1]
		if r <= 0.0:
			start(e[0])
			return


## Start an event by kind (the simtest calls this directly).
func start(kind: String) -> void:
	var p := _player()
	set_cruise(false)
	main.sfx.play("event_ping", -4.0)
	match kind:
		"distress":
			ev = {"kind": kind, "phase": "offer", "t": 22.0, "label": "HELP HAULER", "color": Color(0.5, 1.0, 0.7), "blocks_cruise": true,
				"title": "DISTRESS CALL", "text": "\"Mayday-ish! Our drive coughed and died. We've got coffee.\" A hauler is stranded just off the road."}
		"derelict":
			ev = {"kind": kind, "phase": "offer", "t": 22.0, "label": "SALVAGE POD", "color": Color(0.5, 1.0, 0.6), "blocks_cruise": true,
				"title": "DRIFTING CARGO", "text": "Sensors ping a cargo pod tumbling just off the road. Finders keepers."}
		"customs":
			ev = {"kind": kind, "phase": "scan", "t": 5.0, "title": "CUSTOMS SCAN", "blocks_cruise": true,
				"text": "Core Customs is scanning your hold. Please keep your hands where the scanner can see them."}
			main.sfx.play("scan", -4.0)
		"storm":
			storm_t = 45.0
			ev = {}
			GameState.message.emit("ION STORM: the lanes run at half speed for a while", Color(0.75, 0.6, 1.0))
			main.shake(0.4)
		"comet":
			_spawn_comet()
			ev = {}
		"pirates":
			var toll := clampi(int(_cargo_value() * 0.1) + 250 * _threat(), 300, 6000)
			ev = {"kind": kind, "phase": "toll", "t": 12.0, "toll": toll, "label": "PAY TOLL %d" % toll, "color": Color(1.0, 0.75, 0.35), "blocks_cruise": true,
				"title": "INTERDICTION",
				"text": "\"Nice ship. Shame if it got holes in it. Toll's %d cr, or we do this the loud way.\"" % toll}
			if p.mode == PlayerShip.Mode.LANE:
				p.exit_lane()
			p.set_autopilot(false, "")
			main.shake(1.0)
			var fwd := -p.global_transform.basis.z
			var n := 2 + (1 if _threat() >= 3 else 0)
			var crew := []
			for i in n:
				var ang := TAU * i / n
				var off := p.global_transform.basis.x * cos(ang) * 400.0 + p.global_transform.basis.y * sin(ang) * 220.0
				var r := Raider.new()
				main.world_root.add_child(r)
				r.setup(main, p.global_position + fwd * 700.0 + off, i == 0 and _threat() >= 3)
				crew.append(r)
			ev["crew"] = crew


## What the second context button offers right now: {label, color} or {}.
func offer() -> Dictionary:
	if not ev.is_empty() and ev.has("label") and ev.get("phase", "") in ["offer", "toll"]:
		if ev["kind"] == "pirates" and GameState.credits < int(ev["toll"]):
			return {}
		return {"label": ev["label"], "color": ev["color"]}
	if cruise:
		return {"label": "CRUISE OFF", "color": Color(1.0, 0.85, 0.45)}
	if cruise_available():
		return {"label": "CRUISE x3", "color": Color(0.55, 1.0, 0.75)}
	return {}


func take_offer() -> void:
	var p := _player()
	if ev.is_empty() or not ev.get("phase", "") in ["offer", "toll"]:
		toggle_cruise()
		return
	match ev["kind"]:
		"distress":
			if p.mode == PlayerShip.Mode.LANE:
				p.exit_lane()
			var fwd := -p.global_transform.basis.z
			var pos := p.global_position + fwd * 1400.0 + p.global_transform.basis.x * 450.0
			_hauler = MeshInstance3D.new()
			(_hauler as MeshInstance3D).mesh = Models.freighter(_rng.randi() % 1000)
			main.world_root.add_child(_hauler)
			_hauler.global_position = pos
			_hauler.look_at(pos + p.global_transform.basis.x, Vector3.UP)
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.5, 0.3)
			light.omni_range = 120.0
			light.light_energy = 2.0
			_hauler.add_child(light)
			ev["phase"] = "go"
			ev["pos"] = pos
			ev["t"] = 240.0
			ev["mark"] = "Stranded hauler"
			GameState.message.emit("Hauler marked. Fly over and pass them a jump cell.", Color(0.5, 1.0, 0.7))
		"derelict":
			if p.mode == PlayerShip.Mode.LANE:
				p.exit_lane()
			var fwd := -p.global_transform.basis.z
			var pos := p.global_position + fwd * 900.0
			var goods := ["food", "water", "polymer", "electronics", "wine", "spice", "machinery", "gel"]
			for i in 3:
				var g: String = goods[_rng.randi() % goods.size()]
				var contents := {"goods": {g: _rng.randi_range(2, 6)}}
				if i == 0:
					contents["parts"] = {"scrap": _rng.randi_range(1, 3)}
				main.spawn_loot(pos + Vector3(_rng.randf_range(-80, 80), _rng.randf_range(-40, 40), _rng.randf_range(-80, 80)), contents, true)
			GameState.message.emit("Pod cracked open: cargo canisters ahead. Your tractor will pull them in.", Color(0.5, 1.0, 0.6))
			ev = {}
		"pirates":
			var toll: int = ev["toll"]
			if GameState.credits < toll:
				return
			GameState.credits -= toll
			main.sfx.play("ui_buy", -4.0, 0.8)
			for r in ev.get("crew", []):
				if is_instance_valid(r):
					r.remove_from_group("enemies")
					r.queue_free()
			GameState.message.emit("\"Pleasure doing business.\" The pirates peel off. (-%d cr)" % toll, Color(1.0, 0.75, 0.35))
			ev = {}


func _update_event(delta: float) -> void:
	var p := _player()
	ev["t"] = float(ev["t"]) - delta
	match ev["kind"]:
		"distress":
			if ev["phase"] == "offer" and ev["t"] <= 0.0:
				GameState.message.emit("Someone else answered the hauler's call.", Color(0.75, 0.85, 1.0))
				ev = {}
			elif ev["phase"] == "go":
				if p.global_position.distance_to(ev["pos"]) < 260.0 and p.mode == PlayerShip.Mode.FLIGHT:
					var tip := 250 + 200 * _threat() + _rng.randi_range(0, 250)
					GameState.credits += tip
					var gift: String = ["food", "wine", "spice", "gel"][_rng.randi() % 4]
					var got := GameState.add_cargo_free(gift, 2)
					GameState.lifetime["good_deeds"] = int(GameState.lifetime.get("good_deeds", 0)) + 1
					GameState.add_rep("haulers", 3)
					var gift_txt := (" and %d %s" % [got, Economy.good_name(gift)]) if got > 0 else ""
					GameState.message.emit("\"You're a star!\" The crew tips you %d cr%s." % [tip, gift_txt], Color(0.5, 1.0, 0.7))
					main.sfx.play("mission_complete", -4.0)
					_hauler_leave()
					ev = {}
				elif ev["t"] <= 0.0:
					_hauler_leave()
					ev = {}
		"derelict":
			if ev["t"] <= 0.0:
				ev = {}
		"customs":
			if ev["t"] <= 0.0:
				var bad := _illegal_cargo()
				var smuggling := GameState.active_smuggle_here()
				if Items.SHIPS[GameState.ship].get("hidden", false):
					GameState.message.emit("Customs scan: nothing but sandwiches. Your Phantom's hold stays quiet.", Color(0.6, 1.0, 0.75))
				elif GameState.has_licence("navy"):
					GameState.message.emit("Customs sees your Navy commission and waves you through.", Color(0.5, 0.75, 1.0))
				elif not smuggling.is_empty():
					GameState.fail_mission(smuggling, "Customs found the sealed crate. Contract void.")
					var fine2 := mini(GameState.credits, 1500)
					GameState.credits -= fine2
					main.sfx.play("ui_error", -3.0)
				elif bad.is_empty():
					GameState.message.emit("Customs: clean hold. Safe travels, pilot!", Color(0.6, 1.0, 0.75))
				else:
					var worth := 0
					for g in bad:
						worth += bad[g] * int(Economy.GOODS[g]["base"])
						GameState.cargo.erase(g)
						GameState.cargo_cost.erase(g)
					var fine := mini(GameState.credits, maxi(200, int(worth * 0.25)))
					GameState.credits -= fine
					GameState.add_rep("navy", -4)
					GameState.message.emit("Customs seized your contraband and fined you %d cr. Tsk." % fine, Color(1.0, 0.45, 0.4))
					main.sfx.play("ui_error", -3.0)
				ev = {}
		"pirates":
			if ev["phase"] == "toll" and ev["t"] <= 0.0:
				ev["phase"] = "fight"
				ev["t"] = 120.0
				ev["blocks_cruise"] = false
				for r in ev.get("crew", []):
					if is_instance_valid(r):
						r.aggro = true
						r.state = Raider.State.ATTACK
				GameState.message.emit("\"The loud way it is!\" Pirates attacking!", Color(1.0, 0.4, 0.35))
			elif ev["phase"] == "fight":
				var alive := 0
				for r in ev.get("crew", []):
					if is_instance_valid(r) and r.hp > 0.0:
						alive += 1
				if alive == 0:
					GameState.message.emit("Pirate crew scattered. The road is yours again.", Color(0.6, 1.0, 0.75))
					GameState.add_rep("navy", 2)
					ev = {}
				elif ev["t"] <= 0.0:
					ev = {}


func _hauler_leave() -> void:
	if _hauler and is_instance_valid(_hauler):
		var h := _hauler
		var tw := h.create_tween()
		tw.tween_property(h, "position", h.position + h.global_transform.basis.z * -3000.0, 4.0).set_ease(Tween.EASE_IN)
		tw.tween_callback(h.queue_free)
	_hauler = null


# --- comets and postcards ------------------------------------------------------------

func _spawn_comet() -> void:
	var p := _player()
	var fwd := -p.global_transform.basis.z
	var side := p.global_transform.basis.x
	var col: Color = (Galaxy.SYSTEMS[GameState.system_id]["sky"]["c"] as Color).lerp(Color(0.75, 0.9, 1.0), 0.5)
	comet = Wonders.comet(col)
	main.world_root.add_child(comet)
	comet.global_position = p.global_position + fwd * 9000.0 - side * 7000.0 + Vector3.UP * 1500.0
	comet_vel = side * 260.0
	comet.look_at(comet.global_position - comet_vel, Vector3.UP)
	comet_t = 80.0
	GameState.message.emit("A comet is crossing your path! Grab a postcard (PHOTO).", Color(0.75, 0.9, 1.0))


## Something worth a photo in view: {id, name, desc, pos, reward} or {}.
func photo_target() -> Dictionary:
	var cam: Camera3D = main.camera
	var fwd := -cam.global_transform.basis.z
	var cands := []
	if wonder and not wonder_def.is_empty():
		cands.append({"id": "wonder_" + GameState.system_id, "name": wonder_def["name"], "desc": wonder_def["desc"],
			"pos": wonder.global_position, "range": 22000.0, "reward": 500 + 300 * _threat()})
	if comet:
		cands.append({"id": "comet_" + GameState.system_id, "name": "Comet over " + Galaxy.SYSTEMS[GameState.system_id]["name"],
			"desc": "A wandering comet, caught mid-crossing.", "pos": comet.global_position, "range": 18000.0, "reward": 900})
	for c in cands:
		var d: Vector3 = (c["pos"] as Vector3) - cam.global_position
		if d.length() < float(c["range"]) and rad_to_deg(fwd.angle_to(d)) < 30.0:
			return c
	return {}


func take_photo() -> void:
	var t := photo_target()
	main.sfx.play("photo", -3.0)
	photo_flash = 1.0
	if t.is_empty():
		GameState.message.emit("Nice shot of... space. Point the camera at a wonder or a comet.", Color(0.75, 0.85, 1.0))
		return
	var first := not GameState.postcards.has(t["id"])
	GameState.postcards[t["id"]] = {"name": t["name"], "desc": t["desc"], "system": GameState.system_id, "t": int(Time.get_unix_time_from_system())}
	_save_thumb(t["id"])
	GameState.on_photo(t["id"])
	if first:
		t["reward"] = int(t["reward"] * (1.5 if GameState.has_licence("lantern") else 1.0))
		GameState.credits += int(t["reward"])
		GameState.add_rep("lantern", 2)
		GameState.message.emit("POSTCARD: %s! The Tourism Board pays %d cr." % [t["name"], t["reward"]], Color(1.0, 0.85, 0.5))
		main.sfx.play("kaching", -4.0)
	else:
		GameState.message.emit("Another lovely shot of %s for the album." % t["name"], Color(1.0, 0.9, 0.7))


func _save_thumb(id: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	img.resize(384, 216, Image.INTERPOLATE_BILINEAR)
	DirAccess.make_dir_recursive_absolute("user://postcards")
	img.save_png("user://postcards/%s.png" % id)


## Marker for the HUD while an event wants you somewhere: {pos, label} or {}.
func marker() -> Dictionary:
	if ev.get("phase", "") == "go" and ev.has("pos"):
		return {"pos": ev["pos"], "label": ev.get("mark", "")}
	return {}
