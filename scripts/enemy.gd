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
var kind := "raider"       # 0.15: raider, scout, brawler, sniper, bomber, ace, drone
var dmg := 5.0
var fire_min := 0.55
var fire_max := 1.0
var fire_range := 900.0
var bolt_speed := 0.0      # 0 = Combat.ENEMY_BOLT_SPEED
var keep_away := 140.0

const KINDS := {
	"scout": {"hp": 35.0, "speed": 140.0, "turn": 2.0, "bounty": 140, "scale": 0.8, "dmg": 3.0, "cd": [0.3, 0.5], "tint": Color(1.0, 0.85, 0.4)},
	"brawler": {"hp": 140.0, "speed": 82.0, "turn": 1.1, "bounty": 320, "scale": 1.5, "dmg": 9.0, "cd": [0.6, 1.0], "tint": Color(0.75, 0.55, 0.45)},
	"sniper": {"hp": 60.0, "speed": 95.0, "turn": 1.4, "bounty": 260, "scale": 1.0, "dmg": 15.0, "cd": [1.6, 2.2], "range": 1700.0, "bolt": 1.6, "keep": 650.0, "tint": Color(0.5, 0.75, 1.0)},
	"bomber": {"hp": 95.0, "speed": 85.0, "turn": 1.0, "bounty": 340, "scale": 1.3, "dmg": 20.0, "cd": [2.2, 2.8], "bolt": 0.55, "tint": Color(0.85, 0.5, 1.0)},
	"ace": {"hp": 190.0, "speed": 132.0, "turn": 2.3, "bounty": 900, "scale": 1.3, "dmg": 8.0, "cd": [0.3, 0.5], "tint": Color(1.0, 0.85, 0.3)},
	"drone": {"hp": 18.0, "speed": 150.0, "turn": 2.6, "bounty": 60, "scale": 0.5, "dmg": 2.0, "cd": [0.25, 0.4], "tint": Color(0.5, 1.0, 0.8)},
}


## Pick an enemy type for a system's threat level.
static func random_kind(threat: int) -> String:
	var pool := ["raider", "raider", "scout", "drone"]
	if threat >= 2:
		pool += ["brawler", "sniper", "raider"]
	if threat >= 3:
		pool += ["bomber", "brawler", "sniper"]
	return pool[randi() % pool.size()]


func setup(w: Node, pos: Vector3, is_elite := false, k := "raider") -> void:
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
		dmg = 7.0
		fire_min = 0.35
		fire_max = 0.7
	kind = k
	if KINDS.has(k):
		var d: Dictionary = KINDS[k]
		hp = d["hp"]
		max_hp = hp
		speed = d["speed"]
		turn_rate = d["turn"]
		bounty = d["bounty"]
		model.scale = Vector3.ONE * float(d["scale"])
		hit_radius = 7.0 * float(d["scale"])
		dmg = d["dmg"]
		fire_min = d["cd"][0]
		fire_max = d["cd"][1]
		fire_range = d.get("range", 900.0)
		bolt_speed = Combat.ENEMY_BOLT_SPEED * float(d.get("bolt", 1.0))
		keep_away = d.get("keep", 140.0)
		var hi := (model.mesh as ArrayMesh).surface_find_by_name("hull")
		if hi >= 0:
			var m: StandardMaterial3D = MeshBuilder.hull_material().duplicate()
			m.albedo_color = d["tint"]
			model.set_surface_override_material(hi, m)
		if k == "ace":
			elite = true
	global_position = pos
	patrol_target = _random_patrol()


func _random_patrol() -> Vector3:
	return home + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 0.4), rng.randf_range(-1, 1)) * 600.0


func take_damage(d: float) -> void:
	if hp <= 0.0:
		return
	hp -= d
	aggro = true
	if kind == "ace" and state == State.ATTACK and rng.randf() < 0.25:
		state = State.BREAK
		state_t = 0.0
		break_dir = (global_transform.basis.x * (1.0 if rng.randf() < 0.5 else -1.0) + global_transform.basis.y * 0.5).normalized()
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
			if dist < keep_away or state_t > 9.0:
				state = State.BREAK
				state_t = 0.0
				var side := global_transform.basis.x * (1.0 if rng.randf() < 0.5 else -1.0)
				break_dir = (side + global_transform.basis.y * rng.randf_range(-0.6, 0.6) - to_p.normalized() * 0.4).normalized()
			# fire when roughly lined up
			var fwd := -global_transform.basis.z
			if dist < fire_range and fwd.dot(desired) > 0.97 and fire_cd <= 0.0:
				fire_cd = rng.randf_range(fire_min, fire_max)
				var spread := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * (0.008 if kind == "sniper" else 0.02)
				var bs := bolt_speed if bolt_speed > 0.0 else Combat.ENEMY_BOLT_SPEED
				world.combat.fire(global_position + fwd * 6.0, (fwd + spread).normalized() * bs + velocity, dmg, Combat.TEAM_ENEMY)
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
