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
var ap_lane_exit_s := -1.0      # on a track: drop out around this s
var ap_route: Array = []        # planned rides [{track, dir, enter_s, exit_s}], first = current
var _lane_was_inside := false
var _merge_cd := 0.0

# roads and highways
var net: RoadNet
var lane: SpaceLane             # the track we're riding (null in free flight)
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
	if boost_level > 0.001:
		target_speed = maxf(target_speed, top_speed() * (1.0 + 1.1 * boost_level))
	speed = lerpf(speed, target_speed, 1.0 - exp(-delta * lerpf(1.4, 2.2, boost_level)))
	if not boosting and absf(speed - target_speed) < 0.5:
		speed = target_speed
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


## Boost with a smooth tail: full boost while the meter lasts, then a steady
## "drained" boost for as long as the button stays held (no regen meanwhile).
## The meter has to refill to 25% before full boost comes back, and the
## effective strength is eased, so speed never flickers at the empty mark.
func _boosting(delta: float) -> bool:
	var held: bool = GameInput.boost
	var want := 0.0
	if held:
		if boost_drained:
			want = DRAINED_BOOST
		else:
			want = 1.0
			boost_energy = maxf(0.0, boost_energy - delta * 0.25 / GameState.boost_mult())
			if boost_energy <= 0.0:
				boost_drained = true
	else:
		boost_energy = minf(1.0, boost_energy + delta * 0.12)
		if boost_energy >= 0.25:
			boost_drained = false
	boost_level = move_toward(boost_level, want, delta * (1.6 if want < boost_level else 2.5))
	return held


const DRAINED_BOOST := 0.3      # share of the full boost you keep on an empty meter
var boost_level := 0.0           # eased 0..1 boost strength actually applied
var boost_drained := false


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
	ap_route = []
	world.on_autopilot_changed(on, why)


func _autopilot_flight(delta: float) -> void:
	var to := ap_goal - global_position
	var dist := to.length()
	var dir := _avoid_rocks(to / maxf(dist, 0.001), dist)
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


## Bend the autopilot heading around asteroids on the way: the nearest rock
## whose surface the straight line would pass too close to pushes the heading
## sideways, so the autopilot can't wedge itself against a rock.
func _avoid_rocks(dir: Vector3, dist: float) -> Vector3:
	var look := minf(dist, 500.0 + speed * 2.5)
	var margin := 45.0 * cam_scale
	var best_t := INF
	var push := Vector3.ZERO
	for r in world.rocks:
		var rel: Vector3 = r["pos"] - global_position
		var t := rel.dot(dir)
		if t < -float(r["r"]) or t > look:
			continue
		var side := rel - dir * t
		var clear: float = r["r"] + margin
		if side.length_squared() < clear * clear and t < best_t:
			best_t = t
			var away := -side
			if away.length_squared() < 1.0:
				away = global_transform.basis.x
			push = away.normalized() * (1.0 - side.length() / clear + 0.35)
	if push == Vector3.ZERO:
		return dir
	return (dir + push * 1.6).normalized()


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


# --- Roads and highways ------------------------------------------------------------

func can_enter_lane() -> Dictionary:
	if mode != Mode.FLIGHT or net == null:
		return {}
	var c := net.closest(global_position, 700.0)
	if c.is_empty() or c["dist"] > (c["track"] as SpaceLane).spec()["merge"]:
		return {}
	return c


## Merge automatically when flying into a tube roughly along it.
func _check_merge() -> void:
	if net == null:
		return
	var c := net.closest(global_position, 0.0)
	var inside: bool = not c.is_empty() and c["dist"] < (c["track"] as SpaceLane).radius * 0.85
	if inside and not _lane_was_inside and _merge_cd <= 0.0 and speed > 25.0 and not autopilot:
		var t: SpaceLane = c["track"]
		var f := t.frame(c["s"])
		var d: float = (-global_transform.basis.z).dot(f["fwd"])
		if absf(d) > 0.6:
			enter_lane(1 if d > 0.0 else -1, true, t)
			return
	_lane_was_inside = inside


## Enter the nearest road / highway where we are (or `track` if given).
## dir 0 = pick from where the nose points.
func enter_lane(dir := 0, merged := false, track: SpaceLane = null) -> void:
	if mode != Mode.FLIGHT or net == null:
		return
	var c := track.closest(global_position) if track else net.closest(global_position, 700.0)
	if c.is_empty():
		return
	var t: SpaceLane = c["track"]
	if c["dist"] > t.spec()["merge"] and not merged:
		return
	lane = t
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
	lane_offset = Vector2(rel.dot(f["right"]), rel.dot(f["up"])).limit_length(lane.radius * 0.7)
	lane_speed = maxf(speed, 200.0)
	_ride_basis = global_transform.basis
	junction = {}
	mode = Mode.LANE
	_lane_was_inside = true
	lane_changed.emit(true)
	if not autopilot:
		var where := net.node_name(net.end_node(lane, lane_dir))
		GameState.message.emit("%s %s toward %s" % ["Merged onto the" if merged else "Joined the", lane.kind, where], Color(0.5, 0.9, 1.0))


## Junction preview for the HUD: {node, name, kind, dist, options, pick, bands}.
## The options are the junction's lanes, left to right: every branch you can
## take with a turn of at most 60 degrees, plus "stop here" on the far right
## at stations, gates and beacons. Which one you take is set by which lane
## (side of the tube) you hold as you arrive.
var junction := {}

const BAND_WIDTH := 0.8   # the lanes share this fraction of the tube's width


## The lanes at the end of track t when riding it in dir.
func junction_options(t: SpaceLane, dir: int) -> Array:
	var n := net.end_node(t, dir)
	var opts: Array = net.allowed(t, dir).duplicate()
	if net.nodes[n]["kind"] == "poi":
		opts.append({"stop": true, "turn": 90.0, "name": net.node_name(n), "kind": "stop", "track": null, "dir": 0})
	return opts


## Lane index for a sideways offset (ship-relative, metres) with nb lanes.
func band_at(rx: float, nb: int) -> int:
	var u := clampf(rx / (lane.radius * BAND_WIDTH), -0.999, 0.999)
	return clampi(int(floor((u + 1.0) * 0.5 * nb)), 0, nb - 1)


## Ship-relative sideways offset (metres) of the middle of lane i of nb.
func band_centre(i: int, nb: int) -> float:
	return ((i + 0.5) / nb * 2.0 - 1.0) * lane.radius * BAND_WIDTH


func _update_junction() -> void:
	var end_s: float = lane.length if lane_dir > 0 else 0.0
	var rem := absf(end_s - lane_s)
	var look := maxf(4500.0, lane_speed * 6.0)
	if rem > look:
		junction = {}
		return
	var n := net.end_node(lane, lane_dir)
	var opts := junction_options(lane, lane_dir)
	var nb := opts.size()
	var pick := -1
	if nb > 0:
		pick = band_at(lane_offset.x * lane_dir, nb)
		if autopilot:
			var want := -1
			if ap_route.size() > 1:
				for i in nb:
					if opts[i]["track"] == ap_route[1]["track"] and opts[i]["dir"] == ap_route[1]["dir"]:
						want = i
			elif opts[nb - 1].get("stop", false):
				want = nb - 1
			if want >= 0:
				pick = want
	junction = {"node": n, "name": net.node_name(n), "kind": net.nodes[n]["kind"], "dist": rem, "options": opts, "pick": pick, "bands": nb}


func _lane_ride(delta: float) -> void:
	var inp := GameInput
	if autopilot and (inp.stick.length() > 0.35 or absf(inp.roll) > 0.5):
		set_autopilot(false, "Manual override: autopilot off")
	if autopilot and not ap_route.is_empty() and ap_route[0]["track"] == lane:
		var es: float = ap_route[0]["exit_s"]
		var endp: float = lane.length if lane_dir > 0 else 0.0
		ap_lane_exit_s = -1.0 if (ap_route.size() > 1 and absf(es - endp) < 5.0) else es
	var sp := lane.spec()
	var boosting: bool = inp.boost
	var steer: Vector2 = inp.stick
	var target_speed: float = sp["min"] + (sp["speed"] - sp["min"]) * inp.throttle + (sp["boost"] if boosting else 0.0)
	if autopilot:
		# a bit slower than a pilot flying flat out, and it eases off for the
		# sharp turns ahead; boost still works where it's safe
		var k := lane.max_curvature_ahead(lane_s, lane_dir, maxf(lane_speed * 2.5, 800.0))
		target_speed = minf(sp["ap"] + (sp["boost"] * 0.6 if boosting else 0.0), lane.safe_speed(k))
	if lane_speed > target_speed + 150.0:
		lane_speed = move_toward(lane_speed, target_speed, delta * maxf(2500.0, lane_speed * 0.9))   # braking
	else:
		lane_speed = lerpf(lane_speed, target_speed, 1.0 - exp(-delta * float(sp["accel"])))
	var s_prev := lane_s
	lane_s += lane_dir * lane_speed * delta

	# turns push you toward the outside wall
	var v_eff := minf(lane_speed, sp["speed"] + sp["boost"])
	var push := lane.drift(clampf(lane_s, 0.0, lane.length), v_eff)
	drift_push = push
	_update_junction()
	var steer_v: Vector2
	if autopilot:
		var want := Vector2(0, lane.radius * 0.3)
		var in_band: bool = not junction.is_empty() and junction["pick"] >= 0 and junction["bands"] > 1
		var ahead := lane.traffic_near(lane_s, lane_dir, lane_offset, maxf(500.0, lane_speed * 0.5))
		if in_band:
			# get into the lane for the branch we want, dodging traffic up or down
			want = Vector2(band_centre(junction["pick"], junction["bands"]) * lane_dir, lane.radius * 0.3)
			if not ahead.is_empty():
				want.y = -signf((ahead["offset"] as Vector2).y + 0.01) * lane.radius * 0.4
		elif not ahead.is_empty():
			want = Vector2(-(ahead["offset"] as Vector2).x, lane.radius * 0.35)
		steer_v = ((want - lane_offset) * 1.5 - push + lane_offset / lane.radius * float(sp["steer"]) * 0.55).limit_length(sp["steer"])
		steer = Vector2(steer_v.x * lane_dir, steer_v.y) / float(sp["steer"])
	else:
		# lane right flips when travelling backwards
		steer_v = Vector2(steer.x * lane_dir, steer.y) * float(sp["steer"])
	# the tube gently pulls you back toward the middle, harder near the wall,
	# so easy turns ride themselves and only sharp ones at speed need a hand
	var hold := Vector2.ZERO
	if not junction.is_empty() and junction["bands"] > 1:
		# near a junction it holds you in the middle of your lane instead,
		# so you slide across to pick a branch and it keeps you there
		var nb: int = junction["bands"]
		hold.x = band_centre(band_at(lane_offset.x * lane_dir, nb), nb) * lane_dir
	var centre := -(lane_offset - hold) / lane.radius * float(sp["steer"]) * 0.55
	lane_offset += (steer_v + push + centre) * delta

	if lane_offset.length() > lane.radius - 6.0:
		_thrown_off()
		return

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
		_update_junction()
		var pick: int = junction.get("pick", -1)
		if junction.is_empty() or pick < 0 or junction["options"][pick].get("stop", false):
			var where := net.node_name(net.end_node(lane, lane_dir))
			_leave_lane(false)
			if pick >= 0:
				GameState.message.emit("Off the %s at %s" % [lane_kind_word(), where], Color(0.5, 0.9, 1.0))
			else:
				GameState.message.emit("End of the %s: %s" % [lane_kind_word(), where], Color(0.5, 0.9, 1.0))
			return
		_switch_track(junction["options"][pick])
		return

	var f := lane.frame(lane_s)
	var fwd: Vector3 = f["fwd"] * lane_dir
	var pos: Vector3 = f["origin"] + f["right"] * lane_offset.x + f["up"] * lane_offset.y
	var want_b := Basis.looking_at(fwd, f["up"])
	_ride_basis = _ride_basis.slerp(want_b, 1.0 - exp(-delta * 9.0)).orthonormalized()
	# lean into the push of the turn
	var lean := Vector2(push.x * lane_dir, push.y) / float(sp["steer"])
	bank = lerpf(bank, -steer.x * 0.5 + lean.x * 0.35, 1.0 - exp(-delta * 4.0))
	model.rotation = Vector3(steer.y * 0.15, 0, bank)
	velocity = fwd * lane_speed
	speed = lane_speed
	global_transform = Transform3D(_ride_basis, pos)


var drift_push := Vector2.ZERO
var _ride_basis := Basis.IDENTITY


func lane_kind_word() -> String:
	return lane.kind if lane else "lane"


## Carry on through a junction onto another track.
func _switch_track(b: Dictionary) -> void:
	var end_s: float = lane.length if lane_dir > 0 else 0.0
	var wp := lane.lane_to_world(end_s, lane_offset)
	var old_kind := lane.kind
	lane = b["track"]
	lane_dir = b["dir"]
	lane_s = b["s"]
	var nf := lane.frame(lane_s)
	var rel: Vector3 = wp - nf["origin"]
	lane_offset = Vector2(rel.dot(nf["right"]), rel.dot(nf["up"])).limit_length(lane.radius * 0.55)
	junction = {}
	if autopilot and ap_route.size() > 1 and ap_route[1]["track"] == lane:
		ap_route.pop_front()
	world.sfx.play("lane_merge", -7.0)
	if old_kind != lane.kind:
		world.shake(0.5 if lane.kind == "road" else 0.3)
		GameState.message.emit(("Onto the HIGHWAY toward %s" if lane.kind == "highway" else "Off the highway: road to %s") % b["name"], Color(1.0, 0.85, 0.5) if lane.kind == "highway" else Color(0.5, 0.9, 1.0))
	elif not autopilot:
		GameState.message.emit("%s to %s" % [lane.kind.capitalize(), b["name"]], Color(0.5, 0.9, 1.0))


func _thrown_off() -> void:
	var word := lane_kind_word()
	lane_offset = lane_offset.limit_length(lane.radius - 6.0)
	var f := lane.frame(lane_s)
	global_transform = Transform3D(_ride_basis, f["origin"] + f["right"] * lane_offset.x + f["up"] * lane_offset.y)
	_leave_lane(false)
	_merge_cd = 3.0
	speed = top_speed() * 1.5
	velocity = -global_transform.basis.z * speed
	world.shake(1.2)
	world.sfx.play("hit_hull", -6.0)
	GameState.message.emit("Thrown off the %s! Hold the inside line in turns." % word, Color(1.0, 0.6, 0.35))


func exit_lane() -> void:
	if mode == Mode.LANE:
		_leave_lane(true)


func _leave_lane(announce: bool) -> void:
	mode = Mode.FLIGHT
	_merge_cd = 2.0
	ap_lane_exit_s = -1.0
	ap_route = []
	junction = {}
	drift_push = Vector2.ZERO
	speed = top_speed() * 0.9
	velocity = -global_transform.basis.z * speed
	ang_vel = Vector3.ZERO
	lane_changed.emit(false)
	if announce:
		var e := lane.nearest_entry(global_position)
		if not e.is_empty() and e["dist"] < 900.0:
			GameState.message.emit("Dropped out at %s" % e["name"], Color(0.5, 0.9, 1.0))
		else:
			GameState.message.emit("Dropped out of the %s" % lane.kind, Color(0.5, 0.9, 1.0))


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
