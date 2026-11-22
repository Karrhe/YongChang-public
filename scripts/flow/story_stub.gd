extends Control
## 剧情占位：FLOW-2 的对话播放器做好之前，整段显示文本表里这一场的文字（没有就显示 [待写: ID]）。
## 接口：setup({"scene_id", "version", "key"}) → finished({})。

signal finished(result: Dictionary)

var input: Dictionary = {}


func setup(story_input: Dictionary) -> void:
	input = story_input


func _ready() -> void:
	var box := DevUI.panel(self, input.get("scene_id", ""))
	var body := Label.new()
	body.text = Game.text(input.get("key", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(480, 0)
	box.add_child(body)
	DevUI.button(box, "UI_CONTINUE_STORY", func() -> void: finished.emit({}))
