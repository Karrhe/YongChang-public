extends Control
## 剧情占位：FLOW-2 的剧情画面（scenes/story/story.tscn）不存在时才用。现在只给结局占位用（END 做好之前）。
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
