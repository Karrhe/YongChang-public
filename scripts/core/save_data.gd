class_name SaveData
extends Resource
## 跨战斗、跨代保存的全部状态（一个自动保存的资源）。

## 玩家起的名字，只有第二、三代：下标 0 = {名2}，下标 1 = {名3}。
## 第一代主角名字固定，写在文本表 NAME_GEN1 里，不进存档。
@export var names: PackedStringArray = PackedStringArray(["", ""])
## 每一代主角 / 同伴是否存活，下标 0–2 对应第一到第三代。
@export var hero_alive: Array[bool] = [true, true, true]
@export var companion_alive: Array[bool] = [true, true, true]

@export var people: int = 0
@export var rice: int = 0
@export var materials: int = 0
@export var hungry: int = 0

## 训练过的守军（含教学单位），每项是兵种 ID，例如 "spearman"。
@export var defenders: PackedStringArray = PackedStringArray()

## 墙位：键是墙位 ID（如 "A1"、"gate_A"），值是 {"type": "none"/"fence"/"stone", "hp": [每一格的 HP]}。
@export var wall_slots: Dictionary = {}
@export var wall_goal_met: bool = false

## 灯分三组：villager（乡亲）、defender（守军）、hero（主角和同伴，记名字）。
@export var lanterns_villager: int = 0
@export var lanterns_defender: int = 0
@export var lantern_hero_names: PackedStringArray = PackedStringArray()

@export var raiders_defeated: int = 0

## 剧情选择 C1–C6："A" / "B"，没做过为空。
@export var choices: Dictionary = {}
## 战斗结果 B1–B9："held"（守住）/ "costly"（惨胜）。
@export var battle_results: Dictionary = {}

## 当前进度：下一步要进入的流程节点 ID。
@export var progress: String = ""
