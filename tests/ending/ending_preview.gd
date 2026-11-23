extends Node
## 预览结局（校对文字和看放灯用）：用假存档从 E1 播起，播完退出。
## 运行：godot --path . res://tests/ending/ending_preview.tscn -- lost=6 dead=2
## 参数：lost=N（乡亲、守军各失去 N 人）、dead=1,2,3（这几代主角阵亡）、step=K（直接跳到 ending.json 的第 K 步，从 0 数）、
## shot=<PNG 绝对路径>（等 wait 秒后截图并退出，默认 3 秒）。


func _ready() -> void:
	var args := {"lost": "3", "dead": "", "step": "0", "shot": "", "wait": "3"}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	Game.new_game()
	FlowLogic.start_new_game(Game.save)
	var save := Game.save
	FlowLogic.apply_default_name(save, 2)
	FlowLogic.apply_default_name(save, 3)
	for i in int(args.lost):
		FlowLogic.add_lantern(save, "villager", 1 + i % 3, "battle_1")
		FlowLogic.add_lantern(save, "defender", 1 + i % 3, "battle_2")
	var battles := {"1": "battle_2", "2": "battle_5", "3": "battle_9"}
	for g in String(args.dead).split(",", false):
		var hero := {"gen": int(g), "role": "hero"}
		save.hero_alive[int(g) - 1] = false
		save.death_battle[int(g) - 1] = battles.get(g, "")
		save.lanterns_hero.append({"name": FlowLogic.hero_name(save, hero), "gen": int(g), "battle": battles.get(g, "")})
	save.choices = {"C1": "A", "C2": "B", "C3": "A", "C4": "B", "C5": "A"}
	var ending: EndingScreen = load("res://scenes/ending/ending.tscn").instantiate()
	ending.setup({"save": save.duplicate(true)})
	ending.finished.connect(func(_r: Dictionary) -> void: get_tree().quit())
	add_child(ending)
	while ending.step_index < int(args.step) and not ending.done:
		ending.advance()
		await get_tree().process_frame
	if args.shot != "":
		await get_tree().create_timer(float(args.wait)).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args.shot)
		print("Saved screenshot: ", args.shot)
		get_tree().quit()
