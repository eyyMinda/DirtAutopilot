extends CanvasLayer
## A card with an icon, a title and a description below both. Alerts queue up
## and show one at a time; clicking a card runs its action and closes it.
## Centered at the top of the play field, or of the screen if there's no field.

const WIDTH := 360
const TOP := 24
const ICON_PX := 32
const FADE_SEC := 0.3
const PAD := 12
const ICON_GAP := 10

var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _panel: PanelContainer
var _icon: TextureRect
var _title: Label
var _desc: Label
var _tween: Tween
## The play field to center on; set by mod_main once the game's UI exists.
var field: Control


func _ready() -> void:
	layer = 127

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.07, 0.05, 0.94)
	sb.border_color = Color(0.85, 0.56, 0.21)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(PAD)
	_panel.add_theme_stylebox_override("panel", sb)
	# Without a minimum width, resizing to fit would squeeze the text into a column.
	_panel.custom_minimum_size = Vector2(WIDTH, 0)
	_panel.gui_input.connect(_on_gui_input)
	_panel.visible = false
	add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", ICON_GAP)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_icon)

	# Wrapping labels need a known width, or they report a column-tall height
	# before the first layout and the card grows to the bottom of the screen.
	_title = Label.new()
	_title.custom_minimum_size.x = WIDTH - PAD * 2 - ICON_PX - ICON_GAP
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_title)

	_desc = Label.new()
	_desc.custom_minimum_size.x = WIDTH - PAD * 2
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.modulate = Color(1, 1, 1, 0.75)
	_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_desc)


## action: called when the card is clicked; leave empty for click-to-close.
func push(icon: Texture2D, title: String, desc: String, action := Callable(), seconds := 8.0) -> void:
	_queue.append({"icon": icon, "title": title, "desc": desc, "action": action, "seconds": seconds})
	if _current.is_empty():
		_show_next()


func _show_next() -> void:
	_current = {}
	if _queue.is_empty():
		_panel.visible = false
		return
	_current = _queue.pop_front()
	_icon.texture = _current.icon
	_icon.visible = _current.icon != null
	_title.text = _current.title
	_desc.text = _current.desc
	_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _current.action.is_valid() else Control.CURSOR_ARROW
	# Shrink back to the content after a taller alert.
	_fit.call_deferred()
	_panel.modulate.a = 0.0
	_panel.visible = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, FADE_SEC)
	_tween.tween_interval(_current.seconds)
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE_SEC)
	_tween.tween_callback(_show_next)


## Shrinks the card back to its content; a free-floating Control never shrinks on its own.
func _fit() -> void:
	_panel.size = Vector2(WIDTH, 0)
	_place()


func _process(_delta: float) -> void:
	if _panel.visible:
		_place()


## Every frame while shown, so it follows window and resolution changes.
func _place() -> void:
	var area := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	if is_instance_valid(field) and field.is_visible_in_tree():
		area = field.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, field.size)
	_panel.position = Vector2(area.get_center().x - WIDTH / 2.0, area.position.y + TOP)


func _on_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or !mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or _current.is_empty():
		return
	_panel.accept_event()
	var action: Callable = _current.action
	if _tween:
		_tween.kill()
	_show_next()
	if action.is_valid():
		action.call()
