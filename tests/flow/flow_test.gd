extends Node
## FLOW-1 测试：节点表、长辈、退休、换代、台风、灯、战后重打，以及流程画面从头走到尾。
## 运行：godot --headless --path . res://tests/flow/flow_test.tscn
## 用临时存档路径，不会碰真实存档。

const TEST_SAVE_PATH := "user://test_flow_save.tres"
const FakeBattle := preload("res://scripts/flow/fake_battle.gd")
const FakeWork := preload("res://scripts/flow/fake_work.gd")

var failures := 0


func _ready() -> void:
	var real_path := Game.save_path
	var real_save := Game.save
	Game.save_path = TEST_SAVE_PATH

	_check("规则文件都合格", Rules.errors.is_empty())
	_test_node_table()
	_test_elders_and_retire()
	_test_battle_apply()
	_test_auto_retry()
	_test_events()
	_test_both_dead()
	_test_rollcall()
	await _test_resume_at_event()
	await _test_runner_end_to_end()

	Game.delete_save()
	Game.save_path = real_path
	Game.save = real_save
	print("FLOW TEST: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	Game.quit(failures)


func _new_save() -> SaveData:
	Game.new_game()
	FlowLogic.start_new_game(Game.save)
	return Game.save


func _test_node_table() -> void:
	var list := FlowLogic.nodes()
	_check("节点表从 P1 开始", list[0].id == "P1")
	_check("节点表以结局结束", list[-1].type == "ending")
	var ids := {}
	var battles := 0
	var works := 0
	var choices := 0
	for n: Dictionary in list:
		ids[n.id] = true
		battles += 1 if n.type == "battle" else 0
		works += 1 if n.type == "work" else 0
		choices += 1 if n.type == "choice" else 0
	_check("节点 ID 不重复", ids.size() == list.size())
	_check("9 场战斗、6 个劳作阶段、5 个选择", battles == 9 and works == 6 and choices == 5)
	for n: Dictionary in list:
		if n.type == "battle":
			_check("%s 是接口里的战斗 ID" % n.id, n.id in Contract.BATTLE_IDS)
		if n.type == "work":
			_check("%s 是接口里的劳作 ID" % n.id, n.id in Contract.WORK_IDS)
	_check("台风在 C3 之后、B6 之前",
		FlowLogic.node_index("C3") < FlowLogic.node_index("typhoon")
		and FlowLogic.node_index("typhoon") < FlowLogic.node_index("battle_6"))
	_check("退休在 G2-3 之后", FlowLogic.node_index("retire_elder") == FlowLogic.node_index("G2-3") + 1)
	var save := _new_save()
	_check("新游戏墙位 12 个、都是空地", save.wall_slots.size() == 12 and save.wall_slots.A1.type == "none")
	_check("A/B 版本：主角活着用 A", FlowLogic.story_key(save, FlowLogic.find_node("G1-2")) == "G1-2_A")
	save.hero_alive[0] = false
	_check("A/B 版本：主角阵亡用 B", FlowLogic.story_key(save, FlowLogic.find_node("G1-2")) == "G1-2_B")
	_check("没有版本的场景不加后缀", FlowLogic.story_key(save, FlowLogic.find_node("G2-1")) == "G2-1")


func _test_elders_and_retire() -> void:
	var save := _new_save()
	for n: Dictionary in FlowLogic.nodes():
		if n.type != "battle":
			continue
		var input := FlowLogic.battle_input(save, n)
		_check("%s 的输入合格" % n.id, Contract.check_battle_input(input).is_empty())
		var has_elder: bool = input.elder != null
		_check("%s 长辈只在 battle_4 / battle_9" % n.id, has_elder == (n.id in ["battle_4", "battle_9"]))
	var b4 := FlowLogic.find_node("battle_4")
	save.hero_alive[0] = false
	_check("王成阵亡时阿棠当长辈", FlowLogic.battle_input(save, b4).elder == {"gen": 1, "role": "companion"})
	save.companion_alive[0] = false
	_check("第一代都不在时没有长辈", FlowLogic.battle_input(save, b4).elder == null)
	save.hero_alive[0] = true
	FlowLogic.apply_event(save, "retire_elder")
	_check("退休后 battle_4 没有长辈", FlowLogic.battle_input(save, b4).elder == null)
	var b9 := FlowLogic.find_node("battle_9")
	_check("battle_9 长辈是第二代", FlowLogic.battle_input(save, b9).elder == {"gen": 2, "role": "hero"})
	_check("battle_1 有遗言台词键", FlowLogic.battle_input(save, FlowLogic.find_node("battle_1")).story_keys.hero_death.size() == 1)
	_check("battle_8 有开场和结束台词键", FlowLogic.battle_input(save, FlowLogic.find_node("battle_8")).story_keys.start.size() == 1)
	_check("没选 C5-A 时 battle_9 没有临时守军", FlowLogic.battle_input(save, b9).bonus_defenders == 0)
	FlowLogic.apply_choice(save, "C5", "A")
	_check("C5-A 时 battle_9 临时守军 +2", FlowLogic.battle_input(save, b9).bonus_defenders == 2)


func _test_battle_apply() -> void:
	var save := _new_save()
	save.roster.assign([save.new_unit("spearman"), save.new_unit("craftsman")])
	var node := FlowLogic.find_node("battle_2")
	var input := FlowLogic.battle_input(save, node)
	var result := FakeBattle.make_result(input, "costly", true)
	FlowLogic.apply_battle(save, input, result)
	_check("记下战斗结果", save.battle_results.battle_2 == "costly")
	_check("主角阵亡写进存档", not save.hero_alive[0] and save.death_battle[0] == "battle_2")
	_check("主角的灯写王成", save.lanterns_hero.size() == 1 and save.lanterns_hero[0].name == "王成")
	_check("乡亲灯 2 盏、守军灯 1 盏", save.lanterns_villager.size() == 2 and save.lanterns_defender.size() == 1)
	_check("乡亲的灯从名字表按顺序取名", save.lanterns_villager[0].name == "王福生")
	_check("灯的名字键按顺序", save.lanterns_villager[1].key == "LANTERN_VILLAGER_G1_02")
	var many := SaveData.new()
	for i in 12:
		FlowLogic.add_lantern(many, "villager", 1, "battle_1")
	var extra := String(many.lanterns_villager[10].name)
	_check("名字表用完时按姓加排行起名，不和表里重名",
		extra != "无名" and extra.contains("老")
		and not many.lanterns_villager.slice(0, 10).any(func(e: Dictionary) -> bool: return e.name == extra))
	_check("人口扣失去的乡亲和守军，一场最多扣 max_people_loss_per_battle", save.people == 8 - mini(3, int(Rules.get_value("core.max_people_loss_per_battle", 3))))
	_check("名单去掉阵亡的守军", save.roster.size() == 1)
	var next_input := FlowLogic.battle_input(save, FlowLogic.find_node("battle_3"))
	_check("主角阵亡后同伴出战", next_input.hero == {"gen": 1, "role": "companion"})
	_check("battle_2 之后 G1-4 用 B 版", FlowLogic.story_key(save, FlowLogic.find_node("G1-4")) == "G1-4_B")
	save.people = 4
	FlowLogic.apply_battle(save, next_input, FakeBattle.make_result(next_input, "costly", false))
	_check("人口不低于 4", save.people == 4)


func _test_auto_retry() -> void:
	var save := _new_save()
	for id in ["battle_7", "battle_8", "battle_9", "battle_1"]:
		var input := FlowLogic.battle_input(save, FlowLogic.find_node(id))
		var died := FakeBattle.make_result(input, "costly", true)
		var expect: bool = id in ["battle_7", "battle_8"]
		_check("%s 主角阵亡%s直接重打" % [id, "" if expect else "不"], FlowLogic.must_retry(died) == expect)
		_check("%s 主角没死不强制重打" % id, not FlowLogic.must_retry(FakeBattle.make_result(input, "held", false)))


func _test_events() -> void:
	var save := _new_save()
	save.materials = 5
	FlowLogic.apply_event(save, "gen1_to_gen2")
	_check("换代：材料折半向下取整再 +6", save.materials == 2 + 6)
	save.wall_slots.A1 = {"type": "stone", "hp": [6, 6]}
	save.wall_slots.A2 = {"type": "fence", "hp": [2, 1]}
	save.wall_slots.gate_A = {"type": "stone", "hp": [8]}
	FlowLogic.apply_event(save, "typhoon")
	_check("台风：没有砖槽的旧石墙照旧 −3", save.wall_slots.A1.hp == [3, 3])
	_check("台风：栅栏变废墟", save.wall_slots.A2.hp == [0, 0])
	_check("台风：门也 −3", save.wall_slots.gate_A.hp == [5])
	_check("台风：空墙位不变", save.wall_slots.A3.hp == [0, 0])
	FlowLogic.apply_event(save, "repair_after_battle_6")
	_check("B6 后修满（含废墟）", save.wall_slots.A1.hp == [6, 6] and save.wall_slots.A2.hp == [2, 2]
		and save.wall_slots.gate_A.hp == [8])
	save.roster.assign([save.new_unit("spearman")])
	var people := save.people
	FlowLogic.apply_event(save, "gen2_to_gen3")
	_check("第二代到第三代：门老化 −3、没有砖槽的墙不风化、人口 +2、守军清零",
		save.wall_slots.gate_A.hp == [5] and save.wall_slots.A1.hp == [6, 6] and save.people == people + 2 and save.roster.is_empty())
	FlowLogic.apply_default_name(save, 2)
	_check("起名界面之前用默认名字", save.names[0] == "阿囡")


func _test_both_dead() -> void:
	var save := _new_save()
	var b2 := FlowLogic.find_node("battle_2")
	var input := FlowLogic.battle_input(save, b2)
	FlowLogic.apply_battle(save, input, FakeBattle.make_result(input, "held", true))
	input = FlowLogic.battle_input(save, FlowLogic.find_node("battle_3"))
	FlowLogic.apply_battle(save, input, FakeBattle.make_result(input, "held", true))
	_check("同伴也阵亡：灯写阿棠", save.lanterns_hero.size() == 2 and save.lanterns_hero[1].name == "阿棠")
	_check("同伴阵亡不改主角的死亡场次", save.death_battle[0] == "battle_2")
	_check("一代两人都不在：之后没有主角单位", FlowLogic.current_hero(save, 1) == null)
	_check("一代两人都不在：battle_4 没有长辈", FlowLogic.battle_input(save, FlowLogic.find_node("battle_4")).elder == null)
	_check("一代两人都不在：二代主角照常出战",
		FlowLogic.battle_input(save, FlowLogic.find_node("battle_4")).hero == {"gen": 2, "role": "hero"})


## 每代最后一仗之后的点名（REDESIGN-002 方案一）：只点这一代失去的人，四个名字一句。
func _test_rollcall() -> void:
	var save := _new_save()
	_check("点名在 B3、B6、B9 之后", FlowLogic.next_id("battle_3") == "rollcall_1" and FlowLogic.next_id("battle_6") == "rollcall_2"
		and FlowLogic.next_id("battle_9") == "rollcall_3")
	var none := FlowLogic.event_notice("rollcall_1", FlowLogic.apply_event(save, "rollcall_1"))
	_check("没人失去：点到的人都应了", none.append.size() == 2 and none.append[1].text == Game.text("EVT_ROLLCALL_NONE"))
	for i in 5:
		FlowLogic.add_lantern(save, "villager", 1, "battle_2")
	FlowLogic.add_lantern(save, "villager", 2, "battle_4")
	save.lanterns_hero.append({"name": "王成", "gen": 1, "battle": "battle_1"})
	var v := FlowLogic.apply_event(save, "rollcall_1")
	_check("只点第一代的 6 个人，主角在前", v.count == 6 and v.names[0] == "王成")
	var n := FlowLogic.event_notice("rollcall_1", v)
	_check("开头一句 + 两批名字各带一句没人应 + 结尾一句", n.append.size() == 6 and n.append[1].text.contains("王成"))


## 在规则事件节点退出再读档：事件只生效一次（存档在事件生效之前写，生效后的状态在下一个节点才写）。
func _test_resume_at_event() -> void:
	var save := _new_save()
	var stack := StoneWall.empty("stone")
	for y in 3:
		StoneWall.place(stack, "bar2", 0, Vector2i(0, y))
		StoneWall.place(stack, "bar2", 0, Vector2i(2, y))
	save.wall_layouts.A1 = stack  # 一条通缝：台风每格 −2
	save.wall_slots.A1 = StoneWall.wall_full(stack, 2)
	save.progress = "typhoon"
	Game.save_game()
	var copy := FlowLogic.find_node("typhoon")
	_check("测试前提：台风是规则事件", copy.type == "event")
	# 模拟“在台风节点退出”：读回的就是事件之前的存档。
	_check("读档", Game.load_game() and Game.save.wall_slots.A1.hp == [5, 5])
	var flow: Node = load("res://scenes/flow/flow.tscn").instantiate()
	add_child(flow)
	for i in 6:
		await get_tree().process_frame
	_check("从台风节点继续：先显示台风的说明", Game.save.progress == "typhoon"
		and flow.current != null and flow.current.has_signal("finished"))
	flow.current.finished.emit({})
	for i in 6:
		await get_tree().process_frame
	_check("看完说明后停在 G2-5", Game.save.progress == "G2-5")
	Game.load_game()
	_check("读档后台风只扣了一次", Game.save.wall_slots.A1.hp == [3, 3])

	# 旧存档（砌石拼图之前）：墙没有砖槽，读档时补上（QA-2 的 QA-006、QA-007）。
	var old := _new_save()
	old.wall_slots.A1 = {"type": "stone", "hp": [6, 4]}
	old.wall_slots.B1 = {"type": "fence", "hp": [2, 2]}
	old.wall_slots.gate_A = {"type": "stone", "hp": [8]}
	old.progress = "typhoon"
	Game.save = old
	Game.save_game()
	_check("旧存档读档：旧石墙补成完美咬合的砖槽，HP 不变", Game.load_game()
		and StoneWall.red_seams(Game.save.wall_layouts.A1).is_empty() and Game.save.wall_slots.A1.hp == [6, 4]
		and int(Game.save.wall_slots.A1.max) == 6)
	_check("旧存档读档：旧栅栏补成木桩，门不拼", StoneWall.is_built(Game.save.wall_layouts.B1)
		and Game.save.wall_layouts.B1.kind == "fence" and not Game.save.wall_layouts.has("gate_A"))
	var tv := FlowLogic.apply_event(Game.save, "typhoon")
	_check("补过砖槽的旧墙按红缝过台风", Game.save.wall_slots.A1.hp == [6, 4] and Game.save.wall_slots.B1.hp == [0, 0]
		and int(tv.seams) == 3)
	flow.queue_free()
	await get_tree().process_frame


## 用真的流程画面，从 P1 一直点到结局（假战斗、假劳作、剧情占位）。
func _test_runner_end_to_end() -> void:
	Game.delete_save()
	_new_save()
	var flow: Node = load("res://scenes/flow/flow.tscn").instantiate()
	var real_after: String = Rules.data.flow.scenes.after_ending
	Rules.data.flow.scenes.after_ending = ""  # 测试里不切场景
	add_child(flow)
	var battles := 0
	var retried := false
	var forced_seen := false
	var forced_had_accept := true
	var b9_bonus := -1
	var steps := 0
	while Game.save.progress != "done" and steps < 300:
		steps += 1
		await get_tree().process_frame
		await get_tree().process_frame
		if Game.save.progress == "done":
			break
		var child: Node = flow.current
		if child != null and child.has_signal("finished") and child.is_inside_tree():
			var node_type: String = flow.node.type
			if node_type == "battle":
				battles += 1
				_check_once("流程每个节点开始时存了档", Game.has_save())
				var id: String = child.input.battle_id
				if id == "battle_9":
					b9_bonus = child.input.bonus_defenders
				if id == "battle_7" and not forced_seen:
					forced_seen = true
					child.finished.emit(FakeBattle.make_result(child.input, "costly", true))
					await get_tree().process_frame
					forced_had_accept = _find_button(flow, Game.text("FLOW_ACCEPT")) != null
					_find_button(flow, Game.text("FLOW_RETRY")).pressed.emit()
					continue
				child.finished.emit(FakeBattle.make_result(child.input, "held", false))
			elif node_type == "work":
				child.finished.emit(FakeWork.make_result(child.input, true))
			elif node_type == "choice":
				child.finished.emit({"pick": "A" if flow.node.id == "C5" else "B"})
			else:
				child.finished.emit({})
		else:
			# 战后确认画面：第一次点重打，之后都接受。
			var label := "FLOW_ACCEPT" if retried else "FLOW_RETRY"
			retried = true
			var btn := _find_button(flow, Game.text(label))
			if btn != null:
				btn.pressed.emit()
	Rules.data.flow.scenes.after_ending = real_after
	_check("流程走到结局", Game.save.progress == "done")
	_check("流程里接受了 9 场战斗（含两次重打）", Game.save.battle_results.size() == 9 and battles == 11)
	_check("流程里 battle_7 主角阵亡时没有“接受”按钮", forced_seen and not forced_had_accept)
	_check("流程里第三代主角重打后仍活着", Game.save.hero_alive[2])
	_check("流程里选 C5-A 后 battle_9 临时守军 +2", b9_bonus == 2)
	_check("流程记下 5 个选择", Game.save.choices.size() == 5)
	_check("流程里起了默认名字", Game.save.names[1] == "阿潮")
	_check("流程里长辈退休了", Game.save.elder_retired)
	flow.queue_free()


func _find_button(root: Node, text: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if n.text == text:
			return n
	return null


var _once := {}


func _check_once(label: String, ok: bool) -> void:
	if not _once.has(label):
		_once[label] = true
		_check(label, ok)


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		failures += 1
