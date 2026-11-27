extends Control
## 劳作画面（WORK，REDESIGN-002 方案一《石头要彼此咬住》）：两个季节。每季分人种田、训练，剩下的石匠砌石；
## 点城防图选墙位，点石料、在砖槽里放（右键转向）；门、修墙用按钮。结束这一季看报告；两季后交回结果。
## 接口：setup(TEAM-001 §4 的劳作 input) → finished(result)。不写存档。规则都在 WorkState / StoneWall；这里只管显示和点击。

signal finished(result: Dictionary)

const DIALOGUE_BOX := preload("res://scenes/story/dialogue_box.tscn")

var input: Dictionary = {}
var state: WorkState
var box: DialogueBox
var wall_map: WallMap
var grid: StoneGrid
var goal_label: Label
var season_label: Label
var resource_label: Label
var hammer_label: Label
var slot_label: Label
var rule_label: Label
var stones_box: HBoxContainer
var action_box: HFlowContainer
var jobs_box: VBoxContainer
var preview_label: Label
var hint_label: Label
var end_button: Button
var selected_slot := ""
var pick := 0
var rot := 0
var _finished := false


func setup(work_input: Dictionary) -> void:
	input = work_input


func _ready() -> void:
	state = WorkState.new()
	state.setup(input)
	_build()
	selected_slot = _first_slot()
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
	var bg_path := String(Rules.get_value("work.view.background", ""))
	if bg_path != "" and ResourceLoader.exists(bg_path):
		var art := TextureRect.new()
		art.texture = load(bg_path)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.modulate = Color.html(String(Rules.get_value("work.view.background_tint", "#404040")))
		add_child(art)
	var root := VBoxContainer.new()
	root.position = Vector2(8, 4)
	root.size = Vector2(624, 352)
	root.add_theme_constant_override("separation", 3)
	add_child(root)
	goal_label = _label(root, "#dad45e", 624)
	season_label = _label(root, "#6dc2ca")
	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 2)
	root.add_child(res_row)
	for icon_name: String in Rules.get_value("work.view.resource_icons", []):
		var path := "res://assets/art/ui/%s.png" % icon_name
		if ResourceLoader.exists(path):
			var icon := TextureRect.new()
			icon.texture = load(path)
			icon.custom_minimum_size = Vector2(16, 16)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			res_row.add_child(icon)
	resource_label = _label(res_row)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	# 左：城防图
	wall_map = WallMap.new()
	wall_map.compact = true
	wall_map.slot_pressed.connect(_on_slot)
	row.add_child(wall_map)
	# 中：锤柄上的字、砖槽、这段墙的情况
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 3)
	mid.custom_minimum_size = Vector2(150, 0)
	row.add_child(mid)
	hammer_label = _label(mid, "#d2aa99", 150)
	slot_label = _label(mid, "#dad45e", 150)
	grid = StoneGrid.new()
	grid.cell_clicked.connect(_on_grid_click)
	grid.cell_hovered.connect(func(_c: Vector2i) -> void: grid.queue_redraw())
	mid.add_child(grid)
	rule_label = _label(mid, "#8595a1", 150)
	# 右：石料、按钮、人手、季末
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 3)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	stones_box = HBoxContainer.new()
	stones_box.add_theme_constant_override("separation", 4)
	right.add_child(stones_box)
	action_box = HFlowContainer.new()
	action_box.add_theme_constant_override("h_separation", 3)
	right.add_child(action_box)
	jobs_box = VBoxContainer.new()
	jobs_box.add_theme_constant_override("separation", 2)
	right.add_child(jobs_box)
	preview_label = _label(right, "#6dc2ca", 200)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	end_button = _button(right, Game.text("WORK_END_SEASON"), _end_season)
	hint_label = _label(root, "#8595a1", 624)
	hint_label.text = Game.text("WORK_HINT")
	box = DIALOGUE_BOX.instantiate()
	add_child(box)


func _first_slot() -> String:
	for slot: String in Rules.get_value("core.walls.slots", []):
		if state.wall_slots.has(slot):
			return slot
	return ""


# ---------- 刷新 ----------

func _refresh() -> void:
	var p := state.goal_progress()
	goal_label.text = Game.text(String(state.goal().get("text", ""))) + "  " + Game.text("WORK_PROGRESS").format(p) \
		+ ("  " + Game.text("WORK_GOAL_MET") if p.met else "")
	var delivery := state.season_delivery()
	season_label.text = Game.text("WORK_SEASON").format({"season": state.season, "seasons": state.seasons(),
		"left": state.seasons_left_in_gen()}) + "  " + Game.text("WORK_DELIVERY").format({
		"tide": Game.text("BAT_TIDE_" + String(delivery.get("tide", "low"))), "pieces": state.delivered, "stone": _stone_word()})
	resource_label.text = Game.text("WORK_RESOURCES").format({"people": state.people, "rice": state.rice,
		"materials": state.materials, "stone": _stone_word(), "masons": state.masons(), "left": state.placements_left()}) \
		+ ("  " + Game.text("WORK_HUNGRY").format({"n": state.hungry}) if state.hungry > 0 else "")
	wall_map.show_slots(state.wall_slots, [selected_slot], [], state.wall_layouts)
	_refresh_slot()
	_refresh_stones()
	_refresh_actions()
	_refresh_jobs()
	var pv := state.preview()
	var text := Game.text("WORK_PREVIEW").format(pv)
	if pv.granary:
		text += " " + Game.text("WORK_PREVIEW_GRANARY")
	elif int(pv.hungry) > 0:
		text += " " + Game.text("WORK_PREVIEW_HUNGRY").format({"n": pv.hungry})
	preview_label.text = text
	end_button.disabled = state.done or box.playing


func _stone_word() -> String:
	return Game.text("WORK_STONE_%d" % state.gen)


func _refresh_slot() -> void:
	var hammer := Game.hammer_text() if state.gen >= 2 else ""
	hammer_label.text = Game.text("WORK_HAMMER").format({"hammer": hammer}) if hammer != "" else Game.text("WORK_FENCE_RULE")
	if selected_slot == "":
		slot_label.text = ""
		grid.layout = {}
		grid.queue_redraw()
		return
	var wall: Dictionary = state.wall_slots.get(selected_slot, {"type": "none", "hp": []})
	var title := Game.text("WORK_MAP_" + selected_slot.trim_prefix("gate_").substr(0, 1)) + " " + Game.text("WORK_SLOT_" + selected_slot)
	slot_label.text = title
	if selected_slot.begins_with("gate_"):
		grid.layout = {}
		grid.visible = false
		rule_label.text = Game.text("WORK_GATE_NOTE").format({"type": Game.text("WORK_TYPE_gate_" + String(wall.type)),
			"hp": "/".join(wall.hp.map(func(h: Variant) -> String: return str(h))), "cost": state.gate_cost()})
		return
	grid.visible = true
	var layout := state.layout(selected_slot)
	grid.layout = layout
	var shapes := state.window()
	grid.ghost_shape = String(shapes[pick]) if pick < shapes.size() and state.can_work(selected_slot) else ""
	grid.ghost_rot = rot
	grid.active = not state.done and not box.playing
	grid.queue_redraw()
	var cells := StoneWall.width() * StoneWall.height()
	var now := Game.text("WORK_WALL_NOW").format({"type": Game.text("WORK_TYPE_" + String(wall.type)),
		"hp": "/".join(wall.hp.map(func(h: Variant) -> String: return str(h)))})
	rule_label.text = now + "\n" + Game.text("WORK_LAYOUT_" + String(layout.kind)).format({
		"filled": StoneWall.filled(layout), "cells": cells, "need": int(Rules.get_value("work.puzzle.built_cells", 9)),
		"seams": StoneWall.red_seams(layout).size(), "gold": StoneWall.gold_joints(layout).size(),
		"hp": _hp_if_built(layout)})


## 这段墙按现在的样子筑成后每格多少 HP（没够格数时按补到筑成线算不出来，就显示“—”）。
func _hp_if_built(layout: Dictionary) -> String:
	var m := StoneWall.max_hp(layout)
	return str(m) if m > 0 else "—"


func _refresh_stones() -> void:
	for child in stones_box.get_children():
		child.queue_free()
	var shapes := state.window()
	if pick >= shapes.size():
		pick = 0
	var caption := _label(stones_box, "#8595a1")
	caption.text = Game.text("WORK_WINDOW")
	for i in shapes.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(44, 44)
		b.tooltip_text = Game.text("WORK_PIECE_" + String(shapes[i]))
		var icon := Control.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var shape := String(shapes[i])
		var selected := i == pick
		var r := rot if selected else 0
		icon.draw.connect(func() -> void: StoneGrid.draw_shape(icon, shape, r, Vector2(6, 6), 9.0, selected))
		b.add_child(icon)
		b.pressed.connect(func() -> void:
			if pick == i:
				_rotate()
			else:
				pick = i
				rot = 0
			_refresh())
		stones_box.add_child(b)
	if shapes.is_empty():
		_label(stones_box, "#d04648").text = Game.text("WORK_NO_STONE").format({"stone": _stone_word()})


func _refresh_actions() -> void:
	for child in action_box.get_children():
		child.queue_free()
	var shapes := state.window()
	if pick < shapes.size() and StoneWall.can_rotate(String(shapes[pick])):
		_button(action_box, Game.text("WORK_ROTATE"), func() -> void:
			_rotate()
			_refresh())
	if state.can_chisel(pick):
		_button(action_box, Game.text("WORK_CHISEL"), func() -> void:
			if state.chisel(pick):
				rot = 0
				Game.play_sfx("repair")
			_refresh())
	if selected_slot.begins_with("gate_"):
		var g := _button(action_box, Game.text("WORK_BUILD_GATE").format({"cost": state.gate_cost(),
			"type": Game.text("WORK_TYPE_gate_" + state.wall_kind())}), func() -> void:
			if state.build_gate(selected_slot):
				Game.play_sfx("repair")
				hint_label.text = Game.text("WORK_GATE_BUILT")
			_refresh())
		g.disabled = not state.can_build_gate(selected_slot)
	var cost := state.repair_cost(selected_slot) if selected_slot != "" else 0
	if cost > 0:
		var b := _button(action_box, Game.text("WORK_REPAIR").format({"cost": cost}), func() -> void:
			if state.repair(selected_slot):
				Game.play_sfx("repair")
				hint_label.text = Game.text("WORK_REPAIRED").format({"cost": cost})
			_refresh())
		b.disabled = cost > state.materials


func _refresh_jobs() -> void:
	for child in jobs_box.get_children():
		child.queue_free()
	for job: String in WorkState.JOBS:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 3)
		jobs_box.add_child(line)
		var name := _label(line)
		name.text = Game.text("WORK_JOB_" + job)
		name.custom_minimum_size = Vector2(30, 0)
		_button(line, "−", func() -> void: _change(job, -1), 20)
		var count := _label(line)
		count.text = str(state.assign[job])
		count.custom_minimum_size = Vector2(16, 0)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_button(line, "+", func() -> void: _change(job, 1), 20)
		var note := _label(line, "#8595a1")
		note.text = Game.text("WORK_NOTE_" + job).format({"rice": int(Rules.get_value("work.jobs.farm.rice", 3))})
	var masons := _label(jobs_box, "#8595a1", 200)
	masons.text = Game.text("WORK_MASONS").format({"masons": state.masons(), "left": state.placements_left(),
		"per": int(Rules.get_value("work.puzzle.placements_per_mason", 3))})
	if not state.train_types.is_empty():
		var picks := HFlowContainer.new()
		picks.custom_minimum_size = Vector2(200, 0)
		jobs_box.add_child(picks)
		for i in state.train_types.size():
			_button(picks, Game.text("BAT_UNIT_" + String(state.train_types[i])) + " ▸", func() -> void:
				state.cycle_train_type(i)
				_refresh())


# ---------- 操作 ----------

func _rotate() -> void:
	rot = (rot + 1) % 4


func _change(job: String, delta: int) -> void:
	state.set_job(job, int(state.assign[job]) + delta)
	_refresh()


func _on_slot(slot: String) -> void:
	if box.playing:
		return
	selected_slot = slot
	hint_label.text = Game.text("WORK_HINT")
	_refresh()


func _on_grid_click(cell: Vector2i, button: int) -> void:
	if state.done or box.playing:
		return
	if button == MOUSE_BUTTON_RIGHT:
		_rotate()
		_refresh()
		return
	if button != MOUSE_BUTTON_LEFT or cell == Vector2i(-1, -1):
		return
	if not state.can_work(selected_slot):
		hint_label.text = Game.text("WORK_NO_MASON" if state.placements_left() <= 0 else "WORK_NO_STONE").format({"stone": _stone_word()})
		return
	var was_built := StoneWall.is_built(state.layout(selected_slot))
	if state.place(selected_slot, pick, rot, cell):
		Game.play_sfx("repair")
		var layout := state.layout(selected_slot)
		if not was_built and StoneWall.is_built(layout):
			hint_label.text = Game.text("WORK_WALL_BUILT").format({"hp": StoneWall.max_hp(layout)})
		else:
			hint_label.text = Game.text("WORK_HINT")
		rot = 0
	else:
		hint_label.text = Game.text("WORK_CANNOT_PLACE")
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
	pick = 0
	rot = 0
	_refresh()


func _after_report() -> void:
	if state.done and not _finished:
		_finished = true
		finished.emit(state.result())
		return
	_refresh()


func _narration(text: String) -> Dictionary:
	return {"scene_id": "", "line_id": "", "speaker": "", "portrait": "", "text": text, "narration": true}


## 测试用：台词在播就点一下；否则够吃的人去种田、剩下的人砌石（StoneBot 的简单放法），结束这一季。
func auto_play_for_test() -> void:
	if box.playing:
		box.advance()
		return
	if state.done:
		return
	WorkBot.play_season(state)
	_end_season()
