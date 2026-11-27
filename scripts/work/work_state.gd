class_name WorkState
extends RefCounted
## 劳作阶段的规则部分（WORK，REDESIGN-002 方案一《石头要彼此咬住》）：分人种田和训练，剩下的人是石匠，
## 每人每季放几块石头（砌石拼图，规则在 StoneWall）；石料按潮汐送来；修墙、修门；吃粮、义仓和饥饿、目标卡。
## 不碰界面，方便无头测试。数值在 data/rules/work.json。一个劳作阶段 2 个季节。

const JOBS := ["farm", "train"]
const TYPE_RANK := {"none": 0, "fence": 1, "stone": 2}

var cfg: Dictionary = {}
var pz: Dictionary = {}
var input: Dictionary = {}
var work_id := ""
var gen := 1
var season := 1
var people := 0
var rice := 0
var materials := 0
var hungry := 0
var roster: Array = []
var wall_slots: Dictionary = {}
var wall_layouts: Dictionary = {}
## 石料库存的形状，从前往后；长度 = materials。
var stone_queue: Array = []
var stone_next := 0
var granary_used := false
## 这一季每个工种几个人；剩下的人是石匠。
var assign := {"farm": 0, "train": 0}
## 这一季受训的人各练什么兵种（长度 = assign.train）。
var train_types: Array = []
## 这一季已经用掉几次放置（放石头、凿石头、修门）。
var placements_used := 0
## 这一季潮汐送来几块（报告用）。
var delivered := 0
## 每季的报告：{"season", "rice", "materials", "placed", "trained", "repaired", "granary", "hungry", "delivered"}。
var reports: Array = []
var done := false
var _placed := 0
var _repaired := 0


func setup(work_input: Dictionary) -> void:
	input = work_input
	cfg = Rules.get_value("work", {})
	pz = cfg.get("puzzle", {})
	work_id = input.get("work_id", "")
	gen = int(input.get("gen", 1))
	people = int(input.get("people", 0))
	rice = int(input.get("rice", 0))
	materials = int(input.get("materials", 0))
	hungry = int(input.get("hungry", 0))
	roster = input.get("roster", []).duplicate(true)
	wall_slots = input.get("wall_slots", {}).duplicate(true)
	wall_layouts = input.get("wall_layouts", {}).duplicate(true)
	stone_queue = Array(input.get("stone_queue", [])).duplicate()
	stone_next = int(input.get("stone_next", 0))
	granary_used = input.get("granary_used", false)
	_deliver()


func seasons() -> int:
	return int(cfg.get("seasons", 2))


## 这一代算上这一季还剩几季。
func seasons_left_in_gen() -> int:
	var phase := int(cfg.get("phases", {}).get(work_id, 1))
	return (int(cfg.get("phases_per_gen", 2)) - phase) * seasons() + seasons() - season + 1


## 这一季的潮汐：{"tide", "pieces"}。
func season_delivery() -> Dictionary:
	var list: Array = pz.get("deliveries", {}).get(work_id, [])
	return list[season - 1] if season - 1 < list.size() else {"tide": "", "pieces": 0}


func _deliver() -> void:
	delivered = int(season_delivery().get("pieces", 0))
	materials += delivered
	_normalize_queue()


## 石料库存的形状和 materials 对齐：这一代用不了的形状换掉，不够就按这一代的顺序补，多了从后面截掉。
func _normalize_queue() -> void:
	var allowed: Array = pz.get("sets", {}).get(str(gen), [])
	stone_queue = stone_queue.filter(func(s: Variant) -> bool: return String(s) in allowed)
	var seq: Array = pz.get("sequence", {}).get(str(gen), allowed)
	while stone_queue.size() < materials and not seq.is_empty():
		stone_queue.append(seq[stone_next % seq.size()])
		stone_next += 1
	while stone_queue.size() > maxi(0, materials):
		stone_queue.pop_back()


func idle() -> int:
	return people - int(assign.farm) - int(assign.train)


## 石匠 = 没去种田、没去训练的人。
func masons() -> int:
	return maxi(0, idle())


func placements_left() -> int:
	return masons() * int(pz.get("placements_per_mason", 3)) - placements_used


## 能挑的石料：库存最前面 window 块。
func window() -> Array:
	return stone_queue.slice(0, int(pz.get("window", 3)))


func wall_kind() -> String:
	return String(pz.get("kind", {}).get(str(gen), "stone"))


# ---------- 分配 ----------

## 设置一个工种的人数。石匠已经放出去的石头收不回来，所以人数不能少于已经用掉的放置。
func set_job(job: String, count: int) -> void:
	var per := int(pz.get("placements_per_mason", 3))
	var masons_needed := ceili(float(placements_used) / per)
	var others := 0
	for j: String in JOBS:
		if j != job:
			others += int(assign[j])
	count = clampi(count, 0, maxi(0, people - others - masons_needed))
	assign[job] = count
	var types: Array = cfg.train_types.get(str(gen), ["spearman"])
	while train_types.size() < int(assign.train):
		train_types.append(types[0])
	while train_types.size() > int(assign.train):
		train_types.pop_back()


## 第 i 个受训的人换成下一个兵种。
func cycle_train_type(i: int) -> void:
	var types: Array = cfg.train_types.get(str(gen), ["spearman"])
	if i < 0 or i >= train_types.size():
		return
	train_types[i] = types[(types.find(train_types[i]) + 1) % types.size()]


# ---------- 砌石 ----------

## 这个墙位的砖槽（没有就是空的）。第二代起在木栅栏上砌石：木桩先拆掉，栅栏留着挡，石墙筑成才换上。
func layout(slot: String) -> Dictionary:
	var l: Dictionary = wall_layouts.get(slot, {})
	if l.is_empty() or l.kind != wall_kind():
		return StoneWall.empty(wall_kind())
	return l


## 能不能在这个墙位放石头：要是墙位（门不拼），还有放置次数和石料。
func can_work(slot: String) -> bool:
	return not slot.begins_with("gate_") and placements_left() > 0 and not stone_queue.is_empty()


## 把库存前面第 pick 块石头，转 rot 次，左下角放在 origin。
func place(slot: String, pick: int, rot: int, origin: Vector2i) -> bool:
	if not can_work(slot) or pick < 0 or pick >= window().size():
		return false
	var l := layout(slot)
	if StoneWall.place(l, String(stone_queue[pick]), rot, origin) == 0:
		return false
	wall_layouts[slot] = l
	stone_queue.remove_at(pick)
	materials -= 1
	placements_used += 1
	_placed += 1
	if StoneWall.is_built(l):
		wall_slots[slot] = StoneWall.wall_full(l, _cells(slot))
	return true


## 凿：花一次放置，把挑中的石块凿成楔石（不会卡死，agy 2026-11-27）。第一代的木桩不凿。
func can_chisel(pick: int) -> bool:
	return gen >= 2 and placements_left() > 0 and pick >= 0 and pick < window().size() \
		and stone_queue[pick] != "wedge"


func chisel(pick: int) -> bool:
	if not can_chisel(pick):
		return false
	stone_queue[pick] = "wedge"
	placements_used += 1
	return true


## 门不拼：花一次放置 + gate_pieces 块石料修成这一代的门（第一代栅栏门，第二代起石门），HP 满。
func gate_cost() -> int:
	return int(pz.get("gate_pieces", 2))


func can_build_gate(slot: String) -> bool:
	if not slot.begins_with("gate_") or placements_left() <= 0 or materials < gate_cost():
		return false
	var wall: Dictionary = wall_slots.get(slot, {"type": "none", "hp": [0]})
	if TYPE_RANK[wall.type] < TYPE_RANK[wall_kind()]:
		return true
	return wall.type == wall_kind() and wall.hp.any(func(h: Variant) -> bool: return int(h) <= 0)


func build_gate(slot: String) -> bool:
	if not can_build_gate(slot):
		return false
	for i in gate_cost():
		stone_queue.pop_front()
	materials -= gate_cost()
	placements_used += 1
	_placed += 1
	var full := FlowLogic.max_hp(slot, wall_kind())
	wall_slots[slot] = {"type": wall_kind(), "hp": StoneWall._fill(_cells(slot), full)}
	return true


func _cells(slot: String) -> int:
	return maxi(1, wall_slots.get(slot, {"hp": [0]}).hp.size())


# ---------- 修墙 ----------

## 修这个墙位要几块石料：每个没坏透（HP > 0）但不满的格子，每 3 点 HP 1 块，向上取整。
func repair_cost(slot: String) -> int:
	var wall: Dictionary = wall_slots.get(slot, {"type": "none", "hp": []})
	if wall.type == "none":
		return 0
	var full := FlowLogic.wall_max(slot, wall)
	var per := int(cfg.get("repair_hp_per_material", 3))
	var cost := 0
	for h: Variant in wall.hp:
		if int(h) > 0 and int(h) < full:
			cost += ceili(float(full - int(h)) / per)
	return cost


func repair(slot: String) -> bool:
	var cost := repair_cost(slot)
	if cost <= 0 or cost > materials:
		return false
	var wall: Dictionary = wall_slots[slot]
	var full := FlowLogic.wall_max(slot, wall)
	for i in wall.hp.size():
		if int(wall.hp[i]) > 0:
			wall.hp[i] = full
	for i in cost:
		stone_queue.pop_front()
	materials -= cost
	_repaired += cost
	return true


# ---------- 季末 ----------

## 结束这一季会变成什么样（确认前预览）。
func preview() -> Dictionary:
	var r := rice + int(assign.farm) * int(cfg.jobs.farm.rice) - people * int(cfg.eat_per_person)
	var granary := r < 0 and not granary_used
	return {"rice": maxi(r, 0), "materials": materials, "placed": _placed, "trained": int(assign.train),
		"left": placements_left(), "granary": granary, "hungry": 0 if r >= 0 or granary else -r}


func end_season() -> Dictionary:
	var rice_before := rice
	rice += int(assign.farm) * int(cfg.jobs.farm.rice)
	for i in train_types.size():
		roster.append({"id": "%s_s%d_%d" % [work_id, season, i + 1], "type": train_types[i]})
	rice -= people * int(cfg.eat_per_person)
	var granary := false
	if rice < 0:
		if not granary_used:
			granary_used = true  # 宗族义仓：每代一次，粮食补到 0（WORK-001 §8）
			granary = true
			rice = 0
			hungry = 0
		else:
			hungry = -rice
			rice = 0
	else:
		hungry = 0
	var report := {"season": season, "rice": rice - rice_before, "materials": materials, "placed": _placed,
		"built": _placed, "trained": train_types.size(), "repaired": _repaired, "granary": granary, "hungry": hungry,
		"delivered": delivered}
	reports.append(report)
	_placed = 0
	_repaired = 0
	placements_used = 0
	set_job("train", 0)
	season += 1
	if season > seasons():
		done = true
	else:
		_deliver()
	return report


# ---------- 目标卡 ----------

func goal() -> Dictionary:
	return cfg.goals.get(str(gen), {})


## 目标卡的进度：{"walls", "walls_need", "gates", "gates_need", "defenders", "defenders_need", "met"}。
func goal_progress() -> Dictionary:
	var g := goal()
	var need_type: String = g.get("type", "fence")
	var full: bool = g.get("full", false)
	var walls := 0
	var gates := 0
	for slot: String in wall_slots:
		var wall: Dictionary = wall_slots[slot]
		if TYPE_RANK.get(wall.type, 0) < TYPE_RANK[need_type]:
			continue
		var max_hp := FlowLogic.wall_max(slot, wall)
		var ok: bool = wall.hp.all(func(h: Variant) -> bool: return int(h) >= max_hp if full else int(h) > 0)
		if not ok:
			continue
		if slot.begins_with("gate_"):
			gates += 1
		else:
			walls += 1
	var p := {
		"walls": walls, "walls_need": int(g.get("walls", 0)),
		"gates": gates, "gates_need": int(g.get("gates", 0)),
		"defenders": roster.size(), "defenders_need": int(g.get("defenders", 0)),
	}
	p.met = walls >= p.walls_need and gates >= p.gates_need and roster.size() >= p.defenders_need
	return p


func result() -> Dictionary:
	return {
		"work_id": work_id, "gen": gen, "people": people, "rice": rice, "materials": materials,
		"hungry": hungry, "roster": roster.duplicate(true), "wall_slots": wall_slots.duplicate(true),
		"granary_used": granary_used, "goal_met": goal_progress().met,
		"wall_layouts": wall_layouts.duplicate(true), "stone_queue": stone_queue.duplicate(), "stone_next": stone_next,
	}
