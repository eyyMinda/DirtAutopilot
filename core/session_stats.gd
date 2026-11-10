extends Node
## Counts what happened since the game was started (or the stats were reset).

const COUNTERS := ["tools_triggered", "items", "relics", "items_sold", "relics_opened",
	"minigames_won", "minigames_lost", "sand_runs", "perfects", "sand_levels",
	"coffees", "chests", "hats", "prestiges", "achievements"]

## Icons for the stats tiles: [texture path, hframes, vframes, frame].
const ICON_DIRT := ["res://app/ui/currency_dirt.png", 1, 1, 0]
const ICON_WORMS := ["res://app/ui/currency_worms.png", 1, 1, 0]
const ICON_CURSOR := ["res://app/ui/icons_nodes.png", 10, 10, 5]
const ICON_HAT := ["res://app/ui/icons_nodes.png", 10, 10, 26]
const ICON_ITEM := ["res://app/ui/inventory/item/items_common_sheet.png", 20, 4, 0]
const ICON_RELIC := ["res://app/ui/badges/icon/badges_icons_sheet.png", 20, 4, 0]
const ICON_ACHIEVEMENT := ["res://app/ui/badges/icon/badges_icons_sheet.png", 20, 4, 73]
const ICON_MINIGAME := ["res://app/ui/mini_game/sign_correct.png", 1, 1, 0]
const ICON_SAND := ["res://app/ui/sand/sand_icon.png", 1, 1, 0]
const ICON_TROPHY := ["res://app/ui/sand/icon_trophy.png", 1, 1, 0]
const ICON_COFFEE := ["res://app/ui/coffee/coffee_bean.png", 1, 1, 0]
const ICON_CHEST := ["res://app/world/node/chest/wooden/chests_wooden_sheet.png", 2, 1, 0]

var play_sec := 0.0
var dirt := 0.0
var worms := 0.0
var n: Dictionary = {}

var _connected := false
var _dirt_prev := -1.0
var _worms_prev := -1.0
var _sand_levels_prev := -1
var _sand_check_t := 0.0


func _init() -> void:
	reset()


func reset() -> void:
	play_sec = 0.0
	dirt = 0.0
	worms = 0.0
	for key in COUNTERS:
		n[key] = 0
	_dirt_prev = -1.0
	_worms_prev = -1.0
	_sand_levels_prev = -1


func add(key: String, amount := 1) -> void:
	n[key] += amount


func _process(delta: float) -> void:
	if !GM.is_app_init:
		return
	if !_connected:
		_connect()
	if !GM.is_playing():
		_dirt_prev = -1.0
		_worms_prev = -1.0
		_sand_levels_prev = -1
		return
	play_sec += delta
	# amount_overall resets on prestige, so only increases are counted.
	dirt += _gain(GM.player.currency_dirt.amount_overall, _dirt_prev)
	_dirt_prev = GM.player.currency_dirt.amount_overall
	worms += _gain(GM.player.currency_worms.amount_overall, _worms_prev)
	_worms_prev = GM.player.currency_worms.amount_overall
	_sand_check_t -= delta
	if _sand_check_t <= 0.0:
		_sand_check_t = 1.0
		var levels := _sand_levels()
		if _sand_levels_prev >= 0 and levels > _sand_levels_prev:
			n.sand_levels += levels - _sand_levels_prev
		_sand_levels_prev = levels


static func _gain(now: float, prev: float) -> float:
	return now - prev if prev >= 0.0 and now > prev else 0.0


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
	GM.inv.on_item_dig.connect(add.bind("items").unbind(1))
	GM.inv.on_item_dig_relic.connect(add.bind("relics").unbind(1))
	GM.inv.on_sell_data.connect(func(_k, count, _gain): add("items_sold", count))
	GM.mini_games.on_game_end.connect(func(_k, won: bool): add("minigames_won" if won else "minigames_lost"))
	GM.coffee.on_effect_activated.connect(add.bind("coffees"))
	GM.sand.game.on_completed.connect(add.bind("sand_runs").unbind(1))
	GM.sand.game.on_btn_pressed.connect(_on_sand_btn_pressed)
	GM.hat.on_hat_placed.connect(add.bind("hats").unbind(1))
	GM.ac.prestige_start.on_init.connect(add.bind("prestiges"))
	GM.ach.on_unlock.connect(add.bind("achievements").unbind(1))


func _on_sand_btn_pressed(time_left: float, _streak: int) -> void:
	if time_left == 0:
		n.perfects += 1


func _per_hour(v: float) -> String:
	return "—" if play_sec < 60.0 else _num(v / (play_sec / 3600.0))


## The headline numbers, shown large.
func hero() -> Array:
	return [
		{"label": "Play time", "value": _time(play_sec)},
		{"label": "Dirt earned", "value": _num(dirt), "icon": ICON_DIRT},
		{"label": "Dirt per hour", "value": _per_hour(dirt), "icon": ICON_DIRT},
	]


func tiles() -> Array:
	return [
		{"label": "Worms earned", "value": _num(worms), "icon": ICON_WORMS},
		{"label": "Tools triggered", "value": _num(n.tools_triggered), "icon": ICON_CURSOR},
		{"label": "Items found", "value": _num(n.items), "icon": ICON_ITEM},
		{"label": "Items per hour", "value": _per_hour(n.items), "icon": ICON_ITEM},
		{"label": "Items sold", "value": _num(n.items_sold), "icon": ICON_ITEM},
		{"label": "Relics found", "value": _num(n.relics), "icon": ICON_RELIC},
		{"label": "Relics opened", "value": _num(n.relics_opened), "icon": ICON_RELIC},
		{"label": "Minigames won", "value": "%d / %d" % [n.minigames_won, n.minigames_won + n.minigames_lost], "icon": ICON_MINIGAME},
		{"label": "Sand Mines games", "value": _num(n.sand_runs), "icon": ICON_SAND},
		{"label": "PERFECT stops", "value": _num(n.perfects), "icon": ICON_TROPHY},
		{"label": "Sand upgrades", "value": _num(n.sand_levels), "icon": ICON_SAND},
		{"label": "Coffee beans", "value": _num(n.coffees), "icon": ICON_COFFEE},
		{"label": "Chests opened", "value": _num(n.chests), "icon": ICON_CHEST},
		{"label": "Hats placed", "value": _num(n.hats), "icon": ICON_HAT},
		{"label": "Prestiges", "value": _num(n.prestiges), "icon": ICON_WORMS},
		{"label": "Achievements", "value": _num(n.achievements), "icon": ICON_ACHIEVEMENT},
	]


func summary() -> String:
	return "This session: %s played · %s dirt" % [_time(play_sec), _num(dirt)]


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
