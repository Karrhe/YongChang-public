class_name WorkBot
extends RefCounted
## 测试用的劳作玩法（REDESIGN-002 方案一）：够吃的人去种田，目标卡要守军就练，剩下的石匠砌石——
## 先修门，再一段一段砌墙，每块石头挑红缝最少、放得最低的位置。不是给玩家的 AI，只在测试里用。


static func play_season(s: WorkState) -> void:
	var eat := s.people * int(s.cfg.eat_per_person) - s.rice
	var farmers := clampi(ceili(float(eat) / int(s.cfg.jobs.farm.rice)), 0, s.people)
	s.set_job("farm", farmers)
	var p := s.goal_progress()
	if p.defenders < p.defenders_need and s.idle() > 1:
		s.set_job("train", 1)
	if p.gates < p.gates_need:
		for gate: String in Rules.get_value("core.walls.gates", []):
			if s.can_build_gate(gate):
				s.build_gate(gate)
				break
	for slot: String in Rules.get_value("core.walls.slots", []):
		while s.placements_left() > 0 and not s.stone_queue.is_empty() and not _done(s, slot):
			if not place_best(s, slot):
				if s.can_chisel(0):
					s.chisel(0)
					continue
				break
	for slot: String in s.wall_slots:
		var cost := s.repair_cost(slot)
		if cost > 0 and cost <= s.materials:
			s.repair(slot)


static func _done(s: WorkState, slot: String) -> bool:
	var l := s.layout(slot)
	if l.kind == "fence":
		return StoneWall.is_built(l)
	return StoneWall.filled(l) >= StoneWall.width() * StoneWall.height() \
		or (StoneWall.is_built(l) and StoneWall.red_seams(l).is_empty())


## 在这个墙位放一块：库存窗口 × 转向 × 位置里挑红缝最少、最低、最大的。放不下返回 false。
static func place_best(s: WorkState, slot: String) -> bool:
	var best: Array = []
	var best_score := 1 << 20
	var shapes := s.window()
	for i in shapes.size():
		for r in 4:
			for origin in StoneWall.placements(s.layout(slot), String(shapes[i]), r):
				var trial := s.layout(slot).duplicate(true)
				StoneWall.place(trial, String(shapes[i]), r, origin)
				var score := StoneWall.red_seams(trial).size() * 10 + origin.y * 3 - StoneWall.shape_cells(String(shapes[i]), r).size()
				if score < best_score:
					best_score = score
					best = [i, r, origin]
			if not StoneWall.can_rotate(String(shapes[i])):
				break
	if best.is_empty():
		return false
	return s.place(slot, best[0], best[1], best[2])
