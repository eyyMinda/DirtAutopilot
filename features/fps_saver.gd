extends Node
## FPS savers for the late game, all switchable and fully undone when off.
##
## Flying dirt/worms: the game only adds a particle's dirt when it reaches the
## counter (ui_overlay_particles.gd, Point.end()), so the particles can't just be
## hidden. Their processing is switched off instead and every new particle is
## paid out at once. The per-particle loop in GDScript is what gets slow with
## thousands of tools.
##
## Effects: dust puffs, zap lines and item pops come from GM.pool and are purely
## visual, so their pooled nodes are kept hidden. Their tweens still finish and
## return them to the pool as usual.
##
## Clutter: buff icons (BuffUI, one _process each), pal nametags, stomp circles,
## sell amounts (GameTextPop) and the "+N" on inventory items. All visual only.
## Labels the game shows again by itself are guarded through visibility_changed.

const EFFECT_TYPES := ["DIG_EFFECT", "DIG_EFFECT_CRIT", "ZAP", "ITEM_POP"]

var s

var _particles_off := false
var _effects_off := false
## Pool sizes already hidden, so the pool is only walked again after it grows.
var _hidden_counts: Dictionary = {}

var _buffs_off := false
var _names_off := false
var _stomps_off := false
var _new_counts_off := false
## World nodes / item stacks already handled; walk again when these change.
var _world_id := 0
var _node_count := -1
var _stack_count := -1
var _rewalk_t := 0.0
var _stomp_parent: Node
var _sell_hooked := false
## Sell pops we hid; shown again once they're back in the pool.
var _hidden_pops: Array = []

const REWALK_SEC := 2.0


func setup(settings) -> void:
	s = settings


func _ready() -> void:
	# Before the overlay particles' own _process, so nothing is drawn first.
	process_priority = -1000


func _process(delta: float) -> void:
	if !GM.is_app_init or !is_instance_valid(GM.ui):
		return
	_update_particles(s.get_value("perf_no_particles"))
	_update_effects(s.get_value("perf_no_effects"))
	_rewalk_t -= delta
	var rewalk := _rewalk_t <= 0.0
	if rewalk:
		_rewalk_t = REWALK_SEC
	_update_world(rewalk)
	_update_inventory(rewalk)
	_update_sell_pops()


func _overlays() -> Array:
	var out := []
	for o in [GM.ui.overlay_particles_dirt, GM.ui.overlay_particles_worms]:
		if is_instance_valid(o):
			out.append(o)
	return out


func _update_particles(off: bool) -> void:
	if off != _particles_off:
		_particles_off = off
		for o in _overlays():
			o.set_process(!off)
			o.visible = !off
	if !off:
		return
	for o in _overlays():
		if o.points.is_empty():
			continue
		# Paying out can spawn new particles (signals), so work on a copy.
		var pts: Array = o.points.duplicate()
		o.points.clear()
		o.point_index_remove.clear()
		o.__flush()
		for p in pts:
			p.end()


func _update_effects(off: bool) -> void:
	if !is_instance_valid(GM.pool):
		return
	if off != _effects_off:
		_effects_off = off
		_hidden_counts.clear()
		if !off:
			_set_effects_visible(true)
	if !off:
		return
	for type in EFFECT_TYPES:
		var nodes: Array = GM.pool.nodes_type_all.get(type, [])
		if _hidden_counts.get(type, -1) != nodes.size():
			_hidden_counts[type] = nodes.size()
			for n in nodes:
				n.visible = false


func _set_effects_visible(on: bool) -> void:
	for type in EFFECT_TYPES:
		for n in GM.pool.nodes_type_all.get(type, []):
			n.visible = on


func _update_world(rewalk: bool) -> void:
	if !is_instance_valid(GM.wc) or !GM.wc.world_exists or !is_instance_valid(GM.wc.world):
		return
	var w = GM.wc.world
	var buffs: bool = s.get_value("perf_hide_buffs")
	var names: bool = s.get_value("perf_hide_names")
	var stomps: bool = s.get_value("perf_hide_stomps")

	var toggled := buffs != _buffs_off or names != _names_off
	var grew: bool = w.get_instance_id() != _world_id or w.all_nodes.size() != _node_count
	# With both off, new nodes are already in the game's default state.
	if toggled or ((grew or rewalk) and (buffs or names)):
		_world_id = w.get_instance_id()
		_node_count = w.all_nodes.size()
		_buffs_off = buffs
		_names_off = names
		for n in w.all_nodes:
			if !is_instance_valid(n):
				continue
			_apply_buffs(n, buffs)
			if n is GuyNodeWorld and is_instance_valid(n.nametag_label):
				_guard(n.nametag_label, "perf_hide_names")
				n.nametag_label.visible = !names and !n.nametag.is_empty()

	if _stomp_parent != w.bot_low:
		_stomp_parent = w.bot_low
		_stomp_parent.child_entered_tree.connect(_on_stomp_added)
		_stomps_off = !stomps # apply to what's already there
	if stomps != _stomps_off:
		_stomps_off = stomps
		for c in _stomp_parent.get_children():
			_apply_stomp(c, stomps)


func _apply_buffs(n: Node, off: bool) -> void:
	var con = n.buff_ui_container
	if !is_instance_valid(con):
		return
	con.visible = !off
	# BuffUI updates its shader every frame even when hidden.
	con.process_mode = Node.PROCESS_MODE_DISABLED if off else Node.PROCESS_MODE_INHERIT


func _on_stomp_added(node: Node) -> void:
	if s.get_value("perf_hide_stomps"):
		_apply_stomp(node, true)


func _apply_stomp(node: Node, off: bool) -> void:
	if node is Stomp:
		var c := node.get_node_or_null("Body/Circle") as CanvasItem
		if c:
			c.visible = !off


func _update_inventory(rewalk: bool) -> void:
	if !is_instance_valid(GM.inv):
		return
	var off: bool = s.get_value("perf_hide_new_counts")
	var grew: bool = GM.inv.item_stacks.size() != _stack_count
	if off == _new_counts_off and !(off and (grew or rewalk)):
		return
	_new_counts_off = off
	_stack_count = GM.inv.item_stacks.size()
	for st in GM.inv.item_stacks:
		var ui = st.ui_item
		if !is_instance_valid(ui) or !is_instance_valid(ui.label_new):
			continue
		_guard(ui.label_new, "perf_hide_new_counts")
		ui.label_new.visible = !off and ui.amount_new > 0


## Hides `node` whenever the game shows it while `key` is on.
func _guard(node: CanvasItem, key: String) -> void:
	if node.has_meta("dap_guard"):
		return
	node.set_meta("dap_guard", true)
	node.visibility_changed.connect(_on_guarded_visibility.bind(node, key))


func _on_guarded_visibility(node: CanvasItem, key: String) -> void:
	if node.visible and s.get_value(key):
		node.set_deferred("visible", false)


func _update_sell_pops() -> void:
	if !_sell_hooked and is_instance_valid(GM.inv):
		_sell_hooked = true
		GM.inv.on_sell.connect(_on_sell)
	for i in range(_hidden_pops.size() - 1, -1, -1):
		var p = _hidden_pops[i]
		if !is_instance_valid(p):
			_hidden_pops.remove_at(i)
		elif p.get_parent() == GM.pool:
			p.visible = true
			_hidden_pops.remove_at(i)


## CmdSell creates its GameTextPop right before emitting on_sell, so it's the
## newest active one (only while the inventory tab is open, like the game).
func _on_sell() -> void:
	if !s.get_value("perf_hide_sell_pops") or !is_instance_valid(GM.pool):
		return
	if GM.ui.game.tab_type_current != UIGame.TabType.INV:
		return
	var active: Array = GM.pool.nodes_type_active.get("GAME_TEXT_POP", [])
	if active.is_empty():
		return
	var p = active.back()
	if is_instance_valid(p) and p.get_parent() == GM.ui.base and p.visible:
		p.visible = false
		_hidden_pops.append(p)
