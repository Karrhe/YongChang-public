extends Control
## 主菜单：开始 / 继续 / 制作人员 / 退出。

const CREDITS_SCENE := "res://scenes/credits/credits.tscn"


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
	cont.disabled = not Game.has_save()
	_add_button(box, "UI_CREDITS", func() -> void: Game.go_to(CREDITS_SCENE))
	_add_button(box, "UI_QUIT", Game.quit)


func _add_button(parent: Node, text_id: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = Game.text(text_id)
	button.custom_minimum_size = Vector2(120, 24)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _on_new_game() -> void:
	Game.new_game()
	Game.save_game()
	# 起名和剧情画面还没做（第 7 天），先回到菜单。
	push_warning("New game started; story scene not implemented yet.")


func _on_continue() -> void:
	if Game.load_game():
		push_warning("Save loaded at %s; scenes not implemented yet." % Game.save.progress)
