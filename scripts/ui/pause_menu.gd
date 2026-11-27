extends CanvasLayer
## 暂停画面（自动加载 Pause）：在主流程画面里按 Esc 打开，游戏暂停。
## 继续 / 设置 / 回到主菜单 / 退出游戏。
## 回到主菜单不用另外存档：flow.gd 在每个节点开始时自动存档，继续时从这个节点的开头来；
## 战斗结果没接受之前、事件说明还没看完时都不存，回菜单等于没走完这一段。
## 主菜单、制作人员、结局不开（结局是一整段放灯演出，制作人员自己用 Esc 回菜单）。

const FLOW_SCENE := "res://scenes/flow/flow.tscn"
const MENU_SCENE := "res://scenes/menu/menu.tscn"

var root: Control = null
var settings: SettingsPanel = null
var resume_button: Button = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100


func is_open() -> bool:
	return root != null


## 现在能不能暂停：只在主流程画面里，结局节点不算。
func can_pause() -> bool:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != FLOW_SCENE:
		return false
	var node: Variant = scene.get("node")
	return node is Dictionary and String(node.get("type", "")) != "ending"


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if is_open():
		if settings == null:  # 设置画面开着时由它自己关
			get_viewport().set_input_as_handled()
			close()
	elif can_pause():
		get_viewport().set_input_as_handled()
		open()


func open() -> void:
	if is_open():
		return
	get_tree().paused = true
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var box := SettingsPanel.build_frame(root, "UI_PAUSE_TITLE")
	resume_button = SettingsPanel.add_button(box, "UI_RESUME", close)
	SettingsPanel.add_button(box, "UI_SETTINGS", open_settings)
	SettingsPanel.add_button(box, "UI_TO_MENU", to_menu)
	SettingsPanel.add_button(box, "UI_QUIT_GAME", Game.quit)
	box.add_child(SettingsPanel.note_label("UI_PAUSE_NOTE"))
	resume_button.grab_focus.call_deferred()


func close() -> void:
	if settings != null:
		settings.closed.disconnect(_on_settings_closed)
		settings.queue_free()
		settings = null
	if root != null:
		root.queue_free()
		root = null
	resume_button = null
	get_tree().paused = false


func open_settings() -> void:
	if settings != null:
		return
	root.visible = false
	settings = SettingsPanel.new()
	settings.closed.connect(_on_settings_closed)
	add_child(settings)


func _on_settings_closed() -> void:
	settings = null
	if root != null:
		root.visible = true
		resume_button.grab_focus.call_deferred()


func to_menu() -> void:
	close()
	Game.go_to(MENU_SCENE)
