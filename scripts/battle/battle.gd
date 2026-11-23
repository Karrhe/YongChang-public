extends Control
## 战斗画面（BAT）：出战勾选 → 开场台词和教程提示 → 玩家回合（选人、移动、动作、结束回合）→ 结束台词 → 交回结果。
## 接口：setup(TEAM-001 §4 的战斗 input) → finished(result)。不写存档、不切场景；接受还是重打由 FLOW 问。
## 规则都在 BattleState（battle_state.gd）；这里只管显示和点击。

signal finished(result: Dictionary)

const DIALOGUE_BOX := preload("res://scenes/story/dialogue_box.tscn")
const BOARD_SCRIPT := preload("res://scripts/battle/battle_board.gd")

var input: Dictionary = {}
var state: BattleState
var selected: Dictionary = {}
## 正在选目标的动作（attack / repair / barrier / gate），空 = 没在选。
var mode := ""
var move_cells: Array = []
var target_cells: Array = []
var blink := false

var board: Control
var box: DialogueBox
var turn_label: Label
var villager_label: Label
var tide_bar: HBoxContainer
var unit_title: Label
var unit_stats: Label
var unit_note: Label
var action_grid: GridContainer
var end_button: Button
var info_label: Label
var deploy_panel: Control
var _queue: Array = []  # 等着播的台词（每项是整理好的台词列表）
var _finished := false
var _clock := 0.0


func setup(battle_input: Dictionary) -> void:
	input = battle_input


func _ready() -> void:
	state = BattleState.new()
	state.setup(input)
	_build()
	var options := state.deploy_options()
	if options.choices.size() > options.slots and options.slots > 0:
		_show_deploy(options)
	else:
		_begin(state.default_picks())


func _process(delta: float) -> void:
	_clock += delta
	var now := fmod(_clock, 0.8) < 0.5
	if now != blink:
		blink = now
		board.queue_redraw()


# ---------- 流程 ----------

func _begin(picks: Array) -> void:
	if deploy_panel != null:
		deploy_panel.queue_free()
		deploy_panel = null
	state.start(picks)
	state.events.clear()
	var keys: Dictionary = input.get("story_keys", {})
	_queue_scenes(keys.get("start", []))
	var hint_lines: Array[Dictionary] = []
	for key: String in Rules.get_value("battle.hints", {}).get(state.battle_id, []):
		if not key in state.seen_hints:
			state.seen_hints.append(key)
			hint_lines.append(_narration(Game.text(key)))
	if not hint_lines.is_empty():
		_queue.append(hint_lines)
	_play_queue()
	_refresh()


func _queue_scenes(ids: Array) -> void:
	var lines: Array[Dictionary] = []
	for id in ids:
		lines.append_array(StoryTable.main().lines(String(id)))
	if not lines.is_empty():
		_queue.append(lines)


func _play_queue() -> void:
	if box.playing:
		return
	if _queue.is_empty():
		if state.over and not _finished:
			_finished = true
			finished.emit(state.result())
		return
	var lines: Array[Dictionary] = _queue.pop_front()
	box.done.connect(_play_queue, CONNECT_ONE_SHOT)
	box.play_lines(lines)


func _narration(text: String) -> Dictionary:
	return {"scene_id": "", "line_id": "", "speaker": "", "portrait": "", "text": text, "narration": true}


## 规则那边发生的事：主角阵亡弹遗言，战斗结束弹结束台词，其他写进下面的信息栏。
func _take_events() -> void:
	var notes := PackedStringArray()
	var keys: Dictionary = input.get("story_keys", {})
	var counts := {}
	for ev: Dictionary in state.events:
		match ev.kind:
			"hero_death":
				_queue_scenes(keys.get("hero_death", []))
			"end":
				_queue_scenes(keys.get("end", []))
			"landing":
				counts["landing"] = int(counts.get("landing", 0)) + int(ev.count)
			"lantern", "reinforcements", "retire", "npc_down", "saved":
				counts[ev.kind] = int(counts.get(ev.kind, 0)) + 1
			"beacon":
				if ev.get("by", "") == "ally":
					counts["beacon"] = 1
	for kind: String in ["landing", "saved", "lantern", "reinforcements", "beacon", "retire", "npc_down"]:
		if counts.has(kind):
			notes.append(Game.text("BAT_EVENT_" + kind).format({"count": counts[kind]}))
	state.events.clear()
	if not notes.is_empty():
		info_label.text = " ".join(notes)
	_play_queue()


func _end_turn() -> void:
	if state.over or box.playing:
		return
	_deselect()
	state.end_turn()
	_take_events()
	_refresh()


# ---------- 点击 ----------

func _on_cell_clicked(cell: Vector2i, button: int) -> void:
	if state.over or box.playing or not state.started:
		return
	if button == MOUSE_BUTTON_RIGHT:
		if mode != "":
			_set_mode("")
		else:
			_deselect()
		return
	if mode != "":
		if cell in target_cells:
			state.do_action(selected, mode, cell)
			_after_action()
		else:
			_set_mode("")
		return
	var u := state.unit_at(cell)
	if not u.is_empty() and u.side == "ally" and u != selected:
		_select(u)
		return
	if not selected.is_empty() and state.can_command(selected) and not selected.moved and cell in move_cells and cell != selected.pos:
		state.move_unit(selected, cell)
		_refresh()
		return
	if not u.is_empty():
		_select(u)
	else:
		_deselect()


func _on_cell_hovered(cell: Vector2i) -> void:
	info_label.text = _describe(cell)


func _select(u: Dictionary) -> void:
	selected = u
	_set_mode("")


func _deselect() -> void:
	selected = {}
	_set_mode("")


func _set_mode(new_mode: String) -> void:
	mode = new_mode
	_refresh()


func _after_action() -> void:
	mode = ""
	_take_events()
	_refresh()


func _on_action(action: String) -> void:
	if action == "undo":
		state.undo_move(selected)
		_refresh()
	elif action in ["attack", "repair", "barrier", "gate"]:
		_set_mode(action)
	else:
		state.do_action(selected, action)
		_after_action()


# ---------- 显示 ----------

func _refresh() -> void:
	if state == null or not state.started:
		return
	turn_label.text = Game.text("BAT_TURN").format({"turn": state.turn, "turns": state.turns})
	if state.bcfg.get("night", false):
		turn_label.text += " · " + Game.text("BAT_NIGHT")
	var outside := state.villagers_outside().size()
	villager_label.text = Game.text("BAT_VILLAGERS").format({
		"saved": state.saved, "out": outside, "lost": state.lost, "goal": state.goal})
	if int(input.get("hungry", 0)) > 0:
		villager_label.text += " · " + Game.text("BAT_HUNGRY")
	_refresh_tide()
	move_cells.clear()
	target_cells.clear()
	if not selected.is_empty() and state.on_map(selected) and selected.side == "ally" and state.can_command(selected):
		if mode != "":
			target_cells = state.targets_for(selected, mode)
		elif not selected.moved:
			move_cells = state.move_range(selected).keys()
	_refresh_panel()
	end_button.disabled = state.over
	board.queue_redraw()


func _refresh_tide() -> void:
	for child in tide_bar.get_children():
		child.queue_free()
	var colors: Dictionary = Rules.get_value("battle.view.tide_colors", {})
	var storm: bool = state.bcfg.get("storm", false)
	for i in 4:
		var t: String = state.tide_at(state.turn + i)
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color.html(String(colors.get(t, "#000000")))
		if storm:
			style.border_color = Color.html(String(colors.get("storm", "#ff0000")))
			style.set_border_width_all(1)
		if i == 0:
			style.border_color = Color.html("#dad45e")
			style.set_border_width_all(2)
		style.set_content_margin_all(2)
		panel.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.text = Game.text("BAT_TIDE_" + t)
		label.add_theme_font_size_override("font_size", _fs())
		label.custom_minimum_size = Vector2(36, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(label)
		tide_bar.add_child(panel)
	if storm:
		var tag := Label.new()
		tag.text = Game.text("BAT_STORM")
		tag.add_theme_font_size_override("font_size", _fs())
		tag.add_theme_color_override("font_color", Color.html(String(colors.get("storm", "#ff0000"))))
		tide_bar.add_child(tag)


func _refresh_panel() -> void:
	for child in action_grid.get_children():
		child.queue_free()
	if selected.is_empty() or not state.on_map(selected):
		unit_title.text = ""
		unit_stats.text = ""
		unit_note.text = Game.text("BAT_SELECT_HINT")
		return
	var u := selected
	unit_title.text = unit_name(u)
	var range_text := Game.text("BAT_RANGE_NONE") if int(u.rmax) <= 0 else (
		str(u.rmax) if int(u.rmin) == int(u.rmax) else "%d–%d" % [u.rmin, u.rmax])
	unit_stats.text = Game.text("BAT_STATS").format({"hp": u.hp, "max": u.max_hp,
		"atk": int(u.atk) + int(u.buff_atk), "move": int(u.move) + int(u.buff_move), "range": range_text})
	unit_note.text = ""
	if u.side == "enemy":
		unit_note.text = _intent_text(u)
		return
	if u.side != "ally":
		return
	var threat := state.threat_to(int(u.uid))
	if threat > 0:
		unit_note.text = Game.text("BAT_DANGER").format({"damage": threat})
	if mode != "":
		unit_note.text = Game.text("BAT_PICK_TARGET")
	if not state.can_command(u):
		if unit_note.text == "":
			unit_note.text = Game.text("BAT_DONE")
		return
	var actions: Array = state.actions_for(u)
	if u.moved:
		actions.append("undo")
	for action: String in actions:
		var b := Button.new()
		b.text = Game.text("BAT_ACT_" + action)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", _fs())
		b.custom_minimum_size = Vector2(96, 20)
		b.pressed.connect(_on_action.bind(action))
		if action == mode:
			b.modulate = Color.html("#dad45e")
		action_grid.add_child(b)


func unit_name(u: Dictionary) -> String:
	if u.role in ["hero", "elder"] and not u.hero.is_empty():
		return FlowLogic.hero_name(Game.save, u.hero) + Game.text("BAT_ROLE_" + String(u.role))
	return Game.text("BAT_UNIT_" + String(u.type))


func glyph(u: Dictionary) -> String:
	if u.role in ["hero", "elder"] and not u.hero.is_empty():
		var n := FlowLogic.hero_name(Game.save, u.hero)
		return n.substr(n.length() - 1, 1) if n != "" else "?"
	return Game.text("BAT_GLYPH_" + String(u.type))


func _intent_text(e: Dictionary) -> String:
	for plan: Dictionary in state.intents:
		if int(plan.uid) != int(e.uid):
			continue
		if plan.hidden:
			return Game.text("BAT_INTENT_hidden")
		var t := state.unit_by_uid(int(plan.target_uid))
		var damage := 0
		if plan.act in ["attack", "shoot"] and not t.is_empty():
			damage = state.damage_to_unit(e, t)
		elif plan.act == "smash":
			damage = state.damage_to_structure(e)
		return Game.text("BAT_INTENT_" + String(plan.act)).format({
			"target": unit_name(t) if not t.is_empty() else "", "damage": damage})
	return ""


func _describe(cell: Vector2i) -> String:
	var parts := PackedStringArray([Game.text("BAT_TERRAIN_" + state.terrain_name(cell))])
	if state.structures.has(cell):
		var st: Dictionary = state.structures[cell]
		var type_key := "BAT_STRUCT_" + ("gate_" if st.kind == "gate" else "") + String(st.type)
		if int(st.hp) <= 0:
			type_key = "BAT_STRUCT_ruin"
		var text := Game.text("BAT_STRUCTURE").format({"type": Game.text(type_key), "hp": st.hp, "max": st.max})
		if st.kind == "gate" and int(st.hp) > 0:
			text += "，" + Game.text("BAT_GATE_OPEN" if st.open else "BAT_GATE_CLOSED")
		parts.append(text)
	if state.barriers.has(cell):
		parts.append(Game.text("BAT_BARRIER").format({"hp": state.barriers[cell]}))
	if state.beacons.has(cell):
		parts.append(Game.text("BAT_BEACON_LIT" if int(state.beacons[cell]) > 0 else "BAT_BEACON"))
	var u := state.unit_at(cell)
	if not u.is_empty():
		parts.append("%s HP %d/%d" % [unit_name(u), u.hp, u.max_hp])
		if u.side == "enemy":
			parts.append(_intent_text(u))
	return " · ".join(parts)


func _fs() -> int:
	return int(Rules.get_value("story.box.font_size", 12))


func _label(parent: Node, pos: Vector2, size: Vector2 = Vector2.ZERO) -> Label:
	var l := Label.new()
	l.position = pos
	if size != Vector2.ZERO:
		l.size = size
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", _fs())
	parent.add_child(l)
	return l


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color.html("#140c1c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var cell := int(Rules.get_value("battle.view.cell", 32))
	var origin: Array = Rules.get_value("battle.view.origin", [8, 44])
	turn_label = _label(self, Vector2(8, 4))
	tide_bar = HBoxContainer.new()
	tide_bar.position = Vector2(150, 2)
	tide_bar.add_theme_constant_override("separation", 2)
	add_child(tide_bar)
	villager_label = _label(self, Vector2(8, 24))

	board = Control.new()
	board.set_script(BOARD_SCRIPT)
	board.view = self
	board.cell = cell
	board.position = Vector2(origin[0], origin[1])
	board.size = Vector2(state.width * cell, state.height * cell)
	board.cell_clicked.connect(_on_cell_clicked)
	board.cell_hovered.connect(_on_cell_hovered)
	add_child(board)

	var px := float(origin[0]) + state.width * cell + 8
	var panel := VBoxContainer.new()
	panel.position = Vector2(px, origin[1])
	panel.size = Vector2(640 - px - 8, state.height * cell)
	panel.add_theme_constant_override("separation", 4)
	add_child(panel)
	unit_title = Label.new()
	unit_title.add_theme_font_size_override("font_size", _fs())
	unit_title.add_theme_color_override("font_color", Color.html("#dad45e"))
	panel.add_child(unit_title)
	unit_stats = Label.new()
	unit_stats.add_theme_font_size_override("font_size", _fs())
	panel.add_child(unit_stats)
	unit_note = Label.new()
	unit_note.add_theme_font_size_override("font_size", _fs())
	unit_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unit_note.custom_minimum_size = Vector2(panel.size.x, 0)
	panel.add_child(unit_note)
	action_grid = GridContainer.new()
	action_grid.columns = 2
	panel.add_child(action_grid)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(spacer)
	end_button = Button.new()
	end_button.text = Game.text("BAT_END_TURN")
	end_button.focus_mode = Control.FOCUS_NONE
	end_button.add_theme_font_size_override("font_size", _fs())
	end_button.pressed.connect(_end_turn)
	panel.add_child(end_button)

	var info_y := float(origin[1]) + state.height * cell + 4
	info_label = _label(self, Vector2(8, info_y), Vector2(624, 360 - info_y - 4))
	box = DIALOGUE_BOX.instantiate()
	add_child(box)


func _show_deploy(options: Dictionary) -> void:
	deploy_panel = CenterContainer.new()
	deploy_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(deploy_panel)
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html("#140c1c")
	style.border_color = Color.html("#8595a1")
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	frame.add_theme_stylebox_override("panel", style)
	frame.custom_minimum_size = Vector2(420, 0)
	deploy_panel.add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	frame.add_child(column)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", _fs())
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	column.add_child(grid)
	var picks: Array = state.default_picks()
	var ok := Button.new()
	var update := func() -> void:
		title.text = Game.text("BAT_DEPLOY_TITLE").format({"n": int(options.slots) - picks.size()})
		ok.disabled = picks.size() > int(options.slots)
	for c: Dictionary in options.choices:
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = c.key in picks
		b.add_theme_font_size_override("font_size", _fs())
		if c.kind == "elder":
			b.text = FlowLogic.hero_name(Game.save, input.elder) + Game.text("BAT_ROLE_elder")
		else:
			b.text = Game.text("BAT_UNIT_" + String(c.unit.type))
		b.toggled.connect(func(on: bool) -> void:
			if on and not c.key in picks:
				if picks.size() >= int(options.slots):
					b.set_pressed_no_signal(false)
					return
				picks.append(c.key)
			elif not on:
				picks.erase(c.key)
			update.call())
		grid.add_child(b)
	ok.text = Game.text("BAT_DEPLOY_OK")
	ok.add_theme_font_size_override("font_size", _fs())
	ok.pressed.connect(func() -> void: _begin(picks))
	column.add_child(ok)
	update.call()


# ---------- 测试用 ----------

## 自动打一步（测试用）：有勾选就按默认出战；台词在播就点一下；否则能打就打，然后结束回合。
func auto_play_for_test() -> void:
	if deploy_panel != null:
		_begin(state.default_picks())
		return
	if box.playing:
		box.advance()
		return
	if state.over:
		_play_queue()
		return
	for a in state.allies_on_map():
		if "attack" in state.actions_for(a):
			state.do_action(a, "attack", state.targets_for(a, "attack")[0])
	_take_events()
	_end_turn()
