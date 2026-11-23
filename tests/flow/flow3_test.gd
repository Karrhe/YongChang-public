extends Node
## FLOW-3 测试：剧情选择 C1–C5 的效果和付不起时的处理、选择画面、起名和石锤刻字、规则事件的说明。
## 运行：godot --headless --path . res://tests/flow/flow3_test.tscn
## 不读写存档文件。

var failures := 0


func _ready() -> void:
	var real_save := Game.save
	_test_effects()
	_test_cannot_pay()
	_test_choice_input()
	await _test_choice_scene()
	_test_naming_rules()
	await _test_naming_scene()
	_test_event_notice()
	Game.save = real_save
	print("FLOW3 TEST: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _new_save() -> SaveData:
	Game.new_game()
	FlowLogic.start_new_game(Game.save)
	return Game.save


func _stone(save: SaveData, slots: Array) -> void:
	for slot: String in slots:
		save.wall_slots[slot] = {"type": "stone", "hp": [6, 6]}


func _test_effects() -> void:
	var save := _new_save()
	FlowLogic.apply_choice(save, "C1", "A")
	_check("C1-A：材料 +3、多一名枪兵", save.materials == 2 + 3 and save.roster.size() == 1
		and save.roster[0].type == "spearman" and save.choices.C1 == "A")

	save = _new_save()
	save.roster.assign([save.new_unit("spearman"), save.new_unit("craftsman"), save.new_unit("spearman")])
	save.wall_slots.B2 = {"type": "fence", "hp": [2, 1]}
	FlowLogic.apply_choice(save, "C2", {"pick": "A", "slots": ["B2"]})
	_check("C2-A：调走最后加入的枪兵", save.roster.size() == 2 and save.roster[0].id == "u1" and save.roster[1].type == "craftsman")
	_check("C2-A：选的墙位筑成满 HP 石墙", save.wall_slots.B2 == {"type": "stone", "hp": [6, 6]})

	save = _new_save()
	FlowLogic.apply_choice(save, "C3", "A")
	_check("C3-A：粮食 +5、人口 −1", save.rice == 6 + 5 and save.people == 8 - 1)
	_check("C3-A 不放灯", save.lantern_count() == 0)

	save = _new_save()
	_stone(save, ["A1", "A2", "B1", "C3"])
	FlowLogic.apply_choice(save, "C4", {"pick": "A", "slots": ["A1", "B1", "C3"]})
	_check("C4-A：拆掉选的三段", save.wall_slots.A1.type == "none" and save.wall_slots.B1.hp == [0, 0]
		and save.wall_slots.C3.type == "none" and save.wall_slots.A2.type == "stone")
	_check("C4-A：材料 +6、粮食 +3", save.materials == 2 + 6 and save.rice == 6 + 3)

	save = _new_save()
	FlowLogic.apply_choice(save, "C4", "B")
	_check("C4-B：粮食 −2", save.rice == 4)
	save = _new_save()
	FlowLogic.apply_choice(save, "C5", "A")
	_check("C5-A：粮食 −4", save.rice == 2 and save.choices.C5 == "A")
	FlowLogic.apply_choice(save, "C1", "B")
	_check("B 选项：只记下选择", save.choices.C1 == "B" and save.rice == 2 and save.materials == 2)


func _test_cannot_pay() -> void:
	var save := _new_save()
	var states := Choices.option_states(save, "C2", 2)
	_check("C2-A：没有守军不能选", not states.A.enabled and states.A.reason == "CHOICE_NEED_DEFENDER" and states.B.enabled)
	save.people = 4
	_check("C3-A：人口只有 4 不能选", Choices.option_states(save, "C3", 2).A.reason == "CHOICE_NEED_PEOPLE")
	_stone(save, ["A1", "A2"])
	var c4 := Choices.option_states(save, "C4", 3)
	_check("C4-A：石墙不到 3 段不能选", not c4.A.enabled and c4.A.reason_args == {"count": 3})

	save.rice = 1
	c4 = Choices.option_states(save, "C4", 3)
	_check("C4-B：粮不够时要开义仓", c4.B.enabled and c4.B.granary)
	var out := FlowLogic.apply_choice(save, "C4", "B")
	_check("开了义仓：粮食补到 0，记下这一代用过", out.granary and save.rice == 0 and save.granary_used[2])
	c4 = Choices.option_states(save, "C4", 3)
	_check("A、B 都不能选时 B 照样能选", not c4.A.enabled and c4.B.enabled and not c4.B.granary)
	FlowLogic.apply_choice(save, "C4", "B")
	_check("义仓开过以后粮食最低扣到 0", save.rice == 0)
	_check("C5-A：粮不够、义仓也开过了就不能选", Choices.option_states(save, "C5", 3).A.reason == "CHOICE_NEED_RICE")
	_check("别的代的义仓不受影响", Choices.option_states(save, "C4", 2).B.granary)


func _test_choice_input() -> void:
	var save := _new_save()
	var c1 := FlowLogic.choice_input(save, FlowLogic.find_node("C1"))
	_check("C1 主角在时播 C1_A", c1.key == "C1_A" and c1.gen == 1)
	save.hero_alive[0] = false
	_check("C1 主角阵亡时播 C1_B", FlowLogic.choice_input(save, FlowLogic.find_node("C1")).key == "C1_B")
	_check("第三代的选择不分版本", FlowLogic.choice_input(save, FlowLogic.find_node("C4")).key == "C4")
	var c3 := FlowLogic.choice_input(save, FlowLogic.find_node("C3"))
	_check("C3-A 选完播结果句", c3.options.A.after == ["C3_A_result"])
	_check("义仓的话按代取", c3.granary_scene == "EVT_granary_G2")
	_stone(save, ["A1", "B1", "C1", "C2"])
	var c4 := FlowLogic.choice_input(save, FlowLogic.find_node("C4"))
	_check("C4-A 要从 4 段石墙里选 3 段", c4.options.A.slot_pick.kind == "demolish"
		and c4.options.A.slot_pick.count == 3 and c4.options.A.slot_pick.slots.size() == 4)
	_check("C2-A 从不是石墙的墙位里选", Choices.slot_pick(save, "C2", "A").slots.size() == 5)


func _test_choice_scene() -> void:
	var save := _new_save()
	_stone(save, ["A1", "B1", "C1", "C2"])
	var scene: Node = load("res://scenes/flow/choice.tscn").instantiate()
	scene.setup(FlowLogic.choice_input(save, FlowLogic.find_node("C4")))
	var result := [null]
	scene.finished.connect(func(r: Dictionary) -> void: result[0] = r)
	add_child(scene)
	_check("先播选择前的对话", scene.box.playing)
	while scene.box.playing:
		scene.box.advance()
	await get_tree().process_frame
	_check("对话播完显示两个选项", scene.option_buttons.size() == 2 and not scene.option_buttons.A.disabled)
	scene.option_buttons.A.pressed.emit()
	while scene.box.playing:
		scene.box.advance()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("选 A 后列出 4 段石墙", scene.slot_buttons.size() == 4 and scene.slot_ok.disabled)
	for slot: String in ["A1", "B1", "C1", "C2"]:
		scene.slot_buttons[slot].button_pressed = true
	_check("最多选 3 段", scene.picked_slots == ["A1", "B1", "C1"] and not scene.slot_buttons.C2.button_pressed)
	_check("选够了才能确定", not scene.slot_ok.disabled)
	scene.slot_ok.pressed.emit()
	_check("交回选择和墙位", result[0] == {"pick": "A", "slots": ["A1", "B1", "C1"]})
	scene.queue_free()

	save = _new_save()
	var c2: Node = load("res://scenes/flow/choice.tscn").instantiate()
	c2.setup(FlowLogic.choice_input(save, FlowLogic.find_node("C2")))
	c2.finished.connect(func(r: Dictionary) -> void: result[0] = r)
	add_child(c2)
	while c2.box.playing:
		c2.box.advance()
	await get_tree().process_frame
	_check("付不起的选项按钮不能按", c2.option_buttons.A.disabled and not c2.option_buttons.B.disabled)
	c2.option_buttons.B.pressed.emit()
	while c2.box.playing:
		c2.box.advance()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("选 B 不用选墙位，直接交回", result[0] == {"pick": "B", "slots": []})
	c2.queue_free()
	await get_tree().process_frame


func _test_naming_rules() -> void:
	var taken := ["王成", "阿棠", "石娘"]
	_check("两个汉字可以", NamingScreen.check_name("阿海", "阿潮", taken, 4).is_empty())
	_check("空着用默认名字", NamingScreen.check_name("  ", "阿潮", taken, 4).is_empty())
	_check("默认名字被占了也不行", NamingScreen.check_name("", "石娘", taken, 4).key == "NAMING_ERR_TAKEN")
	_check("五个字太长", NamingScreen.check_name("一二三四五", "阿潮", taken, 4).key == "NAMING_ERR_CHARS")
	_check("不能用字母", NamingScreen.check_name("Ada", "阿潮", taken, 4).key == "NAMING_ERR_CHARS")
	_check("不能和固定角色重名", NamingScreen.check_name("阿棠", "阿潮", taken, 4).args == {"name": "阿棠"})
	_check("刻字可以带标点", NamingScreen.check_hammer("石头要彼此咬住。", 12).is_empty())
	_check("刻字不能有花括号", NamingScreen.check_hammer("{名2}", 12).key == "NAMING_ERR_HAMMER")
	_check("刻字太长", not NamingScreen.check_hammer("一二三四五六七八九十十一十二十三", 12).is_empty())

	var save := _new_save()
	var in2 := FlowLogic.naming_input(save, FlowLogic.find_node("naming_2"))
	_check("第二代：问刻字、默认阿囡、王成和阿棠不能用", in2.ask_hammer and in2.default_name == "阿囡"
		and "王成" in in2.taken and "阿棠" in in2.taken and not "阿囡" in in2.taken)
	FlowLogic.apply_naming(save, 2, {"name": "石娘", "hammer": ""})
	_check("刻字空着时显示默认刻字", save.names[0] == "石娘" and Game.hammer_text(save) == "石头要彼此咬住")
	var in3 := FlowLogic.naming_input(save, FlowLogic.find_node("naming_3"))
	_check("第三代：不问刻字，不能和 {名2} 重名", not in3.ask_hammer and "石娘" in in3.taken)
	FlowLogic.apply_naming(save, 3, {})
	_check("第三代空着用默认名字", save.names[1] == "阿潮")


func _test_naming_scene() -> void:
	var save := _new_save()
	var scene: NamingScreen = load("res://scenes/naming/naming.tscn").instantiate()
	scene.setup(FlowLogic.naming_input(save, FlowLogic.find_node("naming_2")))
	var result := [null]
	scene.finished.connect(func(r: Dictionary) -> void: result[0] = r)
	add_child(scene)
	_check("起名界面显示剧本里的问句", scene.prompt.text.contains("她叫什么名字"))
	scene.edit.text = "王成"
	scene.submit()
	_check("重名时说明原因、留在这一步", scene.step == "name" and scene.error.text.contains("王成") and result[0] == null)
	scene.edit.text = "石娘"
	scene.submit()
	_check("名字合格后问石锤刻字", scene.step == "hammer" and scene.error.text == "")
	scene.edit.text = "墙在人在"
	scene.edit.text_submitted.emit(scene.edit.text)
	_check("回车确定，交回名字和刻字", result[0] == {"name": "石娘", "hammer": "墙在人在"})
	scene.queue_free()
	await get_tree().process_frame


func _test_event_notice() -> void:
	var save := _new_save()
	save.materials = 5
	var notice := FlowLogic.event_notice("gen1_to_gen2", FlowLogic.apply_event(save, "gen1_to_gen2"))
	_check("换代说明：先播捐银的剧情", notice.keys == ["EVT_donation"])
	_check("换代说明：数字填进去了", notice.append[0].text.contains("5 → 2") and notice.append[0].text.contains("现在有 8"))
	notice = FlowLogic.event_notice("typhoon", FlowLogic.apply_event(save, "typhoon"))
	_check("台风说明写 HP −3", notice.keys.is_empty() and notice.append[0].text.contains("−3"))
	_check("退休没有说明", FlowLogic.event_notice("retire_elder", FlowLogic.apply_event(save, "retire_elder")).is_empty())


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		failures += 1
