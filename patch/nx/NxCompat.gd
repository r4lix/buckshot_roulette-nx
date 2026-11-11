extends Node
# Godot 4.1's Compatibility (OpenGL) renderer ignores GeometryInstance3D.transparency (the per-object fade).
# The game fades the blood splatter plane and the "DEALER"/"YOU" shot texts with it, so on Switch they never fade.
# This maps the property onto something OpenGL does honour: Label3D.modulate alpha, or the alpha of the node's
# StandardMaterial3D material_override (switched to alpha blending while faded).

var tracked: Array = [] # [node, last_transparency, base_alpha, base_transparency_mode]
# Lights: the game animates some lights' energy to 0 between effects (muzzle flash, masks, zippo...). In the OpenGL
# renderer a visible light costs per-pixel shading even at energy 0, so those are hidden while dark (same picture).
var lights: Array = [] # Light3D nodes
var stat_t := 0.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_scan.call_deferred(get_tree().root)

func _scan(n: Node):
	_on_node_added(n)
	for c in n.get_children():
		_scan(c)

func _on_node_added(n: Node):
	var sc = n.get_script()
	if sc and sc.resource_path == "res://scripts/MenuManager.gd":
		_hide_multiplayer.call_deferred(n)
	if n is Light3D and !n.has_meta("nx_light"):
		n.set_meta("nx_light", true)
		lights.append(n)
	if n.has_meta("nx_fade"):
		return
	if n is Label3D:
		n.set_meta("nx_fade", true)
		tracked.append([n, -1.0, n.modulate.a, 0])
	elif n is GeometryInstance3D and n.material_override is StandardMaterial3D:
		n.set_meta("nx_fade", true)
		var m: StandardMaterial3D = n.material_override
		tracked.append([n, -1.0, m.albedo_color.a, m.transparency])

# Multiplayer needs Steam, which the Switch does not have. The game would only show "no connection" (after clearing the
# save file), and loading its lobby scene crashes on Switch, so the menu entry is hidden.
func _hide_multiplayer(menu: Node):
	if !is_instance_valid(menu) or !("buttons" in menu) or menu.buttons.size() <= 22 or menu.buttons[22] == null:
		return
	var b = menu.buttons[22]
	var ctl = b.get_parent()
	if ctl is CanvasItem:
		ctl.visible = false
	if b.ui is CanvasItem:
		b.ui.visible = false
	print("[nx] multiplayer menu entry hidden (", ctl.get_path() if ctl else "?", ")")

func _process(delta):
	_lights(delta)
	var i := 0
	while i < tracked.size():
		var e = tracked[i]
		var n = e[0]
		if !is_instance_valid(n):
			tracked.remove_at(i)
			continue
		var t: float = n.transparency
		if t != e[1]:
			e[1] = t
			_apply(n, t, e)
		i += 1

func _apply(n, t: float, e):
	var a: float = clamp(1.0 - t, 0.0, 1.0)
	if n is Label3D:
		var c: Color = n.modulate
		c.a = e[2] * a
		n.modulate = c
		var oc: Color = n.outline_modulate
		oc.a = a
		n.outline_modulate = oc
		return
	var m = n.material_override
	if !(m is StandardMaterial3D):
		return
	# Switch to alpha blending once and keep it (changing it back and forth would recompile the shader).
	if t > 0.0 and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var col: Color = m.albedo_color
	col.a = e[2] * a
	m.albedo_color = col

func _lights(delta):
	var shown := 0
	var hidden_dark := 0
	var i := 0
	while i < lights.size():
		var l = lights[i]
		if !is_instance_valid(l):
			lights.remove_at(i)
			continue
		i += 1
		var dark: bool = l.light_energy <= 0.001 or l.light_color.v <= 0.001
		if l.has_meta("nx_dark"):
			if !dark:
				l.remove_meta("nx_dark")
				l.visible = true
			else:
				if l.visible:
					l.visible = false # the game switched it back on while still dark
				hidden_dark += 1
		elif dark and l.visible:
			l.set_meta("nx_dark", true)
			l.visible = false
			hidden_dark += 1
		if l.is_visible_in_tree():
			shown += 1
	stat_t += delta
	if stat_t >= 10.0:
		stat_t = 0.0
		print("[nx lights] visible %d, hidden while dark %d, total %d" % [shown, hidden_dark, lights.size()])
