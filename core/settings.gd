extends RefCounted

signal changed(key: String)

const PATH := "user://DirtAutopilot/settings.json"
## Where settings were saved before the mod was renamed from Dirt Sweeper.
const LEGACY_PATH := "user://DirtSweeper/settings.json"
## Bump when keys are renamed, and add the renames to MIGRATIONS.
const VERSION := 3

## Settings in display order; the settings screen and hotkeys are built from this.
## Entries: {section}, {view} (custom block in settings_view.gd), or a setting:
##   bool default = switch, int default = slider (min/max/step/unit), hotkey: true = key.
## Optional: desc, requires (parent switch), hotkey_of (key that flips this switch),
##   all: false (left out of "Enable all").
const SCHEMA: Array[Dictionary] = [
	{"view": "title"},
	{"view": "enable_all"},

	{"section": "Auto-sweeper"},
	{"key": "sweep_enabled", "default": false, "hotkey_of": "key_sweep",
		"label": "Auto-sweep",
		"desc": "Moves the hover circle onto tools that are ready, so they trigger without you moving the mouse."},
	{"key": "sweep_guides", "default": false, "hotkey_of": "key_guides", "all": false,
		"label": "Show sweep guides"},
	{"key": "sweep_extra_hold_ms", "default": 0, "min": 0, "max": 500, "step": 5, "unit": "ms",
		"requires": "sweep_enabled",
		"label": "Extra wait per spot",
		"desc": "Leave at 0 unless tools get skipped."},

	{"section": "Minigames"},
	{"key": "timer_game", "default": false, "hotkey_of": "key_timer",
		"label": "Play the Sand Mines timer"},
	{"key": "timer_game_auto_start", "default": true, "requires": "timer_game",
		"label": "Start it when it's ready"},
	{"key": "relic_mg_solve", "default": false,
		"label": "Solve relic minigames",
		"desc": "Words, math cards, dice and the rest."},
	{"key": "relic_mg_delay_ms", "default": 500, "min": 0, "max": 5000, "step": 100, "unit": "ms",
		"requires": "relic_mg_solve",
		"label": "Answer after"},

	{"section": "Relics & items"},
	{"key": "relics_open", "default": false,
		"label": "Open relics",
		"desc": "Relics with a minigame are only opened while \"Solve relic minigames\" is on."},
	{"key": "protect_legendary", "default": false,
		"label": "Protect legendary items",
		"desc": "Fox pals and Sell All leave them alone. You can't sell them by hand while this is on."},

	{"section": "Extras"},
	{"key": "coffee_click", "default": false,
		"label": "Grab the coffee bean"},
	{"key": "chests_open", "default": false,
		"label": "Open chests when you have the key"},
	{"key": "skip_popup_relics", "default": false,
		"label": "Skip relic popups"},
	{"key": "skip_popup_achievements", "default": false,
		"label": "Skip achievement popups"},

	{"section": "Session stats"},
	{"view": "stats"},

	{"section": "Hotkeys"},
	{"key": "key_sweep", "default": KEY_F5, "hotkey": true, "label": "Auto-sweep"},
	{"key": "key_guides", "default": KEY_F6, "hotkey": true, "label": "Sweep guides"},
	{"key": "key_timer", "default": KEY_F7, "hotkey": true, "label": "Sand Mines timer"},
	{"key": "key_status", "default": KEY_INSERT, "hotkey": true, "label": "Show what's on"},
	{"key": "key_settings", "default": KEY_F9, "hotkey": true, "label": "Open these settings"},
	{"view": "hotkey_help"},

	{"section": "General"},
	{"key": "toasts", "default": true, "all": false,
		"label": "Show hotkey messages"},
	{"view": "reset"},

	{"view": "credits"},
]

const MIGRATIONS := {
	"guides": "sweep_guides",
	"min_hold_ms": "sweep_extra_hold_ms",
	"timer_enabled": "timer_game",
	"timer_auto_start": "timer_game_auto_start",
	"mg_solve": "relic_mg_solve",
	"mg_solve_delay_ms": "relic_mg_delay_ms",
	"relics_auto": "relics_open",
	"coffee_auto": "coffee_click",
	"chests_auto": "chests_open",
}

var values: Dictionary = {}
var dirty := false
var _entries: Dictionary = {}


func _init() -> void:
	for e in SCHEMA:
		if e.has("key"):
			_entries[e.key] = e
			values[e.key] = e.default


func entry(key: String) -> Dictionary:
	return _entries.get(key, {})


func get_value(key: String) -> Variant:
	return values.get(key)


func set_value(key: String, value: Variant) -> void:
	if !values.has(key) or values[key] == value:
		return
	values[key] = value
	dirty = true
	changed.emit(key)


func toggle(key: String) -> bool:
	set_value(key, !get_value(key))
	return get_value(key)


func reset() -> void:
	for key in _entries:
		set_value(key, _entries[key].default)


## Main feature switches: top-level, not excluded with "all": false.
func feature_keys() -> Array[String]:
	var out: Array[String] = []
	for e in SCHEMA:
		if e.has("key") and e.default is bool and !e.has("requires") and e.get("all", true):
			out.append(e.key)
	return out


func set_all_features(on: bool) -> void:
	for key in feature_keys():
		set_value(key, on)


func hotkey_keys() -> Array[String]:
	var out: Array[String] = []
	for e in SCHEMA:
		if e.get("hotkey", false):
			out.append(e.key)
	return out


## Returns an error message, or "" if the file was fine or doesn't exist yet.
func load_file() -> String:
	if !FileAccess.file_exists(PATH) and FileAccess.file_exists(LEGACY_PATH):
		DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
		if DirAccess.rename_absolute(LEGACY_PATH, PATH) == OK:
			DirAccess.remove_absolute(LEGACY_PATH.get_base_dir())
	if !FileAccess.file_exists(PATH):
		return ""
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return "Can't open %s (%s); using defaults." % [PATH, error_string(FileAccess.get_open_error())]
	var data = JSON.parse_string(f.get_as_text())
	if !(data is Dictionary):
		return "%s isn't valid JSON; using defaults." % PATH

	if int(data.get("version", 1)) < VERSION:
		for old in MIGRATIONS:
			if data.has(old) and !data.has(MIGRATIONS[old]):
				data[MIGRATIONS[old]] = data[old]

	for key in _entries:
		if !data.has(key):
			continue
		var e: Dictionary = _entries[key]
		var v = data[key]
		if e.default is bool and v is bool:
			values[key] = v
		elif e.default is int and (v is float or v is int):
			values[key] = clampi(int(v), e.get("min", int(v)), e.get("max", int(v)))
	return ""


func save_file() -> String:
	dirty = false
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var data := values.duplicate()
	data["version"] = VERSION
	# Write to a temp file and swap it in, so a crash mid-write can't corrupt the settings.
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "Can't write %s (%s)." % [tmp, error_string(FileAccess.get_open_error())]
	f.store_string(JSON.stringify(data, "\t", false))
	f.close()
	var err := DirAccess.rename_absolute(tmp, PATH)
	if err != OK:
		return "Can't replace %s (%s)." % [PATH, error_string(err)]
	return ""


static func key_name(keycode: int) -> String:
	return "None" if keycode == KEY_NONE else OS.get_keycode_string(keycode)
