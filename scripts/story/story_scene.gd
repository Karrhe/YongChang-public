extends Control
## 剧情画面（FLOW-2）：背景 + 对话框，播完一场交回 FLOW。
## 接口：setup({"scene_id": 流程节点 ID, "key": 剧情表的场景 ID, "gen": 1–3}) → finished({})。
## 也可以给 "keys"（几个场景 ID 接着播）和 "append"（整理好的台词，播在最后；规则事件的说明用）。
## 背景按 story.json 的 backgrounds 配；没配或还没有图时按代用整体色。

signal finished(result: Dictionary)

const DIALOGUE_BOX := preload("res://scenes/story/dialogue_box.tscn")

var input: Dictionary = {}
var box: DialogueBox
var background: Control


func setup(story_input: Dictionary) -> void:
	input = story_input


func _ready() -> void:
	background = _make_background()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_add_prop()
	box = DIALOGUE_BOX.instantiate()
	add_child(box)
	box.done.connect(func() -> void: finished.emit({}), CONNECT_ONE_SHOT)
	var keys: Array = input.get("keys", [input.get("key", input.get("scene_id", ""))])
	var lines: Array[Dictionary] = []
	for id in keys:
		lines.append_array(StoryTable.main().lines(String(id)))
	for line: Dictionary in input.get("append", []):
		lines.append(line)
	box.play_lines(lines)


func _make_background() -> Control:
	var cfg: Dictionary = Rules.get_value("story.backgrounds", {})
	var bg_id: String = cfg.get("by_scene", {}).get(input.get("scene_id", ""), "")
	var path := "%s%s.png" % [cfg.get("dir", ""), bg_id]
	if bg_id != "" and ResourceLoader.exists(path):
		var tex := TextureRect.new()
		tex.texture = load(path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		# 三代的氛围用整体调色，不重画（ART-001 §1）：按代乘一个颜色；夜里的场景再乘一层。
		var tint := Color.html(String(cfg.get("gen_tints", {}).get(str(input.get("gen", 0)), "#ffffff")))
		var night_tint: String = cfg.get("night_scenes", {}).get(input.get("scene_id", ""), "")
		if night_tint != "":
			tint *= Color.html(night_tint)
		tex.modulate = tint
		return tex
	var block := ColorRect.new()
	block.color = Color.html(String(cfg.get("gen_colors", {}).get(str(input.get("gen", 0)), "#000000")))
	return block


## 道具小图（story.json 的 props）：画在左上角（右上角是“回看”按钮）。
func _add_prop() -> void:
	var cfg: Dictionary = Rules.get_value("story.props", {})
	var prop_id: String = cfg.get("by_scene", {}).get(input.get("scene_id", ""), "")
	var path := "%s%s.png" % [cfg.get("dir", ""), prop_id]
	if prop_id == "" or not ResourceLoader.exists(path):
		return
	var prop := TextureRect.new()
	prop.texture = load(path)
	prop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var side := 32.0 * float(cfg.get("scale", 2))
	prop.size = Vector2(side, side)
	prop.position = Vector2(12, 12)
	prop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prop)
