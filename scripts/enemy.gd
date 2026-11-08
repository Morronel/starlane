class_name Raider
extends Node3D
## Pirate fighter: attack runs, break-offs and strafing.

var world: Node
var hp := 55.0
var max_hp := 55.0
var hit_radius := 7.0
var speed := 95.0
var turn_rate := 1.5
var bounty := 180
var home := Vector3.ZERO
var aggro := false

enum State { PATROL, ATTACK, BREAK }
var state := State.PATROL
var state_t := 0.0
var fire_cd := 0.0
var patrol_target := Vector3.ZERO
var break_dir := Vector3.ZERO
var rng := RandomNumberGenerator.new()
var velocity := Vector3.ZERO
var model: MeshInstance3D
var elite := false


func setup(w: Node, pos: Vector3, is_elite := false) -> void:
	world = w
	home = pos
	elite = is_elite
	rng.randomize()
	add_to_group("enemies")
	model = MeshInstance3D.new()
	model.mesh = Models.raider_ship()
	add_child(model)
	if elite:
		hp = 110.0
		max_hp = 110.0
		speed = 110.0
		turn_rate = 1.8
		bounty = 400
		model.scale = Vector3.ONE * 1.35
		hit_radius = 9.0
	global_position = pos
	patrol_target = _random_patrol()


func _random_patrol() -> Vector3:
	return home + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 0.4), rng.randf_range(-1, 1)) * 600.0


func take_damage(d: float) -> void:
	if hp <= 0.0:
		return
	hp -= d
	aggro = true
	if state == State.PATROL:
		state = State.ATTACK
	if hp <= 0.0:
		remove_from_group("enemies")
		world.combat.explosion(global_position, 1.3 if elite else 1.0)
		world.spawn_loot(global_position, Loot.raider_drop(elite, rng))
		GameState.on_enemy_killed(bounty)
		queue_free()


## True while this raider is actively fighting the player (drives combat music).
func engaged() -> bool:
	return state != State.PATROL


func _physics_process(delta: float) -> void:
	var player: PlayerShip = world.player
	var player_ok := player.mode == PlayerShip.Mode.FLIGHT
	var to_p := player.global_position - global_position
	var dist := to_p.length()
	state_t += delta
	fire_cd -= delta

	if not player_ok:
		if state != State.PATROL:
			state = State.PATROL
			patrol_target = _random_patrol()
	elif dist < 1600.0 or aggro:
		if state == State.PATROL:
			state = State.ATTACK
			state_t = 0.0

	var desired := -global_transform.basis.z
	var spd := speed
	match state:
		State.PATROL:
			var d := patrol_target - global_position
			if d.length() < 80.0:
				patrol_target = _random_patrol()
			desired = d.normalized()
			spd = speed * 0.6
		State.ATTACK:
			var lead: Vector3 = world.lead_point(global_position, player, Combat.ENEMY_BOLT_SPEED)
			desired = (lead - global_position).normalized()
			if dist < 140.0 or state_t > 9.0:
				state = State.BREAK
				state_t = 0.0
				var side := global_transform.basis.x * (1.0 if rng.randf() < 0.5 else -1.0)
				break_dir = (side + global_transform.basis.y * rng.randf_range(-0.6, 0.6) - to_p.normalized() * 0.4).normalized()
			# fire when roughly lined up
			var fwd := -global_transform.basis.z
			if dist < 900.0 and fwd.dot(desired) > 0.97 and fire_cd <= 0.0:
				fire_cd = rng.randf_range(0.35, 0.7) if elite else rng.randf_range(0.55, 1.0)
				var spread := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.02
				var dmg := 7.0 if elite else 5.0
				world.combat.fire(global_position + fwd * 6.0, (fwd + spread).normalized() * Combat.ENEMY_BOLT_SPEED + velocity, dmg, Combat.TEAM_ENEMY)
		State.BREAK:
			desired = break_dir
			spd = speed * 1.35
			if state_t > rng.randf_range(2.2, 3.5) and dist > 350.0:
				state = State.ATTACK
				state_t = 0.0

	# never fly too far from home
	if global_position.distance_to(home) > 2500.0 and state == State.PATROL:
		desired = (home - global_position).normalized()

	# turn towards desired heading with limited rate
	var cur := -global_transform.basis.z
	var angle := cur.angle_to(desired)
	if angle > 0.001:
		var axis := cur.cross(desired)
		if axis.length_squared() < 1e-6:
			axis = global_transform.basis.y
		var step := minf(angle, turn_rate * delta)
		var nb := Basis(axis.normalized(), step) * global_transform.basis
		# bank into the turn
		var roll_target := clampf(-global_transform.basis.x.dot(desired) * 2.0, -1.0, 1.0)
		model.rotation.z = lerpf(model.rotation.z, roll_target * 0.9, delta * 3.0)
		global_transform.basis = nb.orthonormalized()
	velocity = velocity.lerp(-global_transform.basis.z * spd, 1.0 - exp(-delta * 2.0))
	global_position += velocity * delta
