extends Node
## 预览一个剧情场景（校对剧情表用）：用默认名字的新存档播放，播完退出。
## 运行：godot --path . res://tests/story/story_preview.tscn -- scene=G2-1 gen=2
## 其他参数：dead=1,2（这几代主角阵亡）、skip=N（先跳过 N 句）、backlog=1（打开回看）、
## shot=<PNG 绝对路径>（等 wait 秒后截图并退出，默认 1.5 秒）。


func _ready() -> void:
	var args := {"scene": "P1", "gen": "1", "dead": "", "skip": "0", "backlog": "0", "shot": "", "wait": "1.5"}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	Game.new_game()
	FlowLogic.start_new_game(Game.save)
	for g in String(args.dead).split(",", false):
		Game.save.hero_alive[int(g) - 1] = false
	StoryTable.reload_main()
	var scene: Node = load("res://scenes/story/story.tscn").instantiate()
	scene.setup({"scene_id": String(args.scene).get_slice("_", 0), "key": args.scene, "gen": int(args.gen)})
	scene.finished.connect(func(_r: Dictionary) -> void: get_tree().quit())
	add_child(scene)
	for i in int(args.skip) * 2:
		scene.box.advance()
	if args.backlog == "1":
		scene.box.open_backlog()
	if args.shot != "":
		await get_tree().create_timer(float(args.wait)).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args.shot)
		print("Saved screenshot: ", args.shot)
		get_tree().quit()
