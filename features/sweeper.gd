extends Node
## Moves the game's hover circle (CursorNodeWorld) onto ready tools; the real
## mouse is never moved. When no tool is ready, the circle follows the mouse.

## Shapes must overlap by at least this much (px) to count as covered.
const MARGIN := 2.0
## Extra wait on top of a tool's own hover time before giving up on it.
const STUCK_EXTRA_SEC := 0.25
## A tool that didn't trigger in time is skipped for this long.
const SKIP_SEC := 1.5

var enabled := false
var min_hold_sec := 0.0

var cursor: CursorNodeWorld
var world: World

var holding := false
var target := Vector2.ZERO
var covered: Array[ToolNodeWorld] = []
var _hold_start_msec := 0
var _hold_start_physics := 0
var _deadline_msec := 0

var _physics_frames := 0
var _skip_until: Dictionary = {}
var _shape_cache: Dictionary = {}

var stops := 0
var triggers := 0
var ready_count := 0


func _ready() -> void:
	# After CursorNodeWorld._process, which snaps the circle back to the mouse.
	process_priority = 1000


func _physics_process(_delta: float) -> void:
	_physics_frames += 1


func set_enabled(on: bool) -> void:
	enabled = on
	_release()


func _release() -> void:
	holding = false
	covered.clear()


func _process(_delta: float) -> void:
	if !enabled:
		return
	# The game disables the circle's collision while a menu is open.
	if !_find_world() or !GM.is_playing() or cursor.col.disabled:
		_release()
		return

	var now := Time.get_ticks_msec()
	if holding and _hold_done(now):
		holding = false
	if !holding:
		_start_next(now)
	if holding:
		cursor.global_position = target


func _find_world() -> bool:
	if !GM.is_app_init or !is_instance_valid(GM.wc) or !GM.wc.world_exists or !is_instance_valid(GM.wc.world):
		return false
	if world != GM.wc.world:
		world = GM.wc.world
		cursor = null
		_shape_cache.clear()
		_skip_until.clear()
		_release()
	if !is_instance_valid(cursor) or !cursor.is_inside_tree():
		cursor = null
		for n in world.all_nodes:
			if is_instance_valid(n) and n is CursorNodeWorld:
				cursor = n
				break
	return cursor != null


func cursor_radius() -> float:
	if !is_instance_valid(cursor):
		return 0.0
	var s := cursor.col.shape as CircleShape2D
	var r := s.radius if s else CursorNodeWorld.RADIUS_BASE
	return r * absf(cursor.col.global_scale.x)


func _hold_done(now: int) -> bool:
	# Area overlaps are only detected on a physics step after the move.
	if _physics_frames - _hold_start_physics < 1:
		return false
	if now - _hold_start_msec < int(min_hold_sec * 1000.0):
		return false
	var pending := false
	for t in covered:
		if is_instance_valid(t) and !t.is_triggered:
			pending = true
			break
	if !pending:
		triggers += covered.size()
		return true
	if now >= _deadline_msec:
		for t in covered:
			if is_instance_valid(t) and !t.is_triggered:
				_skip_until[t.get_instance_id()] = now + int(SKIP_SEC * 1000.0)
		return true
	return false


func _start_next(now: int) -> void:
	var rc := cursor_radius()
	var items := ready_tools(now, rc)
	ready_count = items.size()
	if items.is_empty():
		return
	var pick := _pick_spot(items, rc)
	target = pick.pos
	covered.assign(pick.covered)
	# Some tools need to be hovered for a while (TRIGGER_DURATION) before they trigger.
	var max_dur := 0.0
	for t in covered:
		max_dur = maxf(max_dur, t._hover_sec_needed)
	_hold_start_msec = now
	_hold_start_physics = _physics_frames
	_deadline_msec = now + int((max_dur + STUCK_EXTRA_SEC) * 1000.0)
	holding = true
	stops += 1


## Landed, untriggered tools the cursor can trigger, as [{tool, pos, reach}].
func ready_tools(now: int, rc: float) -> Array:
	var out: Array = []
	if !is_instance_valid(world):
		return out
	for t in world.tools_grounded:
		if !is_instance_valid(t) or t.is_triggered or !t.can_trigger_by_cursor or !t.is_active_in_world:
			continue
		var id := t.get_instance_id()
		if _skip_until.has(id):
			if now < _skip_until[id]:
				continue
			_skip_until.erase(id)
		var cs := _tool_shape(t)
		if cs == null or cs.disabled:
			continue
		out.append({
			"tool": t,
			"pos": cs.global_position,
			"reach": rc + _shape_radius(cs) - MARGIN,
		})
	return out


func _tool_shape(t: ToolNodeWorld) -> CollisionShape2D:
	var id := t.get_instance_id()
	var cs = _shape_cache.get(id)
	if cs == null or !is_instance_valid(cs):
		cs = null
		if is_instance_valid(t.area_input):
			for c in t.area_input.get_children():
				if c is CollisionShape2D:
					cs = c
					break
		_shape_cache[id] = cs
	return cs


func _shape_radius(cs: CollisionShape2D) -> float:
	var sc := absf(cs.global_scale.x)
	var sh = cs.shape
	if sh is CircleShape2D or sh is CapsuleShape2D:
		return sh.radius * sc
	if sh is RectangleShape2D:
		return minf(sh.size.x, sh.size.y) * 0.5 * sc
	return 0.0


## Greedy cover: of each tool's position and the centroid of the tools around it,
## the spot covering the most tools. A grid keeps it cheap with hundreds of tools.
func _pick_spot(items: Array, rc: float) -> Dictionary:
	var max_reach := 0.0
	for it in items:
		max_reach = maxf(max_reach, it.reach)
	var cell := maxf(rc + max_reach, 8.0)
	var grid: Dictionary = {}
	for i in items.size():
		var k := _cell(items[i].pos, cell)
		if grid.has(k):
			grid[k].append(i)
		else:
			grid[k] = [i]

	var best: Array = []
	var best_pos: Vector2 = items[0].pos
	for i in items.size():
		var p: Vector2 = items[i].pos
		var near := _near(grid, _cell(p, cell))
		var cov := _covered_at(items, near, p)
		if cov.size() > best.size():
			best = cov
			best_pos = p
		var c := p
		for _step in 2:
			if cov.size() < 2:
				break
			var sum := Vector2.ZERO
			for j in cov:
				sum += items[j].pos
			c = sum / cov.size()
			cov = _covered_at(items, near, c)
			if cov.size() > best.size():
				best = cov
				best_pos = c

	var tools: Array = []
	for j in best:
		tools.append(items[j].tool)
	return {"pos": best_pos, "covered": tools}


func _cell(p: Vector2, cell: float) -> Vector2i:
	return Vector2i(floori(p.x / cell), floori(p.y / cell))


func _near(grid: Dictionary, k: Vector2i) -> Array:
	var out: Array = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var kk := k + Vector2i(dx, dy)
			if grid.has(kk):
				out.append_array(grid[kk])
	return out


func _covered_at(items: Array, idxs: Array, c: Vector2) -> Array:
	var out: Array = []
	for j in idxs:
		var it: Dictionary = items[j]
		if c.distance_to(it.pos) <= it.reach:
			out.append(j)
	return out
