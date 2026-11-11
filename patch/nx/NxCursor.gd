extends CanvasLayer
# Switch: draws the mouse cursor (there is no hardware cursor). The display server passes
# the game's custom cursor image and the mouse mode through ProjectSettings ("nx/cursor*").

var sprite := Sprite2D.new()
var fallback: Texture2D

func _ready():
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	sprite.centered = false
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			if x <= y and x + y < 24:
				img.set_pixel(x, y, Color.BLACK if (x == 0 or x == y or x + y == 23) else Color.WHITE)
	fallback = ImageTexture.create_from_image(img)
	add_child(sprite)

var _acc := 0.0
var _frames := 0
var _worst := 0.0

func _process(_delta):
	# Perf readout in godot_log.txt every 5 s.
	_acc += _delta
	_frames += 1
	_worst = max(_worst, _delta)
	if _acc >= 5.0:
		var scene = get_tree().current_scene
		print("[nx perf] fps=%.1f worst=%.0fms draws=%d objs=%d prims=%dk scene=%s" % [_frames / _acc, _worst * 1000.0,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
			scene.name if scene else "?"])
		_acc = 0.0
		_frames = 0
		_worst = 0.0
	var vis: bool = ProjectSettings.get_setting("nx/cursor_visible", true)
	sprite.visible = vis
	if !vis:
		return
	var tex = ProjectSettings.get_setting("nx/cursor", null)
	var hot: Vector2 = ProjectSettings.get_setting("nx/cursor_hotspot", Vector2.ZERO)
	if tex is Texture2D:
		sprite.texture = tex
	else:
		sprite.texture = fallback
		hot = Vector2.ZERO
	# Window pixels -> canvas coordinates (the game uses a stretched viewport).
	var vp := get_viewport()
	var xf := vp.get_final_transform()
	var p := xf.affine_inverse() * Vector2(DisplayServer.mouse_get_position())
	sprite.scale = Vector2.ONE / xf.get_scale()
	sprite.position = p - hot * sprite.scale
