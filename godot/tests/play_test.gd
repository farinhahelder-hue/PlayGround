extends SceneTree

const Gen = preload("res://scripts/generators.gd")

var main = null
var failures: Array = []

func _initialize() -> void:
	seed(4242)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	call_deferred("_run")

func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

func _run() -> void:
	_check(main != null, "scène non instanciée")
	_check(main.menu_root.visible, "menu non visible au démarrage")

	# trois manches solo de 5 questions
	for round_idx in range(3):
		main.start_game()
		_check(main.playing, "partie non démarrée (manche %d)" % round_idx)
		var texts := []
		var themes := []
		themes.append(main.theme)
		for i in range(5):
			var st: Dictionary = main.debug_state()
			texts.append(str(st["q"]))
			var opts: Array = st["opts"]
			_check(opts.size() >= 2 and opts.size() <= 4, "nombre d'options invalide : %d" % opts.size())
			var seen := {}
			for o in opts:
				seen[str(o)] = true
			_check(seen.size() == opts.size(), "option dupliquée : %s" % str(opts))
			var ans := int(st["ans"])
			_check(ans >= 0 and ans < opts.size(), "index de réponse invalide")
			_check(str(st["q"]).find("${") < 0 and str(st["q"]).find("null") < 0, "question invalide : %s" % st["q"])
			main.answer(0)
			_check(main.total == i + 1, "compteur non incrémenté")
			main.next_question()
		_check(main.results_root.visible, "résultats non affichés (manche %d)" % round_idx)
		var uniq := {}
		for t in texts:
			uniq[t] = true
		_check(uniq.size() == texts.size(), "question répétée dans la manche : %s" % str(texts))
		main.back_to_menu()
		_check(main.menu_root.visible, "retour menu raté")

	# sans fin : 12 questions et remise à zéro du compteur jamais atteinte
	main.start_nonstop()
	var count := 0
	for i in range(12):
		main.answer(1)
		main.next_question()
		count += 1
	_check(main.total == 12, "sans fin : total %d" % main.total)
	_check(main.results_root.visible == false, "sans fin s'arrête à tort")
	main.back_to_menu()

	# duo : deux joueurs alternent
	main.start_duo()
	var p1_start: int = main.duo_turn
	main.answer(0)
	main.next_question()
	for i in range(4):
		main.answer(0)
		main.next_question()
	_check(main.results_root.visible, "duo : résultats absents")
	main.duo_next()
	_check(main.duo_turn != p1_start, "duo : joueur non changé")
	_check(main.playing, "duo : manche suivante non lancée")

	# échantillon large des générateurs sous le moteur
	var total_q := 0
	var dup := 0
	for level in ["CP", "CE1", "CE2"]:
		for th in ["nombres", "mesures", "grammaire", "conjugaison", "sciences", "anglais", "logique"]:
			for i in range(120):
				var r: Dictionary = Gen.question(th, level)
				total_q += 1
				var seen := {}
				for o in r["opts"]:
					seen[str(o)] = true
				if seen.size() != r["opts"].size():
					dup += 1
	_check(dup == 0, "doublons générateurs : %d" % dup)
	_check(total_q == 2520, "échantillon incomplet")

	if failures.is_empty():
		print("PLAYTEST OK — manches solo, sans fin, duo, 2520 questions sans doublon")
		quit(0)
	else:
		for f in failures:
			print("ECHEC :: ", f)
		quit(1)
