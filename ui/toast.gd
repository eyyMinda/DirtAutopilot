extends CanvasLayer

const SHOW_SEC := 1.5
const FADE_SEC := 0.4

var _label: Label
var _tween: Tween


func _ready() -> void:
	layer = 128
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.position.y = 12
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.modulate.a = 0.0
	add_child(_label)


func show_text(text: String, seconds: float = SHOW_SEC) -> void:
	_label.text = text
	_label.modulate.a = 1.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(seconds)
	_tween.tween_property(_label, "modulate:a", 0.0, FADE_SEC)
