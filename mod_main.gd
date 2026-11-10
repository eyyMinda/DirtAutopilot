extends Node
## Dirt Autopilot entry point.
##
## Loader-agnostic on purpose: no Mod Loader classes or APIs and no fixed folder
## name. Scripts are preloaded relative to this file, so the mod works from
## res://mods-unpacked/ (Godot Mod Loader), <game>/mods/ (DirtLoader) or a zip.

const Settings := preload("core/settings.gd")
const SessionStats := preload("core/session_stats.gd")
const Sweeper := preload("features/sweeper.gd")
const Automations := preload("features/automations.gd")
const Progress := preload("features/progress.gd")
const Achievements := preload("features/achievements.gd")
const FpsSaver := preload("features/fps_saver.gd")
const UpdateCheck := preload("core/update_check.gd")
const SettingsView := preload("ui/settings_view.gd")
const Icons := preload("ui/icons.gd")
const Guides := preload("ui/guides.gd")
const Toast := preload("ui/toast.gd")
const Alert := preload("ui/alert.gd")
const MilestoneBar := preload("ui/milestone_bar.gd")

const LOG_NAME := "eyyMinda-DirtAutopilot"
const TAB_TITLE := "Dirt Autopilot"
const SAVE_DELAY_SEC := 0.5
const FIELD_PATH := "Base/Game/Panels/Left"
## Used for logging when the loader provides it; print() otherwise.
const ML_LOG_PATH := "res://addons/mod_loader/api/log.gd"

var settings := Settings.new()
var stats: SessionStats
var sweeper: Sweeper
var auto: Automations
var guides: Guides
var toast: Toast
var alert: Alert
var progress: Progress
var achievements: Achievements
var fps_saver: FpsSaver
var updates: UpdateCheck
var milestone_bar: MilestoneBar
## Set by the settings screen while it waits for a new hotkey.
var rebinding := false
var version := ""

var _ml_log: Script
var _tab: Control
var _save_t := 0.0


func _init() -> void:
	if ResourceLoader.exists(ML_LOG_PATH):
		_ml_log = load(ML_LOG_PATH)


func _ready() -> void:
	version = _read_manifest_version()
	var err: String = settings.load_file()
	if !err.is_empty():
		log_warn(err)

	stats = _add(SessionStats.new(), "SessionStats")
	sweeper = _add(Sweeper.new(), "Sweeper")
	auto = _add(Automations.new(), "Automations")
	auto.setup(settings)
	progress = _add(Progress.new(), "Progress")
	progress.setup(settings)
	achievements = _add(Achievements.new(), "Achievements")
	achievements.setup(settings)
	fps_saver = _add(FpsSaver.new(), "FpsSaver")
	fps_saver.setup(settings)
	updates = _add(UpdateCheck.new(), "UpdateCheck")
	toast = _add(Toast.new(), "Toast")
	alert = _add(Alert.new(), "Alert")
	_set_alert_field()
	auto.relic_opened.connect(stats.add.bind("relics_opened"))
	auto.chest_opened.connect(stats.add.bind("chests"))
	progress.prestige_ready.connect(_on_prestige_ready)
	updates.update_found.connect(_on_update_found)

	settings.changed.connect(_on_setting_changed)
	for key in ["sweep_enabled", "sweep_guides", "milestone_bar"]:
		_on_setting_changed(key)
	updates.check(version)
	_save_t = 0.0

	_add_options_tab()
	log_info("v%s ready, loaded from %s." % [version, _script_dir()])


func _add(node: Node, node_name: String) -> Node:
	node.name = node_name
	add_child(node)
	return node


func _process(delta: float) -> void:
	if settings.dirty:
		_save_t -= delta
		if _save_t <= 0.0:
			_save()


func _physics_process(_delta: float) -> void:
	# The guides are reparented into the world, so they're freed with it on prestige or a world change.
	if settings.get_value("sweep_guides") and !is_instance_valid(guides):
		_set_guides(true)


func _exit_tree() -> void:
	if settings.dirty:
		_save()


func _save() -> void:
	var err: String = settings.save_file()
	if !err.is_empty():
		log_warn(err)


func _on_setting_changed(key: String) -> void:
	_save_t = SAVE_DELAY_SEC
	var v = settings.get_value(key)
	match key:
		"sweep_enabled":
			sweeper.set_enabled(v)
		"sweep_guides":
			_set_guides(v)
		"milestone_bar":
			_set_milestone_bar(v)


func _set_guides(on: bool) -> void:
	if is_instance_valid(guides):
		guides.queue_free()
	guides = null
	if on:
		guides = Guides.new()
		guides.name = "DirtAutopilotGuides"
		guides.sweeper = sweeper
		add_child(guides)


func _set_milestone_bar(on: bool) -> void:
	if is_instance_valid(milestone_bar):
		milestone_bar.queue_free()
	milestone_bar = null
	if !on:
		return
	var bar := MilestoneBar.new()
	bar.name = "DirtAutopilotMilestone"
	bar.progress = progress
	milestone_bar = bar
	while !(is_instance_valid(GM) and GM.ui):
		await get_tree().process_frame
	if milestone_bar != bar:
		return
	# The screen corner if the game's layout changes.
	var parent: Node = _field()
	if parent == null:
		parent = CanvasLayer.new()
		add_child(parent)
	parent.add_child(bar)


## The play field: the game area left of the shop panel.
func _field() -> Control:
	return GM.ui.get_node_or_null(FIELD_PATH) as Control


func _set_alert_field() -> void:
	while !(is_instance_valid(GM) and GM.ui):
		await get_tree().process_frame
	alert.field = _field()


func _on_prestige_ready(new_upgrades: int, worms_gain: int, icon: Texture2D, best_name: String) -> void:
	var title := "Prestige: %d new upgrade%s" % [new_upgrades, "" if new_upgrades == 1 else "s"]
	var desc := "+%s worms." % SessionStats._num(worms_gain)
	if !best_name.is_empty():
		desc += " Best buy: %s." % best_name
	alert.push(icon if icon else Progress.worms_icon(), title, desc, GM.prestige._input_prestige_tree_view, 10.0)


func _on_update_found(new_version: String, url: String) -> void:
	log_info("v%s is available: %s" % [new_version, url])
	alert.push(Icons.texture(Icons.GITHUB, Color.WHITE, 32), "Dirt Autopilot v%s is out" % new_version,
		"You have v%s. Click to open the download page." % version, OS.shell_open.bind(url), 12.0)


func active_feature_labels() -> Array:
	var out := []
	for key in settings.feature_keys():
		if settings.get_value(key):
			out.append(settings.entry(key).label)
	return out


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or !k.pressed or k.echo or rebinding or k.keycode == KEY_NONE:
		return
	# Don't react while the player is typing, e.g. a minigame answer.
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var code := int(k.keycode)

	if code == settings.get_value("key_status"):
		var on := active_feature_labels()
		var line := "On: " + ", ".join(on) if !on.is_empty() else "Nothing is switched on."
		_show(line + "\n" + stats.summary(), true)
	elif code == settings.get_value("key_settings"):
		toggle_settings()
	else:
		var hit := false
		for e in Settings.SCHEMA:
			if e.has("hotkey_of") and code == settings.get_value(e.hotkey_of):
				_show("%s: %s" % [e.label, "ON" if settings.toggle(e.key) else "OFF"])
				hit = true
				break
		if !hit:
			return
	get_viewport().set_input_as_handled()


## DirtLoader calls this to fill its Options > Mods > Settings popup.
func dirtloader_build_settings(container: Control) -> void:
	container.add_child(_make_view())


func _make_view() -> Control:
	var view := SettingsView.new()
	view.setup(self)
	return view


func _add_options_tab() -> void:
	while !(is_instance_valid(GM) and GM.ui and is_instance_valid(GM.ui.options)):
		await get_tree().process_frame
	var tabs := GM.ui.options.get_node_or_null("V/M/TabContainer") as TabContainer
	if tabs == null:
		tabs = GM.ui.options.find_child("TabContainer", true, false) as TabContainer
	if tabs == null:
		log_warn("The Options menu has no tabs; the settings tab wasn't added.")
		return

	var margin := MarginContainer.new()
	margin.name = "DirtAutopilot"
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	# Keeps the content clear of the scrollbar.
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 18)
	scroll.add_child(pad)
	var view := _make_view()
	view.custom_minimum_size = Vector2(300, 0)
	pad.add_child(view)
	tabs.add_child(margin)
	tabs.set_tab_title(margin.get_index(), TAB_TITLE)
	_tab = margin


func toggle_settings() -> void:
	if !is_instance_valid(_tab) or !is_instance_valid(GM.ui.options):
		return
	var options = GM.ui.options
	var tabs := _tab.get_parent() as TabContainer
	if options.visible and tabs.current_tab == _tab.get_index():
		options.toggle_off()
	else:
		tabs.current_tab = _tab.get_index()
		if !options.visible:
			options.toggle_on()


func _show(text: String, force := false) -> void:
	log_info(text.replace("\n", " · "))
	if force or settings.get_value("toasts"):
		toast.show_text(text)


func _script_dir() -> String:
	return (get_script() as Script).resource_path.get_base_dir()


func _read_manifest_version() -> String:
	var f := FileAccess.open(_script_dir().path_join("manifest.json"), FileAccess.READ)
	if f == null:
		return ""
	var data = JSON.parse_string(f.get_as_text())
	return str(data.get("version_number", "")) if data is Dictionary else ""


func log_info(msg: String) -> void:
	if _ml_log:
		_ml_log.info(msg, LOG_NAME)
	else:
		print("[%s] %s" % [LOG_NAME, msg])


func log_warn(msg: String) -> void:
	if _ml_log:
		_ml_log.warning(msg, LOG_NAME)
	else:
		push_warning("[%s] %s" % [LOG_NAME, msg])
