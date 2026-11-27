extends Node
## 调难度用：用新存档打一场战斗，每回合把地图打印出来。
## 运行：godot --headless --path . res://tests/battle/sim.tscn -- battle_2 [escort|passive] [quiet]
## 地图：F 安全区 W 墙 G 门 T 敌台 m 滩涂（涨水时 ~）r 路 h 屋 s 海滩；
## 单位：大写 = 守军（H 主角 S 枪兵 X 弩手 C 工匠 M 民兵 R 援军），v 乡亲 V 走不动的乡亲，e 海寇 a 斧手 b 弓箭船 k 首领，q 峤叔。


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var id := args[0] if args.size() > 0 else "battle_1"
	var policy := args[1] if args.size() > 1 else "escort"
	var quiet := args.has("quiet")
	Game.save_path = "user://sim_%d.tres" % OS.get_process_id()
	Game.new_game()
	FlowLogic.start_new_game(Game.save)
	var input := FlowLogic.battle_input(Game.save, FlowLogic.find_node(id))
	var s := BattleState.new()
	s.setup(input)
	s.start(s.default_picks())
	while not s.over:
		if not quiet:
			_print(s)
		if policy == "escort":
			BattleBot.play_turn(s)
		else:
			for a in s.allies_on_map():
				if "attack" in s.actions_for(a):
					s.do_action(a, "attack", s.targets_for(a, "attack")[0])
		s.end_turn()
	var r := s.result()
	print("%s %s: saved %d/%d lost %d outside %d looted %d defenders lost %d" % [id, policy, r.villagers_saved, s.goal,
		r.villagers_lost, s.villagers_outside().size(), s.looted, r.defenders_lost])
	Game.quit(0)


func _print(s: BattleState) -> void:
	var lines := PackedStringArray(["--- turn %d tide %s next %s" % [s.turn, s.tide(), s.tide_at(s.turn + 1)]])
	for y in s.height:
		var row := ""
		for x in s.width:
			var p := Vector2i(x, y)
			var ch := s.terrain_char(p)
			if ch == "m" and s.is_flooded(p):
				ch = "~"
			if s.structures.has(p):
				var st: Dictionary = s.structures[p]
				ch = "_" if int(st.hp) <= 0 else ("G" if st.kind == "gate" else ("W" if st.type == "stone" else "w"))
			var u := s.unit_at(p)
			if not u.is_empty():
				ch = _glyph(u)
			row += ch
		lines.append(row)
	for plan in s.intents:
		var e := s.unit_by_uid(int(plan.uid))
		lines.append("  %s@%s -> %s %s" % [_glyph(e), e.pos, plan.act, plan.target])
	print("\n".join(lines))


func _glyph(u: Dictionary) -> String:
	match u.side:
		"villager":
			return "V" if u.get("needs_escort", false) else "v"
		"enemy":
			return {"raider": "e", "axeman": "a", "archer_boat": "b", "chief": "k"}.get(u.type, "e")
		"npc":
			return "q"
	if u.role in ["hero", "elder"]:
		return "H"
	return {"spearman": "S", "crossbow": "X", "craftsman": "C", "courier": "U", "militia": "M", "reinforcement": "R", "bonus": "B"}.get(u.type, "A")
