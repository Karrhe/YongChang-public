extends Node
## 整局通关测试：用真的剧情、战斗、劳作、选择、起名、结局，从 P1 一直点到制作人员之前。
## 每个画面用最简单的玩法：台词点过去、战斗能打就打然后结束回合、劳作全员种田、选择选 B、名字用默认、战后接受。
## 运行：godot --headless --path . res://tests/flow/playthrough_test.tscn
## 用临时存档路径，不会碰真实存档。

const TEST_SAVE_PATH := "user://test_playthrough_save.tres"

var failures := 0


func _ready() -> void:
	var real_path := Game.save_path
	var real_save := Game.save
	Game.save_path = TEST_SAVE_PATH
	Game.delete_save()
	Game.new_game()
	FlowLogic.start_new_game(Game.save)
	var real_after: String = Rules.data.flow.scenes.after_ending
	Rules.data.flow.scenes.after_ending = ""
	var flow: Node = load("res://scenes/flow/flow.tscn").instantiate()
	add_child(flow)
	var seen := {}
	var battles := 0
	## 每场战斗的余量（调难度用，ISSUE-001 BAT-08）：救下 / 目标、失去的乡亲。
	var margins: PackedStringArray = PackedStringArray()
	var steps := 0
	var started := Time.get_ticks_msec()
	var trace := "--trace" in OS.get_cmdline_user_args()
	var last_node := ""
	while Game.save.progress != "done" and steps < 20000:
		steps += 1
		await get_tree().process_frame
		if trace and flow.node.get("id", "") != last_node:
			last_node = flow.node.get("id", "")
			print("  [trace] step %d %.1fs %s" % [steps, (Time.get_ticks_msec() - started) / 1000.0, last_node])
		var child: Node = flow.current
		if child == null or not child.is_inside_tree():
			var accept := _find_button(flow, Game.text("FLOW_ACCEPT"))
			var retry := _find_button(flow, Game.text("FLOW_RETRY"))
			if accept != null:
				accept.pressed.emit()
			elif retry != null:
				retry.pressed.emit()  # 第三代 B7、B8 主角阵亡：只能重打
			continue
		var type: String = flow.node.type
		seen[type] = int(seen.get(type, 0)) + 1
		match type:
			"battle":
				if child.has_signal("finished") and not child.has_meta("margin_hooked"):
					child.set_meta("margin_hooked", true)
					child.finished.connect(func(r: Dictionary) -> void:
						margins.append("%s 救 %d/%d 失 %d" % [String(r.battle_id).trim_prefix("battle_"),
							int(r.villagers_saved), int(child.state.goal), int(r.villagers_lost)]))
				if child.has_method("auto_play_for_test"):
					child.auto_play_for_test()
			"work":
				child.auto_play_for_test()
			"naming":
				child.submit()
			"choice":
				if child.box.playing:
					child.box.advance()
				elif not child.option_buttons.is_empty() and child.option_buttons.has("B"):
					child.option_buttons.B.pressed.emit()
				elif child.slot_ok != null:
					child.slot_ok.pressed.emit()
			"ending":
				child.advance()
			_:
				if "box" in child and child.box != null:
					child.box.advance()
		if flow.node.type == "battle" and flow.current == child and child.state != null and child.state.over:
			battles += 1

	Rules.data.flow.scenes.after_ending = real_after
	_check("整局走到结局（%d 步，%.1f 秒）" % [steps, (Time.get_ticks_msec() - started) / 1000.0], Game.save.progress == "done")
	_check("九场战斗都接受了", Game.save.battle_results.size() == 9)
	_check("五个选择都做了", Game.save.choices.size() == 5)
	_check("两个名字都起了", Game.save.names[0] != "" and Game.save.names[1] != "")
	_check("每种画面都出现过", seen.has("story") and seen.has("battle") and seen.has("work")
		and seen.has("choice") and seen.has("naming") and seen.has("ending"))
	print("  战斗结果：", Game.save.battle_results)
	print("  战斗余量：", " · ".join(margins))
	print("  人口 %d · 粮 %d · 材料 %d · 灯 %d（乡亲 %d、守军 %d、主角和同伴 %d）" % [Game.save.people, Game.save.rice,
		Game.save.materials, Game.save.lantern_count(), Game.save.lanterns_villager.size(),
		Game.save.lanterns_defender.size(), Game.save.lanterns_hero.size()])
	print("  主角存活：", Game.save.hero_alive, " 同伴存活：", Game.save.companion_alive)
	var built := Game.save.wall_slots.keys().filter(func(k: String) -> bool: return Game.save.wall_slots[k].type != "none")
	print("  目标卡：", Game.save.goal_met, " 筑成的墙和门：", built.size())
	flow.queue_free()
	Game.delete_save()
	Game.save_path = real_path
	Game.save = real_save
	print("PLAYTHROUGH TEST: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	Game.quit(failures)


func _find_button(root: Node, text: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if n.text == text and n.is_visible_in_tree():
			return n
	return null


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		failures += 1
