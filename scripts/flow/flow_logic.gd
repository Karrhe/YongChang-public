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


## 剧情节点在剧情表里的场景 ID，如 "G1-2_B"。
## goal_split 的节点再按这一代的城墙目标分 _met / _unmet（G2-6，剧本附录 D）。
static func story_key(save: SaveData, node: Dictionary) -> String:
	var key: String = node.id
	var version := story_version(save, node)
	if version != "":
		key += "_" + version
	if node.get("goal_split", false):
		key += "_met" if save.goal_met[int(node.gen) - 1] else "_unmet"
	return key


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
	# 海寇冲进安全区抢走的粮，扣到 0 为止（REDESIGN-001 M6）。
	save.rice = maxi(0, save.rice - int(result.get("rice_looted", 0)))
	save.seen_hints = PackedStringArray(result.seen_hints)
	save.wall_slots = result.wall_slots.duplicate(true)
	collapse_ruins(save)

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
	var loss := mini(int(result.villagers_lost) + roster_lost, int(Rules.get_value("core.max_people_loss_per_battle", 1 << 20)))
	save.people = maxi(min_people, save.people - loss)

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
		name = _fallback_lantern_name(save, group, gen, n, names)
	list.append({"key": key, "name": name, "gen": gen, "battle": battle_id})


## 名字表用完时：按“姓 + 老大…老十”生成（DRAFT-001 §1.1），跳过表里和已用过的名字；还用完就“无名”。
static func _fallback_lantern_name(save: SaveData, group: String, gen: int, n: int, names: Dictionary) -> String:
	var surnames: Array = names.get("fallback_surnames", [])
	var ranks: Array = names.get("fallback_ranks", [])
	if surnames.is_empty() or ranks.is_empty():
		return _tr(names.get("unnamed", ""))
	var taken := {}
	for g in range(1, 4):
		for grp in ["villager", "defender"]:
			for i in range(1, 31):
				var k := "%s%d_%02d" % [names.get(grp + "_prefix", ""), g, i]
				var t := _tr(k)
				if t != k:
					taken[t] = true
	for entry: Dictionary in save.lanterns_villager + save.lanterns_defender:
		taken[String(entry.name)] = true
	var start := 0 if group == "villager" else surnames.size() / 2
	for step in surnames.size() * ranks.size():
		var idx := start + step
		var candidate := String(surnames[idx % surnames.size()]) + String(ranks[(idx / surnames.size()) % ranks.size()])
		if not taken.has(candidate):
			return candidate
	return _tr(names.get("unnamed", ""))


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
		"wall_layouts": save.wall_layouts.duplicate(true),
		"stone_queue": Array(save.stone_queue),
		"stone_next": save.stone_next,
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
	save.wall_layouts = result.get("wall_layouts", save.wall_layouts).duplicate(true)
	save.stone_queue = PackedStringArray(result.get("stone_queue", Array(save.stone_queue)))
	save.stone_next = int(result.get("stone_next", save.stone_next))
	# 目标卡看这一代最后一个劳作阶段（第二代就是台风之前的那一次）。
	save.goal_met[gen - 1] = result.goal_met


# ---------- 选择、起名（FLOW-3） ----------

## 选择节点交给界面的输入：选择前的剧情、两个选项能不能选、选完要不要选墙位。
static func choice_input(save: SaveData, node: Dictionary) -> Dictionary:
	var id: String = node.id
	var gen := int(node.gen)
	var states := Choices.option_states(save, id, gen)
	var options := {}
	for pick: String in Choices.PICKS:
		var option: Dictionary = states[pick].duplicate()
		option["slot_pick"] = Choices.slot_pick(save, id, pick)
		option["after"] = Choices.effect(id, pick).get("after", []).duplicate()
		options[pick] = option
	return {
		"choice_id": id,
		"key": story_key(save, node),
		"gen": gen,
		"options": options,
		"wall_slots": save.wall_slots.duplicate(true),
		"granary_scene": Rules.get_value("flow.granary_scenes", {}).get(str(gen), ""),
	}


## 记下选择并算效果（Choices.apply）。pick 是 "A" / "B"，或界面交回的整份结果。
static func apply_choice(save: SaveData, choice_id: String, pick: Variant) -> Dictionary:
	var result: Dictionary = pick if pick is Dictionary else {"pick": pick}
	return Choices.apply(save, choice_id, result, int(find_node(choice_id).get("gen", 1)))


## 起名界面的输入（ISSUE-001 WORK-09 临时做法：1–4 个汉字，不能和固定角色、上一代主角重名）。
static func naming_input(save: SaveData, node: Dictionary) -> Dictionary:
	var gen := int(node.gen)
	var cfg: Dictionary = Rules.get_value("flow.naming", {})
	var taken := PackedStringArray()
	for key: String in cfg.get("reserved_keys", []):
		taken.append(_tr(key))
	for reserved: String in cfg.get("reserved_names", []):
		taken.append(reserved)
	for i in save.names.size():
		if i != gen - 2 and save.names[i] != "":
			taken.append(save.names[i])
	return {
		"gen": gen,
		"prompt_key": cfg.get("prompt_keys", {}).get(str(gen), ""),
		"default_name": default_name(gen),
		"max_chars": int(cfg.get("max_chars", 4)),
		"taken": taken,
		"ask_hammer": gen == int(cfg.get("hammer_gen", 2)),
		"default_hammer": _tr("HAMMER_DEFAULT"),
		"hammer_max_chars": int(cfg.get("hammer_max_chars", 12)),
	}


## 起名界面交回 {"name", "hammer"}：名字空着就用默认名字；刻字空着存空，显示时用默认刻字。
static func apply_naming(save: SaveData, gen: int, result: Dictionary) -> void:
	var name := String(result.get("name", "")).strip_edges()
	save.names[gen - 2] = name if name != "" else default_name(gen)
	if result.has("hammer"):
		save.hammer_text = String(result.hammer).strip_edges()


static func default_name(gen: int) -> String:
	return _tr(Rules.get_value("flow.default_name_keys", {}).get(str(gen), ""))


## 起名界面不存在时：用文本表里的默认名字。
static func apply_default_name(save: SaveData, gen: int) -> void:
	if save.names[gen - 2] == "":
		save.names[gen - 2] = default_name(gen)


# ---------- 规则事件 ----------

## 返回给说明文字用的数字（flow.json 的 notice.summary 按它们填空）。
static func apply_event(save: SaveData, event_id: String) -> Dictionary:
	var cfg: Dictionary = Rules.get_value("flow.events", {}).get(event_id, {})
	var values := {}
	match event_id:
		"gen1_to_gen2":
			# 材料折半（向下取整），再加王叔杲捐银（WORK-001 §6）。
			values.before = save.materials
			save.materials = int(floor(save.materials * float(cfg.get("materials_keep_fraction", 1.0))))
			values.half = save.materials
			values.bonus = int(cfg.get("materials_bonus", 0))
			save.materials += values.bonus
			values.after = save.materials
		"retire_elder":
			save.elder_retired = true
		"rollcall_1", "rollcall_2", "rollcall_3":
			# 每代最后一仗之后的点名（REDESIGN-002 方案一，负责人定每代一次）：这一代失去的人，按灯的顺序。
			var g := int(cfg.get("gen", 1))
			values.names = []
			for entry: Dictionary in save.lanterns_hero + save.lanterns_defender + save.lanterns_villager:
				if int(entry.gen) == g:
					values.names.append(String(entry.name))
			values.count = values.names.size()
			values.per_line = int(cfg.get("names_per_line", 4))
		"typhoon":
			# 每段墙按红缝掉 HP，咬住的墙不掉；门照旧掉 gate_hp_loss（REDESIGN-002 方案一）。
			values.gate = int(cfg.get("gate_hp_loss", 0))
			values.merge(typhoon(save, values.gate))
		"repair_after_battle_6":
			repair_walls(save)
		"gen2_to_gen3":
			values.loss = int(cfg.get("gate_hp_loss", 0))
			values.people = int(cfg.get("people_bonus", 0))
			# 三十年风化：每段墙按 work.puzzle.weathering 掉几格（预设，不随机）；门照旧掉 gate_hp_loss。
			values.weathered = weather(save)
			# 没有墙风化时不说“掉了石头”（QA-2 的 QA-009）。
			values.weather_text = _tr("EVT_WEATHER_SOME" if int(values.weathered) > 0 else "EVT_WEATHER_NONE") \
				.format({"n": values.weathered})
			damage_walls(save, values.loss, true)
			save.people += values.people
			if cfg.get("clear_roster", false):
				save.roster.clear()
		_:
			push_error("Unknown flow event: %s" % event_id)
	return values


## 事件生效后给玩家看的台词：先播 notice.story 的剧情场景，再加一句带数字的说明。没有 notice 时返回空表。
static func event_notice(event_id: String, values: Dictionary) -> Dictionary:
	var notice: Dictionary = Rules.get_value("flow.events", {}).get(event_id, {}).get("notice", {})
	if notice.is_empty():
		return {}
	var append: Array[Dictionary] = []
	if notice.get("rollcall", false):
		append.append(_narration_line(event_id, _tr("EVT_ROLLCALL_INTRO")))
		var names: Array = values.get("names", [])
		var per := maxi(1, int(values.get("per_line", 4)))
		for i in range(0, names.size(), per):
			var called := PackedStringArray()
			for n: String in names.slice(i, i + per):
				called.append(_tr("EVT_ROLLCALL_NAME").format({"name": n}))
			append.append(_narration_line(event_id, "".join(called)))
			append.append(_narration_line(event_id, _tr("EVT_ROLLCALL_SILENT")))
		append.append(_narration_line(event_id, _tr("EVT_ROLLCALL_END" if not names.is_empty() else "EVT_ROLLCALL_NONE")
			.format({"count": names.size()})))
		return {"keys": [], "append": append}
	var summary: String = notice.get("summary", "")
	if summary != "":
		append.append({"scene_id": event_id, "line_id": "", "speaker": "", "portrait": "",
			"text": _tr(summary).format(values), "narration": true})
	return {"keys": notice.get("story", []).duplicate(), "append": append}


## 每段墙和门（栅栏、石墙）每格 HP −amount，最低 0（ISSUE-001 WORK-04 临时做法：门也受影响）。gates_only = 只扣门。
static func damage_walls(save: SaveData, amount: int, gates_only: bool = false) -> void:
	for slot: String in save.wall_slots:
		var wall: Dictionary = save.wall_slots[slot]
		if wall.type == "none" or (gates_only and not slot.begins_with("gate_")):
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
		var full := wall_max(slot, wall)
		var hp: Array = wall.hp
		for i in hp.size():
			hp[i] = full


## 台风：有砖槽的墙每格 HP −（每条红缝 typhoon_per_seam），木栅栏全是红缝；没有砖槽的墙和门 −gate_loss。
## 返回 {"walls": 掉了 HP 的墙段数, "seams": 红缝总数}。
static func typhoon(save: SaveData, gate_loss: int) -> Dictionary:
	var hit := 0
	var seams := 0
	for slot: String in save.wall_slots:
		var wall: Dictionary = save.wall_slots[slot]
		if wall.type == "none":
			continue
		var loss := gate_loss
		if not slot.begins_with("gate_"):
			var layout: Dictionary = save.wall_layouts.get(slot, {})
			if layout.is_empty():
				pass  # 没有砖槽的墙（旧存档）：照旧掉 gate_loss
			elif layout.kind != wall.type:
				# 栅栏上正在砌、还没筑成的石墙：按栅栏算，每条竖线都是通缝。
				var all_seams := StoneWall.width() - 1
				seams += all_seams
				loss = int(Rules.get_value("work.puzzle.typhoon_per_seam", 2)) * all_seams
			else:
				seams += StoneWall.red_seams(layout).size()
				loss = StoneWall.typhoon_loss(layout)
		if loss > 0:
			hit += 1
		for i in wall.hp.size():
			wall.hp[i] = maxi(0, int(wall.hp[i]) - loss)
	return {"walls": hit, "seams": seams}


## 第三代开头的风化：每段筑成的墙按 work.puzzle.weathering 清掉几格，重算满 HP。返回掉了格子的墙段数。
static func weather(save: SaveData) -> int:
	var holes: Dictionary = Rules.get_value("work.puzzle.weathering", {})
	var n := 0
	for slot: String in save.wall_layouts:
		var wall: Dictionary = save.wall_slots.get(slot, {})
		if wall.is_empty() or wall.type == "none" or not holes.has(slot) or save.wall_layouts[slot].kind != wall.type:
			continue
		StoneWall.clear_cells(save.wall_layouts[slot], holes[slot])
		n += 1
		save.wall_slots[slot] = StoneWall.wall_after_loss(save.wall_layouts[slot], wall)
	return n


## 战后：被打成废墟（有格子 HP 0）的墙，砖槽最上面一行塌掉；剩下的还够筑成就留着（塌掉的格子 HP 1），不够就变回空地。
static func collapse_ruins(save: SaveData) -> void:
	for slot: String in save.wall_layouts:
		var wall: Dictionary = save.wall_slots.get(slot, {})
		if wall.is_empty() or wall.type == "none" or not wall.hp.any(func(h: Variant) -> bool: return int(h) <= 0):
			continue
		var layout: Dictionary = save.wall_layouts[slot]
		if layout.kind != wall.type:
			continue  # 栅栏上正在砌的石墙：栅栏照旧是废墟，砖槽不动
		StoneWall.clear_top_row(layout)
		save.wall_slots[slot] = StoneWall.wall_after_loss(layout, wall)


## 旧存档（砌石拼图之前）读进来以后补上砖槽：旧石墙当完美咬合的墙（旧规则下石墙本来就是满 HP 6），
## 旧栅栏当刚扎成的木桩。不看版本号：旧存档没写版本字段，读进来就是默认的 3（QA-2 的 QA-006、QA-007）。
static func migrate(save: SaveData) -> void:
	for slot: String in save.wall_slots:
		var wall: Dictionary = save.wall_slots[slot]
		if slot.begins_with("gate_") or wall.type == "none" or save.wall_layouts.has(slot):
			continue
		var layout := StoneWall.perfect() if wall.type == "stone" else StoneWall.fence()
		save.wall_layouts[slot] = layout
		wall.max = StoneWall.max_hp(layout)
		for i in wall.hp.size():
			wall.hp[i] = mini(int(wall.hp[i]), int(wall.max))
	save.version = 3


## 这段墙的满 HP：砌石筑成的墙记在 "max"，其余按类型查 core.walls.max_hp。
static func wall_max(slot: String, wall: Dictionary) -> int:
	return int(wall.get("max", max_hp(slot, wall.type)))


static func max_hp(slot: String, type: String) -> int:
	var key := type + ("_gate" if slot.begins_with("gate_") else "")
	return int(Rules.get_value("core.walls.max_hp", {}).get(key, 0))


static func _zeros(n: int) -> Array:
	var a := []
	a.resize(n)
	a.fill(0)
	return a


static func _narration_line(scene_id: String, text: String) -> Dictionary:
	return {"scene_id": scene_id, "line_id": "", "speaker": "", "portrait": "", "text": text, "narration": true}


static func _tr(key: String) -> String:
	return String(TranslationServer.translate(key))
