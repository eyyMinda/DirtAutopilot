extends Node
## Session stats as a tab of the game's right panel, after Badges: its own
## button in the tab column (the game's button scene with a drawn stopwatch
## icon) and a page in the panel's view.
##
## UIGame.tab_switch() only knows its TabType enum, so showing this page makes
## it the game's tab_con_current with tab_type_current = -1 (like at start):
## the game then hides it itself when any of its tabs is clicked.

const StatsView := preload("stats_view.gd")
const Settings := preload("../core/settings.gd")

const BTN_SCENE := "res://app/ui/btn_spr/main/btn_spr_main.tscn"
const BTN_PARENT := "Panels/Right/MainButtons/V/M/M/V"
const VIEW_PARENT := "Panels/Right/M/V/View/M"
const TITLE := "Session stats"
const REFRESH_SEC := 0.5
## The game's button sheet: 28 px frames, black outline, light grey fill.
const ICON_PX := 28
const OUTLINE := Color8(0, 0, 0)
const FILL := Color8(173, 173, 173)

var stats
var settings

## BtnSprMain (the game's class), untyped for its exported texture/frame.
var _btn
var _page: Control
var _view: StatsView
var _prev_tab := 0
var _refresh_t := 0.0


func _ready() -> void:
	while !(is_instance_valid(GM) and GM.ui and is_instance_valid(GM.ui.game)):
		await get_tree().process_frame
	var game: Control = GM.ui.game
	var btn_parent := game.get_node_or_null(BTN_PARENT)
	var view_parent := game.get_node_or_null(VIEW_PARENT)
	if btn_parent == null or view_parent == null or !ResourceLoader.exists(BTN_SCENE):
		push_warning("[eyyMinda-DirtAutopilot] The game's tab panel changed; no Session stats tab.")
		return

	_btn = (load(BTN_SCENE) as PackedScene).instantiate()
	_btn.name = "DirtAutopilotStats"
	_btn.texture = _stopwatch()
	_btn.hframes = 1
	_btn.vframes = 1
	_btn.frame = 0
	btn_parent.add_child(_btn)
	update_hint()
	_btn.on_pressed.connect(show_page)

	var scroll := ScrollContainer.new()
	scroll.name = "DirtAutopilotStats"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.visible = false
	_page = scroll
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 10)
	_page.add_child(pad)
	_view = StatsView.new()
	_view.setup(stats, _on_reset)
	pad.add_child(_view)
	view_parent.add_child(_page)


func _process(delta: float) -> void:
	if !is_instance_valid(_page) or !_page.is_visible_in_tree():
		return
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = REFRESH_SEC
		_view.refresh()


## "Session stats [C]", like the game's own tab hints.
func update_hint() -> void:
	if _btn == null:
		return
	var key: int = settings.get_value("key_stats") if settings else KEY_NONE
	_btn.hover_info.text = TITLE if key == KEY_NONE else "%s [%s]" % [TITLE, Settings.key_name(key)]


func is_open() -> bool:
	return is_instance_valid(_page) and _page.visible


## Hotkey: opens the page, or goes back to the previous tab. False when there's
## nothing to toggle (no run, or the tab couldn't be added).
func toggle() -> bool:
	if !is_instance_valid(_page) or !GM.is_playing():
		return false
	if is_open():
		GM.ui.game.tab_switch(_prev_tab)
	else:
		show_page()
	return true


func show_page() -> void:
	var game = GM.ui.game
	if game.tab_con_current == _page:
		return
	if int(game.tab_type_current) >= 0:
		_prev_tab = int(game.tab_type_current)
	if is_instance_valid(game.tab_con_current):
		game.tab_con_current.visible = false
	game.tab_con_current = _page
	game.tab_type_current = -1
	_page.visible = true
	game.label_panel_name.text = TITLE
	var bg: Control = game.bg_selected
	var t := bg.create_tween()
	t.tween_property(bg, "position", _btn.position, 0.125).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_refresh_t = 0.0


func _on_reset() -> void:
	stats.reset()
	_view.refresh()


## A stopwatch in the style of the game's tab icons.
static func _stopwatch() -> Texture2D:
	var img := Image.create_empty(ICON_PX, ICON_PX, false, Image.FORMAT_RGBA8)
	var c := Vector2(14, 15)
	for y in ICON_PX:
		for x in ICON_PX:
			var d := (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(c)
			if d <= 10.0:
				img.set_pixel(x, y, OUTLINE if d > 8.0 else FILL)
	_rect(img, 11, 2, 6, 2)  # crown
	_rect(img, 13, 4, 2, 2)  # stem
	_rect(img, 13, 8, 2, 8)  # minute hand
	_rect(img, 13, 14, 6, 2)  # hour hand
	return ImageTexture.create_from_image(img)


static func _rect(img: Image, x: int, y: int, w: int, h: int) -> void:
	img.fill_rect(Rect2i(x, y, w, h), OUTLINE)
