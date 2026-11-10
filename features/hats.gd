extends RefCounted
## Which pals each hat actually helps, best first. From what each pal does in the game:
##   Mushroom walks to tools and uses them; Frog stomps tools; Kiwi hits them with
##   a boomerang; Ghost floats through them. The hat counts for those hits.
##   Mole digs on its own. Golem and Druid only buff other pals with a stomp.
##   Fox only sells items.
## Witch hat doubles buffs the wearer *receives*, so it belongs on pals that get buffed.

const PALS := {
	"MUSHROOM_GUY": "Mushroom pal",
	"FROG_GUY": "Frog pal",
	"MOLE_GUY": "Mole pal",
	"KIWI_GUY": "Kiwi pal",
	"GHOST_GUY": "Ghost pal",
	"GOLEM_GUY": "Dirt golem",
	"DRUID_GUY": "Druid pal",
	"FOX_GUY": "Fox pal",
}

const HATS := {
	"HAT_DIRT_MULTIPLY": {"name": "Hard hat", "effect": "x5 dirt",
		"fit": ["MUSHROOM_GUY", "MOLE_GUY", "KIWI_GUY", "FROG_GUY", "GHOST_GUY"]},
	"HAT_RADIUS": {"name": "Antenna hat", "effect": "+50% radius",
		"fit": ["FROG_GUY", "DRUID_GUY", "GOLEM_GUY"]},
	"HAT_LUCK": {"name": "Leprechaun hat", "effect": "always finds items",
		"fit": ["MUSHROOM_GUY", "MOLE_GUY", "KIWI_GUY", "FROG_GUY", "GHOST_GUY"]},
	"HAT_WORMS": {"name": "Apple hat", "effect": "digs up worms",
		"fit": ["MUSHROOM_GUY", "MOLE_GUY", "KIWI_GUY", "FROG_GUY", "GHOST_GUY"]},
	"HAT_ACTIONS": {"name": "Pizza worker hat", "effect": "double actions",
		"fit": ["MUSHROOM_GUY", "FROG_GUY", "KIWI_GUY", "MOLE_GUY", "DRUID_GUY", "GOLEM_GUY", "FOX_GUY"]},
	"HAT_IDLE_REDUCE": {"name": "Rabbit ears", "effect": "no breaks",
		"fit": ["MUSHROOM_GUY", "FROG_GUY", "KIWI_GUY", "MOLE_GUY", "DRUID_GUY", "GOLEM_GUY", "FOX_GUY", "GHOST_GUY"]},
	"HAT_BUFF_TIME": {"name": "Witch hat", "effect": "double buff time",
		"fit": ["MUSHROOM_GUY", "MOLE_GUY", "KIWI_GUY", "FROG_GUY", "GHOST_GUY"]},
}

const BEST_FIT := ""


## Pal types to try for a hat, in order. preferred = a pal key or BEST_FIT.
## Hats added by a game update fit any pal.
static func pal_order(hat_key: String, preferred: String) -> Array:
	if !HATS.has(hat_key):
		return PALS.keys()
	var order: Array = HATS[hat_key].fit.duplicate()
	if order.has(preferred):
		order.erase(preferred)
		order.push_front(preferred)
	return order


## [value, label] pairs for the settings dropdown.
static func options(hat_key: String) -> Array:
	var out := [[BEST_FIT, "Best fit"]]
	for pal in HATS.get(hat_key, {}).get("fit", []):
		out.append([pal, PALS[pal]])
	return out


## Naming a pal Todd unlocks an achievement, so Todd always comes first.
const FIRST_NAME := "Todd"
## The game's nametag box takes at most 20 characters.
const NAME_MAX := 20
## Credits entries that aren't people.
const NOT_NAMES := ["USERNAMES", "Godot"]


## People from the game's Credits screen, read from the screen itself so new
## credits are picked up. Nicknames are preferred and extras like "(mads)" dropped.
static func credit_names() -> Array[String]:
	var out: Array[String] = []
	if !GM.ui.top.sub_exists("CREDITS"):
		return out
	for body in GM.ui.top.sub("CREDITS").find_children("Body", "Label", true, false):
		for line in (body as Label).text.split("\n", false):
			var person := _clean_name(line)
			if !person.is_empty() and !NOT_NAMES.has(person) and !out.has(person):
				out.append(person)
	return out


static func _clean_name(line: String) -> String:
	var parts := line.split("\"")
	if parts.size() >= 3:
		line = parts[1]
	line = line.get_slice("(", 0).get_slice(" from ", 0)
	return line.strip_edges().left(NAME_MAX).strip_edges()


## Todd first, then a random credits name no pal has yet. When every name is
## taken, they come back numbered ("Liz 2"), so a name is never used twice.
static func pick_name(taken: Dictionary, credits: Array[String]) -> String:
	if !taken.has(FIRST_NAME.to_upper()):
		return FIRST_NAME
	var pool: Array[String] = []
	pool.assign(credits if !credits.is_empty() else [FIRST_NAME])
	pool.shuffle()
	var n := 1
	while true:
		for person in pool:
			var candidate := person if n == 1 else "%s %d" % [person.left(NAME_MAX - 4), n]
			if !taken.has(candidate.to_upper()):
				return candidate
		n += 1
	return FIRST_NAME
