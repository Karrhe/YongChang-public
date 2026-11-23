extends Control
## 劳作画面（WORK）：两个季节。每季分配人手、点城防图排修建或修墙，结束这一季看报告；两季后交回结果。
## 接口：setup(TEAM-001 §4 的劳作 input) → finished(result)，result 和 input 字段相同，另加 goal_met。不写存档。
## 规则都在 WorkState（work_state.gd）；这里只管显示和点击。

signal finished(result: Dictionary)

const DIALOGUE_BOX := preload("res://scenes/story/dialogue_box.tscn")

var input: Dictionary = {}
var state: WorkState
var box: DialogueBox
var wall_map: WallMap
var goal_label: Label
var season_label: Label
var resource_label: Label
var jobs_box: VBoxContainer
var preview_label: Label
var hint_label: Label
var end_button: Button
var _finished := false


func setup(work_input: Dictionary) -> void:
	input = work_input


func _ready() -> void:
	state = WorkState.new()
	state.setup(input)
	_build()
	_refresh()


func _fs() -> int:
	return int(Rules.get_value("story.box.font_size", 12))


func _label(parent: Node, color: String = "#deeed6", wrap_width: float = 0.0) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", _fs())
	l.add_theme_color_override("font_color", Color.html(color))
	if wrap_width > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(wrap_width, 0)
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, callback: Callable, width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", _fs())
	if width > 0:
		b.custom_minimum_size = Vector2(width, 0)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color.html(String(Rules.get_value("story.backgrounds.gen_colors", {}).get(str(state.gen), "#140c1c"))).darkened(0.5)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.position = Vector2(8, 6)
	root.size = Vector2(624, 348)
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	goal_label = _label(root, "#dad45e", 624)
	season_label = _label(root)
	resource_label = _label(root)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	wall_map = WallMap.new()
	wall_map.slot_pressed.connect(_on_slot)
	row.add_child(wall_map)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	jobs_box = VBoxContainer.new()
	jobs_box.add_theme_constant_override("separation", 3)
	right.add_child(jobs_box)
	preview_label = _label(right, "#6dc2ca", 290)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	end_button = _button(right, Game.text("WORK_END_SEASON"), _end_season)
	hint_label = _label(root, "#8595a1", 624)
	hint_label.text = Game.text("WORK_HINT")
	box = DIALOGUE_BOX.instantiate()
	add_child(box)


func _refresh() -> void:
	var p := state.goal_progress()
	goal_label.text = Game.text(String(state.goal().get("text", ""))) + "  " + Game.text("WORK_PROGRESS").format(p) \
		+ ("  " + Game.text("WORK_GOAL_MET") if p.met else "")
	season_label.text = Game.text("WORK_SEASON").format({"season": state.season, "seasons": state.seasons(),
		"left": state.seasons_left_in_gen()})
	resource_label.text = Game.text("WORK_RESOURCES").format({"people": state.people, "rice": state.rice,
		"materials": state.materials, "idle": state.idle()}) \
		+ ("  " + Game.text("WORK_HUNGRY").format({"n": state.hungry}) if state.hungry > 0 else "")
	var disabled: Array = []
	for slot: String in state.wall_slots:
		if not state.can_build(slot) and state.repair_cost(slot) == 0:
			disabled.append(slot)
	wall_map.show_slots(state.wall_slots, state.build_queue, disabled)
	_refresh_jobs()
	var pv := state.preview()
	var text := Game.text("WORK_PREVIEW").format({"rice": pv.rice, "materials": pv.materials, "built": pv.built, "trained": pv.trained})
	if pv.granary:
		text += " " + Game.text("WORK_PREVIEW_GRANARY")
	elif int(pv.hungry) > 0:
		text += " " + Game.text("WORK_PREVIEW_HUNGRY").format({"n": pv.hungry})
	preview_label.text = text
	end_button.disabled = state.done or box.playing


func _refresh_jobs() -> void:
	for child in jobs_box.get_children():
		child.queue_free()
	var spec := state.build_spec()
	for job: String in WorkState.JOBS:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		jobs_box.add_child(line)
		var name := _label(line)
		name.text = Game.text("WORK_JOB_" + job)
		name.custom_minimum_size = Vector2(40, 0)
		_button(line, "−", func() -> void: _change(job, -1), 22)
		var count := _label(line)
		count.text = str(state.assign[job])
		count.custom_minimum_size = Vector2(18, 0)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_button(line, "+", func() -> void: _change(job, 1), 22)
		var note := _label(line, "#8595a1", 170)
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		note.text = Game.text("WORK_NOTE_" + job).format({"people": int(spec.people), "materials": int(spec.materials),
			"type": Game.text("WORK_TYPE_" + String(spec.type)), "capacity": state.build_capacity(), "queued": state.build_queue.size()})
	if not state.train_types.is_empty():
		var picks := HFlowContainer.new()
		picks.custom_minimum_size = Vector2(300, 0)
		jobs_box.add_child(picks)
		for i in state.train_types.size():
			_button(picks, Game.text("BAT_UNIT_" + String(state.train_types[i])) + " ▸", func() -> void:
				state.cycle_train_type(i)
				_refresh())


func _change(job: String, delta: int) -> void:
	state.set_job(job, int(state.assign[job]) + delta)
	_refresh()


func _on_slot(slot: String) -> void:
	if state.done or box.playing:
		return
	if slot in state.build_queue or state.can_build(slot):
		if not state.toggle_build(slot):
			hint_label.text = Game.text("WORK_CANNOT_BUILD").format({"people": int(state.build_spec().people),
				"materials": int(state.build_spec().materials)})
		else:
			hint_label.text = Game.text("WORK_HINT")
	elif state.repair_cost(slot) > 0:
		var cost := state.repair_cost(slot)
		if state.repair(slot):
			hint_label.text = Game.text("WORK_REPAIRED").format({"cost": cost})
		else:
			hint_label.text = Game.text("WORK_CANNOT_REPAIR").format({"cost": cost})
	_refresh()


func _end_season() -> void:
	if state.done or box.playing:
		return
	var report := state.end_season()
	var lines: Array[Dictionary] = []
	lines.append(_narration(Game.text("WORK_REPORT").format(report)))
	if report.granary:
		lines.append_array(StoryTable.main().lines(String(Rules.get_value("work.granary_scenes", {}).get(str(state.gen), ""))))
		lines.append(_narration(Game.text("CHOICE_GRANARY_SUMMARY")))
	elif int(report.hungry) > 0:
		lines.append(_narration(Game.text("WORK_REPORT_HUNGRY").format(report)))
	if state.done:
		var p := state.goal_progress()
		lines.append(_narration(Game.text("WORK_GOAL_MET_REPORT" if p.met else "WORK_GOAL_NOT_MET_REPORT")))
	box.done.connect(_after_report, CONNECT_ONE_SHOT)
	box.play_lines(lines)
	_refresh()


func _after_report() -> void:
	if state.done and not _finished:
		_finished = true
		finished.emit(state.result())
		return
	_refresh()


func _narration(text: String) -> Dictionary:
	return {"scene_id": "", "line_id": "", "speaker": "", "portrait": "", "text": text, "narration": true}


## 测试用：台词在播就点一下；否则所有空闲的人去种田，结束这一季。
func auto_play_for_test() -> void:
	if box.playing:
		box.advance()
		return
	if state.done:
		return
	state.set_job("farm", int(state.assign.farm) + state.idle())
	_end_season()
