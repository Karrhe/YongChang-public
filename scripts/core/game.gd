extends Node
## 全局游戏状态：保存 / 读取存档，取剧情文字，切换画面。

const DEFAULT_SAVE_PATH := "user://save.tres"
## 每个模块一张文本表，都放在这里。Godot 导入 CSV 后在旁边生成 .translation，
## 启动时全部加载，所以新加一张表不用改 project.godot。
const TEXT_DIR := "res://data/text/"

## 测试改成临时路径，避免删掉真实存档。
var save_path := DEFAULT_SAVE_PATH
var save: SaveData = SaveData.new()
## 已加载的文本表路径（测试检查用）。
var text_tables: PackedStringArray = PackedStringArray()


func _ready() -> void:
	# 只做中文：不跟随系统语言。
	TranslationServer.set_locale("zh")
	load_text_tables()


func load_text_tables() -> void:
	for file_name in DirAccess.get_files_at(TEXT_DIR):
		# 导出版里资源可能带 .remap 后缀，去掉后再按原路径加载。
		file_name = file_name.trim_suffix(".remap")
		if file_name.get_extension() != "translation":
			continue
		var path := TEXT_DIR + file_name
		if path in text_tables:
			continue
		var table := load(path)
		if table is Translation:
			TranslationServer.add_translation(table)
			text_tables.append(path)
		else:
			push_error("Not a translation file: %s" % path)


func new_game() -> void:
	save = SaveData.new()
	save.people = int(Rules.get_value("core.new_game.people", 0))
	save.rice = int(Rules.get_value("core.new_game.rice", 0))
	save.materials = int(Rules.get_value("core.new_game.materials", 0))
	save.progress = "P1"


func has_save() -> bool:
	return ResourceLoader.exists(save_path)


func save_game() -> void:
	var err := ResourceSaver.save(save, save_path)
	if err != OK:
		push_error("Save failed: %s" % error_string(err))


func load_game() -> bool:
	if not has_save():
		return false
	var loaded := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded is SaveData:
		save = loaded
		return true
	return false


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


## 取剧情或界面文字。文本表里没有这一条时，显示 [待写: ID]。
## 文字里的 {名1} 换成文本表里固定的第一代主角名字（NAME_GEN1），
## {名2} {名3} 换成玩家起的名字，{刻字} 换成石锤刻字。
func text(id: String) -> String:
	var value := tr(id)
	if value == id:
		return missing(id)
	return fill_names(value)


## 还没写的文字或剧情场景显示的占位。
func missing(id: String) -> String:
	return "[待写: %s]" % id


## 替换名字和刻字。from 不给时用当前存档。
func fill_names(value: String, from: SaveData = null) -> String:
	var s := from if from != null else save
	if value.contains("{名1}"):
		value = value.replace("{名1}", tr("NAME_GEN1"))
	for i in s.names.size():
		var name := s.names[i]
		if name == "":
			# 还没起名（起名界面之前）：用默认名字。
			name = tr("NAME_DEFAULT_%d" % (i + 2))
		value = value.replace("{名%d}" % (i + 2), name)
	if value.contains("{刻字}"):
		value = value.replace("{刻字}", hammer_text(s))
	return value


func hammer_text(from: SaveData = null) -> String:
	var s := from if from != null else save
	return s.hammer_text if s.hammer_text != "" else tr("HAMMER_DEFAULT")


func go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func quit() -> void:
	get_tree().quit()
