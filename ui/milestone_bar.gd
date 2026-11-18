extends Control
## Two milestone bars side by side: NEXT RELIC (from the last relic reached, or 0,
## to the next one) and NEXT CHEST with its icon (hidden once every chest has been
## opened in earlier runs). Normally in the game's top-left Data column under the
## dirt and sand counters (`in_column`), details card below it on hover;
## otherwise in the bottom-left of the play field, card above.

const SessionStats := preload("../core/session_stats.gd")

const WIDTH := 230
const MARGIN := 12
const PAD := 6
const GAP := 6
const ICON_PX := 24
const CAPTION_PX := 11
const TIP_GAP := 4
const KINDS := ["relic", "chest"]
## How fast the bars catch up with the real value; higher is snappier.
const BAR_EASE := 6.0
const FILL_COLOR := Color(0.96, 0.76, 0.42)
## The timeline is looked up this often; the bars still ease every frame.
const LOOKUP_SEC := 0.1

var progress
## Set before adding: true when placed inside the game's Data VBoxContainer.
var in_column := false

var _card: PanelContainer
## kind -> {box, bar, icon}
var _parts: Dictionary = {}
var _tip: PanelContainer
var _details: Label
var _hovered := false
var _shown_key := ""
var _info: Dictionary = {}
var _lookup_t := 0.0


func _ready() -> void:
	# Fixed size, so nothing inside can change the layout.
	var h := ICON_PX + CAPTION_PX + PAD * 2 + 4
	if in_column:
		custom_minimum_size = Vector2(WIDTH, h + GAP)
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
	if in_column:
		_card.offset_top = GAP  # a little air under the dirt and sand counters
	# PASS keeps hover working without eating clicks meant for the field.
	_card.mouse_filter = Control.MOUSE_FILTER_PASS
	_card.mouse_entered.connect(_set_hovered.bind(true))
	_card.mouse_exited.connect(_set_hovered.bind(false))
	add_child(_card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)
	for kind in KINDS:
		_parts[kind] = _add_part(row, "NEXT " + kind.to_upper(), kind == "chest")

	# Grows away from the bars (down in the column, up in the corner), so the
	# bars themselves never move.
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


func _set_hovered(on: bool) -> void:
	_hovered = on


## Caption over [bar][icon]. Each part takes half the card.
func _add_part(row: HBoxContainer, caption: String, with_icon: bool) -> Dictionary:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", CAPTION_PX)
	cap.add_theme_color_override("font_color", FILL_COLOR)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(cap)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = FILL_COLOR
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	line.add_child(bar)

	var icon: TextureRect = null
	if with_icon:
		icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(icon)
	return {"box": box, "bar": bar, "icon": icon}


func _panel(alpha: float) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.07, 0.05, alpha)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(PAD)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func _fraction(amount: float, m: Dictionary) -> float:
	return clampf((amount - m.start) / maxf(m.goal - m.start, 1.0), 0.0, 1.0)


func _process(delta: float) -> void:
	_lookup_t -= delta
	if _lookup_t <= 0.0:
		_lookup_t = LOOKUP_SEC
		_info = progress.next_by_kind() if GM.is_app_init and GM.is_playing() else {}
	var info := _info
	visible = !info.is_empty() and !(info.relic.is_empty() and info.chest.is_empty())
	if !visible:
		_shown_key = ""
		_hovered = false
		_tip.visible = false
		return

	var amount: float = info.amount
	# Includes the goals, so back-to-back relics still restart the bar at 0.
	var key := "%s|%s" % [info.relic.get("goal", -1.0), info.chest.get("goal", -1.0)]
	var changed := key != _shown_key
	_shown_key = key
	var k := 1.0 - exp(-BAR_EASE * delta)
	for kind in KINDS:
		var part: Dictionary = _parts[kind]
		var m: Dictionary = info[kind]
		part.box.visible = !m.is_empty()
		if m.is_empty():
			continue
		var target := _fraction(amount, m)
		if changed:
			part.bar.value = target
			if part.icon:
				part.icon.texture = m.icon
		part.bar.value = lerpf(part.bar.value, target, k)

	_tip.visible = _hovered
	if _hovered:
		var lines: Array[String] = []
		for kind in KINDS:
			var m: Dictionary = info[kind]
			if m.is_empty():
				continue
			var what: String = "Next relic" if kind == "relic" else "Next chest - " + m.name
			if kind == "relic" and m.icon != null:
				what += " - " + m.name
			lines.append("%s\n   %s / %s dirt dug (%d%%)" % [what, SessionStats._num(amount),
				SessionStats._num(m.goal), int(_fraction(amount, m) * 100.0)])
		_details.text = "\n".join(lines)
