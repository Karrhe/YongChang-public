class_name Choices
extends RefCounted
## 剧情选择 C1–C5 的规则部分（FLOW-3）：哪个选项能选、选了以后改存档。不碰界面，方便无头测试。
## 效果在 flow.json 的 choices（WORK-001 §7）；付不起时按 ISSUE-001 WORK-03 临时做法。

const PICKS := ["A", "B"]


static func effect(choice_id: String, pick: String) -> Dictionary:
	return Rules.get_value("flow.choices", {}).get(choice_id, {}).get(pick, {})


## 墙位（不含门）里还不是石墙的：可以筑石墙的地方。
static func buildable_slots(save: SaveData) -> Array:
	return _wall_slots(save).filter(func(slot: String) -> bool: return save.wall_slots[slot].type != "stone")


static func stone_slots(save: SaveData) -> Array:
	return _wall_slots(save).filter(func(slot: String) -> bool: return save.wall_slots[slot].type == "stone")


static func _wall_slots(save: SaveData) -> Array:
	return Rules.get_value("core.walls.slots", []).filter(func(slot: String) -> bool: return save.wall_slots.has(slot))


## 一个选项现在能不能选。返回 {"enabled", "reason"（不能选时的文字键）, "reason_args", "granary"（要开义仓）}。
static func option_state(save: SaveData, choice_id: String, pick: String, gen: int) -> Dictionary:
	var fx := effect(choice_id, pick)
	var state := {"enabled": true, "reason": "", "reason_args": {}, "granary": false}
	var rice := int(fx.get("rice", 0))
	if rice < 0 and save.rice + rice < 0:
		if save.granary_used[gen - 1]:
			return _blocked(state, "CHOICE_NEED_RICE")
		state.granary = true
	var people := int(fx.get("people", 0))
	if people < 0 and save.people + people < int(Rules.get_value("core.min_people", 4)):
		return _blocked(state, "CHOICE_NEED_PEOPLE")
	if save.roster.size() < int(fx.get("remove_units", 0)):
		return _blocked(state, "CHOICE_NEED_DEFENDER")
	if buildable_slots(save).size() < int(fx.get("build_stone", 0)):
		return _blocked(state, "CHOICE_NEED_WALL_SLOT")
	var demolish := int(fx.get("demolish_stone", 0))
	if stone_slots(save).size() < demolish:
		return _blocked(state, "CHOICE_NEED_STONE", {"count": demolish})
	return state


## 两个选项的状态。A、B 都不能选时，B 照样能选（粮食最低扣到 0，不开义仓）。
static func option_states(save: SaveData, choice_id: String, gen: int) -> Dictionary:
	var states := {}
	for pick: String in PICKS:
		states[pick] = option_state(save, choice_id, pick, gen)
	if not states.A.enabled and not states.B.enabled:
		states.B = {"enabled": true, "reason": "", "reason_args": {}, "granary": false}
	return states


static func _blocked(state: Dictionary, reason: String, args: Dictionary = {}) -> Dictionary:
	state.enabled = false
	state.reason = reason
	state.reason_args = args
	state.granary = false
	return state


## 选完以后要玩家在墙位里选几段：{"kind": "build" | "demolish" | "", "count", "slots"（候选）}。
static func slot_pick(save: SaveData, choice_id: String, pick: String) -> Dictionary:
	var fx := effect(choice_id, pick)
	if int(fx.get("build_stone", 0)) > 0:
		return {"kind": "build", "count": int(fx.build_stone), "slots": buildable_slots(save)}
	if int(fx.get("demolish_stone", 0)) > 0:
		return {"kind": "demolish", "count": int(fx.demolish_stone), "slots": stone_slots(save)}
	return {"kind": "", "count": 0, "slots": []}


## 把选择写进存档并算效果。result = {"pick": "A" | "B", "slots": [墙位 ID]}（slots 只在要选墙位时有）。
## 返回 {"granary": 这次开了义仓, "removed": 调走的单位}。
static func apply(save: SaveData, choice_id: String, result: Dictionary, gen: int) -> Dictionary:
	var pick: String = result.get("pick", "B")
	save.choices[choice_id] = pick
	var fx := effect(choice_id, pick)
	var out := {"granary": false, "removed": []}

	save.materials += int(fx.get("materials", 0))
	var rice := int(fx.get("rice", 0))
	if save.rice + rice < 0:
		# 粮不够：每代一次开宗族义仓，补到 0（WORK-001 §8）；开过了也最低到 0。
		if not save.granary_used[gen - 1]:
			save.granary_used[gen - 1] = true
			out.granary = true
		save.rice = 0
	else:
		save.rice += rice
	var people := int(fx.get("people", 0))
	save.people += people
	if people < 0:
		save.people = maxi(int(Rules.get_value("core.min_people", 4)), save.people)

	for type: String in fx.get("add_units", []):
		save.roster.append(save.new_unit(type))
	for i in int(fx.get("remove_units", 0)):
		var unit := _take_unit(save)
		if not unit.is_empty():
			out.removed.append(unit)

	var slots: Array = result.get("slots", [])
	for slot: String in slots.slice(0, int(fx.get("build_stone", 0))):
		if slot in buildable_slots(save):
			# 调守军筑的墙是一段完美咬合的砌石（REDESIGN-002 方案一）。
			save.wall_layouts[slot] = StoneWall.perfect()
			save.wall_slots[slot] = StoneWall.wall_full(save.wall_layouts[slot], save.wall_slots[slot].hp.size())
	for slot: String in slots.slice(0, int(fx.get("demolish_stone", 0))):
		if slot in stone_slots(save):
			save.wall_slots[slot] = {"type": "none", "hp": _filled(save.wall_slots[slot].hp.size(), 0)}
			save.wall_layouts.erase(slot)
	return out


## 调走一个守军：先找最后加入的 remove_prefer 兵种（枪兵、弩手），没有就调最后加入的。
static func _take_unit(save: SaveData) -> Dictionary:
	if save.roster.is_empty():
		return {}
	for type: String in Rules.get_value("flow.choices.remove_prefer", []):
		for i in range(save.roster.size() - 1, -1, -1):
			if save.roster[i].type == type:
				var unit := save.roster[i]
				save.roster.remove_at(i)
				return unit
	return save.roster.pop_back()


static func _filled(n: int, value: int) -> Array:
	var a := []
	a.resize(n)
	a.fill(value)
	return a


## 选项下面那行效果说明：按 flow.json 的效果拼出来，数值改了说明跟着变（REDESIGN-001 M7 以后不再手写）。
static func effect_text(id: String, pick: String) -> String:
	var fx := effect(id, pick)
	var parts := PackedStringArray()
	for key: String in ["materials", "rice", "people"]:
		var n := int(fx.get(key, 0))
		if n != 0:
			parts.append(Game.text("CHOICE_FX_" + key).format({"n": ("+%d" % n) if n > 0 else ("−%d" % -n)}))
	for type: String in fx.get("add_units", []):
		parts.append(Game.text("CHOICE_FX_add_unit").format({"unit": Game.text("BAT_UNIT_" + type)}))
	if int(fx.get("remove_units", 0)) > 0:
		parts.append(Game.text("CHOICE_FX_remove_units").format({"n": int(fx.remove_units)}))
	if int(fx.get("build_stone", 0)) > 0:
		parts.append(Game.text("CHOICE_FX_build_stone").format({"n": int(fx.build_stone)}))
	if int(fx.get("demolish_stone", 0)) > 0:
		parts.append(Game.text("CHOICE_FX_demolish_stone").format({"n": int(fx.demolish_stone)}))
	var bonus: Dictionary = Rules.get_value("flow.bonus_defenders", {})
	if bonus.get("choice", "") == id and bonus.get("pick", "") == pick:
		parts.append(Game.text("CHOICE_FX_bonus").format({"n": int(bonus.get("count", 0))}))
	return Game.text("CHOICE_FX_none") if parts.is_empty() else Game.text("CHOICE_FX_SEPARATOR").join(parts)
