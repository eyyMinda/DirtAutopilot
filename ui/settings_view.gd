extends VBoxContainer
## Built from Settings.SCHEMA with plain Controls, so it takes the look of
## wherever it's placed (the game's Options menu or DirtLoader's popup).

const Settings := preload("../core/settings.gd")
const Icons := preload("icons.gd")
const Hats := preload("../features/hats.gd")
const StatsView := preload("stats_view.gd")
const AchievementsView := preload("achievements_view.gd")

const NEXUS_URL := "https://www.nexusmods.com/profile/eyyMinda"
const GITHUB_URL := "https://github.com/eyyMinda"
const NEXUS_COLOR := Color("da8e35")

const INDENT := 28
const DESC_ALPHA := 0.6
const DESC_SCALE := 0.8
const RESET_CONFIRM_SEC := 3.0

var mod
var s

var _rows: Dictionary = {}
var _desc_labels: Array[Label] = []
var _stats_view: StatsView
var _achievements_view: AchievementsView
var _reset_btn: Button
var _update_btn: Button
var _reset_armed_until := 0
var _rebinding := ""
var _refresh_t := 0.0


func setup(mod_main) -> void:
	mod = mod_main
	s = mod_main.settings
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for e in Settings.SCHEMA:
		if e.has("section"):
			_add_section(e.section)
		elif e.has("view"):
			call("_add_view_" + e.view)
		elif e.get("hotkey", false):
			_add_hotkey(e)
		elif e.default is bool:
			_add_switch(e)
		elif e.default is String:
			_add_choice(e)

	s.changed.connect(_on_changed)
	visibility_changed.connect(_cancel_rebind)
	_refresh_all()


func _ready() -> void:
	# The theme's font size is only known once the view is in the tree.
	var size := int(get_theme_font_size("font_size", "Label") * DESC_SCALE)
	for l in _desc_labels:
		l.add_theme_font_size_override("font_size", size)


func _process(delta: float) -> void:
	if !is_visible_in_tree():
		return
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 0.5
		_refresh_live()


func _add_section(title: String) -> void:
	_add_gap(10)
	var l := Label.new()
	l.text = title.to_upper()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	add_child(HSeparator.new())


func _add_gap(height: int) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	add_child(gap)


func _block(e: Dictionary) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 0)
	if e.has("requires"):
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", INDENT)
		m.add_child(block)
		add_child(m)
	else:
		add_child(block)
	return block


func _add_desc(block: Control, text: String) -> void:
	if text.is_empty():
		return
	block.add_child(_faint_label(text))


func _faint_label(text: String, center := false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.modulate = Color(1, 1, 1, DESC_ALPHA)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_labels.append(l)
	return l


func _button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_pressed)
	return b


func _add_switch(e: Dictionary) -> void:
	var block := _block(e)
	var b := CheckButton.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.toggled.connect(func(on: bool): s.set_value(e.key, on))
	block.add_child(b)
	_add_desc(block, e.get("desc", ""))
	_rows[e.key] = {"control": b, "block": block.get_parent() if e.has("requires") else block}


func _add_choice(e: Dictionary) -> void:
	var block := _block(e)
	var row := HBoxContainer.new()
	var l := Label.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hat: Dictionary = Hats.HATS[e.hat]
	l.text = "%s (%s)" % [hat.name, hat.effect]
	var options: Array = Hats.options(e.hat)
	row.add_child(l)
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(150, 0)
	ob.focus_mode = Control.FOCUS_NONE
	for o in options:
		ob.add_item(o[1])
		ob.set_item_metadata(ob.item_count - 1, o[0])
	ob.item_selected.connect(func(i: int): s.set_value(e.key, ob.get_item_metadata(i)))
	row.add_child(ob)
	block.add_child(row)
	_add_desc(block, e.get("desc", ""))
	_rows[e.key] = {"control": ob, "block": block.get_parent() if e.has("requires") else block}


func _add_hotkey(e: Dictionary) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = e.label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var b := _button("", _start_rebind.bind(e.key))
	b.custom_minimum_size = Vector2(120, 0)
	row.add_child(b)
	add_child(row)
	_rows[e.key] = {"control": b, "block": row}


func _add_view_title() -> void:
	var title := Label.new()
	title.text = "DIRT AUTOPILOT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	if !mod.version.is_empty():
		add_child(_faint_label("v" + mod.version, true))
	_update_btn = _button("", _open_update)
	_update_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_update_btn.icon = Icons.texture(Icons.GITHUB, Color.WHITE, 20)
	_update_btn.visible = false
	add_child(_update_btn)


func _add_view_enable_all() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.add_child(_button("Enable all", s.set_all_features.bind(true)))
	row.add_child(_button("Disable all", s.set_all_features.bind(false)))
	add_child(row)


func _add_view_stats() -> void:
	_stats_view = StatsView.new()
	_stats_view.setup(mod.stats, _on_reset_stats)
	add_child(_stats_view)


func _add_view_achievements() -> void:
	_achievements_view = AchievementsView.new()
	_achievements_view.setup(mod.achievements, s)
	add_child(_achievements_view)


func _add_view_hotkey_help() -> void:
	add_child(_faint_label("Click a key to change it. Backspace removes it."))


func _add_view_reset() -> void:
	_reset_btn = _button("Reset all settings", _on_reset_pressed)
	_reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_reset_btn)


func _add_view_credits() -> void:
	_add_gap(16)
	add_child(HSeparator.new())
	var made := Label.new()
	made.text = "Made by eyyMinda"
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(made)
	add_child(_faint_label("If you like Dirt Autopilot, you'll find my other mods and tools here:", true))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.add_child(_link_button("Nexus Mods", Icons.NEXUSMODS, NEXUS_COLOR, NEXUS_URL))
	row.add_child(_link_button("GitHub", Icons.GITHUB, Color.WHITE, GITHUB_URL))
	add_child(row)


func _link_button(text: String, icon_path: String, color: Color, url: String) -> Button:
	var b := _button(text, OS.shell_open.bind(url))
	b.icon = Icons.texture(icon_path, color, 20)
	b.tooltip_text = url
	return b


func _on_changed(_key: String) -> void:
	_refresh_all()


func _refresh_all() -> void:
	for key in _rows:
		var e: Dictionary = s.entry(key)
		var r: Dictionary = _rows[key]
		var v = s.get_value(key)
		if e.get("hotkey", false):
			if key != _rebinding:
				r.control.text = Settings.key_name(v)
		elif e.default is bool:
			r.control.set_pressed_no_signal(v)
			r.control.text = _switch_label(e)
		elif e.default is String:
			var ob: OptionButton = r.control
			ob.select(0)
			for i in ob.item_count:
				if ob.get_item_metadata(i) == v:
					ob.select(i)
		if e.has("requires"):
			var on: bool = s.get_value(e.requires)
			r.block.modulate.a = 1.0 if on else 0.45
			r.control.disabled = !on
	_refresh_live()


func _switch_label(e: Dictionary) -> String:
	var hk: String = e.get("hotkey_of", "")
	if hk.is_empty() or s.get_value(hk) == KEY_NONE:
		return e.label
	return "%s  [%s]" % [e.label, Settings.key_name(s.get_value(hk))]


func _refresh_live() -> void:
	if _stats_view:
		_stats_view.refresh()
	if _achievements_view:
		_achievements_view.refresh()
	if _update_btn and !mod.updates.latest_version.is_empty():
		_update_btn.text = "Update to v%s" % mod.updates.latest_version
		_update_btn.tooltip_text = mod.updates.latest_url
		_update_btn.visible = true
	if _reset_btn and _reset_armed_until > 0 and Time.get_ticks_msec() > _reset_armed_until:
		_reset_armed_until = 0
		_reset_btn.text = "Reset all settings"


func _open_update() -> void:
	OS.shell_open(mod.updates.latest_url)


func _on_reset_stats() -> void:
	mod.stats.reset()
	_refresh_live()


## Needs a second click within RESET_CONFIRM_SEC.
func _on_reset_pressed() -> void:
	if _reset_armed_until > 0 and Time.get_ticks_msec() <= _reset_armed_until:
		_reset_armed_until = 0
		_reset_btn.text = "Reset all settings"
		s.reset()
	else:
		_reset_armed_until = Time.get_ticks_msec() + int(RESET_CONFIRM_SEC * 1000.0)
		_reset_btn.text = "Click again to reset"


func _start_rebind(key: String) -> void:
	_cancel_rebind()
	_rebinding = key
	mod.rebinding = true
	_rows[key].control.text = "Press a key…"


func _cancel_rebind() -> void:
	if _rebinding.is_empty():
		return
	var key := _rebinding
	_rebinding = ""
	mod.rebinding = false
	_rows[key].control.text = Settings.key_name(s.get_value(key))


func _input(event: InputEvent) -> void:
	if _rebinding.is_empty():
		return
	var k := event as InputEventKey
	if k == null or !k.pressed or k.echo:
		return
	get_viewport().set_input_as_handled()
	var key := _rebinding
	if k.keycode == KEY_ESCAPE:
		_cancel_rebind()
		return
	_rebinding = ""
	mod.rebinding = false
	if k.keycode == KEY_BACKSPACE or k.keycode == KEY_DELETE:
		s.set_value(key, KEY_NONE)
	else:
		# A key can only be bound to one action.
		for other in s.hotkey_keys():
			if other != key and s.get_value(other) == k.keycode:
				s.set_value(other, KEY_NONE)
		s.set_value(key, int(k.keycode))
	_refresh_all()
