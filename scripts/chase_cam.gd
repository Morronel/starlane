class_name ChaseCam
extends Camera3D
## Smooth chase camera with speed-based FOV and screen shake.

var target: PlayerShip
var shake_amt := 0.0
var orbit := 0.0   # slow orbit used while docked
var smooth_basis := Basis.IDENTITY


func _ready() -> void:
	near = 0.3
	far = 100000.0
	fov = 70.0
	process_physics_priority = 10


func shake(a: float) -> void:
	shake_amt = maxf(shake_amt, a)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var t := target.global_transform
	var in_lane := target.mode == PlayerShip.Mode.LANE
	if target.mode == PlayerShip.Mode.DOCKED or target.mode == PlayerShip.Mode.DEAD:
		var look_at_pt := target.global_position
		var desired_pos := global_position
		if target.mode == PlayerShip.Mode.DOCKED:
			orbit += delta * 0.12
			var c := target.dock_station.global_transform * Vector3(0, 0, 10)
			desired_pos = c + Vector3(cos(orbit), 0.35, sin(orbit)) * 420.0
			look_at_pt = c
		global_position = global_position.lerp(desired_pos, 1.0 - exp(-delta * 2.0))
		var want_d := Transform3D().looking_at(look_at_pt - global_position, Vector3.UP).basis
		global_basis = global_basis.slerp(want_d.orthonormalized(), 1.0 - exp(-delta * 3.0)).orthonormalized()
		smooth_basis = global_basis
		return
	# Rotational lag only: the camera orbits the ship with a smoothed basis, so it
	# never falls behind at lane speeds but still swings nicely in turns.
	var k := 7.0 if not in_lane else 5.0
	smooth_basis = smooth_basis.slerp(t.basis.orthonormalized(), 1.0 - exp(-delta * k)).orthonormalized()
	var pull := clampf(target.speed / target.top_speed(), 0.0, 3.0)
	var offset := Vector3(0, 3.4, 13.5 + pull * 1.5) if not in_lane else Vector3(0, 4.2, 17.0)
	global_position = t.origin + smooth_basis * offset
	var look_at_pt2 := t.origin + smooth_basis * Vector3(0, 1.2, 0) + t.basis * Vector3(0, 0, -40.0)
	global_basis = Transform3D().looking_at(look_at_pt2 - global_position, smooth_basis.y).basis

	var spd_ratio := clampf(target.speed / target.top_speed(), 0.0, 6.0)
	var want_fov := 68.0 + minf(spd_ratio, 2.2) * 6.0 + (10.0 if in_lane else 0.0)
	fov = lerpf(fov, want_fov, 1.0 - exp(-delta * 2.5))

	if shake_amt > 0.001:
		h_offset = randf_range(-1, 1) * shake_amt * 0.6
		v_offset = randf_range(-1, 1) * shake_amt * 0.6
		shake_amt = maxf(0.0, shake_amt - delta * 2.0)
	else:
		h_offset = 0.0
		v_offset = 0.0
	# subtle constant rumble in the lane
	if in_lane:
		h_offset += randf_range(-1, 1) * 0.05
		v_offset += randf_range(-1, 1) * 0.05


func snap() -> void:
	if target:
		smooth_basis = target.global_transform.basis.orthonormalized()
		global_transform = target.global_transform * Transform3D(Basis(), Vector3(0, 3.4, 13.5))
