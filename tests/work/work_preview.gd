extends Node
## 截图用：打开一个劳作画面，先放几块石头（看金边、红缝、影子）。
## 运行：godot --path . res://tests/screenshot.tscn -- res://tests/work/work_preview.tscn <输出 PNG>
## 第几代：命令行最后一个参数写 gen1 / gen2（默认 gen2）。


func _ready() -> void:
	var gen2 := not "gen1" in OS.get_cmdline_user_args()
	Game.save_path = "user://preview_%d.tres" % OS.get_process_id()
	Game.new_game()
	FlowLogic.start_new_game(Game.save)
	Game.save.hammer_text = ""
	var scene: Node = load("res://scenes/work/work.tscn").instantiate()
	scene.setup(FlowLogic.work_input(Game.save, FlowLogic.find_node("after_battle_4" if gen2 else "after_battle_1")))
	add_child(scene)
	await get_tree().process_frame
	var s: WorkState = scene.state
	s.set_job("farm", 5)
	if gen2:
		s.stone_queue[0] = "bar2"
		s.place("A1", 0, 0, Vector2i(0, 0))
		s.stone_queue[0] = "bar2"
		s.place("A1", 0, 0, Vector2i(2, 0))
		s.stone_queue[0] = "bar2"
		s.place("A1", 0, 0, Vector2i(1, 1))
	else:
		s.place("A1", 0, 0, Vector2i(0, 0))
		s.place("A1", 0, 0, Vector2i(1, 0))
	scene.selected_slot = "A1"
	scene._refresh()
	scene.grid.hover = Vector2i(0, 1)
	scene.grid.queue_redraw()
