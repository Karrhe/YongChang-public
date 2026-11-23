extends Control
## 剧情选择占位：真的选择画面（scenes/flow/choice.tscn）不存在时才用，只交回选了 A 还是 B。
## 接口：setup({"choice_id"}) → finished({"pick": "A" | "B"})。

signal finished(result: Dictionary)

var input: Dictionary = {}


func setup(choice_input: Dictionary) -> void:
	input = choice_input


func _ready() -> void:
	var id: String = input.get("choice_id", "")
	var box := DevUI.panel(self, "%s\n%s" % [id, Game.text(id)])
	DevUI.button(box, "UI_CHOICE_A", func() -> void: finished.emit({"pick": "A"}))
	DevUI.button(box, "UI_CHOICE_B", func() -> void: finished.emit({"pick": "B"}))
