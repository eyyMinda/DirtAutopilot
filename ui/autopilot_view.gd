extends VBoxContainer
## Autopilot tab content for the narrow right panel (~260 px).
## Top: the shop card (AUTO-BUY, its options, what's next and what was just
## bought, in one place). Below: a few foldable cards that group the other mod
## settings as two-column toggle chips (built from Settings.SCHEMA, same settings
## as Options > Dirt Autopilot). Hotkeys, achievements and reset stay in Options.

const Settings := preload("../core/settings.gd")
const SettingsView := preload("settings_view.gd")
const Hats := preload("../features/hats.gd")
const Icons := preload("icons.gd")

const MAIN := "shop_buy"
## The rest of the Shopping section, shown under AUTO-BUY instead of in a card.
const SHOP_SECTION := "Shopping"
## Foldable cards: title -> the Settings.SCHEMA sections they hold (in order).
const CARDS := [
	{"title": "Prestige", "sections": ["Prestige"]},
	{"title": "Automation", "sections": ["Auto-sweeper", "Sand Mines", "Relics", "Pickups"]},
	{"title": "Hats on pals", "sections": ["Hats on pals"]},
	{"title": "Display", "sections": ["Progress", "Items & popups", "Performance"]},
]
## Chip texts; the full label and description show as a tooltip.
const SHORT := {
	"perf_no_effects": "Hide effects", "perf_hide_buffs": "Hide buffs", "perf_hide_stomps": "Hide stomps",
	"perf_hide_names": "Hide names", "perf_hide_sell_pops": "Hide sells", "perf_hide_new_counts": "Hide +N",
	"sweep_enabled": "Auto-sweep",
	"timer_game": "Sand timer", "sand_auto": "Spend sand",
	"shop_no_fox": "Skip foxes", "shop_hats": "Buy hats",
	"prestige_buy": "Buy upgrades", "auto_prestige": "Auto-prestige", "auto_restart": "Auto-restart",
	"relic_mg_solve": "Solve games", "relics_open": "Open relics",
	"coffee_click": "Coffee bean", "chests_open": "Open chests",
	"hats_place": "Place hats",
	"milestone_bar": "Milestones", "prestige_alert": "Prestige alert",
	"protect_legendary": "Keep legendary", "skip_popup_relics": "No relic popup",
	"skip_popup_achievements": "No badge popup",
}
## Tooltips are wrapped at about this many characters (Godot doesn't wrap them).
const TIP_CHARS := 42
const QUEUE := 3
const HISTORY := 5

const MAIN_PX := 20
const TITLE_PX := 15
const SUB_PX := 12
const ROW_PX := 14
const CHIP_PX := 13
const COUNT_PX := 12
const FOLD_PX := 16
## The gold of the Options page headings, so both read as the mod's.
const ACCENT := Color(0.96, 0.76, 0.42)
const ACCENT_DARK := Color(0.55, 0.36, 0.12)
const INK := Color(0.13, 0.09, 0.05)
const TEXT := Color(0.93, 0.9, 0.85)
const FAINT := Color(0.93, 0.9, 0.85, 0.6)
const CARD_BG := Color(0.07, 0.055, 0.045, 0.85)
const CHIP_OFF := Color(1, 1, 1, 0.06)
const DARK_BTN := Color(0.16, 0.13, 0.11)

## Remembered while the game runs, so reopening the tab keeps the cards as left.
static var _open: Dictionary = {}
static var _chevrons: Dictionary = {}

var s
var buyer
var prestige_auto

var _main: Button
var _main_on: StyleBoxFlat
var _main_off: StyleBoxFlat
var _next: Label
var _next_info: Label
var _bar: ProgressBar
var _queue: Label
var _bought_title: Label
var _bought: Label
var _notes: Label
var _prestige: Label
## key -> Button (chip) / OptionButton (dropdown)
var _chips: Dictionary = {}
var _choices: Dictionary = {}
## {title, chevron: TextureRect, count: Label, all: CheckButton, body: Control, keys: Array[String]}
var _cards: Array[Dictionary] = []


func setup(settings, buyer_node, prestige_node) -> void:
	s = settings
	buyer = buyer_node
	prestige_auto = prestige_node
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_add_shop_card()
	for c in CARDS:
		_add_card(c.title, c.sections)
	refresh()


# ---------- shop card ----------

func _add_shop_card() -> void:
	var box := _card()
	_main = Button.new()
	_main.toggle_mode = true
	_main.focus_mode = Control.FOCUS_NONE
	_main.custom_minimum_size.y = 44
	_main.add_theme_font_size_override("font_size", MAIN_PX)
	_main.tooltip_text = _wrap(s.entry(MAIN).get("desc", ""))
	_main_on = _style(ACCENT, ACCENT_DARK, 6, 8)
	_main_on.border_width_bottom = 4
	_main_off = _style(DARK_BTN, Color(ACCENT, 0.55), 6, 8)
	_main_off.border_width_bottom = 4
	_main.toggled.connect(_on_switch.bind(MAIN))
	box.add_child(_main)
	box.add_child(_chip_grid(_section_entries(SHOP_SECTION).filter(func(e): return e.key != MAIN)))

	_next = _label(box, ROW_PX + 1, ACCENT)
	_next_info = _label(box, ROW_PX - 1, FAINT)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size.y = 6
	_bar.add_theme_stylebox_override("background", _style(Color(1, 1, 1, 0.1), Color.TRANSPARENT, 3, 0))
	_bar.add_theme_stylebox_override("fill", _style(ACCENT, Color.TRANSPARENT, 3, 0))
	box.add_child(_bar)
	_queue = _label(box, ROW_PX - 1, FAINT)
	_bought_title = _label(box, SUB_PX, ACCENT)
	_bought_title.text = "JUST BOUGHT"
	_bought = _label(box, ROW_PX - 1, TEXT)
	_notes = _label(box, ROW_PX - 1, FAINT)


# ---------- grouped cards ----------

func _section_entries(title: String) -> Array:
	var out: Array = []
	var inside := false
	for e in Settings.SCHEMA:
		if e.has("section") or e.has("group"):
			inside = e.get("section", "") == title
		elif inside and e.has("key") and !e.get("hotkey", false):
			out.append(e)
	return out


func _add_card(title: String, sections: Array) -> void:
	var keys: Array[String] = []
	var parts: Array = []
	for sec in sections:
		var entries := _section_entries(sec)
		if entries.is_empty():
			continue
		parts.append([sec, entries])
		for e in entries:
			keys.append(e.key)
	if parts.is_empty():
		return
	var body := _foldable(title, keys)
	if title == "Prestige":
		_prestige = _label(body, ROW_PX - 1, FAINT)
	for part in parts:
		if parts.size() > 1:
			var sub := Label.new()
			sub.text = part[0].to_upper()
			sub.add_theme_font_size_override("font_size", SUB_PX)
			sub.add_theme_color_override("font_color", FAINT)
			body.add_child(sub)
		var bools: Array = part[1].filter(func(e): return e.default is bool)
		if !bools.is_empty():
			body.add_child(_chip_grid(bools))
		for e in part[1]:
			if e.default is String:
				body.add_child(_choice(e))


## A card whose header (chevron, title, on/total pill) folds its body. Returns the body.
func _foldable(title: String, keys: Array[String]) -> VBoxContainer:
	var box := _card()
	var header := Button.new()
	header.flat = true
	header.focus_mode = Control.FOCUS_NONE
	header.custom_minimum_size.y = 26
	header.add_theme_stylebox_override("hover", _style(Color(1, 1, 1, 0.06), Color.TRANSPARENT, 3, 0))
	box.add_child(header)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	header.add_child(row)
	var chevron := TextureRect.new()
	chevron.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	chevron.custom_minimum_size = Vector2(FOLD_PX, 0)
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chevron)
	var name_l := Label.new()
	name_l.text = title.to_upper()
	name_l.clip_text = true
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_l.add_theme_font_size_override("font_size", TITLE_PX)
	name_l.add_theme_color_override("font_color", ACCENT)
	row.add_child(name_l)
	var count := Label.new()
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.add_theme_font_size_override("font_size", COUNT_PX)
	count.add_theme_stylebox_override("normal", _style(Color(ACCENT, 0.18), Color.TRANSPARENT, 8, 2))
	row.add_child(count)
	# Switches everything in the card; on while all of it is on (like Options' header switch).
	var all := CheckButton.new()
	all.focus_mode = Control.FOCUS_NONE
	all.mouse_filter = Control.MOUSE_FILTER_STOP
	all.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	all.tooltip_text = "Switch everything in %s on or off" % title
	row.add_child(all)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	box.add_child(body)
	var card := {"title": title, "chevron": chevron, "count": count, "all": all, "body": body, "keys": keys}
	header.pressed.connect(_on_fold.bind(card))
	all.toggled.connect(_on_card_all.bind(card))
	_cards.append(card)
	return body


func _chip_grid(entries: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for e in entries:
		grid.add_child(_chip(e))
	return grid


func _chip(e: Dictionary) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.text = SHORT.get(e.key, e.label)
	b.tooltip_text = _wrap(e.label + ("\n" + e.desc if e.has("desc") else ""))
	b.clip_text = true
	b.custom_minimum_size = Vector2(0, 30)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", CHIP_PX)
	b.add_theme_stylebox_override("normal", _style(CHIP_OFF, Color(1, 1, 1, 0.12), 4, 4))
	b.add_theme_stylebox_override("disabled", _style(CHIP_OFF, Color(1, 1, 1, 0.08), 4, 4))
	b.add_theme_stylebox_override("hover", _style(Color(ACCENT, 0.12), Color(ACCENT, 0.6), 4, 4))
	b.add_theme_stylebox_override("pressed", _style(ACCENT, ACCENT_DARK, 4, 4))
	b.add_theme_stylebox_override("hover_pressed", _style(ACCENT.lightened(0.12), ACCENT_DARK, 4, 4))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_hover_pressed_color", INK)
	b.toggled.connect(_on_switch.bind(e.key))
	_chips[e.key] = b
	return b


func _choice(e: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = Hats.HATS[e.hat].name if e.has("hat") else e.get("label", e.key)
	l.tooltip_text = "%s (%s)" % [Hats.HATS[e.hat].name, Hats.HATS[e.hat].effect] if e.has("hat") else ""
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.add_theme_font_size_override("font_size", CHIP_PX)
	l.add_theme_color_override("font_color", TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	row.add_child(l)
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.custom_minimum_size.x = 104
	ob.clip_text = true
	ob.fit_to_longest_item = false  # else the longest world name sets the page width
	ob.add_theme_font_size_override("font_size", CHIP_PX)
	ob.item_selected.connect(_on_choice.bind(e.key, ob))
	row.add_child(ob)
	_choices[e.key] = ob
	return row


func _on_switch(on: bool, key: String) -> void:
	s.set_value(key, on)
	refresh()


func _on_choice(i: int, key: String, ob: OptionButton) -> void:
	s.set_value(key, ob.get_item_metadata(i))


func _on_card_all(on: bool, card: Dictionary) -> void:
	for key in card.keys:
		if s.entry(key).default is bool:
			s.set_value(key, on)
	refresh()


func _on_fold(card: Dictionary) -> void:
	_open[card.title] = !_open.get(card.title, false)
	refresh()


# ---------- refresh ----------

func refresh() -> void:
	var main_on: bool = s.get_value(MAIN)
	_main.set_pressed_no_signal(main_on)
	_main.text = "AUTO-BUY  ON" if main_on else "AUTO-BUY  OFF"
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		_main.add_theme_stylebox_override(state, _main_on if main_on else _main_off)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		_main.add_theme_color_override(state, INK if main_on else ACCENT)

	for key in _chips:
		var b: Button = _chips[key]
		b.set_pressed_no_signal(s.get_value(key))
		b.disabled = !_enabled(key)
		b.modulate.a = 1.0 if !b.disabled else 0.45
	for key in _choices:
		var ob: OptionButton = _choices[key]
		SettingsView.fill_choice(ob, SettingsView.choice_options(s.entry(key)))
		for i in ob.item_count:
			if ob.get_item_metadata(i) == s.get_value(key):
				ob.select(i)
		ob.disabled = !_enabled(key)
		ob.get_parent().modulate.a = 1.0 if !ob.disabled else 0.45
	for card in _cards:
		var open: bool = _open.get(card.title, false)
		card.body.visible = open
		var on := 0
		var total := 0
		for key in card.keys:
			if s.entry(key).default is bool:
				total += 1
				on += int(s.get_value(key))
		card.all.set_pressed_no_signal(total > 0 and on == total)
		card.all.visible = total > 0
		card.count.text = "%d/%d" % [on, total]
		card.count.visible = total > 0
		card.count.add_theme_color_override("font_color", ACCENT if on > 0 else FAINT)
		card.chevron.texture = _chevron(open)

	_refresh_shop()
	_refresh_prestige()


## A setting is usable while every switch it requires is on.
func _enabled(key: String) -> bool:
	var req: String = s.entry(key).get("requires", "")
	return req.is_empty() or (s.get_value(req) and _enabled(req))


func _refresh_shop() -> void:
	var plan: Array = buyer.plan
	var dirt: float = GM.player.currency_amount("DIRT") if is_instance_valid(GM.player) else 0.0
	if plan.is_empty():
		if !GM.is_playing():
			_next.text = "Start a run"
		elif buyer.shop_done and buyer.tree_done:
			_next.text = "Everything bought"
		else:
			_next.text = "Nothing to buy right now"
		_next_info.text = ""
		_bar.value = 0
		_queue.text = ""
	else:
		var c: Dictionary = plan[0]
		_next.text = "Next - " + c.name
		var when := "now" if c.cost <= dirt else "in " + _time(c.eta)
		_next_info.text = "%s dirt, %s, pays back in %s" % [_num(c.cost), when, _time(c.payback)]
		_bar.value = clampf(dirt / maxf(c.cost, 1.0), 0.0, 1.0) * 100.0
		var lines: Array[String] = []
		for i in range(1, mini(plan.size(), QUEUE + 1)):
			lines.append("%d. %s  %s" % [i + 1, plan[i].name, _num(plan[i].cost)])
		_queue.text = "\n".join(lines)
	_next_info.visible = !_next_info.text.is_empty()
	_bar.visible = !plan.is_empty()
	_queue.visible = !_queue.text.is_empty()

	var hist: Array[String] = []
	for i in range(buyer.history.size() - 1, maxi(buyer.history.size() - HISTORY, 0) - 1, -1):
		var h: Dictionary = buyer.history[i]
		var n := " x%d" % h.count if h.count > 1 else ""
		hist.append("%s%s  %s" % [h.text, n, _num(h.cost)])
	_bought.text = "\n".join(hist)
	_bought_title.visible = !hist.is_empty()
	_bought.visible = !hist.is_empty()

	var notes: Array[String] = []
	if buyer.shop_done:
		notes.append("Shop sold out.")
	if buyer.tree_done:
		notes.append("Skill tree fully upgraded.")
	if s.get_value(MAIN) and buyer.skip_fox():
		notes.append("Fox pals skipped until Full bag and Legendary bag are unlocked.")
	_notes.text = "\n".join(notes)
	_notes.visible = !notes.is_empty()


func _refresh_prestige() -> void:
	if _prestige == null:
		return
	_prestige.visible = s.get_value("auto_prestige")
	if is_instance_valid(GM.prestige) and GM.prestige.is_active:
		_prestige.text = "Prestiged, starting the next run..." if s.get_value("auto_restart") else "Prestiged. Pick a world and press Play."
	elif _prestige.visible:
		_prestige.text = "Run %s, %s" % [_time(prestige_auto.run_sec),
			"prestiging" if prestige_auto.should_prestige() else "waiting for new upgrades and a slower run"]


# ---------- building blocks ----------

static func _chevron(open: bool) -> Texture2D:
	if !_chevrons.has(open):
		_chevrons[open] = Icons.texture(Icons.CHEVRON_DOWN if open else Icons.CHEVRON_RIGHT, ACCENT, FOLD_PX)
	return _chevrons[open]


func _card() -> VBoxContainer:
	var panel := PanelContainer.new()
	var st := _style(CARD_BG, Color(ACCENT, 0.28), 5, 7)
	st.shadow_color = Color(0, 0, 0, 0.35)
	st.shadow_size = 3
	st.shadow_offset = Vector2(0, 2)
	panel.add_theme_stylebox_override("panel", st)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	add_child(panel)
	return box


## Line breaks every ~TIP_CHARS characters, at spaces, keeping existing ones.
static func _wrap(text: String) -> String:
	var out: Array[String] = []
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" "):
			if !line.is_empty() and line.length() + 1 + word.length() > TIP_CHARS:
				out.append(line)
				line = word
			else:
				line = word if line.is_empty() else line + " " + word
		out.append(line)
	return "\n".join(out)


## Rounded box with a 1 px border (none when border is transparent).
static func _style(bg: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(0 if border.a == 0.0 else 1)
	st.set_corner_radius_all(radius)
	st.set_content_margin_all(margin)
	return st


func _label(parent: Control, px: int, color := TEXT) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 120
	parent.add_child(l)
	return l


## "16s", "2m 05s", "1h 02m": the game font draws ":" badly.
static func _time(sec: float) -> String:
	var t := int(sec)
	if t >= 3600:
		return "%dh %02dm" % [t / 3600, (t / 60) % 60]
	if t >= 60:
		return "%dm %02ds" % [t / 60, t % 60]
	return "%ds" % t


static func _num(v: float) -> String:
	var units := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
	var i := 0
	while absf(v) >= 1000.0 and i < units.size() - 1:
		v /= 1000.0
		i += 1
	return str(int(v)) if i == 0 else "%.1f%s" % [v, units[i]]
