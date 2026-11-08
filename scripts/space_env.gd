class_name SpaceEnv
extends Node3D
## Procedural backdrop: baked nebula panorama, 3D starfield, gas giant, sun,
## lighting, glow/bloom and the speed dust around the camera.

const SKY_DIST := 80000.0

var sun_dir := Vector3(-0.45, 0.25, -0.85).normalized()   # direction TOWARDS the sun
var camera: Camera3D
var sky_root: Node3D
var dust_mat: ShaderMaterial
var env: Environment


var nebula_mat: ShaderMaterial
var nebula_vp: SubViewport
var sun_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var system_root: Node3D   # planet + sun, rebuilt per system
var sky_data := {}


func setup(cam: Camera3D) -> void:
	camera = cam
	_make_environment()
	_make_light()
	sky_root = Node3D.new()
	sky_root.name = "SkyRoot"
	add_child(sky_root)
	_make_stars()
	_make_dust()


## Re-skin the backdrop for a star system (see Galaxy.SYSTEMS[*].sky).
func apply_system(sky: Dictionary) -> void:
	sky_data = sky
	sun_dir = (sky["sun"] as Vector3).normalized()
	nebula_mat.set_shader_parameter("col_a", Vector3(sky["a"].r, sky["a"].g, sky["a"].b))
	nebula_mat.set_shader_parameter("col_b", Vector3(sky["b"].r, sky["b"].g, sky["b"].b))
	nebula_mat.set_shader_parameter("col_c", Vector3(sky["c"].r, sky["c"].g, sky["c"].b))
	nebula_mat.set_shader_parameter("plane_normal", sky["plane"])
	nebula_mat.set_shader_parameter("seed", sky["seed"])
	nebula_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	sun_light.light_color = sky["sun_col"]
	sun_light.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.y) < 0.95 else Vector3.RIGHT)
	fill_light.light_color = (sky["b"] as Color).lerp(Color(0.5, 0.5, 0.8), 0.5)
	fill_light.look_at_from_position(Vector3.ZERO, sun_dir + Vector3(0, -0.6, 0), Vector3.UP)
	if system_root:
		system_root.queue_free()
	system_root = Node3D.new()
	sky_root.add_child(system_root)
	_make_planet()
	_make_sun()


func _process(_delta: float) -> void:
	if camera and sky_root:
		sky_root.global_position = camera.global_position


func set_dust_velocity(v: Vector3) -> void:
	if dust_mat:
		dust_mat.set_shader_parameter("velocity", v)


func _make_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = _bake_nebula()
	pano.energy_multiplier = 0.75
	sky.sky_material = pano
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.31, 0.38)
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.4)
	env.set_glow_level(5, 0.2)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _bake_nebula() -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(2048, 1024)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.use_hdr_2d = true
	var rect := ColorRect.new()
	rect.size = Vector2(2048, 1024)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/nebula_pano.gdshader")
	rect.material = mat
	nebula_mat = mat
	nebula_vp = vp
	vp.add_child(rect)
	add_child(vp)
	return vp.get_texture()


func _make_light() -> void:
	var sun := DirectionalLight3D.new()
	sun_light = sun
	sun.light_color = Color(1.0, 0.92, 0.82)
	sun.light_energy = 1.45
	sun.shadow_enabled = false
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP)
	# cool rim/fill from the nebula side
	var fill := DirectionalLight3D.new()
	fill_light = fill
	fill.light_color = Color(0.45, 0.4, 0.9)
	fill.light_energy = 0.22
	fill.light_specular = 0.2
	add_child(fill)
	fill.look_at_from_position(Vector3.ZERO, sun_dir + Vector3(0, -0.6, 0), Vector3.UP)


func _make_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	mm.mesh = quad
	var count := 2600
	mm.instance_count = count
	var plane_n := Vector3(0.25, 1.0, 0.35).normalized()
	for i in count:
		var d := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		# bias some stars towards the galactic band
		if rng.randf() < 0.45:
			d = (d - plane_n * d.dot(plane_n) * rng.randf_range(0.7, 1.0)).normalized()
		var mag := pow(rng.randf(), 6.0)
		var size := SKY_DIST * (0.0011 + mag * 0.0035)
		var t := Transform3D(Basis().scaled(Vector3.ONE * size), d * SKY_DIST)
		mm.set_instance_transform(i, t)
		var temp := rng.randf()
		var col := Color(0.7, 0.8, 1.0) if temp < 0.35 else (Color(1.0, 0.85, 0.65) if temp > 0.8 else Color(1, 1, 1))
		var bright := 0.35 + mag * 6.0
		col.a = bright
		mm.set_instance_color(i, col)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/stars.gdshader")
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3.ONE * -SKY_DIST * 1.1, Vector3.ONE * SKY_DIST * 2.2)
	sky_root.add_child(mmi)


func _make_planet() -> void:
	var dir: Vector3 = (sky_data["planet_dir"] as Vector3).normalized()
	var dist := SKY_DIST * 0.6
	var radius: float = dist * float(sky_data["planet_size"])
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 96
	sphere.rings = 48
	var planet := MeshInstance3D.new()
	planet.mesh = sphere
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/planet.gdshader")
	mat.set_shader_parameter("sun_dir", sun_dir)
	for k in ["p1", "p2", "p3"]:
		var c: Color = sky_data[k]
		mat.set_shader_parameter("c" + k.substr(1), Vector3(c.r, c.g, c.b))
	planet.material_override = mat
	planet.position = dir * dist
	planet.rotation = Vector3(0.35, 0.0, 0.25)
	planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	system_root.add_child(planet)

	var atmo_mesh := SphereMesh.new()
	atmo_mesh.radius = radius * 1.06
	atmo_mesh.height = radius * 2.12
	atmo_mesh.radial_segments = 96
	atmo_mesh.rings = 48
	var atmo := MeshInstance3D.new()
	atmo.mesh = atmo_mesh
	var am := ShaderMaterial.new()
	am.shader = load("res://shaders/atmosphere.gdshader")
	am.set_shader_parameter("sun_dir", sun_dir)
	var pc: Color = (sky_data["p3"] as Color).lerp(sky_data["sun_col"], 0.5)
	am.set_shader_parameter("tint", Vector3(pc.r, pc.g, pc.b))
	atmo.material_override = am
	atmo.position = planet.position
	atmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	system_root.add_child(atmo)

	if not sky_data["rings"]:
		return
	# thin ring system
	var ring := MeshBuilder.new()
	ring.xform = Transform3D(Basis(Vector3(1, 0, 0.3).normalized(), 0.35), Vector3.ZERO)
	var steps := 128
	for i in steps:
		var a0 := TAU * i / steps
		var a1 := TAU * (i + 1) / steps
		for band in [[1.35, 1.55, 0.55], [1.6, 1.95, 0.85], [2.0, 2.1, 0.35]]:
			var r0: float = radius * band[0]
			var r1: float = radius * band[1]
			var c: Color = (sky_data["p1"] as Color).lerp(Color(0.8, 0.75, 0.7), 0.4) * float(band[2])
			ring.quad("glow", Vector3(cos(a0) * r0, 0, sin(a0) * r0), Vector3(cos(a1) * r0, 0, sin(a1) * r0),
				Vector3(cos(a1) * r1, 0, sin(a1) * r1), Vector3(cos(a0) * r1, 0, sin(a0) * r1), c, Vector3(0, -1, 0))
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.vertex_color_use_as_albedo = true
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rm.albedo_color = Color(0.45, 0.4, 0.36, 0.35)
	var rmi := MeshInstance3D.new()
	rmi.mesh = ring.build({"glow": rm})
	rmi.position = planet.position
	rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	system_root.add_child(rmi)


func _make_sun() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/sun.gdshader")
	var sc: Color = sky_data["sun_col"]
	mat.set_shader_parameter("color", Vector3(sc.r, sc.g, sc.b))
	mi.material_override = mat
	mi.position = sun_dir * SKY_DIST * 0.9
	mi.scale = Vector3.ONE * SKY_DIST * 0.22
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	system_root.add_child(mi)


func _make_dust() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	mm.mesh = quad
	mm.instance_count = 400
	for i in 400:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(rng.randf(), rng.randf(), rng.randf()) * 240.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	dust_mat = ShaderMaterial.new()
	dust_mat.shader = load("res://shaders/dust.gdshader")
	mmi.material_override = dust_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 16384.0
	add_child(mmi)
