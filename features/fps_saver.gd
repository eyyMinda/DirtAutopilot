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

const EFFECT_TYPES := ["DIG_EFFECT", "DIG_EFFECT_CRIT", "ZAP", "ITEM_POP"]

var s

var _particles_off := false
var _effects_off := false
## Pool sizes already hidden, so the pool is only walked again after it grows.
var _hidden_counts: Dictionary = {}


func setup(settings) -> void:
	s = settings


func _ready() -> void:
	# Before the overlay particles' own _process, so nothing is drawn first.
	process_priority = -1000


func _process(_delta: float) -> void:
	if !GM.is_app_init or !is_instance_valid(GM.ui):
		return
	_update_particles(s.get_value("perf_no_particles"))
	_update_effects(s.get_value("perf_no_effects"))


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
