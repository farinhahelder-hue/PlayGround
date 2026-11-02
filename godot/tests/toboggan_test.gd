extends SceneTree

# Test headless du mode Toboggan : descente, portes, tir, obstacles, vies, fin de partie.

var main = null
var t = null
var failures: Array = []


func _initialize() -> void:
	seed(2027)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _state() -> Dictionary:
	return t.debug_state()


func _run() -> void:
	await process_frame
	_check(main.menu_root.visible, "menu non visible au démarrage")

	main.start_toboggan()
	await process_frame
	t = main.toboggan_mode
	_check(t != null, "toboggan non instancié")
	_check(main.action_mode == null, "l'arène ne doit pas démarrer en même temps")
	t.save_path = "user://toboggan_test.cfg"
	t.best = 0
	_check(not main.menu_root.visible, "menu encore visible sur la piste")
	_check(not main.ui.visible, "HUD quiz encore visible sur la piste")

	var st := _state()
	_check(str(st["question"]) != "", "question vide")
	_check(str(st["question"]).find("${") < 0, "question non résolue : %s" % st["question"])
	var opts: Array = st["opts"]
	_check(opts.size() >= 2 and opts.size() <= 4, "options invalides : %d" % opts.size())
	_check(int(st["ans"]) >= 0 and int(st["ans"]) < opts.size(), "index de réponse invalide")
	_check(int(st["gate_count"]) == opts.size(), "portes 3D incomplètes")
	_check(float(st["gate_z"]) < -20.0, "portes trop proches du joueur")
	_check(int(st["hearts"]) == 3, "cœurs initiaux != 3")
	_check(bool(st["accepting"]), "question non acceptée")
	_check(int(st["obstacles"]) == 0, "blocs présents dès le départ")
	_check(float(st["speed"]) >= 8.0, "vitesse initiale trop faible")

	# franchir la bonne porte
	var ans := int(st["ans"])
	t.debug_set_player_x(float(t.gate_items[ans]["x"]))
	var before_score := int(st["score"])
	t.debug_cross_gate()
	st = _state()
	_check(not bool(st["accepting"]), "la question reste ouverte après le passage d'une porte")
	_check(int(st["score"]) > before_score, "score non augmenté après la bonne porte")
	_check(int(st["streak"]) == 1, "série non incrémentée après la bonne porte")
	_check(int(st["answered"]) == 1, "compteur de questions non incrémenté")
	t.debug_skip()
	st = _state()
	_check(bool(st["accepting"]), "question suivante non ouverte")
	_check(int(st["gate_count"]) > 0, "portes non recréées")

	# mauvaise porte -> perte d'un cœur
	st = _state()
	var wrong := (int(st["ans"]) + 1) % (st["opts"] as Array).size()
	t.debug_set_player_x(float(t.gate_items[wrong]["x"]))
	t.debug_cross_gate()
	st = _state()
	_check(int(st["hearts"]) == 2, "cœur non perdu après la mauvaise porte")
	_check(int(st["streak"]) == 0, "série non remise à zéro après la mauvaise porte")
	t.debug_skip()

	# porte manquée (aucune porte franchie) -> pas de cœur perdu
	st = _state()
	t.debug_set_player_x(100.0)
	t.debug_cross_gate()
	st = _state()
	_check(int(st["hearts"]) == 2, "une porte manquée ne doit pas retirer de cœur")
	_check(int(st["streak"]) == 0, "série non remise à zéro après une porte manquée")
	_check(not bool(st["accepting"]), "question encore ouverte après une porte manquée")
	t.debug_skip()
	t.debug_set_player_x(0.0)

	# réponse écrite correcte
	st = _state()
	var txt := str((st["opts"] as Array)[int(st["ans"])])
	var s_before := int(st["score"])
	t.debug_type(txt)
	st = _state()
	_check(int(st["score"]) > s_before, "réponse écrite correcte non validée (%s)" % txt)
	_check(int(st["streak"]) == 1, "série non incrémentée après la réponse écrite")
	t.debug_skip()

	# réponse écrite fausse -> cœur perdu
	st = _state()
	var h_before := int(st["hearts"])
	t.debug_type("zzz-reponse-impossible")
	st = _state()
	_check(int(st["hearts"]) == h_before - 1, "pas de pénalité sur réponse écrite fausse")
	t.debug_skip()

	# tirer sur la bonne porte
	st = _state()
	s_before = int(st["score"])
	t.debug_shoot(int(st["ans"]))
	st = _state()
	_check(int(st["score"]) > s_before, "score non augmenté après un tir sur la bonne porte")
	t.debug_skip()

	# tirer sur un bloc de glace
	st = _state()
	var kills_before := int(st["destroyed"])
	t.debug_spawn_obstacle(-2.0, -12.0)
	_check(int(_state()["obstacles"]) == 1, "bloc de glace non créé")
	s_before = int(_state()["score"])
	t.debug_shoot_obstacle(0)
	st = _state()
	_check(int(st["obstacles"]) == 0, "bloc non détruit au tir")
	_check(int(st["destroyed"]) == kills_before + 1, "compteur de blocs non incrémenté")
	_check(int(st["score"]) > s_before, "score non augmenté après un bloc détruit")

	# percuter un bloc -> cœur perdu
	t.debug_set_hearts(3)
	t.debug_spawn_obstacle(0.0, -5.0)
	var hb := int(_state()["hearts"])
	t.debug_collide_obstacle(0)
	st = _state()
	_check(int(st["hearts"]) == hb - 1, "cœur non perdu après une collision")
	_check(int(st["obstacles"]) == 0, "bloc non retiré après une collision")

	# le programme CE2 tourne sur les 7 thèmes, sans doublon ni question vide
	t.debug_set_hearts(3)
	var seen_themes := {}
	for i in range(60):
		var qs := _state()
		var qopts: Array = qs["opts"]
		_check(str(qs["question"]) != "" and str(qs["question"]).find("${") < 0, "question CE2 invalide")
		_check(qopts.size() >= 2 and qopts.size() <= 4, "options CE2 invalides")
		var uniq := {}
		for o in qopts:
			uniq[str(o)] = true
		_check(uniq.size() == qopts.size(), "options dupliquées : %s" % str(qopts))
		seen_themes[str(qs["theme"])] = true
		t.debug_shoot(int(qs["ans"]))
		t.debug_skip()
	_check(seen_themes.size() == 7, "thèmes CE2 incomplets : %s" % str(seen_themes.keys()))

	# fin de partie
	t.debug_set_hearts(1)
	t.debug_lose_hearts(3)
	st = _state()
	_check(int(st["hearts"]) == 0, "cœurs non à zéro")
	_check(float(st["pending_over"]) > 0.0, "fin de partie non programmée")
	t._show_game_over()
	st = _state()
	_check(bool(st["game_over"]), "partie non terminée à 0 cœur")
	_check(t.over_root.visible, "écran de fin non affiché")
	_check(int(st["best"]) >= int(st["score"]), "record non mis à jour")

	# rejouer
	t._restart()
	st = _state()
	_check(bool(st["accepting"]), "question non ouverte après Rejouer")
	_check(int(st["hearts"]) == 3, "cœurs non restaurés")
	_check(int(st["score"]) == 0, "score non remis à zéro")
	_check(not bool(st["game_over"]), "partie encore terminée après Rejouer")
	_check(int(st["gate_count"]) > 0, "portes non recréées après Rejouer")

	# retour au menu
	t.exit_toboggan()
	await process_frame
	await process_frame
	t = main.toboggan_mode
	_check(t == null, "toboggan non libéré")
	_check(main.ui.visible, "HUD quiz non restauré")
	_check(main.menu_root.visible, "menu non restauré")

	# une descente peut être relancée
	main.start_toboggan()
	await process_frame
	_check(main.toboggan_mode != null, "toboggan non relancé")
	main.toboggan_mode.save_path = "user://toboggan_test.cfg"
	main.toboggan_mode.best = 0
	main.toboggan_mode.exit_toboggan()
	await process_frame
	await process_frame
	_check(main.toboggan_mode == null, "seconde descente non libérée")

	var abs := ProjectSettings.globalize_path("user://toboggan_test.cfg")
	if FileAccess.file_exists(abs):
		DirAccess.remove_absolute(abs)

	if failures.is_empty():
		print("TOBOGGAN OK — descente, portes, tir, obstacles, vies, fin de partie")
		quit(0)
	else:
		for f in failures:
			print("ECHEC :: ", f)
		quit(1)
