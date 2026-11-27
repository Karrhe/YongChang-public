extends SceneTree
## 查字体缺字：data/text/ 下所有表里用到的字，游戏字体里有没有。
## 运行：godot --headless --path . -s res://tests/font_check.gd
## 缺字会显示成别的字或方块（REDESIGN 时“石匠”的“匠”就缺），改词或换字体。


func _init() -> void:
	var theme_font: Font = null
	var theme: Theme = load(String(ProjectSettings.get_setting("gui/theme/custom", "")))
	if theme != null:
		theme_font = theme.default_font
	if theme_font == null:
		print("FONT CHECK: no theme font")
		quit(1)
		return
	var missing := {}
	for file in DirAccess.get_files_at("res://data/text/"):
		if file.get_extension() != "csv":
			continue
		var text := FileAccess.get_file_as_string("res://data/text/" + file)
		for i in text.length():
			var c := text.unicode_at(i)
			if c < 0x2E80:
				continue  # 只查中日韩字和全角标点
			if not theme_font.has_char(c):
				var ch := String.chr(c)
				missing[ch] = String(missing.get(ch, "")) + ("" if String(missing.get(ch, "")).contains(file) else file + " ")
	for ch: String in missing:
		print("missing %s (U+%04X) in %s" % [ch, ch.unicode_at(0), missing[ch]])
	print("FONT CHECK: %s" % ("PASS" if missing.is_empty() else "FAIL (%d)" % missing.size()))
	quit(0 if missing.is_empty() else 1)
