extends Control
## 假劳作：WORK 交付前顶替 res://scenes/work/work.tscn（TEAM-001 §1）。
## 和真劳作同一个接口：setup(input) → finished(result)。资源、墙位、守军原样返回。

signal finished(result: Dictionary)

var input: Dictionary = {}


func setup(work_input: Dictionary) -> void:
	input = work_input.duplicate(true)


func _ready() -> void:
	var box := DevUI.panel(self, "%s  %s" % [Game.text("DEV_FAKE_WORK"), input.get("work_id", "")])
	DevUI.button(box, "DEV_GOAL_MET", func() -> void: finished.emit(make_result(input, true)))
	DevUI.button(box, "DEV_GOAL_NOT_MET", func() -> void: finished.emit(make_result(input, false)))


static func make_result(work_input: Dictionary, goal_met: bool) -> Dictionary:
	var result := work_input.duplicate(true)
	result["goal_met"] = goal_met
	return result
