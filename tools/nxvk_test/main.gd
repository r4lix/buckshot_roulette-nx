extends Node
# nxvk + Godot smoke test: adds render features in stages and logs each one,
# so a GPU hang names the stage that caused it.

var stage := -1
var frames := 0
var t := 0.0
var label := Label.new()
var cam := Camera3D.new()
var cube := MeshInstance3D.new()
var sun := DirectionalLight3D.new()
var omni := OmniLight3D.new()
var env := WorldEnvironment.new()

const STAGES = ["2d only", "3d unshaded cube", "3d lit cube + sun", "sun shadow", "omni light + shadow", "environment glow+fog", "msaa 2x", "done"]

func _ready():
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.3)
	bg.size = Vector2(4000, 4000)
	var layer := CanvasLayer.new()
	layer.layer = -1
	layer.add_child(bg)
	add_child(layer)
	var top := CanvasLayer.new()
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 32)
	top.add_child(label)
	add_child(top)
	_next()

func _next():
	stage += 1
	frames = 0
	t = 0.0
	print("[nxtest] stage %d: %s" % [stage, STAGES[stage]])
	match stage:
		1:
			cam.position = Vector3(0, 1, 3)
			add_child(cam)
			cam.look_at(Vector3.ZERO)
			var m := BoxMesh.new()
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color.ORANGE
			m.material = mat
			cube.mesh = m
			add_child(cube)
			var floor := MeshInstance3D.new()
			floor.mesh = PlaneMesh.new()
			floor.mesh.size = Vector2(6, 6)
			floor.position.y = -0.5
			add_child(floor)
		2:
			cube.mesh.material = StandardMaterial3D.new()
			cube.mesh.material.albedo_color = Color.ORANGE
			sun.rotation_degrees = Vector3(-50, 30, 0)
			add_child(sun)
		3:
			sun.shadow_enabled = true
		4:
			omni.position = Vector3(1, 1, 1)
			omni.omni_range = 4
			omni.shadow_enabled = true
			add_child(omni)
		5:
			var e := Environment.new()
			e.glow_enabled = true
			e.fog_enabled = true
			env.environment = e
			add_child(env)
		6:
			get_viewport().msaa_3d = Viewport.MSAA_2X

func _process(delta):
	cube.rotate_y(delta)
	frames += 1
	t += delta
	label.text = "nxvk test - stage %d: %s\nfps %.0f" % [stage, STAGES[stage], Engine.get_frames_per_second()]
	if t > 4.0 and stage < STAGES.size() - 1:
		print("[nxtest] stage %d ok: %d frames in %.1fs" % [stage, frames, t])
		_next()
