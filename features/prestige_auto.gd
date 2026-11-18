extends Node
## Prestige side of the autopilot, both off by default:
## - prestige_buy: spends worms on the advisor's pick (features/prestige_advisor.gd)
##   whenever one is affordable, run or prestige screen.
## - auto_prestige: prestiges once it buys new prestige upgrades and the run is
##   slowing down (worms per minute over the last few minutes below the run's
##   average). With auto_restart it then presses Play in the prestige tree, in
##   restart_world ("" = the latest unlocked world before the Void).
## Both go through the game's own buttons/inputs.

signal prestiged(worms_gain: int)

const Advisor := preload("prestige_advisor.gd")
const Progress := preload("progress.gd")

const TICK_SEC := 1.0
## No auto-prestige before the run is this old.
const MIN_RUN_SEC := 300.0
## Worms/min over this window vs the run average.
const RECENT_SEC := 180.0
const SLOWDOWN := 0.8
## On the prestige screen, time to show what was bought before starting again.
const PLAY_DELAY_SEC := 2.0

var s

var run_sec := 0.0
var _t := 0.0
var _samples: Array = []  # [run_sec, worms_run] every TICK_SEC
var _busy := false
var _screen_sec := 0.0


func setup(settings) -> void:
	s = settings


func _process(delta: float) -> void:
	if !GM.is_app_init or !is_instance_valid(GM.prestige):
		return
	if GM.is_playing() and !GM.prestige.is_active:
		run_sec += delta
		_screen_sec = 0.0
	elif GM.prestige.is_active:
		_screen_sec += delta
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK_SEC

	if s.get_value("prestige_buy"):
		_buy_upgrades()

	if GM.prestige.is_active:
		run_sec = 0.0
		_samples.clear()
		_busy = false
		if s.get_value("auto_prestige") and s.get_value("auto_restart") and _screen_sec >= PLAY_DELAY_SEC:
			var key := restart_world(s.get_value("restart_world"))
			if !key.is_empty() and key != GM.wc.world_key:
				GM.wc._world_type_setup(key)
			GM.prestige.ui_prestige_tree.on_btn_play_pressed.emit()
		return

	if !GM.is_playing():
		return
	_samples.append([run_sec, GM.player.currency_amount("WORMS_RUN")])
	while _samples.size() > 1 and run_sec - _samples[0][0] > RECENT_SEC:
		_samples.pop_front()
	if s.get_value("auto_prestige") and !_busy and should_prestige():
		_prestige()


## [key, label] for the world dropdowns: "" (automatic) first, then the unlocked worlds.
static func world_options() -> Array:
	var auto := restart_world("")
	var out := [["", "Latest before the Void" + (" (%s)" % _world_name(auto) if !auto.is_empty() else "")]]
	if is_instance_valid(GM.wc):
		for key in GM.wc.world_keys_available:
			out.append([key, _world_name(key)])
	return out


## The world the next run starts in: the picked one if it's unlocked, else the
## latest unlocked one that isn't the Void (no tools work there yet).
static func restart_world(choice: String) -> String:
	if !is_instance_valid(GM.wc):
		return ""
	var available: Array[String] = GM.wc.world_keys_available
	if !choice.is_empty() and available.has(choice):
		return choice
	for i in range(World.KEYS.size() - 1, -1, -1):
		var key: String = World.KEYS[i]
		if key != "VOID" and available.has(key):
			return key
	return available[0] if !available.is_empty() else ""


static func _world_name(key: String) -> String:
	return TranslationServer.translate("UI_WORLD_" + key)


func _buy_upgrades() -> void:
	# A few per tick; each purchase changes the costs, so pick again each time.
	for i in 5:
		var best = Advisor.best(GM.player.currency_amount("WORMS"), s)
		if best == null:
			return
		best.on_pressed_buy.emit(false)


## New prestige upgrades become affordable and the run has slowed down.
func should_prestige() -> bool:
	if !GM.prestige.is_unlocked or run_sec < MIN_RUN_SEC or _samples.size() < 2:
		return false
	var worms: float = GM.player.currency_amount("WORMS")
	var gain: float = GM.player.currency_amount("WORMS_RUN")
	if Progress.prestige_new_upgrades(worms, gain).is_empty():
		return false
	var first: Array = _samples[0]
	var recent := (gain - float(first[1])) / maxf(run_sec - float(first[0]), 1.0)
	var average := gain / maxf(run_sec, 1.0)
	return recent < average * SLOWDOWN


func _prestige() -> void:
	_busy = true
	var gain := int(GM.player.currency_amount("WORMS_RUN"))
	GM.prestige._input_prestige_warning()
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(GM.prestige) and is_instance_valid(GM.prestige.ui_prestige_warning) and GM.is_playing():
		GM.prestige.ui_prestige_warning._btn_confirm_pressed()
		prestiged.emit(gain)
