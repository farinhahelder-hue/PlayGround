extends Node3D

signal exited

var player: CharacterBody3D
var camera: Camera3D
var arena: MeshInstance3D
var health: float = 100.0
var score: int = 0
var wave: int = 1
var fire_cooldown: float = 0.0
var flash_timer: float = 0.0
var game_over: bool = false
var enemies: Array = []
var projectiles: Array = []
var hud: CanvasLayer
var hud_label: Label
var status_label: Label

func _ready() -> void:
	_build_world()
	_build_hud()
	_build_player()
	_spawn_wave()
	set_process(true)
	set_physics_process(true)

func _build_world() -> void:
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(32.0, 0.5, 32.0)
	var floor := MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.position = Vector3(0.0, -0.25, 0.0)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.12, 0.14, 0.18)
	floor.material_override = floor_mat
	add_child(floor)
	arena = floor

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.3, 0.36, 0.42)
	wall_mat.roughness = 0.7
	for i in range(4):
		var wall := MeshInstance3D.new()
		var wall_box := BoxMesh.new()
		wall_box.size = Vector3(32.0, 3.0, 0.6)
		wall.mesh = wall_box
		wall.material_override = wall_mat
		match i:
			0:
				wall.position = Vector3(0.0, 1.5, -15.5)
			1:
				wall.position = Vector3(0.0, 1.5, 15.5)
			2:
				wall.position = Vector3(-15.5, 1.5, 0.0)
				wall.rotation_degrees = Vector3(0.0, 90.0, 0.0)
			3:
				wall.position = Vector3(15.5, 1.5, 0.0)
				wall.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		add_child(wall)

	camera = Camera3D.new()
	camera.position = Vector3(0.0, 7.0, 12.0)
	camera.fov = 72
	add_child(camera)
	camera.current = true

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 20
	margin.offset_top = 20
	margin.offset_right = -20
	margin.offset_bottom = -20
	hud.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	margin.add_child(vbox)
	var hp := Label.new()
	hp.text = "Health 100"
	hp.add_theme_font_size_override("font_size", 24)
	hp.add_theme_color_override("font_color", Color(0.9, 1.0, 1.0))
	vbox.add_child(hp)
	hud_label = hp
	var stat := Label.new()
	stat.text = "Wave 1 · Score 0"
	stat.add_theme_font_size_override("font_size", 18)
	stat.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	vbox.add_child(stat)
	status_label = stat

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(0.0, 0.0, 8.0)
	add_child(player)
	var player_collision := CollisionShape3D.new()
	var player_shape := CapsuleShape3D.new()
	player_shape.radius = 0.45
	player_shape.height = 1.8
	player_collision.shape = player_shape
	player_collision.position.y = 0.9
	player.add_child(player_collision)
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.7
	body_mesh.height = 1.8
	var visual := MeshInstance3D.new()
	visual.mesh = body_mesh
	visual.position.y = 1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.7, 1.0)
	visual.material_override = mat
	player.add_child(visual)
	var weapon := MeshInstance3D.new()
	var gun := BoxMesh.new()
	gun.size = Vector3(0.25, 0.25, 0.9)
	weapon.mesh = gun
	weapon.position = Vector3(0.5, 1.2, 0.75)
	weapon.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	player.add_child(weapon)

func _spawn_wave() -> void:
	enemies.clear()
	var count := 3 + wave
	for i in range(count):
		var enemy := CharacterBody3D.new()
		var spawn := Vector3.ZERO
		for attempt in range(20):
			spawn = Vector3(randf_range(-11.0, 11.0), 0.0, randf_range(-11.0, 11.0))
			if spawn.distance_to(player.position) >= 5.0:
				break
		if spawn.distance_to(player.position) < 5.0:
			var corners := [Vector3(-12.0, 0.0, -12.0), Vector3(12.0, 0.0, -12.0), Vector3(-12.0, 0.0, 12.0), Vector3(12.0, 0.0, 12.0)]
			spawn = corners[0]
			for corner in corners:
				if corner.distance_to(player.position) > spawn.distance_to(player.position):
					spawn = corner
		enemy.position = spawn
		var enemy_collision := CollisionShape3D.new()
		var enemy_shape := CapsuleShape3D.new()
		enemy_shape.radius = 0.55
		enemy_shape.height = 1.5
		enemy_collision.shape = enemy_shape
		enemy_collision.position.y = 0.75
		enemy.add_child(enemy_collision)
		var enemy_visual := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.75
		sphere.height = 1.5
		enemy_visual.mesh = sphere
		enemy_visual.position.y = 1.0
		var enemy_mat := StandardMaterial3D.new()
		enemy_mat.albedo_color = Color(0.9, 0.26, 0.23)
		enemy_visual.material_override = enemy_mat
		enemy.add_child(enemy_visual)
		add_child(enemy)
		enemies.append(enemy)
	status_label.text = "Wave %d · Score %d" % [wave, score]

func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for e in enemies:
		if e == null:
			continue
		var d := player.global_position.distance_to(e.global_position)
		if d < best_dist:
			best = e
			best_dist = d
	return best

func _fire() -> void:
	if fire_cooldown > 0.0 or game_over:
		return
	fire_cooldown = 0.22
	var target := _nearest_enemy()
	var aim := Vector3(0.0, 0.0, -1.0)
	if target != null:
		aim = (target.global_position - (player.global_position + Vector3(0.0, 1.2, 0.0))).normalized()
	var slug := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	slug.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.2)
	slug.material_override = mat
	slug.position = player.global_position + Vector3(0.0, 1.2, 0.0)
	add_child(slug)
	projectiles.append({"node": slug, "velocity": aim * 22.0, "life": 2.0})

func _update_player(delta: float) -> void:
	if game_over:
		return
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		move.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		move.z += 1.0
	if Input.is_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move.x += 1.0
	if move.length() > 0.0:
		move = move.normalized() * 8.0
	player.velocity = Vector3(move.x, 0.0, move.z)
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -14.0, 14.0)
	player.position.z = clampf(player.position.z, -14.0, 14.0)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_fire()
	var target := _nearest_enemy()
	if target != null:
		var facing := target.global_position - player.global_position
		player.rotation.y = atan2(facing.x, facing.z)
	camera.position = player.position + Vector3(0.0, 7.0, 9.0)
	camera.look_at(player.position + Vector3(0.0, 1.2, 0.0))
	fire_cooldown = maxf(0.0, fire_cooldown - delta)

func _update_enemies(delta: float) -> void:
	if game_over:
		return
	for i in range(enemies.size() - 1, -1, -1):
		var enemy = enemies[i]
		if enemy == null:
			enemies.remove_at(i)
			continue
		var direction := player.global_position - enemy.global_position
		var flat := Vector3(direction.x, 0.0, direction.z)
		if flat.length() > 0.001:
			enemy.velocity = flat.normalized() * (1.6 + wave * 0.2)
			enemy.move_and_slide()
			enemy.rotation.y = atan2(flat.x, flat.z)
		var d := enemy.global_position.distance_to(player.global_position)
		if d < 1.4:
			health -= delta * 16.0
			if health <= 0.0:
				health = 0.0
				status_label.text = "You were overrun"
				_game_over()
				return

func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var data: Dictionary = projectiles[i]
		var node: MeshInstance3D = data.get("node")
		if node == null:
			projectiles.remove_at(i)
			continue
		var velocity: Vector3 = data.get("velocity", Vector3.ZERO)
		node.position += velocity * delta
		data["life"] = float(data.get("life", 0.0)) - delta
		if data["life"] <= 0.0:
			node.queue_free()
			projectiles.remove_at(i)
			continue
		for j in range(enemies.size() - 1, -1, -1):
			var enemy = enemies[j]
			if enemy == null:
				continue
			if node.global_position.distance_to(enemy.global_position) < 1.0:
				enemy.queue_free()
				enemies.remove_at(j)
				score += 10
				node.queue_free()
				projectiles.remove_at(i)
				break
	if enemies.is_empty() and not game_over:
		wave += 1
		score += 50
		health = minf(100.0, health + 15.0)
		_spawn_wave()
		status_label.text = "Wave %d · Score %d" % [wave, score]

func _game_over() -> void:
	if game_over:
		return
	game_over = true
	status_label.text = "Mission failed · Press Esc"
	hud_label.text = "Health 0"

func _exit() -> void:
	emit_signal("exited")

func _physics_process(delta: float) -> void:
	if game_over:
		if Input.is_key_pressed(KEY_ESCAPE):
			_exit()
		return
	_update_player(delta)
	_update_enemies(delta)
	if game_over:
		return
	_update_projectiles(delta)
	hud_label.text = "Health %d" % [int(clampf(health, 0.0, 100.0))]
	status_label.text = "Wave %d · Score %d" % [wave, score]
	if Input.is_key_pressed(KEY_ESCAPE):
		_exit()
