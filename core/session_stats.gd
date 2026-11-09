extends Node

var play_sec := 0.0
var dirt := 0.0
var tools_triggered := 0
var items := 0
var relics := 0
var items_sold := 0
var minigames_won := 0
var minigames_lost := 0
var sand_runs := 0
var perfects := 0
var coffees := 0
var chests := 0
var relics_opened := 0

var _connected := false
var _dirt_prev := -1.0


func reset() -> void:
	play_sec = 0.0
	dirt = 0.0
	tools_triggered = 0
	items = 0
	relics = 0
	items_sold = 0
	minigames_won = 0
	minigames_lost = 0
	sand_runs = 0
	perfects = 0
	coffees = 0
	chests = 0
	relics_opened = 0
	_dirt_prev = -1.0


func _process(delta: float) -> void:
	if !GM.is_app_init:
		return
	if !_connected:
		_connect()
	if !GM.is_playing():
		_dirt_prev = -1.0
		return
	play_sec += delta
	# amount_overall resets on prestige, so only increases are counted.
	var d: float = GM.player.currency_dirt.amount_overall
	if _dirt_prev >= 0.0 and d > _dirt_prev:
		dirt += d - _dirt_prev
	_dirt_prev = d


func _connect() -> void:
	if !(is_instance_valid(GM.inv) and is_instance_valid(GM.mini_games) and is_instance_valid(GM.coffee) and is_instance_valid(GM.sand)):
		return
	_connected = true
	GM.on_dig.connect(func(): tools_triggered += 1)
	GM.inv.on_item_dig.connect(func(_k): items += 1)
	GM.inv.on_item_dig_relic.connect(func(_k): relics += 1)
	GM.inv.on_sell_data.connect(func(_k, count, _gain): items_sold += count)
	GM.mini_games.on_game_end.connect(_on_minigame_end)
	GM.coffee.on_effect_activated.connect(func(): coffees += 1)
	GM.sand.game.on_completed.connect(func(_streak): sand_runs += 1)
	GM.sand.game.on_btn_pressed.connect(_on_sand_btn_pressed)


func _on_minigame_end(_key: String, success: bool) -> void:
	if success:
		minigames_won += 1
	else:
		minigames_lost += 1


func _on_sand_btn_pressed(time_left: float, _streak: int) -> void:
	if time_left == 0:
		perfects += 1


func rows() -> Array:
	var per_hour := "—" if play_sec < 60.0 else _num(dirt / (play_sec / 3600.0)) + " / hour"
	return [
		["Play time", _time(play_sec)],
		["Dirt earned", _num(dirt)],
		["Dirt rate", per_hour],
		["Tools triggered", _num(tools_triggered)],
		["Items found", _num(items)],
		["Relics found", _num(relics)],
		["Items sold", _num(items_sold)],
		["Relics opened", _num(relics_opened)],
		["Relic minigames won", "%d of %d" % [minigames_won, minigames_won + minigames_lost]],
		["Sand Mines games", _num(sand_runs)],
		["PERFECT stops", _num(perfects)],
		["Coffee beans", _num(coffees)],
		["Chests opened", _num(chests)],
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
