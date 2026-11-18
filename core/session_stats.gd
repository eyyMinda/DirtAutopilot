extends Node
## Counts what happened this run (since the last prestige, or since the save was
## loaded) and all time. All time is kept per save slot (the game's own save
## folder: Steam user + slot), in user://DirtAutopilot/stats_<user>_<slot>.json;
## loading another slot saves the old one and switches over.

const Achievements := preload("../features/achievements.gd")

const DIR := "user://DirtAutopilot"
## Before 1.2.0 one file held every slot's stats; the first slot loaded takes it over.
const LEGACY_PATH := "user://DirtAutopilot/stats.json"
const SAVE_EVERY_SEC := 30.0
const AMOUNTS := ["play_sec", "dirt", "worms", "sand"]
const COUNTERS := ["tools_triggered", "items", "relics", "items_sold", "relics_opened",
	"minigames_won", "minigames_lost", "sand_runs", "perfects", "sand_levels",
	"coffees", "chests", "hats", "prestiges", "achievements", "voids"]

## Icons for the stats tiles: [texture path, hframes, vframes, frame].
const ICON_DIRT := ["res://app/ui/currency_dirt.png", 1, 1, 0]
const ICON_WORMS := ["res://app/ui/currency_worms.png", 1, 1, 0]
const ICON_VOID := ["res://app/ui/currency_void.png", 1, 1, 0]
const ICON_SHOVEL := ["res://app/ui/icons_nodes.png", 10, 10, 1]
const ICON_HAT := ["res://app/ui/icons_nodes.png", 10, 10, 26]
const ICON_ITEM := ["res://app/ui/inventory/item/items_common_sheet.png", 20, 1, 0]
const NODE_SHEET := "res://app/ui/icons_nodes.png"
const TOOL_WINDOW_SEC := 60
const ICON_RELIC := ["res://app/ui/badges/icon/badges_icons_sheet.png", 20, 4, 0]
const ICON_ACHIEVEMENT := ["res://app/ui/badges/icon/badges_icons_sheet.png", 20, 4, 73]
const ICON_MINIGAME := ["res://app/ui/mini_game/sign_correct.png", 1, 1, 0]
const ICON_SAND := ["res://app/ui/sand/sand_icon.png", 1, 1, 0]
const ICON_TROPHY := ["res://app/ui/sand/icon_trophy.png", 1, 1, 0]
const ICON_COFFEE := ["res://app/ui/coffee/coffee_bean.png", 1, 1, 0]
const ICON_CHEST := ["res://app/world/node/chest/wooden/chests_wooden_sheet.png", 2, 1, 0]

## This run and all time: AMOUNTS (floats) + COUNTERS (ints).
var run: Dictionary = {}
var all: Dictionary = {}
## Which one hero() and tiles() show.
var show_all := false
## Dirt per tool this run (the game's currency source key = node key).
var run_tools: Dictionary = {}

var _tool_sec: Dictionary = {}
var _tool_window: Array[Dictionary] = []
var _tool_t := 1.0

## The loaded save slot ("<user>_game_slot_<n>"), "" until one is loaded.
var _slot := ""
var _connected := false
var _dirty := false
var _save_t := SAVE_EVERY_SEC
var _dirt_prev := -1.0
var _worms_prev := -1.0
var _sand_prev := -1.0
var _sand_levels_prev := -1
var _sand_check_t := 0.0


func _init() -> void:
	reset_run()
	all = _blank()


func _exit_tree() -> void:
	if _dirty:
		save_file()


static func _blank() -> Dictionary:
	var d := {}
	for key in AMOUNTS:
		d[key] = 0.0
	for key in COUNTERS:
		d[key] = 0
	return d


func reset_run() -> void:
	run = _blank()
	run_tools.clear()
	_tool_sec.clear()
	_tool_window.clear()


func add(key: String, amount = 1) -> void:
	if _slot.is_empty():
		return
	run[key] += amount
	all[key] += amount
	_dirty = true


func _process(delta: float) -> void:
	if !GM.is_app_init:
		return
	if !_connected:
		_connect()
	if GM.is_playing():
		var slot := _current_slot()
		if !slot.is_empty() and slot != _slot:
			_switch_slot(slot)
	if _dirty:
		_save_t -= delta
		if _save_t <= 0.0:
			_save_t = SAVE_EVERY_SEC
			save_file()
	if !GM.is_playing():
		_dirt_prev = -1.0
		_worms_prev = -1.0
		_sand_prev = -1.0
		_sand_levels_prev = -1
		return
	add("play_sec", delta)
	_tool_t -= delta
	if _tool_t <= 0.0:
		_tool_t = 1.0
		_tool_window.append(_tool_sec)
		_tool_sec = {}
		if _tool_window.size() > TOOL_WINDOW_SEC:
			_tool_window.pop_front()
	# amount_overall resets on prestige, so only increases are counted.
	_add_gain("dirt", GM.player.currency_dirt.amount_overall, _dirt_prev)
	_dirt_prev = GM.player.currency_dirt.amount_overall
	_add_gain("worms", GM.player.currency_worms.amount_overall, _worms_prev)
	_worms_prev = GM.player.currency_worms.amount_overall
	_add_gain("sand", GM.player.currency_sand.amount_overall, _sand_prev)
	_sand_prev = GM.player.currency_sand.amount_overall
	_sand_check_t -= delta
	if _sand_check_t <= 0.0:
		_sand_check_t = 1.0
		var levels := _sand_levels()
		if _sand_levels_prev >= 0 and levels > _sand_levels_prev:
			add("sand_levels", levels - _sand_levels_prev)
		_sand_levels_prev = levels


func _add_gain(key: String, now: float, prev: float) -> void:
	if prev >= 0.0 and now > prev:
		add(key, now - prev)


static func _sand_levels() -> int:
	var total := 0
	if is_instance_valid(GM.sand):
		for slot in GM.sand.slots:
			total += slot.stat_data.level
	return total


func _connect() -> void:
	if !(is_instance_valid(GM.inv) and is_instance_valid(GM.mini_games) and is_instance_valid(GM.coffee) \
			and is_instance_valid(GM.sand) and is_instance_valid(GM.hat) and is_instance_valid(GM.ach)):
		return
	_connected = true
	GM.on_dig.connect(add.bind("tools_triggered"))
	GM.player.currency_dirt.on_updated_info.connect(_on_dirt_info)
	GM.inv.on_item_dig.connect(add.bind("items").unbind(1))
	GM.inv.on_item_dig_relic.connect(add.bind("relics").unbind(1))
	GM.inv.on_sell_data.connect(func(_k, count, _gain): add("items_sold", count))
	GM.mini_games.on_game_end.connect(func(_k, won: bool): add("minigames_won" if won else "minigames_lost"))
	GM.coffee.on_effect_activated.connect(add.bind("coffees"))
	GM.sand.game.on_completed.connect(add.bind("sand_runs").unbind(1))
	GM.sand.game.on_btn_pressed.connect(_on_sand_btn_pressed)
	GM.hat.on_hat_placed.connect(add.bind("hats").unbind(1))
	GM.ac.prestige_start.on_init.connect(_on_prestige)
	GM.ach.on_unlock.connect(add.bind("achievements").unbind(1))
	if is_instance_valid(GM.void_fusion):
		GM.void_fusion.on_fusion_spawn_node.connect(add.bind("voids").unbind(1))


## A prestige ends the run: counted all time, then the run starts over.
func _on_prestige() -> void:
	add("prestiges")
	reset_run()
	save_file()


## The same source the game's Stats graph uses.
func _on_dirt_info(update) -> void:
	if update.value <= 0 or update.source_key.is_empty() or !GM.is_playing():
		return
	run_tools[update.source_key] = run_tools.get(update.source_key, 0.0) + update.value
	_tool_sec[update.source_key] = _tool_sec.get(update.source_key, 0.0) + update.value


## Tools by dirt earned this run, best first: key, name, icon, dirt, share
## (0..1 of all tool dirt) and per_sec (over the last minute).
func tools() -> Array:
	var total := 0.0
	for key in run_tools:
		total += run_tools[key]
	var secs := maxi(_tool_window.size(), 1)
	var out: Array = []
	for key in run_tools:
		var recent := 0.0
		for sec in _tool_window:
			recent += sec.get(key, 0.0)
		var data: Dictionary = GM.data.raw_data_nodes.get(key, {})
		out.append({
			"key": key,
			"name": tr(data.get("NAME", key)).capitalize(),
			"icon": [NODE_SHEET, 10, 10, int(data.get("ICON_FRAME", 0))],
			"dirt": run_tools[key],
			"share": run_tools[key] / total if total > 0.0 else 0.0,
			"per_sec": recent / secs,
		})
	out.sort_custom(func(a, b): return a.dirt > b.dirt)
	return out


func _on_sand_btn_pressed(time_left: float, _streak: int) -> void:
	if time_left == 0:
		add("perfects")


## "<user>_game_slot_<n>" from the game's save folder, "" when unknown.
static func _current_slot() -> String:
	if !is_instance_valid(GM.data) or GM.game_id < 0:
		return ""
	return GM.data.folder_path().trim_prefix("user://data/").replace("/", "_")


func _path() -> String:
	return "%s/stats_%s.json" % [DIR, _slot]


## Another save was loaded: keep the old slot's numbers, load this one's, new run.
func _switch_slot(slot: String) -> void:
	if !_slot.is_empty() and _dirty:
		save_file()
	_slot = slot
	all = _blank()
	reset_run()
	_dirt_prev = -1.0
	_worms_prev = -1.0
	_sand_prev = -1.0
	_sand_levels_prev = -1
	if !FileAccess.file_exists(_path()) and FileAccess.file_exists(LEGACY_PATH):
		DirAccess.rename_absolute(LEGACY_PATH, _path())
	_load()


func _load() -> void:
	var path := _path()
	if !FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if !(data is Dictionary) or !(data.get("all") is Dictionary):
		push_warning("[eyyMinda-DirtAutopilot] %s isn't valid; all-time stats start over." % path)
		return
	for key in all:
		var v = data.all.get(key)
		if v is float or v is int:
			if key in AMOUNTS:
				all[key] = maxf(float(v), 0.0)
			else:
				all[key] = maxi(int(v), 0)


## Writes a temp file and swaps it in, like the settings.
func save_file() -> void:
	_dirty = false
	_save_t = SAVE_EVERY_SEC
	if _slot.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := _path()
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"version": 1, "all": all}, "\t", false))
	f.close()
	DirAccess.rename_absolute(tmp, path)


func _cur() -> Dictionary:
	return all if show_all else run


func _per_hour(v: float) -> String:
	var sec: float = _cur().play_sec
	return "—" if sec < 60.0 else _num(v / (sec / 3600.0))


## The headline numbers, shown large.
func hero() -> Array:
	var d := _cur()
	return [
		{"label": "Play time", "value": _time(d.play_sec)},
		{"label": "Dirt earned", "value": _num(d.dirt), "icon": ICON_DIRT},
		{"label": "Dirt per hour", "value": _per_hour(d.dirt), "icon": ICON_DIRT},
	]


## Grouped rows; "group" starts a new block in the stats tab, "hidden" hides
## the row in this view. Since game 1.3 minigames and chests are done once per
## save, so those rows (and other "save" ones) read the game, not the counters.
func tiles() -> Array:
	var d := _cur()
	return [
		{"group": "Digging", "label": "Worms earned", "value": _num(d.worms), "icon": ICON_WORMS},
		{"label": "Tools triggered", "value": _num(d.tools_triggered), "icon": ICON_SHOVEL},
		{"label": "Void tools fused", "value": _num(d.voids), "icon": ICON_VOID},
		{"group": "Items", "label": "Found", "value": _num(d.items), "icon": ICON_ITEM},
		{"label": "Per hour", "value": _per_hour(d.items), "icon": ICON_ITEM},
		{"label": "Sold", "value": _num(d.items_sold), "icon": ICON_ITEM},
		{"group": "Relics", "label": "Found", "value": _num(d.relics), "icon": ICON_RELIC},
		{"label": "Opened", "value": _num(d.relics_opened), "icon": ICON_RELIC},
		{"label": "Minigames done", "value": _minigames_done(), "icon": ICON_MINIGAME},
		{"group": "Sand Mines", "label": "Sand dug", "value": _num(d.sand), "icon": ICON_SAND},
		{"label": "Games", "value": _num(d.sand_runs), "icon": ICON_SAND},
		{"label": "PERFECT stops", "value": _num(d.perfects), "icon": ICON_TROPHY},
		{"label": "Levels bought", "value": _num(d.sand_levels), "icon": ICON_SAND},
		{"label": "Upgrades maxed", "value": _sand_maxed(), "icon": ICON_TROPHY},
		{"group": "Other", "label": "Coffee beans", "value": _num(d.coffees), "icon": ICON_COFFEE},
		{"label": "Chests opened", "value": _chests_opened(), "icon": ICON_CHEST},
		{"label": "Hats worn", "value": _hats_worn(), "icon": ICON_HAT},
		{"label": "Achievements", "value": _achievements() if show_all else _num(d.achievements), "icon": ICON_ACHIEVEMENT},
		{"label": "Prestiges", "value": _num(all.prestiges), "icon": ICON_WORMS, "hidden": !show_all},
	]


## Sand Mines upgrades at max level in this save / all of them.
static func _sand_maxed() -> String:
	if !is_instance_valid(GM.sand) or GM.sand.slots.is_empty():
		return "—"
	var maxed := 0
	for slot in GM.sand.slots:
		if slot.is_max_level:
			maxed += 1
	return "%d / %d" % [maxed, GM.sand.slots.size()]


## Pals wearing a hat right now.
static func _hats_worn() -> String:
	if !(is_instance_valid(GM.wc) and GM.wc.world_exists and is_instance_valid(GM.wc.world)):
		return "—"
	var worn := 0
	for nodes in GM.wc.world.key_to_nodes.values():
		for node in nodes:
			if is_instance_valid(node) and !node.hat_node_data_key.is_empty():
				worn += 1
	return _num(worn)


## Achievements owned in this save / all of them (the mod's Achievements list).
static func _achievements() -> String:
	if !Achievements.is_ready():
		return "—"
	var owned := 0
	var entries: Array = Achievements.entries()
	for e in entries:
		if Achievements.owned(e.key):
			owned += 1
	return "%d / %d" % [owned, entries.size()]


## Relic minigames won at least once in this save / all of them.
static func _minigames_done() -> String:
	if !is_instance_valid(GM.mini_games):
		return "—"
	return "%d / %d" % [GM.mini_games.finished_mini_game_keys.size(), PRELOADS.PS_MINI_GAMES.size()]


## Chests opened for good in this save (their reward badge is owned) / all chests.
static func _chests_opened() -> String:
	if !(is_instance_valid(GM.chest) and is_instance_valid(GM.badges)) or GM.chest.data_raw.is_empty():
		return "—"
	var opened := 0
	for key in GM.chest.data_raw:
		var badge: String = GM.chest.data_raw[key].get("KEY_BADGE_REWARD", "")
		if !badge.is_empty() and GM.badges.badge_exists(badge) and GM.badges.badge_is_own_max(badge):
			opened += 1
	return "%d / %d" % [opened, GM.chest.data_raw.size()]


static func _time(sec: float) -> String:
	var s := int(sec)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


static func _num(v: float) -> String:
	var units := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
	var i := 0
	while absf(v) >= 1000.0 and i < units.size() - 1:
		v /= 1000.0
		i += 1
	if i == 0:
		return str(int(v))
	return ("%.2f" % v) + units[i]
