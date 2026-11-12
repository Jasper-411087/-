extends HBoxContainer
## 流速調整列：「流速  [－]  9.0  [＋]」，掛在主選單與暫停選單。數值存在 Settings。

var _value: Label


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 16)
	var title := Label.new()
	title.text = "流速"
	title.add_theme_font_size_override("font_size", 32)
	add_child(title)
	add_child(_button("－", -1))
	_value = Label.new()
	_value.custom_minimum_size = Vector2(90, 0)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.add_theme_font_size_override("font_size", 32)
	add_child(_value)
	add_child(_button("＋", 1))
	Settings.changed.connect(_refresh)
	_refresh()


func _button(text: String, steps: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(64, 56)
	b.add_theme_font_size_override("font_size", 32)
	b.pressed.connect(Settings.change_speed.bind(steps))
	return b


func _refresh() -> void:
	_value.text = "%.1f" % Settings.scroll_speed
