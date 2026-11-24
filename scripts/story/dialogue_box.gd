class_name DialogueBox
extends Control
## 对话框（FLOW-2）：一句一句播放剧情表里的台词。对话没有配音，只做文字：
## - 逐字显示，标点后稍停（速度和停顿在 story.json 的 typing）；
## - 点一下（或按空格、回车）先显示整句，再点下一句；
## - 滚轮向上、PageUp 或“回看”按钮看这一段前面的台词；右键、Esc 或“返回”关掉回看。
## 剧情画面（story.tscn）和战斗里的 story_keys 都用它：play(场景 ID 列表)，播完发 done。
## 它盖住整个画面，播放时挡住下面的点击（TEAM-001 §4）。

signal done

var table: StoryTable = null
## 这一次 play 要播的全部台词。
var lines: Array[Dictionary] = []
## 当前是第几句（从 0 开始）；-1 = 还没开始。
var index := -1
## 已经显示过的台词（回看用）。
var history: Array[Dictionary] = []
var playing := false
## 当前这句还在逐字显示。
var typing := false

var _plain := ""
var _clock := 0.0
var _next_cost := 0.0
var _blink := 0.0

var _panel: PanelContainer
var _portrait_slot: Control
var _portrait_tex: TextureRect
var _portrait_block: ColorRect
var _name_label: Label
var _text: RichTextLabel
var _next_mark: Label
var _backlog: PanelContainer
var _backlog_button: Button
var _backlog_list: VBoxContainer
var _backlog_scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = playing


## 播放几个场景（剧情表的场景 ID），按顺序接着播。from 不给时用游戏的剧情表。
func play(scene_ids: Array, from: StoryTable = null) -> void:
	table = from if from != null else StoryTable.main()
	var all: Array[Dictionary] = []
	for id in scene_ids:
		all.append_array(table.lines(String(id)))
	play_lines(all)


## 直接播放整理好的台词（每句格式同 StoryTable.lines）。
func play_lines(to_play: Array[Dictionary]) -> void:
	_build()
	lines = to_play
	index = -1
	history.clear()
	playing = true
	visible = true
	_close_backlog()
	if lines.is_empty():
		_finish.call_deferred()
		return
	_show_next()


## 点一下：在回看里就关掉回看；正在逐字显示就显示整句；否则下一句。
func advance() -> void:
	if not playing:
		return
	if is_backlog_open():
		_close_backlog()
	elif typing:
		_complete_line()
	else:
		_show_next()


func _show_next() -> void:
	index += 1
	if index >= lines.size():
		_finish()
		return
	var line := lines[index]
	history.append(line)
	_name_label.text = line.speaker
	_name_label.visible = line.speaker != ""
	_show_portrait(line.portrait)
	_plain = line.text
	_text.text = to_bbcode(_plain, _color("action"))
	_clock = 0.0
	var cps := float(Rules.get_value("story.typing.chars_per_second", 0))
	if cps <= 0.0 or _plain.is_empty():
		_complete_line()
		return
	typing = true
	_text.visible_characters = 0
	_next_cost = 1.0 / cps
	_next_mark.visible = false


func _complete_line() -> void:
	typing = false
	_text.visible_characters = -1


func _finish() -> void:
	if not playing:
		return
	playing = false
	typing = false
	visible = false
	done.emit()


func _process(delta: float) -> void:
	if not playing:
		return
	_blink += delta
	_next_mark.visible = not typing and fmod(_blink, 1.0) < 0.6
	if not typing:
		return
	_clock += delta
	var cps := float(Rules.get_value("story.typing.chars_per_second", 30))
	while typing and _clock >= _next_cost:
		_clock -= _next_cost
		var shown := _text.visible_characters + 1
		_text.visible_characters = shown
		if shown >= _plain.length():
			_complete_line()
			return
		_next_cost = 1.0 / cps + pause_after(_plain[shown - 1])


## 这个字显示出来以后要停多久（秒）。
static func pause_after(character: String) -> float:
	for rule: Dictionary in Rules.get_value("story.typing.pauses", []):
		if String(rule.get("chars", "")).contains(character):
			return float(rule.get("seconds", 0.0))
	return 0.0


## 台词原文转成 BBCode：方括号转义，全角括号里的动作换成灰色。
static func to_bbcode(plain: String, action_color: Color) -> String:
	var escaped := plain.replace("[", "[lb]")
	var re := RegEx.create_from_string("（[^（）]*）")
	return re.sub(escaped, "[color=#%s]$0[/color]" % action_color.to_html(false), true)


# ---------- 输入 ----------

func _gui_input(event: InputEvent) -> void:
	if not playing or not event is InputEventMouseButton or not event.pressed:
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			advance()
			accept_event()
		MOUSE_BUTTON_WHEEL_UP:
			open_backlog()
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not playing or not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_accept"):
		advance()
	elif event.is_action_pressed("ui_page_up"):
		open_backlog()
	elif event.is_action_pressed("ui_cancel") and is_backlog_open():
		_close_backlog()
	else:
		return
	get_viewport().set_input_as_handled()


# ---------- 回看 ----------

func is_backlog_open() -> bool:
	return _backlog != null and _backlog.visible


func open_backlog() -> void:
	if not playing or history.is_empty():
		return
	for child in _backlog_list.get_children():
		child.queue_free()
	var action := _color("action")
	for line: Dictionary in history:
		var entry := RichTextLabel.new()
		entry.bbcode_enabled = true
		entry.fit_content = true
		entry.scroll_active = false
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_theme_font_size_override("normal_font_size", _font_size())
		entry.add_theme_color_override("default_color", _color("text"))
		var body := to_bbcode(line.text, action)
		if line.speaker != "":
			body = tr("STORY_BACKLOG_LINE").format({
				"name": "[color=#%s]%s[/color]" % [_color("name").to_html(false), line.speaker.replace("[", "[lb]")],
				"text": body})
		entry.text = body
		_backlog_list.add_child(entry)
	_backlog.visible = true
	_backlog_button.visible = false
	await get_tree().process_frame
	_backlog_scroll.scroll_vertical = int(_backlog_scroll.get_v_scroll_bar().max_value)


func _close_backlog() -> void:
	_backlog.visible = false
	_backlog_button.visible = true


func _on_backlog_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_close_backlog()
		_backlog.accept_event()


# ---------- 画面 ----------

func _box(key: String, default: Variant) -> Variant:
	return Rules.get_value("story.box." + key, default)


func _color(key: String) -> Color:
	return Color.html(String(_box("colors." + key, "#ffffff")))


func _font_size() -> int:
	return int(_box("font_size", 12))


func _style(fill: Color) -> StyleBox:
	# 有对话框九宫格图（ART-001 §3.3）就用图，底色仍按 fill（回看半透明）。
	var frame := String(_box("frame", ""))
	if frame != "" and ResourceLoader.exists(frame):
		var tex := StyleBoxTexture.new()
		tex.texture = load(frame)
		tex.texture_margin_left = 4
		tex.texture_margin_top = 4
		tex.texture_margin_right = 4
		tex.texture_margin_bottom = 4
		tex.modulate_color = Color(1, 1, 1, fill.a)
		tex.set_content_margin_all(float(_box("padding", 8)))
		return tex
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = _color("border")
	style.set_border_width_all(1)
	style.set_content_margin_all(float(_box("padding", 8)))
	return style


func _build() -> void:
	if _panel != null:
		return
	var margin := float(_box("margin", 8))
	var height := float(_box("height", 92))

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _style(_color("panel")))
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = margin
	_panel.offset_right = -margin
	_panel.offset_top = -margin - height
	_panel.offset_bottom = -margin
	add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_box("padding", 8)))
	_panel.add_child(row)

	var size := float(Rules.get_value("story.portraits.size", 32)) * float(Rules.get_value("story.portraits.scale", 1))
	_portrait_slot = Control.new()
	_portrait_slot.custom_minimum_size = Vector2(size, size)
	_portrait_slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_portrait_slot)
	_portrait_block = ColorRect.new()
	_portrait_block.color = _color("portrait_placeholder")
	_portrait_block.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_slot.add_child(_portrait_block)
	_portrait_tex = TextureRect.new()
	_portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_slot.add_child(_portrait_tex)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	row.add_child(column)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", _font_size())
	_name_label.add_theme_color_override("font_color", _color("name"))
	column.add_child(_name_label)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_text.add_theme_font_size_override("normal_font_size", _font_size())
	_text.add_theme_constant_override("line_separation", int(_box("line_spacing", 4)))
	_text.add_theme_color_override("default_color", _color("text"))
	column.add_child(_text)

	_next_mark = Label.new()
	_next_mark.text = tr("STORY_NEXT_MARK")
	_next_mark.add_theme_font_size_override("font_size", _font_size())
	_next_mark.add_theme_color_override("font_color", _color("name"))
	_next_mark.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_next_mark.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_next_mark.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_next_mark.offset_right = -margin - 6
	_next_mark.offset_bottom = -margin - 2
	_next_mark.visible = false
	add_child(_next_mark)

	# 这些只用来显示：点击都交给对话框自己（_gui_input）。
	for node: Node in [_panel, row, _portrait_slot, _portrait_block, _portrait_tex, column, _name_label, _text, _next_mark]:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	_backlog_button = Button.new()
	_backlog_button.text = tr("STORY_BACKLOG")
	_backlog_button.focus_mode = Control.FOCUS_NONE
	_backlog_button.add_theme_font_size_override("font_size", _font_size())
	_backlog_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_backlog_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_backlog_button.offset_right = -margin
	_backlog_button.offset_top = margin
	_backlog_button.pressed.connect(open_backlog)
	add_child(_backlog_button)

	_build_backlog(margin)


func _build_backlog(margin: float) -> void:
	_backlog = PanelContainer.new()
	_backlog.add_theme_stylebox_override("panel", _style(_color("backlog")))
	_backlog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backlog.offset_left = margin
	_backlog.offset_top = margin
	_backlog.offset_right = -margin
	_backlog.offset_bottom = -margin
	_backlog.mouse_filter = Control.MOUSE_FILTER_STOP
	_backlog.gui_input.connect(_on_backlog_input)
	_backlog.visible = false
	add_child(_backlog)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	_backlog.add_child(column)

	_backlog_scroll = ScrollContainer.new()
	_backlog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_backlog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_backlog_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_backlog_scroll)

	_backlog_list = VBoxContainer.new()
	_backlog_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_backlog_list.add_theme_constant_override("separation", 6)
	_backlog_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_backlog_scroll.add_child(_backlog_list)

	var close := Button.new()
	close.text = tr("STORY_BACKLOG_CLOSE")
	close.focus_mode = Control.FOCUS_NONE
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.add_theme_font_size_override("font_size", _font_size())
	close.pressed.connect(_close_backlog)
	column.add_child(close)


func _show_portrait(portrait_id: String) -> void:
	_portrait_slot.visible = portrait_id != ""
	if portrait_id == "":
		return
	var path := "%s%s.png" % [Rules.get_value("story.portraits.dir", ""), portrait_id]
	if ResourceLoader.exists(path):
		_portrait_tex.texture = load(path)
		_portrait_block.visible = false
	else:
		# 还没有头像图：画同样大小的色块（CLAUDE.md 美术）。
		_portrait_tex.texture = null
		_portrait_block.visible = true
