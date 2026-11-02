class_name BanquiseAction
extends Node3D

# Mode « Arène » : déplacement, FPS / 3ème personne, Arsenal CS Gun Game, cibles et monstres de neige.
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

const MAX_HEARTS := 3
const TURN_TIME := 25.0
const GOOD_PAUSE := 0.9
const BAD_PAUSE := 2.6
const PLAYER_SPEED := 8.5
const SPAWN_EVERY := 9.0
const MAX_HAZARDS := 4
const GRACE_TIME := 2.0

# Arsenal complet inspiré de Counter-Strike Gun Game (du plus basique au plus puissant)
var weapons := [
	{
		"name": "Arc Givré",
		"cd": 0.35,
		"pts": 10,
		"assist": 105.0,
		"hazard_assist": 75.0,
		"type": "bow",
		"desc": "Flèches rapides & silencieuses",
	},
	{
		"name": "Pistolet Polaire",
		"cd": 0.22,
		"pts": 14,
		"assist": 95.0,
		"hazard_assist": 68.0,
		"type": "pistol",
		"desc": "Semi-auto précis et vif",
	},
	{
		"name": "Fusil à Pompe Blizzard",
		"cd": 0.50,
		"pts": 20,
		"assist": 135.0,
		"hazard_assist": 115.0,
		"type": "shotgun",
		"desc": "Gerbe de 5 plombs de glace dévastateurs",
	},
	{
		"name": "Mitrailleuse Tempête",
		"cd": 0.09,
		"pts": 12,
		"assist": 88.0,
		"hazard_assist": 62.0,
		"type": "smg",
		"desc": "Cadence automatique ultra-rapide",
	},
	{
		"name": "Fusil Sniper Arctique",
		"cd": 0.85,
		"pts": 35,
		"assist": 175.0,
		"hazard_assist": 130.0,
		"type": "sniper",
		"desc": "Rayon perforant haute précision",
	},
	{
		"name": "Lance-Roquettes Cryo",
		"cd": 1.15,
		"pts": 50,
		"assist": 195.0,
		"hazard_assist": 160.0,
		"type": "bazooka",
		"desc": "Roquette explosive à dégâts de zone",
	},
]

var slots := [
	Vector3(-6.4, 1.25, -6.0),
	Vector3(-2.15, 1.25, -6.0),
	Vector3(2.15, 1.25, -6.0),
	Vector3(6.4, 1.25, -6.0),
]

# --- état de jeu ---
var niveau := "CE2"
var char_index := 0
var host: Node = null
var built := false
var save_path := "user://banquise_action.cfg"

var hearts := MAX_HEARTS
var score := 0
var best := 0
var streak := 0
var best_streak := 0
var weapon := 0
var gun_game_mode := true
var hazard_kills := 0
var game_over := false
var accepting := false
var resolving := false
var time_left := TURN_TIME
var resolve_timer := 0.0
var pending_over := 0.0
var cd_left := 0.0
var invuln := 0.0
var grace_left := 0.0
var hazard_timer := SPAWN_EVERY
var banner_timer := 0.0

var question: Dictionary = {}
var theme := "nombres"
var theme_bag: Array = []
var recent: Array = []
var hazards: Array = []

# --- FPS et caméra ---
var fps_mode := false
var view_pitch := 0.0
var view_yaw := 0.0
var recoil_pos := Vector3.ZERO
var recoil_rot := Vector3.ZERO
var shake_strength := 0.0

# --- noeuds ---
var player: CharacterBody3D
var visual: Node3D
var char_weapon_holder: Node3D
var camera: Camera3D
var fps_rig: Node3D
var fps_weapon_holder: Node3D
var marble: MeshInstance3D
var targets: Array = []
var target_mats: Array = []
var target_labels: Array = []
var target_nums: Array = []
var hazard_root: Node3D
var canvas: CanvasLayer
var ui_root: Control
var hud_left: Label
var hud_right: Label
var q_label: Label
var timer_bar: ProgressBar
var feedback: Label
var banner_label: Label
var hearts_label: Label
var weapon_label: Label
var input_field: LineEdit
var reticle: Label
var hitmarker: Label
var hitmarker_timer := 0.0
var btn_fps: Button
var flash_rect: ColorRect
var over_root: Control
var over_score: Label
var over_meta: Label
var t_accum := 0.0
var flash_alpha := 0.0
var muzzle_timer := 0.0


func setup(level: String, char_idx: int, host_node: Node) -> void:
	if built:
		return
	niveau = level if level in ["CP", "CE1", "CE2"] else "CE2"
	char_index = clampi(char_idx, 0, CHAR_NAMES.size() - 1)
	host = host_node
	_load_best()
	_build_arena()
	_build_player()
	_build_targets()
	_build_ui()
	_update_weapon_nodes()
	built = true
	hearts = MAX_HEARTS
	score = 0
	_restart()


# ---------- sauvegarde ----------

func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		best = int(cfg.get_value("arene", "best", 0))

func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("arene", "best", best)
	cfg.save(save_path)


# ---------- construction 3D ----------

func _build_arena() -> void:
	# eau autour de la banquise
	var water := MeshInstance3D.new()
	var wm := PlaneMesh.new()
	wm.size = Vector2(220, 220)
	water.mesh = wm
	var wmat := _mat(Color(0.07, 0.25, 0.42), 0.25)
	wmat.metallic = 0.45
	water.material_override = wmat
	water.position.y = -0.9
	add_child(water)

	# props physiques (blocs de glace) placés sur le pourtour, hors du champ de la caméra
	var cube_spots := [
		Vector3(-10.6, 0.45, -3.2),
		Vector3(10.6, 0.45, -3.2),
		Vector3(-9.4, 0.45, -9.0),
		Vector3(9.4, 0.45, -9.0),
		Vector3(-0.4, 0.45, -11.6),
	]
	for i in range(cube_spots.size()):
		var rb := RigidBody3D.new()
		rb.position = cube_spots[i]
		rb.linear_damp = 3.0
		rb.angular_damp = 3.0
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mesh.mesh.size = Vector3(0.8, 0.8, 0.8)
		mesh.material_override = _mat(Color(0.7, 0.9, 1.0), 0.3)
		rb.add_child(mesh)
		var c := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.8, 0.8, 0.8)
		c.shape = bs
		rb.add_child(c)
		add_child(rb)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 15.0
	shape.height = 1.0
	col.shape = shape
	col.position.y = -0.5
	floor_body.add_child(col)
	var floor_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 15.0
	cyl.bottom_radius = 16.5
	cyl.height = 1.0
	cyl.radial_segments = 24
	floor_mesh.mesh = cyl
	floor_mesh.material_override = _mat(Color(0.88, 0.96, 1.0), 0.55)
	floor_mesh.position.y = -0.5
	floor_body.add_child(floor_mesh)
	add_child(floor_body)

	# ourlet de neige
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 14.4
	torus.outer_radius = 15.6
	torus.rings = 32
	torus.ring_segments = 10
	rim.mesh = torus
	rim.material_override = _mat(Color(0.76, 0.9, 1.0), 0.7)
	rim.position.y = 0.1
	add_child(rim)

	# petits monticules de neige au fond
	for i in range(8):
		var a := PI + float(i) / 7.0 * PI
		var r := 12.6 + randf() * 2.0
		var mound := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.7 + randf() * 0.6
		hm.height = hm.radius * 1.1
		hm.radial_segments = 10
		hm.rings = 5
		mound.mesh = hm
		mound.material_override = _mat(Color(0.82, 0.94, 1.0), 0.7)
		mound.position = Vector3(cos(a) * r, hm.height * 0.25, sin(a) * r - 2.0)
		add_child(mound)

	# fanions au fond
	for x in [-9.0, -4.5, 0.0, 4.5, 9.0]:
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.05
		pm.bottom_radius = 0.05
		pm.height = 2.2
		pole.mesh = pm
		pole.material_override = _mat(Color(0.3, 0.36, 0.46), 0.5)
		pole.position = Vector3(x, 1.1, -11.5)
		add_child(pole)
		var flag := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.55, 0.35, 0.04)
		flag.mesh = fm
		flag.material_override = _mat(Color(1.0, 0.42, 0.5) if x < 0 else Color(0.35, 0.72, 1.0), 0.5)
		flag.position = Vector3(x + 0.3, 1.95, -11.5)
		add_child(flag)

	hazard_root = Node3D.new()
	hazard_root.name = "Bourrasques"
	add_child(hazard_root)

	camera = Camera3D.new()
	camera.fov = 45.0
	camera.far = 400.0
	camera.position = Vector3(0, 8.2, 14.0)
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0, 1.0, 0))

	# Rig FPS fixé sur la caméra pour afficher l'arme en vue 1ère personne
	fps_rig = Node3D.new()
	fps_rig.name = "FPS_Rig"
	fps_rig.position = Vector3(0.30, -0.30, -0.78)
	fps_rig.visible = false
	camera.add_child(fps_rig)

	fps_weapon_holder = Node3D.new()
	fps_weapon_holder.name = "FPS_Weapon"
	fps_rig.add_child(fps_weapon_holder)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.collision_layer = 1
	player.collision_mask = 1
	player.position = Vector3(0, 0, 3.5)
	add_child(player)

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.5
	col.shape = shape
	col.position.y = 0.75
	player.add_child(col)

	visual = Node3D.new()
	visual.name = "Perso"
	player.add_child(visual)

	# muzzle flash
	var mf := MeshInstance3D.new()
	mf.name = "MuzzleFlash"
	mf.mesh = SphereMesh.new()
	mf.mesh.radius = 0.18
	mf.material_override = _mat(Color(1, 0.9, 0.4), 0.2)
	mf.visible = false
	visual.add_child(mf)
	mf.position = Vector3(0, 1.2, 0.6)

	var body: Node3D = null
	if host != null and host.has_method("_make_char"):
		body = host._make_char(char_index)
	if body != null:
		body.scale = Vector3(0.95, 0.95, 0.95)
		visual.add_child(body)
		for ch in body.get_children():
			if ch is Label3D:
				ch.visible = false
	else:
		var torso := MeshInstance3D.new()
		torso.mesh = _capsule(0.42, 1.2)
		torso.material_override = _mat(Color(1.0, 0.62, 0.77), 0.65)
		torso.position.y = 0.95
		visual.add_child(torso)
		var head := MeshInstance3D.new()
		head.mesh = _sphere(0.34)
		head.material_override = _mat(Color(1.0, 0.86, 0.74), 0.65)
		head.position.y = 1.62
		visual.add_child(head)

	# Porte-arme 3ème personne visible sur le personnage
	char_weapon_holder = Node3D.new()
	char_weapon_holder.name = "CharWeaponHolder"
	char_weapon_holder.position = Vector3(0.34, 0.98, 0.38)
	visual.add_child(char_weapon_holder)

	# halo de visée au sol (mode 3ème personne)
	marble = MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.55
	mm.bottom_radius = 0.55
	mm.height = 0.02
	marble.mesh = mm
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color(0.4, 0.8, 1.0, 0.35)
	mmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marble.material_override = mmat
	marble.position = Vector3(0, 0.03, 0)
	player.add_child(marble)


# ---------- modèles 3D d'armes procéduraux ----------

func _build_weapon_mesh(idx: int, is_fps: bool) -> Node3D:
	var root := Node3D.new()
	var s: float = 0.35 if is_fps else 0.9
	root.scale = Vector3(s, s, s)
	if is_fps:
		root.rotation_degrees = Vector3(6, -16, -6)

	match idx:
		0: # Arc Givré (Bow)
			var bow := Node3D.new()
			var top_arm := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.025
			cyl.bottom_radius = 0.038
			cyl.height = 0.68
			top_arm.mesh = cyl
			top_arm.material_override = _mat(Color(0.25, 0.65, 0.95), 0.3)
			top_arm.rotation_degrees = Vector3(-35, 0, 0)
			top_arm.position = Vector3(0, 0.30, -0.15)
			bow.add_child(top_arm)

			var bot_arm := MeshInstance3D.new()
			bot_arm.mesh = cyl
			bot_arm.material_override = _mat(Color(0.25, 0.65, 0.95), 0.3)
			bot_arm.rotation_degrees = Vector3(35, 0, 0)
			bot_arm.position = Vector3(0, -0.30, -0.15)
			bow.add_child(bot_arm)

			var grip := MeshInstance3D.new()
			var gm := BoxMesh.new()
			gm.size = Vector3(0.08, 0.22, 0.1)
			grip.mesh = gm
			grip.material_override = _mat(Color(0.12, 0.28, 0.45), 0.6)
			bow.add_child(grip)

			var str_node := MeshInstance3D.new()
			var sm := CylinderMesh.new()
			sm.top_radius = 0.007
			sm.bottom_radius = 0.007
			sm.height = 1.08
			str_node.mesh = sm
			var str_mat := StandardMaterial3D.new()
			str_mat.albedo_color = Color(1.0, 1.0, 1.0)
			str_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			str_node.material_override = str_mat
			str_node.position = Vector3(0, 0, -0.32)
			bow.add_child(str_node)

			var arrow := Node3D.new()
			var shaft := MeshInstance3D.new()
			var shm := CylinderMesh.new()
			shm.top_radius = 0.014
			shm.bottom_radius = 0.014
			shm.height = 0.88
			shaft.mesh = shm
			shaft.rotation_degrees = Vector3(90, 0, 0)
			shaft.material_override = _mat(Color(0.85, 0.95, 1.0), 0.4)
			arrow.add_child(shaft)

			var tip := MeshInstance3D.new()
			var tm := CylinderMesh.new()
			tm.top_radius = 0.0
			tm.bottom_radius = 0.05
			tm.height = 0.18
			tip.mesh = tm
			var tmat := StandardMaterial3D.new()
			tmat.albedo_color = Color(0.4, 0.9, 1.0)
			tmat.emission_enabled = true
			tmat.emission = Color(0.5, 0.95, 1.0)
			tmat.emission_energy_multiplier = 2.0
			tip.material_override = tmat
			tip.rotation_degrees = Vector3(90, 0, 0)
			tip.position = Vector3(0, 0, 0.48)
			arrow.add_child(tip)
			bow.add_child(arrow)

			bow.rotation_degrees = Vector3(0, 90, 18) if is_fps else Vector3(0, 0, 15)
			root.add_child(bow)

		1: # Pistolet Polaire (Pistol)
			var gun := Node3D.new()
			var slide := MeshInstance3D.new()
			var slm := BoxMesh.new()
			slm.size = Vector3(0.12, 0.16, 0.52)
			slide.mesh = slm
			slide.material_override = _mat(Color(0.2, 0.45, 0.65), 0.3)
			slide.position = Vector3(0, 0.08, 0.1)
			gun.add_child(slide)

			var grip := MeshInstance3D.new()
			var gm := BoxMesh.new()
			gm.size = Vector3(0.1, 0.28, 0.15)
			grip.mesh = gm
			grip.material_override = _mat(Color(0.1, 0.18, 0.28), 0.7)
			grip.rotation_degrees = Vector3(-16, 0, 0)
			grip.position = Vector3(0, -0.12, -0.06)
			gun.add_child(grip)

			var b := MeshInstance3D.new()
			var bm := CylinderMesh.new()
			bm.top_radius = 0.04
			bm.bottom_radius = 0.04
			bm.height = 0.22
			b.mesh = bm
			b.rotation_degrees = Vector3(90, 0, 0)
			b.material_override = _mat(Color(0.1, 0.1, 0.15), 0.2)
			b.position = Vector3(0, 0.08, 0.38)
			gun.add_child(b)

			var laser := MeshInstance3D.new()
			laser.mesh = _sphere(0.02)
			var lmat := StandardMaterial3D.new()
			lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			lmat.albedo_color = Color(0.2, 1.0, 0.9)
			laser.material_override = lmat
			laser.position = Vector3(0, 0.18, 0.32)
			gun.add_child(laser)
			root.add_child(gun)

		2: # Fusil à Pompe Blizzard (Shotgun)
			var sg := Node3D.new()
			for side in [-0.055, 0.055]:
				var barrel := MeshInstance3D.new()
				var bm := CylinderMesh.new()
				bm.top_radius = 0.045
				bm.bottom_radius = 0.045
				bm.height = 0.82
				barrel.mesh = bm
				barrel.rotation_degrees = Vector3(90, 0, 0)
				barrel.material_override = _mat(Color(0.15, 0.28, 0.4), 0.3)
				barrel.position = Vector3(side, 0.06, 0.35)
				sg.add_child(barrel)

			var body := MeshInstance3D.new()
			var bdm := BoxMesh.new()
			bdm.size = Vector3(0.19, 0.22, 0.48)
			body.mesh = bdm
			body.material_override = _mat(Color(0.1, 0.2, 0.3), 0.4)
			body.position = Vector3(0, 0.02, -0.1)
			sg.add_child(body)

			var pump := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.21, 0.14, 0.28)
			pump.mesh = pm
			pump.material_override = _mat(Color(0.35, 0.72, 0.95), 0.5)
			pump.position = Vector3(0, -0.05, 0.28)
			sg.add_child(pump)

			var stock := MeshInstance3D.new()
			var stm := BoxMesh.new()
			stm.size = Vector3(0.13, 0.24, 0.44)
			stock.mesh = stm
			stock.material_override = _mat(Color(0.12, 0.22, 0.32), 0.6)
			stock.position = Vector3(0, -0.09, -0.42)
			sg.add_child(stock)
			root.add_child(sg)

		3: # Mitrailleuse Tempête (SMG)
			var smg := Node3D.new()
			var body := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.15, 0.22, 0.62)
			body.mesh = bm
			body.material_override = _mat(Color(0.16, 0.22, 0.32), 0.4)
			smg.add_child(body)

			var b := MeshInstance3D.new()
			var bm2 := CylinderMesh.new()
			bm2.top_radius = 0.05
			bm2.bottom_radius = 0.05
			bm2.height = 0.42
			b.mesh = bm2
			b.rotation_degrees = Vector3(90, 0, 0)
			b.material_override = _mat(Color(0.25, 0.35, 0.5), 0.3)
			b.position = Vector3(0, 0.02, 0.46)
			smg.add_child(b)

			var mag := MeshInstance3D.new()
			var mm := BoxMesh.new()
			mm.size = Vector3(0.09, 0.36, 0.16)
			mag.mesh = mm
			mag.material_override = _mat(Color(0.08, 0.12, 0.18), 0.5)
			mag.rotation_degrees = Vector3(15, 0, 0)
			mag.position = Vector3(0, -0.22, 0.08)
			smg.add_child(mag)

			var sight := MeshInstance3D.new()
			var sim := BoxMesh.new()
			sim.size = Vector3(0.08, 0.1, 0.15)
			sight.mesh = sim
			sight.material_override = _mat(Color(0.1, 0.15, 0.25), 0.4)
			sight.position = Vector3(0, 0.16, 0.0)
			smg.add_child(sight)
			root.add_child(smg)

		4: # Fusil Sniper Arctique (Sniper)
			var snip := Node3D.new()
			var body := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.14, 0.18, 0.88)
			body.mesh = bm
			body.material_override = _mat(Color(0.2, 0.3, 0.45), 0.35)
			snip.add_child(body)

			var b := MeshInstance3D.new()
			var bm2 := CylinderMesh.new()
			bm2.top_radius = 0.035
			bm2.bottom_radius = 0.045
			bm2.height = 1.02
			b.mesh = bm2
			b.rotation_degrees = Vector3(90, 0, 0)
			b.material_override = _mat(Color(0.12, 0.18, 0.26), 0.2)
			b.position = Vector3(0, 0.02, 0.88)
			snip.add_child(b)

			var mb := MeshInstance3D.new()
			var mbm := BoxMesh.new()
			mbm.size = Vector3(0.09, 0.09, 0.16)
			mb.mesh = mbm
			mb.material_override = _mat(Color(0.1, 0.1, 0.15), 0.3)
			mb.position = Vector3(0, 0.02, 1.42)
			snip.add_child(mb)

			var scope := MeshInstance3D.new()
			var scm := CylinderMesh.new()
			scm.top_radius = 0.065
			scm.bottom_radius = 0.065
			scm.height = 0.54
			scope.mesh = scm
			scope.rotation_degrees = Vector3(90, 0, 0)
			scope.material_override = _mat(Color(0.15, 0.22, 0.32), 0.2)
			scope.position = Vector3(0, 0.18, 0.05)
			snip.add_child(scope)

			var lens := MeshInstance3D.new()
			lens.mesh = _sphere(0.06)
			var lmat := StandardMaterial3D.new()
			lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			lmat.albedo_color = Color(0.2, 0.9, 1.0)
			lens.material_override = lmat
			lens.position = Vector3(0, 0.18, 0.32)
			snip.add_child(lens)
			root.add_child(snip)

		5: # Lance-Roquettes Cryo (Bazooka)
			var bzk := Node3D.new()
			var tube := MeshInstance3D.new()
			var tm := CylinderMesh.new()
			tm.top_radius = 0.16
			tm.bottom_radius = 0.16
			tm.height = 1.25
			tube.mesh = tm
			tube.rotation_degrees = Vector3(90, 0, 0)
			tube.material_override = _mat(Color(0.18, 0.32, 0.48), 0.35)
			bzk.add_child(tube)

			var ring := MeshInstance3D.new()
			var rm := CylinderMesh.new()
			rm.top_radius = 0.18
			rm.bottom_radius = 0.18
			rm.height = 0.12
			ring.mesh = rm
			ring.rotation_degrees = Vector3(90, 0, 0)
			ring.material_override = _mat(Color(0.9, 0.65, 0.2), 0.4)
			ring.position = Vector3(0, 0, 0.58)
			bzk.add_child(ring)

			var warhead := MeshInstance3D.new()
			var wm := CylinderMesh.new()
			wm.top_radius = 0.0
			wm.bottom_radius = 0.14
			wm.height = 0.32
			warhead.mesh = wm
			warhead.rotation_degrees = Vector3(90, 0, 0)
			var wmat := StandardMaterial3D.new()
			wmat.albedo_color = Color(0.4, 0.85, 1.0)
			wmat.emission_enabled = true
			wmat.emission = Color(0.3, 0.8, 1.0)
			wmat.emission_energy_multiplier = 1.5
			warhead.material_override = wmat
			warhead.position = Vector3(0, 0, 0.72)
			bzk.add_child(warhead)

			var grip := MeshInstance3D.new()
			var gm := BoxMesh.new()
			gm.size = Vector3(0.08, 0.26, 0.12)
			grip.mesh = gm
			grip.material_override = _mat(Color(0.1, 0.15, 0.2), 0.6)
			grip.position = Vector3(0, -0.22, 0.1)
			bzk.add_child(grip)
			root.add_child(bzk)

	return root


func _update_weapon_nodes() -> void:
	if char_weapon_holder != null:
		for ch in char_weapon_holder.get_children():
			ch.queue_free()
		var mesh3p := _build_weapon_mesh(weapon, false)
		char_weapon_holder.add_child(mesh3p)

	if fps_weapon_holder != null:
		for ch in fps_weapon_holder.get_children():
			ch.queue_free()
		var mesh1p := _build_weapon_mesh(weapon, true)
		fps_weapon_holder.add_child(mesh1p)


func _advance_gun() -> void:
	if weapon < weapons.size() - 1:
		weapon += 1
		_show_banner("★ ARME AMÉLIORÉE (GUN GAME) ! %s ★" % str(weapons[weapon].get("name", "")))
		_play("level")
		_update_weapon_nodes()
		_update_hud()


func _toggle_fps() -> void:
	fps_mode = not fps_mode
	if fps_mode:
		camera.fov = 75.0
		visual.visible = false
		fps_rig.visible = true
		marble.visible = false
		btn_fps.text = "Vue : FPS (1ère pers.) [V]"
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		feedback.text = "Mode FPS activé ! Viseur centré, ZQSD pour bouger."
	else:
		camera.fov = 45.0
		visual.visible = true
		fps_rig.visible = false
		marble.visible = true
		btn_fps.text = "Vue : 3ème personne [V]"
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		feedback.text = "Mode 3ème personne réactivé."
	feedback.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))


func _show_banner(txt: String) -> void:
	if banner_label != null:
		banner_label.text = txt
		banner_label.visible = true
		banner_timer = 2.4


func _show_hitmarker() -> void:
	if hitmarker != null:
		hitmarker.visible = true
		hitmarker.modulate = Color(1.0, 0.35, 0.35, 1.0)
		hitmarker_timer = 0.15


func _build_targets() -> void:
	for i in range(4):
		var root := Node3D.new()
		root.name = "Cible%d" % (i + 1)
		root.position = slots[i]
		add_child(root)

		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.3, 2.2, 0.45)
		body.mesh = bm
		var mat := _mat(Color(0.13, 0.42, 0.62), 0.5)
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.55, 0.8)
		mat.emission_energy_multiplier = 0.0
		body.material_override = mat
		root.add_child(body)

		var frame := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(3.55, 2.45, 0.3)
		frame.mesh = fm
		frame.material_override = _mat(Color(0.85, 0.95, 1.0), 0.55)
		frame.position.z = -0.12
		root.add_child(frame)

		var lab := Label3D.new()
		lab.text = ""
		lab.font_size = 60
		lab.pixel_size = 0.011
		lab.width = 280.0
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.outline_size = 14
		lab.outline_modulate = Color(0.02, 0.1, 0.18, 0.95)
		lab.modulate = Color(0.97, 0.99, 1.0)
		lab.position = Vector3(0, -0.06, 0.27)
		root.add_child(lab)

		var num := Label3D.new()
		num.text = str(i + 1)
		num.font_size = 40
		num.pixel_size = 0.008
		num.width = 60.0
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.outline_size = 10
		num.outline_modulate = Color(0.02, 0.1, 0.18, 0.95)
		num.modulate = Color(0.7, 0.9, 1.0)
		num.position = Vector3(-1.35, 0.94, 0.28)
		root.add_child(num)

		targets.append(root)
		target_mats.append(mat)
		target_labels.append(lab)
		target_nums.append(num)


# ---------- interface ----------

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


func _build_ui() -> void:
	canvas = CanvasLayer.new()
	canvas.layer = 4
	add_child(canvas)

	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui_root)

	hud_left = _make_label("", 20)
	hud_left.position = Vector2(26, 16)
	hud_left.size = Vector2(620, 30)
	ui_root.add_child(hud_left)

	hud_right = _make_label("", 19, Color(0.72, 0.88, 1.0))
	hud_right.anchor_left = 1.0
	hud_right.anchor_right = 1.0
	hud_right.offset_left = -540
	hud_right.offset_right = -26
	hud_right.offset_top = 16
	hud_right.offset_bottom = 46
	hud_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui_root.add_child(hud_right)

	# Bouton bascule FPS / 3ème personne dans le coin haut droit
	btn_fps = _make_button("Vue : 3ème personne [V]", Vector2(210, 34), 14)
	btn_fps.anchor_left = 1.0
	btn_fps.anchor_right = 1.0
	btn_fps.offset_left = -236
	btn_fps.offset_right = -26
	btn_fps.offset_top = 50
	btn_fps.offset_bottom = 84
	btn_fps.pressed.connect(_toggle_fps)
	ui_root.add_child(btn_fps)

	# Bannière centrale de Level Up / Gun Game
	banner_label = _make_label("", 28, Color(1.0, 0.9, 0.4))
	banner_label.anchor_left = 0.5
	banner_label.anchor_right = 0.5
	banner_label.offset_left = -400
	banner_label.offset_right = 400
	banner_label.offset_top = 18
	banner_label.offset_bottom = 54
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.visible = false
	ui_root.add_child(banner_label)

	var qpanel := PanelContainer.new()
	qpanel.anchor_right = 1.0
	qpanel.offset_left = 130
	qpanel.offset_right = -250
	qpanel.offset_top = 58
	qpanel.offset_bottom = 164
	qpanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qpanel.add_theme_stylebox_override("panel", _stylebox(Color(0.03, 0.11, 0.19, 0.9), 16, 1))
	ui_root.add_child(qpanel)
	var qmargin := MarginContainer.new()
	for side in ["left", "right"]:
		qmargin.add_theme_constant_override("margin_" + side, 18)
	for side in ["top", "bottom"]:
		qmargin.add_theme_constant_override("margin_" + side, 8)
	qpanel.add_child(qmargin)
	q_label = _make_label("", 26)
	q_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qmargin.add_child(q_label)

	timer_bar = ProgressBar.new()
	timer_bar.anchor_left = 0.5
	timer_bar.anchor_right = 0.5
	timer_bar.offset_left = -380
	timer_bar.offset_right = 380
	timer_bar.offset_top = 170
	timer_bar.offset_bottom = 188
	timer_bar.max_value = 100.0
	timer_bar.value = 100.0
	timer_bar.show_percentage = false
	timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := _stylebox(Color(0.05, 0.14, 0.22, 0.9), 9)
	var fill := _stylebox(Color(0.36, 0.82, 0.62), 9)
	timer_bar.add_theme_stylebox_override("background", bg)
	timer_bar.add_theme_stylebox_override("fill", fill)
	ui_root.add_child(timer_bar)

	feedback = _make_label("", 24, Color(0.8, 1.0, 0.85))
	feedback.anchor_right = 1.0
	feedback.offset_left = 60
	feedback.offset_right = -60
	feedback.offset_top = 316
	feedback.offset_bottom = 406
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
	bottom.offset_top = -124
	bottom.offset_bottom = -12
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_stylebox_override("panel", _stylebox(Color(0.03, 0.11, 0.19, 0.92), 16, 1))
	ui_root.add_child(bottom)
	var bmargin := MarginContainer.new()
	bmargin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		bmargin.add_theme_constant_override("margin_" + side, 16)
	for side in ["top", "bottom"]:
		bmargin.add_theme_constant_override("margin_" + side, 8)
	bottom.add_child(bmargin)
	var bvb := VBoxContainer.new()
	bvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bvb.add_theme_constant_override("separation", 4)
	bmargin.add_child(bvb)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	bvb.add_child(row)
	hearts_label = _make_label("", 26, Color(1.0, 0.45, 0.55))
	hearts_label.custom_minimum_size = Vector2(130, 0)
	hearts_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(hearts_label)

	input_field = LineEdit.new()
	input_field.placeholder_text = "Écris la réponse, puis Entrée = tir direct !"
	input_field.custom_minimum_size = Vector2(460, 46)
	input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_field.add_theme_font_size_override("font_size", 21)
	input_field.add_theme_color_override("font_color", Color(0.95, 0.99, 1.0))
	input_field.add_theme_color_override("font_placeholder_color", Color(0.55, 0.72, 0.88))
	input_field.add_theme_stylebox_override("normal", _stylebox(Color(0.06, 0.18, 0.28), 12, 1))
	input_field.add_theme_stylebox_override("focus", _stylebox(Color(0.08, 0.24, 0.36), 12, 2))
	input_field.text_submitted.connect(_on_text_submitted)
	row.add_child(input_field)

	weapon_label = _make_label("", 17, Color(0.72, 0.88, 1.0))
	weapon_label.custom_minimum_size = Vector2(280, 0)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(weapon_label)

	var hint := _make_label(
		"ZQSD : bouger   ·   Clic/Espace : tirer   ·   V : Vue FPS / 3D   ·   1 à 6 ou Molette : arme   ·   T ou Tab : écrire",
		15,
		Color(0.62, 0.8, 0.95)
	)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bvb.add_child(hint)

	reticle = _make_label("+", 32, Color(0.75, 0.95, 1.0, 0.9))
	reticle.size = Vector2(32, 32)
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(reticle)

	hitmarker = _make_label("×", 38, Color(1.0, 0.35, 0.35, 1.0))
	hitmarker.size = Vector2(38, 38)
	hitmarker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hitmarker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hitmarker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hitmarker.visible = false
	ui_root.add_child(hitmarker)

	flash_rect = ColorRect.new()
	flash_rect.color = Color(1.0, 0.3, 0.35, 0.0)
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
	dim.color = Color(0.01, 0.05, 0.09, 0.74)
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

	var title := _make_label("Partie terminée", 36, Color(0.92, 0.98, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	over_score = _make_label("", 26)
	over_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(over_score)
	over_meta = _make_label("", 19, Color(0.7, 0.87, 1.0))
	over_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	over_meta.custom_minimum_size = Vector2(460, 0)
	vb.add_child(over_meta)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	var retry := _make_button("Rejouer", Vector2(200, 52), 21)
	retry.pressed.connect(_restart)
	row.add_child(retry)
	var menu := _make_button("Menu", Vector2(170, 52), 21)
	menu.pressed.connect(exit_arena)
	row.add_child(menu)


# ---------- boucle de jeu ----------

func _restart() -> void:
	game_over = false
	pending_over = 0.0
	resolve_timer = 0.0
	over_root.visible = false
	hearts = MAX_HEARTS
	score = 0
	streak = 0
	best_streak = 0
	weapon = 0
	hazard_kills = 0
	invuln = 0.0
	grace_left = GRACE_TIME
	cd_left = 0.0
	hazard_timer = SPAWN_EVERY
	time_left = TURN_TIME
	_clear_hazards()
	recent.clear()
	theme_bag.clear()
	input_field.text = ""
	input_field.release_focus()
	player.position = Vector3(0, 0, 3.5)
	view_pitch = 0.0
	view_yaw = 0.0
	_update_weapon_nodes()
	_new_question()


func _new_question() -> void:
	if game_over or pending_over > 0.0:
		return
	resolving = false
	accepting = true
	time_left = TURN_TIME
	resolve_timer = 0.0
	theme = _pick_theme()
	var tries := 0
	while true:
		question = Gen.question(theme, niveau)
		tries += 1
		if tries >= 8 or recent.find(str(question.get("q", ""))) < 0:
			break
	recent.append(str(question.get("q", "")))
	if recent.size() > 14:
		recent.pop_front()
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
	hud_right.text = "%s · %s · %s" % [
		CHAR_NAMES[char_index],
		niveau,
		str(THEME_LABELS.get(theme, theme)),
	]
	var opts: Array = question.get("opts", [])
	_layout_targets(opts.size())
	for i in range(targets.size()):
		var t: Node3D = targets[i]
		if i < opts.size():
			var txt := str(opts[i])
			t.visible = true
			target_labels[i].text = txt
			var longest := 1
			for word in txt.split(" ", false):
				longest = maxi(longest, word.length())
			var size := clampi(int(520.0 / float(longest)), 36, 60)
			target_labels[i].font_size = size
			target_mats[i].emission_energy_multiplier = 0.0
			t.scale = Vector3.ONE
		else:
			t.visible = false
	input_field.text = ""
	input_field.release_focus()
	feedback.text = ""
	_update_hud()


func _layout_targets(count: int) -> void:
	var xs: Array = []
	match count:
		1:
			xs = [0.0]
		2:
			xs = [-3.2, 3.2]
		3:
			xs = [-5.2, 0.0, 5.2]
		_:
			xs = [-6.4, -2.15, 2.15, 6.4]
	for i in range(mini(count, targets.size())):
		targets[i].position = Vector3(float(xs[i]), 1.25, -6.0)


func _update_hud() -> void:
	if hud_left == null:
		return
	var hearts_txt := ""
	for i in range(MAX_HEARTS):
		hearts_txt += "❤" if i < hearts else "♡"
	hud_left.text = "Score %d   ·   Série x%d   ·   Meilleur %d" % [score, streak, best]
	hearts_label.text = hearts_txt
	var w: Dictionary = weapons[weapon]
	weapon_label.text = "[Arme %d/6] %s\n%s" % [
		weapon + 1,
		str(w.get("name", "")),
		str(w.get("desc", ""))
	]


func _set_weapon(i: int) -> void:
	if i < 0 or i >= weapons.size():
		return
	weapon = i
	cd_left = 0.0
	_play("click")
	_update_weapon_nodes()
	_update_hud()
	feedback.text = "%s sélectionnée (%s)" % [
		str(weapons[weapon].get("name", "")),
		str(weapons[weapon].get("desc", ""))
	]
	feedback.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))


func _aim_point() -> Vector3:
	if fps_mode:
		var from := camera.global_position
		var dir := -camera.global_transform.basis.z
		return from + dir * 18.0
	else:
		var mouse := get_viewport().get_mouse_position()
		var from := camera.project_ray_origin(mouse)
		var dir := camera.project_ray_normal(mouse)
		if absf(dir.y) < 0.0001:
			return player.global_position + Vector3(0, 1.3, -6)
		var t := (1.3 - from.y) / dir.y
		if t < 0.0:
			t = 6.0
		return from + dir * t


func _physics_process(_delta: float) -> void:
	if not built or player == null or game_over:
		return
	if input_field != null and input_field.has_focus():
		player.velocity = Vector3.ZERO
		return

	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_UP):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0

	var speed := PLAYER_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= 1.55

	if move.length() > 1.0:
		move = move.normalized()

	if fps_mode:
		# Déplacement relatif à l'orientation de la caméra FPS
		var forward := Vector3(-sin(view_yaw), 0, -cos(view_yaw))
		var right := Vector3(cos(view_yaw), 0, -sin(view_yaw))
		var world_move := (forward * (-move.y) + right * move.x) * speed
		player.velocity = world_move
	else:
		player.velocity = Vector3(move.x, 0, move.y) * speed

	player.move_and_slide()
	player.position.x = clampf(player.position.x, -7.0, 7.0)
	player.position.z = clampf(player.position.z, -1.0, 6.0)
	player.position.y = 0.0


func _process(delta: float) -> void:
	if not built:
		return
	t_accum += delta

	# Amortissement du recul et du screenshake
	recoil_pos = recoil_pos.lerp(Vector3.ZERO, 1.0 - exp(-16.0 * delta))
	recoil_rot = recoil_rot.lerp(Vector3.ZERO, 1.0 - exp(-16.0 * delta))
	shake_strength = maxf(0.0, shake_strength - delta * 5.0)
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake_strength

	# Gestion de la caméra (FPS ou 3ème personne)
	if fps_mode:
		camera.global_position = player.global_position + Vector3(0, 1.55, 0) + shake
		camera.rotation = Vector3(view_pitch, view_yaw, 0)
		player.rotation.y = view_yaw

		# Sway et animation d'inertie de l'arme en 1ère personne
		var move_speed := player.velocity.length()
		var sway_x := sin(t_accum * 5.0) * 0.015 * (move_speed / PLAYER_SPEED)
		var sway_y := absf(cos(t_accum * 10.0)) * 0.018 * (move_speed / PLAYER_SPEED)
		fps_rig.position = Vector3(0.30, -0.30, -0.78) + recoil_pos + Vector3(sway_x, sway_y, 0)
		fps_rig.rotation = recoil_rot

		# En FPS, le viseur est fixé au centre
		var center := get_viewport().get_visible_rect().size * 0.5
		reticle.global_position = center - reticle.size * 0.5
		hitmarker.global_position = center - hitmarker.size * 0.5
	else:
		var desired := player.global_position + Vector3(0, 8.2, 10.4) + shake
		var k := 1.0 - exp(-6.5 * delta)
		camera.global_position = camera.global_position.lerp(desired, k)
		camera.look_at(player.global_position + Vector3(0, 1.0, -4.6))

		# Le personnage regarde le curseur
		var aim := _aim_point()
		var look := aim - player.global_position
		if Vector2(look.x, look.z).length() > 0.15:
			var want := atan2(look.x, look.z)
			visual.rotation.y = lerp_angle(visual.rotation.y, want, 1.0 - exp(-14.0 * delta))

		marble.global_position = Vector3(aim.x, 0.03, aim.z)
		var mpos := get_viewport().get_mouse_position()
		reticle.global_position = mpos - reticle.size * 0.5
		hitmarker.global_position = mpos - hitmarker.size * 0.5

	# Timer hitmarker
	if hitmarker_timer > 0.0:
		hitmarker_timer -= delta
		if hitmarker_timer <= 0.0:
			hitmarker.visible = false

	# Timer bannière Level Up
	if banner_timer > 0.0:
		banner_timer -= delta
		if banner_timer <= 0.0:
			banner_label.visible = false

	if not game_over:
		if cd_left > 0.0:
			cd_left = maxf(0.0, cd_left - delta)
		if invuln > 0.0:
			invuln = maxf(0.0, invuln - delta)
			marble.visible = (not fps_mode) and (fmod(invuln, 0.2) > 0.1)
		else:
			marble.visible = not fps_mode

		if accepting:
			time_left = maxf(0.0, time_left - delta)
			timer_bar.value = time_left / TURN_TIME * 100.0
			var ratio := time_left / TURN_TIME
			var col := Color(0.36, 0.82, 0.62)
			if ratio < 0.35:
				col = Color(0.95, 0.42, 0.38)
			elif ratio < 0.65:
				col = Color(1.0, 0.78, 0.34)
			timer_bar.add_theme_stylebox_override("fill", _stylebox(col, 9))
			if time_left <= 0.0:
				_timeout()

		if not accepting and resolve_timer > 0.0:
			resolve_timer = maxf(0.0, resolve_timer - delta)
			if resolve_timer <= 0.0 and pending_over <= 0.0:
				_new_question()

		if pending_over > 0.0:
			pending_over = maxf(0.0, pending_over - delta)
			if pending_over <= 0.0:
				_show_game_over()

		if accepting:
			hazard_timer -= delta
			grace_left = maxf(0.0, grace_left - delta)
			if hazard_timer <= 0.0:
				hazard_timer = SPAWN_EVERY + randf() * 2.5
				if hazards.size() < MAX_HAZARDS:
					_spawn_hazard()

	# Bourrasques (monstres de neige qui suivent le joueur)
	for h in hazards.duplicate():
		if not is_instance_valid(h):
			continue
		var to: Vector3 = player.global_position - h.global_position
		to.y = 0.0
		var d: float = to.length()
		if d > 0.05:
			var dirv: Vector3 = to / d
			h.global_position += dirv * float(h.get_meta("speed", 3.2)) * delta
		h.rotation.y += delta * 2.5
		h.position.y = 0.95 + sin(t_accum * 3.5 + float(h.get_meta("phase", 0.0))) * 0.22
		if d < 1.15 and grace_left <= 0.0:
			_pop_hazard(h, false)
			_hurt()

	# Survol des cibles
	var aim_s := (get_viewport().get_visible_rect().size * 0.5) if fps_mode else get_viewport().get_mouse_position()
	var hover := _pick_target(aim_s)
	for i in range(targets.size()):
		if not is_instance_valid(targets[i]):
			continue
		var on := i == hover
		target_mats[i].emission_energy_multiplier = 0.9 if on else 0.0
		target_mats[i].albedo_color = Color(0.2, 0.58, 0.82) if on else Color(0.13, 0.42, 0.62)
		target_nums[i].modulate = Color(1.0, 0.95, 0.6) if on else Color(0.7, 0.9, 1.0)

	# Flash de dégât
	if flash_alpha > 0.0:
		flash_alpha = maxf(0.0, flash_alpha - delta * 2.2)
	muzzle_timer = maxf(0.0, muzzle_timer - delta)
	if visual != null and visual.has_node("MuzzleFlash"):
		visual.get_node("MuzzleFlash").visible = muzzle_timer > 0.0
		flash_rect.color = Color(1.0, 0.32, 0.36, flash_alpha)


# ---------- entrées ----------

func _unhandled_input(event: InputEvent) -> void:
	if not built or game_over:
		return

	# Orientation FPS par mouvement de souris
	if fps_mode and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		view_yaw -= event.relative.x * 0.0032
		view_pitch = clampf(view_pitch - event.relative.y * 0.0032, -1.15, 1.15)
		return

	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if fps_mode and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not input_field.has_focus():
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_try_fire()
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_weapon((weapon - 1 + weapons.size()) % weapons.size())
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_weapon((weapon + 1) % weapons.size())
			get_viewport().set_input_as_handled()
		return

	if not (event is InputEventKey):
		return
	if not event.pressed or event.echo:
		return

	var code: int = event.keycode
	var phys: int = event.physical_keycode

	if code == KEY_ESCAPE:
		if fps_mode and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			exit_arena()
		get_viewport().set_input_as_handled()
	elif code == KEY_V or phys == KEY_V:
		_toggle_fps()
		get_viewport().set_input_as_handled()
	elif code == KEY_SPACE or phys == KEY_SPACE:
		_try_fire()
		get_viewport().set_input_as_handled()
	elif code == KEY_1 or phys == KEY_1 or code == KEY_KP_1:
		_set_weapon(0)
	elif code == KEY_2 or phys == KEY_2 or code == KEY_KP_2:
		_set_weapon(1)
	elif code == KEY_3 or phys == KEY_3 or code == KEY_KP_3:
		_set_weapon(2)
	elif code == KEY_4 or phys == KEY_4 or code == KEY_KP_4:
		_set_weapon(3)
	elif code == KEY_5 or phys == KEY_5 or code == KEY_KP_5:
		_set_weapon(4)
	elif code == KEY_6 or phys == KEY_6 or code == KEY_KP_6:
		_set_weapon(5)
	elif code == KEY_T or phys == KEY_T or code == KEY_TAB or phys == KEY_TAB:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		input_field.grab_focus()
		get_viewport().set_input_as_handled()


func _try_fire() -> void:
	if not accepting or game_over or cd_left > 0.0:
		return
	if input_field.has_focus():
		return

	var w: Dictionary = weapons[weapon]
	var wtype: String = str(w.get("type", "pistol"))
	cd_left = float(w.get("cd", 0.3))
	muzzle_timer = 0.05

	# Recul d'arme dynamique
	recoil_pos = Vector3(0.02, 0.035, 0.14)
	recoil_rot = Vector3(0.20, 0.05, -0.04)

	var aim_s := (get_viewport().get_visible_rect().size * 0.5) if fps_mode else get_viewport().get_mouse_position()

	# Détection prioritaire sur les monstres de neige qui approchent
	var hi := _pick_hazard(aim_s)
	var ti := _pick_target(aim_s)

	if hi >= 0:
		var h = hazards[hi]
		if is_instance_valid(h):
			_fire_shot_effect(h.global_position, wtype)
			_pop_hazard(h, true)
			score += 3
			hazard_kills += 1
			_show_hitmarker()
			_update_hud()
			_play("boom")
			if gun_game_mode and hazard_kills >= 2:
				hazard_kills = 0
				_advance_gun()
			return

	if ti >= 0:
		_fire_shot_effect(targets[ti].global_position, wtype)
		_play("shot" + str(weapon))
		_show_hitmarker()
		_resolve(ti, false)
		return

	# Tir dans le vide ou tir de zone (Fusil à pompe / Lance-roquettes)
	var aim3d := _aim_point()
	_fire_shot_effect(aim3d, wtype)

	# Si c'est un lance-roquettes, explosion de zone qui nettoie les monstres alentour !
	if wtype == "bazooka":
		shake_strength = 0.35
		_play("boom")
		for h in hazards.duplicate():
			if is_instance_valid(h) and h.global_position.distance_to(aim3d) < 5.8:
				_pop_hazard(h, true)
				score += 3
				_show_hitmarker()
	elif wtype == "shotgun":
		shake_strength = 0.15
		_play("shot" + str(weapon))
		for h in hazards.duplicate():
			if is_instance_valid(h) and h.global_position.distance_to(aim3d) < 3.8:
				_pop_hazard(h, true)
				score += 3
				_show_hitmarker()
	elif wtype == "sniper":
		shake_strength = 0.22
		_play("shot" + str(weapon))
	else:
		_play("shot" + str(weapon))


func _pick_target(screen_pos: Vector2) -> int:
	if camera == null:
		return -1
	var best_idx := -1
	var best_d := float(weapons[weapon].get("assist", 80.0))
	for i in range(targets.size()):
		var t: Node3D = targets[i]
		if not is_instance_valid(t) or not t.visible:
			continue
		var wp := t.global_position
		if camera.is_position_behind(wp):
			continue
		var sp := camera.unproject_position(wp)
		var d := sp.distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best_idx = i
	return best_idx


func _pick_hazard(screen_pos: Vector2) -> int:
	var best_idx := -1
	var best_d := float(weapons[weapon].get("hazard_assist", 55.0))
	for i in range(hazards.size()):
		var h = hazards[i]
		if not is_instance_valid(h):
			continue
		var wp: Vector3 = h.global_position
		if camera.is_position_behind(wp):
			continue
		var d := camera.unproject_position(wp).distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best_idx = i
	return best_idx


func _on_text_submitted(text: String) -> void:
	if not accepting or game_over:
		return
	var raw := text.strip_edges()
	if raw == "":
		return
	var opts: Array = question.get("opts", [])
	var ans := int(question.get("ans", -1))
	var target := -1
	var norm := _norm(raw)
	for i in range(opts.size()):
		if _norm(str(opts[i])) == norm:
			target = i
			break
	if target < 0:
		var matches: Array = []
		for i in range(opts.size()):
			var o := _norm(str(opts[i]))
			if o.begins_with(norm) and norm.length() >= 2:
				matches.append(i)
		if matches.size() == 1:
			target = int(matches[0])
	input_field.release_focus()
	if fps_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Tir automatique guidé sur la cible correspondante
	if target >= 0 and target < targets.size():
		_fire_shot_effect(targets[target].global_position, str(weapons[weapon].get("type", "bazooka")))

	if target == ans:
		_resolve(target, true)
	elif target >= 0:
		_resolve(target, false)
	else:
		_resolve(-1, true)


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


# ---------- résolution ----------

func _resolve(index: int, typed: bool) -> void:
	if not accepting or game_over:
		return
	accepting = false
	resolving = true
	cd_left = maxf(cd_left, 0.25)
	var opts: Array = question.get("opts", [])
	var ans := int(question.get("ans", -1))
	var correct := index == ans and ans >= 0
	if correct:
		streak += 1
		if streak > best_streak:
			best_streak = streak
		var mult := 1.0 + float(mini(streak - 1, 5)) * 0.2
		var pts := int(round(float(weapons[weapon].get("pts", 10)) * mult))
		if typed:
			pts += 5
		score += pts
		if score > best:
			best = score
			_save_best()
		if index >= 0:
			_pop_target(index, true)
		var msg := "Bravo ! +%d" % pts
		if typed:
			msg += "  (réponse écrite)"
		feedback.text = msg
		feedback.add_theme_color_override("font_color", Color(0.6, 1.0, 0.72))
		_play("ok")
		if gun_game_mode:
			_advance_gun()
		resolve_timer = GOOD_PAUSE
	else:
		streak = 0
		var good := ""
		if ans >= 0 and ans < opts.size():
			good = str(opts[ans])
		var msg := "Raté ! La bonne réponse : %s" % good if good != "" else "Raté !"
		if index >= 0:
			_pop_target(index, false)
		var expl := str(question.get("expl", ""))
		if expl != "":
			msg += "\n" + expl
		feedback.text = msg
		feedback.add_theme_color_override("font_color", Color(1.0, 0.76, 0.6))
		_play("no")
		_lose_hearts(1)
		resolve_timer = BAD_PAUSE
		if pending_over > 0.0:
			resolve_timer = pending_over
	_update_hud()


func _timeout() -> void:
	if not accepting or game_over:
		return
	accepting = false
	resolving = true
	streak = 0
	var opts: Array = question.get("opts", [])
	var ans := int(question.get("ans", -1))
	var good := str(opts[ans]) if ans >= 0 and ans < opts.size() else ""
	feedback.text = "Temps écoulé ! La bonne réponse : %s" % good
	feedback.add_theme_color_override("font_color", Color(1.0, 0.76, 0.6))
	_play("no")
	_lose_hearts(1)
	resolve_timer = BAD_PAUSE
	if pending_over > 0.0:
		resolve_timer = pending_over
	_update_hud()


func _lose_hearts(n: int) -> void:
	if game_over:
		return
	hearts = maxi(0, hearts - n)
	flash_alpha = 0.34
	_update_hud()
	if hearts <= 0:
		pending_over = 1.4


func _hurt() -> void:
	if invuln > 0.0 or game_over:
		return
	invuln = 1.6
	_lose_hearts(1)
	_play("hurt")


func _show_game_over() -> void:
	if game_over:
		return
	game_over = true
	accepting = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear_hazards()
	over_root.visible = true
	over_score.text = "Score : %d   ·   Meilleure série : x%d" % [score, best_streak]
	if score >= best:
		over_meta.text = "Nouveau record !\n%s · %s" % [niveau, CHAR_NAMES[char_index]]
	else:
		over_meta.text = "Record : %d\n%s · %s" % [best, niveau, CHAR_NAMES[char_index]]
	_play("level")
	get_viewport().set_input_as_handled()


func exit_arena() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	exited.emit()


# ---------- bourrasques (monstres de neige) ----------

func _spawn_hazard() -> void:
	var h := Node3D.new()
	h.name = "Bourrasque"
	var off := Vector3(randf_range(-9.0, 9.0), 0.95, randf_range(-11.0, -4.5))
	var base := player.global_position + off
	if base.length() > 14.0:
		base = base.normalized() * 14.0
	base.y = 0.95
	h.position = base
	h.add_child(_snowball())
	h.set_meta("speed", 2.0 + randf() * 1.2)
	h.set_meta("phase", randf() * TAU)
	hazard_root.add_child(h)
	hazards.append(h)


func _snowball() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = _sphere(0.55)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.93, 0.98, 1.0)
	mat.roughness = 0.4
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.6, 0.9)
	mat.emission_energy_multiplier = 0.35
	body.material_override = mat
	root.add_child(body)

	# Yeux bleus lumineux pour repérer les créatures
	for eye_x in [-0.18, 0.18]:
		var eye := MeshInstance3D.new()
		eye.mesh = _sphere(0.08)
		var emat := StandardMaterial3D.new()
		emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		emat.albedo_color = Color(0.2, 0.95, 1.0)
		eye.material_override = emat
		eye.position = Vector3(eye_x, 0.16, 0.48)
		root.add_child(eye)

	# Piques de glace
	for i in range(4):
		var a := float(i) / 4.0 * TAU
		var spike := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.0
		sm.bottom_radius = 0.15
		sm.height = 0.45
		spike.mesh = sm
		spike.material_override = _mat(Color(0.55, 0.82, 1.0), 0.4)
		spike.position = Vector3(cos(a) * 0.45, 0.28, sin(a) * 0.45)
		root.add_child(spike)
	return root


func _pop_hazard(h: Node3D, destroyed: bool) -> void:
	if not is_instance_valid(h):
		return
	hazards.erase(h)
	var pos := h.global_position
	if destroyed:
		_burst(pos, Color(0.75, 0.95, 1.0))
		_spawn_floating_text(pos + Vector3(0, 0.8, 0), "+3", Color(0.4, 1.0, 0.6))
		if host != null and host.has_method("_play"):
			host._play("boom")
	h.queue_free()


func _clear_hazards() -> void:
	for h in hazards:
		if is_instance_valid(h):
			h.queue_free()
	hazards.clear()


# ---------- effets & tirs ----------

func _fire_shot_effect(target_pos: Vector3, wtype: String) -> void:
	var muzzle: Vector3
	if fps_mode:
		muzzle = camera.global_position + (-camera.global_transform.basis.z * 0.4) + (camera.global_transform.basis.x * 0.25) + (camera.global_transform.basis.y * -0.18)
	else:
		muzzle = visual.to_global(Vector3(0.34, 0.98, 0.9))

	# Flash au canon
	var flash := MeshInstance3D.new()
	flash.mesh = _sphere(0.25 if wtype != "bazooka" else 0.45)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.95, 0.6) if wtype != "bow" else Color(0.4, 0.95, 1.0)
	flash.material_override = fm
	add_child(flash)
	flash.global_position = muzzle
	var t1 := create_tween()
	t1.tween_property(flash, "scale", Vector3(2.5, 2.5, 2.5), 0.08)
	t1.parallel().tween_property(flash, "scale", Vector3.ZERO, 0.12).set_delay(0.08)
	t1.finished.connect(flash.queue_free)

	match wtype:
		"bow":
			# Flèche traçante rapide
			var arrow := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.02
			cyl.bottom_radius = 0.02
			cyl.height = 0.65
			arrow.mesh = cyl
			var amat := StandardMaterial3D.new()
			amat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			amat.albedo_color = Color(0.5, 0.95, 1.0)
			arrow.material_override = amat
			add_child(arrow)
			arrow.global_position = muzzle
			arrow.look_at(target_pos)
			var tw := create_tween()
			tw.tween_property(arrow, "global_position", target_pos, 0.08)
			tw.finished.connect(arrow.queue_free)
			_burst(target_pos, Color(0.55, 0.92, 1.0))

		"shotgun":
			# 5 plombs en gerbe
			for k in range(5):
				var tracer := MeshInstance3D.new()
				tracer.mesh = _sphere(0.08)
				var tm := StandardMaterial3D.new()
				tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				tm.albedo_color = Color(0.85, 0.95, 1.0)
				tracer.material_override = tm
				add_child(tracer)
				tracer.global_position = muzzle
				var spread := Vector3(randf_range(-0.8, 0.8), randf_range(-0.6, 0.6), randf_range(-0.4, 0.4))
				var tw := create_tween()
				tw.tween_property(tracer, "global_position", target_pos + spread, 0.07)
				tw.finished.connect(tracer.queue_free)
			_burst(target_pos, Color(0.7, 0.9, 1.0))

		"sniper":
			# Rayon laser instantané puissant
			var beam := MeshInstance3D.new()
			var bm := CylinderMesh.new()
			bm.top_radius = 0.04
			bm.bottom_radius = 0.04
			var dist := muzzle.distance_to(target_pos)
			bm.height = dist
			beam.mesh = bm
			var bmat := StandardMaterial3D.new()
			bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bmat.albedo_color = Color(0.3, 0.9, 1.0)
			beam.material_override = bmat
			add_child(beam)
			beam.global_position = (muzzle + target_pos) * 0.5
			beam.look_at(target_pos)
			beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)
			var tw := create_tween()
			tw.tween_property(beam, "scale", Vector3(0.01, 1.0, 0.01), 0.16)
			tw.finished.connect(beam.queue_free)
			_burst(target_pos, Color(0.4, 0.95, 1.0))

		"bazooka":
			# Roquette explosive
			var rocket := MeshInstance3D.new()
			rocket.mesh = _sphere(0.18)
			var rmat := StandardMaterial3D.new()
			rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			rmat.albedo_color = Color(1.0, 0.85, 0.3)
			rocket.material_override = rmat
			add_child(rocket)
			rocket.global_position = muzzle
			var tw := create_tween()
			tw.tween_property(rocket, "global_position", target_pos, 0.10)
			tw.finished.connect(rocket.queue_free)
			# Explosion massive
			_burst(target_pos, Color(1.0, 0.85, 0.4))
			_burst(target_pos, Color(0.45, 0.85, 1.0))

		_: # Pistolet & Mitrailleuse
			var tracer := MeshInstance3D.new()
			tracer.mesh = _sphere(0.09)
			var tm := StandardMaterial3D.new()
			tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			tm.albedo_color = Color(0.7, 0.93, 1.0)
			tracer.material_override = tm
			add_child(tracer)
			tracer.global_position = muzzle
			var t2 := create_tween()
			t2.tween_property(tracer, "global_position", target_pos, 0.07)
			t2.finished.connect(tracer.queue_free)
			_burst(target_pos, Color(0.72, 0.94, 1.0))


func _burst(pos: Vector3, color: Color) -> void:
	for k in range(16):
		var s := MeshInstance3D.new()
		s.mesh = _sphere(0.12)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		s.material_override = mat
		add_child(s)
		s.global_position = pos
		var d := Vector3(randf_range(-1, 1), randf_range(0.3, 1.0), randf_range(-1, 1)).normalized()
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(s, "global_position", pos + d * randf_range(1.4, 3.2) + Vector3(0, 0.9, 0), 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(s, "scale", Vector3.ZERO, 0.55)
		tw.finished.connect(s.queue_free)


func _spawn_floating_text(pos: Vector3, text: String, color: Color) -> void:
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


func _pop_target(i: int, good: bool) -> void:
	if i < 0 or i >= targets.size():
		return
	var t: Node3D = targets[i]
	if not is_instance_valid(t):
		return
	_burst(t.global_position, Color(0.55, 1.0, 0.65) if good else Color(1.0, 0.5, 0.45))
	var tw := create_tween()
	tw.tween_property(t, "scale", Vector3(1.18, 1.18, 1.18), 0.1)
	tw.tween_property(t, "scale", Vector3.ONE, 0.2)


# ---------- utilitaires ----------

func _play(sname: String) -> void:
	if host != null and host.has_method("_play"):
		host._play(sname)


func _mat(color: Color, rough := 0.65) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
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
		"weapon": weapon,
		"hazards": hazards.size(),
		"best": best,
		"time_left": time_left,
		"niveau": niveau,
		"theme": theme,
	}


func debug_shoot(index: int) -> void:
	_resolve(index, false)


func debug_type(text: String) -> void:
	_on_text_submitted(text)


func debug_skip() -> void:
	if not accepting and not game_over:
		_new_question()


func debug_set_weapon(i: int) -> void:
	_set_weapon(i)


func debug_spawn_hazard() -> void:
	_spawn_hazard()


func debug_lose_hearts(n: int) -> void:
	_lose_hearts(n)
