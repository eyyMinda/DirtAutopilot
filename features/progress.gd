extends Node
## Read-only helpers for the milestone bar, the prestige alert and the advisor's
## marker in the prestige tree.

const Advisor := preload("prestige_advisor.gd")

signal prestige_ready(new_upgrades: int, worms_gain: int, icon: Texture2D, best_name: String)

const CHECK_SEC := 0.5
const WORMS_ICON := "res://app/ui/currency_worms.png"
const MARKER_COLOR := Color(1.0, 0.85, 0.3)

var s

var _check_t := 0.0
## Highest "new upgrades" count already alerted this run; reset by prestiging.
var _alerted := 0
var _gain_prev := 0.0
var _icons: Dictionary = {}
var _marker: Label


func setup(settings) -> void:
	s = settings


func _process(delta: float) -> void:
	if !GM.is_app_init:
		return
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = CHECK_SEC
	_update_marker()
	if GM.is_playing() and s.get_value("prestige_alert"):
		_check_prestige()


func _check_prestige() -> void:
	var p = GM.prestige
	if !is_instance_valid(p) or !p.is_unlocked or p.is_active:
		return
	var worms: float = GM.player.currency_amount("WORMS")
	var gain: float = GM.player.currency_amount("WORMS_RUN")
	if gain < _gain_prev:
		_alerted = 0
	_gain_prev = gain
	var unlocks := prestige_new_upgrades(worms, gain)
	if unlocks.size() <= _alerted:
		return
	_alerted = unlocks.size()
	var best = Advisor.best(worms + gain, s)
	var shown = best if best else unlocks[0]
	prestige_ready.emit(unlocks.size(), int(gain), upgrade_icon(shown), Advisor.display_name(best) if best else "")


## "BEST" above the advisor's pick while the prestige tree is open. Before
## prestiging (view only) the budget includes this run's worms; while
## prestiging they've already been added to the worms you own.
func _update_marker() -> void:
	var p = GM.prestige
	var target = null
	if is_instance_valid(p) and is_instance_valid(p.ui_prestige_tree) and p.ui_prestige_tree.is_active:
		var budget: float = GM.player.currency_amount("WORMS")
		if !p.is_active:
			budget += GM.player.currency_amount("WORMS_RUN")
		target = Advisor.best(budget, s)
	if target == null:
		if is_instance_valid(_marker):
			_marker.visible = false
		return
	if !is_instance_valid(_marker):
		_marker = _make_marker()
	if _marker.get_parent() != target:
		if _marker.get_parent():
			_marker.get_parent().remove_child(_marker)
		target.add_child(_marker)
	_marker.visible = true


func _make_marker() -> Label:
	var l := Label.new()
	l.name = "DirtAutopilotBest"
	l.text = "BEST"
	l.add_theme_color_override("font_color", MARKER_COLOR)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.offset_top = -4
	l.offset_bottom = -4
	return l


## The prestige tree buttons the worms from prestiging would newly pay for,
## cheapest first. Only upgrades already reachable in the tree count, at their current level's cost.
static func prestige_new_upgrades(worms: float, gain: float) -> Array:
	var btns := []
	for btn in UIBtnSkillTree.All:
		if !is_instance_valid(btn) or btn.type != UIBtnSkillTree.Type.PRESTIGE_TREE:
			continue
		var st = btn.stat_data
		if st == null or st.is_demo_lock or st.is_locked or st.is_max_level() or st.get_cost_type() != "WORMS":
			continue
		btns.append(btn)
	btns.sort_custom(func(a, b): return a.stat_data.get_cost() < b.stat_data.get_cost())
	var now := _count_affordable(btns, worms)
	return btns.slice(now, _count_affordable(btns, worms + gain))


static func _count_affordable(sorted_btns: Array, budget: float) -> int:
	var n := 0
	for btn in sorted_btns:
		var cost: float = btn.stat_data.get_cost()
		if cost > budget:
			break
		budget -= cost
		n += 1
	return n


## The button's icon as the tree shows it: the pal or tool, with the stat's
## small icon at its top-right (offsets from ui_btn_skill_tree.tscn).
static func upgrade_icon(btn) -> Texture2D:
	var node_spr := btn.get_node_or_null("Body/Icon/Node") as Sprite2D
	var stat_spr := btn.get_node_or_null("Body/Icon/Stat") as Sprite2D
	if node_spr == null or node_spr.texture == null:
		return null
	var layers := [node_spr]
	if stat_spr and stat_spr.texture:
		layers.append(stat_spr)
	var bounds := Rect2()
	var frames := []
	for spr: Sprite2D in layers:
		var img := spr.texture.get_image()
		if img == null:
			return null
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var fs := Vector2i(img.get_width() / spr.hframes, img.get_height() / spr.vframes)
		var src := Rect2i(Vector2i(spr.frame % spr.hframes, spr.frame / spr.hframes) * fs, fs)
		var dst := Rect2(spr.position - Vector2(fs) / 2.0, Vector2(fs))
		frames.append([img, src, dst])
		bounds = dst if frames.size() == 1 else bounds.merge(dst)
	var out := Image.create(int(bounds.size.x), int(bounds.size.y), false, Image.FORMAT_RGBA8)
	for f in frames:
		out.blend_rect(f[0], f[1], Vector2i(f[2].position - bounds.position))
	return ImageTexture.create_from_image(out)


static func worms_icon() -> Texture2D:
	return load(WORMS_ICON) if ResourceLoader.exists(WORMS_ICON) else null


## The next point on the game's milestone timeline:
## {kind: "chest"/"minigame"/"relic", key, name, icon (null = random), amount, goal, progress 0..1}.
## Empty when there's nothing left, or before the first item is dug up (the
## timeline only gets its final dirt values then).
func next_milestone() -> Dictionary:
	var m = GM.milestones
	if !is_instance_valid(m) or m.timeline == null or m.timeline.currency == null:
		return {}
	if GM.inv.item_dig_out_first.is_empty():
		return {}
	var amount: float = m.timeline.currency.amount_overall
	var next = null
	var prev_goal := 0.0
	for p in m.timeline.points:
		if !p.chest_key.is_empty() and GM.chest.chest_is_opened(p.chest_key):
			continue
		var goal: float = p.currency_overall_goal
		if goal > amount:
			if next == null or goal < next.currency_overall_goal:
				next = p
		elif goal > prev_goal:
			prev_goal = goal
	if next == null:
		return {}

	var info := {"amount": amount, "goal": next.currency_overall_goal}
	info.progress = clampf((amount - prev_goal) / maxf(next.currency_overall_goal - prev_goal, 1.0), 0.0, 1.0)
	if !next.chest_key.is_empty():
		info.kind = "chest"
		info.key = next.chest_key
		info.name = "%s chest" % next.chest_key.capitalize()
		info.icon = _icon("chest:" + next.chest_key)
	elif GM.inv.item_is_game(next.relic_key):
		# Minigame relics have a fixed spot on the timeline.
		info.kind = "minigame"
		info.key = next.relic_key
		info.name = tr(GM.inv.item_name(next.relic_key))
		info.icon = _icon("item:" + next.relic_key)
	else:
		# Dug-up relics are shuffled into their slots, so which one comes next is random.
		info.kind = "relic"
		info.key = ""
		info.name = "A random relic"
		info.icon = null
	return info


## Cached, since the milestone bar asks every frame.
func _icon(id: String) -> Texture2D:
	if !_icons.has(id):
		var key := id.get_slice(":", 1)
		if id.begins_with("chest:"):
			var t := key.to_lower()
			var path := "res://app/world/node/chest/%s/chests_%s_sheet.png" % [t, t]
			_icons[id] = _sheet_frame(load(path), 2, 1, 0) if ResourceLoader.exists(path) else null
		else:
			_icons[id] = _sheet_frame(PRELOADS.PS_TEXTURE_ITEMS.get("RELIC"), 20, 4, GM.inv.item_icon_frame(key))
	return _icons[id]


static func _sheet_frame(sheet: Texture2D, hframes: int, vframes: int, frame: int) -> Texture2D:
	if sheet == null:
		return null
	var w := sheet.get_width() / hframes
	var h := sheet.get_height() / vframes
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2((frame % hframes) * w, (frame / hframes) * h, w, h)
	return at
