extends Node
## 冒烟测试：检查文本表、规则读取、存档读写。
## 运行：godot --headless --path . res://tests/smoke_test.tscn

var failures := 0


func _ready() -> void:
	_check("文本表能读到标题", Game.text("UI_TITLE") == "永昌堡·守潮")
	_check("缺少的场景显示待写", Game.text("G1-2_A") == "[待写: G1-2_A]")
	_check("规则能读到初始粮食", int(Rules.get_value("work.start.rice", -1)) == 6)
	_check("找不到的规则返回默认值", Rules.get_value("no.such.key", 42) == 42)

	Game.new_game()
	_check("第一代名字固定", tr("NAME_GEN1") == "王成")
	_check("存档只存两个名字", Game.save.names.size() == 2)
	Game.save.names[0] = "测试名"
	Game.save.names[1] = "第三代"
	var tmp := Translation.new()
	tmp.locale = "zh"
	tmp.add_message("TEST_NAMES", "{名1}/{名2}/{名3}")
	TranslationServer.add_translation(tmp)
	_check("名字占位符替换正确", Game.text("TEST_NAMES") == "王成/测试名/第三代")
	TranslationServer.remove_translation(tmp)
	_check("新游戏使用规则里的初始人口", Game.save.people == 8)
	Game.save_game()
	Game.save.people = 0
	_check("存档能读回", Game.load_game() and Game.save.people == 8 and Game.save.names[0] == "测试名")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	print("SMOKE TEST: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		failures += 1
