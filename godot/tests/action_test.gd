extends SceneTree

# Test headless du mode Arène : déplacement/tir/réponse écrite/armes/dégâts.

var main = null
var a = null
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
	return a.debug_state()


func _run() -> void:
	await process_frame
	_check(main.menu_root.visible, "menu non visible au démarrage")

	main.start_arena()
	await process_frame
	a = main.action_mode
	_check(a != null, "arène non instanciée")
	_check(not main.menu_root.visible, "menu encore visible dans l'arène")
	_check(not main.ui.visible, "HUD quiz encore visible dans l'arène")

	var st := _state()
	_check(str(st["question"]) != "", "question vide")
	_check(str(st["question"]).find("${") < 0, "question non résolue : %s" % st["question"])
	var opts: Array = st["opts"]
	_check(opts.size() >= 2 and opts.size() <= 4, "options invalides : %d" % opts.size())
	_check(int(st["ans"]) >= 0 and int(st["ans"]) < opts.size(), "index de réponse invalide")
	_check(int(st["hearts"]) == 3, "cœurs initiaux != 3")
	_check(bool(st["accepting"]), "question non acceptée")

	# tir sur la bonne cible
	var ans := int(st["ans"])
	var before_score := int(st["score"])
	a.debug_shoot(ans)
	st = _state()
	_check(not bool(st["accepting"]), "la question reste ouverte après un tir")
	_check(int(st["score"]) > before_score, "score non augmenté après bonne réponse")
	_check(int(st["streak"]) == 1, "série non incrémentée")

	# question suivante
	a.debug_skip()
	st = _state()
	_check(bool(st["accepting"]), "question suivante non ouverte")

	# mauvaise réponse -> perte d'un cœur
	a.debug_shoot((int(st["ans"]) + 1) % (st["opts"] as Array).size())
	st = _state()
	_check(int(st["hearts"]) == 2, "cœur non perdu après mauvaise réponse")
	_check(int(st["streak"]) == 0, "série non remise à zéro")
	a.debug_skip()

	# réponse écrite correcte
	st = _state()
	_check(bool(st["accepting"]), "question non ouverte pour le test écrit")
	var txt := str((st["opts"] as Array)[int(st["ans"])])
	var s_before := int(st["score"])
	a.debug_type(txt)
	st = _state()
	_check(int(st["score"]) > s_before, "réponse écrite correcte non validée (%s)" % txt)
	a.debug_skip()

	# réponse écrite fausse
	st = _state()
	_check(bool(st["accepting"]), "question non ouverte pour la réponse écrite fausse")
	a.debug_type("zzz-réponse-impossible")
	st = _state()
	_check(int(st["hearts"]) == 1, "pas de pénalité sur réponse écrite fausse")
	a.debug_skip()

	# armes
	a.debug_set_weapon(1)
	_check(int(_state()["weapon"]) == 1, "arme 2 non sélectionnée")
	a.debug_set_weapon(2)
	_check(int(_state()["weapon"]) == 2, "arme 3 non sélectionnée")
	a.debug_set_weapon(0)

	# bourrasque
	a.debug_spawn_hazard()
	_check(int(_state()["hazards"]) == 1, "bourrasque non créée")

	# fin de partie
	a.debug_lose_hearts(3)
	_check(int(_state()["hearts"]) == 0, "cœurs non à zéro")
	_check(a.pending_over > 0.0, "fin de partie non programmée")
	a._show_game_over()
	_check(a != null and bool(_state()["game_over"]), "partie non terminée à 0 cœur")
	_check(a.over_root.visible, "écran de fin non affiché")

	# retour au menu
	a.exit_arena()
	await process_frame
	await process_frame
	a = main.action_mode
	_check(a == null, "arène non libérée")
	_check(main.ui.visible, "HUD quiz non restauré")
	_check(main.menu_root.visible, "menu non restauré")

	# une arène peut être relancée
	main.start_arena()
	await process_frame
	_check(main.action_mode != null, "arène non relancée")
	main.action_mode.exit_arena()
	await process_frame
	await process_frame
	_check(main.action_mode == null, "seconde arène non libérée")

	if failures.is_empty():
		print("ARENE OK — déplacement, cibles, réponse écrite, armes, dégâts, fin de partie")
		quit(0)
	else:
		for f in failures:
			print("ECHEC :: ", f)
		quit(1)
