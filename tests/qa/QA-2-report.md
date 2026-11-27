# QA-2 · 《永昌堡·守潮》 v0.3.0-preview

**Tested base** `06f8cf7b018820ca2649b1bc9d99c93fe8356b68` on `feat/QA-2`. After updating public `main`, its only tree difference from preview commit `e626a84dedc03d40836d8392083b30938f7c5e5d` was `CREDITS.md`, so QA branched from updated `main`. Engine `4.7.2.stable.official.ed1daf0bf` on macOS.

## Headless suite and project launch

Both runs passed all eight test scenes (Smoke, Flow, Flow3, Story, Ending, Battle, Work, Playthrough). The font checker and the prior QA-1 probe also passed twice. All 20 processes returned 0 and produced a PASS verdict. The separate `--escort --trace` run passed in 541 steps and 5.5 seconds, accepting all nine battles and reaching the ending. [Suite exit codes](qa2-evidence/suite-status.log), [escort trace](qa2-evidence/escort-playthrough.log)

A cold editor import reported missing cached button and font resources while loading the theme, and issued two locale warnings. The import generated the caches. A subsequent editor import and a normal headless project launch for 120 frames completed with zero errors or warnings. The runnable `Windows Desktop` preset targets `export/windows/YongchangShouchao.exe` and declares product version `0.3.0.0`. The Windows binary could not run natively on this Mac. **Windows export not manually tested** for startup, save or exit. [Cold import](qa2-evidence/import.log), [reimport](qa2-evidence/reimport.log), [project launch](qa2-evidence/headless-launch.log)

## Escort battles

Run `godot --headless --path . res://tests/battle/sim.tscn -- battle_N escort` for each battle. These are fresh-save sims with default deployment. All nine exited 0. The campaign columns come from a second escort playthrough with logging added in a temporary project copy. Its outcomes and rescue margins match the unmodified escort trace. Entries show rescued/target, then lost, grain looted and hero death. The sim prints loot *events*. Each event removes two grain per the battle rules, so B8's two events equal four grain. Outside survivors are excluded from the lost count.

| Battle | Standalone rescued/target · lost · grain · hero died | Campaign rescued/target · lost · grain · hero died | First-turn and tide-channel observations |
|---|---|---|---|
| [B1](qa2-evidence/battle-1.log) | 5/4 · 0 · 0 · no | 5/4 · 0 · 0 · no | Target reached. No stationary villager by a tide tile. |
| [B2](qa2-evidence/battle-2.log) | 3/3 · 3 · 0 · no | 3/3 · 3 · 0 · no | Target reached. No stationary villager by a tide tile. |
| [B3](qa2-evidence/battle-3.log) | 5/5 · 2 · 0 · no | 5/5 · 2 · 0 · no | Target reached. One slow villager held at (9, 0) on turns 4–5, rising and high tide. |
| [B4](qa2-evidence/battle-4.log) | 3/3 · 2 · 0 · no | 3/3 · 3 · 2 · no | Target reached. One slow villager held at (5, 2) on turn 4, high tide. |
| [B5](qa2-evidence/battle-5.log) | 4/5 · 2 · 0 · no | 3/5 · 2 · 0 · no | Both runs missed target. First-turn solvability remains open. No stationary villager by a tide tile in the sim. |
| [B6](qa2-evidence/battle-6.log) | 5/4 · 2 · 0 · yes | 6/4 · 2 · 0 · no | Target reached. One regular villager held at (9, 0) on turn 3, falling tide. |
| [B7](qa2-evidence/battle-7.log) | 5/4 · 2 · 0 · no | 4/4 · 2 · 0 · no | Target reached. No stationary villager by a tide tile. |
| [B8](qa2-evidence/battle-8.log) | 5/5 · 2 · 4 · no | 5/5 · 2 · 0 · no | Target reached. Two slow villagers held at (6, 5) and (7, 5) on turn 4, falling tide. The one at (6, 5) also held on turn 5, low tide. |
| [B9](qa2-evidence/battle-9.log) | 6/6 · 4 · 0 · yes | 6/6 · 4 · 0 · yes | Target reached. No stationary villager by a tide tile. |

The sim probe tracked unit IDs and flagged unchanged positions on or adjacent to floodable tiles across a turn. B3 and B8 are the repeated-hold signals for manual follow-up. Both involved slow villagers, whose movement requires escort or guidance, so the holds alone do not establish a pathfinding defect. No raider-on-gate stall was observed in any battle. The standalone starts had no built gates. The campaign entered B4 and B7 with an intact gate, and no ordinary raider was on or adjacent to an intact gate immediately before an enemy phase. This leaves the suspected interaction unexercised. [Hold logs and campaign results](qa2-evidence/)

## Stone puzzle

Both Work suite runs passed. A separate headless `StoneGrid` probe mapped a synthetic mouse press to the bottom-left cell, emitted the grid signal and placed a stake through the real Work scene. The suite also checks invalid placements, gold joints that eliminate red seams, 90° rotation, chisel costs, gate construction, repairs, typhoon damage and weathering.

| Work phase | Escort trace in–out | Approximate automated time |
|---|---|---:|
| After B1 | 0.5–0.6 s | 0.1 s |
| After B2 | 0.9–1.0 s | 0.1 s |
| After B4 | 2.3–2.4 s | 0.1 s |
| After B5 | 2.8–2.9 s | 0.1 s |
| After B7 | 3.9–4.0 s | 0.1 s |
| After B8 | 4.6–4.6 s | below trace precision |

Each phase advanced two seasons in eight test-loop steps. The logged campaign exercised red seams and gold joints, nonzero rotations after B4/B5/B7/B8, chiseling twice after B7, building gates after B1/B4 and repairing the damaged gate after B7. These are bot-driven rule actions. First-time comprehension of gold lines, red seams, rotation, chiseling and gate repair, plus the lead's two-to-three-minute human timing target, require manual play. [Work suite](qa2-evidence/suite-1-work_test.log), [StoneGrid probe](qa2-evidence/stone-grid-probe.log), [instrumented playthrough](qa2-evidence/work-instrumented.log)

## Text and v2 save

- The same five Chinese roll-call strings serve all three generations. The escort trace rendered one call after each generation's final battle, with 5, 8 and 9 names respectively. Name and count placeholders resolved. The zero-loss line reads naturally on its own. The intro's promise of a full roster call is misleading when the scene only reads the missing names. [Extracted strings](qa2-evidence/text-extract.log), [rendered lines](qa2-evidence/work-instrumented.log)
- The typhoon notice rendered two seams and −3 gate HP on the campaign route. Its reference to wall segments and per-cell damage is readable for redesigned walls. Its treatment of legacy walls is inaccurate. The generation-three notice rendered five weathered segments, −3 gate HP, +2 population and retraining. The repair instruction uses a different material name from the work screen and is awkward with zero affected segments. [Rendered lines](qa2-evidence/work-instrumented.log), [source strings](qa2-evidence/text-extract.log)
- A temporary copy of `v0.2.0-playtest` generated a real v2 resource through `Game.save_game()`. The constructed checkpoint was `after_battle_5`, with a custom name, grain, materials and a full A1 stone wall built via the old C2 choice. The stock resource omitted its default `version` field. A second copy explicitly stored `version = 2` after the script property.
- Preview loaded both with zero engine errors and preserved the checkpoint, custom name, grain, materials, wall type and HP. Both opened Work with a valid input, replenished the stone queue from the material count and completed two seasons with a valid work result. The stock save reported version 3 by default. The explicit v2 copy stayed version 2 after loading, saving and reopening. Neither initialized a layout for the old wall. On the original loaded state before applying any work result, the typhoon took A1 from [6, 6] to [3, 3] while reporting zero seams. Weathering reported zero affected segments because the legacy wall had no layout. **Loadable with compatibility gaps.** [v2 generation](qa2-evidence/save-v2.log), [preview probe](qa2-evidence/save-preview.log)

## Issues

Totals for QA-2 are **0 blocker, 0 high, 2 medium, 3 low**. Numbering starts at QA-006: the lead renumbered these on merge because QA-1 already used QA-005 (exit diagnostics), which did not recur in these suite runs.

| ID | Severity | Reproduction and finding |
|---|---|---|
| QA-006 | Medium | Load the generated v2 checkpoint. Its explicit version stays at 2 through resave, and its standing A1 wall opens with an empty 4×3 layout. Generation-three weathering skips legacy walls without layouts. The version and puzzle state are only partially compatible. [Save probe](qa2-evidence/save-preview.log) |
| QA-007 | Low | Apply the typhoon to the loaded v2 checkpoint before rebuilding A1. The notice reports zero seams and only describes seam-based wall damage, yet A1 loses 3 HP per cell. The notice omits the legacy damage rule. [Save probe](qa2-evidence/save-preview.log) |
| QA-008 | Medium | Run B5 with the escort bot and default deployment, then compare with the campaign escort route. Both miss the target (4/5 and 3/5). This is a balance finding for those routes. Turn-one unsolvability remains unverified. [Standalone](qa2-evidence/battle-5.log), [campaign](qa2-evidence/work-instrumented.log) |
| QA-009 | Low | Read the generation-three weathering notice. It says to use `碎石`, while the work inventory and chisel action label the one-cell piece `楔石`. With zero weathered segments the unconditional instruction still says stones fell and need filling. [Text extract](qa2-evidence/text-extract.log), [zero-segment probe](qa2-evidence/save-preview.log) |
| QA-010 | Low | Read any generation’s roll call after casualties. `按名册一个一个点名` suggests the whole roster will be called. The scene only names people whose names were added to the lantern ledger, then follows each group with silence. Clarify whose names are being read. [Rendered examples](qa2-evidence/work-instrumented.log) |

A complete manual playthrough remains pending. Headless checks cover the automated path, rule behavior and Chinese strings, with visual legibility and pacing, alternate B5 tactics, the suspected gate stall, and Windows executable startup/save/exit still unverified.

## 负责人处理（2026-11-27，合并时由 Claude Code 补）

编号已改成 QA-006 起（QA-1 用过 QA-005）。五个问题都在 public main 修了，修复见 `AI_LOG.md` 2026-11-27 的 QA-2 一行：

| ID | 处理 |
|---|---|
| QA-006 | 读档时 `FlowLogic.migrate` 给没有砖槽的旧墙补砖槽：旧石墙当完美咬合的墙（旧规则下本来就是满 HP 6），旧栅栏当刚扎成的木桩；不看版本号（旧存档没写版本字段，读进来就是默认的 3）。测试：`tests/flow/flow_test.gd` 的旧存档读档三条 |
| QA-007 | 随 QA-006 解决：补过砖槽的旧墙按红缝过台风，说明文字和实际扣法一致 |
| QA-008 | B5 目标人数 5 → 4；认真玩法机器人重跑救下 4/4 |
| QA-009 | 第三代说明改为“用楔石、条石补上”；没有墙风化时改说“石墙咬得牢，三十年没掉一块石头” |
| QA-010 | 点名开头改为“宗祠前点名，点的是这一代没能回来的人” |
