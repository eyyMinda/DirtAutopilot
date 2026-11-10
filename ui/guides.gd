extends Node2D

const COL_READY := Color(1, 1, 1, 0.55)
const COL_COVERED := Color(0.35, 1.0, 0.45, 0.95)
const COL_RING := Color(0.35, 1.0, 0.45, 0.8)

var sweeper


func _ready() -> void:
	top_level = true
	z_index = 4000
	z_as_relative = false


func _process(_delta: float) -> void:
	# Drawn in the cursor's parent so it shares the world's canvas transform.
	var c: Node = sweeper.cursor
	if is_instance_valid(c) and get_parent() != c.get_parent():
		reparent.call_deferred(c.get_parent(), false)
	global_position = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if !is_instance_valid(sweeper.cursor):
		return
	var rc: float = sweeper.cursor_radius()
	# While auto-sweep runs it already scans every frame; reuse that list.
	var ready: Array = sweeper.last_ready if sweeper.enabled else sweeper.ready_tools(Time.get_ticks_msec(), rc)
	for it in ready:
		if is_instance_valid(it.tool) and !it.tool.is_triggered:
			draw_circle(it.pos, 4.0, COL_READY)
	if sweeper.holding:
		draw_arc(sweeper.target, rc, 0.0, TAU, 64, COL_RING, 2.0)
		for t in sweeper.covered:
			if is_instance_valid(t) and !t.is_triggered:
				draw_circle(t.global_position, 6.0, COL_COVERED)
