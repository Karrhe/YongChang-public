class_name Contract
extends RefCounted
## 模块接口 v2（TEAM-001 §4）的字段检查。每个检查函数返回问题列表，空 = 合格。
## 战斗、劳作的测试都可以用它检查自己的 result。

const BATTLE_IDS := ["battle_1", "battle_2", "battle_3", "battle_4", "battle_5",
	"battle_6", "battle_7", "battle_8", "battle_9"]
const WORK_IDS := ["after_battle_1", "after_battle_2", "after_battle_4",
	"after_battle_5", "after_battle_7", "after_battle_8"]
const WALL_SLOT_IDS := ["A1", "A2", "A3", "B1", "B2", "B3", "C1", "C2", "C3",
	"gate_A", "gate_B", "gate_C"]
const WALL_TYPES := ["none", "fence", "stone"]
const UNIT_TYPES := ["spearman", "crossbow", "craftsman", "courier"]
const OUTCOMES := ["held", "costly"]
const STORY_KEY_SLOTS := ["start", "end", "hero_death"]

const BATTLE_INPUT_KEYS := {
	"battle_id": TYPE_STRING, "roster": TYPE_ARRAY, "bonus_defenders": TYPE_INT,
	"wall_slots": TYPE_DICTIONARY, "hungry": TYPE_INT, "story_mode": TYPE_BOOL,
	"seen_hints": TYPE_ARRAY, "story_keys": TYPE_DICTIONARY,
}
const BATTLE_RESULT_KEYS := {
	"battle_id": TYPE_STRING, "outcome": TYPE_STRING, "hero_died": TYPE_BOOL,
	"elder_retired": TYPE_BOOL, "roster": TYPE_ARRAY, "defenders_lost": TYPE_INT,
	"villagers_saved": TYPE_INT, "villagers_lost": TYPE_INT, "raiders_defeated": TYPE_INT,
	"wall_slots": TYPE_DICTIONARY, "seen_hints": TYPE_ARRAY,
}
const WORK_KEYS := {
	"work_id": TYPE_STRING, "gen": TYPE_INT, "people": TYPE_INT, "rice": TYPE_INT,
	"materials": TYPE_INT, "hungry": TYPE_INT, "roster": TYPE_ARRAY,
	"wall_slots": TYPE_DICTIONARY, "granary_used": TYPE_BOOL,
}


static func check_battle_input(input: Dictionary) -> PackedStringArray:
	var errors := _check_keys("battle input", input, BATTLE_INPUT_KEYS)
	if not input.has("hero") or not input.has("elder"):
		errors.append("battle input: hero and elder must be present (null allowed)")
	errors.append_array(_check_hero("hero", input.get("hero")))
	errors.append_array(_check_hero("elder", input.get("elder")))
	if not input.get("battle_id") in BATTLE_IDS:
		errors.append("battle input: unknown battle_id %s" % input.get("battle_id"))
	errors.append_array(_check_roster(input.get("roster", [])))
	errors.append_array(_check_walls(input.get("wall_slots", {})))
	var keys: Variant = input.get("story_keys", {})
	if keys is Dictionary:
		for slot: String in keys:
			if not slot in STORY_KEY_SLOTS:
				errors.append("battle input: unknown story_keys slot %s" % slot)
	return errors


static func check_battle_result(result: Dictionary) -> PackedStringArray:
	var errors := _check_keys("battle result", result, BATTLE_RESULT_KEYS)
	if not result.get("outcome") in OUTCOMES:
		errors.append("battle result: outcome must be held or costly")
	errors.append_array(_check_roster(result.get("roster", [])))
	errors.append_array(_check_walls(result.get("wall_slots", {})))
	return errors


static func check_work_input(input: Dictionary) -> PackedStringArray:
	var errors := _check_keys("work input", input, WORK_KEYS)
	if not input.get("work_id") in WORK_IDS:
		errors.append("work input: unknown work_id %s" % input.get("work_id"))
	errors.append_array(_check_roster(input.get("roster", [])))
	errors.append_array(_check_walls(input.get("wall_slots", {})))
	return errors


static func check_work_result(result: Dictionary) -> PackedStringArray:
	var errors := _check_keys("work result", result, WORK_KEYS)
	if typeof(result.get("goal_met")) != TYPE_BOOL:
		errors.append("work result: goal_met must be bool")
	errors.append_array(_check_roster(result.get("roster", [])))
	errors.append_array(_check_walls(result.get("wall_slots", {})))
	return errors


static func _check_keys(label: String, data: Dictionary, spec: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for key: String in spec:
		if not data.has(key):
			errors.append("%s: missing %s" % [label, key])
			continue
		var value: Variant = data[key]
		var ok: bool = typeof(value) == spec[key]
		if spec[key] == TYPE_ARRAY and value is PackedStringArray:
			ok = true
		if not ok:
			errors.append("%s: %s has wrong type" % [label, key])
	return errors


static func _check_hero(label: String, hero: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if hero == null:
		return errors
	if not hero is Dictionary or not int(hero.get("gen", 0)) in [1, 2, 3] \
			or not hero.get("role") in ["hero", "companion"]:
		errors.append("%s must be null or {gen: 1-3, role: hero|companion}" % label)
	return errors


static func _check_roster(roster: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not roster is Array:
		return errors
	var seen := {}
	for unit: Variant in roster:
		if not unit is Dictionary or not unit.get("type") in UNIT_TYPES \
				or typeof(unit.get("id")) != TYPE_STRING:
			errors.append("roster: bad unit %s" % str(unit))
		elif seen.has(unit.id):
			errors.append("roster: duplicate id %s" % unit.id)
		else:
			seen[unit.id] = true
	return errors


static func _check_walls(walls: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not walls is Dictionary:
		return errors
	for slot: String in walls:
		var wall: Variant = walls[slot]
		if not slot in WALL_SLOT_IDS:
			errors.append("wall_slots: unknown slot %s" % slot)
		elif not wall is Dictionary or not wall.get("type") in WALL_TYPES or not wall.get("hp") is Array:
			errors.append("wall_slots: bad slot %s" % slot)
	return errors
