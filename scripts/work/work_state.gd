class_name WorkState
extends RefCounted
## 劳作阶段的规则部分（WORK）：分配人手、修建、训练、修墙、吃粮、义仓和饥饿、目标卡。不碰界面，方便无头测试。
## 规则见 WORK-001，数值在 data/rules/work.json。一个劳作阶段 2 个季节。

const JOBS := ["farm", "gather", "build", "train"]
const TYPE_RANK := {"none": 0, "fence": 1, "stone": 2}

var cfg: Dictionary = {}
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
var granary_used := false
## 这一季每个工种几个人。
var assign := {"farm": 0, "gather": 0, "build": 0, "train": 0}
## 这一季受训的人各练什么兵种（长度 = assign.train）。
var train_types: Array = []
## 这一季要修建的墙位。
var build_queue: Array = []
## 每季的报告：{"season", "rice", "materials", "built", "trained", "repaired", "granary", "hungry"}。
var reports: Array = []
var done := false
## 这一季修墙已经花掉的材料（报告用）。
var _repaired := 0


func setup(work_input: Dictionary) -> void:
	input = work_input
	cfg = Rules.get_value("work", {})
	work_id = input.get("work_id", "")
	gen = int(input.get("gen", 1))
	people = int(input.get("people", 0))
	rice = int(input.get("rice", 0))
	materials = int(input.get("materials", 0))
	hungry = int(input.get("hungry", 0))
	roster = input.get("roster", []).duplicate(true)
	wall_slots = input.get("wall_slots", {}).duplicate(true)
	granary_used = input.get("granary_used", false)


func seasons() -> int:
	return int(cfg.get("seasons", 2))


## 这一代算上这一季还剩几季。
func seasons_left_in_gen() -> int:
	var phase := int(cfg.get("phases", {}).get(work_id, 1))
	return (int(cfg.get("phases_per_gen", 2)) - phase) * seasons() + seasons() - season + 1


func idle() -> int:
	var used := 0
	for job: String in JOBS:
		used += int(assign[job])
	return people - used


# ---------- 分配 ----------

## 设置一个工种的人数（不超过空闲的人）。修建的人少了会去掉排不上的墙位；训练的人数变了会补上或去掉兵种。
func set_job(job: String, count: int) -> void:
	count = clampi(count, 0, int(assign[job]) + idle())
	assign[job] = count
	while build_queue.size() > build_capacity():
		build_queue.pop_back()
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


func build_spec() -> Dictionary:
	return cfg.build.get(str(gen), {"type": "fence", "people": 1, "materials": 2})


## 这一季最多能修几段：看修建的人数和手上的材料。
func build_capacity() -> int:
	var spec := build_spec()
	var by_people := int(assign.build) / maxi(1, int(spec.people))
	var by_materials := materials / maxi(1, int(spec.materials))
	return mini(by_people, by_materials)


## 这个墙位能不能修建：空地、废墟（有格子 HP 0），或者第二代起把栅栏升级成石墙。
func can_build(slot: String) -> bool:
	var wall: Dictionary = wall_slots.get(slot, {"type": "none", "hp": []})
	var target: String = build_spec().type
	if TYPE_RANK[wall.type] < TYPE_RANK[target]:
		return true
	return wall.type == target and wall.hp.any(func(h: Variant) -> bool: return int(h) <= 0)


func toggle_build(slot: String) -> bool:
	if slot in build_queue:
		build_queue.erase(slot)
		return true
	if not can_build(slot) or build_queue.size() >= build_capacity():
		return false
	build_queue.append(slot)
	return true


## 修这个墙位要几份材料：每个没坏透（HP > 0）但不满的格子，每 3 点 HP 1 份，向上取整。
func repair_cost(slot: String) -> int:
	var wall: Dictionary = wall_slots.get(slot, {"type": "none", "hp": []})
	if wall.type == "none":
		return 0
	var full := FlowLogic.max_hp(slot, wall.type)
	var per := int(cfg.get("repair_hp_per_material", 3))
	var cost := 0
	for h: Variant in wall.hp:
		if int(h) > 0 and int(h) < full:
			cost += ceili(float(full - int(h)) / per)
	return cost


func repair(slot: String) -> bool:
	var cost := repair_cost(slot)
	if cost <= 0 or cost > materials - reserved_materials():
		return false
	var wall: Dictionary = wall_slots[slot]
	var full := FlowLogic.max_hp(slot, wall.type)
	for i in wall.hp.size():
		if int(wall.hp[i]) > 0:
			wall.hp[i] = full
	materials -= cost
	_repaired += cost
	return true


## 排进修建的墙位要花的材料（还没花，季末才算）。
func reserved_materials() -> int:
	return build_queue.size() * int(build_spec().materials)


# ---------- 季末 ----------

## 结束这一季会变成什么样（确认前预览）。
func preview() -> Dictionary:
	var spec := build_spec()
	var r := rice + int(assign.farm) * int(cfg.jobs.farm.rice) - people * int(cfg.eat_per_person)
	var m := materials + int(assign.gather) * int(cfg.jobs.gather.materials) - build_queue.size() * int(spec.materials)
	var granary := r < 0 and not granary_used
	return {"rice": maxi(r, 0), "materials": m, "built": build_queue.size(), "trained": int(assign.train),
		"granary": granary, "hungry": 0 if r >= 0 or granary else -r}


func end_season() -> Dictionary:
	var spec := build_spec()
	var rice_before := rice
	var materials_before := materials + _repaired
	rice += int(assign.farm) * int(cfg.jobs.farm.rice)
	materials += int(assign.gather) * int(cfg.jobs.gather.materials) - build_queue.size() * int(spec.materials)
	for slot: String in build_queue:
		var full := FlowLogic.max_hp(slot, spec.type)
		var cells: int = maxi(1, wall_slots.get(slot, {"hp": [0]}).hp.size())
		var hp: Array = []
		hp.resize(cells)
		hp.fill(full)
		wall_slots[slot] = {"type": spec.type, "hp": hp}
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
	var report := {"season": season, "rice": rice - rice_before, "materials": materials - materials_before,
		"built": build_queue.size(), "trained": train_types.size(), "repaired": _repaired,
		"granary": granary, "hungry": hungry}
	reports.append(report)
	build_queue.clear()
	_repaired = 0
	set_job("train", 0)
	season += 1
	if season > seasons():
		done = true
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
		var max_hp := FlowLogic.max_hp(slot, wall.type)
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
	}
