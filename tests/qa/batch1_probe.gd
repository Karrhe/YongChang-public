extends Node

const FLOW := preload("res://scenes/flow/flow.tscn")
const ENDING := preload("res://scenes/ending/ending.tscn")
const RESULT_FIXTURE := preload("res://scripts/flow/fake_battle.gd")

var failures := 0


func _ready() -> void:
	Game.save_path = "user://qa_batch1_%s.tres" % OS.get_process_id()
	await _retry("battle_1", false, true)
	await _retry("battle_7", true, false)
	await _retry("battle_8", true, false)
	await _story()
	await _lanterns()
	Game.delete_save()
	print("QA BATCH 1 PROBE: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _check(label: String, ok: bool) -> void:
	print("%s %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _open_flow(at: String) -> Node:
	Game.save.progress = at
	var flow := FLOW.instantiate()
	add_child(flow)
	await get_tree().process_frame
	return flow


func _button(flow: Node, key: String) -> Button:
	for button: Button in flow.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and button.text == Game.text(key):
			return button
	return null


func _retry(id: String, forced: bool, use_real_result: bool) -> void:
	Game.new_game()
	FlowLogic.start_new_game(Game.save)
	var flow := await _open_flow(id)
	var original: Dictionary = flow.battle_in.duplicate(true)
	var before := FileAccess.get_file_as_string(Game.save_path)
	var real_results := []
	var attempts := 2 if use_real_result else 1
	for attempt in attempts:
		var battle: Node = flow.current
		if use_real_result:
			battle.finished.connect(func(result: Dictionary) -> void: real_results.append(result))
			for step in 160:
				battle.auto_play_for_test()
				if flow.current == null:
					break
				await get_tree().process_frame
		else:
			# Force the casualty at the scene boundary to cover either battle deterministically.
			battle.finished.emit(RESULT_FIXTURE.make_result(original, "costly", true))
		await get_tree().process_frame
		var retry := _button(flow, "FLOW_RETRY")
		_check("%s attempt %d Accept visibility / Retry available" % [id, attempt + 1],
			(_button(flow, "FLOW_ACCEPT") == null) == forced and retry != null)
		_check("%s attempt %d pending result leaves save untouched" % [id, attempt + 1],
			Game.save.battle_results.is_empty() and Game.save.lantern_count() == 0
			and Game.save.hero_alive == [true, true, true]
			and FileAccess.get_file_as_string(Game.save_path) == before)
		if retry == null:
			break
		retry.pressed.emit()
		await get_tree().process_frame
		_check("%s reopened a fresh battle with identical input on turn 1" % id,
			flow.current != null and flow.current != battle
			and flow.current.input == original and flow.current.state.turn == 1)
	if use_real_result:
		_check("%s identical autoplay reproduces same outcome and losses" % id,
			real_results.size() == 2 and real_results[0] == real_results[1])
		if not real_results.is_empty():
			var result: Dictionary = real_results[0]
			print("  %s real result %s, villagers saved/lost %d/%d, defenders lost %d" %
				[id, result.outcome, result.villagers_saved, result.villagers_lost, result.defenders_lost])
	flow.queue_free()
	await get_tree().process_frame
	_check("%s reload remains at battle start" % id, Game.load_game()
		and Game.save.progress == id and Game.save.battle_results.is_empty()
		and Game.save.lantern_count() == 0)


func _story() -> void:
	var table := StoryTable.main()
	var checked := 0
	var conditions := {
		"GEN1_ALIVE": [true, false, false],
		"GEN1_DEAD": [false, true, false],
		"GEN2_ELDER_A": [true, false, false],
		"GEN2_ELDER_B": [false, true, false],
		"GEN2_NONE": [false, false, true],
	}
	var ok := true
	for state in 3:
		Game.new_game()
		Game.save.hero_alive.assign([state == 0, state == 0, true])
		Game.save.companion_alive.assign([state < 2, state < 2, true])
		for scene: String in table.scenes:
			var ids := table.lines(scene, Game.save).map(func(line: Dictionary) -> String: return line.line_id)
			for row: Dictionary in table.scenes[scene]:
				if row.condition.is_empty():
					continue
				checked += 1
				if not conditions.has(row.condition) or ids.has(row.line_id) != conditions[row.condition][state]:
					print("  Unexpected conditional line %s/%s in state %d" % [scene, row.line_id, state])
					ok = false
	_check("production conditional rows across three survival states (%d checks)" % checked, ok and checked == 114)

	for variant in ["A_met", "A_unmet", "B_met", "B_unmet"]:
		for state in 3:
			Game.new_game()
			Game.save.names[0] = "测试石娘"
			Game.save.hero_alive[0] = state == 0
			Game.save.companion_alive[0] = state < 2
			Game.save.hero_alive[1] = variant.begins_with("A")
			Game.save.goal_met[1] = variant.ends_with("_met")
			var flow := await _open_flow("G2-6")
			var expected: String = "G2-6_" + variant
			var lines: Array[Dictionary] = flow.current.box.lines
			var ids := lines.map(func(line: Dictionary) -> String: return line.line_id)
			_check("%s state %d selected, dialogue loaded (%s)" % [expected, state, ids],
				flow.current.input.key == expected and not lines.is_empty()
				and lines.all(func(line: Dictionary) -> bool:
						return line.scene_id == expected and not line.text.begins_with("[待写:")))
			if variant.begins_with("B") and state == 0:
				print("  custom name %s, actual memorial line %s" % [Game.save.names[0], lines[-1].text])
			flow.queue_free()
			await get_tree().process_frame

	Game.new_game()
	FlowLogic.start_new_game(Game.save)
	for id in ["battle_4", "battle_5"]:
		var input := FlowLogic.battle_input(Game.save, FlowLogic.find_node(id))
		FlowLogic.apply_battle(Game.save, input, RESULT_FIXTURE.make_result(input, "costly", true))
	_check("accepted B4 hero death and B5 replacement death leave both Gen 2 characters dead",
		not Game.save.hero_alive[1] and not Game.save.companion_alive[1])
	var flow := await _open_flow("G2-6")
	print("  both Gen 2 dead, G2-6 first dialogue speaker: %s" % flow.current.box.lines[1].speaker)
	flow.queue_free()
	await get_tree().process_frame

	Game.new_game()
	flow = await _open_flow("G2-4")
	print("  B5 map %s, G2-4 first line: %s" % [
		Rules.get_value("battle.battles.battle_5.map", "?"), flow.current.box.lines[0].text])
	flow.queue_free()
	await get_tree().process_frame


func _lanterns() -> void:
	Game.new_game()
	Game.save.names[1] = "测试三代"
	var expected := ["王福生", "王桂嫂", "王秀姑", "王大根", "王坚官", "王岩生", "测试三代"]
	for gen in range(1, 4):
		var battle_id := "battle_%d" % (gen * 3)
		FlowLogic.add_lantern(Game.save, "villager", gen, battle_id)
		FlowLogic.add_lantern(Game.save, "defender", gen, battle_id)
	Game.save.lanterns_hero.append({"name": "{名3}", "gen": 3, "battle": "battle_9"})
	for i in 10:
		FlowLogic.add_lantern(Game.save, "villager", 1, "battle_1")
	var fallback: String = Game.save.lanterns_villager[-1].name
	print("  first overflow villager name: %s" % fallback)
	_check("table overflow produces a distinct name", fallback != "无名" and not fallback.is_empty()
		and not Game.save.lanterns_villager.slice(0, -1).any(
			func(entry: Dictionary) -> bool: return entry.name == fallback))
	expected.append(fallback)
	var ending := ENDING.instantiate()
	ending.setup({"save": Game.save})
	add_child(ending)
	var labels := {}
	var steps: Array = Rules.get_value("ending.steps", [])
	for click in 400:
		if ending.done:
			break
		if steps[ending.step_index].type == "lanterns":
			for label: Label in ending.layer.find_children("*", "Label", true, false):
				labels[label.text] = true
		ending.advance()
		await get_tree().process_frame
	print("  E3 floating labels: %s" % [labels.keys()])
	_check("E3 displays names from all three generations, hero substitution and overflow",
		expected.all(func(name: String) -> bool: return labels.has(name)) and not labels.has("无名"))
	_check("ending completed", ending.done)
	ending.queue_free()
	await get_tree().process_frame
