extends "stats_tab.gd"
## The Autopilot tab in the game's right panel: buying switches, what gets bought
## next and recent purchases (ui/autopilot_view.gd). Same mechanics as the stats tab.

const AutopilotView := preload("autopilot_view.gd")

var buyer
var prestige_auto


func _init() -> void:
	title = "Autopilot"
	hotkey_key = "key_autopilot"
	first = true


func _make_view() -> Control:
	var v := AutopilotView.new()
	v.setup(settings, buyer, prestige_auto)
	return v


## A steering wheel in the style of the game's tab icons: filled shape, 1 px outline.
func _icon() -> Texture2D:
	var img := Image.create_empty(ICON_PX, ICON_PX, false, Image.FORMAT_RGBA8)
	var c := Vector2(14, 14)
	var mask := {}
	for y in ICON_PX:
		for x in ICON_PX:
			var p := Vector2(x, y) + Vector2(0.5, 0.5)
			var d := p.distance_to(c)
			var rim := d <= 11.5 and d > 8.0
			var hub := d <= 3.5
			var spoke := d <= 9.0 and (absf(p.y - c.y) < 1.5 or (absf(p.x - c.x) < 1.5 and p.y > c.y))
			if rim or hub or spoke:
				mask[Vector2i(x, y)] = true
				img.set_pixel(x, y, FILL)
	for y in ICON_PX:
		for x in ICON_PX:
			if mask.has(Vector2i(x, y)):
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if mask.has(Vector2i(x, y) + o):
					img.set_pixel(x, y, OUTLINE)
					break
	return ImageTexture.create_from_image(img)
