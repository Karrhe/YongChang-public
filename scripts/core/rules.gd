extends Node
## 所有可调的规则和数值都从 data/rules/*.json 读取，代码里不写死数值。
## 每个文件只有一个顶层键，键名等于文件名（battle.json → "battle"），
## 这样各任务包各管一个文件，不会互相覆盖。以下划线开头的键（如 "_note"）是注释，忽略。

const RULES_DIR := "res://data/rules/"

var data: Dictionary = {}
## 读取时发现的问题（文件打不开、格式不对、键名和文件名不一致），测试会检查它为空。
var errors: PackedStringArray = PackedStringArray()


func _ready() -> void:
	load_rules()


func load_rules() -> void:
	data = {}
	errors = PackedStringArray()
	var files := DirAccess.get_files_at(RULES_DIR)
	files.sort()
	for file_name in files:
		if file_name.get_extension() == "json":
			_load_file(file_name)


func _load_file(file_name: String) -> void:
	var path := RULES_DIR + file_name
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_error("Cannot open rules file: %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_error("Rules file is not a JSON object: %s" % path)
		return
	var expected := file_name.get_basename()
	for key: String in parsed:
		if key.begins_with("_"):
			continue
		if key != expected:
			_error("Rules file %s must only have the top-level key \"%s\", found \"%s\"" % [path, expected, key])
			continue
		data[key] = parsed[key]


func _error(message: String) -> void:
	errors.append(message)
	push_error(message)


## 按路径取值，例如 get_value("core.new_game.rice")。找不到时返回 default。
func get_value(path: String, default: Variant = null) -> Variant:
	var node: Variant = data
	for key in path.split("."):
		if node is Dictionary and node.has(key):
			node = node[key]
		else:
			return default
	return node
