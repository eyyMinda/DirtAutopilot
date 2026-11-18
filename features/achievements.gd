extends Node
## The game's achievements (IS_META badges, minus the SUPER_ relic sets) with
## progress where the game tracks it, a note when one of the mod's features
## earns it, and a one-click action for the two that are only odd chores.
## Conditions are in the game's app/controllers/achievements_controller.gd.

signal changed

const SHEET := "res://app/ui/badges/icon/badges_icons_sheet.png"
const COOKIE_SCRIPT := "res://app/ui/badges/icon/cookie_clicker.gd"
const DRAGOON_CLICKS := 999
## How often to look again for the cookie while the player doesn't have it.
const COOKIE_SEARCH_MSEC := 5000
## Cookie clicks per frame, so the 999 clicks take about a second instead of hanging a frame.
const CLICKS_PER_FRAME := 20

## In display order. "auto": the mod setting that earns it; "action": a do_action() id.
const LIST := [
	{"key": "IMCADE", "auto": "hats_place"},
	{"key": "DRAGOON", "action": "cookie"},
	{"key": "CONNOR_LP", "action": "volume"},
	{"key": "BUTTON_LUCK", "auto": "timer_game"},
	{"key": "BUTTON_EXPERT", "auto": "timer_game"},
	{"key": "GAMEBOY", "auto": "relic_mg_solve"},
	{"key": "FISHING_BAIT"},
	{"key": "CEREAL_BOX"},
	{"key": "LEGENDARY_BAG"},
	{"key": "FULL_BAG"},
	{"key": "LEGENDARY_HOURGLASS", "auto": "sand_auto"},
	{"key": "EXPENSIVE_SUIT"},
	{"key": "SPOONING"},
	{"key": "IDLE_CUB"},
	{"key": "CAN_OF_WORMS"},
	{"key": "CAVE_REACH"},
	{"key": "LAVA_REACH"},
	{"key": "VOID_REACH"},
	{"key": "GOLDEN_SHOVEL"},
	{"key": "SKILL_TREE_MAX"},
]

var s
var busy := ""

var _cookie_node: Node
var _cookie_search_at := 0

var _icons: Dictionary = {}


func setup(settings) -> void:
	s = settings


static func is_ready() -> bool:
	return GM.is_app_init and is_instance_valid(GM.ach) and !GM.data.badges_data.is_empty()


static func owned(key: String) -> bool:
	return GM.ach.key_exists(key) and GM.ach.key_owned(key)


static func title(key: String) -> String:
	return _cap(tr_key(GM.data.raw_data_badges[key].get("NAME", key)))


static func description(key: String) -> String:
	return tr_key(GM.data.raw_data_badges[key].get("DESCRIPTION", ""))


static func tr_key(key: String) -> String:
	return TranslationServer.translate(key)


static func _cap(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)


func icon(key: String) -> Texture2D:
	if !_icons.has(key):
		var sheet: Texture2D = load(SHEET)
		var frame: int = GM.data.raw_data_badges[key].get("ICON_FRAME", 0)
		var w := sheet.get_width() / 20
		var h := sheet.get_height() / 4
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2((frame % 20) * w, (frame / 20) * h, w, h)
		_icons[key] = at
	return _icons[key]


## LIST plus, per tool/pal (game 1.3+), "fully upgrade in the Sand Mines" and
## "Create 10 void <tool>".
static func entries() -> Array:
	var out: Array = LIST.duplicate()
	if is_instance_valid(GM.sand):
		for node_key in GM.sand.node_keys_sand_enabled:
			out.append({"key": "SANDY_" + node_key, "auto": "sand_auto"})
	if is_instance_valid(GM.void_fusion):
		for node_key in GM.void_fusion.node_keys_void_fuse_enabled:
			out.append({"key": "CREATE_VOID_" + node_key})
	return out


## "37 / 100" style progress for the ones the game counts, else "".
static func progress(key: String) -> String:
	if key.begins_with("CREATE_VOID_"):
		var count: int = GM.void_fusion.void_node_count(key.trim_prefix("CREATE_VOID_"))
		return "%d / %d" % [count, goal(key, 10)]
	match key:
		"FISHING_BAIT":
			return "%d / 100" % int(GM.player.currency_worms_dug_up.amount)
		"CEREAL_BOX":
			return "%d / 999" % GM.upgrades.spoons_bought_overall
		"LEGENDARY_BAG", "FULL_BAG":
			var best := 0
			for st: ItemStack in GM.inv.item_stacks:
				if key == "FULL_BAG" or st.rarity == "LEGENDARY":
					best = maxi(best, st.amount)
			return "%d / %d" % [best, goal(key, ItemStack.AMOUNT_MAX)]
		"LEGENDARY_HOURGLASS":
			if !GM.sand.is_unlocked:
				return ""
			var maxed := 0
			for slot in GM.sand.slots:
				if slot.is_max_level:
					maxed += 1
			return "%d / %d" % [maxed, GM.sand.slots.size()]
	return ""


## The target in the game's own description ("Own 64 stacks…" -> 64), so the
## progress follows the game when it changes the number; fallback otherwise.
static func goal(key: String, fallback: int) -> int:
	var m := _NUMBER.search(description(key))
	return int(m.get_string()) if m else fallback


static var _NUMBER := RegEx.create_from_string(r"\d+")


## Why the action can't run right now, or "" when it can.
func action_blocker(entry: Dictionary) -> String:
	if !GM.is_playing():
		return "Start a run first"
	match entry.get("action", ""):
		"cookie":
			var cookie = _cookie()
			if cookie == null or !cookie.ui_badge_icon.unlocked:
				return "Find the cookie relic first"
	return ""


func do_action(entry: Dictionary) -> void:
	if !busy.is_empty() or !action_blocker(entry).is_empty():
		return
	match entry.get("action", ""):
		"cookie":
			_click_cookie()
		"volume":
			_volume_trick()


## Same as clicking the cookie relic in the badges screen: the game counts the
## clicks of that one cookie and unlocks Dragoon at 999.
func _click_cookie() -> void:
	var cookie = _cookie()
	busy = "cookie"
	changed.emit()
	while is_instance_valid(cookie) and cookie._clicked_amount < DRAGOON_CLICKS:
		for i in CLICKS_PER_FRAME:
			cookie._clicked_amount += 1
			GM.badges.on_cookie_clicked.emit(cookie._clicked_amount)
			if cookie._clicked_amount >= DRAGOON_CLICKS:
				break
		await get_tree().process_frame
	busy = ""
	changed.emit()


## Walks the whole tree, so the result is kept; the settings page asks twice a second.
func _cookie() -> Node:
	if is_instance_valid(_cookie_node):
		return _cookie_node
	if Time.get_ticks_msec() < _cookie_search_at:
		return null
	_cookie_search_at = Time.get_ticks_msec() + COOKIE_SEARCH_MSEC
	for n in get_tree().root.find_children("*", "Node", true, false):
		var script: Script = n.get_script()
		if script and script.resource_path == COOKIE_SCRIPT:
			_cookie_node = n
			return n
	return null


## The game checks the saved volumes (master and music at 100 %, SFX at 0 %)
## when Options is closed. Only the saved values are swapped for that moment,
## so nothing gets louder, and they're put back right after.
func _volume_trick() -> void:
	var ud: Dictionary = GM.data.user_data
	var keys := ["volume_master", "volume_music", "volume_sfx"]
	var old := {}
	for k in keys:
		old[k] = ud.get(k)
	ud["volume_master"] = 1.0
	ud["volume_music"] = 1.0
	ud["volume_sfx"] = 0.0
	var options = GM.ui.options
	if !options.visible:
		options.toggle_on()
	options.toggle_off()
	for k in keys:
		if old[k] == null:
			ud.erase(k)
		else:
			ud[k] = old[k]
	GM.data.user_data_save()
	changed.emit()
