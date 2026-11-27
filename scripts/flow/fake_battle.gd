extends Control
## 假战斗：BAT 交付前顶替 res://scenes/battle/battle.tscn（TEAM-001 §1）。
## 和真战斗同一个接口：setup(input) → finished(result)。按钮直接给结果。

signal finished(result: Dictionary)

var input: Dictionary = {}


func setup(battle_input: Dictionary) -> void:
	input = battle_input.duplicate(true)


func _ready() -> void:
	var box := DevUI.panel(self, "%s  %s" % [Game.text("DEV_FAKE_BATTLE"), input.get("battle_id", "")])
	DevUI.button(box, "DEV_HELD", func() -> void: _finish("held", false))
	DevUI.button(box, "DEV_COSTLY", func() -> void: _finish("costly", false))
	var hero_btn := DevUI.button(box, "DEV_HERO_DIED", func() -> void: _finish("costly", true))
	hero_btn.disabled = input.get("hero") == null


## 按接口 v2 拼一份结果：守住时不失去人；惨胜时失去 2 个乡亲、1 个守军（名单最后一个）。
static func make_result(battle_input: Dictionary, outcome: String, hero_died: bool) -> Dictionary:
	var roster: Array = battle_input.get("roster", []).duplicate(true)
	var defenders_lost := 0
	if outcome == "costly" and not roster.is_empty():
		roster.pop_back()
		defenders_lost = 1
	return {
		"battle_id": battle_input.get("battle_id", ""),
		"outcome": outcome,
		"hero_died": hero_died and battle_input.get("hero") != null,
		"elder_retired": false,
		"roster": roster,
		"defenders_lost": defenders_lost,
		"villagers_saved": 4 if outcome == "held" else 3,
		"villagers_lost": 0 if outcome == "held" else 2,
		"raiders_defeated": 3,
		"rice_looted": 0,
		"wall_slots": battle_input.get("wall_slots", {}).duplicate(true),
		"seen_hints": Array(battle_input.get("seen_hints", [])),
	}


func _finish(outcome: String, hero_died: bool) -> void:
	finished.emit(make_result(input, outcome, hero_died))
