extends Control
## 战斗地图（BAT）：画地形、墙、单位、高亮和海寇的意图；把点击和悬停交给战斗画面。
## 有美术图就画图（battle.json 的 view.sprites），没有图时画色块和一个字（CLAUDE.md 美术）。

signal cell_clicked(cell: Vector2i, button: int)
signal cell_hovered(cell: Vector2i)

var view: Node  # 战斗画面（battle.gd）
var cell := 32
var _hover := Vector2i(-1, -1)
var _tex_cache := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _v(key: String, default: Variant = null) -> Variant:
	return Rules.get_value("battle.view." + key, default)


func _c(key: String) -> Color:
	return Color.html(String(_v(key, "#ff00ff")))


func cell_at(local: Vector2) -> Vector2i:
	return Vector2i(int(local.x) / cell, int(local.y) / cell)


func _gui_input(event: InputEvent) -> void:
	var s: BattleState = view.state if view != null else null
	if s == null:
		return
	if event is InputEventMouseMotion:
		var c := cell_at(event.position)
		if c != _hover and s.in_bounds(c):
			_hover = c
			cell_hovered.emit(c)
	elif event is InputEventMouseButton and event.pressed:
		var c := cell_at(event.position)
		if s.in_bounds(c) and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			cell_clicked.emit(c, event.button_index)
			accept_event()


func _draw() -> void:
	var s: BattleState = view.state if view != null else null
	if s == null:
		return
	var font := ThemeDB.fallback_font
	var fs := int(Rules.get_value("story.box.font_size", 12))
	for y in s.height:
		for x in s.width:
			_draw_cell(s, Vector2i(x, y), font, fs)
	# 高亮：能走的格子、能选的目标、选中的单位。
	var move_mark := _tex("ui_dir", "move_mark")
	for p: Vector2i in view.move_cells:
		draw_rect(_rect(p), _c("highlight_move"))
		if move_mark != null:
			draw_texture_rect(move_mark, _rect(p), false)
	for p: Vector2i in view.target_cells:
		draw_rect(_rect(p).grow(-1), _c("highlight_target"), false, 2.0)
	# 单位。
	for u in s.units:
		if s.on_map(u):
			_draw_unit(s, u, font, fs)
	if not view.selected.is_empty() and s.on_map(view.selected):
		var cursor := _tex("ui_dir", "cursor")
		if cursor != null:
			draw_texture_rect(cursor, _rect(view.selected.pos), false)
		else:
			draw_rect(_rect(view.selected.pos).grow(-1), _c("highlight_select"), false, 2.0)
	_draw_intents(s, font, fs)
	# 斩击效果：被打到的格子上画 8×8 的斩击（放大 2 倍），两帧随闪烁切换。
	var slash := _tex("ui_dir", "slash_%d" % (1 if view.blink else 0))
	if slash != null:
		for p: Vector2i in s.hits:
			draw_texture_rect(slash, Rect2(_rect(p).position + Vector2(cell / 4, cell / 4), Vector2(cell / 2, cell / 2)), false)


func _rect(p: Vector2i) -> Rect2:
	return Rect2(Vector2(p.x * cell, p.y * cell), Vector2(cell, cell))


func _draw_cell(s: BattleState, p: Vector2i, font: Font, fs: int) -> void:
	var name := s.terrain_name(p)
	if name == "mud" and s.is_flooded(p):
		name = "mud_flooded"
	var tile := _tile_tex(s, name)
	if tile != null:
		draw_texture_rect(tile, _rect(p), false)
	else:
		draw_rect(_rect(p), Color.html(String(_v("terrain_colors", {}).get(name, "#000000"))))
	draw_rect(_rect(p), Color(0, 0, 0, 0.15), false, 1.0)
	if s.structures.has(p):
		var st: Dictionary = s.structures[p]
		var colors: Dictionary = _v("structure_colors", {})
		var r := _rect(p).grow(-3)
		var st_tex := _structure_tex(st)
		if st_tex != null:
			draw_texture_rect(st_tex, _rect(p), false)
		elif int(st.hp) <= 0:
			draw_rect(r, Color.html(String(colors.ruin)), false, 2.0)
			draw_line(r.position, r.end, Color.html(String(colors.ruin)), 2.0)
		elif st.kind == "gate" and st.open:
			draw_rect(r, Color.html(String(colors.gate_open)), false, 2.0)
		else:
			draw_rect(r, Color.html(String(colors[st.type])))
		if int(st.hp) > 0:
			draw_string(font, r.position + Vector2(1, fs), str(st.hp), HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2, _c("dark_text"))
	if s.barriers.has(p):
		var bar := _tex("tiles_dir", "barrier")
		if bar != null:
			draw_texture_rect(bar, _rect(p), false)
		else:
			draw_rect(_rect(p).grow(-6), Color.html(String(_v("structure_colors", {}).barrier)))
	if s.beacons.has(p):
		var lit := int(s.beacons[p]) > 0
		var frame := ("beacon_lit_%d" % (1 if view.blink else 0)) if lit else "beacon_unlit"
		var bt := _tex("tiles_dir", frame)
		if bt != null:
			# 烽火画在格子右上角，原大小（16×16），不挡住下面的敌台。
			draw_texture_rect(bt, Rect2(_rect(p).position + Vector2(cell / 2, 0), Vector2(cell / 2, cell / 2)), false)
		else:
			draw_circle(_rect(p).position + Vector2(cell - 7, 7), 4.0, Color.html("#d27d2c") if lit else Color.html("#757161"))


func _draw_unit(s: BattleState, u: Dictionary, font: Font, fs: int) -> void:
	var r := _rect(u.pos).grow(-5)
	var color := Color.html(String(_v("side_colors", {}).get(u.side, "#ffffff")))
	if u.side == "ally" and u.acted:
		color = color.darkened(0.45)
	if u.side == "ally" and s.threat_to(int(u.uid)) >= int(u.hp) and view.blink:
		color = _c("danger_color")
	var sprite := _unit_tex(u)
	if sprite != null:
		# 行动过的单位变暗；快被打死时闪红（和色块一样的含义）。
		var tint := Color.WHITE
		if u.side == "ally" and u.acted:
			tint = Color(0.55, 0.55, 0.55)
		if u.side == "ally" and s.threat_to(int(u.uid)) >= int(u.hp) and view.blink:
			tint = _c("danger_color").lightened(0.3)
		var size := Vector2(sprite.get_width(), sprite.get_height()) * (cell / 16.0)
		if size.x > cell:
			size = Vector2(sprite.get_width(), sprite.get_height())  # 弓箭船 32×16：按原大小画
		var at := _rect(u.pos).position + (Vector2(cell, cell) - size) / 2.0
		draw_texture_rect(sprite, Rect2(at, size), false, tint)
		if u.role in ["hero", "elder"]:
			draw_rect(_rect(u.pos).grow(-1), _c("highlight_select"), false, 1.0)
	else:
		draw_rect(r, color)
		if u.role in ["hero", "elder"]:
			draw_rect(r, _c("highlight_select"), false, 1.0)
		var glyph: String = view.glyph(u)
		var dark: bool = u.side == "villager"
		draw_string(font, r.position + Vector2(0, r.size.y / 2 + fs / 2 - 1), glyph, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs,
			_c("dark_text") if dark else _c("text_color"))
	# 血量：右下角的小字。
	draw_string(font, _rect(u.pos).position + Vector2(cell - 11, cell - 1), str(u.hp), HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 3,
		_c("text_color"))
	if int(u.carrying) != 0:
		draw_rect(Rect2(r.position + Vector2(-3, -3), Vector2(8, 8)), Color.html(String(_v("side_colors", {}).villager)))


func _draw_intents(s: BattleState, font: Font, fs: int) -> void:
	var color := _c("intent_color")
	for plan: Dictionary in s.intents:
		var e := s.unit_by_uid(int(plan.uid))
		if e.is_empty() or not s.on_map(e):
			continue
		var top := _rect(e.pos).position
		if plan.hidden:
			var unknown := _tex("ui_dir", "intent_unknown")
			if unknown != null:
				draw_texture_rect(unknown, Rect2(top + Vector2(cell / 2, 0), Vector2(cell / 2, cell / 2)), false)
			else:
				draw_string(font, top + Vector2(cell - 9, fs), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
			continue
		var points := PackedVector2Array([_center(e.pos)])
		for p: Vector2i in plan.path:
			points.append(_center(p))
		if points.size() > 1:
			draw_polyline(points, color, 2.0)
			draw_circle(points[-1], 3.0, color)
		if plan.act in ["grab", "attack", "shoot", "smash"] and plan.target != BattleState.NOWHERE:
			var mark := _tex("ui_dir", "target_mark")
			if mark != null:
				draw_texture_rect(mark, _rect(plan.target).grow(-6), false)
			else:
				var t := _rect(plan.target).grow(-9)
				draw_line(t.position, t.end, color, 2.0)
				draw_line(Vector2(t.end.x, t.position.y), Vector2(t.position.x, t.end.y), color, 2.0)


func _center(p: Vector2i) -> Vector2:
	return _rect(p).get_center()


# ---------- 美术图 ----------

func _tex(dir_key: String, file: String) -> Texture2D:
	var path := "%s%s.png" % [String(_v("sprites." + dir_key, "")), file]
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if file != "" and ResourceLoader.exists(path) else null
	return _tex_cache[path]


## “甲|乙”：pick_second 为真时用乙。
static func _pick(spec: String, pick_second: bool) -> String:
	var parts := spec.split("|")
	return parts[1] if pick_second and parts.size() > 1 else parts[0]


func _tile_tex(s: BattleState, terrain: String) -> Texture2D:
	var spec := String(_v("sprites.tiles", {}).get(terrain, ""))
	var file := _pick(spec, s.gen == 1).replace("{frame}", "1" if view.blink else "0")
	return _tex("tiles_dir", file)


func _structure_tex(st: Dictionary) -> Texture2D:
	var kind := String(st.type)  # fence | stone
	if int(st.hp) <= 0:
		return _tex("tiles_dir", ("fence" if kind == "fence" else "stone_wall") + "_ruin")
	if st.kind == "gate":
		return _tex("tiles_dir", "gate_%s_%s" % [kind, "open" if st.open else "closed"])
	var state := "intact" if int(st.hp) >= int(st.max) else "cracked"
	return _tex("tiles_dir", ("fence" if kind == "fence" else "stone_wall") + "_" + state)


func _unit_tex(u: Dictionary) -> Texture2D:
	if u.role == "elder":
		return _tex("units_dir", String(_v("sprites.units", {}).get("elder", "")))
	if not u.hero.is_empty():
		var list: Array = _v("sprites.heroes", {}).get(String(u.hero.role), [])
		var g := int(u.hero.gen) - 1
		return _tex("units_dir", String(list[g]) if g >= 0 and g < list.size() else "")
	var spec := String(_v("sprites.units", {}).get(String(u.type), ""))
	return _tex("units_dir", _pick(spec, int(u.uid) % 2 == 1))
