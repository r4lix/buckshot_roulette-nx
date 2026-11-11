extends Node
# Switch render debug, driven by words in sdmc:/switch/buckshot_roulette/nx_debug.txt.
# Static strips (applied to every node as it enters the tree):
#   unshaded nolight noshadow nomesh nomat noenv nomsaa nocanvasmat no3d nofog noglow
# Profiler: "prof" cycles A/B configs in the "main" (table) scene, 8 s each, and logs
#   [nx prof] <config> fps=.. ms=.. worst=..
var flags := {}
var prof_wait := 20.0 # seconds in the main scene before the profiler starts ("profwait=N")

func _enter_tree():
	process_mode = Node.PROCESS_MODE_ALWAYS
	var f := FileAccess.open("sdmc:/switch/buckshot_roulette/nx_debug.txt", FileAccess.READ)
	if f == null:
		return
	for w in f.get_as_text().split(" ", false):
		var word := w.strip_edges()
		if word.begins_with("profwait="):
			prof_wait = float(word.substr(9))
			word = "prof"
		flags[word] = true
	print("[nx debug] flags: ", flags.keys())
	if flags.has("profscale"):
		flags["prof"] = true
		CONFIGS = CONFIGS_SCALE
	if flags.is_empty():
		return
	get_tree().node_added.connect(_fix)
	var vp := get_tree().root
	if flags.has("unshaded"):
		vp.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	if flags.has("nomsaa"):
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED

func _fix(n: Node):
	if n is Viewport:
		if flags.has("unshaded"):
			n.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
		if flags.has("nomsaa"):
			n.msaa_3d = Viewport.MSAA_DISABLED
	if n is Light3D:
		if flags.has("nolight"):
			n.visible = false
		if flags.has("noshadow"):
			n.shadow_enabled = false
	if n is GeometryInstance3D:
		if flags.has("nomesh") or flags.has("no3d"):
			n.visible = false
		if flags.has("nomat"):
			n.material_override = StandardMaterial3D.new()
	if n is WorldEnvironment and n.environment:
		if flags.has("noenv"):
			n.environment = null
		else:
			if flags.has("nofog"):
				n.environment.fog_enabled = false
				n.environment.volumetric_fog_enabled = false
			if flags.has("noglow"):
				n.environment.glow_enabled = false
	if n is CanvasItem and flags.has("nocanvasmat") and n.material is ShaderMaterial:
		n.material = null
	if flags.has("nofullscreen2d") and n is TextureRect:
		_hide_if_fullscreen.call_deferred(n)

# test: hide full-screen 2D texture overlays (vignettes...) to see whether a seam comes from them
func _hide_if_fullscreen(n):
	if is_instance_valid(n) and n.size.x >= 900 and n.size.y >= 500:
		print("[nx debug] hiding full-screen TextureRect ", n.get_path(), " ", n.texture.resource_path if n.texture else "")
		n.visible = false

# ---------------- profiler ----------------
const CONFIGS_FULL = ["base", "halfres", "base", "noretro", "noenv", "nolight", "unshaded", "halfmesh", "noshadow", "base"]
# "profscale": A/B of 3D render scales in one run (same camera), base = whatever override.cfg sets.
const CONFIGS_SCALE = ["s1.0", "s0.9", "s0.8", "s0.7", "s1.0", "s0.8", "s0.9", "s0.7", "s1.0"]
var CONFIGS: Array = CONFIGS_FULL
const SETTLE := 2.0
const MEASURE := 6.0
var p_idx := -1
var p_t := 0.0
var p_frames := 0
var p_sum := 0.0
var p_worst := 0.0
var p_undo: Array = []
var p_wait := 0.0

func _process(delta):
	if !flags.has("prof"):
		return
	var scene = get_tree().current_scene
	if scene == null or (scene.name != "main" and !flags.has("profany")):
		return
	if p_idx < 0:
		p_wait += delta
		if p_wait < (5.0 if flags.has("profany") else prof_wait): # let the intro finish
			return
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED) # uncapped frame times
		Engine.max_fps = 0
		_start(0)
		return
	if p_idx >= CONFIGS.size():
		return
	p_t += delta
	if p_t < SETTLE:
		return
	p_frames += 1
	p_sum += delta
	p_worst = max(p_worst, delta)
	if p_t >= SETTLE + MEASURE:
		print("[nx prof] %-9s fps=%.1f ms=%.1f worst=%.0f draws=%d prims=%dk" % [CONFIGS[p_idx], p_frames / p_sum, p_sum * 1000.0 / p_frames, p_worst * 1000.0,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000])
		_revert()
		_start(p_idx + 1)

func _start(i):
	p_idx = i
	p_t = 0.0
	p_frames = 0
	p_sum = 0.0
	p_worst = 0.0
	if i >= CONFIGS.size():
		print("[nx prof] done")
		return
	var root := get_tree().root
	if CONFIGS[i].begins_with("s"):
		_pset(root, "scaling_3d_scale", float(CONFIGS[i].substr(1)))
	match CONFIGS[i]:
		"halfres":
			_pset(root, "content_scale_size", root.content_scale_size / 2)
		"unshaded":
			_pset(root, "debug_draw", Viewport.DEBUG_DRAW_UNSHADED)
	var k := 0
	for n in _all(root):
		match CONFIGS[i]:
			"noretro":
				if n is CanvasItem and n.material is ShaderMaterial and n.visible:
					_pset(n, "visible", false)
			"noshadow":
				if n is Light3D and n.shadow_enabled:
					_pset(n, "shadow_enabled", false)
			"nolight":
				if n is Light3D and n.visible:
					_pset(n, "visible", false)
			"noenv":
				if n is WorldEnvironment and n.environment:
					_pset(n, "environment", null)
			"halfmesh":
				if n is GeometryInstance3D and n.visible:
					k += 1
					if k % 2 == 0:
						_pset(n, "visible", false)

func _pset(o: Object, prop: String, v):
	p_undo.append([o, prop, o.get(prop)])
	o.set(prop, v)

func _revert():
	for u in p_undo:
		if is_instance_valid(u[0]):
			u[0].set(u[1], u[2])
	p_undo.clear()

func _all(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out
