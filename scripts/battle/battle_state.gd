class_name BattleState
extends RefCounted
## 战斗的规则部分（BAT）：地图、潮汐、单位、海寇的意图和行动、乡亲、墙、烽火、胜负。不碰界面，方便无头测试。
## 规则见 BAT-001，数值在 data/rules/battle.json。坐标 Vector2i(列, 行)，城在西、海在东。
## 用法：setup(input) → deploy_options() 给玩家勾选 → start(选中的) → 玩家行动 … end_turn() … → over 后取 result()。

## 寻路和潮水推人时邻格的顺序：西、北、南、东（ISSUE-001 BAT-04 临时做法）。
const DIRS: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0)]
const FAR := 1 << 20
const NOWHERE := Vector2i(-1, -1)

var cfg: Dictionary = {}
var bcfg: Dictionary = {}
var map: Dictionary = {}
var input: Dictionary = {}
var battle_id := ""
var gen := 1
var width := 0
var height := 0
var rows: PackedStringArray = PackedStringArray()
## 修好的墙和门：格子 → {"slot", "index", "kind": "wall" | "gate", "type": "fence" | "stone", "hp", "max", "open"}。
## 没修的墙位是田地，没修的门位是开口，都不在这里。
var structures: Dictionary = {}
## 战斗中搭的障碍：格子 → HP。
var barriers: Dictionary = {}
## 烽火：格子 → 第几回合点的（0 = 没点）。
var beacons: Dictionary = {}
## 所有单位（含已倒下的），每个是一个 Dictionary，见 _make_unit。
var units: Array[Dictionary] = []
var next_uid := 1
var turn := 1
var turns := 0
var tide_cycle: Array = []
var tide_start := 0
var goal := 0
var villager_total := 0
## 乡亲分几批从屋里出来：第 1 个数是第 1 回合出来的人数，以此类推（没写就第 1 回合全部出来）。
var villager_schedule: Array = []
## 已经按日程放出来的批数。
var villager_batches := 0
var saved := 0
var lost := 0
var raiders_defeated := 0
var hero_died := false
var elder_retired := false
var inspire_used := false
var started := false
var over := false
var seen_hints: Array = []
## 海寇这一回合要做的事（玩家行动前显示）：见 plan_enemy。
var intents: Array[Dictionary] = []
## 发生过的事，界面取走后清空：{"kind": "hero_death" | "landing" | "lantern" | "saved" | "beacon" | "reinforcements" | "retire" | "end", ...}。
var events: Array[Dictionary] = []


# ---------- 开始 ----------

func setup(battle_input: Dictionary) -> void:
	input = battle_input
	cfg = Rules.get_value("battle", {})
	battle_id = input.get("battle_id", "battle_1")
	bcfg = cfg.battles[battle_id]
	map = cfg.maps[bcfg.map]
	rows = PackedStringArray(map.rows)
	height = rows.size()
	width = rows[0].length()
	var number := int(battle_id.trim_prefix("battle_"))
	gen = 1 if number <= 3 else (2 if number <= 6 else 3)
	turns = int(bcfg.turns) + (1 if input.get("story_mode", false) else 0)
	goal = int(bcfg.goal)
	tide_cycle = cfg.tides["storm" if bcfg.get("storm", false) else "normal"]
	tide_start = tide_cycle.find(bcfg.tide)
	seen_hints = Array(input.get("seen_hints", [])).duplicate()
	_build_structures(input.get("wall_slots", {}))
	for b: Array in map.get("beacons", []):
		beacons[Vector2i(b[0], b[1])] = 0


func _build_structures(wall_slots: Dictionary) -> void:
	for slot: String in map.slots:
		var wall: Dictionary = wall_slots.get(slot, {"type": "none", "hp": []})
		if wall.get("type", "none") == "none":
			continue
		var cells: Array = map.slots[slot]
		var is_gate := slot.begins_with("gate_")
		var full := FlowLogic.max_hp(slot, wall.type)
		for i in cells.size():
			var hp: int = int(wall.hp[i]) if i < wall.hp.size() else full
			structures[Vector2i(cells[i][0], cells[i][1])] = {
				"slot": slot, "index": i, "kind": "gate" if is_gate else "wall",
				"type": wall.type, "hp": hp, "max": full, "open": true}


## 出战勾选：fixed 一定出战（主角、教学单位；B1 固定），choices 由玩家选（长辈、名单上的守军），slots 是还能选几个。
func deploy_options() -> Dictionary:
	var fixed: Array = []
	if input.get("hero") != null:
		fixed.append({"key": "hero", "kind": "hero"})
	for t: Dictionary in cfg.get("teaching", {}).get(battle_id, []):
		fixed.append({"key": t.id, "kind": "teaching", "unit": t})
	var choices: Array = []
	if not bcfg.get("fixed_roster", false):
		if input.get("elder") != null:
			choices.append({"key": "elder", "kind": "elder"})
		for u: Dictionary in input.get("roster", []):
			choices.append({"key": u.id, "kind": "roster", "unit": u})
	var bonus := int(input.get("bonus_defenders", 0))
	var slots := maxi(0, int(cfg.deploy.max) - fixed.size() - bonus)
	return {"fixed": fixed, "choices": choices, "slots": slots, "bonus": bonus}


## 默认勾选：长辈在前，名单按顺序，选满为止。
func default_picks() -> Array:
	var options := deploy_options()
	var picks: Array = []
	for c: Dictionary in options.choices:
		if picks.size() < options.slots:
			picks.append(c.key)
	return picks


func start(picks: Array) -> void:
	var options := deploy_options()
	var spots := _spots("deploy")
	for f: Dictionary in options.fixed:
		if f.kind == "hero":
			_place(_make_hero(input.hero, "hero"), spots)
		else:
			_place(_make_unit(f.unit.type, "ally", "teaching", f.unit.id), spots)
	var count := 0
	for c: Dictionary in options.choices:
		if not c.key in picks or count >= options.slots:
			continue
		count += 1
		if c.kind == "elder":
			_place(_make_hero(input.elder, "elder"), spots)
		else:
			_place(_make_unit(c.unit.type, "ally", "roster", c.unit.id), spots)
	for i in options.bonus:
		_place(_make_unit("bonus", "ally", "bonus"), spots)
	# 从 B2 起出战不足 3 人时补民兵（BAT-001 §5.3a）。
	if not bcfg.get("fixed_roster", false):
		while allies_on_map().size() < int(cfg.deploy.min_from_battle_2):
			_place(_make_unit("militia", "ally", "militia"), spots)
	villager_total = int(bcfg.villagers)
	villager_schedule = Array(bcfg.get("villager_schedule", [villager_total]))
	if bcfg.get("qiao", false) and not beacons.is_empty():
		var tower: Vector2i = beacons.keys()[0]
		var qiao := _make_unit("qiao", "npc", "npc")
		qiao.pos = tower
		units.append(qiao)
		beacons[tower] = 1  # 峤叔第 1 回合自动点烽火（BAT-001 §5.5）
		events.append({"kind": "beacon", "by": "qiao"})
	started = true
	_start_turn()
	compute_intents()


func _spots(key: String) -> Array:
	var out: Array = []
	for p: Array in map.get(key, []):
		out.append(Vector2i(p[0], p[1]))
	return out


## 放到第一个空的位置；位置用完了就放在离最后一个位置最近的空格。
func _place(u: Dictionary, spots: Array) -> void:
	for p: Vector2i in spots:
		if walkable(p) and unit_at(p).is_empty():
			u.pos = p
			units.append(u)
			return
	u.pos = nearest_free(spots[-1] if not spots.is_empty() else Vector2i(width / 2, height / 2))
	units.append(u)


func _make_hero(hero: Dictionary, role: String) -> Dictionary:
	var hero_gen := int(hero.gen)
	var type := "elder2" if role == "elder" and hero_gen == 2 else "hero"
	var u := _make_unit(type, "ally", role)
	u.hero = hero.duplicate()
	u.ability = String(cfg.hero_abilities.get(str(hero_gen), ""))
	if u.ability == "builder":
		u.builder = true
	return u


func _make_unit(type: String, side: String, role: String, roster_id: String = "") -> Dictionary:
	var stats: Dictionary = cfg.units[type]
	var hp := int(stats.hp)
	if side == "enemy" and input.get("story_mode", false):
		hp = maxi(1, hp - 1)  # 剧情模式：海寇 HP −1（BAT-001 §8）
	var move := int(stats.get("move", 0))
	if side == "ally" and int(input.get("hungry", 0)) > 0:
		move = maxi(1, move - 1)  # 饥饿：守军移动 −1（WORK-001 §3）
	var r: Array = stats.get("range", [0, 0])
	var u := {
		"uid": next_uid, "type": type, "side": side, "role": role, "roster_id": roster_id,
		"hp": hp, "max_hp": hp, "atk": int(stats.get("atk", 0)), "move": move,
		"rmin": int(r[0]), "rmax": int(r[1]), "pos": NOWHERE, "from_pos": NOWHERE,
		"alive": true, "retreated": false, "moved": false, "acted": false,
		"carrying": 0, "carried_by": 0, "guided": false,
		"brace": int(stats.get("brace", 0)), "brace_used": false, "countered": false,
		"builder": stats.get("builder", false), "guide": stats.get("guide", false),
		"free_beacon": stats.get("free_beacon", false), "hits_boats": stats.get("hits_boats", false),
		"no_counter": stats.get("no_counter", false), "ai": String(stats.get("ai", "")),
		"structure_mult": int(stats.get("structure_mult", 1)), "aura": int(stats.get("aura", 0)),
		"barriers_left": int(cfg.abilities.barriers_per_battle), "ability": "", "hero": {},
		"buff_atk": 0, "buff_move": 0,
	}
	next_uid += 1
	return u


# ---------- 查询 ----------

func tide_at(t: int) -> String:
	return tide_cycle[(tide_start + t - 1) % tide_cycle.size()]


func tide() -> String:
	return tide_at(turn)


## 潮汐条：从这一回合起的 n 步。
func tide_forecast(n: int = 4) -> Array:
	var out: Array = []
	for i in n:
		out.append(tide_at(turn + i))
	return out


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func terrain_char(p: Vector2i) -> String:
	return rows[p.y][p.x]


func terrain_name(p: Vector2i) -> String:
	return String(cfg.terrain.get(terrain_char(p), {}).get("name", "field"))


func is_sea(p: Vector2i) -> bool:
	return terrain_char(p) == "~"


func is_safe(p: Vector2i) -> bool:
	return terrain_char(p) == "F"


func is_beach(p: Vector2i) -> bool:
	return terrain_char(p) == "s"


func is_tower(p: Vector2i) -> bool:
	return terrain_char(p) == "T"


func is_flooded(p: Vector2i) -> bool:
	return cfg.terrain.get(terrain_char(p), {}).get("floods", false) and tide() in cfg.tides.flooded


## 墙（HP > 0）、关着的门、障碍挡路；废墟可以走。
func blocked(p: Vector2i) -> bool:
	if barriers.has(p):
		return true
	var s: Dictionary = structures.get(p, {})
	if s.is_empty() or int(s.hp) <= 0:
		return false
	return s.kind == "wall" or not s.open


func walkable(p: Vector2i) -> bool:
	return in_bounds(p) and not is_sea(p) and not is_flooded(p) and not blocked(p)


func step_cost(p: Vector2i) -> int:
	return int(cfg.terrain.get(terrain_char(p), {}).get("cost", 1))


func on_map(u: Dictionary) -> bool:
	return u.alive and not u.retreated and int(u.carried_by) == 0


func unit_at(p: Vector2i) -> Dictionary:
	for u in units:
		if on_map(u) and u.pos == p:
			return u
	return {}


func unit_by_uid(uid: int) -> Dictionary:
	for u in units:
		if int(u.uid) == uid:
			return u
	return {}


func allies_on_map() -> Array:
	return units.filter(func(u: Dictionary) -> bool: return on_map(u) and u.side == "ally")


func enemies_on_map() -> Array:
	return units.filter(func(u: Dictionary) -> bool: return on_map(u) and u.side == "enemy")


func villagers_outside() -> Array:
	return units.filter(func(u: Dictionary) -> bool: return u.alive and u.side == "villager")


## 还没从屋里出来的乡亲。
func villagers_pending() -> int:
	var n := 0
	for i in range(villager_batches, villager_schedule.size()):
		n += int(villager_schedule[i])
	return n


func hero_unit() -> Dictionary:
	for u in units:
		if on_map(u) and u.role == "hero":
			return u
	return {}


func neighbors(p: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		if in_bounds(p + d):
			out.append(p + d)
	return out


static func dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func nearest_free(from: Vector2i) -> Vector2i:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if walkable(p) and unit_at(p).is_empty():
			return p
		for n in neighbors(p):
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	return from


# ---------- 寻路 ----------

## 能不能经过某格：守军和乡亲能穿过自己人，海寇能穿过海寇；谁都不能穿过对方。
func _can_pass(u: Dictionary, p: Vector2i) -> bool:
	if not walkable(p):
		return false
	var other := unit_at(p)
	if other.is_empty() or other.uid == u.uid:
		return true
	if u.side == "enemy":
		return other.side == "enemy"
	return other.side != "enemy"


## 从 u 出发的花费表（不限步数）：格子 → [花费, 上一格]。
func _costs(u: Dictionary, from: Vector2i) -> Dictionary:
	var best := {from: [0, NOWHERE]}
	var open: Array[Vector2i] = [from]
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if best[open[i]][0] < best[open[bi]][0]:
				bi = i
		var p: Vector2i = open[bi]
		open.remove_at(bi)
		for n in neighbors(p):
			if not _can_pass(u, n):
				continue
			var c: int = best[p][0] + step_cost(n)
			if not best.has(n) or c < best[n][0]:
				best[n] = [c, p]
				open.append(n)
	return best


static func _path_to(costs: Dictionary, goal_pos: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var p := goal_pos
	while costs.has(p) and costs[p][1] != NOWHERE:
		path.push_front(p)
		p = costs[p][1]
	return path


## 这一回合能走到的空格（含原地）：格子 → 花费。
func move_range(u: Dictionary) -> Dictionary:
	var budget := int(u.move) + int(u.buff_move)
	var out := {}
	var costs := _costs(u, u.pos)
	for p: Vector2i in costs:
		var c: int = costs[p][0]
		if c <= budget and (p == u.pos or unit_at(p).is_empty()):
			out[p] = c
	return out


## 沿路走，最多花 budget；停在最后一个空着、没被占用的格子。
func _walk(u: Dictionary, path: Array[Vector2i], budget: int, reserved: Dictionary) -> Array[Vector2i]:
	var walked: Array[Vector2i] = []
	var spent := 0
	var stop := 0
	for i in path.size():
		spent += step_cost(path[i])
		if spent > budget:
			break
		walked.append(path[i])
		var other := unit_at(path[i])
		if (other.is_empty() or other.uid == u.uid) and not reserved.has(path[i]):
			stop = walked.size()
	return walked.slice(0, stop)


# ---------- 伤害 ----------

func attack_power(attacker: Dictionary) -> int:
	var power := int(attacker.atk) + int(attacker.buff_atk)
	if attacker.side == "enemy":
		for c in enemies_on_map():
			if int(c.aura) > 0 and c.uid != attacker.uid and dist(c.pos, attacker.pos) == 1:
				power += int(c.aura)  # 首领旁边的海寇攻击 +1
	return power


## 打到单位身上的伤害：攻击力；站在敌台上的 −1。
func damage_to_unit(attacker: Dictionary, target: Dictionary) -> int:
	var power := attack_power(attacker)
	if is_tower(target.pos):
		power -= int(cfg.tower.damage_reduction)
	return maxi(0, power)


func damage_to_structure(attacker: Dictionary) -> int:
	return attack_power(attacker) * int(attacker.structure_mult)


func _hurt(u: Dictionary, amount: int) -> void:
	if amount <= 0 or not u.alive:
		return
	u.hp = int(u.hp) - amount
	if int(u.hp) <= 0:
		u.hp = 0
		_fall(u)


func _fall(u: Dictionary) -> void:
	u.alive = false
	match u.side:
		"enemy":
			raiders_defeated += 1
			_drop(u)
		"villager":
			lost += 1
			events.append({"kind": "lantern", "group": "villager"})
		"ally":
			match u.role:
				"hero":
					hero_died = true
					events.append({"kind": "hero_death"})
				"elder":
					elder_retired = true  # 长辈重伤撤下，不死、不计灯（BAT-001 §5.3）
					events.append({"kind": "retire"})
				"reinforcement":
					pass
				_:
					events.append({"kind": "lantern", "group": "defender"})
		"npc":
			events.append({"kind": "npc_down"})


## 抓着乡亲的海寇倒下：乡亲落在原地，接着往安全区走。
func _drop(carrier: Dictionary) -> void:
	if int(carrier.carrying) == 0:
		return
	var v := unit_by_uid(int(carrier.carrying))
	carrier.carrying = 0
	if v.is_empty():
		return
	v.carried_by = 0
	v.pos = carrier.pos if unit_at(carrier.pos).is_empty() else nearest_free(carrier.pos)


# ---------- 玩家行动 ----------

func can_command(u: Dictionary) -> bool:
	return started and not over and on_map(u) and u.side == "ally" and not u.acted


func move_unit(u: Dictionary, p: Vector2i) -> bool:
	if not can_command(u) or u.moved or not move_range(u).has(p):
		return false
	u.from_pos = u.pos
	u.pos = p
	u.moved = true
	compute_intents()
	return true


## 撤销移动：还没做动作之前可以（BAT-001 §11）。
func undo_move(u: Dictionary) -> bool:
	if not can_command(u) or not u.moved or not unit_at(u.from_pos).is_empty():
		return false
	u.pos = u.from_pos
	u.moved = false
	compute_intents()
	return true


## 这个单位现在能做的动作。
func actions_for(u: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if not can_command(u):
		return out
	if not targets_for(u, "attack").is_empty():
		out.append("attack")
	if u.builder and not targets_for(u, "repair").is_empty():
		out.append("repair")
	if u.builder and int(u.barriers_left) > 0 and not targets_for(u, "barrier").is_empty():
		out.append("barrier")
	if not targets_for(u, "gate").is_empty():
		out.append("gate")
	if u.guide and not _adjacent_villagers(u.pos).is_empty():
		out.append("guide")
	if beacons.has(u.pos) and int(beacons[u.pos]) == 0:
		out.append("beacon")
	if u.ability == "inspire" and not inspire_used:
		out.append("inspire")
	if is_safe(u.pos):
		out.append("retreat")
	out.append("wait")
	return out


## 需要选目标的动作能选哪些格子。
func targets_for(u: Dictionary, action: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	match action:
		"attack":
			if int(u.atk) <= 0 or int(u.rmax) <= 0:
				return out
			var bonus := int(cfg.tower.range_bonus) if is_tower(u.pos) and int(u.rmax) > 1 else 0
			for e in enemies_on_map():
				var d := dist(u.pos, e.pos)
				if d < int(u.rmin) or d > int(u.rmax) + bonus:
					continue
				if e.ai == "boat" and not u.hits_boats:
					continue  # 只有弩手打得到弓箭船
				out.append(e.pos)
		"repair":
			for n in neighbors(u.pos):
				var s: Dictionary = structures.get(n, {})
				if not s.is_empty() and int(s.hp) > 0 and int(s.hp) < int(s.max):
					out.append(n)
		"barrier":
			for n in neighbors(u.pos):
				if walkable(n) and unit_at(n).is_empty() and not is_safe(n) and not structures.has(n):
					out.append(n)
		"gate":
			for n in neighbors(u.pos):
				var s: Dictionary = structures.get(n, {})
				if not s.is_empty() and s.kind == "gate" and int(s.hp) > 0 and (s.open == false or unit_at(n).is_empty()):
					out.append(n)
	return out


func do_action(u: Dictionary, action: String, target: Vector2i = NOWHERE) -> bool:
	if not action in actions_for(u):
		return false
	if action in ["attack", "repair", "barrier", "gate"] and not target in targets_for(u, action):
		return false
	var uses_action := true
	match action:
		"attack":
			var e := unit_at(target)
			_hurt(e, damage_to_unit(u, e))
		"repair":
			var s: Dictionary = structures[target]
			s.hp = mini(int(s.max), int(s.hp) + int(cfg.abilities.repair))
		"barrier":
			barriers[target] = int(cfg.barrier_hp)
			u.barriers_left = int(u.barriers_left) - 1
		"gate":
			structures[target].open = not structures[target].open
		"guide":
			for v in _adjacent_villagers(u.pos):
				v.guided = true
		"beacon":
			beacons[u.pos] = turn
			events.append({"kind": "beacon", "by": "ally"})
			uses_action = not u.free_beacon  # 信使点烽火不占动作
		"inspire":
			inspire_used = true
			uses_action = false
			for a in allies_on_map():
				if dist(a.pos, u.pos) <= int(cfg.abilities.inspire_range):
					a.buff_atk = int(a.buff_atk) + int(cfg.abilities.inspire_atk)
					a.buff_move = int(a.buff_move) + int(cfg.abilities.inspire_move)
		"retreat":
			u.retreated = true
		"wait":
			pass
	if uses_action:
		u.acted = true
	compute_intents()
	_check_end()
	return true


func _adjacent_villagers(p: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n in neighbors(p):
		var v := unit_at(n)
		if not v.is_empty() and v.side == "villager":
			out.append(v)
	return out


# ---------- 回合 ----------

func end_turn() -> void:
	if over or not started:
		return
	_villager_phase()
	if _check_end():
		return
	_enemy_phase()
	if _check_end():
		return
	if turn >= turns:
		_finish()
		return
	turn += 1
	_tide_changes()
	if _check_end():
		return
	_start_turn()
	if _check_end():
		return
	compute_intents()


func _start_turn() -> void:
	for u in units:
		u.moved = false
		u.acted = false
		u.guided = false
		u.buff_atk = 0
		u.buff_move = 0
		u.from_pos = u.pos
	while villager_batches < mini(turn, villager_schedule.size()):
		for i in int(villager_schedule[villager_batches]):
			_place(_make_unit("villager", "villager", ""), _spots("villagers"))
		villager_batches += 1
	var landed := 0
	for wave: Dictionary in bcfg.get("waves", []):
		if int(wave.turn) == turn:
			for type: String in wave.units:
				if _spawn_enemy(type, wave):
					landed += 1
	if landed > 0:
		events.append({"kind": "landing", "count": landed})
	# 烽火点燃 3 回合后，援军从道路进来（BAT-001 §7）。
	for b: Vector2i in beacons:
		if int(beacons[b]) > 0 and turn == int(beacons[b]) + int(cfg.beacon.delay):
			for i in int(cfg.beacon.reinforcements):
				_place(_make_unit("reinforcement", "ally", "reinforcement"), _spots("reinforcements"))
			events.append({"kind": "reinforcements"})


func _spawn_enemy(type: String, wave: Dictionary) -> bool:
	var lo := int(wave.rows[0])
	var hi := int(wave.rows[1])
	var candidates: Array[Vector2i] = []
	var sea: bool = wave.get("sea", false)
	var columns: Array = range(width - 1, -1, -1) if sea else range(width)
	for x: int in columns:
		for y in range(lo, hi + 1):
			var p := Vector2i(x, y)
			if (is_sea(p) if sea else is_beach(p)) and unit_at(p).is_empty():
				candidates.append(p)
	if candidates.is_empty() and not sea:
		for y in range(lo, hi + 1):
			for x in range(width):
				var p := Vector2i(x, y)
				if is_beach(p):
					candidates.append(nearest_free(p))
					break
			if not candidates.is_empty():
				break
	if candidates.is_empty():
		return false
	var e := _make_unit(type, "enemy", "")
	e.pos = candidates[0]
	units.append(e)
	return true


## 乡亲阶段：离安全区近的先走；旁边有守军 +1，被引导或护乡 +2（BAT-001 §6）。
func _villager_phase() -> void:
	var safe_dist := _distance_to_safe()
	var list := villagers_outside().filter(func(v: Dictionary) -> bool: return on_map(v))
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(safe_dist.get(a.pos, FAR)) < int(safe_dist.get(b.pos, FAR)))
	for v: Dictionary in list:
		var bonus := 0
		for n in neighbors(v.pos):
			var a := unit_at(n)
			if a.is_empty() or a.side != "ally":
				continue
			bonus = maxi(bonus, int(cfg.abilities.escort_bonus))
			if a.ability == "protect":
				bonus = maxi(bonus, int(cfg.abilities.guide_bonus))
		if v.guided:
			bonus = maxi(bonus, int(cfg.abilities.guide_bonus))
		var budget := int(v.move) + bonus
		var costs := _costs(v, v.pos)
		var best: Vector2i = v.pos
		var best_far := int(safe_dist.get(v.pos, FAR))
		var best_cost := 0
		for p: Vector2i in costs:
			var c: int = costs[p][0]
			if c > budget or (p != v.pos and not unit_at(p).is_empty()):
				continue
			var far := 0 if is_safe(p) else int(safe_dist.get(p, FAR))
			if far < best_far or (far == best_far and c < best_cost):
				best = p
				best_far = far
				best_cost = c
		v.pos = best
		if is_safe(v.pos):
			v.alive = false
			saved += 1
			events.append({"kind": "saved"})


## 每格到最近安全区的步数（不看人，只看路）；走不通时按直线距离估。
func _distance_to_safe() -> Dictionary:
	var out := {}
	var queue: Array[Vector2i] = []
	for y in height:
		for x in width:
			var p := Vector2i(x, y)
			if is_safe(p):
				out[p] = 0
				queue.append(p)
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for n in neighbors(p):
			if not out.has(n) and walkable(n):
				out[n] = int(out[p]) + 1
				queue.append(n)
	for y in height:
		for x in width:
			var p := Vector2i(x, y)
			if not out.has(p):
				out[p] = 1000 + _manhattan_to_safe(p)
	return out


func _manhattan_to_safe(p: Vector2i) -> int:
	var best := FAR
	for y in height:
		for x in width:
			if is_safe(Vector2i(x, y)):
				best = mini(best, dist(p, Vector2i(x, y)))
	return best


func _enemy_phase() -> void:
	for a in units:
		a.brace_used = false
		a.countered = false
	# 峤叔先打旁边最弱的海寇（BAT-001 §5.5）。
	for q in units.filter(func(u: Dictionary) -> bool: return on_map(u) and u.side == "npc"):
		var near := enemies_on_map().filter(func(e: Dictionary) -> bool: return dist(e.pos, q.pos) == 1 and e.ai != "boat")
		near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.hp) < int(b.hp))
		if not near.is_empty():
			_hurt(near[0], damage_to_unit(q, near[0]))
	var order := enemies_on_map()
	for e: Dictionary in order:
		if not on_map(e):
			continue
		_execute(e, plan_enemy(e, {}))
		if over:
			return


func _execute(e: Dictionary, plan: Dictionary) -> void:
	for step: Vector2i in plan.path:
		e.pos = step
		if int(e.carrying) != 0:
			unit_by_uid(int(e.carrying)).pos = step
		# 架枪：第一个走到枪兵旁边的海寇受 2 点伤害并停下（BAT-001 §5.1）。
		var braced := false
		for a in allies_on_map():
			if int(a.brace) > 0 and not a.brace_used and dist(a.pos, e.pos) == 1:
				a.brace_used = true
				_hurt(e, int(a.brace))
				braced = true
				break
		if braced or not e.alive:
			break
	if not e.alive:
		return
	match plan.act:
		"grab":
			var v := unit_by_uid(int(plan.target_uid))
			if not v.is_empty() and on_map(v) and dist(v.pos, e.pos) == 1:
				e.carrying = v.uid
				v.carried_by = e.uid
				v.pos = e.pos
		"attack", "shoot":
			var t := unit_by_uid(int(plan.target_uid))
			if t.is_empty() or not on_map(t):
				return
			var d := dist(t.pos, e.pos)
			if d < int(e.rmin) or d > int(e.rmax):
				return
			_hurt(t, damage_to_unit(e, t))
			# 反击：近战守军活着就以全额攻击力反击，每个海寇阶段一次。
			if t.alive and t.side == "ally" and d == 1 and int(t.rmax) == 1 and int(t.atk) > 0 \
					and not t.no_counter and not t.countered:
				t.countered = true
				_hurt(e, damage_to_unit(t, e))
		"smash":
			var p: Vector2i = plan.target
			if dist(p, e.pos) != 1:
				return
			if barriers.has(p):
				barriers[p] = int(barriers[p]) - damage_to_structure(e)
				if int(barriers[p]) <= 0:
					barriers.erase(p)
			elif structures.has(p):
				var s: Dictionary = structures[p]
				s.hp = maxi(0, int(s.hp) - damage_to_structure(e))


## 潮汐前进一步之后：滩涂被淹时把上面的人推到最近的干格、受 1 点伤害；退潮时，抓着乡亲停在海滩的船开走。
func _tide_changes() -> void:
	var now := tide()
	if now in cfg.tides.flooded:
		for u in units.duplicate():
			if not on_map(u) or u.ai == "boat":
				continue
			if is_flooded(u.pos):
				u.pos = nearest_free(u.pos)
				if int(u.carrying) != 0:
					unit_by_uid(int(u.carrying)).pos = u.pos
				_hurt(u, int(cfg.flood_damage))
	if now == "falling":
		for e in enemies_on_map():
			if int(e.carrying) != 0 and is_beach(e.pos):
				var v := unit_by_uid(int(e.carrying))
				e.retreated = true  # 船开走了，不算击败
				if not v.is_empty():
					v.carried_by = 0
					v.alive = false
					lost += 1
					events.append({"kind": "lantern", "group": "villager"})


func _check_end() -> bool:
	if over:
		return true
	if started and ((villagers_outside().is_empty() and villagers_pending() == 0) or allies_on_map().is_empty()):
		_finish()
	return over


func _finish() -> void:
	over = true
	events.append({"kind": "end"})


# ---------- 海寇的意图 ----------

## 每个海寇按顺序算这一回合要做什么，前面的人要去的格子后面的人不能再去。玩家每动一步都重算。
func compute_intents() -> void:
	intents.clear()
	if over:
		return
	var reserved := {}
	for e in enemies_on_map():
		var plan := plan_enemy(e, reserved)
		if not plan.path.is_empty():
			reserved[plan.path[-1]] = true
		plan.hidden = _hidden_at_night(e)
		intents.append(plan)


## 夜战：离我方单位和敌台都超过 2 格的海寇，意图显示成“？”（BAT-001 §10.2）。
func _hidden_at_night(e: Dictionary) -> bool:
	if not bcfg.get("night", false):
		return false
	var sight := int(cfg.night_sight)
	for a in allies_on_map():
		if dist(a.pos, e.pos) <= sight:
			return false
	for y in height:
		for x in width:
			if is_tower(Vector2i(x, y)) and dist(Vector2i(x, y), e.pos) <= sight:
				return false
	return true


## 一个海寇的计划：{"uid", "path"（要走的格子，不含起点）, "act": "grab" | "attack" | "smash" | "shoot" | "carry" | "none",
## "target"（目标格）, "target_uid"}。
func plan_enemy(e: Dictionary, reserved: Dictionary) -> Dictionary:
	var plan := {"uid": e.uid, "path": [] as Array[Vector2i], "act": "none", "target": NOWHERE, "target_uid": 0, "hidden": false}
	if e.ai == "boat":
		return _plan_boat(e, plan)
	if int(e.carrying) != 0:
		return _plan_carry(e, plan, reserved)
	var order: Array[String] = []
	match e.ai:
		"structure":
			order = ["smash", "attack", "grab"]
		"hero":
			order = ["hero", "attack", "grab", "smash"]
		_:
			order = ["grab", "attack", "smash"]
	var costs := _costs(e, e.pos)
	for kind in order:
		var goal_plan := _plan_towards(e, kind, costs, reserved)
		if not goal_plan.is_empty():
			plan.merge(goal_plan, true)
			return plan
	return plan


## 朝某类目标走：找花费最少、能站上去动手的格子，走到预算为止；走到了就动手。
func _plan_towards(e: Dictionary, kind: String, costs: Dictionary, reserved: Dictionary) -> Dictionary:
	var targets: Array = []  # [目标格, 目标 uid]
	match kind:
		"grab":
			for v in villagers_outside():
				if on_map(v):
					targets.append([v.pos, v.uid])
		"attack":
			for a in units:
				if on_map(a) and (a.side == "ally" or a.side == "npc"):
					targets.append([a.pos, a.uid])
		"hero":
			var h := hero_unit()
			if not h.is_empty():
				targets.append([h.pos, h.uid])
		"smash":
			for p: Vector2i in structures:
				if int(structures[p].hp) > 0:
					targets.append([p, 0])
			for p: Vector2i in barriers:
				targets.append([p, 0])
	var best_cost := FAR
	var best_stand := NOWHERE
	var best_target: Array = []
	for t: Array in targets:
		for stand in neighbors(t[0]):
			if not costs.has(stand):
				continue
			var free: bool = stand == e.pos or (unit_at(stand).is_empty() and not reserved.has(stand))
			if not free:
				continue
			var c: int = costs[stand][0]
			if c < best_cost:
				best_cost = c
				best_stand = stand
				best_target = t
	if best_stand == NOWHERE:
		return {}
	var path := _walk(e, _path_to(costs, best_stand), int(e.move), reserved)
	var end: Vector2i = path[-1] if not path.is_empty() else e.pos
	var act := "none"
	if end == best_stand:
		act = {"grab": "grab", "attack": "attack", "hero": "attack", "smash": "smash"}[kind]
	return {"path": path, "act": act, "target": best_target[0], "target_uid": best_target[1]}


func _plan_carry(e: Dictionary, plan: Dictionary, reserved: Dictionary) -> Dictionary:
	plan.act = "carry"
	if is_beach(e.pos):
		return plan  # 停在海滩等退潮（ISSUE-001 BAT-02 临时做法）
	var costs := _costs(e, e.pos)
	var best := NOWHERE
	for p: Vector2i in costs:
		if is_beach(p) and unit_at(p).is_empty() and not reserved.has(p):
			if best == NOWHERE or costs[p][0] < costs[best][0]:
				best = p
	if best != NOWHERE:
		plan.path = _walk(e, _path_to(costs, best), int(cfg.carry_move), reserved)
		plan.target = best
	return plan


## 弓箭船：涨潮、高潮时射程里最弱的守军；够不到就沿海走近（最多 2 格）。
func _plan_boat(e: Dictionary, plan: Dictionary) -> Dictionary:
	if not tide() in cfg.tides.boats_shoot:
		return plan
	var spots: Array[Vector2i] = [e.pos]
	var seen := {e.pos: 0}
	var queue: Array[Vector2i] = [e.pos]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if int(seen[p]) >= int(e.move):
			continue
		for n in neighbors(p):
			if is_sea(n) and not seen.has(n) and (unit_at(n).is_empty()):
				seen[n] = int(seen[p]) + 1
				spots.append(n)
				queue.append(n)
	for spot in spots:
		var best: Dictionary = {}
		for a in allies_on_map():
			var d := dist(a.pos, spot)
			if d < int(e.rmin) or d > int(e.rmax):
				continue
			if best.is_empty() or int(a.hp) < int(best.hp) or (int(a.hp) == int(best.hp) and int(a.uid) < int(best.uid)):
				best = a
		if not best.is_empty():
			var path: Array[Vector2i] = []
			var p := spot
			while p != e.pos:
				path.push_front(p)
				var back := p
				for n in neighbors(p):
					if seen.has(n) and int(seen[n]) == int(seen[p]) - 1:
						back = n
						break
				p = back
			plan.path = path
			plan.act = "shoot"
			plan.target = best.pos
			plan.target_uid = best.uid
			return plan
	return plan


## 玩家结束回合时，这一个守军会受到多少伤害（危险提示用）。
func threat_to(uid: int) -> int:
	var total := 0
	for plan in intents:
		if int(plan.target_uid) == uid and plan.act in ["attack", "shoot"]:
			total += damage_to_unit(unit_by_uid(int(plan.uid)), unit_by_uid(uid))
	return total


# ---------- 结果 ----------

func result() -> Dictionary:
	var died := {}
	var lost_defenders := 0
	for u in units:
		if u.side == "ally" and not u.alive:
			if u.roster_id != "":
				died[u.roster_id] = true
			if u.role in ["roster", "teaching", "militia", "bonus"]:
				lost_defenders += 1
	var roster: Array = []
	for r: Dictionary in input.get("roster", []):
		if not died.has(r.id):
			roster.append(r.duplicate())
	for t: Dictionary in cfg.get("teaching", {}).get(battle_id, []):
		if not died.has(t.id) and not roster.any(func(r: Dictionary) -> bool: return r.id == t.id):
			roster.append(t.duplicate())
	var walls: Dictionary = input.get("wall_slots", {}).duplicate(true)
	for p: Vector2i in structures:
		var s: Dictionary = structures[p]
		if walls.has(s.slot):
			walls[s.slot].hp[int(s.index)] = int(s.hp)
	return {
		"battle_id": battle_id,
		"outcome": "held" if saved >= goal else "costly",
		"hero_died": hero_died,
		"elder_retired": elder_retired,
		"roster": roster,
		"defenders_lost": lost_defenders,
		"villagers_saved": saved,
		"villagers_lost": lost,
		"raiders_defeated": raiders_defeated,
		"wall_slots": walls,
		"seen_hints": seen_hints.duplicate(),
	}
