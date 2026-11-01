extends SceneTree

var main = null


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	call_deferred("_run")


func _shot(path: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("capture: ", path, " ", img.get_width(), "x", img.get_height())


func _run() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	main.start_arena()
	var a = main.action_mode
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_shot("res://capture_arena.png")
	var st: Dictionary = a.debug_state()
	a.debug_shoot(int(st["ans"]))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_shot("res://capture_arena_hit.png")
	a._show_game_over()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_shot("res://capture_arena_over.png")
	quit()
