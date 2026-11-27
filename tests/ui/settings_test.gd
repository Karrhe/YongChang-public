extends Node
## 设置和暂停测试：settings.cfg 读写、音量和剧情模式、主菜单的设置画面、Esc 暂停。
## 运行：godot --headless --path . res://tests/ui/settings_test.tscn
## 用临时存档和临时设置路径，不会碰真实存档和玩家设置。

const TEST_SAVE_PATH := "user://test_settings_save.tres"
const TEST_SETTINGS_PATH := "user://test_settings.cfg"
const MENU_SCENE := preload("res://scenes/menu/menu.tscn")

var failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时测试也要接着跑
	var real_save_path := Game.save_path
	var real_settings_path := Game.settings_path
	var real_save := Game.save
	Game.save_path = TEST_SAVE_PATH
	Game.settings_path = TEST_SETTINGS_PATH
	Game.delete_save()
	_remove(TEST_SETTINGS_PATH)

	_check_settings_file()
	_check_story_mode()
	await _check_menu()
	await _check_pause()

	Game.delete_save()
	_remove(TEST_SETTINGS_PATH)
	Game.save_path = real_save_path
	Game.settings_path = real_settings_path
	Game.save = real_save
	Game.load_settings()
	Game.apply_settings()
	_check("真实存档和设置路径没变", Game.save_path == Game.DEFAULT_SAVE_PATH
		and Game.settings_path == Game.DEFAULT_SETTINGS_PATH)
	print("SETTINGS TEST: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	Game.quit(failures)


func _check_settings_file() -> void:
	Game.load_settings()
	_check("没有设置文件时用 core.json 的默认值",
		Game.settings.story_mode == bool(Rules.get_value("core.settings.story_mode", true))
		and is_equal_approx(Game.settings.volume, float(Rules.get_value("core.settings.volume", -1.0)))
		and Game.settings.fullscreen == bool(Rules.get_value("core.settings.fullscreen", true)))
	Game.set_setting("volume", 0.5)
	var bus := AudioServer.get_bus_index("Master")
	_check("音量接到 Master 总线", is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.5))
		and not AudioServer.is_bus_mute(bus))
	Game.set_setting("volume", 0.0)
	_check("音量 0 时静音", AudioServer.is_bus_mute(bus))
	Game.set_setting("volume", 0.7)
	Game.set_setting("fullscreen", true)  # 无界面时不切窗口，只存
	_check("设置写进临时 settings.cfg", FileAccess.file_exists(TEST_SETTINGS_PATH))
	Game.settings = {}
	Game.load_settings()
	_check("设置能读回", is_equal_approx(Game.settings.volume, 0.7) and Game.settings.fullscreen == true)
	Game.set_setting("fullscreen", false)


func _check_story_mode() -> void:
	Game.set_story_mode(true)
	_check("没有存档时剧情模式只改默认值", Game.settings.story_mode and not Game.has_save())
	Game.new_game(true)
	_check("新游戏按设置开剧情模式", Game.save.story_mode)
	Game.new_game()
	_check("测试用的 new_game() 不看设置", not Game.save.story_mode)

	# 节点开始时的存档：之后内存里的进度变了（比如事件已生效），不能被设置画面写进存档。
	Game.new_game(true)
	FlowLogic.start_new_game(Game.save)
	Game.save.progress = "G1-1"
	Game.save_game()
	Game.save.rice = 99
	Game.set_story_mode(false)
	var on_disk: SaveData = ResourceLoader.load(TEST_SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check("剧情模式写进当前存档", on_disk != null and not on_disk.story_mode and not Game.save.story_mode)
	_check("写剧情模式不改存档里的其他进度", on_disk != null and on_disk.rice == 6 and on_disk.progress == "G1-1")
	_check("新游戏默认值也跟着改", not Game.settings.story_mode)
	Game.set_story_mode(true)
	_check("current_story_mode 读存档", Game.current_story_mode())
	Game.set_story_mode(false)
	var input := FlowLogic.battle_input(Game.save, FlowLogic.find_node("battle_1"))
	_check("战斗输入带剧情模式", input.has("story_mode") and input.story_mode == false)


func _check_menu() -> void:
	var menu: Control = MENU_SCENE.instantiate()
	add_child(menu)
	await get_tree().process_frame
	var button := _find_button(menu, Game.text("UI_SETTINGS"))
	_check("主菜单有设置按钮", button != null)
	_check("主菜单按钮都在 640×360 里", _all_inside(menu))
	if button == null:
		menu.queue_free()
		return
	button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: SettingsPanel = null
	for child in menu.get_children():
		if child is SettingsPanel:
			panel = child
	_check("按设置打开设置画面", panel != null)
	if panel != null:
		_check("设置画面的文字来自文本表", panel.story_mode.text == "剧情模式"
			and not _has_missing(panel))
		_check("剧情模式勾选和存档一致", panel.story_mode.button_pressed == Game.current_story_mode())
		_check("设置画面在 640×360 里", _all_inside(panel))
		panel.story_mode.button_pressed = true
		_check("勾选剧情模式写进存档", Game.current_story_mode() and Game.settings.story_mode)
		panel.volume.value = 0.3
		_check("拖音量滑条改设置", is_equal_approx(Game.settings.volume, 0.3)
			and panel.volume_value.text == "30%")
		_press_escape()
		await get_tree().process_frame
		_check("Esc 关掉设置画面", not is_instance_valid(panel) or panel.is_queued_for_deletion())
	menu.queue_free()
	await get_tree().process_frame


func _check_pause() -> void:
	_check("主菜单以外的画面（测试场景）不暂停", not Pause.can_pause())
	_press_escape()
	_check("不能暂停时 Esc 不开暂停画面", not Pause.is_open() and not get_tree().paused)

	# 假的主流程画面：current_scene 指向它，检查 Esc 能开暂停、结局节点不开。
	var fake := _fake_flow("story")
	get_tree().current_scene = fake
	_check("主流程画面能暂停", Pause.can_pause())
	_press_escape()
	_check("Esc 打开暂停画面并暂停游戏", Pause.is_open() and get_tree().paused)
	_check("暂停画面一直运行", Pause.process_mode == Node.PROCESS_MODE_ALWAYS)
	await get_tree().process_frame
	_check("暂停画面有继续、设置、回到主菜单、退出游戏", Pause.root != null
		and _find_button(Pause.root, "继续") != null and _find_button(Pause.root, "设置") != null
		and _find_button(Pause.root, "回到主菜单") != null and _find_button(Pause.root, "退出游戏") != null)
	_check("暂停画面在 640×360 里", _all_inside(Pause.root) and not _has_missing(Pause.root))
	Pause.open_settings()
	await get_tree().process_frame
	_check("暂停时能打开设置", Pause.settings != null and not Pause.root.visible)
	_check("设置画面在暂停时也运行", Pause.settings.can_process())
	_press_escape()
	await get_tree().process_frame
	_check("Esc 先关设置，回到暂停画面", Pause.settings == null and Pause.is_open() and Pause.root.visible)
	_press_escape()
	await get_tree().process_frame
	_check("再按 Esc 继续游戏", not Pause.is_open() and not get_tree().paused)

	fake.set("node", {"type": "ending"})
	_check("结局节点不暂停", not Pause.can_pause())
	_press_escape()
	_check("结局时 Esc 不开暂停画面", not Pause.is_open())
	get_tree().current_scene = self
	fake.queue_free()
	await get_tree().process_frame


func _fake_flow(type: String) -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar node: Dictionary = {}\n"
	script.reload()
	var fake := Node.new()
	fake.set_script(script)
	fake.scene_file_path = Pause.FLOW_SCENE
	fake.set("node", {"type": type})
	get_tree().root.add_child(fake)
	return fake


func _press_escape() -> void:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	get_viewport().push_input(event)


func _find_button(node: Node, text: String) -> Button:
	for b in node.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null


func _all_inside(node: Node) -> bool:
	var screen := Rect2(Vector2.ZERO, Vector2(640, 360))
	for c in node.find_children("*", "Control", true, false):
		var control := c as Control
		if control.is_visible_in_tree() and not screen.encloses(control.get_global_rect()):
			print("    outside: %s %s" % [control.name, control.get_global_rect()])
			return false
	return true


func _has_missing(node: Node) -> bool:
	for c in node.find_children("*", "", true, false):
		var t: Variant = c.get("text")
		if t is String and String(t).contains("[待写:"):
			print("    missing text: %s" % t)
			return true
	return false


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		failures += 1
