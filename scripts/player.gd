class_name PlayerShip
extends CharacterBody3D
## Arcade 6DOF flight, lane riding, docking autopilot and weapons.

signal died
signal docked(station: Station)
signal lane_changed(in_lane: bool)

enum Mode { FLIGHT, LANE, DOCKING, DOCKED, DEAD, JUMPING }

var mode := Mode.FLIGHT
var world: Node   # main.gd

# flight
var ang_vel := Vector3.ZERO
var speed := 0.0
var boost_energy := 1.0
var bank := 0.0
var model: Node3D
var engine_glow: OmniLight3D

# combat
var shield := 100.0
var shield_delay := 0.0
var weapon_cd: Array = []     # per primary slot
var missile_cd := 0.0
var gun_i := 0
var target: Node3D = null
var hardpoints: Array = []
var cam_scale := 1.0
var _shape: CollisionShape3D

# autopilot (main.gd plans the route, the ship flies it)
var autopilot := false
var ap_goal := Vector3.ZERO
var ap_arrive_slow := true      # slow down near the goal (stations / beacon)
var ap_lane_exit_s := -1.0      # in a lane: drop out around this s
var _lane_was_inside := false
var _merge_cd := 0.0

# lane
var lane: SpaceLane
var lane_s := 0.0
var lane_dir := 1
var lane_offset := Vector2.ZERO
var lane_speed := 0.0
var lane_bump_cd := 0.0

# docking
var dock_station: Station
var dock_t := 0.0
var dock_from: Transform3D


func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	_shape = CollisionShape3D.new()
	_shape.shape = SphereShape3D.new()
	add_child(_shape)
	model = MeshInstance3D.new()
	add_child(model)
	engine_glow = OmniLight3D.new()
	engine_glow.light_color = Color(0.3, 0.85, 1.0)
	engine_glow.omni_range = 14.0
	engine_glow.light_energy = 1.5
	add_child(engine_glow)
	refresh_ship()
	shield = GameState.max_shield()


## Rebuild the model and hardpoints after buying a ship.
func refresh_ship() -> void:
	var id: String = GameState.ship
	(model as MeshInstance3D).mesh = Models.ship(id)
	cam_scale = Models.ship_size(id)
	hardpoints = Models.hardpoints(id)
	engine_glow.position = Vector3(0, 0.5, 6.0 * cam_scale + 2.5)
	engine_glow.omni_range = 16.0 * cam_scale
	(_shape.shape as SphereShape3D).radius = 3.2 * cam_scale
	weapon_cd.clear()


func top_speed() -> float:
	return GameState.top_speed()


func _physics_process(delta: float) -> void:
	match mode:
		Mode.FLIGHT:
			_flight(delta)
		Mode.LANE:
			_lane_ride(delta)
		Mode.DOCKING:
			_docking(delta)
		_:
			pass
	_regen(delta)
	_merge_cd -= delta
	update_view_mode()
	if mode == Mode.FLIGHT or mode == Mode.LANE:
		_weapons(delta)
	engine_glow.light_energy = 0.4 + clampf(speed / top_speed(), 0.0, 2.5) * 0.8


func _flight(delta: float) -> void:
	var inp := GameInput
	if autopilot and (inp.stick.length() > 0.35 or absf(inp.roll) > 0.5):
		set_autopilot(false, "Manual override: autopilot off")
	if autopilot:
		_autopilot_flight(delta)
		return
	var stick: Vector2 = inp.stick
	var tm := GameState.turn_mult()
	var pitch_rate := 1.5 * tm
	var yaw_rate := 1.15 * tm
	var roll_rate := 2.4 * tm
	var target_av := Vector3(stick.y * pitch_rate, -stick.x * yaw_rate, -inp.roll * roll_rate)
	ang_vel = ang_vel.lerp(target_av, 1.0 - exp(-delta * 6.0))
	var b := global_transform.basis
	b = b * Basis(Vector3.RIGHT, ang_vel.x * delta)
	b = b * Basis(Vector3.UP, ang_vel.y * delta)
	b = b * Basis(Vector3.BACK, ang_vel.z * delta)
	global_transform.basis = b.orthonormalized()

	# visual banking into turns
	bank = lerpf(bank, -stick.x * 0.55, 1.0 - exp(-delta * 4.0))
	model.rotation = Vector3(stick.y * 0.12, 0, bank)

	_drive(delta, top_speed() * inp.throttle)
	_check_merge()


## Speed control shared by manual flight and autopilot (boost always allowed).
func _drive(delta: float, target_speed: float) -> void:
	var boosting := _boosting(delta)
	if boosting:
		target_speed = top_speed() * 2.1
	speed = lerpf(speed, target_speed, 1.0 - exp(-delta * (2.2 if boosting else 1.4)))
	var fwd := -global_transform.basis.z
	# arcade drift: velocity chases the nose
	velocity = velocity.lerp(fwd * speed, 1.0 - exp(-delta * 3.0))
	var pre := velocity
	move_and_slide()
	if get_slide_collision_count() > 0:
		var impact := pre.length() - velocity.length()
		if impact > 25.0:
			take_damage(impact * 0.35)
			world.shake(0.6)
		speed = velocity.length()
	world.asteroid_push(self)


func _boosting(delta: float) -> bool:
	var b: bool = GameInput.boost and boost_energy > 0.02
	if b:
		boost_energy = maxf(0.0, boost_energy - delta * 0.25 / GameState.boost_mult())
	else:
		boost_energy = minf(1.0, boost_energy + delta * 0.12)
	return b


func _regen(delta: float) -> void:
	shield_delay -= delta
	if shield_delay <= 0.0:
		shield = minf(GameState.max_shield(), shield + delta * GameState.shield_regen())
	var rep := GameState.hull_repair_rate()
	if rep > 0.0 and mode != Mode.DEAD:
		GameState.hull = minf(GameState.max_hull(), GameState.hull + rep * delta)


# --- Autopilot ----------------------------------------------------------------

func set_autopilot(on: bool, why := "") -> void:
	if on == autopilot:
		return
	autopilot = on
	ap_lane_exit_s = -1.0
	world.on_autopilot_changed(on, why)


func _autopilot_flight(delta: float) -> void:
	var to := ap_goal - global_position
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var cur := global_transform.basis
	var want := Basis.looking_at(dir, Vector3.UP)
	var ang := (-cur.z).angle_to(dir)
	var rate := 1.3 * GameState.turn_mult()
	var t := 1.0 if ang < 0.0001 else minf(1.0, rate * delta / ang)
	var q := cur.get_rotation_quaternion().slerp(want.get_rotation_quaternion(), t)
	global_transform.basis = Basis(q).orthonormalized()
	ang_vel = Vector3.ZERO
	bank = lerpf(bank, 0.0, 1.0 - exp(-delta * 3.0))
	model.rotation = model.rotation.lerp(Vector3(0, 0, bank), delta * 3.0)
	var spd := top_speed()
	if ap_arrive_slow:
		spd *= clampf(dist / 700.0, 0.25, 1.0)
	if ang > 0.6:
		spd *= 0.5   # turn first, then accelerate
	_drive(delta, spd)
	_check_merge()


func take_damage(amount: float) -> void:
	if mode == Mode.DEAD or mode == Mode.DOCKED or mode == Mode.DOCKING:
		return
	shield_delay = 3.5
	world.shake(0.25)
	world.sfx.hit(shield > amount)
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
	if amount > 0.0:
		GameState.hull -= amount
		world.flash_damage()
	if GameState.hull <= 0.0:
		GameState.hull = 0.0
		_die()


func _die() -> void:
	if mode == Mode.LANE:
		_leave_lane(false)
	set_autopilot(false)
	mode = Mode.DEAD
	model.visible = false
	velocity = Vector3.ZERO
	died.emit()


# --- Weapons ------------------------------------------------------------------

func _weapons(delta: float) -> void:
	var guns: Array = GameState.equip.get("primary", [])
	if weapon_cd.size() != guns.size():
		weapon_cd.resize(guns.size())
		weapon_cd.fill(0.0)
	for i in weapon_cd.size():
		weapon_cd[i] -= delta
	missile_cd -= delta
	target = world.pick_target(self)
	var assist := GameState.assist_deg()
	var want_fire: bool = GameInput.fire
	if GameInput.auto_fire and target and not want_fire:
		# auto-attack: fire whenever the target sits inside the aim-assist cone
		var lead0: Vector3 = world.lead_point(global_position, target, Combat.PLAYER_BOLT_SPEED)
		var fwd0 := -global_transform.basis.z
		want_fire = (lead0 - global_position).normalized().dot(fwd0) > cos(deg_to_rad(assist + 2.0)) and global_position.distance_to(lead0) < 1500.0
	if mode != Mode.FLIGHT:
		return
	if want_fire:
		for i in guns.size():
			if guns[i] == "" or weapon_cd[i] > 0.0:
				continue
			var w: Dictionary = Items.GEAR[guns[i]]
			weapon_cd[i] = w["cd"]
			_fire_gun(w, assist)
	if GameInput.consume_missile() and missile_cd <= 0.0:
		fire_missile()


func _fire_gun(w: Dictionary, assist: float) -> void:
	gun_i = (gun_i + 1) % maxi(hardpoints.size(), 1)
	var hp: Vector3 = hardpoints[gun_i] if not hardpoints.is_empty() else Vector3(0, 0, -3)
	var origin := global_transform * hp
	var dir := -global_transform.basis.z
	var spd: float = w["speed"]
	# aim assist: if a target is near the crosshair, lead it
	if target:
		var lead: Vector3 = world.lead_point(origin, target, spd)
		var to_lead := (lead - origin).normalized()
		if to_lead.dot(dir) > cos(deg_to_rad(assist)) and origin.distance_to(lead) < spd * w["life"]:
			dir = to_lead
	var pellets: int = w.get("pellets", 1)
	for k in pellets:
		var d := dir
		if pellets > 1:
			var sp := deg_to_rad(w["spread"])
			d = (dir + global_transform.basis.x * randf_range(-sp, sp) + global_transform.basis.y * randf_range(-sp, sp)).normalized()
		world.combat.fire(origin, d * spd + velocity, w["dmg"], Combat.TEAM_PLAYER, w["color"], w["life"], k == 0)


## Fire the first secondary weapon that has ammo. Returns false if none could fire.
func fire_missile() -> bool:
	for g in GameState.installed("secondary"):
		var w: Dictionary = Items.GEAR[g]
		var kind: String = w["ammo"]
		if GameState.ammo.get(kind, 0) <= 0:
			continue
		GameState.ammo[kind] -= 1
		missile_cd = w["cd"]
		for k in int(w["count"]):
			var side: float = (k - (w["count"] - 1) * 0.5) * 1.2
			var origin := global_transform * Vector3(side, -0.8, -2.0)
			var dir: Vector3 = (-global_transform.basis.z + global_transform.basis.x * side * 0.08).normalized()
			world.combat.fire_missile(origin, dir, velocity, target, w, Combat.TEAM_PLAYER)
		world.sfx.play("missile_launch", -3.0, randf_range(0.95, 1.05))
		return true
	GameState.message.emit("No missiles. Buy ammo at a station." if not GameState.installed("secondary").is_empty() else "No secondary weapon installed", Color(1, 0.55, 0.4))
	world.sfx.ui("error")
	missile_cd = 0.5
	return false


# --- Lane ---------------------------------------------------------------------

func can_enter_lane() -> Dictionary:
	if mode != Mode.FLIGHT or lane == null:
		return {}
	var c := lane.closest(global_position)
	if c["dist"] > SpaceLane.MERGE_RANGE:
		return {}
	return c


## Merge automatically when flying into the tube roughly along it.
func _check_merge() -> void:
	if lane == null:
		return
	var c := lane.closest(global_position)
	var inside: bool = c["dist"] < SpaceLane.RADIUS * 0.85
	if inside and not _lane_was_inside and _merge_cd <= 0.0 and speed > 25.0 and not autopilot:
		var f := lane.frame(c["s"])
		var d: float = (-global_transform.basis.z).dot(f["fwd"])
		if absf(d) > 0.6:
			enter_lane(1 if d > 0.0 else -1, true)
			return
	_lane_was_inside = inside


## Enter the lane where we are. dir 0 = pick from where the nose points.
func enter_lane(dir := 0, merged := false) -> void:
	if mode != Mode.FLIGHT or lane == null:
		return
	var c := lane.closest(global_position)
	if c["dist"] > SpaceLane.MERGE_RANGE and not merged:
		return
	lane_s = c["s"]
	var f := lane.frame(lane_s)
	var fwd := -global_transform.basis.z
	if dir == 0:
		dir = 1 if fwd.dot(f["fwd"]) >= 0.0 else -1
	if lane_s < 5.0:
		dir = 1
	elif lane_s > lane.length - 5.0:
		dir = -1
	lane_dir = dir
	# start inside the tube near where we are
	var rel: Vector3 = global_position - f["origin"]
	lane_offset = Vector2(rel.dot(f["right"]), rel.dot(f["up"])).limit_length(SpaceLane.RADIUS * 0.7)
	lane_speed = maxf(speed, 200.0)
	mode = Mode.LANE
	_lane_was_inside = true
	lane_changed.emit(true)
	if not autopilot:
		var ne := lane.next_exit(lane_s, lane_dir)
		var where: String = ("toward " + ne["name"]) if not ne.is_empty() else ""
		GameState.message.emit(("Merged into the lane " if merged else "Lane engaged ") + where, Color(0.5, 0.9, 1.0))


func _lane_ride(delta: float) -> void:
	var inp := GameInput
	if autopilot and (inp.stick.length() > 0.35 or absf(inp.roll) > 0.5):
		set_autopilot(false, "Manual override: autopilot off")
	var boosting: bool = inp.boost
	var steer: Vector2 = inp.stick
	var target_speed: float = 500.0 + 1100.0 * inp.throttle + (700.0 if boosting else 0.0)
	if autopilot:
		# a bit slower than a pilot flying flat out, but boost still works
		target_speed = 1250.0 + (700.0 if boosting else 0.0)
		var want := Vector2(0, SpaceLane.RADIUS * 0.55)
		var ahead := lane.traffic_near(lane_s, lane_dir, lane_offset, 500.0)
		if not ahead.is_empty():
			want = Vector2(-(ahead["offset"] as Vector2).x, SpaceLane.RADIUS * 0.6)
		var d := want - lane_offset
		steer = Vector2(d.x * lane_dir, d.y).limit_length(40.0) / 40.0
	lane_speed = lerpf(lane_speed, target_speed, 1.0 - exp(-delta * 0.9))
	var s_prev := lane_s
	lane_s += lane_dir * lane_speed * delta
	# lane right flips when travelling backwards
	lane_offset += Vector2(steer.x * lane_dir, steer.y) * 140.0 * delta
	lane_offset = lane_offset.limit_length(SpaceLane.RADIUS - 12.0)

	if autopilot and ap_lane_exit_s >= 0.0 and (ap_lane_exit_s - lane_s) * lane_dir < lane_speed * 0.6:
		_leave_lane(true)
		return

	lane_bump_cd -= delta
	if lane_bump_cd <= 0.0:
		var hit := lane.traffic_hit(s_prev, lane_s, lane_offset)
		if not hit.is_empty():
			lane_bump_cd = 1.0
			lane_speed *= 0.35
			take_damage(14.0)
			world.shake(1.0)
			GameState.message.emit("Collision! Watch the traffic.", Color(1, 0.5, 0.3))
			# get shoved sideways
			var away: Vector2 = lane_offset - (hit["offset"] as Vector2)
			lane_offset += away.normalized() * 6.0 if away.length() > 0.01 else Vector2(6, 0)

	if lane_s <= 0.0 or lane_s >= lane.length:
		lane_s = clampf(lane_s, 0.0, lane.length)
		_leave_lane(true)
		return

	var f := lane.frame(lane_s)
	var fwd: Vector3 = f["fwd"] * lane_dir
	var pos: Vector3 = f["origin"] + f["right"] * lane_offset.x + f["up"] * lane_offset.y
	var b := Basis.looking_at(fwd, f["up"])
	bank = lerpf(bank, -steer.x * 0.5, 1.0 - exp(-delta * 4.0))
	model.rotation = Vector3(steer.y * 0.15, 0, bank)
	velocity = fwd * lane_speed
	speed = lane_speed
	global_transform = Transform3D(b, pos)


func exit_lane() -> void:
	if mode == Mode.LANE:
		_leave_lane(true)


func _leave_lane(announce: bool) -> void:
	mode = Mode.FLIGHT
	_merge_cd = 2.0
	ap_lane_exit_s = -1.0
	speed = top_speed() * 0.9
	velocity = -global_transform.basis.z * speed
	ang_vel = Vector3.ZERO
	lane_changed.emit(false)
	if announce:
		var e := lane.nearest_entry(global_position)
		if not e.is_empty() and e["dist"] < 500.0:
			GameState.message.emit("Dropped out at %s" % e["name"], Color(0.5, 0.9, 1.0))
		else:
			GameState.message.emit("Dropped out of the lane", Color(0.5, 0.9, 1.0))


# --- Docking ------------------------------------------------------------------

func can_jump() -> Stargate:
	if mode != Mode.FLIGHT:
		return null
	for g in get_tree().get_nodes_in_group("stargates"):
		var sg := g as Stargate
		if sg.global_position.distance_to(global_position) < Stargate.JUMP_RANGE or sg.approach_point().distance_to(global_position) < Stargate.JUMP_RANGE:
			return sg
	return null


func update_view_mode() -> void:
	var fp := Settings.first_person and (mode == Mode.FLIGHT or mode == Mode.LANE or mode == Mode.JUMPING)
	if mode == Mode.DEAD or mode == Mode.DOCKED:
		model.visible = false
	else:
		model.visible = not fp
	engine_glow.visible = not fp


func can_dock() -> Station:
	if mode != Mode.FLIGHT:
		return null
	for s in get_tree().get_nodes_in_group("stations"):
		var st := s as Station
		if st.approach_point().distance_to(global_position) < Station.DOCK_RANGE or st.dock_point().distance_to(global_position) < Station.DOCK_RANGE:
			return st
	return null


func start_docking(st: Station) -> void:
	dock_station = st
	dock_t = 0.0
	dock_from = global_transform
	mode = Mode.DOCKING
	autopilot = false
	velocity = Vector3.ZERO
	GameState.message.emit("Docking computer engaged", Color(0.5, 1.0, 0.7))


func _docking(delta: float) -> void:
	dock_t += delta / 4.0
	var t := clampf(dock_t, 0.0, 1.0)
	var e := t * t * (3.0 - 2.0 * t)
	var a := dock_from.origin
	var c := dock_station.dock_point()
	var mid := dock_station.approach_point()
	# quadratic bezier through the approach point
	var p := a.lerp(mid, e).lerp(mid.lerp(c, e), e)
	var look_dir := (c - p)
	if look_dir.length() < 1.0:
		look_dir = dock_station.global_transform.basis.z
	var target_b := Basis.looking_at(look_dir.normalized(), dock_station.global_transform.basis.y)
	var q := dock_from.basis.get_rotation_quaternion().slerp(target_b.get_rotation_quaternion(), minf(1.0, e * 2.0))
	global_transform = Transform3D(Basis(q), p)
	speed = 60.0 * (1.0 - e)
	model.rotation = model.rotation.lerp(Vector3.ZERO, delta * 3.0)
	if dock_t >= 1.0:
		mode = Mode.DOCKED
		GameState.last_station = dock_station.station_id
		docked.emit(dock_station)


func undock(st: Station) -> void:
	global_transform = st.undock_transform()
	speed = 40.0
	velocity = -global_transform.basis.z * speed
	GameInput.throttle = maxf(GameInput.throttle, 0.4)
	ang_vel = Vector3.ZERO
	model.visible = true
	model.rotation = Vector3.ZERO
	shield = GameState.max_shield()
	mode = Mode.FLIGHT
