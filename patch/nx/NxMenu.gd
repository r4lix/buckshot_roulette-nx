extends CanvasLayer
# "Buckshot Roulette NX" menu, toggled with the Minus button (pauses the game). L/R switch tabs.
# GRAPHICS: 30 fps lock, 3D render scale (manual or dynamic), fps overlay.
# SOUND: one volume slider per audio bus.  CHEATS: shell reveal, item spawn, health and shell tweaks.
# Settings are saved to sdmc:/switch/buckshot_roulette/nx_settings.cfg.

const CFG_PATH := "sdmc:/switch/buckshot_roulette/nx_settings.cfg"
const SCALE_MIN := 0.5
const SCALE_MAX := 1.0
const SCALE_STEP := 0.05
const LSFG_OFF := "sdmc:/switch/buckshot_roulette/nx_lsfg_off" # frame generation is on unless this file exists
const LSFG_DLLS := ["sdmc:/switch/buckshot_roulette/Lossless.dll", "sdmc:/switch/pt/lsfg/Lossless.dll", "sdmc:/Lossless.dll"]

var lock30 := true
var rscale := 0.7
var dynamic := false # off by default: with frame generation the fixed 0.7 scale paces best (raising the scale costs the generated frames)
var sharpness := 0.5
var dyn_min := 0.8 # lowest 3D scale dynamic resolution may use (menu slider; 3D text gets blocky below ~0.8)
var overlay := false
var show_shells := false
var bus_volume := {} # bus name -> linear volume (only buses the user changed)
const ITEMS := ["handsaw", "magnifying glass", "beer", "cigarettes", "handcuffs", "expired medicine", "burner phone", "adrenaline", "inverter"]
var item_pick := 0
var game_speed := 1.0
var fg_on := false

var panel: PanelContainer
var tabs: TabContainer
var slider: HSlider
var lbl_scale: Label
var lbl_info: Label
var lbl_overlay: Label
var lbl_shells: Label
var lbl_cheat: Label
var first_focus := {} # tab index -> Control
var was_paused := false

# dynamic resolution state
var dyn_scale := 0.7
var miss_times: Array = []
var ok_time := 0.0
var cooldown := 0.0
var block_up_until := 0.0
var last_up_at := -100.0
var now := 0.0
var fps_acc := 0.0
var fps_frames := 0
var fps_value := 0.0
var ms_value := 0.0

func _ready():
	layer = 127
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	fg_on = !FileAccess.file_exists(LSFG_OFF)
	_build_ui()
	_apply_all()
	# Per-object fade (GeometryInstance3D.transparency) emulation for the OpenGL renderer; script lives in the patch pack.
	if ResourceLoader.exists("res://nx/NxCompat.gd"):
		var nc = load("res://nx/NxCompat.gd").new()
		nc.name = "NxCompat"
		add_child(nc)
# ---------------- settings ----------------
func _load():
	var c := ConfigFile.new()
	if c.load(CFG_PATH) == OK:
		lock30 = c.get_value("nx", "lock30", lock30)
		rscale = clamp(float(c.get_value("nx", "scale", rscale)), SCALE_MIN, SCALE_MAX)
		dynamic = c.get_value("nx", "dynamic", dynamic)
		overlay = c.get_value("nx", "overlay", overlay)
		sharpness = clamp(float(c.get_value("nx", "sharpness", sharpness)), 0.0, 1.0)
		dyn_min = clamp(float(c.get_value("nx", "dyn_min", dyn_min)), SCALE_MIN, SCALE_MAX)
		show_shells = c.get_value("nx", "show_shells", show_shells)
		bus_volume = c.get_value("nx", "bus_volume", {})
	dyn_scale = max(rscale, 0.9)

func _save():
	var c := ConfigFile.new()
	c.set_value("nx", "lock30", lock30)
	c.set_value("nx", "scale", rscale)
	c.set_value("nx", "dynamic", dynamic)
	c.set_value("nx", "overlay", overlay)
	c.set_value("nx", "sharpness", sharpness)
	c.set_value("nx", "dyn_min", dyn_min)
	c.set_value("nx", "show_shells", show_shells)
	c.set_value("nx", "bus_volume", bus_volume)
	var err := c.save(CFG_PATH)
	print("[nx menu] saved settings: ", err)
	return err

func _apply_all():
	ProjectSettings.set_setting("nx/sharpness", sharpness)
	_apply_lock()
	_set_scale(dyn_scale if dynamic else rscale)
	lbl_overlay.visible = overlay
	lbl_shells.visible = show_shells
	for bus in bus_volume:
		var i := AudioServer.get_bus_index(bus)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(max(float(bus_volume[bus]), 0.0001)))

func _apply_lock():
	ProjectSettings.set_setting("nx/swap_interval", 2 if lock30 else 1)
	if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	_reset_dynamic()

func _set_scale(s: float):
	var root := get_tree().root
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = s

# ---------------- UI helpers ----------------
func _check(parent: Control, text: String, on: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.toggled.connect(cb)
	parent.add_child(c)
	return c

func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _slider_row(parent: Control, label: Label, lo: float, hi: float, step: float, value: float, cb: Callable) -> HSlider:
	var h := HBoxContainer.new()
	label.custom_minimum_size = Vector2(250, 0)
	h.add_child(label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(220, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	s.value_changed.connect(cb)
	h.add_child(s)
	parent.add_child(h)
	return s

func _page(name: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = name
	v.add_theme_constant_override("separation", 6)
	tabs.add_child(v)
	return v

# ---------------- UI ----------------
func _build_ui():
	panel = PanelContainer.new()
	panel.position = Vector2(40, 30)
	panel.custom_minimum_size = Vector2(560, 0)
	panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.88)
	sb.border_color = Color(0.8, 0.8, 0.8)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var title := Label.new()
	title.text = "BUCKSHOT ROULETTE NX"
	title.add_theme_font_size_override("font_size", 22)
	v.add_child(title)

	tabs = TabContainer.new()
	tabs.focus_mode = Control.FOCUS_NONE
	tabs.custom_minimum_size = Vector2(640, 280) # fixed size: the panel was laid out wrong the first time it opened
	tabs.tab_changed.connect(func(_t): _focus_tab())
	v.add_child(tabs)

	# GRAPHICS
	var g := _page("GRAPHICS")
	first_focus[0] = _check(g, "Lock 30 fps", lock30, func(on): lock30 = on; _apply_lock())
	_check(g, "Dynamic resolution", dynamic, func(on):
		dynamic = on
		dyn_scale = rscale
		_reset_dynamic()
		_set_scale(dyn_scale if dynamic else rscale)
		_refresh())
	lbl_scale = Label.new()
	slider = _slider_row(g, lbl_scale, SCALE_MIN, SCALE_MAX, SCALE_STEP, rscale, func(val):
		rscale = val
		dyn_scale = val
		_reset_dynamic()
		_set_scale(rscale)
		_refresh())
	var lbl_min := Label.new()
	lbl_min.text = "Dynamic: lowest 3D scale %d%%" % round(dyn_min * 100)
	_slider_row(g, lbl_min, SCALE_MIN, SCALE_MAX, SCALE_STEP, dyn_min, func(val):
		dyn_min = val
		if dyn_scale < dyn_min:
			dyn_scale = dyn_min
			if dynamic:
				_set_scale(dyn_scale)
		lbl_min.text = "Dynamic: lowest 3D scale %d%%" % round(val * 100)
		_refresh())
	var lbl_sharp := Label.new()
	lbl_sharp.text = "Sharpening %d%%" % round(sharpness * 100)
	_slider_row(g, lbl_sharp, 0.0, 1.0, 0.1, sharpness, func(val):
		sharpness = val
		ProjectSettings.set_setting("nx/sharpness", val)
		lbl_sharp.text = "Sharpening %d%%" % round(val * 100))
	_check(g, "Show fps and resolution", overlay, func(on): overlay = on; lbl_overlay.visible = on)
	var has_dll := false
	for p in LSFG_DLLS:
		has_dll = has_dll or FileAccess.file_exists(p)
	var fg_text := "Frame generation (LSFG, 30 -> 60, restart)" if has_dll else "Frame generation (needs Lossless.dll on the SD card)"
	var fg_box := _check(g, fg_text, fg_on and has_dll, func(on):
		fg_on = on
		if on:
			DirAccess.remove_absolute(LSFG_OFF)
		else:
			var f := FileAccess.open(LSFG_OFF, FileAccess.WRITE)
			if f:
				f.store_string("1")
		lbl_info.text = "Restart the game to apply frame generation.")
	fg_box.disabled = !has_dll

	# SOUND: a slider per audio bus
	var s := _page("SOUND")
	for i in AudioServer.bus_count:
		var bus := AudioServer.get_bus_name(i)
		var lbl := Label.new()
		var vol := db_to_linear(AudioServer.get_bus_volume_db(i))
		lbl.text = "%s  %d%%" % [bus, round(vol * 100)]
		var sl := _slider_row(s, lbl, 0.0, 1.0, 0.05, clamp(vol, 0.0, 1.0), func(val):
			AudioServer.set_bus_volume_db(i, linear_to_db(max(val, 0.0001)))
			bus_volume[bus] = val
			lbl.text = "%s  %d%%" % [bus, round(val * 100)])
		if i == 0:
			first_focus[1] = sl
	var note := Label.new()
	note.text = "The game's own volume option also sets Master."
	note.modulate = Color(0.7, 0.7, 0.7)
	s.add_child(note)

	# CHEATS
	var c := _page("CHEATS")
	first_focus[2] = _check(c, "Show the shells in the shotgun", show_shells, func(on): show_shells = on; lbl_shells.visible = on)
	var lbl_item := Label.new()
	var item_slider := _slider_row(c, lbl_item, 0, ITEMS.size() - 1, 1, 0, func(val):
		item_pick = int(val)
		lbl_item.text = "Item: %s" % ITEMS[item_pick].capitalize())
	lbl_item.text = "Item: %s" % ITEMS[0].capitalize()
	item_slider.custom_minimum_size = Vector2(160, 24)
	var lbl_speed := Label.new()
	lbl_speed.text = "Game speed x%.1f" % game_speed
	_slider_row(c, lbl_speed, 1.0, 3.0, 0.5, game_speed, func(val):
		game_speed = val
		Engine.time_scale = val
		lbl_speed.text = "Game speed x%.1f" % val)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	c.add_child(grid)
	_button(grid, "Spawn the item on my side", func(): _cheat_spawn(ITEMS[item_pick], 1))
	_button(grid, "Fill my side with random items", func(): _cheat_spawn("", 8))
	_button(grid, "Restore my health", func(): _cheat_health(true))
	_button(grid, "Dealer down to 1 charge", func(): _cheat_health(false))
	_button(grid, "Make the next shell blank", func(): _cheat_next("blank"))
	_button(grid, "Make the next shell live", func(): _cheat_next("live"))
	_button(grid, "Make every shell live", func(): _cheat_all("live"))
	_button(grid, "Double damage (sawed-off)", func(): _cheat_saw())
	_button(grid, "Handcuff the dealer", func(): _cheat_cuff())
	lbl_cheat = Label.new()
	lbl_cheat.modulate = Color(0.75, 0.75, 0.75)
	c.add_child(lbl_cheat)

	# footer
	var foot := HBoxContainer.new()
	var save := Button.new()
	save.text = "Save settings"
	save.pressed.connect(func(): lbl_info.text = "Saved to SD card." if _save() == OK else "Could not save.")
	foot.add_child(save)
	lbl_info = Label.new()
	lbl_info.modulate = Color(0.75, 0.75, 0.75)
	foot.add_child(lbl_info)
	v.add_child(foot)

	lbl_overlay = Label.new()
	lbl_overlay.position = Vector2(8, 4)
	lbl_overlay.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_overlay.add_theme_constant_override("outline_size", 4)
	add_child(lbl_overlay)

	lbl_shells = Label.new()
	lbl_shells.position = Vector2(8, 24)
	lbl_shells.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_shells.add_theme_constant_override("outline_size", 4)
	add_child(lbl_shells)
	_refresh()

func _refresh():
	var sc: float = dyn_scale if dynamic else rscale
	var vp := get_tree().root.get_visible_rect().size
	lbl_scale.text = "3D scale %d%%  (%dx%d)%s" % [round(sc * 100), round(vp.x * sc), round(vp.y * sc), " auto" if dynamic else ""]
	slider.editable = !dynamic

func _relayout():
	panel.reset_size()

func _focus_tab():
	var f = first_focus.get(tabs.current_tab)
	if f:
		f.grab_focus()

func _toggle_menu():
	panel.visible = !panel.visible
	var tree := get_tree()
	if panel.visible:
		was_paused = tree.paused
		tree.paused = true
		_refresh()
		lbl_info.text = "D-pad: move   A: select   L/R: tab"
		panel.reset_size()
		_relayout.call_deferred()
		_focus_tab()
	else:
		tree.paused = was_paused
		var f := panel.get_viewport().gui_get_focus_owner()
		if f:
			f.release_focus()

func _input(event):
	if not (event is InputEventJoypadButton):
		return
	if event.button_index == JOY_BUTTON_BACK:
		if event.pressed:
			_toggle_menu()
		get_viewport().set_input_as_handled()
	elif panel.visible and event.pressed and (event.button_index == JOY_BUTTON_LEFT_SHOULDER or event.button_index == JOY_BUTTON_RIGHT_SHOULDER):
		var d := -1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1
		tabs.current_tab = (tabs.current_tab + d + tabs.get_tab_count()) % tabs.get_tab_count()
		get_viewport().set_input_as_handled()

# ---------------- cheats ----------------
func _find(n: Node, cls: String) -> Node:
	if n.get_script() and n.get_script().resource_path.get_file() == cls + ".gd":
		return n
	for ch in n.get_children():
		var r := _find(ch, cls)
		if r:
			return r
	return null

func _round_manager() -> Node:
	var scene := get_tree().current_scene
	return _find(scene, "RoundManager") if scene else null

func _cheat_health(player: bool):
	var rm := _round_manager()
	if rm == null or rm.roundArray.is_empty():
		lbl_cheat.text = "Only works at the table."
		return
	if player:
		rm.health_player = rm.roundArray[rm.currentRound].startingHealth
	else:
		rm.health_opponent = 1
	rm.healthCounter.UpdateDisplay()
	lbl_cheat.text = "Health: you %d, dealer %d." % [rm.health_player, rm.health_opponent]

func _cheat_next(kind: String):
	var rm := _round_manager()
	if rm == null or rm.shellSpawner.sequenceArray.is_empty():
		lbl_cheat.text = "No shell in the shotgun."
		return
	rm.shellSpawner.sequenceArray[0] = kind
	lbl_cheat.text = "Next shell is now %s." % kind

func _cheat_saw():
	var rm := _round_manager()
	if rm == null:
		lbl_cheat.text = "Only works at the table."
		return
	rm.barrelSawedOff = true
	rm.currentShotgunDamage = 2
	lbl_cheat.text = "Next shot does 2 damage."

func _cheat_cuff():
	var rm := _round_manager()
	if rm == null or rm.dealerAI == null:
		lbl_cheat.text = "Only works at the table."
		return
	if rm.dealerCuffed:
		lbl_cheat.text = "The dealer is already cuffed."
		return
	rm.animator_dealerHands.play("dealer get handcuffed")
	rm.dealerCuffed = true
	rm.dealerAI.dealerAboutToBreakFree = false
	lbl_cheat.text = "Dealer cuffed: he skips his next turn."

func _cheat_all(kind: String):
	var rm := _round_manager()
	if rm == null or rm.shellSpawner.sequenceArray.is_empty():
		lbl_cheat.text = "No shell in the shotgun."
		return
	for i in rm.shellSpawner.sequenceArray.size():
		rm.shellSpawner.sequenceArray[i] = kind
	lbl_cheat.text = "All %d shells are now %s." % [rm.shellSpawner.sequenceArray.size(), kind]

# Puts an item straight onto a free slot of the player's grid, the way ItemManager.GrabItem + PlaceDownItem do.
func _cheat_spawn(item: String, count: int):
	var rm := _round_manager()
	var im = rm.itemManager if rm else null
	if im == null or im.instanceArray.is_empty():
		lbl_cheat.text = "Only works at the table."
		return
	var placed := 0
	for n in count:
		var slot := -1
		for g in im.gridOccupiedArray.size():
			if !im.gridOccupiedArray[g]:
				slot = g
				break
		if slot < 0:
			break
		var iname: String = item if item != "" else ITEMS[randi() % ITEMS.size()]
		var res = null
		for r in im.instanceArray:
			if r.itemName == iname:
				res = r
				break
		if res == null:
			lbl_cheat.text = "Unknown item: %s" % iname
			return
		var inst: Node3D = res.instance.instantiate()
		im.itemSpawnParent.add_child(inst)
		var indicator = inst.get_child(0)
		var interaction = inst.get_child(1)
		im.items_dynamicIndicatorArray.append(indicator)
		im.items_dynamicInteractionArray.append(interaction)
		indicator.locationInDynamicArray = im.items_dynamicIndicatorArray.size() - 1
		for a in im.amounts.array_amounts:
			if a.itemName == iname:
				a.amount_player += 1
				break
		im.numberOfOccupiedGrids += 1
		im.gridOccupiedArray[slot] = true
		if iname == "cigarettes":
			im.numberOfCigs_player += 1
		inst.transform.origin = im.gridParentArray[slot].transform.origin + res.pos_offset
		inst.rotation_degrees = im.gridParentArray[slot].rotation_degrees + res.rot_offset
		interaction.isPlayerSide = true
		indicator.dealerGridIndex = slot + 8
		interaction.itemGridIndex = slot
		for ch in inst.get_children():
			if ch is StaticBody3D:
				ch.get_child(0).disabled = false
		placed += 1
	lbl_cheat.text = ("Placed %d item(s)." % placed) if placed > 0 else "No free slot on your side."

func _update_shells():
	var rm := _round_manager()
	if rm == null or rm.shellSpawner.sequenceArray.is_empty():
		lbl_shells.text = ""
		return
	var seq: Array = rm.shellSpawner.sequenceArray
	var parts := []
	for i in seq.size():
		var t: String = "LIVE" if seq[i] == "live" else "blank"
		parts.append("[%s]" % t if i == 0 else t)
	lbl_shells.text = "Shells: " + "  ".join(parts)

# ---------------- dynamic resolution + overlay ----------------
func _reset_dynamic():
	miss_times.clear()
	ok_time = 0.0
	cooldown = 1.0
	block_up_until = 0.0
	last_up_at = -100.0

func _process(delta):
	now += delta
	fps_acc += delta
	fps_frames += 1
	if fps_acc >= 0.5:
		fps_value = fps_frames / fps_acc
		ms_value = fps_acc * 1000.0 / fps_frames
		fps_acc = 0.0
		fps_frames = 0
		if overlay:
			var sc: float = dyn_scale if dynamic else rscale
			var vp := get_tree().root.get_visible_rect().size
			lbl_overlay.text = "%.0f fps  %.1f ms  3D %dx%d%s" % [fps_value, ms_value, round(vp.x * sc), round(vp.y * sc), " auto" if dynamic else ""]
		if show_shells:
			_update_shells()
		_log_slow()
	if now - delta < 10.0 and now >= 10.0 and FileAccess.file_exists("sdmc:/switch/buckshot_roulette/nx_menu_open"):
		_toggle_menu() # test aid: open the menu once, 10 s after start
	if !dynamic or get_tree().paused:
		return
	# Frame generation paces the game at 30 like the lock does.
	var target := 1.0 / 30.0 if (lock30 or fg_on) else 1.0 / 60.0
	cooldown -= delta
	if delta > target * 1.25:
		miss_times.append(now)
		ok_time = 0.0
		# A miss right after stepping up: go back and stop trying for a while.
		if now - last_up_at < 2.0:
			_step(-1)
			block_up_until = now + 20.0
			last_up_at = -100.0
			return
	else:
		ok_time += delta
	while miss_times.size() > 0 and now - miss_times[0] > 2.0:
		miss_times.pop_front()
	if cooldown <= 0.0 and miss_times.size() >= 3:
		_step(-1)
		miss_times.clear()
	elif cooldown <= 0.0 and ok_time > 6.0 and now > block_up_until and dyn_scale < SCALE_MAX:
		_step(1)
		last_up_at = now
		ok_time = 0.0

# Logs where the game runs slowly (camera and position), to find the heavy scenes. At most every 2 s.
var slow_logged_at := -100.0
func _log_slow():
	var tree := get_tree()
	if tree.paused or fps_value >= 27.0 or now - slow_logged_at < 2.0 or now < 15.0:
		return
	slow_logged_at = now
	var cam := tree.root.get_camera_3d()
	var sc: float = dyn_scale if dynamic else rscale
	var scene = tree.current_scene
	print("[nx slow] fps=%.1f ms=%.1f scale=%.2f scene=%s cam=%s pos=%s rot=%s draws=%d objs=%d prims=%dk" % [fps_value, ms_value, sc,
		scene.name if scene else "?", String(cam.get_path()) if cam else "none",
		str(cam.global_position.snapped(Vector3(0.1, 0.1, 0.1))) if cam else "", str(cam.global_rotation_degrees.snapped(Vector3(1, 1, 1))) if cam else "",
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000])

func _step(dir: int):
	var sc: float = clamp(dyn_scale + dir * SCALE_STEP, dyn_min, SCALE_MAX)
	if sc == dyn_scale:
		return
	dyn_scale = sc
	_set_scale(sc)
	cooldown = 1.0
	print("[nx menu] dynamic 3D scale -> %.2f" % sc)
	if panel.visible:
		_refresh()
