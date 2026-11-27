class_name WallMap
extends GridContainer
## 城防图（WORK，可复用）：三张地图各一列，每列 3 个墙位和 1 个门位，按钮上写类型和每格 HP。
## 用法：show_slots(wall_slots, marked) 刷新；点一个墙位发 slot_pressed(slot)。marked 里的墙位描黄边。
## 墙位 ID 和每张地图的顺序在 work.json 之外的公共规则 core.json（walls.slots / walls.gates）。

signal slot_pressed(slot: String)

var buttons: Dictionary = {}
## 紧凑：按钮小一些，两行字（劳作画面左边用）。
var compact := false


func _ready() -> void:
	columns = 3
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 4)


## layouts：砌石的砖槽（REDESIGN-002），有就在按钮上写填了几格。
func show_slots(wall_slots: Dictionary, marked: Array = [], disabled: Array = [], layouts: Dictionary = {}) -> void:
	for child in get_children():
		child.queue_free()
	buttons.clear()
	var slots: Array = Rules.get_value("core.walls.slots", [])
	var gates: Array = Rules.get_value("core.walls.gates", [])
	var maps := ["A", "B", "C"]
	for m: String in maps:
		var title := Label.new()
		title.text = Game.text("WORK_MAP_" + m)
		title.add_theme_font_size_override("font_size", _fs())
		title.add_theme_color_override("font_color", _color("title"))
		add_child(title)
	for row in 4:
		for m: String in maps:
			var slot: String = ("gate_" + m) if row == 3 else m + str(row + 1)
			if not (slot in slots or slot in gates):
				add_child(Control.new())
				continue
			var wall: Dictionary = wall_slots.get(slot, {"type": "none", "hp": []})
			var b := Button.new()
			b.text = _label(slot, wall)
			if compact:
				b.text = _compact_label(slot, wall, layouts.get(slot, {}))
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(62, 30) if compact else Vector2(96, 30)
			b.add_theme_font_size_override("font_size", _fs() - 1)
			var style := StyleBoxFlat.new()
			style.bg_color = _color(_type_color(slot, wall))
			style.set_content_margin_all(3)
			if slot in marked:
				style.border_color = _color("marked")
				style.set_border_width_all(2)
			b.add_theme_stylebox_override("normal", style)
			b.add_theme_stylebox_override("hover", style)
			b.add_theme_color_override("font_color", _color("text"))
			b.disabled = slot in disabled
			b.pressed.connect(func() -> void: slot_pressed.emit(slot))
			add_child(b)
			buttons[slot] = b


func _label(slot: String, wall: Dictionary) -> String:
	var type_key := "WORK_TYPE_" + ("gate_" if slot.begins_with("gate_") else "") + String(wall.type)
	var hp := "/".join(wall.hp.map(func(h: Variant) -> String: return str(h))) if wall.type != "none" else ""
	return Game.text("WORK_SLOT").format({"slot": Game.text("WORK_SLOT_" + slot), "type": Game.text(type_key), "hp": hp})


func _compact_label(slot: String, wall: Dictionary, layout: Dictionary) -> String:
	var type_key := "WORK_TYPE_" + ("gate_" if slot.begins_with("gate_") else "") + String(wall.type)
	var second := ""
	if wall.type != "none":
		second = "HP " + "/".join(wall.hp.map(func(h: Variant) -> String: return str(h)))
	if not layout.is_empty() and not StoneWall.is_built(layout) and StoneWall.filled(layout) > 0:
		second = Game.text("WORK_SLOT_PROGRESS").format({"filled": StoneWall.filled(layout),
			"need": int(Rules.get_value("work.puzzle.built_cells", 9))})
	return Game.text("WORK_SLOT_" + slot) + Game.text(type_key) + "\n" + second


## 墙位按钮的底色用 work.json view.map_colors 的哪一个。
func _type_color(slot: String, wall: Dictionary) -> String:
	if wall.type == "none":
		return "none"
	if wall.hp.any(func(h: Variant) -> bool: return int(h) <= 0):
		return "ruin"
	var full := FlowLogic.max_hp(slot, wall.type)
	if wall.hp.any(func(h: Variant) -> bool: return int(h) < full):
		return "fence" if wall.type == "fence" else "stone_damaged"
	return "fence" if wall.type == "fence" else "stone"


## 墙位画面的颜色（work.json 的 view.map_colors，DB16）。
func _color(key: String) -> Color:
	return Color.html(String(Rules.get_value("work.view.map_colors", {}).get(key, "#140c1c")))


func _fs() -> int:
	return int(Rules.get_value("story.box.font_size", 12))
