extends Control
## 主菜单：开始 / 继续 / 制作人员 / 退出。

const CREDITS_SCENE := "res://scenes/credits/credits.tscn"
const FLOW_SCENE := "res://scenes/flow/flow.tscn"


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)

	var title := Label.new()
	title.text = Game.text("UI_TITLE")
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = Game.text("UI_SUBTITLE")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	_add_button(box, "UI_NEW_GAME", _on_new_game)
	var cont := _add_button(box, "UI_CONTINUE", _on_continue)
	cont.disabled = not _can_continue()
	_add_button(box, "UI_CREDITS", func() -> void: Game.go_to(CREDITS_SCENE))
	_add_button(box, "UI_QUIT", Game.quit)


func _add_button(parent: Node, text_id: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = Game.text(text_id)
	button.custom_minimum_size = Vector2(120, 24)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _can_continue() -> bool:
	if not Game.has_save():
		return false
	var saved := Game.save
	var ok := Game.load_game() and FlowLogic.node_index(Game.save.progress) >= 0
	Game.save = saved
	return ok


func _on_new_game() -> void:
	Game.new_game()
	FlowLogic.start_new_game(Game.save)
	Game.go_to(FLOW_SCENE)


func _on_continue() -> void:
	if Game.load_game():
		Game.go_to(FLOW_SCENE)
