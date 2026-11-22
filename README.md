# 永昌堡·守潮

2026 开源游戏开发大赛（OSGJ）参赛作品。受历史启发。

一家三代人，从组织义兵、修筑城堡到最终守住永昌堡。以潮汐为核心的格子战术，战斗之间是种田、筑城、训练守军的劳作阶段。

- 引擎：Godot 4.7（GDScript）
- 平台：Windows 10/11
- 代码协议：AGPL-3.0（见 `LICENSE`）
- 原创素材协议：CC BY 4.0（见 `LICENSE-ASSETS.md`）
- 素材来源：见 `CREDITS.md`
- AI 使用记录：见 `AI_LOG.md`

## 运行

用 Godot 4.7 打开本文件夹里的 `project.godot`，按 F5 运行。

## 目录

| 目录 | 内容 |
|---|---|
| `scenes/` | 每个画面一个场景：菜单、起名、剧情、战斗、劳作、结局、制作人员 |
| `scripts/core/` | 全局脚本：规则读取 `Rules`、游戏状态和存档 `Game` |
| `scripts/ui/` | 各画面的脚本 |
| `data/rules/rules.json` | 所有可调的规则和数值 |
| `data/text/zh_main.csv` | 所有显示给玩家的文字 |
