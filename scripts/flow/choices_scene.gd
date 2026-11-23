extends Control
## 剧情选择画面（FLOW-3）：先播选择前的对话，再给两个选项（按钮下写效果；不能选时写原因）；
## 选完播选的人说的那句、结果句（C3-A）、开义仓的话；要选墙位时（C2-A 筑 1 段、C4-A 拆 3 段）
## 再从列表里选（城防图交付前的简单做法，TEAM-001 FLOW-3）。
## 接口：setup(FlowLogic.choice_input(...)) → finished({"pick": "A" | "B", "slots": [墙位 ID]})。不写存档。
## 选项文字在剧情表：选择前对话那一场的 optA / optB 行是按钮上的字，optA_say / optB_say 是选了之后说的那句。

signal finished(result: Dictionary)

const DIALOGUE_BOX := preload("res://scenes/story/dialogue_box.tscn")

var input: Dictionary = {}
var box: DialogueBox
var pick := ""
var picked_slots: Array = []
var options_panel: Control
var option_buttons: Dictionary = {}
var slot_panel: Control
var slot_buttons: Dictionary = {}
var slot_label: Label
var slot_ok: Button


func setup(choice_input: Dictionary) -> void:
	input = choice_input


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color.html(String(Rules.get_value("story.backgrounds.gen_colors", {}).get(str(input.get("gen", 0)), "#000000")))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	box = DIALOGUE_BOX.instantiate()
	add_child(box)
	box.done.connect(_show_options, CONNECT_ONE_SHOT)
	box.play_lines(StoryTable.main().lines(input.get("key", "")))


# ---------- 选项 ----------

func _show_options() -> void:
	var table := StoryTable.main()
	var key: String = input.get("key", "")
	var column := _panel(Vector2(440, 0))
	options_panel = column.get_meta("holder")
	for p: String in Choices.PICKS:
		var option: Dictionary = input.options[p]
		var label_line := table.find_line(key, "opt" + p)
		var button := Button.new()
		button.text = label_line.text if not label_line.is_empty() else Game.missing("%s opt%s" % [key, p])
		button.disabled = not option.enabled
		button.add_theme_font_size_override("font_size", _font_size())
		button.pressed.connect(_on_pick.bind(p))
		column.add_child(button)
		option_buttons[p] = button
		var notes := PackedStringArray([Game.text("CHOICE_EFFECT_%s_%s" % [input.choice_id, p])])
		if not option.enabled:
			notes.append(Game.text(option.reason).format(option.get("reason_args", {})))
		elif option.granary:
			notes.append(Game.text("CHOICE_USES_GRANARY"))
		column.add_child(_note("\n".join(notes), not option.enabled))


func _on_pick(p: String) -> void:
	pick = p
	options_panel.queue_free()
	var table := StoryTable.main()
	var option: Dictionary = input.options[p]
	var lines: Array[Dictionary] = []
	var say := table.find_line(input.get("key", ""), "opt%s_say" % p)
	if not say.is_empty():
		lines.append(say)
	for id: String in option.get("after", []):
		lines.append_array(table.lines(id))
	if option.granary:
		lines.append_array(table.lines(input.get("granary_scene", "")))
		lines.append({"scene_id": "", "line_id": "", "speaker": "", "portrait": "",
			"text": Game.text("CHOICE_GRANARY_SUMMARY"), "narration": true})
	box.done.connect(_after_lines, CONNECT_ONE_SHOT)
	box.play_lines(lines)


func _after_lines() -> void:
	var slot_pick: Dictionary = input.options[pick].get("slot_pick", {})
	if int(slot_pick.get("count", 0)) > 0:
		_show_slot_pick(slot_pick)
	else:
		_finish()


func _finish() -> void:
	finished.emit({"pick": pick, "slots": picked_slots.duplicate()})


# ---------- 选墙位（城防图交付前的列表） ----------

func _show_slot_pick(slot_pick: Dictionary) -> void:
	var column := _panel(Vector2(440, 0))
	slot_panel = column.get_meta("holder")
	slot_label = Label.new()
	slot_label.add_theme_font_size_override("font_size", _font_size())
	column.add_child(slot_label)
	var grid := GridContainer.new()
	grid.columns = 3
	column.add_child(grid)
	var walls: Dictionary = input.get("wall_slots", {})
	for slot: String in slot_pick.get("slots", []):
		var wall: Dictionary = walls.get(slot, {"type": "none", "hp": []})
		var button := Button.new()
		button.toggle_mode = true
		button.text = Game.text("CHOICE_SLOT_ITEM").format({
			"slot": slot, "type": Game.text("WALL_TYPE_" + String(wall.type)),
			"hp": "/".join(wall.hp.map(func(v: Variant) -> String: return str(v)))})
		button.add_theme_font_size_override("font_size", _font_size())
		# 选中的墙位描黄边、黄字，和没选的分得清。
		var chosen := StyleBoxFlat.new()
		chosen.bg_color = _color("panel")
		chosen.border_color = _color("name")
		chosen.set_border_width_all(1)
		chosen.set_content_margin_all(4)
		button.add_theme_stylebox_override("pressed", chosen)
		button.add_theme_color_override("font_pressed_color", _color("name"))
		button.toggled.connect(_on_slot_toggled.bind(slot, slot_pick))
		grid.add_child(button)
		slot_buttons[slot] = button
	slot_ok = Button.new()
	slot_ok.text = Game.text("CHOICE_PICK_OK")
	slot_ok.add_theme_font_size_override("font_size", _font_size())
	slot_ok.pressed.connect(_finish)
	column.add_child(slot_ok)
	_update_slot_pick(slot_pick)


func _on_slot_toggled(on: bool, slot: String, slot_pick: Dictionary) -> void:
	if on and picked_slots.size() >= int(slot_pick.count):
		slot_buttons[slot].set_pressed_no_signal(false)  # 已经选够了
		return
	if on:
		picked_slots.append(slot)
	else:
		picked_slots.erase(slot)
	_update_slot_pick(slot_pick)


func _update_slot_pick(slot_pick: Dictionary) -> void:
	var key := "CHOICE_PICK_BUILD" if slot_pick.kind == "build" else "CHOICE_PICK_DEMOLISH"
	slot_label.text = Game.text(key).format({"count": slot_pick.count, "n": picked_slots.size()})
	slot_ok.disabled = picked_slots.size() != int(slot_pick.count)


# ---------- 画面 ----------

func _font_size() -> int:
	return int(Rules.get_value("story.box.font_size", 12))


func _color(key: String) -> Color:
	return Color.html(String(Rules.get_value("story.box.colors." + key, "#ffffff")))


## 对话框上方居中的一块面板，返回里面的竖排容器。
func _panel(min_size: Vector2) -> VBoxContainer:
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.offset_bottom = -float(Rules.get_value("story.box.height", 92))
	add_child(holder)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = _color("panel")
	style.border_color = _color("border")
	style.set_border_width_all(1)
	style.set_content_margin_all(float(Rules.get_value("story.box.padding", 8)))
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = min_size
	holder.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	column.set_meta("holder", holder)  # 删面板时连外面的居中容器一起删
	return column


func _note(text: String, warn: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", _font_size())
	label.add_theme_color_override("font_color", _color("warn" if warn else "action"))
	return label
