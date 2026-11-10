extends RefCounted
## Picks the prestige upgrade worth buying next. The scores are a judgement
## call, weighted towards what this mod's automations get the most out of:
## new worlds and dirt multipliers first, the cursor radius while auto-sweep is
## on, sand upgrades since the timer game is always PERFECT, and nothing for
## minigame auto-solve while the mod solves them itself.

## An upgrade is also worth what it leads to: it gets this share of the best
## score among the upgrades it unlocks.
const UNLOCK_SHARE := 0.9


static func score(btn, s) -> float:
	var node: String = btn.key_node
	var stat: String = btn.key_stat
	if node == "WORLD" or (node == "SAND" and stat == "SHOP_UNLOCK"):
		return 100.0
	if node == "PASSIVE" and stat == "DIRT_MULTIPLY":
		return 90.0
	if node.ends_with("_GUY") and stat == "ACTIONS_MULTIPLY":
		return 85.0
	if node.ends_with("_GUY") and node != "FOX_GUY" and stat == "COUNT_ADD":
		return 80.0
	if node == "CURSOR":
		return 75.0 if s.get_value("sweep_enabled") else 60.0
	if node == "SAND":
		return 70.0
	if node == "PASSIVE" and stat == "MINI_GAME_AUTO_TIME":
		return 5.0 if s.get_value("relic_mg_solve") else 60.0
	if node == "FOX_GUY" and stat == "SELL_ITEMS_LEGENDARY":
		return 5.0 if s.get_value("protect_legendary") else 40.0
	if stat == "SHOP_UNLOCK":
		return 60.0
	if node.begins_with("HAT_"):
		return 55.0
	if node.ends_with("_DISCOUNT"):
		return 50.0
	if node == "PASSIVE" and stat == "SELL_ITEMS_MULTIPLY":
		return 45.0
	if node == "FOX_GUY":
		return 40.0
	return 30.0


## Prestige tree buttons that can be bought now or later (not maxed), with worms.
static func open_upgrades() -> Array:
	var out := []
	for btn in UIBtnSkillTree.All:
		if !is_instance_valid(btn) or btn.type != UIBtnSkillTree.Type.PRESTIGE_TREE:
			continue
		var st = btn.stat_data
		if st == null or st.is_demo_lock or st.is_max_level() or st.get_cost_type() != "WORMS":
			continue
		out.append(btn)
	return out


## The best upgrade that's unlocked in the tree and costs at most budget worms, or null.
static func best(budget: float, s) -> Object:
	var open := open_upgrades()
	var children := {}
	for btn in open:
		var parent = btn.lock_by_btn
		if is_instance_valid(parent):
			children.get_or_add(parent, []).append(btn)
	var memo := {}
	var pick = null
	var pick_score := -1.0
	for btn in open:
		if btn.stat_data.is_locked:
			continue
		var cost: float = btn.stat_data.get_cost()
		if cost > budget:
			continue
		var sc := _value(btn, children, memo, s)
		if sc > pick_score or (sc == pick_score and cost < pick.stat_data.get_cost()):
			pick = btn
			pick_score = sc
	return pick


static func _value(btn, children: Dictionary, memo: Dictionary, s) -> float:
	if memo.has(btn):
		return memo[btn]
	memo[btn] = 0.0
	var v := score(btn, s)
	for child in children.get(btn, []):
		v = maxf(v, _value(child, children, memo, s) * UNLOCK_SHARE)
	memo[btn] = v
	return v


## "Overall: dirt boost", or the world's name for world unlocks.
static func display_name(btn) -> String:
	var stat_name := TranslationServer.translate(btn.stat_data.name)
	if btn.key_node == "WORLD":
		return _cap(stat_name)
	return "%s: %s" % [_cap(TranslationServer.translate(btn.node_data.name)), stat_name]


static func _cap(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)
