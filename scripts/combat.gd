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
var missiles: Array = []  # {node, pos, dir, speed, max_speed, turn, target, dmg, life, team}
var _missile_mesh: Mesh
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


func _bolt_mesh_for(col: Color) -> Mesh:
	var key := col.to_html()
	if not bolt_mesh.has(key):
		var m := CapsuleMesh.new()
		m.radius = 0.4
		m.height = 10.0
		m.radial_segments = 6
		m.rings = 2
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = col
		m.material = mat
		bolt_mesh[key] = m
	return bolt_mesh[key]


func fire(origin: Vector3, vel: Vector3, dmg: float, team: int, col = null, life := 1.8, sound := true) -> void:
	var node: MeshInstance3D
	if pool.is_empty():
		node = MeshInstance3D.new()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	else:
		node = pool.pop_back()
		node.visible = true
	node.mesh = bolt_mesh[team] if col == null else _bolt_mesh_for(col)
	node.global_transform = Transform3D(Basis.looking_at(vel.normalized(), _up(vel)) * Basis(Vector3.RIGHT, PI / 2.0), origin)
	bolts.append({"node": node, "pos": origin, "vel": vel, "life": life, "dmg": dmg, "team": team, "col": col})
	if sound:
		world.sfx_laser(team, origin)


# --- missiles ------------------------------------------------------------------

func fire_missile(origin: Vector3, dir: Vector3, inherit: Vector3, target: Node3D, spec: Dictionary, team: int) -> void:
	if target == null or not is_instance_valid(target):
		target = _missile_target(origin, dir)
	if _missile_mesh == null:
		var mb := MeshBuilder.new()
		mb.cyl("hull", Vector3(0, 0, -1.4), Vector3(0, 0, 1.2), 0.22, 0.28, 6, Color(0.8, 0.82, 0.86))
		mb.box("glow", Vector3(0, 0, -1.5), Vector3(0.3, 0.3, 0.3), Color(1.0, 0.4, 0.2))
		for k in 4:
			var a := TAU * k / 4.0
			mb.box("hull", Vector3(cos(a) * 0.35, sin(a) * 0.35, 1.0), Vector3(0.05 + absf(cos(a)) * 0.4, 0.05 + absf(sin(a)) * 0.4, 0.5), Color(0.5, 0.5, 0.55))
		_missile_mesh = mb.build(MeshBuilder.default_materials())
	var node := MeshInstance3D.new()
	node.mesh = _missile_mesh
	node.scale = Vector3.ONE * (1.6 if spec["dmg"] > 100.0 else 1.0)
	add_child(node)
	var trail := CPUParticles3D.new()
	trail.amount = 40
	trail.lifetime = 0.6
	trail.local_coords = false
	trail.direction = Vector3(0, 0, 1)
	trail.spread = 8.0
	trail.initial_velocity_min = 2.0
	trail.initial_velocity_max = 6.0
	trail.gravity = Vector3.ZERO
	trail.scale_amount_min = 1.2
	trail.scale_amount_max = 2.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	trail.scale_amount_curve = curve
	var q := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(2.2, 1.1, 0.5)
	mat.albedo_texture = _soft_dot()
	q.material = mat
	trail.mesh = q
	trail.position = Vector3(0, 0, 1.4)
	node.add_child(trail)
	node.global_transform = Transform3D(Basis.looking_at(dir, _up(dir)), origin)
	missiles.append({"node": node, "pos": origin, "dir": dir, "speed": inherit.length() * 0.6 + 80.0, "max_speed": spec["speed"],
		"turn": spec["turn"], "target": target, "dmg": spec["dmg"], "life": 7.0, "team": team, "arm": 0.25})


func _missile_target(origin: Vector3, dir: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: Vector3 = e.global_position - origin
		if d.length() < 3000.0 and d.normalized().dot(dir) > 0.6 and d.length() < best_d:
			best_d = d.length()
			best = e
	return best


func _update_missiles(delta: float) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var i := missiles.size() - 1
	while i >= 0:
		var m: Dictionary = missiles[i]
		m["life"] -= delta
		m["arm"] -= delta
		m["speed"] = move_toward(m["speed"], m["max_speed"], delta * 500.0)
		var tv = m["target"]
		if not is_instance_valid(tv) or (tv is Node and not (tv as Node).is_in_group("enemies")):
			tv = _missile_target(m["pos"], m["dir"])
			m["target"] = tv
		var t: Node3D = tv if is_instance_valid(tv) else null
		if t != null and m["arm"] <= 0.0:
			var want: Vector3 = (world.lead_point(m["pos"], t, m["speed"]) - m["pos"]).normalized()
			var ang: float = (m["dir"] as Vector3).angle_to(want)
			if ang > 0.0001:
				m["dir"] = (m["dir"] as Vector3).slerp(want, minf(1.0, m["turn"] * delta / ang)).normalized()
		var from: Vector3 = m["pos"]
		var to: Vector3 = from + m["dir"] * m["speed"] * delta
		var hit: Node3D = null
		for e in enemies:
			if _seg_hit(from, to, e.global_position, e.hit_radius + 4.0):
				hit = e
				break
		if hit != null or m["life"] <= 0.0:
			if hit != null:
				hit.take_damage(m["dmg"])
			explosion(to, 0.7 if m["dmg"] < 100.0 else 1.2)
			(m["node"] as Node3D).queue_free()
			missiles.remove_at(i)
		else:
			m["pos"] = to
			var n: Node3D = m["node"]
			n.global_transform = Transform3D(Basis.looking_at(m["dir"], _up(m["dir"])).scaled(n.scale), to)
		i -= 1


func clear_all() -> void:
	for b in bolts:
		b["node"].visible = false
		pool.append(b["node"])
	bolts.clear()
	for m in missiles:
		(m["node"] as Node3D).queue_free()
	missiles.clear()


func _up(v: Vector3) -> Vector3:
	return Vector3.UP if absf(v.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT


func _physics_process(delta: float) -> void:
	_update_missiles(delta)
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
					spark(to, b["col"] if b["col"] != null else Color(0.5, 2.0, 3.0))
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
	world.sfx_boom(pos, scale_f > 1.2)


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
