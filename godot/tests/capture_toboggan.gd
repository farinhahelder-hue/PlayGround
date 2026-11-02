extends SceneTree

# Captures de contrôle du mode Toboggan.

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
	main.capturing = true
	main.start_toboggan()
	var t = main.toboggan_mode
	t.save_path = "user://capture_toboggan.cfg"
	t.best = 0
	for i in range(20):
		var q0: Dictionary = t.debug_state()
		if (q0["opts"] as Array).size() == 4:
			break
		t.debug_shoot(int(q0["ans"]))
		t.debug_skip()
	for i in range(6):
		await RenderingServer.frame_post_draw
	_shot("res://capture_toboggan.png")

	t.debug_spawn_obstacle(-2.0, -12.0)
	t.debug_spawn_obstacle(2.0, -17.0)
	t.debug_spawn_obstacle(0.0, -21.0)
	for i in range(12):
		await process_frame
	_shot("res://capture_toboggan_obstacles.png")

	var st: Dictionary = t.debug_state()
	t.debug_shoot(int(st["ans"]))
	for i in range(6):
		await RenderingServer.frame_post_draw
	_shot("res://capture_toboggan_hit.png")

	t._show_game_over()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_shot("res://capture_toboggan_over.png")

	var abs := ProjectSettings.globalize_path("user://capture_toboggan.cfg")
	if FileAccess.file_exists(abs):
		DirAccess.remove_absolute(abs)
	quit()
