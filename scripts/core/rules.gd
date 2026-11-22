extends Node
## 所有可调的规则和数值都从 data/rules/rules.json 读取，代码里不写死数值。

const RULES_PATH := "res://data/rules/rules.json"

var data: Dictionary = {}


func _ready() -> void:
	load_rules()


func load_rules() -> void:
	var file := FileAccess.open(RULES_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open rules file: %s" % RULES_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		data = parsed
	else:
		push_error("Rules file is not a JSON object: %s" % RULES_PATH)


## 按路径取值，例如 get_value("work.start.rice")。找不到时返回 default。
func get_value(path: String, default: Variant = null) -> Variant:
	var node: Variant = data
	for key in path.split("."):
		if node is Dictionary and node.has(key):
			node = node[key]
		else:
			return default
	return node
