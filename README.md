# 永昌堡·守潮

2026 开源游戏开发大赛（OSGJ）参赛作品。受历史启发。

一家三代人，从组织义兵、修筑城堡到最终守住永昌堡。

- **战斗是潮汐疏散：** 乡亲住在海边，海寇从海滩登陆。看潮汐条带乡亲过潮沟、走土堤回家；走不动的乡亲要守军去接；门开着，海寇也会冲进来抢粮。
- **劳作是砌石拼图：** 潮水按季送来石料，石匠把石头一块块砌进砖槽。石头要彼此咬住——压住接缝亮金线，通到底的竖缝是红线，台风来时就从那里裂开。第一代只有木桩，第二代女儿学会了砌石，第三代补三十年风化的缺口。
- **失去的人会被记住：** 每代最后一仗之后在宗祠前点名，没有应答的名字写进灯簿，中元节放灯。

- 引擎：Godot 4.7（GDScript）
- 平台：Windows 10/11
- 代码协议：AGPL-3.0（见 `LICENSE`）
- 原创素材协议：CC BY 4.0（见 `LICENSE-ASSETS.md`）
- 素材来源：见 `CREDITS.md`
- AI 使用记录：见 `AI_LOG.md`

## 运行

- **玩：** 双击 `YongchangShouchao.exe`（Windows 10/11，单个文件，数据包已嵌在里面）。存档在 `%APPDATA%\Godot\app_userdata\<项目名>\` 下，自动保存。
- **开发：** 用 Godot 4.7 打开本文件夹里的 `project.godot`，按 F5 运行。
- **设置：** 主菜单的“设置”里有剧情模式（海寇 HP −1、每场多 1 回合）、音量、全屏；存在同一目录的 `settings.cfg`。剧情模式同时改当前存档和以后新游戏的默认值。
- **暂停：** 游戏中（剧情、战斗、劳作、起名、选择）按 Esc 暂停：继续、设置、回到主菜单、退出游戏。每一段开始时自动存档，回主菜单后继续从这一段开头来。

## 目录

| 目录 | 内容 |
|---|---|
| `scenes/` | 每个画面一个场景：菜单、起名、剧情、战斗、劳作、结局、制作人员 |
| `scripts/core/` | 全局脚本：规则读取 `Rules`、游戏状态和存档 `Game`、模块接口检查 `Contract` |
| `scripts/flow/` | 主流程；剧情选择 C1–C5（`Choices`）；假战斗、假劳作（真模块交付前顶替） |
| `scripts/naming/` | 起名界面和石锤刻字 |
| `scripts/ending/` | 结局：E1–E6、放灯、三代墓志、祠堂记录 |
| `scripts/battle/` | 战斗：规则 `BattleState`、地图 `battle_board.gd`、战斗画面；测试用的“认真玩法” `BattleBot` |
| `scripts/work/` | 劳作：规则 `WorkState`、砌石拼图 `StoneWall`、砖槽 `StoneGrid`、城防图 `WallMap`、劳作画面；测试用的 `WorkBot` |
| `scripts/story/` | 剧情表 `StoryTable`、对话框 `DialogueBox`、剧情画面（对话只有文字，没有配音） |
| `scripts/ui/` | 各画面的脚本；设置画面 `SettingsPanel`、暂停画面（自动加载 `Pause`） |
| `data/rules/*.json` | 所有可调的规则和数值；每个文件一个顶层键，键名等于文件名（`core.json` → `core`） |
| `data/text/*.csv` | 所有显示给玩家的文字；每个模块一张表，启动时自动加载 |
| `data/text/story.csv` | 剧情台词，一行一句（不是翻译表，导入方式是“保留文件”）；由 `tools/story/script_to_story_csv.py` 从剧本生成 |
| `assets/art/` | 像素美术：`bg` 剧情背景、`portraits` 头像、`tiles` 地块、`units` 单位、`ui` 界面、`props` 道具、`work` 砖槽石纹、`ending` 结局（放灯、龙灯） |
| `assets/audio/` | 音效（锣、潮水、命中、修墙、烽火、放灯；拼图的放下石头、咬住），事件名见 `data/rules/audio.json` |
| `assets/fonts/` | 中文像素字体 Fusion Pixel Font 12px（SIL OFL，许可证在同一目录） |
| `assets/theme/` | 全局界面主题：按钮九宫格、默认字体 |
| `tools/art/`、`tools/audio/`、`tools/story/` | 生成美术、音效、剧情表的 Python 脚本（需要 Pillow、numpy） |

## 测试

```
godot --headless --path . res://tests/smoke_test.tscn
godot --headless --path . res://tests/flow/flow_test.tscn
godot --headless --path . res://tests/story/story_test.tscn
godot --headless --path . res://tests/flow/flow3_test.tscn
godot --headless --path . res://tests/ending/ending_test.tscn
godot --headless --path . res://tests/battle/battle_test.tscn
godot --headless --path . res://tests/work/work_test.tscn
godot --headless --path . res://tests/flow/playthrough_test.tscn
godot --headless --path . res://tests/ui/settings_test.tscn
```

用临时存档和设置路径，不会删掉真实存档、不改玩家设置。

预览一个剧情场景（校对剧情表用，点击或空格往下播，滚轮向上回看）：

```
godot --path . res://tests/story/story_preview.tscn -- scene=G2-1 gen=2
```

预览结局（假存档；`lost` 是乡亲、守军各失去几人，`dead` 是哪几代主角阵亡）：

```
godot --path . res://tests/ending/ending_preview.tscn -- lost=4 dead=1,2
```

`playthrough_test` 用真的战斗和劳作从序章一直玩到结局。

## 导出

`export_presets.cfg` 里有 Windows 预设（数据包嵌在 exe 里）。导出 exe 需要 Godot 4.7.2 的导出模板（编辑器：编辑器 → 管理导出模板）：

```
godot --headless --path . --export-release "Windows Desktop" export/windows/YongchangShouchao.exe
```

只导出数据包不需要模板：

```
godot --headless --path . --export-pack "Windows Desktop" export/windows/game.pck
```

导出时不打包 `tests/`、`tools/`、`export/`（`export_presets.cfg` 的 exclude_filter）。

## 发布包

Windows 发布包是一个 zip（`YongchangShouchao-<版本>-windows.zip`），解压后在同一层有这些文件：

| 文件 | 内容 |
|---|---|
| `YongchangShouchao.exe` | 游戏（数据包已嵌在里面） |
| `README.md` | 本文件 |
| `LICENSE` | 代码协议 AGPL-3.0 |
| `LICENSE-ASSETS.md` | 原创素材协议 CC BY 4.0 |
| `CREDITS.md` | 素材来源 |
| `AI_LOG.md` | AI 使用记录 |
| `fusion-pixel-OFL.txt`、`ark-pixel-OFL.txt`、`cubic-11-OFL.txt`、`galmuri-LICENSE.txt` | 字体许可证（SIL OFL 1.1） |
