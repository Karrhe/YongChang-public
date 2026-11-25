class_name EndingScreen
extends Control
## 结局（END）：E1 → E2 → E3 放灯 → E3.5 → E4 三代墓志 → E5 祠堂记录 → E6 → 最后一句。
## 顺序、放灯分组和文字键都在 ending.json（CLAUDE.md：结局从列表读取）。
## 接口：setup({"save": SaveData 的只读副本}) → finished({})（TEAM-001 §4）。不写存档。
## 对话用 FLOW-2 的对话框（剧情表 E1_A、E1_B、E2、E3_5、E6）；墓志、记录和最后一句是整屏的牌子，
## 点一下（或按空格、回车）继续。

signal finished(result: Dictionary)
signal _continued

const DIALOGUE_BOX := preload("res://scenes/story/dialogue_box.tscn")

var input: Dictionary = {}
var save: SaveData
var box: DialogueBox
var background: ColorRect
var background_art: TextureRect
## 灯、牌子、龙灯放在这一层，每一步开始时清空。
var layer: Control
## 现在是 steps 里的第几步。
var step_index := -1
## 牌子显示着，等玩家点一下。
var waiting := false
var done := false


func setup(ending_input: Dictionary) -> void:
	input = ending_input
	save = ending_input.get("save")


func _ready() -> void:
	if save == null:
		save = Game.save
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	background = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background_art = TextureRect.new()
	background_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_art)
	layer = Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	box = DIALOGUE_BOX.instantiate()
	add_child(box)
	_run()


func _run() -> void:
	var steps: Array = _cfg("steps", [])
	for i in steps.size():
		step_index = i
		var step: Dictionary = steps[i]
		background.color = _color(step.get("bg", "night"))
		_show_bg_art(String(step.get("bg", "night")))
		for child in layer.get_children():
			child.queue_free()
		match step.type:
			"dialogue":
				if step.get("door_lantern", false):
					_add_door_lantern()
				await _play(StoryTable.main().lines(scene_for(step, save), save))
			"lanterns":
				await _release_lanterns()
			"epitaphs":
				await _plaque(_t(_cfg("epitaphs", {}).get("title", ""), save), epitaph_texts(save))
			"records":
				await _plaque(_t(_cfg("records", {}).get("title", ""), save), record_texts(save))
			"final":
				await _final()
	done = true
	finished.emit({})


## 点一下：对话在播就交给对话框；牌子显示着就继续。
func advance() -> void:
	if box.playing:
		box.advance()
	elif waiting:
		waiting = false
		_continued.emit()


func _gui_input(event: InputEvent) -> void:
	if waiting and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if waiting and event.is_action_pressed("ui_accept"):
		advance()
		get_viewport().set_input_as_handled()


# ---------- 内容（静态，方便测试） ----------

static func _cfg(key: String, default: Variant) -> Variant:
	return Rules.get_value("ending." + key, default)


## 取 ending.csv 的文字：先按 args 填空，再换名字。表里没有时显示 [待写: 键]。
static func _t(key: String, from: SaveData, args: Dictionary = {}) -> String:
	var value := String(TranslationServer.translate(key))
	if value == key:
		return Game.missing(key)
	return Game.fill_names(value.format(args), from)


static func _has(key: String) -> bool:
	return String(TranslationServer.translate(key)) != key


## 对话这一步播哪个场景：E1 按第三代主角是否存活分 A/B。
static func scene_for(step: Dictionary, from: SaveData) -> String:
	if step.has("scene_alive"):
		return step.scene_alive if from.hero_alive[int(step.get("gen", 3)) - 1] else step.scene_dead
	return step.get("scene", "")


## 放灯的分组（跳过没有灯的组）：[{"group", "color", "text", "names"}]。
static func lantern_plan(from: SaveData) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var separator := String(TranslationServer.translate("END_NAME_SEPARATOR"))
	for group_cfg: Dictionary in _cfg("lantern_groups", []):
		var group: String = group_cfg.group
		var entries: Array = from.get("lanterns_" + group)
		if entries.is_empty():
			continue
		var names := PackedStringArray()
		for entry: Dictionary in entries:
			names.append(Game.fill_names(String(entry.get("name", "")), from))
		plan.append({
			"group": group,
			"color": group_cfg.get("color", "#ffffff"),
			"text": _t(group_cfg.get("text", ""), from, {"names": separator.join(names)}),
			"names": names,
		})
	return plan


## E4 三代墓志：活着用 alive，阵亡用 dead，{death} 换成按死亡场次的替换句。
static func epitaph_texts(from: SaveData) -> PackedStringArray:
	var out := PackedStringArray()
	for entry: Dictionary in _cfg("epitaphs", {}).get("list", []):
		var gen := int(entry.gen)
		if from.hero_alive[gen - 1]:
			out.append(_t(entry.alive, from))
			continue
		var death_key: String = entry.get("death", "")
		var specific := "%s_%s" % [death_key, from.death_battle[gen - 1]]
		var death := ""
		if _has(specific):
			death = _t(specific, from)
		elif _has(death_key):
			death = _t(death_key, from)
		out.append(_t(entry.dead, from, {"death": death}))
	return out


## E5 祠堂记录：做过的选择各一句。
static func record_texts(from: SaveData) -> PackedStringArray:
	var cfg: Dictionary = _cfg("records", {})
	var out := PackedStringArray()
	for choice: String in cfg.get("choices", []):
		if from.choices.has(choice):
			out.append(_t(String(cfg.get("key", "")).format({"choice": choice, "pick": from.choices[choice]}), from))
	return out


static func _narration(text: String) -> Dictionary:
	return {"scene_id": "", "line_id": "", "speaker": "", "portrait": "", "text": text, "narration": true}


# ---------- 各步 ----------

func _play(lines: Array[Dictionary]) -> void:
	box.play_lines(lines)
	await box.done


func _release_lanterns() -> void:
	var plan := lantern_plan(save)
	if plan.is_empty():
		await _play([_narration(_t(_cfg("no_lantern_text", ""), save))])
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_cfg("lantern.seed", 0))
	for group: Dictionary in plan:
		for i in group.names.size():
			_launch_lantern(group, group.names[i], i, rng)
		await _play([_narration(group.text)])


func _launch_lantern(group: Dictionary, lantern_name: String, order: int, rng: RandomNumberGenerator) -> void:
	if order == 0:
		Game.play_sfx("lantern")  # 每组第一盏灯放下水时响一下
	var lantern := _lantern(group.group, Color.html(String(group.color)))
	var label := Label.new()
	label.text = lantern_name
	label.add_theme_font_size_override("font_size", _font_size())
	label.add_theme_color_override("font_color", _color("text"))
	label.position = Vector2(-8, lantern.size.y + 1)
	lantern.add_child(label)
	var river_top := float(get_viewport_rect().size.y) - float(Rules.get_value("story.box.height", 92)) - 40.0
	lantern.position = Vector2(rng.randf_range(16, 600), river_top)
	layer.add_child(lantern)
	var target := Vector2(lantern.position.x + rng.randf_range(-24, 24), rng.randf_range(24, river_top - 48))
	var seconds := float(_cfg("lantern.rise_seconds", 8.0)) * rng.randf_range(0.8, 1.2)
	var tween := lantern.create_tween()
	tween.tween_interval(order * 0.3)
	tween.tween_property(lantern, "position", target, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## 一盏灯：有图用图，没有图画同样大小的色块（CLAUDE.md 美术）。
## 步骤背景有图（ending.json 的 bg_art）就铺图并调色，否则只留纯色。
func _show_bg_art(bg: String) -> void:
	var art_cfg: Dictionary = _cfg("bg_art", {}).get(bg, {})
	var path := String(art_cfg.get("art", ""))
	if path != "" and ResourceLoader.exists(path):
		background_art.texture = load(path)
		background_art.modulate = Color.html(String(art_cfg.get("tint", "#ffffff")))
		background_art.visible = true
	else:
		background_art.visible = false


func _lantern(group: String, color: Color) -> Control:
	var side := float(_cfg("lantern.size", 8)) * float(_cfg("lantern.scale", 2))
	var path := String(_cfg("lantern.art", "")).replace("{group}", group)
	var lantern: Control
	if ResourceLoader.exists(path):
		var tex := TextureRect.new()
		tex.texture = load(path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lantern = tex
	else:
		var block := ColorRect.new()
		block.color = color
		lantern = block
	lantern.size = Vector2(side, side)
	lantern.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lantern


func _add_door_lantern() -> void:
	var door := ColorRect.new()
	door.color = _color("plaque")
	door.size = Vector2(48, 80)
	door.position = Vector2(96, 120)
	door.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(door)
	var lantern := _lantern("door", Color.html(String(_cfg("lantern.door_color", "#dad45e"))))
	lantern.position = Vector2(148, 132)
	layer.add_child(lantern)


## 整屏的牌子：标题加几段文字，点一下继续。
func _plaque(title: String, texts: PackedStringArray) -> void:
	var column := _center_panel(Vector2(520, 0))
	var heading := _label(title, _color("title"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	for text in texts:
		column.add_child(_label(text, _color("text")))
	column.add_child(_next_mark())
	await _wait_click()


func _final() -> void:
	var column := _center_panel(Vector2(0, 0), false)
	var dragon_cfg: Dictionary = _cfg("dragon", {})
	var dragon_size := Vector2(dragon_cfg.get("size", [320, 96])[0], dragon_cfg.get("size", [320, 96])[1])
	var art := String(dragon_cfg.get("art", ""))
	if ResourceLoader.exists(art):
		var tex := TextureRect.new()
		tex.texture = load(art)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = dragon_size
		column.add_child(tex)
	else:
		# 还没有插图：五色色块，上面写“天下太平”。
		var holder := Control.new()
		holder.custom_minimum_size = dragon_size
		var strip := HBoxContainer.new()
		strip.add_theme_constant_override("separation", 0)
		strip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(strip)
		for hex: String in dragon_cfg.get("colors", []):
			var block := ColorRect.new()
			block.color = Color.html(hex)
			block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			strip.add_child(block)
		var words := _label(_t(dragon_cfg.get("text", ""), save), _color("night"), false)
		words.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		words.add_theme_font_size_override("font_size", _font_size() * 2)
		holder.add_child(words)
		column.add_child(holder)
	var last := _label(_t(_cfg("final_text", ""), save), _color("title"), false)
	last.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	last.add_theme_font_size_override("font_size", _font_size() * 2)
	column.add_child(last)
	column.add_child(_next_mark())
	await _wait_click()


func _wait_click() -> void:
	waiting = true
	await _continued


# ---------- 画面 ----------

func _font_size() -> int:
	return int(Rules.get_value("story.box.font_size", 12))


static func _color(key: String) -> Color:
	return Color.html(String(_cfg("colors." + key, "#000000")))


func _center_panel(min_size: Vector2, framed: bool = true) -> VBoxContainer:
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if framed:
		# 宗祠牌位：文字加一个简单的框（ART-001 §3.5）。
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = _color("plaque")
		style.border_color = _color("plaque_border")
		style.set_border_width_all(2)
		style.set_content_margin_all(16)
		panel.add_theme_stylebox_override("panel", style)
		panel.custom_minimum_size = min_size
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(panel)
		panel.add_child(column)
	else:
		holder.add_child(column)
	return column


func _label(text: String, color: Color, wrap: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", _font_size())
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _next_mark() -> Label:
	var mark := _label(tr("STORY_NEXT_MARK"), _color("title"), false)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return mark
