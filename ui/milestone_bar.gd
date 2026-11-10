extends Control
## Next milestone: a progress bar with the upcoming item's icon on its right
## ("?" when it's a random relic). Normally sits in the game's top-left Data
## column right under dirt per second (`in_column`), with the details card below
## it on hover; otherwise in the bottom-left of the play field, card above.

const SessionStats := preload("../core/session_stats.gd")

const WIDTH := 230
const MARGIN := 12
const PAD := 6
const ICON_PX := 28
const TIP_GAP := 4
## How fast the bar catches up with the real value; higher is snappier.
const BAR_EASE := 6.0
const FILL_COLOR := Color(0.85, 0.56, 0.21)
## The timeline is looked up this often; the bar still eases every frame.
const LOOKUP_SEC := 0.1

var progress
## Set before adding: true when placed inside the game's Data VBoxContainer.
var in_column := false

var _card: PanelContainer
var _icon: TextureRect
var _unknown: Label
var _bar: ProgressBar
var _tip: PanelContainer
var _details: Label
var _hovered := false
var _shown_key := ""
var _info: Dictionary = {}
var _lookup_t := 0.0


func _ready() -> void:
	# Fixed size, so nothing inside can change the layout.
	var h := ICON_PX + PAD * 2
	if in_column:
		custom_minimum_size = Vector2(WIDTH, h)
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	else:
		anchor_top = 1.0
		anchor_bottom = 1.0
		offset_left = MARGIN
		offset_right = MARGIN + WIDTH
		offset_bottom = -MARGIN
		offset_top = -MARGIN - h
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_card = _panel(0.8)
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	# PASS keeps hover working without eating clicks meant for the field.
	_card.mouse_filter = Control.MOUSE_FILTER_PASS
	_card.mouse_entered.connect(func(): _hovered = true)
	_card.mouse_exited.connect(func(): _hovered = false)
	add_child(_card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 10)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = FILL_COLOR
	fill.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fill)
	row.add_child(_bar)

	var slot := Control.new()
	slot.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(slot)
	_icon = TextureRect.new()
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(_icon)
	_unknown = Label.new()
	_unknown.text = "?"
	_unknown.set_anchors_preset(Control.PRESET_FULL_RECT)
	_unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unknown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_unknown.add_theme_font_size_override("font_size", 22)
	_unknown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(_unknown)

	# Grows away from the bar (down in the column, up in the corner), so the
	# bar itself never moves.
	_tip = _panel(0.92)
	_tip.anchor_right = 1.0
	if in_column:
		_tip.anchor_top = 1.0
		_tip.anchor_bottom = 1.0
		_tip.offset_top = TIP_GAP
		_tip.offset_bottom = TIP_GAP
		_tip.grow_vertical = Control.GROW_DIRECTION_END
		# Over the rows below it (play time).
		_tip.z_index = 1
	else:
		_tip.offset_top = -TIP_GAP
		_tip.offset_bottom = -TIP_GAP
		_tip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	add_child(_tip)
	_details = Label.new()
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(_details)


func _panel(alpha: float) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.07, 0.05, alpha)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(PAD)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _process(delta: float) -> void:
	_lookup_t -= delta
	if _lookup_t <= 0.0:
		_lookup_t = LOOKUP_SEC
		_info = progress.next_milestone() if GM.is_app_init and GM.is_playing() else {}
	var info := _info
	visible = !info.is_empty()
	if info.is_empty():
		_shown_key = ""
		_hovered = false
		_tip.visible = false
		return

	# Includes the goal, so back-to-back random relics still restart the bar at 0.
	var key := "%s:%s:%s" % [info.kind, info.key, info.goal]
	if key != _shown_key:
		_shown_key = key
		_icon.texture = info.icon
		_icon.visible = info.icon != null
		_unknown.visible = info.icon == null
		_bar.value = info.progress
	_bar.value = lerpf(_bar.value, info.progress, 1.0 - exp(-BAR_EASE * delta))

	_tip.visible = _hovered
	if _hovered:
		_details.text = "Next: %s\n%s / %s dirt dug (%d%%)" % [
			info.name, SessionStats._num(info.amount), SessionStats._num(info.goal), int(info.progress * 100.0)]
