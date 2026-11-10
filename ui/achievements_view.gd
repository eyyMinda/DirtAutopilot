extends VBoxContainer
## The achievement checklist: what's still missing, progress where the game
## counts it, which mod feature earns it, and "Do it" for the chores.

const ICON_PX := 32
const SMALL_SCALE := 0.8
const DONE_COLOR := Color(0.55, 0.85, 0.45)

var ach
var s

## For the settings fold's header; 0 until a save is loaded.
var done := 0
var total := 0
var _summary: Label
var _show_done: CheckButton
var _list: VBoxContainer
var _shown_state := ""
var _dynamic: Array = []


func setup(achievements, settings) -> void:
	ach = achievements
	s = settings
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var head := HBoxContainer.new()
	_summary = Label.new()
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_summary)
	_show_done = CheckButton.new()
	_show_done.text = "Show unlocked"
	_show_done.focus_mode = Control.FOCUS_NONE
	_show_done.toggled.connect(func(_on): refresh())
	head.add_child(_show_done)
	add_child(head)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	add_child(_list)

	ach.changed.connect(refresh)
	refresh()


## Rebuilds the rows when the set of shown achievements changes; otherwise
## only updates progress and buttons.
func refresh() -> void:
	if !ach.is_ready():
		_summary.text = "Load a save to see your achievements."
		done = 0
		total = 0
		_show_done.visible = false
		_rebuild([], "not ready")
		return
	_show_done.visible = true
	done = 0
	total = 0
	var shown := []
	for e in ach.LIST:
		if !GM.ach.key_exists(e.key):
			continue
		var owned: bool = ach.owned(e.key)
		total += 1
		done += int(owned)
		if !owned or _show_done.button_pressed:
			shown.append(e)
	_summary.text = "%d of %d unlocked" % [done, total]
	var state := str(shown.map(func(e): return e.key + str(ach.owned(e.key))))
	if state != _shown_state:
		_rebuild(shown, state)
	for d in _dynamic:
		_update_dynamic(d)


func _update_dynamic(d: Dictionary) -> void:
	var e: Dictionary = d.entry
	if d.node is Button:
		var why: String = ach.action_blocker(e)
		d.node.disabled = !why.is_empty() or !ach.busy.is_empty()
		d.node.text = "Working…" if ach.busy == e.action else "Do it"
		d.node.tooltip_text = why
	else:
		d.node.text = ach.progress(e.key)


func _rebuild(entries: Array, state: String) -> void:
	_shown_state = state
	_dynamic.clear()
	for c in _list.get_children():
		c.queue_free()
	if entries.is_empty() and state != "not ready":
		_list.add_child(_small("All of them. Nice.", true))
	for e in entries:
		_list.add_child(_row(e))


func _row(e: Dictionary) -> Control:
	var owned: bool = ach.owned(e.key)
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.22)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)

	var icon := TextureRect.new()
	icon.texture = ach.icon(e.key)
	icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if !owned:
		icon.modulate = Color(0.45, 0.45, 0.45)
	row.add_child(icon)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	var name_l := Label.new()
	name_l.text = ach.title(e.key)
	if owned:
		name_l.add_theme_color_override("font_color", DONE_COLOR)
	text.add_child(name_l)
	text.add_child(_small(ach.description(e.key)))
	if !owned and e.has("auto"):
		var label: String = s.entry(e.auto).label
		text.add_child(_small(("Earned by: %s" if s.get_value(e.auto) else "Switch on \"%s\" to earn it.") % label))
	row.add_child(text)

	if owned:
		var check := Label.new()
		check.text = "✓"
		check.add_theme_color_override("font_color", DONE_COLOR)
		row.add_child(check)
	elif e.has("action"):
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(ach.do_action.bind(e))
		row.add_child(b)
		_dynamic.append({"node": b, "entry": e})
	else:
		var prog := Label.new()
		prog.modulate = Color(1, 1, 1, 0.75)
		row.add_child(prog)
		_dynamic.append({"node": prog, "entry": e})
	return p


func _small(text: String, center := false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.modulate = Color(1, 1, 1, 0.6)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.ready.connect(_shrink_font.bind(l), CONNECT_ONE_SHOT)
	return l


## The theme's font size is only known once the label is in the tree.
func _shrink_font(l: Label) -> void:
	l.add_theme_font_size_override("font_size", int(l.get_theme_font_size("font_size") * SMALL_SCALE))
