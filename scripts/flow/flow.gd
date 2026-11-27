extends Control
## 主流程画面：按 flow.json 的节点表一个一个走。
## 每个节点开始时自动存档（ISSUE-001 WORK-05 临时做法）；中途退出，继续时从这个节点的开头来。
## 模块场景只收输入、只交结果；存档、切场景、战后问接受还是重打都在这里做（TEAM-001 §4）。

const MENU_SCENE := "res://scenes/menu/menu.tscn"

var node: Dictionary = {}
var current: Node = null
## 这一场战斗的输入。重打时原样再用一次，所以战斗结果在玩家接受之前不写存档。
var battle_in: Dictionary = {}


func _ready() -> void:
	var start := Game.save.progress
	if FlowLogic.node_index(start) < 0:
		push_error("Unknown flow node: %s" % start)
		Game.go_to(MENU_SCENE)
		return
	_run.call_deferred(start)


func _run(id: String) -> void:
	node = FlowLogic.find_node(id)
	Game.save.progress = id
	Game.save_game()
	var save := Game.save
	match node.type:
		"story":
			_open(_scene("story", "story_stub"), {
				"scene_id": id,
				"version": FlowLogic.story_version(save, node),
				"key": FlowLogic.story_key(save, node),
				"gen": int(node.gen),
			}, _on_simple_done)
		"battle":
			battle_in = FlowLogic.battle_input(save, node)
			_open_battle()
		"work":
			_open(_scene("work", "work_fake"), FlowLogic.work_input(save, node), _on_work_done)
		"choice":
			_open(_scene("choice", "choice_stub"), FlowLogic.choice_input(save, node), _on_choice_done)
		"naming":
			if ResourceLoader.exists(_path("naming")):
				_open(_path("naming"), FlowLogic.naming_input(save, node), _on_naming_done)
			else:
				FlowLogic.apply_default_name(save, int(node.gen))
				_advance()
		"event":
			# 事件马上生效，再给玩家看说明；这时退出，读档回到事件之前，不会重复生效。
			var notice := FlowLogic.event_notice(id, FlowLogic.apply_event(save, id))
			if notice.is_empty():
				_advance()
			else:
				notice.merge({"scene_id": id, "gen": int(node.gen)})
				_open(_scene("story", "story_stub"), notice, _on_simple_done)
		"ending":
			if ResourceLoader.exists(_path("ending")):
				_open(_path("ending"), {"save": save.duplicate(true)}, _on_simple_done)
			else:
				_open(_path("story_stub"), {"scene_id": id, "version": "", "key": "END_STUB"}, _on_simple_done)
		_:
			push_error("Unknown node type: %s" % node.type)
			_advance()


func _advance() -> void:
	var next := FlowLogic.next_id(node.id)
	if next == "":
		Game.save.progress = "done"
		Game.save_game()
		var after := _path("after_ending")
		if after != "":
			Game.go_to(after)
		return
	_run.call_deferred(next)


# ---------- 打开模块 ----------

func _path(key: String) -> String:
	return Rules.get_value("flow.scenes." + key, "")


## 真模块存在就用真的，否则用顶替的（BAT、WORK 合并前）。
func _scene(real_key: String, fallback_key: String) -> String:
	var real := _path(real_key)
	if ResourceLoader.exists(real) or fallback_key == "":
		return real
	return _path(fallback_key)


func _open(scene_path: String, input: Dictionary, on_done: Callable) -> void:
	_clear()
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Cannot load scene: %s" % scene_path)
		# 不留一块空白画面：回主菜单（存档停在这个节点的开头）。
		Game.go_to.call_deferred(MENU_SCENE)
		return
	current = packed.instantiate()
	current.setup(input)
	current.finished.connect(on_done, CONNECT_ONE_SHOT)
	add_child(current)


func _clear() -> void:
	for child in get_children():
		child.queue_free()
	current = null


# ---------- 各类节点结束 ----------

func _on_simple_done(_result: Dictionary) -> void:
	_advance()


func _on_work_done(result: Dictionary) -> void:
	FlowLogic.apply_work(Game.save, result)
	_advance()


func _on_choice_done(result: Dictionary) -> void:
	FlowLogic.apply_choice(Game.save, node.id, result)
	_advance()


func _on_naming_done(result: Dictionary) -> void:
	FlowLogic.apply_naming(Game.save, int(node.gen), result)
	_advance()


func _open_battle() -> void:
	_open(_scene("battle", "battle_fake"), battle_in.duplicate(true), _on_battle_done)


func _on_battle_done(result: Dictionary) -> void:
	if FlowLogic.must_retry(result):
		_show_battle_panel(result, true)
	else:
		_show_battle_panel(result, false)


## 战后：显示结果，问接受还是重打（BAT-001 §8）。forced = 第三代主角阵亡，只能重打。
func _show_battle_panel(result: Dictionary, forced: bool) -> void:
	_clear()
	var lines := PackedStringArray()
	lines.append(Game.text("FLOW_RESULT_HELD" if result.outcome == "held" else "FLOW_RESULT_COSTLY"))
	lines.append(Game.text("FLOW_RESULT_DETAIL").format({
		"saved": result.villagers_saved, "villagers": result.villagers_lost,
		"defenders": result.defenders_lost}))
	if result.hero_died:
		lines.append(Game.text("FLOW_HERO_DIED"))
	if forced:
		lines.append(Game.text("FLOW_FORCED_RETRY"))
	var box := DevUI.panel(self, "\n".join(lines))
	if not forced:
		DevUI.button(box, "FLOW_ACCEPT", func() -> void:
			FlowLogic.apply_battle(Game.save, battle_in, result)
			_advance())
	DevUI.button(box, "FLOW_RETRY", _open_battle)
