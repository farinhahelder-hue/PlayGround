extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for w in [0.0, 280.0]:
		var l := Label3D.new()
		l.text = "des nuages"
		l.font_size = 60
		l.pixel_size = 0.011
		l.width = w
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		root.add_child(l)
		await process_frame
		var bb: AABB = l.get_aabb()
		print("width=", w, " aabb pos=", bb.position, " size=", bb.size)
		l.queue_free()
		await process_frame
	quit()
