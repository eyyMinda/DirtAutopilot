extends VBoxContainer
## Session stats as tiles: three large headline numbers, then a grid of small
## tiles with the game's own icons. Columns follow the available width.

const TILE_MIN_WIDTH := 150
const HERO_SCALE := 1.5
const CAPTION_SCALE := 0.8
const ICON_PX := 22

var stats

var _hero_values: Array[Label] = []
var _tile_values: Array[Label] = []
var _grid: GridContainer
var _textures: Dictionary = {}


func setup(session_stats, on_reset: Callable) -> void:
	stats = session_stats
	add_theme_constant_override("separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 8)
	add_child(hero)
	for item in stats.hero():
		var tile := _tile(0.35)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 0)
		tile.add_child(v)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		if item.has("icon"):
			row.add_child(_icon(item.icon))
		var value := Label.new()
		value.set_meta("scale", HERO_SCALE)
		row.add_child(value)
		v.add_child(row)
		v.add_child(_caption(item.label, true))
		hero.add_child(tile)
		_hero_values.append(value)

	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	for item in stats.tiles():
		var tile := _tile(0.22)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_icon(item.get("icon", [])))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		var value := Label.new()
		v.add_child(value)
		v.add_child(_caption(item.label))
		row.add_child(v)
		tile.add_child(row)
		_grid.add_child(tile)
		_tile_values.append(value)
	add_child(_grid)

	var reset := Button.new()
	reset.text = "Reset stats"
	reset.focus_mode = Control.FOCUS_NONE
	reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	reset.pressed.connect(on_reset)
	add_child(reset)

	resized.connect(_update_columns)
	refresh()


func _ready() -> void:
	# The theme's font size is only known once the view is in the tree.
	var base := get_theme_font_size("font_size", "Label")
	for l in find_children("*", "Label", true, false):
		if l.has_meta("scale"):
			l.add_theme_font_size_override("font_size", int(base * float(l.get_meta("scale"))))


func refresh() -> void:
	var hero: Array = stats.hero()
	for i in mini(hero.size(), _hero_values.size()):
		_hero_values[i].text = hero[i].value
	var tiles: Array = stats.tiles()
	for i in mini(tiles.size(), _tile_values.size()):
		_tile_values[i].text = tiles[i].value


func _update_columns() -> void:
	_grid.columns = clampi(int(size.x / TILE_MIN_WIDTH), 1, 4)


func _tile(alpha: float) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, alpha)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	return p


func _caption(text: String, center := false) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = Color(1, 1, 1, 0.6)
	l.set_meta("scale", CAPTION_SCALE)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
