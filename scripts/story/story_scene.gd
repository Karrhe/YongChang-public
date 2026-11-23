extends Control
## 剧情画面（FLOW-2）：背景 + 对话框，播完一场交回 FLOW。
## 接口：setup({"scene_id": 流程节点 ID, "key": 剧情表的场景 ID, "gen": 1–3}) → finished({})。
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
	box = DIALOGUE_BOX.instantiate()
	add_child(box)
	box.done.connect(func() -> void: finished.emit({}), CONNECT_ONE_SHOT)
	box.play([input.get("key", input.get("scene_id", ""))])


func _make_background() -> Control:
	var cfg: Dictionary = Rules.get_value("story.backgrounds", {})
	var bg_id: String = cfg.get("by_scene", {}).get(input.get("scene_id", ""), "")
	var path := "%s%s.png" % [cfg.get("dir", ""), bg_id]
	if bg_id != "" and ResourceLoader.exists(path):
		var tex := TextureRect.new()
		tex.texture = load(path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		return tex
	var block := ColorRect.new()
	block.color = Color.html(String(cfg.get("gen_colors", {}).get(str(input.get("gen", 0)), "#000000")))
	return block
