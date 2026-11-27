class_name BattleBot
extends RefCounted
## 测试用的“认真玩法”：出去接乡亲、挡在海寇前面、能打就打（REDESIGN-001 W3 调难度用）。
## 不是给玩家的 AI，只在测试里用；规则都走 BattleState 的公开接口，和玩家点的一样。


## 走完这一回合所有守军的行动（不结束回合）。
static func play_turn(s: BattleState) -> void:
	var allies := s.allies_on_map()
	allies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.move) > int(b.move))
	var claimed := {}  # 已经有人去接的乡亲 uid
	for a: Dictionary in allies:
		if not s.can_command(a):
			continue
		var goal := _pick_goal(s, a, claimed)
		if goal != BattleState.NOWHERE:
			var best := _best_cell(s, a, goal)
			if best != a.pos:
				s.move_unit(a, best)
		_act(s, a)


## 这个守军这一回合要往哪走：先接没人陪的走不动的乡亲，再挡要抓人的海寇，再陪最远的乡亲，最后找海寇打。
static func _pick_goal(s: BattleState, a: Dictionary, claimed: Dictionary) -> Vector2i:
	var safe_dist := s._distance_to_safe()
	var villagers := s.villagers_outside().filter(func(v: Dictionary) -> bool: return s.on_map(v))
	# 1. 走不动的乡亲，旁边还没有守军
	var slow := villagers.filter(func(v: Dictionary) -> bool:
		return v.get("needs_escort", false) and not claimed.has(int(v.uid)) and not _escorted(s, v, a))
	slow.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return BattleState.dist(x.pos, a.pos) < BattleState.dist(y.pos, a.pos))
	if not slow.is_empty() and BattleState.dist(slow[0].pos, a.pos) <= int(a.move) + 4:
		claimed[int(slow[0].uid)] = true
		return slow[0].pos
	# 2. 海寇要抓的乡亲 / 抓着乡亲的海寇
	for plan: Dictionary in s.intents:
		var e := s.unit_by_uid(int(plan.uid))
		if e.is_empty():
			continue
		if plan.act == "carry" or int(e.carrying) != 0:
			return e.pos
		if plan.act in ["grab", "loot"] and plan.target != BattleState.NOWHERE and BattleState.dist(plan.target, a.pos) <= int(a.move) + 3:
			return plan.target
	# 3. 离家最远、还没人陪的乡亲
	villagers.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return int(safe_dist.get(x.pos, 0)) > int(safe_dist.get(y.pos, 0)))
	for v: Dictionary in villagers:
		if not claimed.has(int(v.uid)) and not _escorted(s, v, a):
			claimed[int(v.uid)] = true
			return v.pos
	# 4. 最近的海寇
	var best := BattleState.NOWHERE
	for e in s.enemies_on_map():
		if e.ai == "boat":
			continue
		if best == BattleState.NOWHERE or BattleState.dist(e.pos, a.pos) < BattleState.dist(best, a.pos):
			best = e.pos
	return best


## 每格走到 goal 的花费（只看地形和墙，不看人）。
static func _walk_distance(s: BattleState, goal: Vector2i) -> Dictionary:
	var out := {goal: 0}
	var open: Array[Vector2i] = [goal]
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if int(out[open[i]]) < int(out[open[bi]]):
				bi = i
		var p: Vector2i = open[bi]
		open.remove_at(bi)
		for n in s.neighbors(p):
			if not s.walkable(n):
				continue
			var c := int(out[p]) + s.step_cost(n)
			if not out.has(n) or c < int(out[n]):
				out[n] = c
				open.append(n)
	return out


static func _escorted(s: BattleState, v: Dictionary, me: Dictionary) -> bool:
	for n in s.neighbors(v.pos):
		var u := s.unit_at(n)
		if not u.is_empty() and u.side == "ally" and u.uid != me.uid:
			return true
	return false


## 能走到的格子里离目标最近的（按路走，绕开淹着的潮沟）；一样近时选离安全区近的（站在乡亲回家的路上）。
static func _best_cell(s: BattleState, a: Dictionary, goal: Vector2i) -> Vector2i:
	var safe_dist := s._distance_to_safe()
	var to_goal := _walk_distance(s, goal)
	var best: Vector2i = a.pos
	var best_key := [maxi(1, int(to_goal.get(a.pos, 999))), int(safe_dist.get(a.pos, 0))]
	for p: Vector2i in s.move_range(a):
		if s.threat_cell(p) >= int(a.hp):
			continue  # 不走到会被打死的地方
		var key := [maxi(1, int(to_goal.get(p, 999))), int(safe_dist.get(p, 0))]
		if key[0] < best_key[0] or (key[0] == best_key[0] and key[1] < best_key[1]):
			best = p
			best_key = key
	return best


static func _act(s: BattleState, a: Dictionary) -> void:
	var actions := s.actions_for(a)
	if "beacon" in actions:
		s.do_action(a, "beacon")
		actions = s.actions_for(a)
	if "attack" in actions:
		var targets := s.targets_for(a, "attack")
		targets.sort_custom(func(x: Vector2i, y: Vector2i) -> bool: return int(s.unit_at(x).hp) < int(s.unit_at(y).hp))
		s.do_action(a, "attack", targets[0])
	elif "guide" in actions:
		s.do_action(a, "guide")
	elif "repair" in actions:
		s.do_action(a, "repair", s.targets_for(a, "repair")[0])
