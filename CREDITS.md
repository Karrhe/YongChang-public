# 素材来源 CREDITS

- **代码：** AGPL-3.0（见 `LICENSE`）。
- **本作原创的非代码素材**（美术、音效、剧情和界面文字）：CC BY 4.0（见 `LICENSE-ASSETS.md`）。
- **AI 生成后加工的美术**（`assets/art/bg/`、`assets/art/portraits/`）：用 Microsoft Copilot 生成，再压色和缩放，算作本作原创素材，按 CC BY 4.0；生成工具和处理方式记在 `AI_LOG.md`（2026-11-24）。发布前再核对一次 Copilot 的使用条款。
- **脚本画的美术**（`assets/art/tiles/`、`assets/art/units/`、`assets/art/ui/`、`assets/art/props/`、`assets/art/ending/` 等，除上面 AI 生成后加工的背景和头像）：用 `tools/art/` 下的 Python 脚本逐像素画出或压色，只用 Dawnbringer 16 调色板，没有用第三方图，算作本作原创素材，按 CC BY 4.0；生成过程记在 `AI_LOG.md`。
- **ART-2（协作者 leeli777）**：`assets/art/units/villager_slow.png`（走不动的乡亲）和 `assets/art/work/` 下的砖槽贴图（木桩、楔石、条石、拐角石、方石），用 `tools/art/make_redesign_art.py` 逐像素画出，只用 Dawnbringer 16，算作本作原创素材，按 CC BY 4.0。
- **音效**（`assets/audio/`）：用 `tools/audio/make_sfx.py` 合成，没有用任何采样，算作本作原创素材，按 CC BY 4.0。
- **第三方素材**都记在下表。允许的协议：媒体 CC0 / CC BY / CC BY-SA；代码 MIT / BSD / Apache-2.0（与 AGPL 兼容）；字体 SIL OFL。

| 素材 | 用在哪里 | 作者 | 来源链接 | 协议 | 是否修改 |
|---|---|---|---|---|---|
| `icon.svg` | 工程图标（Godot 默认图标，之后替换） | Andrea Calabró（Godot 标志） | https://godotengine.org/press/ | CC BY 4.0 | 否 |
| `assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2` | 全游戏的中文像素字体（12 px） | TakWolf（含 Ark Pixel、Cubic 11、Galmuri 的字形） | https://github.com/TakWolf/fusion-pixel-font （v2026.11.10） | SIL OFL 1.1（许可证原文在 `assets/fonts/*-OFL.txt`、`galmuri-LICENSE.txt`） | 否 |
