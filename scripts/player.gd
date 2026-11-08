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
var fire_cd := 0.0
var gun_side := 1.0
var target: Node3D = null

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
	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 3.2
	shape.shape = sph
	add_child(shape)
	model = MeshInstance3D.new()
	(model as MeshInstance3D).mesh = Models.player_ship()
	add_child(model)
	engine_glow = OmniLight3D.new()
	engine_glow.light_color = Color(0.3, 0.85, 1.0)
	engine_glow.omni_range = 14.0
	engine_glow.light_energy = 1.5
	engine_glow.position = Vector3(0, 0.5, 5.5)
	add_child(engine_glow)
	shield = GameState.max_shield()


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
	update_view_mode()
	if mode == Mode.FLIGHT or mode == Mode.LANE:
		_weapons(delta)
	engine_glow.light_energy = 0.6 + clampf(speed / top_speed(), 0.0, 2.5) * 1.2


func _flight(delta: float) -> void:
	var inp := GameInput
	var stick: Vector2 = inp.stick
	var pitch_rate := 1.5
	var yaw_rate := 1.15
	var roll_rate := 2.4
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

	var boosting: bool = inp.boost and boost_energy > 0.02
	var target_speed: float = top_speed() * inp.throttle
	if boosting:
		target_speed = top_speed() * 2.1
		boost_energy = maxf(0.0, boost_energy - delta * 0.25)
	else:
		boost_energy = minf(1.0, boost_energy + delta * 0.12)
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


func _regen(delta: float) -> void:
	shield_delay -= delta
	if shield_delay <= 0.0:
		shield = minf(GameState.max_shield(), shield + delta * 9.0)


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
	mode = Mode.DEAD
	model.visible = false
	velocity = Vector3.ZERO
	died.emit()


# --- Weapons ------------------------------------------------------------------

func _weapons(delta: float) -> void:
	fire_cd -= delta
	target = world.pick_target(self)
	var want_fire: bool = GameInput.fire
	if GameInput.auto_fire and target and not want_fire:
		# auto-attack: fire whenever the target sits inside the aim-assist cone
		var lead0: Vector3 = world.lead_point(global_position, target, Combat.PLAYER_BOLT_SPEED)
		var fwd0 := -global_transform.basis.z
		want_fire = (lead0 - global_position).normalized().dot(fwd0) > cos(deg_to_rad(11.0)) and global_position.distance_to(lead0) < 1500.0
	if want_fire and fire_cd <= 0.0 and mode == Mode.FLIGHT:
		fire_cd = 0.14
		gun_side = -gun_side
		var origin := global_transform * Vector3(gun_side * 1.6, 0.0, -3.0)
		var dir := -global_transform.basis.z
		# aim assist: if a target is near the crosshair, lead it
		if target:
			var lead: Vector3 = world.lead_point(origin, target, Combat.PLAYER_BOLT_SPEED)
			var to_lead := (lead - origin).normalized()
			if to_lead.dot(dir) > cos(deg_to_rad(9.0)) and origin.distance_to(lead) < 1600.0:
				dir = to_lead
		world.combat.fire(origin, dir * Combat.PLAYER_BOLT_SPEED + velocity, GameState.laser_damage(), Combat.TEAM_PLAYER)


# --- Lane ---------------------------------------------------------------------

func can_enter_lane() -> Dictionary:
	if mode != Mode.FLIGHT or lane == null:
		return {}
	var e := lane.nearest_entry(global_position)
	if e.is_empty() or e["dist"] > SpaceLane.ENTRY_RANGE:
		return {}
	return e


func enter_lane() -> void:
	var e := can_enter_lane()
	if e.is_empty():
		return
	lane_s = e["s"]
	var f := lane.frame(lane_s)
	var fwd := -global_transform.basis.z
	# pick direction from where the nose points; at the ends there is only one way
	if lane_s < 5.0:
		lane_dir = 1
	elif lane_s > lane.length - 5.0:
		lane_dir = -1
	else:
		lane_dir = 1 if fwd.dot(f["fwd"]) >= 0.0 else -1
	# start inside the tube near where we are
	var rel: Vector3 = global_position - f["origin"]
	lane_offset = Vector2(rel.dot(f["right"]), rel.dot(f["up"])).limit_length(SpaceLane.RADIUS * 0.6)
	lane_speed = maxf(speed, 150.0)
	mode = Mode.LANE
	lane_changed.emit(true)
	GameState.message.emit("Lane engaged. Steer to overtake, tap EXIT to drop out.", Color(0.5, 0.9, 1.0))


func _lane_ride(delta: float) -> void:
	var inp := GameInput
	var boosting: bool = inp.boost
	var target_speed: float = 380.0 + 520.0 * inp.throttle + (300.0 if boosting else 0.0)
	lane_speed = lerpf(lane_speed, target_speed, 1.0 - exp(-delta * 0.9))
	lane_s += lane_dir * lane_speed * delta
	var steer: Vector2 = inp.stick
	# lane right flips when travelling backwards
	lane_offset += Vector2(steer.x * lane_dir, steer.y) * 70.0 * delta
	lane_offset = lane_offset.limit_length(SpaceLane.RADIUS - 8.0)

	lane_bump_cd -= delta
	if lane_bump_cd <= 0.0:
		var hit := lane.traffic_hit(lane_s, lane_offset)
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
