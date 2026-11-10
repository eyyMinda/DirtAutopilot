extends VBoxContainer
## Session stats for the game's narrow right panel (~240 px): a headline card
## (play time large, dirt earned and dirt per hour side by side), then grouped
## cards of one-line rows (icon, name, value on the right). Long names are
## shortened with "…" instead of widening the panel.

const ICON_PX := 18
const HERO_PX := 30
const HERO_SMALL_PX := 18
const ROW_PX := 16
const CAPTION_PX := 14
const FAINT := Color(1, 1, 1, 0.6)
const ROW_ALT := Color(1, 1, 1, 0.05)
const CARD_BG := Color(0, 0, 0, 0.3)
const CARD_BORDER := Color(1, 1, 1, 0.08)

var stats

var _hero_values: Array[Label] = []
var _tile_values: Array[Label] = []
var _textures: Dictionary = {}


func setup(session_stats, on_reset: Callable) -> void:
	stats = session_stats
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_add_hero(stats.hero())

	var rows: VBoxContainer
	var alt := false
	for item in stats.tiles():
		if item.has("group") or rows == null:
			_add_group_title(item.get("group", ""))
			var card := _card(4)
			rows = VBoxContainer.new()
			rows.add_theme_constant_override("separation", 0)
			card.add_child(rows)
			add_child(card)
			alt = false
		rows.add_child(_row(item, alt))
		alt = !alt

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	add_child(gap)
	var reset := Button.new()
	reset.text = "Reset stats"
	reset.focus_mode = Control.FOCUS_NONE
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(on_reset)
	add_child(reset)

	refresh()


func refresh() -> void:
	var hero: Array = stats.hero()
	for i in mini(hero.size(), _hero_values.size()):
		_hero_values[i].text = hero[i].value
	var tiles: Array = stats.tiles()
	for i in mini(tiles.size(), _tile_values.size()):
		_tile_values[i].text = tiles[i].value


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


func _add_group_title(text: String) -> void:
	if text.is_empty():
		return
	var l := _label(CAPTION_PX, HORIZONTAL_ALIGNMENT_LEFT, text.to_upper(), FAINT)
	# A little air above every group but the first.
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_left", 2)
	m.add_child(l)
	add_child(m)


func _row(item: Dictionary, alt: bool) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = ROW_ALT if alt else Color(0, 0, 0, 0)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_icon(item.get("icon", [])))
	row.add_child(_label(ROW_PX, HORIZONTAL_ALIGNMENT_LEFT, item.label, Color.WHITE, true))
	var value := _label(ROW_PX, HORIZONTAL_ALIGNMENT_RIGHT)
	value.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(value)
	p.add_child(row)
	_tile_values.append(value)
	return p


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


func _frame(spec: Array) -> Texture2D:
	var id := str(spec)
	if !_textures.has(id):
		var sheet: Texture2D = load(spec[0]) if ResourceLoader.exists(spec[0]) else null
		if sheet == null:
			_textures[id] = null
		elif spec[1] == 1 and spec[2] == 1:
			_textures[id] = sheet
		else:
			var w: int = sheet.get_width() / spec[1]
			var h: int = sheet.get_height() / spec[2]
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2((spec[3] % spec[1]) * w, (spec[3] / spec[1]) * h, w, h)
			_textures[id] = at
	return _textures[id]
