class_name StoryTable
extends RefCounted
## 剧情表（data/text/story.csv，格式见 TEAM-001 §4）：一行一句，按行的顺序播放。
## 只读不写存档：条件看传进来的存档，名字用 Game.fill_names 替换。

const COLUMNS := ["scene_id", "line_id", "condition", "speaker", "portrait", "text"]
## 条件行（剧本“人物设定”下的表）。死亡阶段替换句另用 DEATH_B1–DEATH_B9。
const CONDITIONS := ["GEN1_ALIVE", "GEN1_DEAD", "GEN1_NONE", "GEN2_ELDER_A", "GEN2_ELDER_B", "GEN2_NONE"]
const DEATH_PREFIX := "DEATH_B"
const BATTLE_COUNT := 9
## line_id 以它开头的行不在对话里播放，留给 FLOW-3 做选项。
const OPTION_PREFIX := "opt"
## portrait 列写它表示这句不要头像。
const NO_PORTRAIT := "-"

static var _main: StoryTable = null

var path := ""
## 场景 ID → 这一场的行（按文件里的顺序）。
## 每行是 {"line_id", "condition", "speaker", "portrait", "text"}，都是表里的原文。
var scenes: Dictionary = {}
## 读表时发现的问题，测试会检查它为空。
var errors: PackedStringArray = PackedStringArray()


## 游戏用的那张表（路径在 story.json 的 table），第一次用时读取。
static func main() -> StoryTable:
	if _main == null:
		_main = load_file(Rules.get_value("story.table", ""))
		for message in _main.errors:
			push_error(message)
	return _main


## 改了表或换了规则以后重新读。
static func reload_main() -> StoryTable:
	_main = null
	return main()


static func load_file(file_path: String) -> StoryTable:
	var table := StoryTable.new()
	table.path = file_path
	table._read()
	return table


# ---------- 读表 ----------

func _read() -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Cannot open story table: %s" % path)
		return
	var header := file.get_csv_line()
	if header.size() > 0:
		header[0] = header[0].trim_prefix("﻿")  # 有的编辑器存 UTF-8 时会加 BOM
	if Array(header) != COLUMNS:
		errors.append("%s: header must be %s" % [path, ",".join(COLUMNS)])
		return
	var record := 1
	while not file.eof_reached():
		var cells := file.get_csv_line()
		record += 1
		if _is_blank(cells) or cells[0].strip_edges().begins_with("#"):
			continue
		if cells.size() != COLUMNS.size():
			errors.append("%s record %d: expected %d columns, found %d" % [path, record, COLUMNS.size(), cells.size()])
			continue
		_add_row(record, cells)


func _add_row(record: int, cells: PackedStringArray) -> void:
	var scene_id := cells[0].strip_edges()
	var row := {
		"line_id": cells[1].strip_edges(),
		"condition": cells[2].strip_edges(),
		"speaker": cells[3].strip_edges(),
		"portrait": cells[4].strip_edges(),
		"text": cells[5].strip_edges(),
	}
	var where := "%s record %d (%s %s)" % [path, record, scene_id, row.line_id]
	if scene_id == "" or row.line_id == "":
		errors.append("%s: scene_id and line_id must not be empty" % where)
		return
	if row.text == "":
		errors.append("%s: text is empty" % where)
	if not is_known_condition(row.condition):
		errors.append("%s: unknown condition %s" % [where, row.condition])
	var rows: Array = scenes.get_or_add(scene_id, [])
	for other: Dictionary in rows:
		# 同一个 line_id 只能给条件行用：几行都带条件，按条件挑一行（选项台词换说话人，ISSUE-001 STO-01）。
		if other.line_id == row.line_id and (other.condition == "" or row.condition == ""):
			errors.append("%s: line_id repeated" % where)
			return
	rows.append(row)


static func _is_blank(cells: PackedStringArray) -> bool:
	for cell in cells:
		if cell.strip_edges() != "":
			return false
	return true


# ---------- 条件 ----------

static func is_known_condition(condition: String) -> bool:
	if condition == "":
		return true
	for raw in condition.split("&"):
		var part := raw.strip_edges()
		if part in CONDITIONS:
			continue
		var n := part.trim_prefix(DEATH_PREFIX)
		if part.begins_with(DEATH_PREFIX) and n.is_valid_int() and int(n) >= 1 and int(n) <= BATTLE_COUNT:
			continue
		return false
	return true


## 条件是否成立。几个条件用 & 连起来时，都成立才算。
static func condition_holds(condition: String, save: SaveData) -> bool:
	if condition == "":
		return true
	for part in condition.split("&"):
		if not _holds(part.strip_edges(), save):
			return false
	return true


static func _holds(condition: String, save: SaveData) -> bool:
	match condition:
		"GEN1_ALIVE":  # [一代存活]
			return save.hero_alive[0]
		"GEN1_DEAD":  # [一代阵亡]：王成阵亡且阿棠在
			return not save.hero_alive[0] and save.companion_alive[0]
		"GEN1_NONE":  # [一代都不在]：王成和阿棠都阵亡
			return not save.hero_alive[0] and not save.companion_alive[0]
		"GEN2_ELDER_A":  # [二代长辈] 甲：{名2} 在
			return save.hero_alive[1]
		"GEN2_ELDER_B":  # [二代长辈] 乙：{名2} 不在、周砚在
			return not save.hero_alive[1] and save.companion_alive[1]
		"GEN2_NONE":  # [二代都不在]
			return not save.hero_alive[1] and not save.companion_alive[1]
	if condition.begins_with(DEATH_PREFIX):
		# 死亡阶段替换句：某一代主角死在这一场。
		return save.death_battle.has("battle_" + condition.trim_prefix(DEATH_PREFIX))
	return false


# ---------- 取台词 ----------

func has_scene(scene_id: String) -> bool:
	return scenes.has(scene_id)


## 一个场景要播放的台词：去掉条件不成立的行和选项行，名字替换好。
## 每句是 {"scene_id", "line_id", "speaker"（显示的名字，旁白为空）, "portrait"（头像 ID，没有为空）,
## "text", "narration"}。表里没有这个场景时，返回一句 [待写: 场景ID]。
func lines(scene_id: String, save: SaveData = null) -> Array[Dictionary]:
	if save == null:
		save = Game.save
	var out: Array[Dictionary] = []
	if not scenes.has(scene_id):
		out.append({"scene_id": scene_id, "line_id": "", "speaker": "", "portrait": "",
			"text": Game.missing(scene_id), "narration": true})
		return out
	for row: Dictionary in scenes[scene_id]:
		if row.line_id.begins_with(OPTION_PREFIX):
			continue
		if condition_holds(row.condition, save):
			out.append(_resolve(scene_id, row, save))
	return out


## 按 line_id 取一行（FLOW-3 取选项用）。同一个 line_id 有几行条件行时，取第一行条件成立的；
## 都不成立就取第一行。没有时返回空表。
func find_line(scene_id: String, line_id: String, save: SaveData = null) -> Dictionary:
	if save == null:
		save = Game.save
	var first: Dictionary = {}
	for row: Dictionary in scenes.get(scene_id, []):
		if row.line_id != line_id:
			continue
		if condition_holds(row.condition, save):
			return _resolve(scene_id, row, save)
		if first.is_empty():
			first = row
	return {} if first.is_empty() else _resolve(scene_id, first, save)


func _resolve(scene_id: String, row: Dictionary, save: SaveData) -> Dictionary:
	var speaker: String = row.speaker
	var narration: bool = speaker == "" or speaker == String(Rules.get_value("story.narrator", ""))
	var portrait: String = row.portrait
	if portrait == NO_PORTRAIT:
		portrait = ""
	elif portrait == "" and not narration:
		portrait = Rules.get_value("story.portraits.by_speaker", {}).get(speaker, "")
	return {
		"scene_id": scene_id,
		"line_id": row.line_id,
		"speaker": "" if narration else Game.fill_names(speaker, save),
		"portrait": portrait,
		"text": Game.fill_names(row.text, save),
		"narration": narration,
	}
