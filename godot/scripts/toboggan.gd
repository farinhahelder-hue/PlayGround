class_name BanquiseToboggan
extends Node3D

# Mode « Toboggan » : descente automatique, portes-réponses à traverser ou à tirer,
# blocs de glace destructibles, vies, combo et record séparé.
# Tout est construit par code, sans ressource externe.

signal exited

const Gen = preload("res://scripts/generators.gd")

const THEMES := ["nombres", "mesures", "grammaire", "conjugaison", "sciences", "anglais", "logique"]
const THEME_LABELS := {
	"nombres": "Nombres",
	"mesures": "Mesures",
	"grammaire": "Grammaire",
	"conjugaison": "Conjugaison",
	"sciences": "Sciences",
	"anglais": "Anglais",
	"logique": "Logique",
}
const CHAR_NAMES := ["Émilie", "Night Squirrel", "Monica"]
const LANE_COLORS := [
	Color(1.0, 0.42, 0.52),
	Color(1.0, 0.74, 0.34),
	Color(0.36, 0.95, 0.78),
	Color(0.42, 0.72, 1.0),
]

const MAX_HEARTS := 3
const PLAYER_LIMIT := 5.25
const BASE_SPEED := 8.0
const MAX_SPEED := 15.0
const SPEED_PER_ANSWER := 0.35
const LATERAL_SPEED := 7.2
const GATE_Z := -28.0
const OBSTACLE_SPAWN_Z := -24.0
const TILE_LEN := 16.0
const TILE_COUNT := 24
const TRACK_LEN := TILE_LEN * TILE_COUNT
const FIRE_CD := 0.17
const GOOD_PAUSE := 0.55
const BAD_PAUSE := 0.95
const GATE_TOLERANCE := 1.42
const MAX_OBSTACLES := 6

# --- état de jeu ---
var niveau := "CE2"
var char_index := 0
var host: Node = null
var built := false
var save_path := "user://banquise_toboggan.cfg"

var hearts := MAX_HEARTS
var score := 0
var best := 0
var streak := 0
var best_streak := 0
var correct_count := 0
var answered := 0
var obstacle_kills := 0
var game_over := false
var accepting := false
var pending_over := 0.0
var resolve_timer := 0.0
var invuln := 0.0
var speed := BASE_SPEED
var distance := 0.0
var lateral := 0.0
var fire_cd := 0.0
var shake_strength := 0.0
var flash_alpha := 0.0
var obstacle_timer := 1.8
var t_accum := 0.0

var question: Dictionary = {}
var theme := "nombres"
var theme_bag: Array = []
var recent: Array = []

var track_tiles: Array = []
var gate: Node3D = null
var gate_items: Array = []
var obstacles: Array = []

# --- noeuds ---
var player: Node3D
var visual: Node3D
var camera: Camera3D
var canvas: CanvasLayer
var ui_root: Control
var hud_left: Label
var hud_right: Label
var hearts_label: Label
var speed_label: Label
var q_label: Label
var feedback: Label
var opt_chips: Array = []
var input_field: LineEdit
var weapon_label: Label
var reticle: Label
var flash_rect: ColorRect
var over_root: Control
var over_score: Label
var over_meta: Label


func setup(level: String, char_idx: int, host_node: Node) -> void:
	if built:
		return
	niveau = level if level in ["CP", "CE1", "CE2"] else "CE2"
	char_index = clampi(char_idx, 0, CHAR_NAMES.size() - 1)
	host = host_node
	_load_best()
	_build_track()
	_build_player()
	_build_ui()
	built = true
	_restart()


# ---------- sauvegarde ----------

func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		best = int(cfg.get_value("toboggan", "best", 0))

func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("toboggan", "best", best)
	cfg.save(save_path)


# ---------- construction 3D ----------

func _build_track() -> void:
	var water := MeshInstance3D.new()
	var wm := PlaneMesh.new()
	wm.size = Vector2(500, 500)
	water.mesh = wm
	water.material_override = _mat(Color(0.05, 0.18, 0.33), 0.2)
	water.position.y = -0.8
	add_child(water)

	for i in range(TILE_COUNT):
		var tile := Node3D.new()
		tile.name = "Neige"
		tile.position = Vector3(0, 0, 8.0 - float(i) * TILE_LEN)
		add_child(tile)
		track_tiles.append(tile)

		var ice := MeshInstance3D.new()
		var im := BoxMesh.new()
		im.size = Vector3(12.4, 0.3, TILE_LEN)
		ice.mesh = im
		ice.material_override = _mat(Color(0.80, 0.91, 1.0), 0.35)
		ice.position = Vector3(0, -0.15, 0)
		tile.add_child(ice)

		for x in [-6.0, -3.0, 0.0, 3.0, 6.0]:
			var line := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.06, 0.025, TILE_LEN)
			line.mesh = lm
			line.material_override = _emissive_mat(Color(0.48, 0.76, 1.0), 0.25)
			line.position = Vector3(x, 0.015, 0)
			tile.add_child(line)

		for sx in [-5.82, 5.82]:
			var dash := MeshInstance3D.new()
			var dm := BoxMesh.new()
			dm.size = Vector3(0.14, 0.03, 11.0)
			dash.mesh = dm
			dash.material_override = _emissive_mat(LANE_COLORS[0] if i % 2 == 0 else LANE_COLORS[3], 0.8)
			dash.position = Vector3(sx, 0.02, 0)
			tile.add_child(dash)

		for sx in [-7.35, 7.35]:
			var bank := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(2.6, 0.62, TILE_LEN)
			bank.mesh = bm
			bank.material_override = _mat(Color(0.88, 0.95, 1.0), 0.7)
			bank.position = Vector3(sx, 0.02, 0)
			tile.add_child(bank)

			var fir := MeshInstance3D.new()
			var fm := CylinderMesh.new()
			fm.top_radius = 0.02
			fm.bottom_radius = 0.38
			fm.height = 1.7
			fm.radial_segments = 7
			fir.mesh = fm
			fir.material_override = _mat(Color(0.22, 0.47, 0.43), 0.7)
			fir.position = Vector3(sx + (0.8 if sx > 0 else -0.8), 1.05, -4.0 + float(i % 4) * 3.0)
			tile.add_child(fir)

	# montagnes lointaines
	for i in range(10):
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = randf_range(11.0, 21.0)
		cm.height = randf_range(16.0, 34.0)
		cm.radial_segments = 6
		m.mesh = cm
		m.material_override = _mat(Color(0.55, 0.72, 0.9), 0.9)
		m.position = Vector3(
			(-1.0 if i % 2 == 0 else 1.0) * randf_range(24.0, 62.0),
			cm.height * 0.5 - 0.8,
			-60.0 - randf() * 180.0
		)
		add_child(m)


func _reset_track() -> void:
	for i in range(track_tiles.size()):
		track_tiles[i].position.z = 8.0 - float(i) * TILE_LEN


func _build_player() -> void:
	player = Node3D.new()
	player.name = "Toboggan"
	player.position = Vector3(0, 0, 0)
	add_child(player)

	visual = Node3D.new()
	visual.name = "Perso"
	player.add_child(visual)

	# luge
	_part(visual, _box_mesh(Vector3(1.28, 0.16, 2.05)), Color(0.1, 0.43, 0.6), Vector3(0, 0.22, 0))
	_part(visual, _box_mesh(Vector3(1.0, 0.34, 0.34)), Color(0.14, 0.55, 0.72), Vector3(0, 0.42, -1.0))
	for sx in [-0.52, 0.52]:
		_part(visual, _box_mesh(Vector3(0.11, 0.1, 2.42)), Color(0.14, 0.19, 0.26), Vector3(sx, 0.08, 0))
	# canon à neige
	_part(visual, _box_mesh(Vector3(0.22, 0.22, 0.9)), Color(0.7, 0.86, 1.0), Vector3(0.58, 0.78, -0.55))
	var barrel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.12
	cyl.height = 0.55
	barrel.mesh = cyl
	barrel.material_override = _mat(Color(0.85, 0.95, 1.0), 0.3)
	barrel.rotation_degrees = Vector3(90, 0, 0)
	barrel.position = Vector3(0.58, 0.78, -1.05)
	visual.add_child(barrel)

	var body: Node3D = null
	if host != null and host.has_method("_make_char"):
		body = host._make_char(char_index)
	if body != null:
		body.scale = Vector3(0.72, 0.72, 0.72)
		body.position = Vector3(0, 0.30, 0.05)
		body.rotation.y = PI
		visual.add_child(body)
		for ch in body.get_children():
			if ch is Label3D:
				ch.visible = false
	else:
		var torso := MeshInstance3D.new()
		torso.mesh = _capsule(0.3, 0.9)
		torso.material_override = _mat(Color(0.95, 0.55, 0.7), 0.6)
		torso.position = Vector3(0, 1.0, 0)
		visual.add_child(torso)

	var light := OmniLight3D.new()
	light.light_color = Color(0.55, 0.8, 1.0)
	light.light_energy = 0.7
	light.omni_range = 10.0
	light.position = Vector3(0, 2.4, 0.4)
	player.add_child(light)

	camera = Camera3D.new()
	camera.fov = 64.0
	camera.far = 400.0
	camera.position = Vector3(0, 5.0, 8.6)
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0, 1.3, -12.0))

func _build_ui() -> void:
	canvas = CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)

	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui_root)

	hud_left = _make_label("", 18)
	hud_left.position = Vector2(24, 12)
	hud_left.size = Vector2(310, 26)
	ui_root.add_child(hud_left)

	hearts_label = _make_label("", 26, Color(1.0, 0.47, 0.58))
	hearts_label.position = Vector2(24, 38)
	hearts_label.size = Vector2(220, 34)
	ui_root.add_child(hearts_label)

	speed_label = _make_label("", 15, Color(0.68, 0.86, 1.0))
	speed_label.position = Vector2(24, 74)
	speed_label.size = Vector2(310, 24)
	ui_root.add_child(speed_label)

	hud_right = _make_label("", 17, Color(0.72, 0.88, 1.0))
	hud_right.anchor_left = 1.0
	hud_right.anchor_right = 1.0
	hud_right.offset_left = -330
	hud_right.offset_right = -24
	hud_right.offset_top = 12
	hud_right.offset_bottom = 54
	hud_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui_root.add_child(hud_right)

	var qpanel := PanelContainer.new()
	qpanel.anchor_left = 0.5
	qpanel.anchor_right = 0.5
	qpanel.offset_left = -300
	qpanel.offset_right = 300
	qpanel.offset_top = 6
	qpanel.offset_bottom = 86
	qpanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qpanel.add_theme_stylebox_override("panel", _stylebox(Color(0.03, 0.11, 0.19, 0.9), 16, 1))
	ui_root.add_child(qpanel)
	var qmargin := MarginContainer.new()
	for side in ["left", "right"]:
		qmargin.add_theme_constant_override("margin_" + side, 16)
	for side in ["top", "bottom"]:
		qmargin.add_theme_constant_override("margin_" + side, 7)
	qpanel.add_child(qmargin)
	q_label = _make_label("", 23)
	q_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qmargin.add_child(q_label)

	var opt_row := HBoxContainer.new()
	opt_row.anchor_left = 0.5
	opt_row.anchor_right = 0.5
	opt_row.offset_left = -300
	opt_row.offset_right = 300
	opt_row.offset_top = 92
	opt_row.offset_bottom = 140
	opt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	opt_row.add_theme_constant_override("separation", 8)
	opt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(opt_row)
	opt_chips.clear()
	for i in range(4):
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(144, 48)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cm := MarginContainer.new()
		for side in ["left", "right"]:
			cm.add_theme_constant_override("margin_" + side, 5)
		for side in ["top", "bottom"]:
			cm.add_theme_constant_override("margin_" + side, 3)
		var lab := _make_label("", 15)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.max_lines_visible = 2
		lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cm.add_child(lab)
		chip.add_child(cm)
		opt_row.add_child(chip)
		opt_chips.append({"panel": chip, "label": lab})

	feedback = _make_label("", 24, Color(0.8, 1.0, 0.85))
	feedback.anchor_left = 0.5
	feedback.anchor_right = 0.5
	feedback.offset_left = -520
	feedback.offset_right = 520
	feedback.offset_top = 146
	feedback.offset_bottom = 214
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui_root.add_child(feedback)

	var bottom := PanelContainer.new()
	bottom.anchor_top = 1.0
	bottom.anchor_right = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.offset_top = -106
	bottom.offset_bottom = -10
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_stylebox_override("panel", _stylebox(Color(0.03, 0.11, 0.19, 0.92), 16, 1))
	ui_root.add_child(bottom)
	var bmargin := MarginContainer.new()
	bmargin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		bmargin.add_theme_constant_override("margin_" + side, 16)
	for side in ["top", "bottom"]:
		bmargin.add_theme_constant_override("margin_" + side, 7)
	bottom.add_child(bmargin)
	var bvb := VBoxContainer.new()
	bvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bvb.add_theme_constant_override("separation", 3)
	bmargin.add_child(bvb)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	bvb.add_child(row)

	input_field = LineEdit.new()
	input_field.placeholder_text = "Écris la réponse, puis Entrée = tir guidé !"
	input_field.custom_minimum_size = Vector2(520, 46)
	input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_field.add_theme_font_size_override("font_size", 20)
	input_field.add_theme_color_override("font_color", Color(0.95, 0.99, 1.0))
	input_field.add_theme_color_override("font_placeholder_color", Color(0.55, 0.72, 0.88))
	input_field.add_theme_stylebox_override("normal", _stylebox(Color(0.06, 0.18, 0.28), 12, 1))
	input_field.add_theme_stylebox_override("focus", _stylebox(Color(0.08, 0.24, 0.36), 12, 2))
	input_field.text_submitted.connect(_on_text_submitted)
	input_field.gui_input.connect(_on_input_gui_event)
	row.add_child(input_field)

	weapon_label = _make_label("", 16, Color(0.72, 0.88, 1.0))
	weapon_label.custom_minimum_size = Vector2(330, 0)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(weapon_label)

	var hint := _make_label(
		"A/D ou flèches : diriger   ·   Clic / Espace : tirer   ·   1 à 4 : tirer une porte   ·   T/Tab : écrire   ·   Échap : menu",
		14,
		Color(0.62, 0.8, 0.95)
	)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bvb.add_child(hint)

	reticle = _make_label("+", 32, Color(0.8, 0.96, 1.0, 0.95))
	reticle.size = Vector2(30, 30)
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(reticle)

	flash_rect = ColorRect.new()
	flash_rect.color = Color(1.0, 0.25, 0.3, 0.0)
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(flash_rect)

	_build_over()
	ui_root.move_child(flash_rect, 0)


func _build_over() -> void:
	over_root = Control.new()
	over_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_root.mouse_filter = Control.MOUSE_FILTER_STOP
	over_root.visible = false
	ui_root.add_child(over_root)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.05, 0.09, 0.76)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_root.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _stylebox(Color(0.03, 0.12, 0.2, 0.97), 22, 2))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 46)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	margin.add_child(vb)

	var title := _make_label("Descente terminée", 36, Color(0.92, 0.98, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	over_score = _make_label("", 26)
	over_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(over_score)
	over_meta = _make_label("", 19, Color(0.7, 0.87, 1.0))
	over_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	over_meta.custom_minimum_size = Vector2(500, 0)
	vb.add_child(over_meta)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	var retry := _make_button("Rejouer", Vector2(200, 52), 21)
	retry.pressed.connect(_restart)
	row.add_child(retry)
	var menu := _make_button("Menu", Vector2(170, 52), 21)
	menu.pressed.connect(exit_toboggan)
	row.add_child(menu)

# ---------- boucle de jeu ----------

func _process(delta: float) -> void:
	if not built:
		return
	t_accum += delta
	fire_cd = maxf(0.0, fire_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	shake_strength = maxf(0.0, shake_strength - delta * 2.6)
	if flash_alpha > 0.0:
		flash_alpha = maxf(0.0, flash_alpha - delta * 1.5)
	if flash_rect != null:
		flash_rect.color = Color(1.0, 0.25, 0.3, flash_alpha)
	var shake := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * shake_strength

	if game_over:
		_update_camera(delta, shake)
		return

	if pending_over > 0.0:
		pending_over = maxf(0.0, pending_over - delta)
		speed = maxf(0.0, speed - delta * 4.0)
		if pending_over <= 0.0:
			_show_game_over()
			return

	# direction
	var steer := 0.0
	if input_field == null or not input_field.has_focus():
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_LEFT):
			steer -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			steer += 1.0
	if pending_over <= 0.0:
		var target_lat := steer * LATERAL_SPEED
		lateral = move_toward(lateral, target_lat, (16.0 if steer != 0.0 else 22.0) * delta)
		player.position.x = clampf(player.position.x + lateral * delta, -PLAYER_LIMIT, PLAYER_LIMIT)
		distance += speed * delta

	# défilement de la piste
	for tile in track_tiles:
		tile.position.z += speed * delta
		if tile.position.z > 24.0:
			tile.position.z -= TRACK_LEN

	# portes-réponses
	if gate != null and is_instance_valid(gate):
		gate.position.z += speed * delta
		if accepting and gate.position.z >= 0.0:
			_check_gate_crossing()

	# blocs de glace
	for o in obstacles.duplicate():
		if not is_instance_valid(o):
			obstacles.erase(o)
			continue
		o.position.z += (speed + 4.5) * delta
		o.rotation.y += delta * 0.9
		if o.position.z > 14.0:
			obstacles.erase(o)
			o.queue_free()
			continue
		if accepting and pending_over <= 0.0 and invuln <= 0.0 and o.position.z > -1.15 and o.position.z < 1.15 and absf(player.position.x - o.position.x) < 1.05:
			_destroy_obstacle(o, false)

	if accepting and pending_over <= 0.0:
		obstacle_timer -= delta
		if obstacle_timer <= 0.0:
			obstacle_timer = randf_range(1.5, 2.8)
			if obstacles.size() < MAX_OBSTACLES:
				_spawn_obstacle()

	if not accepting and resolve_timer > 0.0 and pending_over <= 0.0:
		resolve_timer = maxf(0.0, resolve_timer - delta)
		if resolve_timer <= 0.0:
			_new_question()

	_update_camera(delta, shake)

	visual.position.y = sin(t_accum * 7.0) * 0.035
	visual.rotation.z = lerpf(visual.rotation.z, -lateral * 0.035, 1.0 - exp(-10.0 * delta))

	if reticle != null:
		var mp := get_viewport().get_mouse_position()
		reticle.position = mp - reticle.size * 0.5
	if speed_label != null:
		speed_label.text = "%d km/h   ·   %d m" % [int(speed * 3.6), int(distance)]


func _update_camera(delta: float, shake: Vector3) -> void:
	if camera == null:
		return
	var desired := Vector3(player.position.x * 0.5, 5.0, 8.6) + shake
	var k := 1.0 - exp(-5.5 * delta)
	camera.position = camera.position.lerp(desired, k)
	camera.look_at(Vector3(player.position.x * 0.7, 1.3, -12.0))


func _restart() -> void:
	game_over = false
	pending_over = 0.0
	resolve_timer = 0.0
	hearts = MAX_HEARTS
	score = 0
	streak = 0
	best_streak = 0
	correct_count = 0
	answered = 0
	obstacle_kills = 0
	speed = BASE_SPEED
	distance = 0.0
	lateral = 0.0
	fire_cd = 0.0
	invuln = 0.0
	shake_strength = 0.0
	flash_alpha = 0.0
	obstacle_timer = 1.8
	over_root.visible = false
	_clear_gate()
	_clear_obstacles()
	player.position = Vector3(0, 0, 0)
	visual.position = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	camera.position = Vector3(0, 5.0, 8.6)
	input_field.text = ""
	input_field.release_focus()
	_reset_track()
	theme_bag.clear()
	recent.clear()
	_update_hud()
	_new_question()


func _new_question() -> void:
	if game_over or pending_over > 0.0:
		return
	_clear_gate()
	resolve_timer = 0.0
	accepting = true
	theme = _pick_theme()
	var tries := 0
	while true:
		question = Gen.question(theme, niveau)
		tries += 1
		if tries >= 8 or recent.find(str(question.get("q", ""))) < 0:
			break
	recent.append(str(question.get("q", "")))
	if recent.size() > 16:
		recent.pop_front()
	_build_gate()
	_apply_question()
	if host != null and host.has_method("_speak"):
		host._speak(str(question.get("q", "")))


func _pick_theme() -> String:
	if theme_bag.is_empty():
		theme_bag = THEMES.duplicate()
		theme_bag.shuffle()
	return str(theme_bag.pop_back())


func _apply_question() -> void:
	q_label.text = str(question.get("q", ""))
	hud_right.text = "%s · %s\n%s" % [
		CHAR_NAMES[char_index],
		niveau,
		str(THEME_LABELS.get(theme, theme)),
	]
	var opts: Array = question.get("opts", [])
	for i in range(opt_chips.size()):
		var chip: Dictionary = opt_chips[i]
		var panel: PanelContainer = chip["panel"]
		var lab: Label = chip["label"]
		if i < opts.size():
			panel.visible = true
			lab.text = "%d  %s" % [i + 1, str(opts[i])]
			panel.add_theme_stylebox_override("panel", _chip_style(LANE_COLORS[i % LANE_COLORS.size()]))
		else:
			panel.visible = false
	input_field.text = ""
	input_field.release_focus()
	feedback.text = ""
	_update_hud()


func _update_hud() -> void:
	if hud_left == null:
		return
	var hearts_txt := ""
	for i in range(MAX_HEARTS):
		hearts_txt += "❤" if i < hearts else "♡"
	hud_left.text = "Score %d   ·   Série x%d   ·   Record %d" % [score, streak, best]
	hearts_label.text = hearts_txt
	speed_label.text = "%d km/h   ·   %d m" % [int(speed * 3.6), int(distance)]
	weapon_label.text = "Blocs détruits : %d\nClic / Espace : tirer" % obstacle_kills


func _show_feedback(text: String, color: Color) -> void:
	feedback.text = text
	feedback.add_theme_color_override("font_color", color)

# ---------- portes-réponses ----------

func _build_gate() -> void:
	var opts: Array = question.get("opts", [])
	if opts.is_empty():
		return
	var xs := _gate_positions(opts.size())
	gate = Node3D.new()
	gate.name = "Portes"
	gate.position = Vector3(0, 0, GATE_Z)
	add_child(gate)
	gate_items.clear()
	for i in range(opts.size()):
		var node := _make_gate_item(i, str(opts[i]), float(xs[i]))
		gate.add_child(node)
		gate_items.append({"node": node, "index": i, "x": float(xs[i])})


func _gate_positions(count: int) -> Array:
	match count:
		1:
			return [0.0]
		2:
			return [-2.4, 2.4]
		3:
			return [-4.2, 0.0, 4.2]
		_:
			return [-4.5, -1.5, 1.5, 4.5]


func _make_gate_item(i: int, txt: String, x: float) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(x, 0, 0)
	root.set_meta("index", i)
	root.set_meta("text", txt)
	var color: Color = LANE_COLORS[i % LANE_COLORS.size()]
	var frames: Array = []
	var frame_mat := _emissive_mat(color, 2.4)

	for sx in [-1.34, 1.34]:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.2, 3.05, 0.2)
		post.mesh = pm
		post.material_override = frame_mat
		post.position = Vector3(sx, 1.53, 0)
		root.add_child(post)
		frames.append(post)

	var top := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(2.88, 0.24, 0.24)
	top.mesh = tm
	top.material_override = frame_mat
	top.position = Vector3(0, 3.05, 0)
	root.add_child(top)
	frames.append(top)

	var bottom := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.88, 0.18, 0.18)
	bottom.mesh = bm
	bottom.material_override = frame_mat
	bottom.position = Vector3(0, 0.1, 0)
	root.add_child(bottom)
	frames.append(bottom)

	var beacon := MeshInstance3D.new()
	beacon.mesh = _sphere(0.3)
	beacon.material_override = _emissive_mat(color, 2.0)
	beacon.position = Vector3(0, 4.0, 0)
	root.add_child(beacon)

	var panel := MeshInstance3D.new()
	var pm2 := BoxMesh.new()
	pm2.size = Vector3(2.55, 2.8, 0.05)
	panel.mesh = pm2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.09, 0.16, 0.62)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	panel.material_override = mat
	panel.position = Vector3(0, 1.55, 0)
	root.add_child(panel)

	var num := Label3D.new()
	num.text = str(i + 1)
	num.font_size = 150
	num.pixel_size = 0.014
	num.width = 0.0
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.modulate = Color(1, 1, 1)
	num.outline_size = 20
	num.outline_modulate = Color(0.01, 0.05, 0.1, 0.95)
	num.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	num.no_depth_test = true
	num.render_priority = 3
	num.position = Vector3(0, 1.55, 0.12)
	root.add_child(num)

	root.set_meta("frames", frames)
	return root


func _clear_gate() -> void:
	if gate != null and is_instance_valid(gate):
		gate.queue_free()
	gate = null
	gate_items.clear()


func _gate_flash(index: int, good: bool) -> void:
	var color := Color(0.5, 1.0, 0.65) if good else Color(1.0, 0.45, 0.4)
	for it in gate_items:
		if int(it["index"]) != index:
			continue
		var node: Node3D = it["node"]
		if not is_instance_valid(node):
			return
		_burst(node.global_position + Vector3(0, 1.55, 0), color)
		var frames: Array = node.get_meta("frames", [])
		for f in frames:
			if is_instance_valid(f):
				f.material_override = _emissive_mat(color, 2.3)
		var tw := create_tween()
		tw.tween_property(node, "scale", Vector3(1.1, 1.1, 1.1), 0.08)
		tw.tween_property(node, "scale", Vector3.ONE, 0.18)
		return


func _check_gate_crossing() -> void:
	if gate == null or gate_items.is_empty() or not accepting:
		return
	var nearest := -1
	var best_d := GATE_TOLERANCE
	for it in gate_items:
		var d := absf(player.position.x - float(it["x"]))
		if d <= best_d:
			best_d = d
			nearest = int(it["index"])
	if nearest >= 0:
		_resolve(nearest, false, "pass")
	else:
		_resolve(-1, false, "miss")


func _resolve(index: int, typed: bool, source := "pass") -> void:
	if not accepting or game_over:
		return
	accepting = false
	var opts: Array = question.get("opts", [])
	var ans := int(question.get("ans", -1))
	var correct := index == ans and ans >= 0
	answered += 1
	if correct:
		streak += 1
		best_streak = maxi(best_streak, streak)
		correct_count += 1
		var mult := 1.0 + float(mini(streak - 1, 6)) * 0.2
		var pts := int(round((80.0 + speed * 4.0) * mult))
		if source == "shot":
			pts += 25
		elif typed:
			pts += 45
		score += pts
		speed = minf(MAX_SPEED, BASE_SPEED + float(correct_count) * SPEED_PER_ANSWER)
		var msg := "Bravo ! +%d" % pts
		if typed:
			msg += "  (tir guidé)"
		if streak > 0 and streak % 5 == 0:
			msg += "   ★ Série x%d !" % streak
		_show_feedback(msg, Color(0.6, 1.0, 0.72))
		_play("ok")
		if gate != null:
			_gate_flash(index, true)
		resolve_timer = GOOD_PAUSE
	else:
		streak = 0
		var good := ""
		if ans >= 0 and ans < opts.size():
			good = str(opts[ans])
		if index < 0 and source == "miss":
			_show_feedback("Aucune porte franchie ! La bonne réponse : %s" % good, Color(1.0, 0.82, 0.55))
			_play("no")
		else:
			_show_feedback("Raté ! La bonne réponse : %s" % good, Color(1.0, 0.7, 0.6))
			_play("no")
			_lose_hearts(1)
		if gate != null and index >= 0:
			_gate_flash(index, false)
		resolve_timer = BAD_PAUSE
	if hearts <= 0 or pending_over > 0.0:
		resolve_timer = 0.0
	_update_hud()

# ---------- blocs de glace et tir ----------

func _spawn_obstacle() -> void:
	_spawn_obstacle_at(randf_range(-5.0, 5.0), OBSTACLE_SPAWN_Z)


func _spawn_obstacle_at(x: float, z: float) -> Node3D:
	var root := Node3D.new()
	root.name = "BlocDeGlace"
	root.position = Vector3(x, 0, z)
	add_child(root)

	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.55, 1.15, 1.55)
	base.mesh = bm
	base.material_override = _emissive_mat(Color(0.62, 0.86, 1.0), 0.3)
	base.position.y = 0.62
	root.add_child(base)

	for k in range(3):
		var shard := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.28
		cm.height = 0.9
		cm.radial_segments = 5
		shard.mesh = cm
		shard.material_override = _emissive_mat(Color(0.76, 0.93, 1.0), 0.45)
		shard.position = Vector3(-0.35 + 0.35 * k, 1.45, -0.3 + 0.3 * k)
		shard.rotation_degrees = Vector3(randf_range(-20.0, 20.0), 0.0, randf_range(-25.0, 25.0))
		root.add_child(shard)

	var warn := Label3D.new()
	warn.text = "!"
	warn.font_size = 64
	warn.pixel_size = 0.014
	warn.modulate = Color(1.0, 0.42, 0.42)
	warn.outline_size = 10
	warn.outline_modulate = Color(0.2, 0.02, 0.02, 0.95)
	warn.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	warn.position = Vector3(0, 2.35, 0)
	root.add_child(warn)

	root.set_meta("phase", randf() * TAU)
	obstacles.append(root)
	return root


func _destroy_obstacle(o: Node3D, by_shot: bool) -> void:
	if not is_instance_valid(o):
		return
	var idx := obstacles.find(o)
	if idx < 0:
		return
	obstacles.remove_at(idx)
	var pos := o.global_position + Vector3(0, 0.7, 0)
	if by_shot:
		obstacle_kills += 1
		var pts := 12 + int(speed * 0.8)
		score += pts
		_show_feedback("Bloc détruit ! +%d" % pts, Color(0.72, 0.95, 1.0))
		_show_floating_text(pos, "+%d" % pts, Color(0.75, 0.95, 1.0))
		_play("boom")
		_burst(pos, Color(0.72, 0.94, 1.0))
		shake_strength = maxf(shake_strength, 0.12)
	else:
		_burst(pos, Color(0.86, 0.93, 1.0))
		_show_feedback("Aïe ! Bloc de glace", Color(1.0, 0.62, 0.56))
		_hurt(1)
	o.queue_free()
	_update_hud()


func _clear_obstacles() -> void:
	for o in obstacles:
		if is_instance_valid(o):
			o.queue_free()
	obstacles.clear()


func _muzzle() -> Vector3:
	return player.global_position + Vector3(0.55, 1.0, -0.9)


func _try_fire() -> void:
	if not built or game_over or pending_over > 0.0:
		return
	if input_field != null and input_field.has_focus():
		return
	if fire_cd > 0.0:
		return
	fire_cd = FIRE_CD
	_play("shot2")
	shake_strength = maxf(shake_strength, 0.06)
	var muzzle := _muzzle()
	var pick := _pick_at(get_viewport().get_mouse_position())
	if not pick.is_empty():
		var target_pos: Vector3 = pick["pos"]
		_fire_tracer(muzzle, target_pos, Color(0.75, 0.95, 1.0))
		if str(pick["kind"]) == "obstacle":
			_destroy_obstacle(pick["node"], true)
		elif str(pick["kind"]) == "gate":
			_resolve(int(pick["index"]), false, "shot")
	else:
		var mp := get_viewport().get_mouse_position()
		var from := camera.project_ray_origin(mp)
		var dir := camera.project_ray_normal(mp)
		_fire_tracer(muzzle, from + dir * 40.0, Color(0.7, 0.9, 1.0))


func _pick_at(screen: Vector2) -> Dictionary:
	if camera == null:
		return {}
	var best: Dictionary = {}
	var best_score := INF
	for o in obstacles:
		if not is_instance_valid(o):
			continue
		var wp: Vector3 = o.global_position + Vector3(0, 0.7, 0)
		if camera.is_position_behind(wp):
			continue
		var sp := camera.unproject_position(wp)
		var d := sp.distance_to(screen)
		if d <= 68.0 and d < best_score:
			best_score = d
			best = {"kind": "obstacle", "node": o, "pos": wp}
	for it in gate_items:
		var node: Node3D = it["node"]
		if not is_instance_valid(node):
			continue
		var wp: Vector3 = node.global_position + Vector3(0, 1.55, 0)
		if camera.is_position_behind(wp):
			continue
		var sp := camera.unproject_position(wp)
		var d := sp.distance_to(screen)
		if d <= 105.0 and d < best_score:
			best_score = d
			best = {"kind": "gate", "index": int(it["index"]), "node": node, "pos": wp}
	return best


func _shoot_gate_at(i: int) -> void:
	if not accepting or game_over or pending_over > 0.0:
		return
	if fire_cd > 0.0 or i < 0 or i >= gate_items.size():
		return
	fire_cd = FIRE_CD
	_play("shot2")
	var node: Node3D = gate_items[i]["node"]
	var pos: Vector3 = node.global_position + Vector3(0, 1.55, 0)
	_fire_tracer(_muzzle(), pos, LANE_COLORS[i % LANE_COLORS.size()])
	_resolve(i, false, "shot")

# ---------- réponse écrite et entrées ----------

func _on_text_submitted(raw: String) -> void:
	if not built:
		return
	if input_field != null:
		input_field.release_focus()
	if not accepting or game_over or pending_over > 0.0:
		return
	var norm := _norm(raw)
	if norm == "":
		return
	var opts: Array = question.get("opts", [])
	var target := -1
	for i in range(opts.size()):
		if _norm(str(opts[i])) == norm:
			target = i
			break
	if target < 0 and norm.length() >= 2:
		var matches: Array = []
		for i in range(opts.size()):
			var o := _norm(str(opts[i]))
			if o.begins_with(norm):
				matches.append(i)
		if matches.size() == 1:
			target = int(matches[0])
	if target >= 0 and target < gate_items.size():
		var node: Node3D = gate_items[target]["node"]
		var pos: Vector3 = node.global_position + Vector3(0, 1.55, 0)
		_fire_tracer(_muzzle(), pos, LANE_COLORS[target % LANE_COLORS.size()])
		_resolve(target, true, "typed")
	else:
		_resolve(-1, true, "typed")


func _norm(s: String) -> String:
	var out := s.strip_edges().to_lower()
	out = out.replace("é", "e").replace("è", "e").replace("ê", "e").replace("ë", "e")
	out = out.replace("à", "a").replace("â", "a").replace("ä", "a")
	out = out.replace("î", "i").replace("ï", "i")
	out = out.replace("ô", "o").replace("ö", "o")
	out = out.replace("ù", "u").replace("û", "u").replace("ü", "u")
	out = out.replace("ç", "c").replace("œ", "oe")
	out = out.replace(",", " ").replace(".", " ").replace(";", " ").replace(":", " ")
	out = out.replace("'", " ").replace("’", " ")
	out = out.replace("\t", " ")
	while out.find("  ") >= 0:
		out = out.replace("  ", " ")
	return out.strip_edges()


func _on_input_gui_event(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			input_field.release_focus()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not built:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if input_field != null and input_field.has_focus():
			if key.keycode == KEY_ESCAPE:
				input_field.release_focus()
				get_viewport().set_input_as_handled()
			return
		if game_over:
			if key.keycode == KEY_ESCAPE:
				exit_toboggan()
			return
		match key.keycode:
			KEY_T, KEY_TAB:
				if accepting and pending_over <= 0.0:
					input_field.grab_focus()
					get_viewport().set_input_as_handled()
			KEY_1, KEY_2, KEY_3, KEY_4:
				_shoot_gate_at(int(key.keycode - KEY_1))
				get_viewport().set_input_as_handled()
			KEY_SPACE:
				_try_fire()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				exit_toboggan()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if game_over:
				return
			if input_field != null and input_field.has_focus():
				input_field.release_focus()
			_try_fire()
			get_viewport().set_input_as_handled()


# ---------- vies et fin de partie ----------

func _lose_hearts(n: int) -> void:
	if game_over:
		return
	hearts = maxi(0, hearts - n)
	flash_alpha = 0.42
	_update_hud()
	if hearts <= 0:
		accepting = false
		resolve_timer = 0.0
		pending_over = 1.25


func _hurt(n: int) -> void:
	if invuln > 0.0 or game_over:
		return
	invuln = 1.25
	_lose_hearts(n)
	shake_strength = maxf(shake_strength, 0.32)
	_play("hurt")


func _show_game_over() -> void:
	if game_over:
		return
	game_over = true
	accepting = false
	pending_over = 0.0
	resolve_timer = 0.0
	_clear_gate()
	_clear_obstacles()
	var new_record := score > best
	best = maxi(best, score)
	_save_best()
	over_root.visible = true
	over_score.text = "Score : %d   ·   Meilleure série : x%d" % [score, best_streak]
	var record_txt := "Nouveau record !" if new_record else "Record : %d" % best
	var q_txt := "question" if answered <= 1 else "questions"
	var b_txt := "bloc détruit" if obstacle_kills <= 1 else "blocs détruits"
	over_meta.text = "%s\n%d m parcourus · %d %s · %d %s\n%s · %s" % [
		record_txt,
		int(distance),
		answered,
		q_txt,
		obstacle_kills,
		b_txt,
		niveau,
		CHAR_NAMES[char_index],
	]
	_play("level")
	get_viewport().set_input_as_handled()


func exit_toboggan() -> void:
	if score > best:
		best = score
	_save_best()
	exited.emit()

# ---------- effets ----------

func _fire_tracer(from: Vector3, to: Vector3, color: Color) -> void:
	var tracer := MeshInstance3D.new()
	tracer.mesh = _sphere(0.10)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	tracer.material_override = m
	add_child(tracer)
	tracer.global_position = from
	var tw := create_tween()
	tw.tween_property(tracer, "global_position", to, 0.07)
	tw.finished.connect(_on_tracer_done.bind(tracer, to, color))


func _on_tracer_done(tracer: Node3D, pos: Vector3, color: Color) -> void:
	_burst(pos, color)
	if is_instance_valid(tracer):
		tracer.queue_free()


func _burst(pos: Vector3, color: Color) -> void:
	for k in range(14):
		var s := MeshInstance3D.new()
		s.mesh = _sphere(0.09)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		s.material_override = mat
		add_child(s)
		s.global_position = pos
		var d := Vector3(randf_range(-1, 1), randf_range(0.2, 1.0), randf_range(-1, 1)).normalized()
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(s, "global_position", pos + d * randf_range(1.0, 2.4), 0.5)
		tw.tween_property(s, "scale", Vector3.ZERO, 0.5)
		tw.finished.connect(s.queue_free)


func _show_floating_text(pos: Vector3, text: String, color: Color) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 48
	lab.pixel_size = 0.012
	lab.outline_size = 12
	lab.outline_modulate = Color(0.02, 0.08, 0.15, 0.9)
	lab.modulate = color
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(lab)
	lab.global_position = pos
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lab, "position:y", pos.y + 1.2, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(lab, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tw.finished.connect(lab.queue_free)


func _play(sname: String) -> void:
	if host != null and host.has_method("_play"):
		host._play(sname)


# ---------- utilitaires ----------

func _mat(color: Color, rough := 0.65) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func _emissive_mat(color: Color, energy := 0.6) -> StandardMaterial3D:
	var m := _mat(color, 0.45)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 6
	return c


func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)
	return mi


func _stylebox(color: Color, radius := 14, border := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	if border > 0:
		sb.border_width_left = border
		sb.border_width_right = border
		sb.border_width_top = border
		sb.border_width_bottom = border
		sb.border_color = Color(0.55, 0.78, 1.0, 0.6)
	return sb


func _chip_style(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(c.r * 0.16 + 0.02, c.g * 0.16 + 0.04, c.b * 0.16 + 0.07, 0.94)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = c
	return sb


func _make_label(text: String, size := 20, color := Color(0.9, 0.96, 1.0)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _make_button(text: String, size := Vector2(220, 50), font := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.add_theme_font_size_override("font_size", font)
	b.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_stylebox_override("normal", _stylebox(Color(0.09, 0.29, 0.45)))
	b.add_theme_stylebox_override("hover", _stylebox(Color(0.13, 0.4, 0.6)))
	b.add_theme_stylebox_override("pressed", _stylebox(Color(0.07, 0.22, 0.36)))
	b.add_theme_stylebox_override("focus", _stylebox(Color(0.13, 0.4, 0.6), 14, 2))
	return b


# ---------- tests / debug ----------

func debug_state() -> Dictionary:
	var opts: Array = question.get("opts", [])
	return {
		"question": str(question.get("q", "")),
		"opts": opts,
		"ans": int(question.get("ans", -1)),
		"score": score,
		"hearts": hearts,
		"streak": streak,
		"accepting": accepting,
		"game_over": game_over,
		"best": best,
		"speed": speed,
		"distance": distance,
		"obstacles": obstacles.size(),
		"destroyed": obstacle_kills,
		"gate_count": gate_items.size(),
		"gate_z": (gate.position.z if gate != null and is_instance_valid(gate) else 999.0),
		"answered": answered,
		"pending_over": pending_over,
		"niveau": niveau,
		"theme": theme,
	}


func debug_shoot(index: int) -> void:
	if index < 0 or index >= gate_items.size():
		return
	_resolve(index, false, "shot")


func debug_type(text: String) -> void:
	_on_text_submitted(text)


func debug_skip() -> void:
	if not accepting and not game_over and pending_over <= 0.0:
		_new_question()


func debug_cross_gate() -> void:
	if gate == null or not is_instance_valid(gate):
		return
	gate.position.z = 0.05
	_check_gate_crossing()


func debug_set_player_x(x: float) -> void:
	player.position.x = x
	lateral = 0.0


func debug_spawn_obstacle(x: float = 0.0, z: float = -8.0) -> Node3D:
	return _spawn_obstacle_at(x, z)


func debug_shoot_obstacle(i: int) -> void:
	if i >= 0 and i < obstacles.size():
		_destroy_obstacle(obstacles[i], true)


func debug_collide_obstacle(i: int) -> void:
	if i >= 0 and i < obstacles.size():
		invuln = 0.0
		_destroy_obstacle(obstacles[i], false)


func debug_lose_hearts(n: int) -> void:
	_lose_hearts(n)


func debug_set_hearts(n: int) -> void:
	hearts = clampi(n, 0, MAX_HEARTS)
	_update_hud()
