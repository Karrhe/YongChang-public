# AI 使用记录 AI_LOG

按比赛要求记录所有 AI 生成的内容：日期、工具、生成了什么、人工改了什么。

| 日期 | 工具 | 生成了什么 | 人工改了什么 |
|---|---|---|---|
| 2026-11-21 | Claude（claude.ai） | 设计文档初稿：PLAN-001、BAT-001、WORK-001、STORY-001 模板、CLAUDE.md（英文） | 审阅全部内容；提出改为中文 |
| 2026-11-21 | Claude Code（Claude Opus 5.5 + Claude Sonnet 子代理） | 把 5 份设计文档翻译成中文；统一术语 | 审阅译文 |
| 2026-11-21 | 用户自己查资料 + Claude Code（网络搜索核实） | STORY-001 的历史资料（王氏三代、永昌堡史实）；核实 3 条史实 | 资料由用户收集整理；Claude 只做格式整理和核实 |
| 2026-11-21 | Claude Code（Claude Opus 5.5） | 按史实把故事骨架改为“义 → 筑 → 守”，并同步战斗和劳作设计 | 用户修改了 STORY-001 的结构和用词指南，自己更新了 BAT / WORK / PLAN / CLAUDE.md |
| 2026-11-21 | Claude Code（Claude Opus 5.5）+ agy CLI（Gemini 3.8 Flash） | 设计补充：墙位、登陆时间表、夜战、放灯分组、数值推演；两个 AI 讨论两轮 | 用户逐条选择了所有冲突的处理方式（出战上限、兵种改名等） |
| 2026-11-21 | Claude Code（Claude Opus 5.5） | Godot 工程骨架：工程设置、Rules / Game 自动加载、存档资源、文本表、主菜单、制作人员画面、LICENSE / CREDITS / AI_LOG / README | — |
| 2026-11-21 | Claude Code（Claude Opus 5.5）+ agy CLI（Gemini 3.8 Flash） | 合并两个版本的设计文档；用官方资料《永昌堡十三进士与抗倭纪略》（pdftotext 提取）核对史实；agy 审阅合并方案，并判断风灾年份 | 用户决定：游戏里不写风灾年份；协议改为代码 AGPL-3.0 + 原创素材 CC BY 4.0 |
| 2026-11-21 | Claude Code（Claude Opus 5.5） | 把工程里的协议说明改成 AGPL-3.0 / CC BY 4.0（README、CREDITS、LICENSE-ASSETS.md、制作人员文字） | — |
| 2026-11-21 | Claude Code（Claude Opus 5.5）+ agy CLI | 剧本评审（两个 AI 讨论两轮）；按 .agents 写作技能写 STORY-FINAL-v3：父女两代、长辈条件台词、选择台词对齐机制、E2 史实修正、删口号 | 用户决定：第一、二代改为父女；女儿称"阿囡"；第一代主角名字固定为"王成"，只有第二、三代由玩家起名 |
| 2026-11-21 | Claude Code（Claude Opus 5.5） | 代码：存档只存两个名字，{名1} 取文本表 NAME_GEN1（王成）；冒烟测试加名字检查 | — |
| 2026-11-22 | Claude Code（Claude Opus 5.5） | 剧本 STORY-FINAL-v3 修改：加入"官府护不住乡下"的暗示（NAR-027）；补三十年太平和海寇再来的原因（NAR-028）；第三代改为"守望本身"、B9 缩小为本地海盗抢粮（NAR-029）；STORY-001 §2.8 海寇组成史料（未逐条核对原文） | 用户提出官兵拖延要钱、邻村自顾不暇的写法，并决定第三代按史实改 |
| 2026-11-22 | Claude Code（Claude Opus 5.5）+ agy CLI（Gemini 3.8 Flash） | 新增收尾场景 E3.5"后来"（代代补墙、石锤传用），两个 AI 商定位置和台词（NAR-030） | 用户提出"代代维修永昌堡"的收尾方向 |
| 2026-11-22 | Claude Code（Claude Opus 5.5）+ agy CLI | 协作规则 COLLAB-001、AGENTS.md（两个 AI 讨论两轮） | 用户要求制定协作模式规则 |
| 2026-11-22 | Claude Code（Claude Opus 5.5） | 并行分工 TEAM-001：任务包、模块接口 v1、文件归属、合并流程 | 用户提出负责人和协作者并行分工，并决定由负责人做最后的合并汇总 |
| 2026-11-22 | Claude Code（Claude Opus 5.5）+ agy CLI | COLLAB-001 v2：改写成多人同步 GitHub 仓库的步骤；在本地模拟仓库演练；两轮评审 | 用户纠正：协作规则写给同步仓库的其他人，不是 AI 之间的协作 |
| 2026-11-22 | Claude Code（Claude Opus 5.5） | ISSUE-001 问题清单：汇总设计缺口、剧情、史实、实现问题和临时做法 | 用户要求把设计缺口记进问题清单，放在 personal 仓库 |
| 2026-11-22 | Claude Code（Claude Opus 5.5）+ agy CLI | 剧本 STORY-FINAL-v3 一致性修改（NAR-031）：选择顺延成五次、E5 同步、锣声、石锤和长枪的前后一致 | 负责人先手改了前半部分剧本；AI 只改与之冲突的行，负责人改过的行未动 |
| 2026-11-22 | Claude Code（Claude Opus 5.5）+ agy CLI | 按负责人改后的剧本同步设计文档（CLAUDE、BAT、WORK、TEAM、ISSUE 等）和存档注释：战后确认重打、长辈只到 B4、五次选择新编号、灯都写名字（NAR-032）；起草三处待补剧情，放进剧本；STORY-001 逐条同步 | 负责人回答了编号、阿棠、G2-5 台词、谁起草四个问题；审定草稿时改写了 G3-2 的三句，其余保留 |
| 2026-11-23 | Claude Code（Claude Opus 5.5） | SET 公共地基：规则拆成 `data/rules/*.json` 合并读取；文本表自动加载；显示改为 640×360、viewport、整数缩放、Nearest；存档补死亡场次、长辈退休、石锤刻字、粮仓、带名字的灯、单位 id、剧情模式、提示；接口检查 `Contract`；假战斗、假劳作；冒烟测试改用临时存档 | — |
| 2026-11-23 | Claude Code（Claude Opus 5.5） | FLOW-1 流程骨架：节点表 `flow.json`（P1 → 结局）、每个节点开始时自动存档、真模块不存在时用假战斗 / 假劳作 / 剧情占位 / 选择占位、战后接受或重打、第三代 battle_7/8 主角阵亡直接重打、长辈只进 battle_4/9、G2-3 后退休、换代和台风的数值、带名字的灯；流程测试从头走到结局。默认名字“阿潮”和界面短句是 Claude 写的，待负责人审 | — |
