class_name SettingsPanel
extends Control
## 设置画面（主菜单和暂停画面共用）：剧情模式、音量、全屏。
## 盖在当前画面上面，关掉时发 closed。暂停时也要能用，所以 process_mode 是 ALWAYS。
## 设置存在 user://settings.cfg（Game.settings）；剧情模式同时改当前存档（Game.set_story_mode）。

signal closed

var story_mode: CheckBox
var volume: HSlider
var volume_value: Label
var fullscreen: CheckBox
var back: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := build_frame(self, "UI_SETTINGS")

	story_mode = CheckBox.new()
	story_mode.text = Game.text("UI_STORY_MODE")
	story_mode.button_pressed = Game.current_story_mode()
	story_mode.toggled.connect(Game.set_story_mode)
	box.add_child(story_mode)
	box.add_child(note_label("UI_STORY_MODE_NOTE"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var volume_label := Label.new()
	volume_label.text = Game.text("UI_VOLUME")
	row.add_child(volume_label)
	volume = HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = float(Rules.get_value("core.settings.volume_step", 0.1))
	volume.value = float(Game.settings.volume)
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(volume)
	volume_value = Label.new()
	volume_value.custom_minimum_size = Vector2(36, 0)
	volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(volume_value)
	_show_volume(volume.value)
	volume.value_changed.connect(func(v: float) -> void:
		Game.set_setting("volume", v)
		_show_volume(v))

	fullscreen = CheckBox.new()
	fullscreen.text = Game.text("UI_FULLSCREEN")
	fullscreen.button_pressed = bool(Game.settings.fullscreen)
	fullscreen.toggled.connect(func(on: bool) -> void: Game.set_setting("fullscreen", on))
	box.add_child(fullscreen)

	back = add_button(box, "UI_BACK", close)
	story_mode.grab_focus.call_deferred()


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _show_volume(v: float) -> void:
	volume_value.text = Game.text("UI_VOLUME_VALUE").format({"value": roundi(v * 100.0)})


# ---------- 设置画面和暂停画面共用的框 ----------

static func _color(key: String) -> Color:
	return Color.html(String(Rules.get_value("core.settings.colors." + key, "#000000")))


## 半透明底 + 居中的框 + 标题，返回放内容的竖排容器。底挡住下面画面的点击。
static func build_frame(parent: Control, title_id: String) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = _color("dim")
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(dim)
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(holder)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = _color("panel")
	style.border_color = _color("border")
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(float(Rules.get_value("core.settings.panel_width", 360)), 0)
	holder.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = Game.text(title_id)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	return box


static func note_label(text_id: String) -> Label:
	var note := Label.new()
	note.text = Game.text(text_id)
	note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	note.add_theme_color_override("font_color", _color("note"))
	return note


static func add_button(parent: Node, text_id: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = Game.text(text_id)
	button.custom_minimum_size = Vector2(120, 24)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
