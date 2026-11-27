extends Node
## END 测试：放灯分组、三代墓志（含死亡场次替换句）、祠堂记录、E1 的版本和条件行、整个结局从头点到尾。
## 运行：godot --headless --path . res://tests/ending/ending_test.tscn
## 用假存档，不读写存档文件。

var failures := 0


func _ready() -> void:
	var real_save := Game.save
	StoryTable.reload_main()
	_test_tables()
	_test_lantern_plan()
	_test_epitaphs()
	_test_records()
	_test_e1()
	await _test_full_run(_fake_save(true), "主角都活着、有灯")
	await _test_full_run(_new_save(), "一盏灯也没有")
	Game.save = real_save
	print("ENDING TEST: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	Game.quit(failures)


func _new_save() -> SaveData:
	Game.new_game()
	FlowLogic.start_new_game(Game.save)
	Game.save.names[0] = "石娘"
	Game.save.names[1] = "阿潮"
	return Game.save


## 失去两个乡亲、一个守军；第一代主角死在 battle_2；做了五个选择。
func _fake_save(gen2_alive: bool) -> SaveData:
	var save := _new_save()
	save.lanterns_villager.assign([
		{"key": "LANTERN_VILLAGER_G1_01", "name": "陈阿六", "gen": 1, "battle": "battle_1"},
		{"key": "LANTERN_VILLAGER_G2_01", "name": "林二嫂", "gen": 2, "battle": "battle_5"}])
	save.lanterns_defender.assign([{"key": "LANTERN_DEFENDER_G3_01", "name": "无名", "gen": 3, "battle": "battle_9"}])
	save.lanterns_hero.assign([{"name": "王成", "gen": 1, "battle": "battle_2"}])
	save.hero_alive[0] = false
	save.death_battle[0] = "battle_2"
	if not gen2_alive:
		save.hero_alive[1] = false
		save.death_battle[1] = "battle_5"
	save.choices = {"C1": "A", "C2": "B", "C3": "A", "C4": "B", "C5": "A"}
	return save


func _test_tables() -> void:
	_check("规则文件都合格", Rules.errors.is_empty())
	_check("剧情表没有问题", StoryTable.main().errors.is_empty())
	for id in ["E1_A", "E1_B", "E2", "E3_5", "E6"]:
		_check("剧情表有结局场景 %s" % id, StoryTable.main().has_scene(id))
	_check("结局文本表自动加载", Game.text("END_FINAL") == "灯会漂远，名字不会。")


func _test_lantern_plan() -> void:
	var plan := EndingScreen.lantern_plan(_fake_save(true))
	_check("三组都有灯", plan.map(func(g: Dictionary) -> String: return g.group) == ["villager", "defender", "hero"])
	_check("乡亲的灯带名字", Array(plan[0].names) == ["陈阿六", "林二嫂"] and plan[0].text == "收稻的，晒网的，在灶边等人的。")
	_check("主角和同伴那组的文字就是名字", plan[2].text == "王成")
	var save := _fake_save(true)
	save.lanterns_defender.clear()
	save.lanterns_hero.append({"name": "阿棠", "gen": 1, "battle": "battle_3"})
	plan = EndingScreen.lantern_plan(save)
	_check("没有灯的组跳过", plan.size() == 2 and plan[1].text == "王成、阿棠")
	_check("一盏灯也没有时分组为空", EndingScreen.lantern_plan(_new_save()).is_empty())


func _test_epitaphs() -> void:
	var texts := EndingScreen.epitaph_texts(_new_save())
	_check("三代墓志三句", texts.size() == 3)
	_check("都活着：长寿而终，名字替换了", texts[1].begins_with("石娘，王成之女，永昌堡石匠") and texts[2].begins_with("阿潮，石娘之子"))
	texts = EndingScreen.epitaph_texts(_fake_save(false))
	_check("第一代阵亡用战死那句", texts[0].contains("在村外栅栏前挡住来犯者") and not texts[0].contains("待写"))
	_check("第二代死在 battle_5：换成那一场的替换句", texts[1] == "石娘，王成之女，守筑堡工地时阵亡。她守住了粮道，没能看见城墙合拢。")
	var save := _fake_save(false)
	save.death_battle[1] = ""
	_check("没有对应的替换句时用默认那句", EndingScreen.epitaph_texts(save)[1].ends_with("她没见到城墙合拢，她砌的石头留在了城门里。"))


func _test_records() -> void:
	var texts := EndingScreen.record_texts(_fake_save(true))
	_check("五个选择各一句", texts.size() == 5)
	_check("按选的 A / B 取", texts[0].begins_with("他们动用香火钱") and texts[1].begins_with("他们没有调走守军"))
	var save := _new_save()
	save.choices = {"C1": "B"}
	_check("没做的选择不写", EndingScreen.record_texts(save).size() == 1)


func _test_e1() -> void:
	var step: Dictionary = Rules.get_value("ending.steps", [])[0]
	var save := _new_save()
	_check("第三代主角在：E1_A", EndingScreen.scene_for(step, save) == "E1_A")
	var lines := StoryTable.main().lines("E1_A", save)
	_check("E1_A：{名2} 在时她说话，周砚那句不显示",
		lines.any(func(l: Dictionary) -> bool: return l.speaker == "石娘")
		and not lines.any(func(l: Dictionary) -> bool: return l.speaker == "周砚"))
	save.hero_alive[1] = false
	lines = StoryTable.main().lines("E1_A", save)
	_check("E1_A：{名2} 不在、周砚在时换周砚", lines.any(func(l: Dictionary) -> bool: return l.speaker == "周砚"))
	save.hero_alive[2] = false
	_check("第三代主角阵亡：E1_B", EndingScreen.scene_for(step, save) == "E1_B")


func _test_full_run(save: SaveData, label: String) -> void:
	var ending: EndingScreen = load("res://scenes/ending/ending.tscn").instantiate()
	ending.setup({"save": save})
	var result := [null]
	ending.finished.connect(func(r: Dictionary) -> void: result[0] = r)
	add_child(ending)
	var steps: Array = Rules.get_value("ending.steps", [])
	var seen := []
	var most_lanterns := 0
	var plaque_texts := []
	var lantern_lines := []
	var clicks := 0
	while not ending.done and clicks < 400:
		if seen.is_empty() or seen[-1] != ending.step_index:
			seen.append(ending.step_index)
		var type: String = steps[ending.step_index].type
		if type == "lanterns":
			var lanterns := ending.layer.get_children().filter(
				func(n: Node) -> bool: return (n is ColorRect or n is TextureRect) and not n.is_queued_for_deletion())
			most_lanterns = maxi(most_lanterns, lanterns.size())
			if ending.box.playing and not ending.box.lines.is_empty():
				var text: String = ending.box.lines[0].text
				if not text in lantern_lines:
					lantern_lines.append(text)
		if ending.waiting:
			for n in ending.layer.find_children("*", "Label", true, false):
				if not n.is_queued_for_deletion():
					plaque_texts.append(n.text)
		ending.advance()
		clicks += 1
		await get_tree().process_frame
	_check("%s：每一步都走到了" % label, seen == range(steps.size()))
	_check("%s：结束时交回 finished({})" % label, result[0] == {})
	var lantern_total := save.lantern_count()
	if lantern_total > 0:
		_check("%s：放出的灯和存档里一样多" % label, most_lanterns == lantern_total)
		_check("%s：每组一句" % label, lantern_lines.size() == 3)
		_check("%s：墓志、记录、最后一句都显示了" % label, plaque_texts.has("石娘，王成之女，永昌堡石匠。砌过敌台和城堞，台风后带人补墙。到老还认得自己敲进去的每一块石头。")
			and plaque_texts.has("他们动用香火钱打了枪头、补了栅栏，每一笔都记在账上。") and plaque_texts.has("灯会漂远，名字不会。"))
	else:
		_check("%s：显示没有新灯的那句" % label, lantern_lines == ["今年的河面上没有新灯。人们照旧把旧灯点亮，放下水。"])
	ending.queue_free()
	await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		failures += 1
