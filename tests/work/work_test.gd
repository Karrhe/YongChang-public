extends Node
## WORK 测试（REDESIGN-002 方案一《石头要彼此咬住》）：砌石拼图的规则、石匠和石料、门、凿石、栅栏换石墙、
## 修墙、吃粮、义仓和饥饿、目标卡、台风和风化、战后塌顶、结果格式、劳作画面。
## 运行：godot --headless --path . res://tests/work/work_test.tscn
## 用假存档，不读写存档文件。

var failures := 0


func _ready() -> void:
	var real_save := Game.save
	_check("规则文件都合格", Rules.errors.is_empty())
	_test_stone_rules()
	_test_jobs_and_stones()
	_test_gate_and_chisel()
	_test_fence_to_stone()
	_test_repair()
	_test_food()
	_test_goals()
	_test_weather_and_ruins()
	await _test_scene()
	Game.save = real_save
	print("WORK TEST: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	Game.quit(failures)


func _state(work_id: String, edit: Callable = Callable()) -> WorkState:
	Game.new_game()
	FlowLogic.start_new_game(Game.save)
	if edit.is_valid():
		edit.call(Game.save)
	var s := WorkState.new()
	s.setup(FlowLogic.work_input(Game.save, FlowLogic.find_node(work_id)))
	return s


func _delivery(work_id: String, season: int = 1) -> int:
	return int(Rules.get_value("work.puzzle.deliveries", {})[work_id][season - 1].pieces)


func _test_stone_rules() -> void:
	_check("砖槽 4 × 3", StoneWall.width() == 4 and StoneWall.height() == 3)
	_check("条石转 90° 变竖的", StoneWall.shape_cells("bar2", 1) == [Vector2i(0, 1), Vector2i(0, 0)]
		or StoneWall.shape_cells("bar2", 1) == [Vector2i(0, 0), Vector2i(0, 1)])
	_check("木桩不能转", not StoneWall.can_rotate("stake3") and StoneWall.shape_cells("stake3", 1).size() == 3)
	var l := StoneWall.empty("stone")
	_check("不能悬空放", not StoneWall.can_place(l, "bar2", 0, Vector2i(0, 1)))
	_check("底行能放", StoneWall.place(l, "bar2", 0, Vector2i(0, 0)) == 1)
	_check("不能叠在别的石头上", not StoneWall.can_place(l, "wedge", 0, Vector2i(1, 0)))
	StoneWall.place(l, "bar2", 0, Vector2i(2, 0))
	_check("底行两块条石：中间是红缝，两边被跨过", StoneWall.red_seams(l) == [2])
	StoneWall.place(l, "bar2", 0, Vector2i(1, 1))
	_check("第二行条石压住下面两块：金边，红缝没了", StoneWall.gold_joints(l) == [Vector2i(2, 1)] and StoneWall.red_seams(l).is_empty())
	_check("6 格还没筑成", not StoneWall.is_built(l) and StoneWall.max_hp(l) == 0)
	StoneWall.place(l, "wedge", 0, Vector2i(0, 1))
	StoneWall.place(l, "wedge", 0, Vector2i(3, 1))
	StoneWall.place(l, "bar2", 0, Vector2i(0, 2))
	_check("10 格筑成：HP = 6 − 0 红缝 − ⌈2/2⌉ = 5", StoneWall.is_built(l) and StoneWall.max_hp(l) == 5)
	var p := StoneWall.perfect()
	_check("完美咬合的墙：填满、没有红缝、HP 6、台风不掉", StoneWall.filled(p) == 12 and StoneWall.red_seams(p).is_empty()
		and StoneWall.max_hp(p) == 6 and StoneWall.typhoon_loss(p) == 0)
	var f := StoneWall.empty("fence")
	for x in 3:
		StoneWall.place(f, "stake3", 0, Vector2i(x, 0))
	_check("三根木桩扎成栅栏：HP 2，三条红缝", StoneWall.is_built(f) and StoneWall.max_hp(f) == 2 and StoneWall.red_seams(f).size() == 3)
	_check("台风：栅栏每格 −6", StoneWall.typhoon_loss(f) == 6)
	var stack := StoneWall.empty("stone")
	for y in 3:
		StoneWall.place(stack, "bar2", 0, Vector2i(0, y))
		StoneWall.place(stack, "bar2", 0, Vector2i(2, y))
	_check("条石整齐码三层：一条通缝，HP 5，台风 −2", StoneWall.red_seams(stack) == [2] and StoneWall.max_hp(stack) == 5
		and StoneWall.typhoon_loss(stack) == 2)


func _test_jobs_and_stones() -> void:
	var s := _state("after_battle_1")
	_check("潮汐送来石料：开局 2 + 这一季 %d" % _delivery("after_battle_1"), s.materials == 2 + _delivery("after_battle_1")
		and s.stone_queue.size() == s.materials)
	_check("第一代的料全是木桩", s.stone_queue.all(func(x: Variant) -> bool: return x == "stake3"))
	_check("开始时 8 人都是石匠", s.masons() == 8 and s.placements_left() == 8 * int(Rules.get_value("work.puzzle.placements_per_mason", 3)))
	s.set_job("farm", 6)
	s.set_job("train", 5)
	_check("分配不超过空闲的人", s.assign.train == 2 and s.masons() == 0)
	_check("训练 2 人，默认练枪兵", s.train_types == ["spearman", "spearman"])
	s.cycle_train_type(1)
	_check("点一下换兵种", s.train_types[1] == "crossbow")
	_check("没有石匠就放不了", not s.place("A1", 0, 0, Vector2i(0, 0)))
	s.set_job("train", 1)
	var before := s.materials
	_check("一个石匠能放木桩", s.place("A1", 0, 0, Vector2i(0, 0)) and s.materials == before - 1 and s.stone_queue.size() == before - 1)
	_check("放出去的石匠不能再派去训练", (func() -> bool:
		s.set_job("train", 2)
		return s.masons() >= 1).call())
	s.place("A1", 0, 0, Vector2i(1, 0))
	s.place("A1", 0, 0, Vector2i(2, 0))
	_check("三根木桩扎成栅栏，城防图上就是栅栏", s.wall_slots.A1.type == "fence" and s.wall_slots.A1.hp == [2, 2])
	var eat := int(Rules.get_value("work.eat_per_person", 2))
	var report := s.end_season()
	_check("季末：种田 6 人粮食 +18，8 人各吃 %d" % eat, s.rice == maxi(0, 6 + 18 - 8 * eat) and report.rice == 18 - 8 * eat)
	_check("训练的人进名单，id 不重复", s.roster.size() == 1 and s.roster[0].type == "spearman")
	_check("第 2 季又送来石料", s.season == 2 and s.delivered == _delivery("after_battle_1", 2))
	s.end_season()
	_check("两季后结束", s.done)
	var r := s.result()
	_check("结果格式合格，带砖槽和石料", Contract.check_work_result(r).is_empty() and r.wall_layouts.has("A1")
		and r.stone_queue.size() == r.materials)


func _test_gate_and_chisel() -> void:
	var s := _state("after_battle_4")
	_check("第二代的料是石头，没有木桩", not "stake3" in s.stone_queue)
	var before := s.materials
	_check("修城门：花 1 次放置和 2 块料", s.can_build_gate("gate_A") and s.build_gate("gate_A")
		and s.wall_slots.gate_A.type == "stone" and s.materials == before - 2 and s.placements_used == 1)
	_check("修好的门不能再修", not s.can_build_gate("gate_A"))
	var first := String(s.stone_queue[0])
	if first == "wedge":
		s.stone_queue[0] = "bar2"
	_check("凿：花 1 次放置把料凿成楔石", s.chisel(0) and s.stone_queue[0] == "wedge" and s.placements_used == 2)
	_check("楔石不用再凿", not s.can_chisel(0))
	_check("门位不拼图", not s.can_work("gate_B"))


func _test_fence_to_stone() -> void:
	var s := _state("after_battle_4", func(save: SaveData) -> void:
		var f := StoneWall.empty("fence")
		for x in 3:
			StoneWall.place(f, "stake3", 0, Vector2i(x, 0))
		save.wall_layouts.A1 = f
		save.wall_slots.A1 = {"type": "fence", "hp": [2, 2]})
	_check("第二代在栅栏上砌：砖槽是空的石墙", s.layout("A1").kind == "stone" and StoneWall.filled(s.layout("A1")) == 0)
	s.stone_queue[0] = "bar2"
	s.place("A1", 0, 0, Vector2i(0, 0))
	_check("石墙没筑成前栅栏还在", s.wall_slots.A1.type == "fence")
	for piece: Dictionary in Rules.get_value("work.puzzle.perfect", []).slice(1):
		s.stone_queue[0] = String(piece.shape)
		s.place("A1", 0, 0, Vector2i(int(piece.at[0]), int(piece.at[1])))
	_check("石墙筑成换上：完美咬合 HP 6", s.wall_slots.A1.type == "stone" and s.wall_slots.A1.hp == [6, 6] and s.wall_slots.A1.max == 6)


func _test_repair() -> void:
	var s := _state("after_battle_7", func(save: SaveData) -> void:
		save.materials = 3
		save.wall_slots.A1 = {"type": "stone", "hp": [3, 5]}
		save.wall_slots.A2 = {"type": "stone", "hp": [0, 2]})
	var have := s.materials
	_check("修墙：每格每 3 点 1 块，不足 3 点向上取整", s.repair_cost("A1") == 2)
	_check("废墟的格子不算修墙", s.repair_cost("A2") == 2)
	_check("修墙不占石匠", s.repair("A1") and s.wall_slots.A1.hp == [6, 6] and s.materials == have - 2 and s.placements_used == 0)
	s.materials = 1
	_check("料不够修不了", not s.repair("A2"))
	var s2 := _state("after_battle_7", func(save: SaveData) -> void:
		save.wall_slots.A1 = {"type": "stone", "hp": [3, 3], "max": 4})
	_check("砌出来的墙修到自己的满 HP", s2.repair_cost("A1") == 2 and s2.repair("A1") and s2.wall_slots.A1.hp == [4, 4])


func _test_food() -> void:
	var s := _state("after_battle_1")
	s.end_season()  # 没人种田：6 − 16 < 0
	_check("粮不够：开宗族义仓补到 0，不饿", s.rice == 0 and s.hungry == 0 and s.granary_used and s.reports[0].granary)
	s.end_season()
	_check("义仓开过以后：缺的变成饥饿", s.rice == 0 and s.hungry == 8 * int(Rules.get_value("work.eat_per_person", 1)))
	var s2 := _state("after_battle_2", func(save: SaveData) -> void:
		save.hungry = 3
		save.granary_used[0] = true)
	s2.set_job("farm", 8)
	_check("预览：粮食够了", s2.preview().hungry == 0 and not s2.preview().granary)
	s2.end_season()
	_check("粮食够了饥饿就消失", s2.hungry == 0 and s2.rice == 6 + 24 - 8 * int(Rules.get_value("work.eat_per_person", 1)))


func _test_goals() -> void:
	var s := _state("after_battle_2", func(save: SaveData) -> void:
		for slot in ["A1", "A2", "A3", "B1"]:
			save.wall_slots[slot] = {"type": "fence", "hp": [2, 2]}
		save.wall_slots.gate_B = {"type": "fence", "hp": [4]}
		for i in 2:
			save.roster.append(save.new_unit("spearman")))
	var p := s.goal_progress()
	_check("第一代目标：4 段栅栏、1 道门、守军 2/3", p.walls == 4 and p.gates == 1 and p.defenders == 2 and not p.met)
	s.set_job("train", 1)
	s.end_season()
	_check("训练第 3 名后达成", s.goal_progress().met and s.result().goal_met)
	var s3 := _state("after_battle_8", func(save: SaveData) -> void:
		for slot in ["A1", "A2", "A3", "B1", "B2", "B3"]:
			save.wall_slots[slot] = {"type": "stone", "hp": [5, 5], "max": 5}
		save.wall_slots.B3 = {"type": "stone", "hp": [5, 4], "max": 5}
		for i in 4:
			save.roster.append(save.new_unit("spearman")))
	_check("第三代目标要修满（按这段墙自己的满 HP）：有一段差 1 点就没达成",
		s3.goal_progress().walls == 5 and not s3.goal_progress().met)
	_check("还剩几季：第二个劳作阶段第 1 季还剩 2 季", s3.seasons_left_in_gen() == 2)


func _test_weather_and_ruins() -> void:
	Game.new_game()
	var save := Game.save
	FlowLogic.start_new_game(save)
	save.wall_layouts.A1 = StoneWall.perfect()
	save.wall_slots.A1 = StoneWall.wall_full(save.wall_layouts.A1, 2)
	var stack := StoneWall.empty("stone")
	for y in 3:
		StoneWall.place(stack, "bar2", 0, Vector2i(0, y))
		StoneWall.place(stack, "bar2", 0, Vector2i(2, y))
	save.wall_layouts.A2 = stack
	save.wall_slots.A2 = StoneWall.wall_full(stack, 2)
	save.wall_slots.gate_A = {"type": "stone", "hp": [8]}
	var v := FlowLogic.apply_event(save, "typhoon")
	_check("台风：咬住的墙不掉", save.wall_slots.A1.hp == [6, 6])
	_check("台风：一条通缝的墙每格 −2", save.wall_slots.A2.hp == [3, 3] and int(v.seams) == 1)
	_check("台风：门照旧掉", save.wall_slots.gate_A.hp == [8 - int(Rules.get_value("flow.events.typhoon.gate_hp_loss", 0))])
	var holes: Array = Rules.get_value("work.puzzle.weathering.A1", [])
	v = FlowLogic.apply_event(save, "gen2_to_gen3")
	_check("风化：A1 掉了 %d 格，满 HP 重算" % holes.size(), StoneWall.filled(save.wall_layouts.A1) == 12 - holes.size()
		and int(save.wall_slots.A1.max) == StoneWall.max_hp(save.wall_layouts.A1) and int(v.weathered) >= 1)
	save.wall_slots.A1.hp = [0, 4]
	FlowLogic.collapse_ruins(save)
	_check("战后塌顶：A1 最上面一行没了", StoneWall.filled(save.wall_layouts.A1) <= 8)
	_check("塌完不够筑成就变回空地", save.wall_slots.A1.type == "none")


func _test_scene() -> void:
	Game.new_game()
	FlowLogic.start_new_game(Game.save)
	var scene: Node = load("res://scenes/work/work.tscn").instantiate()
	scene.setup(FlowLogic.work_input(Game.save, FlowLogic.find_node("after_battle_1")))
	var result := [null]
	scene.finished.connect(func(r: Dictionary) -> void: result[0] = r)
	add_child(scene)
	await get_tree().process_frame
	scene._on_slot("A2")
	scene._on_grid_click(Vector2i(0, 0), MOUSE_BUTTON_LEFT)
	_check("在砖槽里点一下放下木桩", StoneWall.filled(scene.state.layout("A2")) == 3 and scene.wall_map.buttons.has("A2"))
	scene._on_grid_click(Vector2i(0, 0), MOUSE_BUTTON_LEFT)
	_check("放不下的地方点了没反应", StoneWall.filled(scene.state.layout("A2")) == 3)
	var guard := 0
	while result[0] == null and guard < 50:
		guard += 1
		scene.auto_play_for_test()
		await get_tree().process_frame
	_check("劳作画面两季后交回结果", result[0] != null and Contract.check_work_result(result[0]).is_empty()
		and result[0].wall_slots.A2.type == "fence")
	scene.queue_free()
	await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		failures += 1
