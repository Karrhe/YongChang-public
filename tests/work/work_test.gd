extends Node
## WORK 测试：分配人手、修建（栅栏、石墙、升级、废墟）、修墙、训练、吃粮、义仓和饥饿、目标卡、结果格式、劳作画面。
## 运行：godot --headless --path . res://tests/work/work_test.tscn
## 用假存档，不读写存档文件。

var failures := 0


func _ready() -> void:
	var real_save := Game.save
	_check("规则文件都合格", Rules.errors.is_empty())
	_test_jobs()
	_test_build()
	_test_repair()
	_test_food()
	_test_goals()
	await _test_scene()
	Game.save = real_save
	print("WORK TEST: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _state(work_id: String, edit: Callable = Callable()) -> WorkState:
	Game.new_game()
	FlowLogic.start_new_game(Game.save)
	if edit.is_valid():
		edit.call(Game.save)
	var s := WorkState.new()
	s.setup(FlowLogic.work_input(Game.save, FlowLogic.find_node(work_id)))
	return s


func _test_jobs() -> void:
	var s := _state("after_battle_1")
	_check("开始时 8 人都空闲", s.idle() == 8)
	s.set_job("farm", 5)
	s.set_job("gather", 5)
	_check("分配不超过空闲的人", s.assign.gather == 3 and s.idle() == 0)
	s.set_job("gather", 1)
	s.set_job("train", 2)
	_check("训练 2 人，默认练枪兵", s.train_types == ["spearman", "spearman"])
	s.cycle_train_type(1)
	_check("点一下换兵种", s.train_types[1] == "crossbow")
	_check("第一代不能练信使", not "courier" in Rules.get_value("work.train_types.1", []))
	var report := s.end_season()
	_check("季末：种田 5 人粮食 +15，8 人吃 8", s.rice == 6 + 15 - 8 and report.rice == 7)
	_check("采料 1 人材料 +2", s.materials == 4)
	_check("训练的人进名单，id 不重复", s.roster.size() == 2 and s.roster[0].id != s.roster[1].id and s.roster[1].type == "crossbow")
	_check("训练只占这一季", s.assign.train == 0 and s.assign.farm == 5)
	_check("第 2 季", s.season == 2 and not s.done)
	s.end_season()
	_check("两季后结束", s.done)
	_check("结果格式合格", Contract.check_work_result(s.result()).is_empty())


func _test_build() -> void:
	var s := _state("after_battle_1", func(save: SaveData) -> void: save.materials = 5)
	_check("没有修建的人就排不了", not s.toggle_build("A1"))
	s.set_job("build", 3)
	_check("第一代每段 1 人 + 2 材料：3 人 5 材料能修 2 段", s.build_capacity() == 2)
	_check("排两段", s.toggle_build("A1") and s.toggle_build("gate_A") and not s.toggle_build("A2"))
	_check("排进去的材料不能再拿去修墙", s.reserved_materials() == 4)
	s.end_season()
	_check("修成栅栏和栅栏门，HP 满", s.wall_slots.A1 == {"type": "fence", "hp": [2, 2]} and s.wall_slots.gate_A == {"type": "fence", "hp": [4]})
	_check("花了 4 份材料", s.materials == 1)
	_check("修好的栅栏不能再修建", not s.can_build("A1"))

	var s2 := _state("after_battle_4", func(save: SaveData) -> void:
		save.materials = 10
		save.wall_slots.A1 = {"type": "fence", "hp": [2, 2]}
		save.wall_slots.B1 = {"type": "stone", "hp": [0, 6]})
	s2.set_job("build", 5)
	_check("第二代每段 2 人：5 人能修 2 段", s2.build_capacity() == 2)
	_check("栅栏可以升级成石墙，石墙废墟可以重建", s2.can_build("A1") and s2.can_build("B1"))
	s2.toggle_build("A1")
	s2.toggle_build("B1")
	s2.end_season()
	_check("升级和重建都修成满 HP 石墙", s2.wall_slots.A1 == {"type": "stone", "hp": [6, 6]} and s2.wall_slots.B1.hp == [6, 6])


func _test_repair() -> void:
	var s := _state("after_battle_7", func(save: SaveData) -> void:
		save.materials = 3
		save.wall_slots.A1 = {"type": "stone", "hp": [3, 5]}
		save.wall_slots.A2 = {"type": "stone", "hp": [0, 2]})
	_check("修墙：每格每 3 点 1 份，不足 3 点向上取整", s.repair_cost("A1") == 2)
	_check("废墟的格子不算修墙", s.repair_cost("A2") == 2)
	_check("修墙不占人手", s.repair("A1") and s.wall_slots.A1.hp == [6, 6] and s.materials == 1 and s.idle() == 8)
	_check("材料不够修不了", not s.repair("A2"))


func _test_food() -> void:
	var s := _state("after_battle_1")
	s.end_season()  # 没人种田：6 − 8 < 0
	_check("粮不够：开宗族义仓补到 0，不饿", s.rice == 0 and s.hungry == 0 and s.granary_used and s.reports[0].granary)
	s.end_season()
	_check("义仓开过以后：缺的变成饥饿", s.rice == 0 and s.hungry == 8)
	var s2 := _state("after_battle_2", func(save: SaveData) -> void:
		save.hungry = 3
		save.granary_used[0] = true)
	s2.set_job("farm", 8)
	_check("预览：粮食够了", s2.preview().hungry == 0 and not s2.preview().granary)
	s2.end_season()
	_check("粮食够了饥饿就消失", s2.hungry == 0 and s2.rice == 6 + 24 - 8)


func _test_goals() -> void:
	var s := _state("after_battle_2", func(save: SaveData) -> void:
		for slot in ["A1", "A2", "A3", "B1", "B2", "B3"]:
			save.wall_slots[slot] = {"type": "fence", "hp": [2, 2]}
		save.wall_slots.gate_B = {"type": "fence", "hp": [4]}
		for i in 3:
			save.roster.append(save.new_unit("spearman")))
	var p := s.goal_progress()
	_check("第一代目标：6 段栅栏、1 道门、守军 3/4", p.walls == 6 and p.gates == 1 and p.defenders == 3 and not p.met)
	s.set_job("train", 1)
	s.end_season()
	_check("训练第 4 名后达成", s.goal_progress().met and s.result().goal_met)
	var s3 := _state("after_battle_8", func(save: SaveData) -> void:
		for slot in ["A1", "A2", "A3", "B1", "B2", "B3", "C1", "C2"]:
			save.wall_slots[slot] = {"type": "stone", "hp": [6, 6]}
		save.wall_slots.C2 = {"type": "stone", "hp": [6, 5]}
		for i in 5:
			save.roster.append(save.new_unit("spearman")))
	_check("第三代目标要修满：有一段差 1 点就没达成", s3.goal_progress().walls == 7 and not s3.goal_progress().met)
	_check("还剩几季：第二个劳作阶段第 1 季还剩 2 季", s3.seasons_left_in_gen() == 2)


func _test_scene() -> void:
	Game.new_game()
	FlowLogic.start_new_game(Game.save)
	var scene: Node = load("res://scenes/work/work.tscn").instantiate()
	scene.setup(FlowLogic.work_input(Game.save, FlowLogic.find_node("after_battle_1")))
	var result := [null]
	scene.finished.connect(func(r: Dictionary) -> void: result[0] = r)
	add_child(scene)
	await get_tree().process_frame
	scene._change("build", 1)
	scene._on_slot("A1")
	_check("在城防图上排修建", scene.state.build_queue == ["A1"] and scene.wall_map.buttons.has("A1"))
	var guard := 0
	while result[0] == null and guard < 50:
		guard += 1
		scene.auto_play_for_test()
		await get_tree().process_frame
	_check("劳作画面两季后交回结果", result[0] != null and Contract.check_work_result(result[0]).is_empty()
		and result[0].wall_slots.A1.type == "fence")
	scene.queue_free()
	await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		failures += 1
