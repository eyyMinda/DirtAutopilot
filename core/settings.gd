extends RefCounted

signal changed(key: String)

const PATH := "user://DirtAutopilot/settings.json"
## Where settings were saved before the mod was renamed from Dirt Sweeper.
const LEGACY_PATH := "user://DirtSweeper/settings.json"
## Bump when keys are renamed (add them to MIGRATIONS) or a saved value must
## go back to its default (RESETS).
const VERSION := 5

## Settings in display order; the settings screen and hotkeys are built from this.
## Entries: {group} (big heading over several sections), {section}, {view}
## (custom block in settings_view.gd), or a setting:
##   bool default = switch, hotkey: true (int keycode) = key,
##   String default = dropdown of pals for hat (a key from features/hats.gd).
## Sections: fold: true = collapsible card with a header switch: "switch": key,
##   else one for all of its switches, else none.
## Optional: desc, requires (parent switch), hotkey_of (key that flips this switch),
##   all: false (left out of "Enable all").
const SCHEMA: Array[Dictionary] = [
	{"view": "title"},
	{"view": "enable_all"},

	# Up top: one row while closed, and the first thing to reach for late game.
	{"section": "Performance", "fold": true},
	{"key": "perf_no_particles", "default": false, "all": false,
		"label": "Skip flying dirt and worms",
		"desc": "Dirt and worms land on your counter at once instead of flying there. The biggest FPS saver late in the game."},
	{"key": "perf_no_effects", "default": false, "all": false,
		"label": "Hide dig effects",
		"desc": "No dust puffs, zap lines or item pops when tools trigger."},
	{"key": "perf_hide_buffs", "default": false, "all": false,
		"label": "Hide buff icons",
		"desc": "The buff timers above tools and pals. Buffs still work."},
	{"key": "perf_hide_stomps", "default": false, "all": false,
		"label": "Hide stomp circles",
		"desc": "The rings pals and tools draw when they stomp or hand out buffs."},
	{"key": "perf_hide_names", "default": false, "all": false,
		"label": "Hide pal names"},
	{"key": "perf_hide_sell_pops", "default": false, "all": false,
		"label": "Hide sell amounts",
		"desc": "The dirt/worms numbers that pop up over items in the inventory when they sell."},
	{"key": "perf_hide_new_counts", "default": false, "all": false,
		"label": "Hide new item counts",
		"desc": "The bouncing +N on inventory items you haven't hovered yet."},

	{"group": "Automations"},

	{"section": "Auto-sweeper"},
	{"key": "sweep_enabled", "default": false, "hotkey_of": "key_sweep",
		"label": "Auto-sweep",
		"desc": "Moves the hover circle onto tools that are ready, so they trigger without you moving the mouse."},
	{"key": "sweep_guides", "default": true, "hotkey_of": "key_guides", "all": false,
		"label": "Show sweep guides"},

	{"section": "Sand Mines"},
	{"key": "timer_game", "default": false, "hotkey_of": "key_timer",
		"label": "Play the Sand Mines timer",
		"desc": "Starts it whenever it's ready and stops on PERFECT."},
	{"key": "sand_auto", "default": true,
		"label": "Spend sand on upgrades",
		"desc": "Fills every sand upgrade, so you don't have to click them."},

	{"section": "Relics"},
	{"key": "relic_mg_solve", "default": false,
		"label": "Solve relic minigames",
		"desc": "Words, math cards, dice and the rest."},
	{"key": "relics_open", "default": false,
		"label": "Open relics",
		"desc": "Relics with a minigame are only opened while \"Solve relic minigames\" is on."},

	{"section": "Pickups"},
	{"key": "coffee_click", "default": false,
		"label": "Grab the coffee bean"},
	{"key": "chests_open", "default": false,
		"label": "Open chests when you have the key"},

	{"section": "Hats on pals", "fold": true, "switch": "hats_place"},
	{"key": "hats_place", "default": true,
		"label": "Put hats on pals",
		"desc": "Each new hat goes on a pal it helps, picked below, and the pal is named after someone from the credits. If none of those pals is free, the hat waits for you."},
	{"key": "hat_HAT_DIRT_MULTIPLY", "default": "", "hat": "HAT_DIRT_MULTIPLY", "requires": "hats_place"},
	{"key": "hat_HAT_RADIUS", "default": "", "hat": "HAT_RADIUS", "requires": "hats_place"},
	{"key": "hat_HAT_LUCK", "default": "", "hat": "HAT_LUCK", "requires": "hats_place"},
	{"key": "hat_HAT_WORMS", "default": "", "hat": "HAT_WORMS", "requires": "hats_place"},
	{"key": "hat_HAT_ACTIONS", "default": "", "hat": "HAT_ACTIONS", "requires": "hats_place"},
	{"key": "hat_HAT_IDLE_REDUCE", "default": "", "hat": "HAT_IDLE_REDUCE", "requires": "hats_place"},
	{"key": "hat_HAT_BUFF_TIME", "default": "", "hat": "HAT_BUFF_TIME", "requires": "hats_place"},

	{"group": "Quality of life"},

	{"section": "Progress"},
	{"key": "milestone_bar", "default": true,
		"label": "Show the next milestone",
		"desc": "A bar under your dirt per second with the next chest or relic. Hover it for details."},
	{"key": "prestige_alert", "default": true,
		"label": "Prestige alert",
		"desc": "Lets you know when prestiging would let you buy more prestige upgrades."},

	{"section": "Items & popups"},
	{"key": "protect_legendary", "default": true,
		"label": "Protect legendary items",
		"desc": "Fox pals and Sell All leave them alone. You can't sell them by hand while this is on."},
	{"key": "skip_popup_relics", "default": false,
		"label": "Skip relic popups"},
	{"key": "skip_popup_achievements", "default": false,
		"label": "Skip achievement popups"},

	{"section": "Achievements", "fold": true},
	{"view": "achievements"},

	{"group": "Setup"},

	{"section": "Hotkeys"},
	{"key": "key_sweep", "default": KEY_F5, "hotkey": true, "label": "Auto-sweep"},
	{"key": "key_guides", "default": KEY_F6, "hotkey": true, "label": "Sweep guides"},
	{"key": "key_timer", "default": KEY_F7, "hotkey": true, "label": "Sand Mines timer"},
	{"key": "key_stats", "default": KEY_C, "hotkey": true, "label": "Session stats tab"},
	{"key": "key_settings", "default": KEY_F9, "hotkey": true, "label": "Open these settings"},
	{"view": "hotkey_help"},

	{"section": "General"},
	{"view": "reset"},

	{"view": "credits"},
]

const MIGRATIONS := {
	"guides": "sweep_guides",
	"timer_enabled": "timer_game",
	"mg_solve": "relic_mg_solve",
	"relics_auto": "relics_open",
	"coffee_auto": "coffee_click",
	"chests_auto": "chests_open",
}

## Keys whose saved value is dropped when the file is older than the version:
## key_stats was Insert in pre-release 1.1.3 builds, now C.
const RESETS := {"key_stats": 5}

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


## Switches between a section header and the next one.
func section_keys(title: String) -> Array[String]:
	var out: Array[String] = []
	var inside := false
	for e in SCHEMA:
		if e.has("section") or e.has("group"):
			inside = e.get("section", "") == title
		elif inside and e.has("key") and e.default is bool and !e.get("hotkey", false):
			out.append(e.key)
	return out


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

	for key in RESETS:
		if int(data.get("version", 1)) < RESETS[key]:
			data.erase(key)

	for key in _entries:
		if !data.has(key):
			continue
		var e: Dictionary = _entries[key]
		var v = data[key]
		if e.default is bool and v is bool:
			values[key] = v
		elif e.default is String and v is String:
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
