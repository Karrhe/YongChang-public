extends Node
## 全局游戏状态：保存 / 读取存档，取剧情文字，切换画面。

const DEFAULT_SAVE_PATH := "user://save.tres"
## 玩家设置（剧情模式默认值、主音量、全屏），和存档分开放，删档不丢。
const DEFAULT_SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "settings"
const SETTINGS_KEYS: PackedStringArray = ["story_mode", "volume", "fullscreen"]
## 每个模块一张文本表，都放在这里。Godot 导入 CSV 后在旁边生成 .translation，
## 启动时全部加载，所以新加一张表不用改 project.godot。
const TEXT_DIR := "res://data/text/"

## 测试改成临时路径，避免删掉真实存档。
var save_path := DEFAULT_SAVE_PATH
var save: SaveData = SaveData.new()
## 测试改成临时路径，避免改掉玩家的设置。
var settings_path := DEFAULT_SETTINGS_PATH
## 当前设置：story_mode（新游戏默认开不开剧情模式）、volume（0–1）、fullscreen。
var settings := {}
## 已加载的文本表路径（测试检查用）。
var text_tables: PackedStringArray = PackedStringArray()
## 音效（data/rules/audio.json）：事件名 → 文件；几个播放器轮流用，几个音效可以叠在一起。
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _sfx_cache := {}
## 开始退出后不再出声。
var _quitting := false


func _ready() -> void:
	# 只做中文：不跟随系统语言。
	TranslationServer.set_locale("zh")
	load_text_tables()
	load_settings()
	apply_settings()
	# 点窗口的关闭按钮也走 quit()，先停音效再退（ISSUE-001 QA-005）。
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not _quitting:
		quit()


## 播一个音效事件：gong、tide、hit、repair、beacon、lantern（TEAM-001 §4）。没配或没有文件时不出声。
func play_sfx(event: String) -> void:
	if _quitting:
		return
	var file := String(Rules.get_value("audio.events." + event, ""))
	if file == "":
		return
	var path := String(Rules.get_value("audio.dir", "")) + file
	if not _sfx_cache.has(path):
		_sfx_cache[path] = load(path) if ResourceLoader.exists(path) else null
	if _sfx_cache[path] == null:
		return
	if _sfx_players.is_empty():
		for i in int(Rules.get_value("audio.voices", 4)):
			var player := AudioStreamPlayer.new()
			add_child(player)
			_sfx_players.append(player)
	var player := _sfx_players[_sfx_next % _sfx_players.size()]
	_sfx_next += 1
	player.stream = _sfx_cache[path]
	player.volume_db = float(Rules.get_value("audio.volume_db", 0.0))
	player.play()


## 停掉所有还在响的音效。
func stop_sfx() -> void:
	for player in _sfx_players:
		player.stop()
		player.stream = null


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


# ---------- 设置 ----------

## 读 settings.cfg；没有的项用 core.json 的 settings 默认值。
func load_settings() -> void:
	var cfg := ConfigFile.new()
	var ok := cfg.load(settings_path) == OK
	settings = {}
	for key in SETTINGS_KEYS:
		var fallback: Variant = Rules.get_value("core.settings." + key, null)
		settings[key] = cfg.get_value(SETTINGS_SECTION, key, fallback) if ok else fallback
	settings.story_mode = bool(settings.story_mode)
	settings.fullscreen = bool(settings.fullscreen)
	settings.volume = clampf(float(settings.volume), 0.0, 1.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in SETTINGS_KEYS:
		cfg.set_value(SETTINGS_SECTION, key, settings[key])
	var err := cfg.save(settings_path)
	if err != OK:
		push_error("Settings save failed: %s" % error_string(err))


## 把音量、全屏用到引擎上。
func apply_settings() -> void:
	var volume := float(settings.volume)
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, volume <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(volume) if volume > 0.0 else -80.0)
	# 无界面运行（测试）时没有窗口可切。
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


## 改一项设置：存进 settings.cfg 并马上生效。
func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	save_settings()
	apply_settings()


## 剧情模式：改新游戏的默认值，也改当前这一局。
## 磁盘上的存档只改 story_mode 这一项，不把内存里的进度写进去：
## 节点开始时存的档要保持原样（事件节点已生效、战斗结果未接受时都不能存，见 flow.gd）。
func set_story_mode(on: bool) -> void:
	set_setting("story_mode", on)
	save.story_mode = on
	if not has_save():
		return
	var on_disk := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if on_disk is SaveData:
		on_disk.story_mode = on
		var err := ResourceSaver.save(on_disk, save_path)
		if err != OK:
			push_error("Save failed: %s" % error_string(err))


## 当前这一局是不是剧情模式：有存档看存档，没有看默认值。
func current_story_mode() -> bool:
	if has_save():
		var on_disk := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if on_disk is SaveData:
			return on_disk.story_mode
	return bool(settings.get("story_mode", false))


## from_settings = true（主菜单开新游戏）时，剧情模式按设置里的默认值开。
func new_game(from_settings: bool = false) -> void:
	save = SaveData.new()
	save.version = SaveData.CURRENT_VERSION
	if from_settings:
		save.story_mode = bool(settings.get("story_mode", false))
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
		FlowLogic.migrate(save)  # 旧存档补砖槽
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


## 退出游戏。先停掉音效、等音频服务器放掉正在播的声音再退，
## 否则 Godot 退出时报对象泄漏和资源占用（ISSUE-001 QA-005）。测试也用它退出。
func quit(exit_code: int = 0) -> void:
	_quitting = true
	stop_sfx()
	_sfx_cache.clear()
	# 音频线程按真实时间混音，等几帧不够（无界面时一帧很快），按秒等。
	await get_tree().create_timer(float(Rules.get_value("audio.quit_delay_seconds", 0.2)), true, false, true).timeout
	get_tree().quit(exit_code)
