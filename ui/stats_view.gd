extends VBoxContainer
## Session stats for the game's narrow right panel (~240 px): Run / All time
## buttons, a headline card (play time large, dirt earned and dirt per hour
## side by side), in the Run view the tools ranked by dirt, then grouped cards
## of one-line rows (icon, name, value on the right). Long names are shortened
## with "…" instead of widening the panel.

const ICON_PX := 20
const HERO_PX := 30
const HERO_SMALL_PX := 18
const ROW_PX := 16
const CAPTION_PX := 14
const FAINT := Color(1, 1, 1, 0.6)
const ROW_ALT := Color(1, 1, 1, 0.05)
const CARD_BG := Color(0, 0, 0, 0.3)
const CARD_BORDER := Color(1, 1, 1, 0.08)
const BAR_BG := Color(1, 1, 1, 0.12)
const BAR_FILL := Color(1, 1, 1, 0.55)

var stats

var _hero_values: Array[Label] = []
## One entry per tile: {panel, style, label, value, group}.
var _rows: Array[Dictionary] = []
var _tools_title: Control
var _tools_card: Control
var _tools_list: VBoxContainer
var _tools_empty: Label
## Reused tool rows: {panel, style, icon, name, share, fill, rest, info}.
var _tool_rows: Array[Dictionary] = []
var _textures: Dictionary = {}


func setup(session_stats) -> void:
	stats = session_stats
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_add_view_buttons()
	_add_hero(stats.hero())
	_add_tools()

	var rows: VBoxContainer
	var group := -1
	for item in stats.tiles():
		if item.has("group") or rows == null:
			_add_group_title(item.get("group", ""))
			var card := _card(4)
			rows = VBoxContainer.new()
			rows.add_theme_constant_override("separation", 0)
			card.add_child(rows)
			add_child(card)
			group += 1
		var row := _row(item)
		row.group = group
		rows.add_child(row.panel)
		_rows.append(row)

	refresh()


## Run (default) / All time, side by side above the headline card.
func _add_view_buttons() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for i in 2:
		var b := Button.new()
		b.text = "All time" if i == 1 else "Run"
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = (i == 1) == stats.show_all
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggled.connect(func(on: bool):
			if on:
				stats.show_all = i == 1
				refresh())
		row.add_child(b)
	add_child(row)


func refresh() -> void:
	var hero: Array = stats.hero()
	for i in mini(hero.size(), _hero_values.size()):
		_hero_values[i].text = hero[i].value
	var tiles: Array = stats.tiles()
	var alt := false
	var group := -1
	for i in mini(tiles.size(), _rows.size()):
		var row: Dictionary = _rows[i]
		if row.group != group:
			group = row.group
			alt = false
		row.label.text = tiles[i].label
		row.value.text = tiles[i].value
		row.panel.visible = !tiles[i].get("hidden", false)
		if row.panel.visible:
			row.style.bg_color = ROW_ALT if alt else Color(0, 0, 0, 0)
			alt = !alt
	_refresh_tools()


## hero[0] large and centred; hero[1..2] in two halves below it.
func _add_hero(hero: Array) -> void:
	var card := _card(8)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)

	var top := _label(HERO_PX, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(top)
	v.add_child(_label(CAPTION_PX, HORIZONTAL_ALIGNMENT_CENTER, hero[0].label.to_upper(), FAINT))
	_hero_values.append(top)

	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.4)
	v.add_child(sep)

	var halves := HBoxContainer.new()
	halves.add_theme_constant_override("separation", 6)
	v.add_child(halves)
	for i in range(1, hero.size()):
		var half := VBoxContainer.new()
		half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		half.add_theme_constant_override("separation", 0)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 4)
		if hero[i].has("icon"):
			row.add_child(_icon(hero[i].icon))
		var value := _label(HERO_SMALL_PX, HORIZONTAL_ALIGNMENT_CENTER)
		row.add_child(value)
		half.add_child(row)
		half.add_child(_label(CAPTION_PX, HORIZONTAL_ALIGNMENT_CENTER, hero[i].label, FAINT, true))
		halves.add_child(half)
		_hero_values.append(value)
	add_child(card)


## "Tools this run": rank, icon, name and share in words and numbers (not just
## colours, unlike the game's graph), a share bar, dirt earned and dirt/s over
## the last minute. Run view only.
func _add_tools() -> void:
	_tools_title = _add_group_title("Tools this run")
	_tools_card = _card(4)
	_tools_list = VBoxContainer.new()
	_tools_list.add_theme_constant_override("separation", 0)
	_tools_card.add_child(_tools_list)
	_tools_empty = _label(ROW_PX, HORIZONTAL_ALIGNMENT_CENTER, "No dirt dug yet", FAINT)
	_tools_list.add_child(_tools_empty)
	add_child(_tools_card)


func _refresh_tools() -> void:
	var on: bool = !stats.show_all
	_tools_title.visible = on
	_tools_card.visible = on
	if !on:
		return
	var tools: Array = stats.tools()
	_tools_empty.visible = tools.is_empty()
	while _tool_rows.size() < tools.size():
		var r := _tool_row()
		_tools_list.add_child(r.panel)
		_tool_rows.append(r)
	for i in _tool_rows.size():
		var r: Dictionary = _tool_rows[i]
		r.panel.visible = i < tools.size()
		if !r.panel.visible:
			continue
		var t: Dictionary = tools[i]
		r.style.bg_color = ROW_ALT if i % 2 == 1 else Color(0, 0, 0, 0)
		r.icon.texture = _frame(t.icon)
		r.name.text = "%d. %s" % [i + 1, t.name]
		r.share.text = "%d%%" % roundi(t.share * 100.0)
		r.fill.size_flags_stretch_ratio = maxf(t.share, 0.001)
		r.rest.size_flags_stretch_ratio = maxf(1.0 - t.share, 0.001)
		r.info.text = "%s · %s/s" % [stats._num(t.dirt), stats._num(t.per_sec)]


func _tool_row() -> Dictionary:
	var r := {}
	var p := PanelContainer.new()
	var sb := _row_style()
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	p.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	var icon := _icon([])
	top.add_child(icon)
	var title := _label(ROW_PX, HORIZONTAL_ALIGNMENT_LEFT, "", Color.WHITE, true)
	top.add_child(title)
	var share := _label(ROW_PX, HORIZONTAL_ALIGNMENT_RIGHT)
	share.size_flags_horizontal = Control.SIZE_SHRINK_END
	top.add_child(share)
	v.add_child(top)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(ICON_PX, 0)
	bottom.add_child(indent)
	var bar := PanelContainer.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(0, 6)
	var bar_sb := StyleBoxFlat.new()
	bar_sb.bg_color = BAR_BG
	bar_sb.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("panel", bar_sb)
	var parts := HBoxContainer.new()
	parts.add_theme_constant_override("separation", 0)
	var fill := ColorRect.new()
	fill.color = BAR_FILL
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rest := Control.new()
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts.add_child(fill)
	parts.add_child(rest)
	bar.add_child(parts)
	bottom.add_child(bar)
	var info := _label(CAPTION_PX, HORIZONTAL_ALIGNMENT_RIGHT, "", FAINT)
	info.size_flags_horizontal = Control.SIZE_SHRINK_END
	bottom.add_child(info)
	v.add_child(bottom)

	r.panel = p
	r.style = sb
	r.icon = icon
	r.name = title
	r.share = share
	r.fill = fill
	r.rest = rest
	r.info = info
	return r


func _add_group_title(text: String) -> Control:
	if text.is_empty():
		return null
	var l := _label(CAPTION_PX, HORIZONTAL_ALIGNMENT_LEFT, text.to_upper(), FAINT)
	# A little air above every group but the first.
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_left", 2)
	m.add_child(l)
	add_child(m)
	return m


func _row_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb


func _row(item: Dictionary) -> Dictionary:
	var p := PanelContainer.new()
	var sb := _row_style()
	p.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_icon(item.get("icon", [])))
	var label := _label(ROW_PX, HORIZONTAL_ALIGNMENT_LEFT, item.label, Color.WHITE, true)
	row.add_child(label)
	var value := _label(ROW_PX, HORIZONTAL_ALIGNMENT_RIGHT)
	value.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(value)
	p.add_child(row)
	return {"panel": p, "style": sb, "label": label, "value": value, "group": 0}


func _card(margin: int) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_BG
	sb.border_color = CARD_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(margin)
	p.add_theme_stylebox_override("panel", sb)
	return p


## shrink: fills the free width and cuts long text with "…" instead of
## pushing the panel wider.
func _label(px: int, align: HorizontalAlignment, text := "", color := Color.WHITE, shrink := false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.modulate = color
	l.add_theme_font_size_override("font_size", px)
	if shrink:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.custom_minimum_size = Vector2(0, 0)
	return l


## spec: [texture path, hframes, vframes, frame]; an empty spec keeps the space.
func _icon(spec: Array) -> TextureRect:
	var r := TextureRect.new()
	r.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if spec.size() == 4:
		r.texture = _frame(spec)
	return r


## The frame, cropped to its drawn pixels: the game's sheets leave wide empty
## borders around small icons, which made them tiny at row size.
func _frame(spec: Array) -> Texture2D:
	var id := str(spec)
	if !_textures.has(id):
		var sheet: Texture2D = load(spec[0]) if ResourceLoader.exists(spec[0]) else null
		if sheet == null:
			_textures[id] = null
		else:
			var w: int = sheet.get_width() / spec[1]
			var h: int = sheet.get_height() / spec[2]
			var region := Rect2i((spec[3] % spec[1]) * w, (spec[3] / spec[1]) * h, w, h)
			var img := sheet.get_image()
			if img != null:
				if img.is_compressed():
					img.decompress()
				var used := img.get_region(region).get_used_rect()
				if used.has_area():
					region = Rect2i(region.position + used.position, used.size)
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(region)
			_textures[id] = at
	return _textures[id]
