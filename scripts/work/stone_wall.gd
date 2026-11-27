class_name StoneWall
extends RefCounted
## 砌石拼图的规则（REDESIGN-002 方案一《石头要彼此咬住》）：一个墙位一个砖槽，不碰界面。
## 砖槽 w × h 格（work.json 的 puzzle.w / puzzle.h），y = 0 是最底下一行。
## 一个砖槽存成字典：{"kind": "stone"/"fence", "cells": [每格的石块编号，0 = 空], "shapes": {编号: 形状 ID}, "next": 下一个编号}。
## 规则：
## - 放石头：每一格都要在槽里、是空的，而且下面有托（最底行，或下面那格有石头）。
## - 金边：一块石头的底边同时压住下面两块不同的石头，接缝处亮金边（咬住了）。
## - 红缝：列和列之间的竖线，没有任何一块石头跨过去，就是红缝（通缝）。
## - 筑成：填满 puzzle.built_cells 格以上。木栅栏 HP 固定；石墙 HP = 满 HP − 红缝数 − 空格数的一半（向上取整），最少 1。


static func cfg() -> Dictionary:
	return Rules.get_value("work.puzzle", {})


static func width() -> int:
	return int(cfg().get("w", 4))


static func height() -> int:
	return int(cfg().get("h", 3))


static func empty(kind: String) -> Dictionary:
	var cells: Array = []
	cells.resize(width() * height())
	cells.fill(0)
	return {"kind": kind, "cells": cells, "shapes": {}, "next": 1}


static func index(p: Vector2i) -> int:
	return p.y * width() + p.x


static func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width() and p.y < height()


static func at(layout: Dictionary, p: Vector2i) -> int:
	return int(layout.cells[index(p)]) if in_bounds(p) else 0


# ---------- 形状 ----------

## 形状转 rot 次 90° 之后的格子，左下角对齐到 (0, 0)。不能转的形状忽略 rot。
static func shape_cells(shape: String, rot: int = 0) -> Array[Vector2i]:
	var spec: Dictionary = cfg().get("shapes", {}).get(shape, {"cells": [[0, 0]]})
	var out: Array[Vector2i] = []
	for c: Array in spec.cells:
		out.append(Vector2i(int(c[0]), int(c[1])))
	if spec.get("rotate", true):
		for i in posmod(rot, 4):
			for j in out.size():
				out[j] = Vector2i(out[j].y, -out[j].x)
	var lo := Vector2i(1 << 20, 1 << 20)
	for c in out:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
	for j in out.size():
		out[j] -= lo
	return out


static func can_rotate(shape: String) -> bool:
	return cfg().get("shapes", {}).get(shape, {}).get("rotate", true)


# ---------- 放石头 ----------

## 把形状放在 origin（形状左下角）上会占哪些格子。
static func footprint(shape: String, rot: int, origin: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in shape_cells(shape, rot):
		out.append(origin + c)
	return out


static func can_place(layout: Dictionary, shape: String, rot: int, origin: Vector2i) -> bool:
	var cells := footprint(shape, rot, origin)
	for p in cells:
		if not in_bounds(p) or at(layout, p) != 0:
			return false
	for p in cells:
		var below := p + Vector2i(0, -1)
		if p.y > 0 and at(layout, below) == 0 and not below in cells:
			return false  # 悬空
	return true


## 放下一块石头，返回它的编号；放不下返回 0。
static func place(layout: Dictionary, shape: String, rot: int, origin: Vector2i) -> int:
	if not can_place(layout, shape, rot, origin):
		return 0
	var id := int(layout.next)
	layout.next = id + 1
	layout.shapes[str(id)] = shape
	for p in footprint(shape, rot, origin):
		layout.cells[index(p)] = id
	return id


## 能放的位置（左下角）：给界面提示和测试用。
static func placements(layout: Dictionary, shape: String, rot: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in height():
		for x in width():
			if can_place(layout, shape, rot, Vector2i(x, y)):
				out.append(Vector2i(x, y))
	return out


## 把这些格子清空（风化掉的格子、战后塌掉的一行）。上面的石头不跟着掉，留着悬空也算数。
static func clear_cells(layout: Dictionary, cells: Array) -> void:
	for c: Variant in cells:
		var p: Vector2i = c if c is Vector2i else Vector2i(int(c[0]), int(c[1]))
		if in_bounds(p):
			layout.cells[index(p)] = 0


static func clear_top_row(layout: Dictionary) -> void:
	var row: Array = []
	for x in width():
		row.append(Vector2i(x, height() - 1))
	clear_cells(layout, row)


# ---------- 判定 ----------

static func filled(layout: Dictionary) -> int:
	var n := 0
	for c: Variant in layout.cells:
		if int(c) != 0:
			n += 1
	return n


static func is_built(layout: Dictionary) -> bool:
	return filled(layout) >= int(cfg().get("built_cells", 9))


## 红缝：第 x 条竖线（在第 x−1 列和第 x 列之间，x = 1 … w−1）没有任何一块石头跨过。
static func red_seams(layout: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for x in range(1, width()):
		var crossed := false
		for y in height():
			var a := at(layout, Vector2i(x - 1, y))
			if a != 0 and a == at(layout, Vector2i(x, y)):
				crossed = true
				break
		if not crossed:
			out.append(x)
	return out


## 金边：格子 (x, y) 左边的竖线上，一块石头同时压住下面两块不同的石头。返回 [Vector2i(x, y)]：竖线 x、在第 y 行的底边。
static func gold_joints(layout: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(1, height()):
		for x in range(1, width()):
			var top := at(layout, Vector2i(x - 1, y))
			if top == 0 or top != at(layout, Vector2i(x, y)):
				continue
			var left := at(layout, Vector2i(x - 1, y - 1))
			var right := at(layout, Vector2i(x, y - 1))
			if left != 0 and right != 0 and left != right:
				out.append(Vector2i(x, y))
	return out


## 这个砖槽筑成后每格的满 HP；没筑成是 0。
static func max_hp(layout: Dictionary) -> int:
	if not is_built(layout):
		return 0
	var hp: Dictionary = cfg().get("hp", {})
	if layout.kind == "fence":
		return int(hp.get("fence", 2))
	var empty_cells := width() * height() - filled(layout)
	var value := int(hp.get("stone", 6)) - red_seams(layout).size() - ceili(empty_cells / 2.0)
	return maxi(int(hp.get("min", 1)), value)


## 刚砌好（或放了一块石头）的墙：每格 HP 都是满的。cells = 这个墙位在战斗里有几格。没筑成返回空地。
static func wall_full(layout: Dictionary, cells: int) -> Dictionary:
	var m := max_hp(layout)
	if m <= 0:
		return {"type": "none", "hp": _fill(cells, 0)}
	return {"type": layout.kind, "hp": _fill(cells, m), "max": m}


## 掉了格子以后（风化、塌顶）：满 HP 重算，现有 HP 不超过新的满 HP，HP 0 的格子变 1（还能修）；不够筑成就变回空地。
static func wall_after_loss(layout: Dictionary, wall: Dictionary) -> Dictionary:
	var m := max_hp(layout)
	var cells: int = wall.hp.size()
	if m <= 0:
		return {"type": "none", "hp": _fill(cells, 0)}
	var hp: Array = []
	for h: Variant in wall.hp:
		hp.append(clampi(int(h), 1, m))
	return {"type": layout.kind, "hp": hp, "max": m}


static func _fill(n: int, value: int) -> Array:
	var a := []
	a.resize(n)
	a.fill(value)
	return a


## 台风：每格 HP 掉 typhoon_per_seam × 红缝数（WORK-001 §6 改，负责人 2026-11-27 定）。
static func typhoon_loss(layout: Dictionary) -> int:
	return int(cfg().get("typhoon_per_seam", 2)) * red_seams(layout).size()


## 一段木栅栏：前几列各插一根木桩，刚好扎成（旧存档补砖槽用）。
static func fence() -> Dictionary:
	var layout := empty("fence")
	var stake_h := shape_cells("stake3").size()
	var need := ceili(float(cfg().get("built_cells", 9)) / stake_h)
	for x in mini(need, width()):
		place(layout, "stake3", 0, Vector2i(x, 0))
	return layout


## 一段完美咬合的墙（C2 调守军筑墙用）：形状和位置写在 puzzle.perfect 里。
static func perfect() -> Dictionary:
	var layout := empty("stone")
	for piece: Dictionary in cfg().get("perfect", []):
		place(layout, String(piece.shape), int(piece.get("rot", 0)), Vector2i(int(piece.at[0]), int(piece.at[1])))
	return layout
