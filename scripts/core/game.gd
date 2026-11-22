extends Node
## 全局游戏状态：保存 / 读取存档，取剧情文字，切换画面。

const SAVE_PATH := "user://save.tres"

var save: SaveData = SaveData.new()


func _ready() -> void:
	# 只做中文：不跟随系统语言。
	TranslationServer.set_locale("zh")


func new_game() -> void:
	save = SaveData.new()
	save.people = int(Rules.get_value("work.start.people", 0))
	save.rice = int(Rules.get_value("work.start.rice", 0))
	save.materials = int(Rules.get_value("work.start.materials", 0))
	save.progress = "P1"


func has_save() -> bool:
	return ResourceLoader.exists(SAVE_PATH)


func save_game() -> void:
	var err := ResourceSaver.save(save, SAVE_PATH)
	if err != OK:
		push_error("Save failed: %s" % error_string(err))


func load_game() -> bool:
	if not has_save():
		return false
	var loaded := ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded is SaveData:
		save = loaded
		return true
	return false


## 取剧情或界面文字。文本表里没有这一条时，显示 [待写: ID]。
## 文字里的 {名1} 换成文本表里固定的第一代主角名字（NAME_GEN1），
## {名2} {名3} 换成玩家起的名字。
func text(id: String) -> String:
	var value := tr(id)
	if value == id:
		return "[待写: %s]" % id
	if value.contains("{名1}"):
		value = value.replace("{名1}", tr("NAME_GEN1"))
	for i in save.names.size():
		value = value.replace("{名%d}" % (i + 2), save.names[i])
	return value


func go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func quit() -> void:
	get_tree().quit()
