extends Node
## All automations except the sweeper. They only call the game's own functions
## and signals (no script extensions), so they work under any mod loader.

const Hats := preload("hats.gd")

signal relic_opened
signal chest_opened

## The game counts a Sand Mines stop within ±0.1 s of zero as PERFECT;
## stopping at 0.05 s left stays perfect down to ~7 FPS.
const TIMER_STOP_AT_SEC := 0.05
## Same hold time as opening a relic by hand.
const RELIC_OPEN_SEC := 1.0
## Pause before answering a relic minigame, so it's visible what was solved.
const MG_ANSWER_DELAY_MSEC := 500
## Automations that don't need frame timing run this often; inventories and
## the world are walked far less in a busy late game.
const TICK_SEC := 0.1
## Pause before each hat, so the hat picker has appeared and the confetti is visible.
const HAT_DELAY_MSEC := 600

var s

var _mg_scene: Node
var _mg_answer_at_msec := 0
var _locked_by_us: Dictionary = {}
var _sell_all_swapped := false
var _hat_at_msec := 0
var _tick_t := 0.0
var _credit_names: Array[String] = []


func setup(settings) -> void:
	s = settings
	s.changed.connect(_on_setting_changed)


func _ready() -> void:
	# After the game's controllers, so values like the Sand Mines countdown are this frame's.
	process_priority = 1000


func _process(delta: float) -> void:
	if !GM.is_app_init:
		return
	_update_sell_all_guard()
	if !GM.is_playing():
		return
	# Frame-exact: the timer must stop within ±0.1 s.
	if s.get_value("timer_game"):
		_play_timer_game()
	if s.get_value("relic_mg_solve"):
		_solve_relic_minigame()
	_tick_t -= delta
	if _tick_t > 0.0:
		return
	_tick_t = TICK_SEC
	if s.get_value("coffee_click"):
		_grab_coffee()
	if s.get_value("chests_open"):
		_open_chests()
	if s.get_value("skip_popup_relics") or s.get_value("skip_popup_achievements"):
		_skip_popup()
	if s.get_value("protect_legendary"):
		_protect_legendary()
	if s.get_value("relics_open"):
		_open_relic()
	if s.get_value("hats_place"):
		_place_hat()
	if s.get_value("sand_auto"):
		_spend_sand()


func _on_setting_changed(key: String) -> void:
	if key == "protect_legendary" and !s.get_value(key):
		_unprotect_all()


func _play_timer_game() -> void:
	if !is_instance_valid(GM.sand):
		return
	var g: SandGameController = GM.sand.game
	if !is_instance_valid(g):
		return
	if g.playing:
		if g.sm_game_state == SandGameController.GameState.TIMER_RUNNING and g.time_sec_left <= TIMER_STOP_AT_SEC:
			g.timer_input_stop()
	elif g.playable and GM.sand.is_unlocked:
		g.game_start()


## Every relic minigame extends UIMiniGame and stores its solution in
## answer_correct; the game's own MINI_GAME_AUTO_TIME upgrade submits it the same way.
func _solve_relic_minigame() -> void:
	if !is_instance_valid(GM.mini_games) or !GM.mini_games.playing:
		_mg_scene = null
		return
	var mg: UIMiniGame = GM.mini_games.current_ui_scene
	if !is_instance_valid(mg) or mg.won or mg.answer_correct.is_empty():
		return
	var now := Time.get_ticks_msec()
	if _mg_scene != mg:
		_mg_scene = mg
		_mg_answer_at_msec = now + MG_ANSWER_DELAY_MSEC
	if now >= _mg_answer_at_msec and !mg.input_locked:
		mg.line_edit.text = mg.answer_correct
		mg._request_answer_check(mg.answer_correct)


func _grab_coffee() -> void:
	if !is_instance_valid(GM.coffee) or !GM.coffee.bean_is_active or GM.coffee.effect_is_active:
		return
	var bean: UICoffeeBean = GM.ui.coffee.coffee_bean
	if is_instance_valid(bean) and bean.is_active and !bean.is_clicked:
		bean._on_pressed()


func _open_chests() -> void:
	if !GM.wc.world_exists or !is_instance_valid(GM.wc.world) or !is_instance_valid(GM.chest):
		return
	for n in GM.wc.world.y_depth.get_children():
		var chest := n as ChestWorld
		if chest == null or chest.is_queued_for_deletion():
			continue
		# is_unlocked means the key is owned; wait for the appear animation to finish.
		if chest.is_unlocked and chest.visible and !chest.ap.is_playing():
			GM.chest.chest_input(chest)
			chest_opened.emit()


func _skip_popup() -> void:
	var badges: BadgesController = GM.badges
	if !is_instance_valid(badges) or !badges.ui_reward_active:
		return
	var icon = badges.ui_badge_unlock.badge_icon
	# badge_key is set a frame after the popup opens (deferred setup).
	if !is_instance_valid(icon) or icon.badge_key.is_empty():
		return
	var is_achievement: bool = badges.badge_is_meta(icon.badge_key)
	if s.get_value("skip_popup_achievements" if is_achievement else "skip_popup_relics"):
		badges.input_close()


## Bought hats wait in the hat picker until a pal is chosen. This picks a free
## pal the hat helps (features/hats.gd), names it and confirms, the same as
## clicking the pal, typing a name and pressing Enter.
func _place_hat() -> void:
	var hm = GM.ui.hat_mode
	var que: Array[String] = GM.hat.hats_que
	if !is_instance_valid(hm) or !hm.is_active or que.is_empty():
		_hat_at_msec = 0
		return
	var now := Time.get_ticks_msec()
	if _hat_at_msec == 0:
		_hat_at_msec = now + HAT_DELAY_MSEC
	if now < _hat_at_msec:
		return
	# The player is naming a pal themselves.
	if hm.line_edit.has_focus():
		return

	var free := {}
	for sel in hm.all_selections:
		if !is_instance_valid(sel) or sel.is_queued_for_deletion() or sel.is_disabled:
			continue
		if !is_instance_valid(sel.node_world) or sel.node_world.hat_enabled:
			continue
		var pal: String = sel.node_world.node_data.key
		if !free.has(pal):
			free[pal] = sel

	for i in que.size():
		var pref = s.get_value("hat_" + que[i])
		for pal in Hats.pal_order(que[i], pref if pref is String else Hats.BEST_FIT):
			if !free.has(pal):
				continue
			_hat_at_msec = now + HAT_DELAY_MSEC
			if i > 0:
				# The picker only offers the first hat in the queue, so bring this one forward.
				for _n in i:
					que.push_back(que.pop_front())
				hm.toggle_start()
				return
			free[pal].on_pressed.emit()
			hm.line_edit.text = _new_pal_name()
			hm.toggle_confirm()
			return


func _new_pal_name() -> String:
	if _credit_names.is_empty():
		_credit_names = Hats.credit_names()
	var taken := {}
	for guy in get_tree().get_nodes_in_group("GUY"):
		if !str(guy.nametag).is_empty():
			taken[str(guy.nametag).to_upper()] = true
	return Hats.pick_name(taken, _credit_names)


## Sand only flows into upgrades that are switched on (focused) in the Sand Mines panel.
func _spend_sand() -> void:
	var sand = GM.sand
	if !is_instance_valid(sand) or !sand.active:
		return
	var open := []
	for slot in sand.slots:
		if !slot.is_locked and !slot.is_max_level:
			open.append(slot)
	for slot in sand.slots:
		var want := open.has(slot)
		if slot.is_focused != want and is_instance_valid(slot.ui_sand_slot):
			slot.ui_sand_slot._set_focus(want)


## One relic at a time, with the game's own progress bar. Minigame relics only
## while the solver is on, so a minigame never pops up unexpectedly.
func _open_relic() -> void:
	for st: ItemStack in GM.inv.item_stacks:
		if st.is_relic:
			_guard_stack_delete(st)
	if GM.mini_games.playing or GM.badges.ui_reward_active:
		return
	for st: ItemStack in GM.inv.item_stacks:
		if st.is_relic and st.action_load.is_running:
			return
	for st: ItemStack in GM.inv.item_stacks:
		if !st.is_relic or st.is_locked or st.amount <= 0 or !is_instance_valid(st.ui_item):
			continue
		if GM.inv.item_is_game(st.key) and !s.get_value("relic_mg_solve"):
			continue
		st.action_load.set_type("DIRT_AUTOPILOT").set_sell_amount(0) \
			.set_particles_pos(st.ui_item.pos_mid / 2.0).set_time(RELIC_OPEN_SEC).start_timer()
		relic_opened.emit()
		return


## Game bug workaround: opening the last relic of a stack runs from a timer, and
## the stack is deleted at the start of the next frame. ItemStack._inv_delete()
## nulls action_load before its inventory icon is freed, so the icon's _process
## (ui_item.gd: action_load.get_progress_perc()) hits null. on_deleted is emitted
## first in _inv_delete, so stopping the icon there closes the gap.
func _guard_stack_delete(st: ItemStack) -> void:
	var cb := _on_relic_stack_deleted.bind(st)
	if !st.on_deleted.is_connected(cb):
		st.on_deleted.connect(cb, CONNECT_ONE_SHOT)


func _on_relic_stack_deleted(st: ItemStack) -> void:
	if is_instance_valid(st.ui_item):
		st.ui_item.set_process(false)


## Fox pals skip locked items, so legendary stacks get locked. The game doesn't
## save locks, so they're re-applied continuously.
func _protect_legendary() -> void:
	for st: ItemStack in GM.inv.item_stacks:
		if st.rarity == "LEGENDARY" and !st.is_locked:
			st.__lock_toggle(true)
			_locked_by_us[st.get_instance_id()] = st


func _unprotect_all() -> void:
	for st in _locked_by_us.values():
		if is_instance_valid(st) and st.is_locked and !st.action_load.is_running:
			st.__lock_toggle(false)
	_locked_by_us.clear()


## Sell All ignores locks, so while protection is on its button is re-wired to
## _sell_all_protected() and restored when it's turned off.
func _update_sell_all_guard() -> void:
	if !is_instance_valid(GM.inv) or !is_instance_valid(GM.inv.ui):
		return
	var want: bool = s.get_value("protect_legendary")
	if want == _sell_all_swapped:
		return
	var sig: Signal = GM.inv.ui.on_request_sell_all
	var vanilla := Callable(GM.inv, "sell_all_stacks")
	var ours := Callable(self, "_sell_all_protected")
	if want:
		if sig.is_connected(vanilla):
			sig.disconnect(vanilla)
		if !sig.is_connected(ours):
			sig.connect(ours)
	else:
		if sig.is_connected(ours):
			sig.disconnect(ours)
		if !sig.is_connected(vanilla):
			sig.connect(vanilla)
	_sell_all_swapped = want


## Copy of Inv.sell_all_stacks() that also skips locked stacks.
func _sell_all_protected() -> void:
	var has_sell := false
	for st: ItemStack in GM.inv.item_stacks.duplicate():
		if st.is_relic or st.is_locked:
			continue
		var sold: int = Inv.CmdSell.new(st).set_particles_pos(st.ui_item.global_position / 2).set_sfx_enabled(false).execute()
		has_sell = has_sell or sold > 0
	if has_sell:
		GM.audio.sfx.play_preload("ItemSell")
