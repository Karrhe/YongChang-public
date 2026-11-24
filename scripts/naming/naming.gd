class_name NamingScreen
extends Control
## 起名界面（FLOW-3）：T1 之后给第二代主角起名，接着输入石锤刻字；T2 之后给第三代主角起名。
## 接口：setup(FlowLogic.naming_input(...)) → finished({"name": 名字, "hammer": 刻字})。
## hammer 只在第二代有。空着交回空字符串，由 FLOW 换成默认名字、默认刻字。不写存档。
## 名字规则（ISSUE-001 WORK-09 临时做法）：1–4 个汉字，不能和固定角色、上一代主角重名。

signal finished(result: Dictionary)

var hammer_icon: TextureRect
var input: Dictionary = {}
var result: Dictionary = {}
## "name" 或 "hammer"。
var step := "name"

var prompt: Label
var edit: LineEdit
var hint: Label
var error: Label
var ok: Button


func setup(naming_input: Dictionary) -> void:
	input = naming_input


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color.html(String(Rules.get_value("story.backgrounds.gen_colors", {}).get(str(input.get("gen", 0)), "#000000")))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var bg_cfg: Dictionary = Rules.get_value("story.backgrounds", {})
	var bg_path := "%s%s.png" % [bg_cfg.get("dir", ""), bg_cfg.get("naming", "")]
	if String(bg_cfg.get("naming", "")) != "" and ResourceLoader.exists(bg_path):
		var art := TextureRect.new()
		art.texture = load(bg_path)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.modulate = Color.html(String(bg_cfg.get("naming_tint", "#ffffff")))
		add_child(art)
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(holder)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = _color("panel")
	style.border_color = _color("border")
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(460, 0)
	holder.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	# 石锤（三代信物）：刻字那一步显示在上面。
	hammer_icon = TextureRect.new()
	var hammer_path := String(Rules.get_value("story.props.dir", "")) + "stone_hammer.png"
	if ResourceLoader.exists(hammer_path):
		hammer_icon.texture = load(hammer_path)
	hammer_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hammer_icon.custom_minimum_size = Vector2(64, 64)
	hammer_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hammer_icon.visible = false
	column.add_child(hammer_icon)
	prompt = _label(column, _color("text"))
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	edit = LineEdit.new()
	edit.add_theme_font_size_override("font_size", _font_size())
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.text_submitted.connect(func(_t: String) -> void: submit())
	column.add_child(edit)
	hint = _label(column, _color("action"))
	error = _label(column, _color("warn"))
	ok = Button.new()
	ok.text = Game.text("NAMING_OK")
	ok.add_theme_font_size_override("font_size", _font_size())
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(submit)
	column.add_child(ok)
	_show_name_step()


func _show_name_step() -> void:
	step = "name"
	prompt.text = Game.text(input.get("prompt_key", ""))
	edit.text = ""
	edit.max_length = int(input.get("max_chars", 4))
	edit.placeholder_text = input.get("default_name", "")
	hint.text = Game.text("NAMING_HINT").format({"name": input.get("default_name", "")})
	error.text = ""
	edit.grab_focus.call_deferred()


func _show_hammer_step() -> void:
	step = "hammer"
	hammer_icon.visible = hammer_icon.texture != null
	prompt.text = Game.text("NAMING_HAMMER_PROMPT")
	edit.text = ""
	edit.max_length = int(input.get("hammer_max_chars", 12))
	edit.placeholder_text = input.get("default_hammer", "")
	hint.text = Game.text("NAMING_HAMMER_HINT").format({
		"max": input.get("hammer_max_chars", 12), "text": input.get("default_hammer", "")})
	error.text = ""
	edit.grab_focus.call_deferred()


## 确定当前这一步（按钮或回车）。不合规则时显示原因，留在这一步。
func submit() -> void:
	var text := edit.text.strip_edges()
	if step == "name":
		var problem := check_name(text, input.get("default_name", ""), Array(input.get("taken", [])), int(input.get("max_chars", 4)))
		if not problem.is_empty():
			error.text = Game.text(problem.key).format(problem.args)
			return
		result["name"] = text
		if input.get("ask_hammer", false):
			_show_hammer_step()
			return
	else:
		var problem := check_hammer(text, int(input.get("hammer_max_chars", 12)))
		if not problem.is_empty():
			error.text = Game.text(problem.key).format(problem.args)
			return
		result["hammer"] = text
	finished.emit(result)


## 名字合不合规则：空着用默认名字（默认名字也不能被占）；1–max 个汉字；不能重名。
## 返回空表 = 合格，否则 {"key": 文字键, "args": 填空}。
static func check_name(text: String, default_name: String, taken: Array, max_chars: int) -> Dictionary:
	var name := text.strip_edges()
	if name == "":
		name = default_name
	elif not RegEx.create_from_string("^\\p{Han}{1,%d}$" % max_chars).search(name):
		return {"key": "NAMING_ERR_CHARS", "args": {"max": max_chars}}
	if name in taken:
		return {"key": "NAMING_ERR_TAKEN", "args": {"name": name}}
	return {}


## 刻字：最多 max 个字，不能有方括号和花括号（会和文字里的标记混在一起）。空着用默认刻字。
static func check_hammer(text: String, max_chars: int) -> Dictionary:
	var t := text.strip_edges()
	if t.length() > max_chars or RegEx.create_from_string("[\\[\\]{}]").search(t) != null:
		return {"key": "NAMING_ERR_HAMMER", "args": {"max": max_chars}}
	return {}


func _font_size() -> int:
	return int(Rules.get_value("story.box.font_size", 12))


func _color(key: String) -> Color:
	return Color.html(String(Rules.get_value("story.box.colors." + key, "#ffffff")))


func _label(parent: Node, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", _font_size())
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label
