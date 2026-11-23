class_name FlowLogic
extends RefCounted
## 主流程的规则部分：不碰界面，方便无头测试。
## 节点表和数值来自 data/rules/flow.json；墙的 HP 来自 core.json。
## 只有 FLOW 写存档（TEAM-001 §4）：模块交结果，这里把结果写进 SaveData。


# ---------- 节点表 ----------

static func nodes() -> Array:
	return Rules.get_value("flow.nodes", [])


static func node_index(id: String) -> int:
	var list := nodes()
	for i in list.size():
		if list[i].id == id:
			return i
	return -1


static func find_node(id: String) -> Dictionary:
	var i := node_index(id)
	return nodes()[i] if i >= 0 else {}


## 下一个节点的 ID；已经是最后一个时返回 ""。
static func next_id(id: String) -> String:
	var i := node_index(id)
	var list := nodes()
	if i < 0 or i + 1 >= list.size():
		return ""
	return list[i + 1].id


# ---------- 新游戏 ----------

static func empty_walls() -> Dictionary:
	var walls := {}
	for slot: String in Rules.get_value("core.walls.slots", []):
		walls[slot] = {"type": "none", "hp": _zeros(int(Rules.get_value("core.walls.slot_cells", 2)))}
	for gate: String in Rules.get_value("core.walls.gates", []):
		walls[gate] = {"type": "none", "hp": _zeros(int(Rules.get_value("core.walls.gate_cells", 1)))}
	return walls


static func start_new_game(save: SaveData) -> void:
	save.wall_slots = empty_walls()
	save.progress = nodes()[0].id if not nodes().is_empty() else ""


# ---------- 剧情 ----------

## 剧情节点用哪个版本："" / "A" / "B"。A/B 看这一代主角是否存活。
static func story_version(save: SaveData, node: Dictionary) -> String:
	if not node.get("ab", false):
		return ""
	return "A" if save.hero_alive[int(node.gen) - 1] else "B"


## 剧情节点的文字键，如 "G1-2_B"。
static func story_key(save: SaveData, node: Dictionary) -> String:
	var version := story_version(save, node)
	return node.id if version == "" else "%s_%s" % [node.id, version]


# ---------- 战斗 ----------

## 当代出战的主角：主角活着用主角，否则同伴，都不在为 null（BAT-001 §5.3）。
static func current_hero(save: SaveData, gen: int) -> Variant:
	if save.hero_alive[gen - 1]:
		return {"gen": gen, "role": "hero"}
	if save.companion_alive[gen - 1]:
		return {"gen": gen, "role": "companion"}
	return null


## 长辈只进 battle_4（第一代）和 battle_9（第二代）；第一代长辈退休后不再出战。
static func elder_for(save: SaveData, battle_id: String) -> Variant:
	var elder_gen := int(Rules.get_value("flow.elder_battles", {}).get(battle_id, 0))
	if elder_gen == 0:
		return null
	if elder_gen == 1 and save.elder_retired:
		return null
	return current_hero(save, elder_gen)


static func battle_input(save: SaveData, node: Dictionary) -> Dictionary:
	var battle_id: String = node.id
	var keys := {"start": [], "end": [], "hero_death": []}
	var configured: Dictionary = Rules.get_value("flow.story_keys", {}).get(battle_id, {})
	for slot: String in configured:
		keys[slot] = configured[slot].duplicate()
	var bonus := 0
	var rule: Dictionary = Rules.get_value("flow.bonus_defenders", {})
	if rule.get("battle") == battle_id and save.choices.get(rule.get("choice")) == rule.get("pick"):
		bonus = int(rule.get("count", 0))
	return {
		"battle_id": battle_id,
		"hero": current_hero(save, int(node.gen)),
		"elder": elder_for(save, battle_id),
		"roster": save.roster.duplicate(true),
		"bonus_defenders": bonus,
		"wall_slots": save.wall_slots.duplicate(true),
		"hungry": save.hungry,
		"story_mode": save.story_mode,
		"seen_hints": Array(save.seen_hints),
		"story_keys": keys,
	}


## 第三代主角在 battle_7、battle_8 阵亡时不问玩家，直接重打（BAT-001 §8）。
static func must_retry(result: Dictionary) -> bool:
	return result.get("hero_died", false) \
		and result.get("battle_id") in Rules.get_value("flow.auto_retry_on_hero_death", [])


## 玩家接受战斗结果后写进存档。input 是这一场用的输入（用来知道谁出战、谁是主角）。
static func apply_battle(save: SaveData, input: Dictionary, result: Dictionary) -> void:
	var battle_id: String = result.battle_id
	var gen := int(find_node(battle_id).get("gen", 1))
	save.battle_results[battle_id] = result.outcome
	save.raiders_defeated += int(result.raiders_defeated)
	save.seen_hints = PackedStringArray(result.seen_hints)
	save.wall_slots = result.wall_slots.duplicate(true)

	# 名单上少了的人（训练过的守军和教学单位）：人口 −1（ISSUE-001 WORK-02 临时做法）。
	var survivors := {}
	for unit: Dictionary in result.roster:
		survivors[unit.id] = true
	var roster_lost := 0
	for unit: Dictionary in input.roster:
		if not survivors.has(unit.id):
			roster_lost += 1
	save.roster.assign(result.roster.duplicate(true))

	# 人口只扣失去的人，不加救下的村民（ISSUE-001 WORK-01 临时做法）。
	var min_people := int(Rules.get_value("core.min_people", 4))
	save.people = maxi(min_people, save.people - int(result.villagers_lost) - roster_lost)

	for i in int(result.villagers_lost):
		add_lantern(save, "villager", gen, battle_id)
	for i in int(result.defenders_lost):
		add_lantern(save, "defender", gen, battle_id)

	if result.hero_died and input.hero != null:
		var hero: Dictionary = input.hero
		var g := int(hero.gen)
		if hero.role == "hero":
			save.hero_alive[g - 1] = false
			save.death_battle[g - 1] = battle_id
		else:
			save.companion_alive[g - 1] = false
		save.lanterns_hero.append({"name": hero_name(save, hero), "gen": g, "battle": battle_id})


# ---------- 灯 ----------

## 乡亲和守军的灯：从当代的名字表按顺序取（BAT-001 §13）。
static func add_lantern(save: SaveData, group: String, gen: int, battle_id: String) -> void:
	var list: Array[Dictionary] = save.lanterns_villager if group == "villager" else save.lanterns_defender
	var n := 1
	for entry: Dictionary in list:
		if int(entry.gen) == gen:
			n += 1
	var names: Dictionary = Rules.get_value("flow.lantern_names", {})
	var key := "%s%d_%02d" % [names.get(group + "_prefix", ""), gen, n]
	var name := _tr(key)
	if name == key:
		name = _tr(names.get("unnamed", ""))
	list.append({"key": key, "name": name, "gen": gen, "battle": battle_id})


static func hero_name(save: SaveData, hero: Dictionary) -> String:
	var g := int(hero.gen)
	if hero.role == "hero" and g >= 2:
		return save.names[g - 2]
	var keys: Array = Rules.get_value("flow.hero_name_keys", {}).get(hero.role, [])
	return _tr(keys[g - 1]) if g - 1 < keys.size() else ""


# ---------- 劳作 ----------

static func work_input(save: SaveData, node: Dictionary) -> Dictionary:
	var gen := int(node.gen)
	return {
		"work_id": node.id,
		"gen": gen,
		"people": save.people,
		"rice": save.rice,
		"materials": save.materials,
		"hungry": save.hungry,
		"roster": save.roster.duplicate(true),
		"wall_slots": save.wall_slots.duplicate(true),
		"granary_used": save.granary_used[gen - 1],
	}


static func apply_work(save: SaveData, result: Dictionary) -> void:
	var gen := int(result.gen)
	save.people = int(result.people)
	save.rice = int(result.rice)
	save.materials = int(result.materials)
	save.hungry = int(result.hungry)
	save.roster.assign(result.roster.duplicate(true))
	save.wall_slots = result.wall_slots.duplicate(true)
	save.granary_used[gen - 1] = result.granary_used
	# 目标卡看这一代最后一个劳作阶段（第二代就是台风之前的那一次）。
	save.goal_met[gen - 1] = result.goal_met


# ---------- 选择、起名（界面和效果在 FLOW-3） ----------

static func apply_choice(save: SaveData, choice_id: String, pick: String) -> void:
	save.choices[choice_id] = pick


## 起名界面还没做（FLOW-3）：先用文本表里的默认名字。
static func apply_default_name(save: SaveData, gen: int) -> void:
	if save.names[gen - 2] == "":
		var key: String = Rules.get_value("flow.default_name_keys", {}).get(str(gen), "")
		save.names[gen - 2] = _tr(key)


# ---------- 规则事件 ----------

static func apply_event(save: SaveData, event_id: String) -> void:
	var cfg: Dictionary = Rules.get_value("flow.events", {}).get(event_id, {})
	match event_id:
		"gen1_to_gen2":
			# 材料折半（向下取整），再加王叔杲捐银（WORK-001 §6）。
			save.materials = int(floor(save.materials * float(cfg.get("materials_keep_fraction", 1.0))))
			save.materials += int(cfg.get("materials_bonus", 0))
		"retire_elder":
			save.elder_retired = true
		"typhoon":
			damage_walls(save, int(cfg.get("wall_hp_loss", 0)))
		"repair_after_battle_6":
			repair_walls(save)
		"gen2_to_gen3":
			damage_walls(save, int(cfg.get("wall_hp_loss", 0)))
			save.people += int(cfg.get("people_bonus", 0))
			if cfg.get("clear_roster", false):
				save.roster.clear()
		_:
			push_error("Unknown flow event: %s" % event_id)


## 每段墙和门（栅栏、石墙）每格 HP −amount，最低 0（ISSUE-001 WORK-04 临时做法：门也受影响）。
static func damage_walls(save: SaveData, amount: int) -> void:
	for slot: String in save.wall_slots:
		var wall: Dictionary = save.wall_slots[slot]
		if wall.type == "none":
			continue
		var hp: Array = wall.hp
		for i in hp.size():
			hp[i] = maxi(0, int(hp[i]) - amount)


## 所有已修的墙和门修满，包括废墟（ISSUE-001 WORK-04 临时做法）。
static func repair_walls(save: SaveData) -> void:
	for slot: String in save.wall_slots:
		var wall: Dictionary = save.wall_slots[slot]
		if wall.type == "none":
			continue
		var full := max_hp(slot, wall.type)
		var hp: Array = wall.hp
		for i in hp.size():
			hp[i] = full


static func max_hp(slot: String, type: String) -> int:
	var key := type + ("_gate" if slot.begins_with("gate_") else "")
	return int(Rules.get_value("core.walls.max_hp", {}).get(key, 0))


static func _zeros(n: int) -> Array:
	var a := []
	a.resize(n)
	a.fill(0)
	return a


static func _tr(key: String) -> String:
	return String(TranslationServer.translate(key))
