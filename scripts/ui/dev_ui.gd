class_name DevUI
extends RefCounted
## 假模块和开发用画面的简单界面，按 640×360 排。正式画面不用它。


static func panel(parent: Control, title: String) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	return box


static func button(parent: Node, text_id: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = Game.text(text_id)
	btn.custom_minimum_size = Vector2(160, 24)
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn
