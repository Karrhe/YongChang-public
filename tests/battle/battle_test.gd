extends Node
## BAT 测试：潮汐、出战和民兵、寻路、潮水推人、架枪、抓人和退潮、烽火援军、门、伤害、结果格式；九场都自动打完。
## 运行：godot --headless --path . res://tests/battle/battle_test.tscn
## 用假存档，不读写存档文件。

var failures := 0


func _ready() -> void:
	var real_save := Game.save
	_check("规则文件都合格", Rules.errors.is_empty())
	_test_tides()
	_test_deploy()
	_test_movement_and_walls()
	_test_flood()
	_test_brace_and_counter()
	_test_grab_and_falling_tide()
	_test_beacon()
	_test_actions()
	_test_all_battles()
	await _test_scene()
	Game.save = real_save
	print("BATTLE TEST: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _save() -> SaveData:
	Game.new_game()
	FlowLogic.start_new_game(Game.save)
	return Game.save


func _battle_input(battle_id: String, save: SaveData = null) -> Dictionary:
	if save == null:
		save = _save()
	return FlowLogic.battle_input(save, FlowLogic.find_node(battle_id))


func _state(input: Dictionary, picks: Variant = null) -> BattleState:
	var s := BattleState.new()
	s.setup(input)
	s.start(s.default_picks() if picks == null else picks)
	return s


func _first(s: BattleState, pred: Callable) -> Dictionary:
	for u in s.units:
		if s.on_map(u) and pred.call(u):
			return u
	return {}


func _clear_enemies(s: BattleState) -> void:
	for e in s.enemies_on_map():
		e.alive = false


func _test_tides() -> void:
	var s := _state(_battle_input("battle_1"))
	_check("B1 从低潮开始，第 3 回合高潮", s.tide() == "low" and s.tide_at(3) == "high")
	_check("潮汐条显示 4 步", s.tide_forecast() == ["low", "rising", "high", "falling"])
	var b6 := _state(_battle_input("battle_6"))
	_check("B6 风暴潮没有低潮", not "low" in [b6.tide_at(1), b6.tide_at(2), b6.tide_at(3), b6.tide_at(4), b6.tide_at(5)])
	_check("B6 第 2、3 回合都是高潮", b6.tide_at(2) == "high" and b6.tide_at(3) == "high")


func _test_deploy() -> void:
	var b1 := _state(_battle_input("battle_1"))
	var allies := b1.allies_on_map()
	_check("B1 只有主角和教学枪兵", allies.size() == 2 and allies.any(func(u: Dictionary) -> bool: return u.role == "hero")
		and allies.any(func(u: Dictionary) -> bool: return u.roster_id == "t1"))
	_check("B1 六个乡亲分三批出来：第 1 回合 2 个", b1.villagers_outside().size() == 2 and b1.villagers_pending() == 4)
	_check("B1 第 1 回合还没有海寇", b1.enemies_on_map().is_empty())
	var b2 := _state(_battle_input("battle_2"))
	_check("B2 不足 3 人补民兵", b2.allies_on_map().size() == 3
		and b2.allies_on_map().any(func(u: Dictionary) -> bool: return u.role == "militia"))
	var save := _save()
	for i in 6:
		save.roster.append(save.new_unit("spearman"))
	var b4 := BattleState.new()
	b4.setup(_battle_input("battle_4", save))
	var options := b4.deploy_options()
	_check("B4：主角和教学信使必出，长辈和 6 名守军里选 3 个", options.fixed.size() == 2 and options.choices.size() == 7
		and options.slots == 3 and options.choices[0].key == "elder")
	b4.start(b4.default_picks())
	_check("B4 出战 5 人，长辈在里面", b4.allies_on_map().size() == 5
		and b4.allies_on_map().any(func(u: Dictionary) -> bool: return u.role == "elder"))
	var b3 := _state(_battle_input("battle_3"))
	_check("B3 峤叔守在烽火台上、第 1 回合点了烽火", b3.units.any(func(u: Dictionary) -> bool: return u.side == "npc")
		and b3.beacons.values()[0] == 1)
	_check("B3 第 1 回合就有 3 个海寇上岸", b3.enemies_on_map().size() == 3)
	save = _save()
	save.hungry = 2
	var hungry := _state(_battle_input("battle_2", save))
	_check("饥饿时守军移动 −1", _first(hungry, func(u: Dictionary) -> bool: return u.role == "hero").move == 3)
	save = _save()
	save.story_mode = true
	var story := _state(_battle_input("battle_3", save))
	_check("剧情模式：回合 +1、海寇 HP −1", story.turns == 9 and story.enemies_on_map()[0].hp == 3)


func _test_movement_and_walls() -> void:
	var save := _save()
	save.wall_slots.gate_A = {"type": "fence", "hp": [4]}
	save.wall_slots.A1 = {"type": "fence", "hp": [2, 2]}
	var s := _state(_battle_input("battle_1", save))
	var hero := _first(s, func(u: Dictionary) -> bool: return u.role == "hero")
	_check("栅栏挡路", s.blocked(Vector2i(2, 0)) and not s.walkable(Vector2i(2, 1)))
	_check("门开着能过", not s.blocked(Vector2i(2, 2)))
	var reach := s.move_range(hero)
	_check("主角移动 4 格以内", reach.keys().all(func(p: Vector2i) -> bool: return reach[p] <= 4))
	_check("不能走进墙", not reach.has(Vector2i(2, 0)))
	var target := Vector2i(3, 0)
	_check("能移动", s.move_unit(hero, target) and hero.pos == target)
	_check("能撤销移动", s.undo_move(hero) and hero.pos != target and not hero.moved)
	s.structures[Vector2i(2, 2)].open = false
	_check("门关上就挡路", s.blocked(Vector2i(2, 2)))
	s.structures[Vector2i(2, 1)].hp = 0
	_check("HP 0 的栅栏是废墟，能走", s.walkable(Vector2i(2, 1)))


func _test_flood() -> void:
	var s := _state(_battle_input("battle_3"))  # 地图 C，第 1 回合高潮
	_clear_enemies(s)
	var hero := _first(s, func(u: Dictionary) -> bool: return u.role == "hero")
	_check("高潮时滩涂淹着，走不了", not s.walkable(Vector2i(6, 1)))
	# 第 2 回合退潮、第 3 回合低潮：滩涂能走。
	s.end_turn()
	_check("退潮时滩涂能走，花 2 步", s.walkable(Vector2i(6, 1)) and s.step_cost(Vector2i(6, 1)) == 2)
	hero.pos = Vector2i(6, 1)
	var hp: int = hero.hp
	s.turn = 4  # 第 4 回合涨潮：淹了
	s._tide_changes()
	_check("涨潮时站在滩涂上的人被推到干格、受 1 点伤害", not s.is_flooded(hero.pos) and hero.hp == hp - 1)


func _test_brace_and_counter() -> void:
	var s := _state(_battle_input("battle_1"))
	var spear := _first(s, func(u: Dictionary) -> bool: return u.roster_id == "t1")
	var hero := _first(s, func(u: Dictionary) -> bool: return u.role == "hero")
	for v in s.villagers_outside():
		v.alive = false
	var keep := s._make_unit("villager", "villager", "")
	keep.pos = Vector2i(3, 7)
	s.units.append(keep)
	spear.pos = Vector2i(5, 3)
	hero.pos = Vector2i(3, 1)
	var e := s._make_unit("raider", "enemy", "")
	e.pos = Vector2i(7, 3)
	s.units.append(e)
	s.compute_intents()
	s._enemy_phase()
	_check("架枪：走到枪兵旁边的海寇受 2 点伤害并停下", e.hp == 2 and s.dist(e.pos, spear.pos) == 1)
	e.hp = 4
	e.pos = Vector2i(4, 1)
	hero.pos = Vector2i(3, 1)
	keep.alive = false
	var hero_hp: int = hero.hp
	s._enemy_phase()
	_check("没有乡亲可抓时打最近的守军，主角反击", hero.hp == hero_hp - 2 and e.hp == 1)


func _test_grab_and_falling_tide() -> void:
	var s := _state(_battle_input("battle_1"))
	for v in s.villagers_outside():
		v.alive = false
	for a in s.allies_on_map():
		a.pos = Vector2i(0, 7 - a.uid % 2)
	var v := s._make_unit("villager", "villager", "")
	v.pos = Vector2i(6, 2)
	s.units.append(v)
	var e := s._make_unit("raider", "enemy", "")
	e.pos = Vector2i(7, 2)
	s.units.append(e)
	s.compute_intents()
	_check("海寇的意图是抓人", s.intents[0].act == "grab")
	s._enemy_phase()
	_check("抓走乡亲", int(e.carrying) == v.uid and int(v.carried_by) == e.uid)
	s.compute_intents()
	_check("抓着乡亲往海滩走", s.intents[0].act == "carry")
	s._enemy_phase()
	_check("走到海滩等着", s.is_beach(e.pos))
	s.turn = 4  # 第 4 回合是退潮
	s._tide_changes()
	_check("退潮：船开走，乡亲失去了", s.lost == 1 and not s.on_map(e) and s.raiders_defeated == 0)

	var s2 := _state(_battle_input("battle_1"))
	var v2: Dictionary = s2.villagers_outside()[0]
	var e2 := s2._make_unit("raider", "enemy", "")
	e2.pos = Vector2i(7, 7)
	s2.units.append(e2)
	e2.carrying = v2.uid
	v2.carried_by = e2.uid
	s2._hurt(e2, 10)
	_check("打倒抓人的海寇，乡亲救回来", s2.on_map(v2) and v2.pos == Vector2i(7, 7) and s2.raiders_defeated == 1)


func _test_beacon() -> void:
	var s := _state(_battle_input("battle_2"))
	_clear_enemies(s)
	var hero := _first(s, func(u: Dictionary) -> bool: return u.role == "hero")
	var tower := Vector2i(4, 1)
	hero.pos = tower
	_check("站在烽火台上能点烽火", "beacon" in s.actions_for(hero) and s.do_action(hero, "beacon"))
	var before := s.allies_on_map().size()
	s.turn = 3
	s._start_turn()
	_check("3 回合内援军还没到", s.allies_on_map().size() == before)
	s.turn = 4
	s._start_turn()
	_check("点烽火 3 回合后来 2 名援军", s.allies_on_map().size() == before + 2)
	s.over = true
	_check("援军不进名单", not s.result().roster.any(func(r: Dictionary) -> bool: return r.type == "reinforcement"))


func _test_actions() -> void:
	var save := _save()
	save.wall_slots.B2 = {"type": "stone", "hp": [2, 6]}
	var s := _state(_battle_input("battle_2", save))
	_clear_enemies(s)
	var craft := _first(s, func(u: Dictionary) -> bool: return u.type == "craftsman")
	craft.pos = Vector2i(5, 2)
	_check("工匠能修旁边受损的墙", Vector2i(4, 2) in s.targets_for(craft, "repair"))
	s.do_action(craft, "repair", Vector2i(4, 2))
	_check("修墙 +3", s.structures[Vector2i(4, 2)].hp == 5 and craft.acted)
	_check("做完动作就不能再动", not s.can_command(craft))
	var hero := _first(s, func(u: Dictionary) -> bool: return u.role == "hero")
	var e := s._make_unit("raider", "enemy", "")
	e.pos = hero.pos + Vector2i(1, 0)
	s.units.append(e)
	_check("能攻击相邻的海寇", "attack" in s.actions_for(hero))
	s.do_action(hero, "attack", e.pos)
	_check("伤害 = 攻击力", e.hp == 1)
	var boat := s._make_unit("archer_boat", "enemy", "")
	boat.pos = Vector2i(9, 3)
	s.units.append(boat)
	hero.acted = false
	hero.pos = Vector2i(8, 3)
	_check("近战打不到弓箭船", not boat.pos in s.targets_for(hero, "attack"))
	s.over = true
	var result := s.result()
	_check("结果的墙位 HP 写回去了", result.wall_slots.B2.hp == [5, 6])
	_check("结果格式合格", Contract.check_battle_result(result).is_empty())


## 九场都用“全员待命”打完：能结束、结果格式合格、乡亲数对得上。
func _test_all_battles() -> void:
	for i in range(1, 10):
		var id := "battle_%d" % i
		var save := _save()
		save.roster.append(save.new_unit("spearman"))
		save.roster.append(save.new_unit("crossbow"))
		if i >= 4:
			save.names[0] = "石娘"
		var s := _state(_battle_input(id, save))
		var guard := 0
		while not s.over and guard < 30:
			guard += 1
			for a in s.allies_on_map():
				var acts := s.actions_for(a)
				if "attack" in acts:
					s.do_action(a, "attack", s.targets_for(a, "attack")[0])
			s.end_turn()
		var r := s.result()
		_check("%s 能打完（%d 回合）" % [id, s.turn], s.over and s.turn <= s.turns)
		_check("%s 结果格式合格" % id, Contract.check_battle_result(r).is_empty())
		_check("%s 乡亲数对得上" % id, r.villagers_saved + r.villagers_lost + s.villagers_outside().size() + s.villagers_pending() == s.villager_total)


func _test_scene() -> void:
	var scene: Node = load("res://scenes/battle/battle.tscn").instantiate()
	var save := _save()
	scene.setup(FlowLogic.battle_input(save, FlowLogic.find_node("battle_2")))
	var result := [null]
	scene.finished.connect(func(r: Dictionary) -> void: result[0] = r)
	add_child(scene)
	for i in 3:
		await get_tree().process_frame
	scene.auto_play_for_test()
	var guard := 0
	while result[0] == null and guard < 300:
		guard += 1
		scene.auto_play_for_test()
		await get_tree().process_frame
	_check("战斗画面能打完并交回结果", result[0] != null and Contract.check_battle_result(result[0]).is_empty())
	scene.queue_free()
	await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		failures += 1
