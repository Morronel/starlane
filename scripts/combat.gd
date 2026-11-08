class_name Combat
extends Node3D
## Pooled laser bolts, hit detection and explosions.

const TEAM_PLAYER := 0
const TEAM_ENEMY := 1
const PLAYER_BOLT_SPEED := 950.0
const ENEMY_BOLT_SPEED := 620.0

var bolts: Array = []   # {node, pos, vel, life, dmg, team}
var pool: Array = []
var bolt_mesh := {}
var world: Node


func _ready() -> void:
	for team in [TEAM_PLAYER, TEAM_ENEMY]:
		var m := CapsuleMesh.new()
		m.radius = 0.35
		m.height = 9.0
		m.radial_segments = 6
		m.rings = 2
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.5, 2.2, 3.0) if team == TEAM_PLAYER else Color(3.0, 0.6, 0.3)
		m.material = mat
		bolt_mesh[team] = m


func fire(origin: Vector3, vel: Vector3, dmg: float, team: int) -> void:
	var node: MeshInstance3D
	if pool.is_empty():
		node = MeshInstance3D.new()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	else:
		node = pool.pop_back()
		node.visible = true
	node.mesh = bolt_mesh[team]
	node.global_transform = Transform3D(Basis.looking_at(vel.normalized(), _up(vel)) * Basis(Vector3.RIGHT, PI / 2.0), origin)
	bolts.append({"node": node, "pos": origin, "vel": vel, "life": 1.8, "dmg": dmg, "team": team})
	world.sfx_laser(team, origin)


func _up(v: Vector3) -> Vector3:
	return Vector3.UP if absf(v.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT


func _physics_process(delta: float) -> void:
	var player: Node3D = world.player
	var enemies := get_tree().get_nodes_in_group("enemies")
	var i := bolts.size() - 1
	while i >= 0:
		var b: Dictionary = bolts[i]
		var from: Vector3 = b["pos"]
		var to: Vector3 = from + b["vel"] * delta
		var hit := false
		if b["team"] == TEAM_PLAYER:
			for e in enemies:
				if _seg_hit(from, to, e.global_position, e.hit_radius):
					e.take_damage(b["dmg"])
					spark(to, Color(0.5, 2.0, 3.0))
					hit = true
					break
		elif player and (player.mode == PlayerShip.Mode.FLIGHT or player.mode == PlayerShip.Mode.LANE):
			if _seg_hit(from, to, player.global_position, 4.5):
				player.take_damage(b["dmg"])
				spark(to, Color(3.0, 0.8, 0.4))
				hit = true
		b["life"] -= delta
		if hit or b["life"] <= 0.0:
			var n: MeshInstance3D = b["node"]
			n.visible = false
			pool.append(n)
			bolts.remove_at(i)
		else:
			b["pos"] = to
			(b["node"] as Node3D).global_position = to
		i -= 1


static func _seg_hit(a: Vector3, b: Vector3, c: Vector3, r: float) -> bool:
	var ab := b - a
	var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return (a + ab * t).distance_squared_to(c) < r * r


func spark(pos: Vector3, color: Color) -> void:
	_burst(pos, color, 10, 0.35, 40.0, 0.6)


func explosion(pos: Vector3, scale_f := 1.0) -> void:
	_burst(pos, Color(3.0, 1.4, 0.5), 48, 1.3, 70.0 * scale_f, 2.6 * scale_f)
	_burst(pos, Color(1.2, 1.2, 1.4), 20, 2.2, 25.0 * scale_f, 1.6 * scale_f)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 12.0
	light.omni_range = 120.0 * scale_f
	add_child(light)
	light.global_position = pos
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.8)
	tw.tween_callback(light.queue_free)
	world.sfx_boom(pos)


func _burst(pos: Vector3, color: Color, amount: int, life: float, vel: float, size: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector3(0, 0, 1)
	p.spread = 180.0
	p.initial_velocity_min = vel * 0.3
	p.initial_velocity_max = vel
	p.gravity = Vector3.ZERO
	p.damping_min = vel * 0.4
	p.damping_max = vel * 0.8
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = color
	mat.albedo_texture = _soft_dot()
	q.material = mat
	p.mesh = q
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


static var _dot_tex: Texture2D


static func _soft_dot() -> Texture2D:
	if _dot_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_dot_tex = t
	return _dot_tex
