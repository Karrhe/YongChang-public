extends Control
## 制作人员画面。

const MENU_SCENE := "res://scenes/menu/menu.tscn"


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)

	var body := Label.new()
	body.text = Game.text("CREDITS_BODY")
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)

	var back := Button.new()
	back.text = Game.text("UI_BACK")
	back.custom_minimum_size = Vector2(240, 48)
	back.pressed.connect(func() -> void: Game.go_to(MENU_SCENE))
	box.add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.go_to(MENU_SCENE)
