# 素材来源 CREDITS

- **代码：** AGPL-3.0（见 `LICENSE`）。
- **本作原创的非代码素材**（美术、音效、剧情和界面文字）：CC BY 4.0（见 `LICENSE-ASSETS.md`）。
- **AI 生成后加工的美术**（都算作本作原创素材，按 CC BY 4.0；生成工具和处理方式记在 `AI_LOG.md` 2026-11-24 各条）：
  - Microsoft Copilot：剧情背景 4 张 `assets/art/bg/`（hall、home、site、river）和第一批头像 5 张 `assets/art/portraits/`（wang_cheng、su_niang、a_nan、gen2、zhou_yan）。用 `tools/art/to_db16.py` 裁切、缩放、压成 DB16；hall 之后又用 `tools/art/fix_hall.py` 调了墙面和地面颜色。发布前再核对一次 Copilot 的使用条款（待核对）。
  - Google Gemini：第二批头像 5 张 `assets/art/portraits/`（gen3、a_tang、a_he、qiao_shu、wang_shugao），由 Gemini 网页版直接画 32×32，按网格取 DB16 颜色后用 `tools/art/grid_to_png.py` 写成图；道具小图 7 张 `assets/art/props/`（stone_hammer、spear、stove_bowl、rice、fishing_net、clothes_red_cloth、swaddle），由 Gemini 网页版画 32×32 图标，按网格取色、去底。发布前再核对一次 Gemini 的使用条款（待核对）。
- **脚本画的美术**（`assets/art/tiles/`、`assets/art/units/`、`assets/art/ui/`、`assets/art/ending/`，以及 `assets/art/props/grain_ledger.png`；不含上面 AI 生成后加工的背景、头像和 7 张道具，也不含下面 ART-2 的图）：由 Claude Code 用 `tools/art/` 下的 Python 脚本逐像素画出（粮册用 `tools/art/make_ledger.py`），只用 Dawnbringer 16 调色板，没有用第三方图，算作本作原创素材，按 CC BY 4.0；生成过程记在 `AI_LOG.md`。
- **ART-2（作者 leeli777）**：`assets/art/units/villager_slow.png`（走不动的乡亲）和 `assets/art/work/` 下的砖槽贴图（木桩、楔石、条石、拐角石、方石），用 `tools/art/make_redesign_art.py` 逐像素画出，只用 Dawnbringer 16，由 leeli777 制作，算作本作原创素材，按 CC BY 4.0。
- **AUD-2（作者 leeli777）**：`assets/audio/stone_place.wav`（放下石头）、`assets/audio/stone_bite.wav`（咬住），由 leeli777 用 Python 脚本合成，没有用任何采样，算作本作原创素材，按 CC BY 4.0。生成脚本还没有进仓库，待 leeli777 补交。
- **音效**（`assets/audio/` 的 gong、tide、hit、repair、beacon、lantern 6 个；不含上面 AUD-2 的两个石头音效）：由 Claude Code 用 `tools/audio/make_sfx.py` 合成，没有用任何采样，算作本作原创素材，按 CC BY 4.0。
- **第三方素材**都记在下表。允许的协议：媒体 CC0 / CC BY / CC BY-SA；代码 MIT / BSD / Apache-2.0（与 AGPL 兼容）；字体 SIL OFL。

| 素材 | 用在哪里 | 作者 | 来源链接 | 协议 | 是否修改 |
|---|---|---|---|---|---|
| `icon.svg` | 工程图标（Godot 默认图标，之后替换） | Andrea Calabró（Godot 标志） | https://godotengine.org/press/ | CC BY 4.0 | 否 |
| `assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2` | 全游戏的中文像素字体（12 px） | TakWolf（含 Ark Pixel、Cubic 11、Galmuri 的字形） | https://github.com/TakWolf/fusion-pixel-font （v2026.11.10） | SIL OFL 1.1（许可证原文在 `assets/fonts/*-OFL.txt`、`galmuri-LICENSE.txt`） | 否 |
