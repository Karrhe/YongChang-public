class_name StoneGrid
extends Control
## 砖槽画面（REDESIGN-002 方案一）：画石块、金边（咬住）、红缝（通缝）和要放的石头的影子。
## 用法：设 layout、ghost_shape / ghost_rot，调 queue_redraw()；点格子发 cell_clicked(cell, button)，鼠标移动发 cell_hovered(cell)。
## 格子 y = 0 是底行，画的时候底行在下。颜色取自 Dawnbringer 16（ART-001）。

signal cell_clicked(cell: Vector2i, button: int)
signal cell_hovered(cell: Vector2i)

const COLORS := {
	"slot": Color("#140c1c"), "grid": Color("#4e4a4e"),
	"stake3": Color("#854c30"), "wedge": Color("#8595a1"), "bar2": Color("#757161"), "bar3": Color("#8595a1"),
	"L3": Color("#6d6d6d"), "sq": Color("#757161"),
	"edge": Color("#140c1c"), "gold": Color("#dad45e"), "red": Color("#d04648"),
	"ghost_ok": Color("#6daa2c99"), "ghost_bad": Color("#d0464899"),
}

var layout: Dictionary = {}
var cell := 28
var ghost_shape := ""
var ghost_rot := 0
var hover := Vector2i(-1, -1)
var active := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(StoneWall.width() * cell, StoneWall.height() * cell)


func cell_rect(p: Vector2i) -> Rect2:
	return Rect2(Vector2(p.x * cell, (StoneWall.height() - 1 - p.y) * cell), Vector2(cell, cell))


func cell_at(pos: Vector2) -> Vector2i:
	var p := Vector2i(floori(pos.x / cell), StoneWall.height() - 1 - floori(pos.y / cell))
	return p if StoneWall.in_bounds(p) else Vector2i(-1, -1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var p := cell_at(event.position)
		if p != hover:
			hover = p
			cell_hovered.emit(p)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var p := cell_at(event.position)
		if p != Vector2i(-1, -1) or event.button_index == MOUSE_BUTTON_RIGHT:
			cell_clicked.emit(p, event.button_index)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover = Vector2i(-1, -1)
		queue_redraw()


func _draw() -> void:
	var w := StoneWall.width()
	var h := StoneWall.height()
	draw_rect(Rect2(Vector2.ZERO, Vector2(w * cell, h * cell)), COLORS.slot)
	if layout.is_empty():
		return
	# 石块：每格涂色，和旁边不是同一块的边画深色线。
	for y in h:
		for x in w:
			var p := Vector2i(x, y)
			var r := cell_rect(p)
			var id := StoneWall.at(layout, p)
			if id == 0:
				draw_rect(r.grow(-1), COLORS.grid, false, 1.0)
				continue
			var shape := String(layout.shapes.get(str(id), "wedge"))
			draw_rect(r, COLORS.get(shape, COLORS.wedge))
			var tl := r.position
			var tr := r.position + Vector2(cell, 0)
			var bl := r.position + Vector2(0, cell)
			var br := r.position + Vector2(cell, cell)
			if StoneWall.at(layout, p + Vector2i(1, 0)) != id:
				draw_line(tr, br, COLORS.edge, 2.0)
			if StoneWall.at(layout, p + Vector2i(-1, 0)) != id:
				draw_line(tl, bl, COLORS.edge, 2.0)
			if StoneWall.at(layout, p + Vector2i(0, 1)) != id:
				draw_line(tl, tr, COLORS.edge, 2.0)
			if StoneWall.at(layout, p + Vector2i(0, -1)) != id:
				draw_line(bl, br, COLORS.edge, 2.0)
	# 红缝：贯穿上下的红线（只在有石头以后画，空槽不吓人）。
	if StoneWall.filled(layout) > 0 and layout.get("kind", "stone") == "stone":
		for x in StoneWall.red_seams(layout):
			draw_line(Vector2(x * cell, 0), Vector2(x * cell, h * cell), COLORS.red, 2.0)
	# 金边：咬住的接缝上一小段金线。
	for j: Vector2i in StoneWall.gold_joints(layout):
		var c := Vector2(j.x * cell, (h - j.y) * cell)
		draw_line(c - Vector2(cell * 0.4, 0), c + Vector2(cell * 0.4, 0), COLORS.gold, 3.0)
	# 影子：要放的石头。
	if active and ghost_shape != "" and hover != Vector2i(-1, -1):
		var ok := StoneWall.can_place(layout, ghost_shape, ghost_rot, hover)
		for p in StoneWall.footprint(ghost_shape, ghost_rot, hover):
			if StoneWall.in_bounds(p):
				draw_rect(cell_rect(p).grow(-2), COLORS.ghost_ok if ok else COLORS.ghost_bad)


## 小图标：画一块石头的形状（库存窗口用）。
static func draw_shape(canvas: CanvasItem, shape: String, rot: int, origin: Vector2, size: float, selected: bool) -> void:
	var cells := StoneWall.shape_cells(shape, rot)
	var top := 0
	for c in cells:
		top = maxi(top, c.y)
	for c in cells:
		var r := Rect2(origin + Vector2(c.x * size, (top - c.y) * size), Vector2(size, size))
		canvas.draw_rect(r, COLORS.get(shape, COLORS.wedge))
		canvas.draw_rect(r, COLORS.gold if selected else COLORS.edge, false, 1.0)
