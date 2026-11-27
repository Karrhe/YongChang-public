class_name SaveData
extends Resource
## 跨战斗、跨代保存的全部状态（一个自动保存的资源）。只有 FLOW 写它（TEAM-001 §4）。
## 代的下标：0 = 第一代，1 = 第二代，2 = 第三代。

## 存档格式版本。以后改字段时加 1，读档时按版本补默认值。
## 默认 0 = 没写版本的旧存档（Godot 不保存等于默认值的字段，默认值不是 0 就永远写不进文件）；
## 新游戏（Game.new_game）和读档迁移（FlowLogic.migrate）写成当前版本 CURRENT_VERSION。
const CURRENT_VERSION := 3
@export var version: int = 0

## 玩家起的名字，只有第二、三代：下标 0 = {名2}，下标 1 = {名3}。
## 第一代主角名字固定，写在文本表 NAME_GEN1 里，不进存档。
@export var names: PackedStringArray = PackedStringArray(["", ""])
## 石锤刻字：T1 起名之后输入。空 = 还没输入（显示时用文本表 HAMMER_DEFAULT）。
@export var hammer_text: String = ""

## 每一代主角 / 同伴是否存活（条件行要用）：
## hero_alive      = [王成, {名2}, {名3}]
## companion_alive = [阿棠, 周砚, 阿禾]
@export var hero_alive: Array[bool] = [true, true, true]
@export var companion_alive: Array[bool] = [true, true, true]
## 每代主角死在哪一场，如 "battle_2"；空 = 没死。死亡阶段替换句按它换（剧本附录 D）。
@export var death_battle: PackedStringArray = PackedStringArray(["", "", ""])
## 第一代的长辈（王成或阿棠）在 G2-3 之后退休，之后只在剧情里出现。
@export var elder_retired: bool = false

@export var people: int = 0
@export var rice: int = 0
@export var materials: int = 0
@export var hungry: int = 0

## 训练过的守军和教学单位，每项是 {"id": "u7", "type": "spearman"}（TEAM-001 §4 的 unit）。
@export var roster: Array[Dictionary] = []
## 下一个新单位用的编号，保证 id 不重复。
@export var next_unit_id: int = 1

## 墙位：键是墙位 ID（如 "A1"、"gate_A"），值是 {"type": "none"/"fence"/"stone", "hp": [每一格的 HP]}。
@export var wall_slots: Dictionary = {}
## 砌石拼图（REDESIGN-002 方案一）：墙位 ID → 砖槽（格式见 StoneWall）。墙位筑成后 wall_slots 里另记 "max"（这段墙的满 HP）。
@export var wall_layouts: Dictionary = {}
## 石料库存的形状，从前往后用；长度跟着 materials 走（WorkState 补齐或截掉）。
@export var stone_queue: PackedStringArray = PackedStringArray()
## 下一块补进来的石料从这一代 sequence 的第几个开始。
@export var stone_next: int = 0
## 每代的目标卡是否达成（G2-6 看第二代的）。
@export var goal_met: Array[bool] = [false, false, false]
## 每代的宗族义仓是否用过（WORK-001 §8，每代一次）。
@export var granary_used: Array[bool] = [false, false, false]

## 灯分三组，每盏灯是 {"name": "陈阿六", "gen": 1, "battle": "battle_2"}：
## villager（乡亲）、defender（守军，含教学单位和民兵）、hero（主角和同伴）。
## 乡亲和守军的名字由 FLOW 在失去时从名字表按顺序取（BAT-001 §13）。
@export var lanterns_villager: Array[Dictionary] = []
@export var lanterns_defender: Array[Dictionary] = []
@export var lanterns_hero: Array[Dictionary] = []

@export var raiders_defeated: int = 0

## 剧情选择："C1"–"C5" → "A" / "B"，没做过就没有这个键。
@export var choices: Dictionary = {}
## 战斗结果："battle_1"–"battle_9" → "held"（守住）/ "costly"（惨胜）。
## 代码里不写 B1，会和墙位 B1 撞名（TEAM-001 §4）。
@export var battle_results: Dictionary = {}

## 剧情模式：海寇 HP −1，每场回合上限 +1（BAT-001 §8）。
@export var story_mode: bool = false
## 看过的教程提示 ID，只显示一次。
@export var seen_hints: PackedStringArray = PackedStringArray()

## 当前进度：下一步要进入的流程节点 ID。
@export var progress: String = ""


## 新单位：分配一个不重复的 id。
func new_unit(type: String) -> Dictionary:
	var unit := {"id": "u%d" % next_unit_id, "type": type}
	next_unit_id += 1
	return unit


func lantern_count() -> int:
	return lanterns_villager.size() + lanterns_defender.size() + lanterns_hero.size()
