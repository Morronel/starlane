class_name Loot
extends Node3D
## A floating canister of salvage. The tractor pulls it in when the ship is close.

var world: Node
var parts := {}            # part id -> count
var blueprint := ""        # blueprint id or ""
var credits := 0
var life := 120.0
var drifting := false      # salvage drifts stay until collected
var _spin := Vector3.ZERO
var _vel := Vector3.ZERO

static var _mesh: Mesh


func setup(w: Node, pos: Vector3, contents: Dictionary, drift := false) -> void:
	world = w
	parts = contents.get("parts", {})
	blueprint = contents.get("blueprint", "")
	credits = contents.get("credits", 0)
	drifting = drift
	add_to_group("loot")
	if _mesh == null:
		var mb := MeshBuilder.new()
		mb.box("hull", Vector3.ZERO, Vector3(2.4, 2.4, 3.2), Color(0.55, 0.58, 0.62))
		for z in [-1.0, 1.0]:
			mb.box("glow", Vector3(0, 0, z * 1.0), Vector3(2.6, 2.6, 0.3), Color(0.4, 1.0, 0.6))
		mb.box("hull", Vector3(0, 1.25, 0), Vector3(0.8, 0.2, 2.0), Color(0.3, 0.32, 0.36))
		_mesh = mb.build(MeshBuilder.default_materials())
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	if blueprint != "":
		mi.scale = Vector3.ONE * 1.4
	add_child(mi)
	if not drift:
		# battle drops get a little light so they pop; field salvage relies on its glow strips
		var light := OmniLight3D.new()
		light.light_color = Color(0.9, 0.6, 1.0) if blueprint != "" else Color(0.4, 1.0, 0.6)
		light.light_energy = 1.2
		light.omni_range = 30.0
		add_child(light)
	global_position = pos
	_spin = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.8
	_vel = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 8.0


func _physics_process(delta: float) -> void:
	rotate_x(_spin.x * delta)
	rotate_y(_spin.y * delta)
	if not drifting:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
	var p: PlayerShip = world.player
	if p.mode != PlayerShip.Mode.FLIGHT and p.mode != PlayerShip.Mode.DOCKING:
		global_position += _vel * delta
		return
	var to := p.global_position - global_position
	var d := to.length()
	var rng := GameState.tractor_range()
	if d < rng:
		var pull := lerpf(260.0, 60.0, d / rng)
		_vel = _vel.lerp(to.normalized() * pull + p.velocity, 1.0 - exp(-delta * 4.0))
	else:
		_vel = _vel.lerp(Vector3.ZERO, 1.0 - exp(-delta * 0.5))
	global_position += _vel * delta
	if d < 10.0 * p.cam_scale:
		_collect()


func _collect() -> void:
	var bonus := GameState.salvage_bonus()
	if bonus > 0:
		parts["scrap"] = parts.get("scrap", 0) + bonus
	GameState.add_parts(parts)
	var bits := []
	for k in parts:
		bits.append("+%d %s" % [parts[k], Items.PARTS[k]["name"]])
	if credits > 0:
		GameState.credits += credits
		bits.append("+%d cr" % credits)
	world.sfx.play("loot_pickup", -4.0, randf_range(0.97, 1.05))
	if blueprint != "" and not GameState.blueprints.has(blueprint):
		GameState.blueprints[blueprint] = true
		GameState.message.emit("BLUEPRINT FOUND: %s! Assemble it in a station workshop." % Items.blueprint_name(blueprint), Color(0.85, 0.6, 1.0))
		world.sfx.play("mission_complete", -6.0)
	if not bits.is_empty():
		GameState.message.emit("Salvage: " + ", ".join(bits), Color(0.5, 1.0, 0.65))
	queue_free()


## Random contents for a destroyed raider.
static func raider_drop(elite: bool, rng: RandomNumberGenerator) -> Dictionary:
	var p := {"scrap": rng.randi_range(2, 4) if elite else rng.randi_range(1, 3)}
	if rng.randf() < (0.8 if elite else 0.45):
		p["circuit"] = rng.randi_range(1, 2)
	if rng.randf() < (0.6 if elite else 0.22):
		p["coil"] = 1
	if rng.randf() < (0.25 if elite else 0.08):
		p["crystal"] = 1
	if elite and rng.randf() < 0.45:
		p["void"] = 1
	var out := {"parts": p}
	if elite and rng.randf() < 0.35:
		out["blueprint"] = GameState.unknown_blueprint(rng)
	return out


static func salvage_drop(rng: RandomNumberGenerator) -> Dictionary:
	var p := {"scrap": rng.randi_range(1, 3)}
	if rng.randf() < 0.4:
		p["crystal"] = 1
	if rng.randf() < 0.3:
		p["circuit"] = 1
	if rng.randf() < 0.04:
		p["void"] = 1
	return {"parts": p}
