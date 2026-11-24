extends Node
## FLOW-2 测试：剧情表的读取和检查、条件行、名字替换、头像、对话框（逐字显示、点击、回看）、剧情画面。
## 运行：godot --headless --path . res://tests/story/story_test.tscn
## 不读写存档文件。

const FIXTURE := "res://tests/story/fixture_story.csv"
const FIXTURE_BAD := "res://tests/story/fixture_bad.csv"

var failures := 0


func _ready() -> void:
	var real_save := Game.save
	_test_main_table()
	_test_reading()
	_test_conditions()
	_test_resolve()
	_test_bad_table()
	_test_bbcode_and_pauses()
	await _test_dialogue_box()
	await _test_story_scene()
	_test_flow_keys()
	Game.save = real_save
	print("STORY TEST: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _new_save() -> SaveData:
	Game.new_game()
	FlowLogic.start_new_game(Game.save)
	return Game.save


func _texts(lines: Array[Dictionary]) -> Array:
	return lines.map(func(l: Dictionary) -> String: return l.text)


func _test_main_table() -> void:
	_check("规则文件都合格", Rules.errors.is_empty())
	var table := StoryTable.reload_main()
	_check("游戏的剧情表读得到、没有问题", table.errors.is_empty() and table.has_scene("P1"))
	for battle_id: String in Rules.get_value("flow.story_keys", {}):
		var slots: Dictionary = Rules.get_value("flow.story_keys", {})[battle_id]
		for slot: String in slots:
			for id: String in slots[slot]:
				_check("战斗台词 %s 在剧情表里" % id, table.has_scene(id))
	var story_translations := Array(DirAccess.get_files_at("res://data/text/")).filter(
		func(f: String) -> bool: return f.begins_with("story.") and f.contains(".translation"))
	_check("剧情表不会被当成翻译表导入", story_translations.is_empty())


func _test_reading() -> void:
	var table := StoryTable.load_file(FIXTURE)
	_check("测试表（带 BOM、注释、空行）没有问题", table.errors.is_empty())
	_check("测试表有两个场景", table.scenes.keys() == ["T_COND", "T_PLAY"])
	_check("一场的行按文件顺序", table.scenes.T_COND[0].line_id == "01" and table.scenes.T_COND[7].line_id == "08")
	_check("引号里的半角逗号和引号读对了", table.scenes.T_PLAY[1].text == "半角逗号, 和\"引号\"")
	_check("读不到的文件报问题", not StoryTable.load_file("res://tests/story/no_such.csv").errors.is_empty())


func _test_conditions() -> void:
	var table := StoryTable.load_file(FIXTURE)
	var save := _new_save()
	_check("都活着：一代存活、二代甲、组合",
		_texts(table.lines("T_COND", save)) == ["开头。", "一代存活", "甲", "组合"])

	save.hero_alive[0] = false
	save.hero_alive[1] = false
	save.death_battle[1] = "battle_4"
	_check("王成和 {名2} 阵亡（死于第四场），阿棠、周砚在",
		_texts(table.lines("T_COND", save)) == ["开头。", "一代阵亡", "乙", "死于第四场"])

	save.companion_alive[0] = false
	save.companion_alive[1] = false
	save.death_battle[1] = "battle_5"
	_check("一代、二代都不在：只有旁白",
		_texts(table.lines("T_COND", save)) == ["开头。", "都不在"])

	_check("条件名检查", StoryTable.is_known_condition("GEN1_ALIVE&DEATH_B9")
		and not StoryTable.is_known_condition("DEATH_B0") and not StoryTable.is_known_condition("gen1_alive"))


func _test_resolve() -> void:
	var table := StoryTable.load_file(FIXTURE)
	var save := _new_save()
	save.names[0] = "石娘"
	save.names[1] = "阿潮"
	var lines := table.lines("T_PLAY", save)
	_check("说话人和台词里的名字替换了", lines[0].speaker == "石娘" and lines[0].text == "（放下石锤）阿潮，过来。")
	_check("头像按说话人自动取", lines[0].portrait == "gen2")
	_check("头像可以在表里改", lines[1].portrait == "gen2_custom")
	_check("头像写 - 就不要", lines[2].portrait == "")
	_check("没配头像的人只显示名字", lines[3].speaker == "工头" and lines[3].portrait == "")
	_check("空说话人算旁白", lines[4].narration and lines[4].speaker == "")
	var narr := table.lines("T_COND", save)[0]
	_check("旁白不显示名字和头像", narr.narration and narr.speaker == "" and narr.portrait == "")
	_check("选项行不播放", not "按钮" in _texts(table.lines("T_COND", save)))
	var opt := table.find_line("T_COND", "optA_say", save)
	_check("选项行能按 line_id 取到", table.find_line("T_COND", "optA", save).text == "按钮"
		and opt.speaker == "石娘")
	var missing := table.lines("G9-9", save)
	_check("没录的场景显示待写", missing.size() == 1 and missing[0].text == "[待写: G9-9]")
	Game.save = save
	_check("不给存档时用当前存档", table.lines("T_PLAY")[0].speaker == "石娘")


func _test_bad_table() -> void:
	var table := StoryTable.load_file(FIXTURE_BAD)
	var all := "\n".join(table.errors)
	_check("坏表报 5 个问题", table.errors.size() == 5)
	_check("报未知条件", all.contains("unknown condition GEN4_ALIVE") and all.contains("unknown condition DEATH_B10"))
	_check("报行号重复", all.contains("line_id repeated"))
	_check("报列数不对", all.contains("expected 6 columns"))
	_check("报台词为空", all.contains("text is empty"))


func _test_bbcode_and_pauses() -> void:
	var grey := Color.html("#8595a1")
	_check("动作换成灰色", DialogueBox.to_bbcode("（坐下）潮退了。", grey) == "[color=#8595a1]（坐下）[/color]潮退了。")
	_check("方括号转义", DialogueBox.to_bbcode("[b]", grey) == "[lb]b]")
	_check("句号后停得久", DialogueBox.pause_after("。") > DialogueBox.pause_after("，"))
	_check("逗号后停一下", DialogueBox.pause_after("，") > 0.0)
	_check("普通字不停", DialogueBox.pause_after("潮") == 0.0)


func _test_dialogue_box() -> void:
	var table := StoryTable.load_file(FIXTURE)
	var save := _new_save()
	Game.save = save
	var box: DialogueBox = load("res://scenes/story/dialogue_box.tscn").instantiate()
	add_child(box)
	var finished := [0]
	box.done.connect(func() -> void: finished[0] += 1)
	_check("没播放时不显示", not box.visible)

	box.play(["T_PLAY"], table)
	_check("播放 5 句", box.lines.size() == 5 and box.index == 0 and box.visible)
	_check("第一句从第 0 个字开始逐字显示", box.typing and box._text.visible_characters == 0)
	await get_tree().create_timer(0.25).timeout
	var shown: int = box._text.visible_characters
	_check("过一会儿显示出几个字", shown > 0 and box.typing)
	box.advance()
	_check("点一下显示整句", not box.typing and box._text.visible_characters == -1 and box.index == 0)
	box.advance()
	_check("再点一下到下一句", box.index == 1 and box.typing)
	_check("有头像 ID 但没有图：画色块", box._portrait_slot.visible and box._portrait_block.visible)

	box.advance()
	box.advance()
	_check("头像写 - 时不显示头像", box.index == 2 and not box._portrait_slot.visible)

	box.open_backlog()
	_check("回看列出已经显示的 3 句", box.is_backlog_open() and box._backlog_list.get_child_count() == 3)
	box.advance()
	_check("回看时点一下只关回看", not box.is_backlog_open() and box.index == 2)

	# 等最后一句自己显示完，再点一下就播完。
	box.advance()
	box.advance()
	box.advance()
	box.advance()
	_check("到最后一句", box.index == 4)
	await get_tree().create_timer(2.0).timeout
	_check("不点也会逐字显示完", not box.typing)
	box.advance()
	_check("播完发 done、隐藏", finished[0] == 1 and not box.visible and not box.playing)
	box.advance()
	_check("播完后再点没反应", finished[0] == 1)

	box.play([], table)
	await get_tree().process_frame
	_check("没有台词时直接 done", finished[0] == 2)

	box.play(["B8_start"])
	_check("不给表时用游戏的剧情表", box.lines.size() == 4 and box.lines[3].speaker == Game.fill_names("{名3}"))
	box.queue_free()
	await get_tree().process_frame


func _test_story_scene() -> void:
	_new_save()
	var scene: Node = load("res://scenes/story/story.tscn").instantiate()
	scene.setup({"scene_id": "P1", "key": "P1", "gen": 1})
	var result := [null]
	scene.finished.connect(func(r: Dictionary) -> void: result[0] = r)
	add_child(scene)
	_check("剧情画面播放 P1", scene.box.lines.size() == 3 and scene.box.lines[2].speaker == "峤叔")
	_check("P1 用宗祠背景图，按第一代调色",
		scene.background is TextureRect and scene.background.modulate == Color.html("#fff0d8"))
	var bare: Node = load("res://scenes/story/story.tscn").instantiate()
	bare.setup({"scene_id": "NO_SUCH_SCENE", "key": "P1", "gen": 1})
	add_child(bare)
	_check("没配背景图的场景按代用整体色",
		bare.background is ColorRect and bare.background.color == Color.html("#854c30"))
	bare.queue_free()
	for i in 6:
		scene.box.advance()
	_check("点完交回 finished({})", result[0] == {})
	scene.queue_free()

	var missing: Node = load("res://scenes/story/story.tscn").instantiate()
	missing.setup({"scene_id": "G1-3", "key": "G1-3_A", "gen": 1})
	add_child(missing)
	_check("没录的场景显示待写", missing.box.lines[0].text == "[待写: G1-3_A]")
	missing.queue_free()
	await get_tree().process_frame


func _test_flow_keys() -> void:
	var save := _new_save()
	var g26 := FlowLogic.find_node("G2-6")
	save.goal_met[1] = true
	_check("G2-6 主角在、目标达成", FlowLogic.story_key(save, g26) == "G2-6_A_met")
	save.hero_alive[1] = false
	save.goal_met[1] = false
	_check("G2-6 主角阵亡、目标未达成", FlowLogic.story_key(save, g26) == "G2-6_B_unmet")
	_check("流程用真的剧情画面",
		ResourceLoader.exists(Rules.get_value("flow.scenes.story", "")))


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		failures += 1
