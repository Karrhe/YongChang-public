extends Node
## 冒烟测试：检查文本表、规则读取、存档读写、假模块的接口。
## 运行：godot --headless --path . res://tests/smoke_test.tscn
## 用临时存档路径，不会碰真实存档。

const TEST_SAVE_PATH := "user://test_smoke_save.tres"
const FakeBattle := preload("res://scripts/flow/fake_battle.gd")
const FakeWork := preload("res://scripts/flow/fake_work.gd")

var failures := 0


func _ready() -> void:
	var real_path := Game.save_path
	var real_save := Game.save
	Game.save_path = TEST_SAVE_PATH

	_check("文本表能读到标题", Game.text("UI_TITLE") == "永昌堡·守潮")
	_check("文本表从 data/text 自动加载", Game.text_tables.size() >= 1)
	_check("缺少的场景显示待写", Game.text("G1-2_A") == "[待写: G1-2_A]")
	_check("规则文件都合格", Rules.errors.is_empty())
	_check("规则能读到初始粮食", int(Rules.get_value("core.new_game.rice", -1)) == 6)
	_check("找不到的规则返回默认值", Rules.get_value("no.such.key", 42) == 42)
	_check("基础分辨率 640×360",
		ProjectSettings.get_setting("display/window/size/viewport_width") == 640
		and ProjectSettings.get_setting("display/window/size/viewport_height") == 360)

	Game.new_game()
	_check("第一代名字固定", tr("NAME_GEN1") == "王成")
	_check("存档只存两个名字", Game.save.names.size() == 2)
	Game.save.names[0] = "测试名"
	Game.save.names[1] = "第三代"
	var tmp := Translation.new()
	tmp.locale = "zh"
	tmp.add_message("TEST_NAMES", "{名1}/{名2}/{名3}/{刻字}")
	TranslationServer.add_translation(tmp)
	_check("名字和刻字占位符替换正确", Game.text("TEST_NAMES") == "王成/测试名/第三代/石头要彼此咬住")
	TranslationServer.remove_translation(tmp)
	_check("新游戏使用规则里的初始人口", Game.save.people == 8)
	var tmp2 := Translation.new()
	tmp2.locale = "zh"
	tmp2.add_message("TEST_NAME2", "{名2}")
	TranslationServer.add_translation(tmp2)
	Game.save.names[0] = ""
	_check("没起名时用默认名字", Game.text("TEST_NAME2") == "阿囡")
	TranslationServer.remove_translation(tmp2)
	Game.save.names[0] = "测试名"

	var u1 := Game.save.new_unit("spearman")
	var u2 := Game.save.new_unit("craftsman")
	_check("新单位 id 不重复", u1.id != u2.id)
	Game.save.roster = [u1, u2]
	Game.save.death_battle[0] = "battle_2"
	Game.save.lanterns_defender.append({"name": "陈阿六", "gen": 1, "battle": "battle_2"})
	Game.save.hammer_text = "测试刻字"
	Game.save_game()
	Game.save.people = 0
	var loaded := Game.load_game()
	_check("存档能读回", loaded and Game.save.people == 8 and Game.save.names[0] == "测试名")
	_check("新字段能读回", loaded and Game.save.roster.size() == 2
		and Game.save.death_battle[0] == "battle_2"
		and Game.save.lanterns_defender[0].name == "陈阿六"
		and Game.save.hammer_text == "测试刻字")
	Game.delete_save()
	_check("测试存档已删除", not Game.has_save())

	_check_fakes()

	Game.save_path = real_path
	Game.save = real_save
	_check("真实存档路径没变", Game.save_path == Game.DEFAULT_SAVE_PATH)
	print("SMOKE TEST: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _check_fakes() -> void:
	var walls := {"A1": {"type": "fence", "hp": [2, 2]}, "gate_A": {"type": "none", "hp": [0]}}
	var battle_input := {
		"battle_id": "battle_2", "hero": {"gen": 1, "role": "hero"}, "elder": null,
		"roster": [{"id": "u1", "type": "spearman"}, {"id": "u2", "type": "craftsman"}],
		"bonus_defenders": 0, "wall_slots": walls, "hungry": 0, "story_mode": false,
		"seen_hints": [], "story_keys": {"start": [], "end": [], "hero_death": []},
	}
	_check("假战斗的输入合格", Contract.check_battle_input(battle_input).is_empty())
	for outcome in ["held", "costly"]:
		var result := FakeBattle.make_result(battle_input, outcome, outcome == "costly")
		var errors := Contract.check_battle_result(result)
		_check("假战斗的结果合格（%s）" % outcome, errors.is_empty())
		for e in errors:
			print("    ", e)
	_check("假战斗不改输入", battle_input.roster.size() == 2)

	var work_input := {
		"work_id": "after_battle_1", "gen": 1, "people": 8, "rice": 6, "materials": 2,
		"hungry": 0, "roster": battle_input.roster, "wall_slots": walls, "granary_used": false,
	}
	_check("假劳作的输入合格", Contract.check_work_input(work_input).is_empty())
	var work_result := FakeWork.make_result(work_input, true)
	_check("假劳作的结果合格", Contract.check_work_result(work_result).is_empty())
	_check("接口检查能发现缺字段", not Contract.check_battle_result({}).is_empty())


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		failures += 1
