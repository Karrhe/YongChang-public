extends Node
## 截图工具：打开一个画面，等几帧后截图并退出。
## 运行：godot --path . res://tests/screenshot.tscn -- <场景路径> <输出 PNG 的绝对路径>


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path := args[0] if args.size() > 0 else "res://scenes/menu/menu.tscn"
	var out_path := args[1] if args.size() > 1 else ProjectSettings.globalize_path("user://screenshot.png")
	add_child(load(scene_path).instantiate())
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_path)
	print("Saved screenshot: ", out_path)
	get_tree().quit()
