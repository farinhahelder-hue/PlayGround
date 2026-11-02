extends Node3D

const Gen = preload("res://scripts/generators.gd")
const ActionScene = preload("res://scripts/action.gd")
const TobogganScene = preload("res://scripts/toboggan.gd")
const Quake2Scene = preload("res://scripts/quake2.gd")

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
const NIVEAUX := ["CP", "CE1", "CE2"]
const CHAR_NAMES := ["Émilie", "Night Squirrel", "Monica"]
const TURN_LEN := 5

var theme := "nombres"
var niveau := "CE2"
var bon := 0
var total := 0
var playing := false
var nonstop := false
var duo := false
var duo_turn := 0
var duo_scores := [0, 0]
var current_q: Dictionary = {}
var recent_qs: Array = []
var theme_order: Array = []
var theme_pos := 0
var current_char := 0
var chars: Array = []
var t_accum := 0.0
var capturing := false
var save_data := ConfigFile.new()
var sfx: Dictionary = {}
var tts_voice := ""
var last_speak_ms := 0
var action_mode: Node3D = null
var toboggan_mode: Node3D = null
var quake_mode: Node3D = null
var main_cam: Camera3D = null
var world_props: Array = []

var ui: CanvasLayer
var menu_root: Control
var play_root: Control
var results_root: Control
var q_label: Label
var opt_buttons: Array = []
var result_label: Label
var expl_label: Label
var next_button: Button
var score_label: Label
var theme_label: Label
var level_label: Label
var turn_label: Label
var final_label: Label
var final_meta: Label
var level_buttons: Array = []
var char_buttons: Array = []
var menu_play_button: Button
var results_button: Button
var results_action := "menu"


func _ready() -> void:
	capturing = OS.get_cmdline_user_args().has("--capture")
	_load_save()
	_build_world()
	_build_ui()
	_build_audio()
	_update_hud()
	_show_menu()
	_pick_tts_voice()
	_maybe_capture()
	if OS.get_cmdline_user_args().has("--arene"):
		start_arena()
	elif OS.get_cmdline_user_args().has("--toboggan"):
		start_toboggan()
	elif OS.get_cmdline_user_args().has("--quake2"):
		start_quake2()


func _process(delta: float) -> void:
	if action_mode != null or toboggan_mode != null or quake_mode != null:
		return
	t_accum += delta
	var cam := get_viewport().get_camera_3d()
	if cam:
		cam.position = Vector3(-0.6 + sin(t_accum * 0.18) * 0.8, 3.6 + sin(t_accum * 0.5) * 0.08, 8.4)
		cam.look_at(Vector3(-0.8, 1.8, 0))
	for i in range(chars.size()):
		var c = chars[i]
		if c and c.visible:
			c.position.y = 0.55 + sin(t_accum * 2.0 + i * 1.7) * 0.07
			c.rotation.y = sin(t_accum * 0.8 + i) * 0.16


# ---------- sauvegarde ----------

func _save_path() -> String:
	return "user://banquise.cfg"

func _load_save() -> void:
	if save_data.load(_save_path()) != OK:
		save_data = ConfigFile.new()
	niveau = str(save_data.get_value("jeu", "niveau", "CE2"))
	if niveau not in NIVEAUX:
		niveau = "CE2"
	current_char = int(save_data.get_value("jeu", "char", 0))
	if current_char < 0 or current_char > 2:
		current_char = 0
	duo_scores[0] = int(save_data.get_value("duo", "p1", 0))
	duo_scores[1] = int(save_data.get_value("duo", "p2", 0))

func _save() -> void:
	save_data.set_value("jeu", "niveau", niveau)
	save_data.set_value("jeu", "char", current_char)
	save_data.set_value("duo", "p1", duo_scores[0])
	save_data.set_value("duo", "p2", duo_scores[1])
	save_data.save(_save_path())


# ---------- audio ----------

func _build_audio() -> void:
	sfx["click"] = _tone([600], 0.05, 0.10)
	sfx["ok"] = _tone([520, 660], 0.09, 0.16)
	sfx["no"] = _tone([220], 0.15, 0.14)
	sfx["level"] = _tone([440, 550, 660], 0.11, 0.14)
	sfx["shot0"] = _tone([880, 620], 0.05, 0.10)
	sfx["shot1"] = _tone([620, 440, 330], 0.08, 0.12)
	sfx["shot2"] = _tone([1200, 900, 600], 0.04, 0.08)
	sfx["shot3"] = _tone([300, 220, 160], 0.12, 0.14)
	sfx["shot4"] = _tone([1000, 720, 480], 0.06, 0.11)
	sfx["shot5"] = _tone([140, 95, 70], 0.20, 0.17)
	sfx["boom"] = _tone([180, 120, 90], 0.16, 0.16)
	sfx["hurt"] = _tone([260, 180], 0.18, 0.16)

func _tone(freqs: Array, dur: float, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(rate * dur)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var idx := mini(int(float(i) / float(frames) * freqs.size()), freqs.size() - 1)
		var f: float = freqs[idx]
		var t := float(i) / float(rate)
		var env := 1.0 - float(i) / float(frames)
		var s := sin(TAU * f * t) * vol * env
		data.encode_s16(i * 2, int(clamp(s, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

func _play(name: String) -> void:
	if not sfx.has(name):
		return
	var p := AudioStreamPlayer.new()
	p.stream = sfx[name]
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func _pick_tts_voice() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var voices := DisplayServer.tts_get_voices()
	for v in voices:
		if str(v.get("language", "")).begins_with("fr"):
			tts_voice = str(v.get("id", ""))
			break

func _speak(text: String) -> void:
	if capturing or DisplayServer.get_name() == "headless" or text.strip_edges() == "":
		return
	var now := Time.get_ticks_msec()
	if now - last_speak_ms < 2200:
		return
	last_speak_ms = now
	var pitch := 50
	if current_char == 1:
		pitch = 42
	elif current_char == 2:
		pitch = 58
	DisplayServer.tts_speak(text, tts_voice, 90, pitch, 45, 0, true)


# ---------- monde 3D ----------

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.03, 0.07, 0.19)
	sm.sky_horizon_color = Color(0.23, 0.41, 0.62)
	sm.ground_bottom_color = Color(0.05, 0.12, 0.2)
	sm.ground_horizon_color = Color(0.23, 0.41, 0.62)
	sky.sky_material = sm
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.9
	e.fog_enabled = true
	e.fog_light_color = Color(0.11, 0.24, 0.38)
	e.fog_density = 0.007
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_color = Color(0.55, 0.75, 1.0)
	fill.light_energy = 0.5
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(fill)

	var cam := Camera3D.new()
	cam.position = Vector3(-0.6, 3.6, 8.4)
	cam.fov = 48
	add_child(cam)
	cam.look_at(Vector3(-0.8, 1.8, 0))
	main_cam = cam

	# eau
	var water := MeshInstance3D.new()
	var wm := PlaneMesh.new()
	wm.size = Vector2(400, 400)
	water.mesh = wm
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.08, 0.28, 0.45)
	water_mat.metallic = 0.4
	water_mat.roughness = 0.25
	water.material_override = water_mat
	water.position.y = -0.55
	add_child(water)
	world_props.append(water)

	# banquise
	var ice := MeshInstance3D.new()
	var im := CylinderMesh.new()
	im.top_radius = 5.0
	im.bottom_radius = 6.6
	im.height = 2.0
	im.radial_segments = 10
	ice.mesh = im
	var ice_mat := StandardMaterial3D.new()
	ice_mat.albedo_color = Color(0.86, 0.95, 1.0)
	ice_mat.roughness = 0.55
	ice.material_override = ice_mat
	ice.position.y = -0.45
	add_child(ice)
	world_props.append(ice)

	# blocs de glace
	for i in range(8):
		var a := randf() * TAU
		var r := 5.3 + randf() * 4.5
		var block := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5 + randf() * 0.9, 0.4 + randf() * 1.0, 0.5 + randf() * 0.9)
		block.mesh = bm
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.78, 0.92, 1.0)
		bmat.roughness = 0.6
		block.material_override = bmat
		block.position = Vector3(cos(a) * r, 0.15 + bm.size.y * 0.5, sin(a) * r - 1.5)
		block.rotation.y = randf() * TAU
		add_child(block)
		world_props.append(block)

	# étoiles
	var stars := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.12
	star_mesh.height = 0.24
	star_mesh.radial_segments = 6
	star_mesh.rings = 3
	mm.mesh = star_mesh
	mm.instance_count = 90
	var star_mat := StandardMaterial3D.new()
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.albedo_color = Color(0.9, 0.96, 1.0)
	stars.material_override = star_mat
	for i in range(90):
		var a := randf() * TAU
		var h := 6.0 + randf() * 34.0
		var rad := 40.0 + randf() * 18.0
		var xf := Transform3D(Basis(), Vector3(cos(a) * rad, h, sin(a) * rad - 10.0))
		mm.set_instance_transform(i, xf)
	stars.multimesh = mm
	add_child(stars)
	world_props.append(stars)

	# personnages
	chars.append(_make_char(0))
	chars.append(_make_char(1))
	chars.append(_make_char(2))
	for c in chars:
		add_child(c)
	chars[0].position = Vector3(-2.0, 0.55, 0)
	chars[1].position = Vector3(-2.0, 0.55, 0)
	chars[2].position = Vector3(-2.0, 0.55, 0)
	_show_char(current_char)

func _mat(color: Color, rough := 0.65) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)
	return mi

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

func _make_char(kind: int) -> Node3D:
	var g := Node3D.new()
	g.name = CHAR_NAMES[kind]
	if kind == 0:
		# Émilie : manteau rose, bonnet, bottes
		_part(g, _capsule(0.42, 1.25), Color(1.0, 0.62, 0.77), Vector3(0, 1.25, 0))
		_part(g, _sphere(0.36), Color(1.0, 0.86, 0.74), Vector3(0, 2.12, 0))
		_part(g, _sphere(0.4), Color(0.42, 0.27, 0.18), Vector3(0, 2.24, -0.05), Vector3(1, 0.7, 1))
		var hat := CylinderMesh.new()
		hat.top_radius = 0.4
		hat.bottom_radius = 0.46
		hat.height = 0.22
		_part(g, hat, Color(0.98, 0.83, 0.35), Vector3(0, 2.52, 0))
		_part(g, _sphere(0.08), Color(0.15, 0.17, 0.2), Vector3(-0.13, 2.12, 0.32))
		_part(g, _sphere(0.08), Color(0.15, 0.17, 0.2), Vector3(0.13, 2.12, 0.32))
		for sx in [-0.18, 0.18]:
			var leg := CylinderMesh.new()
			leg.top_radius = 0.13
			leg.bottom_radius = 0.13
			leg.height = 0.5
			_part(g, leg, Color(0.2, 0.28, 0.42), Vector3(sx, 0.55, 0))
		for sx in [-0.18, 0.18]:
			var boot := CylinderMesh.new()
			boot.top_radius = 0.14
			boot.bottom_radius = 0.17
			boot.height = 0.32
			_part(g, boot, Color(0.2, 0.28, 0.42), Vector3(sx, 0.16, 0))
	elif kind == 1:
		# Night Squirrel : écureuil bleu nuit
		_part(g, _capsule(0.4, 1.1), Color(0.13, 0.18, 0.32), Vector3(0, 1.05, 0))
		_part(g, _sphere(0.26), Color(0.93, 0.97, 1.0), Vector3(0, 1.05, 0.33), Vector3(1, 1.25, 0.5))
		_part(g, _sphere(0.34), Color(0.15, 0.21, 0.36), Vector3(0, 1.85, 0))
		_part(g, _sphere(0.1), Color(0.96, 0.98, 1.0), Vector3(-0.13, 1.9, 0.3))
		_part(g, _sphere(0.1), Color(0.96, 0.98, 1.0), Vector3(0.13, 1.9, 0.3))
		var ear := CylinderMesh.new()
		ear.top_radius = 0.02
		ear.bottom_radius = 0.11
		ear.height = 0.24
		_part(g, ear, Color(0.15, 0.21, 0.36), Vector3(-0.16, 2.18, 0))
		_part(g, ear, Color(0.15, 0.21, 0.36), Vector3(0.16, 2.18, 0))
		var tail := _sphere(0.42)
		_part(g, tail, Color(0.18, 0.26, 0.44), Vector3(0.05, 1.05, -0.45), Vector3(0.9, 1.5, 0.6))
		for sx in [-0.16, 0.16]:
			var leg := CylinderMesh.new()
			leg.top_radius = 0.11
			leg.bottom_radius = 0.11
			leg.height = 0.35
			_part(g, leg, Color(0.13, 0.18, 0.32), Vector3(sx, 0.42, 0))
		for sx in [-0.16, 0.16]:
			var foot := CylinderMesh.new()
			foot.top_radius = 0.1
			foot.bottom_radius = 0.13
			foot.height = 0.22
			_part(g, foot, Color(0.13, 0.18, 0.32), Vector3(sx, 0.12, 0))
	else:
		# Monica : robe rouge, cheveux blonds
		_part(g, _capsule(0.4, 1.15), Color(0.86, 0.24, 0.31), Vector3(0, 1.15, 0))
		_part(g, _sphere(0.35), Color(0.98, 0.84, 0.72), Vector3(0, 2.0, 0))
		_part(g, _sphere(0.38), Color(0.96, 0.8, 0.4), Vector3(0, 2.12, -0.04), Vector3(1, 0.75, 1))
		_part(g, _sphere(0.16), Color(0.96, 0.8, 0.4), Vector3(0.3, 1.85, -0.1))
		_part(g, _sphere(0.08), Color(0.18, 0.16, 0.15), Vector3(-0.13, 2.0, 0.31))
		_part(g, _sphere(0.08), Color(0.18, 0.16, 0.15), Vector3(0.13, 2.0, 0.31))
		for sx in [-0.17, 0.17]:
			var leg := CylinderMesh.new()
			leg.top_radius = 0.1
			leg.bottom_radius = 0.11
			leg.height = 0.58
			_part(g, leg, Color(0.98, 0.84, 0.72), Vector3(sx, 0.31, 0))
	var name_label := Label3D.new()
	name_label.text = CHAR_NAMES[kind]
	name_label.font_size = 64
	name_label.pixel_size = 0.006
	name_label.position = Vector3(0, 3.05, 0)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.modulate = Color(0.9, 0.97, 1.0)
	name_label.outline_size = 14
	name_label.outline_modulate = Color(0.03, 0.09, 0.16, 0.9)
	g.add_child(name_label)
	return g

func _show_char(idx: int) -> void:
	current_char = idx
	for i in range(chars.size()):
		chars[i].visible = (i == idx)
	save_data.set_value("jeu", "char", idx)
	save_data.save(_save_path())
	_refresh_char_buttons()


# ---------- interface ----------

func _stylebox(color: Color, radius := 16, border := 0) -> StyleBoxFlat:
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
		sb.border_color = Color(0.55, 0.78, 1.0, 0.55)
	return sb

func _make_button(text: String, size := Vector2(260, 54), font := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.add_theme_font_size_override("font_size", font)
	b.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_stylebox_override("normal", _stylebox(Color(0.09, 0.29, 0.45)))
	b.add_theme_stylebox_override("hover", _stylebox(Color(0.13, 0.4, 0.6)))
	b.add_theme_stylebox_override("pressed", _stylebox(Color(0.07, 0.22, 0.36)))
	b.add_theme_stylebox_override("focus", _stylebox(Color(0.13, 0.4, 0.6), 16, 2))
	return b

func _make_label(text: String, size := 20, color := Color(0.9, 0.96, 1.0)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)

	# barre du haut
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_right = -18
	top.offset_top = 14
	top.offset_bottom = 76
	top.add_theme_stylebox_override("panel", _stylebox(Color(0.04, 0.12, 0.2, 0.82)))
	root.add_child(top)
	var thin := MarginContainer.new()
	thin.add_theme_constant_override("margin_left", 18)
	thin.add_theme_constant_override("margin_right", 18)
	thin.add_theme_constant_override("margin_top", 8)
	thin.add_theme_constant_override("margin_bottom", 8)
	top.add_child(thin)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	thin.add_child(hb)
	hb.add_child(_make_label("Banquise En Folie", 24, Color(0.85, 0.95, 1.0)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)
	theme_label = _make_label("", 20)
	level_label = _make_label("", 20)
	score_label = _make_label("", 20)
	hb.add_child(theme_label)
	hb.add_child(level_label)
	hb.add_child(score_label)

	# zone de jeu
	play_root = Control.new()
	play_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(play_root)

	var card := PanelContainer.new()
	card.anchor_left = 0.0
	card.anchor_right = 1.0
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.offset_left = 48
	card.offset_right = -48
	card.offset_top = -18
	card.offset_bottom = -18
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.add_theme_stylebox_override("panel", _stylebox(Color(0.04, 0.12, 0.2, 0.9)))
	play_root.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	vb.add_child(head)
	turn_label = _make_label("", 18, Color(0.7, 0.86, 1.0))
	head.add_child(turn_label)

	q_label = _make_label("", 24)
	q_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_label.custom_minimum_size = Vector2(0, 62)
	vb.add_child(q_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	vb.add_child(grid)
	opt_buttons.clear()
	for i in range(4):
		var b := _make_button("", Vector2(540, 50), 20)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(answer.bind(i))
		grid.add_child(b)
		opt_buttons.append(b)

	result_label = _make_label("", 22)
	result_label.visible = false
	vb.add_child(result_label)
	expl_label = _make_label("", 17, Color(0.78, 0.9, 1.0))
	expl_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	expl_label.visible = false
	vb.add_child(expl_label)

	var next_row := HBoxContainer.new()
	next_row.alignment = BoxContainer.ALIGNMENT_END
	vb.add_child(next_row)
	next_button = _make_button("Suivant", Vector2(200, 44), 19)
	next_button.visible = false
	next_button.pressed.connect(next_question)
	next_row.add_child(next_button)

	_build_menu(root)
	_build_results(root)

func _build_menu(root: Control) -> void:
	menu_root = Control.new()
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.06, 0.11, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _stylebox(Color(0.04, 0.13, 0.22, 0.94), 22, 2))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	margin.add_child(vb)

	var title := _make_label("Banquise En Folie", 42, Color(0.9, 0.97, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := _make_label("CP · CE1 · CE2 — 7 thèmes de questions", 19, Color(0.68, 0.86, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)

	var lv_row := HBoxContainer.new()
	lv_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lv_row.add_theme_constant_override("separation", 10)
	vb.add_child(lv_row)
	level_buttons.clear()
	for lv in NIVEAUX:
		var b := _make_button(lv, Vector2(110, 46), 19)
		b.pressed.connect(_on_level.bind(lv))
		lv_row.add_child(b)
		level_buttons.append(b)

	var main_row := HBoxContainer.new()
	main_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_row.add_theme_constant_override("separation", 12)
	vb.add_child(main_row)
	menu_play_button = _make_button("Jouer", Vector2(200, 58), 22)
	menu_play_button.pressed.connect(start_game)
	main_row.add_child(menu_play_button)
	var endless := _make_button("Sans fin", Vector2(170, 58), 20)
	endless.pressed.connect(start_nonstop)
	main_row.add_child(endless)
	var duo_btn := _make_button("Duo", Vector2(150, 58), 20)
	duo_btn.pressed.connect(start_duo)
	main_row.add_child(duo_btn)
	var arena_btn := _make_button("Arène", Vector2(160, 58), 20)
	arena_btn.pressed.connect(start_arena)
	main_row.add_child(arena_btn)
	var toboggan_btn := _make_button("Toboggan", Vector2(180, 58), 20)
	toboggan_btn.pressed.connect(start_toboggan)
	main_row.add_child(toboggan_btn)
	var quake_btn := _make_button("Quake 2", Vector2(160, 58), 20)
	quake_btn.pressed.connect(start_quake2)
	main_row.add_child(quake_btn)

	var char_row := HBoxContainer.new()
	char_row.alignment = BoxContainer.ALIGNMENT_CENTER
	char_row.add_theme_constant_override("separation", 10)
	vb.add_child(char_row)
	char_buttons.clear()
	for i in range(CHAR_NAMES.size()):
		var b := _make_button(CHAR_NAMES[i], Vector2(190, 46), 18)
		b.pressed.connect(_on_char.bind(i))
		char_row.add_child(b)
		char_buttons.append(b)

	var hint := _make_label("Choisis ton personnage, puis joue 5 questions — ou tente l'Arène, le Toboggan ou Quake 2 !", 16, Color(0.62, 0.78, 0.94))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)

func _build_results(root: Control) -> void:
	results_root = Control.new()
	results_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(results_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.06, 0.11, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	results_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	results_root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _stylebox(Color(0.04, 0.13, 0.22, 0.95), 22, 2))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 46)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)
	var title := _make_label("Tour terminé !", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	final_label = _make_label("", 26)
	final_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(final_label)
	final_meta = _make_label("", 19, Color(0.7, 0.86, 1.0))
	final_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(final_meta)
	var b := _make_button("Revenir au menu", Vector2(280, 54), 20)
	results_button = b
	b.pressed.connect(_on_results_button)
	vb.add_child(b)


# ---------- jeu ----------

func _on_level(lv: String) -> void:
	niveau = lv
	_save()
	_update_hud()
	_play("click")

func _on_char(i: int) -> void:
	_show_char(i)
	_play("click")
	if playing and not current_q.is_empty():
		_speak(str(current_q.get("q", "")))

func _refresh_char_buttons() -> void:
	for i in range(char_buttons.size()):
		char_buttons[i].modulate = Color(1, 1, 1) if i == current_char else Color(0.72, 0.8, 0.9)

func _update_hud() -> void:
	if theme_label == null:
		return
	theme_label.text = "Thème : " + str(THEME_LABELS.get(theme, theme))
	level_label.text = "Niveau : " + niveau
	var extra := ""
	if duo:
		extra = "  ·  Joueur %d" % (duo_turn + 1)
	score_label.text = "Score : %d / %d%s" % [bon, total, extra]

func _show_menu() -> void:
	playing = false
	menu_root.visible = true
	play_root.visible = false
	results_root.visible = false
	_refresh_char_buttons()
	_update_hud()
	for c in chars:
		for ch in c.get_children():
			if ch is Label3D:
				ch.visible = false

func _show_game() -> void:
	menu_root.visible = false
	play_root.visible = true
	results_root.visible = false
	for c in chars:
		for ch in c.get_children():
			if ch is Label3D:
				ch.visible = true

func _gen_theme_order() -> void:
	theme_order = THEMES.duplicate()
	theme_order.shuffle()
	theme_pos = 0

func _next_theme() -> String:
	theme_pos = (theme_pos + 1) % theme_order.size()
	return str(theme_order[theme_pos])

func build_question() -> void:
	var tries := 0
	while true:
		var candidate: Dictionary = Gen.question(theme, niveau)
		current_q = candidate
		tries += 1
		if tries >= 8 or recent_qs.find(str(candidate.get("q", ""))) < 0:
			break
	recent_qs.append(str(current_q.get("q", "")))
	if recent_qs.size() > 14:
		recent_qs.pop_front()
	current_q["n"] = TURN_LEN

func _begin_turn(reset_order := true) -> void:
	if reset_order:
		_gen_theme_order()
		theme = str(theme_order[0]) if theme_order.size() > 0 else THEMES[0]
	else:
		theme = _next_theme()
	bon = 0
	total = 0
	recent_qs.clear()
	build_question()
	_show_game()
	_show_question()
	playing = true
	_update_hud()

func start_game() -> void:
	duo = false
	nonstop = false
	_begin_turn(true)
	_play("level")

func start_nonstop() -> void:
	duo = false
	nonstop = true
	theme = THEMES[0]
	bon = 0
	total = 0
	recent_qs.clear()
	build_question()
	_show_game()
	_show_question()
	playing = true
	_update_hud()
	_play("level")

func start_duo() -> void:
	duo = true
	nonstop = false
	duo_turn = 0
	duo_scores = [0, 0]
	_begin_turn(true)
	_play("level")


func start_arena() -> void:
	if action_mode != null or toboggan_mode != null or quake_mode != null:
		return
	print("ARENE — ", niveau, " · ", CHAR_NAMES[current_char])
	playing = false
	menu_root.visible = false
	play_root.visible = false
	results_root.visible = false
	ui.visible = false
	for p in world_props:
		p.visible = false
	for c in chars:
		c.visible = false
	action_mode = ActionScene.new()
	add_child(action_mode)
	action_mode.exited.connect(_close_arena)
	action_mode.setup(niveau, current_char, self)
	_play("level")

func start_quake2() -> void:
	if action_mode != null or toboggan_mode != null or quake_mode != null:
		return
	print("QUAKE2 — ", niveau, " · ", CHAR_NAMES[current_char])
	playing = false
	menu_root.visible = false
	play_root.visible = false
	results_root.visible = false
	ui.visible = false
	for p in world_props:
		p.visible = false
	for c in chars:
		c.visible = false
	quake_mode = Quake2Scene.new()
	add_child(quake_mode)
	quake_mode.exited.connect(_close_quake2)
	_play("level")


func _close_arena() -> void:
	if action_mode == null:
		return
	action_mode.queue_free()
	action_mode = null
	if main_cam != null:
		main_cam.current = true
	ui.visible = true
	for p in world_props:
		p.visible = true
	for c in chars:
		c.visible = false
	if current_char >= 0 and current_char < chars.size():
		chars[current_char].visible = true
	_show_menu()


func start_toboggan() -> void:
	if toboggan_mode != null or action_mode != null or quake_mode != null:
		return
	print("TOBOGGAN — ", niveau, " · ", CHAR_NAMES[current_char])
	playing = false
	menu_root.visible = false
	play_root.visible = false
	results_root.visible = false
	ui.visible = false
	for p in world_props:
		p.visible = false
	for c in chars:
		c.visible = false
	toboggan_mode = TobogganScene.new()
	add_child(toboggan_mode)
	toboggan_mode.exited.connect(_close_toboggan)
	toboggan_mode.setup(niveau, current_char, self)
	_play("level")


func _close_toboggan() -> void:
	if toboggan_mode == null:
		return
	toboggan_mode.queue_free()
	toboggan_mode = null
	if main_cam != null:
		main_cam.current = true
	ui.visible = true
	for p in world_props:
		p.visible = true
	for c in chars:
		c.visible = false
	if current_char >= 0 and current_char < chars.size():
		chars[current_char].visible = true
	_show_menu()

func _close_quake2() -> void:
	if quake_mode == null:
		return
	quake_mode.queue_free()
	quake_mode = null
	if main_cam != null:
		main_cam.current = true
	ui.visible = true
	for p in world_props:
		p.visible = true
	for c in chars:
		c.visible = false
	if current_char >= 0 and current_char < chars.size():
		chars[current_char].visible = true
	_show_menu()

func _show_question() -> void:
	if current_q.is_empty():
		build_question()
	q_label.text = str(current_q.get("q", ""))
	turn_label.text = "Question %d / %d" % [total + 1, TURN_LEN] if not nonstop else "Question %d" % [total + 1]
	var opts: Array = current_q.get("opts", [])
	for i in range(opt_buttons.size()):
		var b: Button = opt_buttons[i]
		if i < opts.size():
			b.visible = true
			b.text = str(opts[i])
			b.disabled = false
			b.modulate = Color(1, 1, 1)
			b.remove_theme_stylebox_override("disabled")
			b.remove_theme_color_override("font_disabled_color")
		else:
			b.visible = false
	result_label.visible = false
	expl_label.visible = false
	next_button.visible = false
	_update_hud()
	_speak(str(current_q.get("q", "")))

func answer(i: int) -> void:
	if not playing or current_q.is_empty():
		return
	var opts: Array = current_q.get("opts", [])
	if i < 0 or i >= opts.size():
		return
	var correct := i == int(current_q.get("ans", -1))
	if correct:
		bon += 1
		_play("ok")
	else:
		_play("no")
	total += 1
	for j in range(opt_buttons.size()):
		var b: Button = opt_buttons[j]
		b.disabled = true
		var bg := Color(0.07, 0.2, 0.32)
		var fg := Color(0.62, 0.72, 0.82)
		if j == int(current_q.get("ans", -1)):
			bg = Color(0.1, 0.45, 0.26)
			fg = Color(0.82, 1.0, 0.86)
		elif j == i:
			bg = Color(0.52, 0.14, 0.16)
			fg = Color(1.0, 0.82, 0.82)
		b.add_theme_stylebox_override("disabled", _stylebox(bg))
		b.add_theme_color_override("font_disabled_color", fg)
	result_label.text = "Bravo !" if correct else "Presque !"
	result_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7) if correct else Color(1.0, 0.75, 0.6))
	result_label.visible = true
	expl_label.text = str(current_q.get("expl", ""))
	expl_label.visible = true
	next_button.visible = true
	next_button.text = "Suivant"
	_update_hud()

func next_question() -> void:
	if not playing:
		return
	if nonstop:
		build_question()
		_show_question()
		return
	if total >= TURN_LEN:
		_end_turn()
	else:
		build_question()
		_show_question()

func _end_turn() -> void:
	playing = false
	_play("level")
	if duo:
		duo_scores[duo_turn] += bon
		_save()
	final_label.text = "%d bonne%s / %d question%s" % [bon, "s" if bon > 1 else "", TURN_LEN, "s" if TURN_LEN > 1 else ""]
	final_meta.text = "%s · %s · %s" % [str(THEME_LABELS.get(theme, theme)), niveau, CHAR_NAMES[current_char]]
	if duo:
		final_meta.text += "\nJoueur 1 : %d — Joueur 2 : %d" % [duo_scores[0], duo_scores[1]]
	play_root.visible = false
	results_root.visible = true
	if duo:
		results_action = "duo"
		results_button.text = "Joueur %d, à toi" % (2 - duo_turn)
	else:
		results_action = "menu"
		results_button.text = "Revenir au menu"

func _on_results_button() -> void:
	if results_action == "duo":
		duo_next()
	else:
		back_to_menu()

func duo_next() -> void:
	if not duo:
		return
	duo_turn = 1 - duo_turn
	results_root.visible = false
	_begin_turn(false)

func back_to_menu() -> void:
	playing = false
	results_root.visible = false
	_show_menu()


# ---------- tests / debug ----------

func debug_state() -> Dictionary:
	return {
		"playing": playing,
		"theme": theme,
		"niveau": niveau,
		"bon": bon,
		"total": total,
		"q": str(current_q.get("q", "")),
		"opts": current_q.get("opts", []),
		"ans": int(current_q.get("ans", -1)),
		"menu": menu_root.visible,
		"play": play_root.visible,
		"results": results_root.visible,
	}


# ---------- capture de contrôle (lancer avec -- --capture) ----------

func _maybe_capture() -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_shot("res://capture_menu.png")
	start_game()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_shot("res://capture_play.png")
	answer(0)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_shot("res://capture_answer.png")
	for i in range(4):
		next_question()
		await get_tree().process_frame
		answer(0)
		await get_tree().process_frame
	next_question()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_shot("res://capture_results.png")
	await get_tree().process_frame
	get_tree().quit()

func _shot(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("capture: ", path, " ", img.get_width(), "x", img.get_height())
