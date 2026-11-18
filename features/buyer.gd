extends Node
## Spends dirt on the shop and the skill tree, best value first.
##
## Every buyable thing gets a payback time: cost / dirt per second it adds. The
## added dirt/s comes from what each tool really earned this run (SessionStats):
## one more tool of a kind adds that kind's dirt/s per tool, an upgrade adds its
## relative step of that kind's dirt/s. Unlocks get a flat share of all dirt/s.
## Upgrades of a tool or pal you own none of are worth nothing until you buy one.
## It buys the shortest payback, but waits instead when that one is affordable
## within SAVE_SEC, so cheap filler doesn't keep it from ever saving up.
##
## Buying is done in bursts: after each purchase only the bought item is scored
## again, so early in a fast run it buys dozens per tick instead of one.
## Purchases go through the buttons' own signal, exactly like a click.

signal bought(text: String, cost: float)

const TICK_SEC := 0.1
## Most purchases in one tick (a fresh run with lots of dirt).
const BURST := 300
## Wait for the best item when it's affordable within this long.
const SAVE_SEC := 30.0
## Unknown tools (none bought yet / no data) count as this many average tools.
const FIRST_UNIT := 2.0
## Shares of all dirt/s for things with no dirt of their own.
const UNLOCK_SHARE := 0.25
const USE_SHARE := 0.05
const HAT_SHARE := 0.03
const PAL_SHARE := 0.05
## Items and worms aren't dirt: their upgrades count for this much.
const SIDE_WEIGHT := 0.2
const FOX := "FOX_GUY"
const BAG_ACHIEVEMENTS := ["FULL_BAG", "LEGENDARY_BAG"]
## Same item bought within this long is one history line ("Spoon x12").
const MERGE_MSEC := 5000
const HISTORY_MAX := 20

var s
var stats

## Best first: {name, cost, payback, eta, btn, shop}. Read by the Autopilot tab.
var plan: Array = []
## Newest last: {text, count, cost, time}.
var history: Array = []
## Every shop item at its max / every dirt skill-tree upgrade maxed (this run).
var shop_done := false
var tree_done := false

var _t := 0.0
## Per tick: node dirt/s, all dirt/s, average dirt/s of one tool.
var _dps: Dictionary = {}
var _total := 1.0
var _avg_unit := 1.0


func setup(settings, session_stats) -> void:
	s = settings
	stats = session_stats


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK_SEC
	if !GM.is_app_init or !GM.is_playing() or !is_instance_valid(GM.upgrades):
		plan.clear()
		return
	_measure()
	plan = _candidates()
	if s.get_value("shop_buy"):
		_burst()


## Whether fox pals are off-limits right now: while the setting is on and the
## stack achievements foxes would undo aren't owned yet.
func skip_fox() -> bool:
	if !s.get_value("shop_no_fox"):
		return false
	for key in BAG_ACHIEVEMENTS:
		if GM.ach.key_exists(key) and !GM.ach.key_owned(key):
			return true
	return false


## Buys while the best affordable item is worth it; after each purchase only that
## item is scored again and put back in order.
func _burst() -> void:
	for n in BURST:
		if plan.is_empty():
			return
		var dirt: float = GM.player.currency_amount("DIRT")
		var best: Dictionary = plan[0]
		if best.cost > dirt and best.eta <= SAVE_SEC:
			return
		var i := -1
		for j in plan.size():
			if plan[j].cost <= dirt:
				i = j
				break
		if i < 0:
			return
		var c: Dictionary = plan[i]
		if !is_instance_valid(c.btn):
			plan.remove_at(i)
			continue
		c.btn.on_pressed_buy.emit(false)
		_log(c.name, c.cost)
		plan.remove_at(i)
		var again := _score(c.btn, c.shop)
		if !again.is_empty():
			_insert(again)


func _log(text: String, cost: float) -> void:
	var now := Time.get_ticks_msec()
	if !history.is_empty() and history[-1].text == text and now - history[-1].time < MERGE_MSEC:
		history[-1].count += 1
		history[-1].cost += cost
		history[-1].time = now
	else:
		history.append({"text": text, "count": 1, "cost": cost, "time": now})
		if history.size() > HISTORY_MAX:
			history.pop_front()
	bought.emit(text, cost)


func _insert(c: Dictionary) -> void:
	for j in plan.size():
		if c.payback < plan[j].payback:
			plan.insert(j, c)
			return
	plan.append(c)


## Dirt/s per node key over the last minute (tools and pals that dig), the total,
## and the average per tool.
func _measure() -> void:
	_dps = {}
	if stats != null:
		for t in stats.tools():
			_dps[t.key] = t.per_sec
	var total := 0.0
	var units := 0
	for key in _dps:
		total += _dps[key]
		var nd = GM.data.node_data_get(key)
		if nd and nd.is_tool:
			units += maxi(nd.stat_count_amount(false), 1)
	_total = maxf(total, 1.0)
	_avg_unit = _total / maxf(units, 1.0)


func _candidates() -> Array:
	var out: Array = []
	var shop = GM.upgrades.ui_shop
	shop_done = is_instance_valid(shop)
	tree_done = GM.upgrades.has_skill_tree
	if is_instance_valid(shop):
		for key in shop.key_to_btn:
			var btn = shop.key_to_btn[key]
			if !is_instance_valid(btn) or !btn.is_setup:
				continue
			if !btn.visible or !btn.is_max_level:
				shop_done = false
			var c := _score(btn, true)
			if !c.is_empty():
				out.append(c)
	if GM.upgrades.has_skill_tree:
		for btn in UIBtnSkillTree.All:
			if !is_instance_valid(btn) or btn.type != UIBtnSkillTree.Type.SKILL_TREE:
				continue
			var st = btn.stat_data
			if st == null or st.is_demo_lock or st.get_cost_type() != "DIRT":
				continue
			if !st.is_max_level():
				tree_done = false
			var c := _score(btn, false)
			if !c.is_empty():
				out.append(c)
	out.sort_custom(func(a, b): return a.payback < b.payback)
	return out


## One buyable thing with its payback, or {} when it can't or shouldn't be bought.
func _score(btn, is_shop: bool) -> Dictionary:
	var cost := 0.0
	var gain := 0.0
	var name := ""
	if is_shop:
		var key: String = btn.node_key
		if !btn.visible or btn.is_max_level or btn.cost_type != "DIRT":
			return {}
		if key == FOX and skip_fox():
			return {}
		if key.begins_with("HAT_") and !(s.get_value("shop_hats") and GM.hat.hats_que.is_empty()):
			return {}
		cost = btn.stat_count.get_cost()
		gain = _shop_gain(btn.node_data)
		name = tr(btn.node_data.name)
	else:
		var st = btn.stat_data
		if st.is_locked or st.is_max_level() or (btn.key_node == FOX and skip_fox()):
			return {}
		cost = st.get_cost()
		gain = _upgrade_gain(btn)
		name = "%s - %s" % [tr(btn.node_data.name), tr(st.name)]  # the game font has no ":"
	if gain <= 0.0:
		return {}
	var dirt: float = GM.player.currency_amount("DIRT")
	return {"name": name, "cost": cost, "payback": cost / gain,
		"eta": maxf(cost - dirt, 0.0) / _total, "btn": btn, "shop": is_shop}


func _shop_gain(nd) -> float:
	var key: String = nd.key
	if key == "SKILL_TREE":
		return _total * UNLOCK_SHARE
	if key.begins_with("HAT_"):
		return _total * HAT_SHARE
	var count: int = nd.stat_count_amount(false)
	var mine: float = _dps.get(key, 0.0)
	var gain := mine / count if count > 0 and mine > 0.0 else _avg_unit * FIRST_UNIT
	if !nd.is_tool and mine <= 0.0:
		gain = _total * PAL_SHARE  # pals that buff or sell earn no dirt of their own
	# Void tools fuse from three charged ones: favour completing a set.
	if nd.stat_get_value("VOID_UNLOCK", 0.0) == 1.0 and count % 3 == 2:
		gain *= 1.25
	return gain


func _upgrade_gain(btn) -> float:
	var st = btn.stat_data
	var key: String = btn.key_stat
	var nd = btn.node_data
	var mine: float = _dps.get(btn.key_node, 0.0)
	if key == "SHOP_UNLOCK":
		return _total * UNLOCK_SHARE
	# Upgrades of a shop tool or pal do nothing until you own one: the shop goes first.
	var is_shop_node: bool = GM.data.raw_data_nodes.get(btn.key_node, {}).get("IS_SHOP", 0) == 1
	if is_shop_node and nd.stat_count_amount(false) == 0:
		return 0.0
	if key.begins_with("USE_"):
		return _total * USE_SHARE
	if key == "COUNT_ADD":
		# Only worth it once the shop has run out of this one.
		if !nd.is_stat_count_max():
			return 0.0
		return (mine / maxi(nd.stat_count_amount(false), 1) if mine > 0.0 else _avg_unit) * 3.0
	var now: float = st.get_value()
	var step := absf(st.get_value(st.level + 1) - now)
	var rel := step / (1.0 + absf(now)) if st.value_type == "PERCENTAGE" else step / maxf(absf(now), 1.0)
	var base := mine if mine > 0.0 else _total * PAL_SHARE
	var gain := base * rel
	if key.begins_with("LUCK_") or key.begins_with("WORMS_"):
		gain *= SIDE_WEIGHT
	return gain
