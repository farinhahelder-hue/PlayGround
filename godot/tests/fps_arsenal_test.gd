extends SceneTree

# Test headless de l'Arsenal CS Gun Game, de la vue FPS et du tir sur les bourrasques

var main = null
var a = null
var failures: Array = []

func _initialize() -> void:
	seed(42)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	call_deferred("_run")

func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

func _run() -> void:
	await process_frame
	main.start_arena()
	await process_frame
	a = main.action_mode
	_check(a != null, "Arène non créée")

	# Vérification des 6 armes
	_check(a.weapons.size() == 6, "L'arsenal doit contenir 6 armes, reçu: %d" % a.weapons.size())
	for i in range(6):
		a._set_weapon(i)
		_check(a.weapon == i, "Arme %d non sélectionnée" % i)
		_check(a.char_weapon_holder.get_child_count() > 0, "Modèle 3D d'arme manquant sur le personnage")
		_check(a.fps_weapon_holder.get_child_count() > 0, "Modèle 3D d'arme manquant sur le viewmodel FPS")

	# Test bascule FPS
	_check(not a.fps_mode, "Mode initial doit être 3ème personne")
	a._toggle_fps()
	_check(a.fps_mode, "Mode FPS non activé")
	_check(a.fps_rig.visible, "Viewmodel FPS doit être visible")
	_check(not a.visual.visible, "Corps du joueur doit être masqué en FPS")

	# Bascule retour
	a._toggle_fps()
	_check(not a.fps_mode, "Mode 3ème personne non restauré")
	_check(not a.fps_rig.visible, "Viewmodel FPS doit être masqué en 3ème personne")
	_check(a.visual.visible, "Corps du joueur doit être visible en 3ème personne")

	# Test tir et destruction des bourrasques (monstres de neige)
	a._set_weapon(0) # Arc
	a.debug_spawn_hazard()
	_check(a.hazards.size() == 1, "Monstre de neige non créé")
	var hz = a.hazards[0]
	var old_score = a.score
	a._pop_hazard(hz, true)
	_check(a.score == old_score, "Score pop")

	# Test Gun Game promotion
	a._set_weapon(0)
	var prev_w = a.weapon
	a._advance_gun()
	_check(a.weapon == prev_w + 1, "Gun Game promotion échouée")

	# Test capture d'écran si disponible
	var tex = root.get_texture()
	if tex != null:
		var img := tex.get_image()
		if img != null:
			img.save_png("res://capture_arena_fps.png")
			print("CAPTURE FPS GENEREE")

	a.exit_arena()
	await process_frame

	if failures.is_empty():
		print("FPS & ARSENAL GUN GAME OK — 6 armes 3D, vue FPS, tir sur les monstres")
		quit(0)
	else:
		for f in failures:
			print("ECHEC :: ", f)
		quit(1)
