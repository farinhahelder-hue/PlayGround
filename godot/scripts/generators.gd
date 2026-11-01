class_name BanquiseGen
extends RefCounted

# ---------- helpers (miroir de index.html) ----------

static func rnd(n: int) -> int:
	return randi() % n

static func pick(a):
	return a[rnd(a.size())]

static func shuf(a):
	var arr = a.duplicate()
	for i in range(arr.size() - 1, 0, -1):
		var j = rnd(i + 1)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t
	return arr

static func mk(q: String, opts, ans: int, expl: String) -> Dictionary:
	return {"q": q, "opts": opts, "ans": ans, "expl": expl}

static func mk_from_pool(q: String, correct, pool, expl: String) -> Dictionary:
	var opts = [correct]
	var seen = {str(correct): true}
	var guard = 0
	while opts.size() < 4 and guard < 120:
		var c = pick(pool)
		if not seen.has(str(c)):
			seen[str(c)] = true
			opts.append(c)
		guard += 1
	var mixed = shuf(opts)
	return mk(q, mixed, mixed.find(correct), expl)

static func num_opts(correct: int, step: int, minimum: int) -> Array:
	var out = [correct]
	var cands = [correct + step, correct - step, correct + 2 * step, correct + 3 * step, correct - 2 * step, correct + 4 * step]
	for i in range(cands.size()):
		if out.size() >= 4:
			break
		var v = int(round(cands[i]))
		if v >= minimum and out.find(v) < 0:
			out.append(v)
	return shuf(out)

static func mk_num(q: String, r: int, step: int, minimum: int, expl: String) -> Dictionary:
	var o = num_opts(r, step, minimum)
	return mk(q, o, o.find(r), expl)

static func mk_list(q: String, list, correct, expl: String) -> Dictionary:
	var o = shuf(list)
	return mk(q, o, o.find(correct), expl)

static func comparer_opts(a: int, b: int) -> Array:
	var hi = max(a, b)
	var lo = min(a, b)
	var out = [hi, lo]
	var guard = 0
	while out.size() < 4 and guard < 80:
		var c = rnd(max(hi, 20)) + 1
		if out.find(c) < 0:
			out.append(c)
		guard += 1
	return shuf(out)

static func conj_q(verb: String, forms: Array, tense_label: String) -> Dictionary:
	var idx = rnd(6)
	var pro = ["Je", "Tu", "Il", "Nous", "Vous", "Ils"][idx]
	var correct = forms[idx]
	var others = []
	for j in range(forms.size()):
		if j != idx and forms[j] != correct and others.find(forms[j]) < 0:
			others.append(forms[j])
	var opts = shuf([correct] + shuf(others).slice(0, 3))
	var head = ""
	if pro == "Je":
		head = "J'" if correct.substr(0, 1).to_lower() in ["a", "e", "i", "o", "u", "é", "è", "ê", "h"] else "Je "
	else:
		head = pro + " "
	return mk(head + "... " + tense_label + " (" + verb + ")", opts, opts.find(correct), head + correct + ".")

# ---------- nombres ----------

static func nombres(level: String) -> Dictionary:
	if level == "CP":
		var mode = pick(["avant", "apres", "comparer", "suite", "double", "moitie", "add", "sous"])
		if mode == "avant" or mode == "apres":
			var n = rnd(17) + 3
			var after = mode == "apres"
			var r = n + 1 if after else n - 1
			return mk_num("Quel nombre vient juste %s %d ?" % ["après" if after else "avant", n], r, 1, 0, "%s %d, c'est %d." % ["Après" if after else "Avant", n, r])
		if mode == "comparer":
			var a = rnd(20) + 1
			var b = rnd(20) + 1
			while a == b:
				b = rnd(20) + 1
			var o = comparer_opts(a, b)
			return mk("Quel est le plus grand nombre ?", o, o.find(max(a, b)), "%d est plus grand que %d." % [max(a, b), min(a, b)])
		if mode == "suite":
			var a = rnd(8) + 1
			return mk_num("Quel nombre continue : %d, %d, %d, ... ?" % [a, a + 1, a + 2], a + 3, 1, 0, "On ajoute 1 à chaque fois : %d." % [a + 3])
		if mode == "double":
			var a = rnd(9) + 1
			return mk_num("Combien font %d + %d ?" % [a, a], a + a, 1, 0, "%d + %d = %d. Le double de %d est %d." % [a, a, a + a, a, a + a])
		if mode == "moitie":
			var a = (rnd(9) + 1) * 2
			return mk_num("Quelle est la moitié de %d ?" % [a], a / 2, 1, 0, "La moitié de %d est %d." % [a, a / 2])
		if mode == "add":
			var a = rnd(10) + 1
			var b = rnd(10) + 1
			return mk_num("Combien font %d + %d ?" % [a, b], a + b, 1, 0, "%d + %d = %d." % [a, b, a + b])
		var a = rnd(12) + 5
		var b = rnd(a - 3) + 1
		return mk_num("Combien font %d - %d ?" % [a, b], a - b, 1, 0, "%d - %d = %d." % [a, b, a - b])
	if level == "CE1":
		var mode = pick(["comparer", "suite10", "add", "sous", "double", "moitie", "table2", "table5", "dizaine"])
		if mode == "comparer":
			var a = rnd(99) + 1
			var b = rnd(99) + 1
			while a == b:
				b = rnd(99) + 1
			var o = comparer_opts(a, b)
			return mk("Quel est le plus grand nombre ?", o, o.find(max(a, b)), "%d est plus grand que %d." % [max(a, b), min(a, b)])
		if mode == "suite10":
			var a = (rnd(8) + 1) * 10
			return mk_num("Quel nombre continue : %d, %d, ... ?" % [a, a + 10], a + 20, 10, 0, "On ajoute 10 à chaque fois : %d." % [a + 20])
		if mode == "add":
			var a = rnd(45) + 10
			var b = rnd(40) + 5
			return mk_num("Combien font %d + %d ?" % [a, b], a + b, 1, 0, "%d + %d = %d." % [a, b, a + b])
		if mode == "sous":
			var a = rnd(60) + 30
			var b = rnd(a - 10) + 1
			return mk_num("Combien font %d - %d ?" % [a, b], a - b, 1, 0, "%d - %d = %d." % [a, b, a - b])
		if mode == "double":
			var a = rnd(40) + 5
			return mk_num("Combien font %d + %d ?" % [a, a], a + a, 1, 0, "Le double de %d est %d." % [a, a + a])
		if mode == "moitie":
			var a = (rnd(30) + 5) * 2
			return mk_num("Quelle est la moitié de %d ?" % [a], a / 2, 1, 0, "La moitié de %d est %d." % [a, a / 2])
		if mode == "table2":
			var a = rnd(9) + 1
			return mk_num("Combien font %d x 2 ?" % [a], a * 2, 1, 0, "%d x 2 = %d." % [a, a * 2])
		if mode == "table5":
			var a = rnd(9) + 1
			return mk_num("Combien font %d x 5 ?" % [a], a * 5, 1, 0, "%d x 5 = %d." % [a, a * 5])
		var n = rnd(89) + 10
		var d = n / 10
		return mk_num("Combien de dizaines y a-t-il dans %d ?" % [n], d, 1, 0, "%d = %d dizaines et %d unités." % [n, d, n % 10])
	# CE2
	var mode = pick(["comparer", "add", "sous", "table", "div2", "centaine", "ordre"])
	if mode == "comparer":
		var a = rnd(899) + 100
		var b = rnd(899) + 100
		while a == b:
			b = rnd(899) + 100
		var o = comparer_opts(a, b)
		return mk("Quel est le plus grand nombre ?", o, o.find(max(a, b)), "%d est plus grand que %d." % [max(a, b), min(a, b)])
	if mode == "add":
		var a = rnd(400) + 100
		var b = rnd(300) + 50
		return mk_num("Combien font %d + %d ?" % [a, b], a + b, 1, 0, "%d + %d = %d." % [a, b, a + b])
	if mode == "sous":
		var a = rnd(400) + 500
		var b = rnd(a - 100) + 50
		return mk_num("Combien font %d - %d ?" % [a, b], a - b, 1, 0, "%d - %d = %d." % [a, b, a - b])
	if mode == "table":
		var m = pick([3, 4, 6, 7, 8])
		var a = rnd(8) + 2
		return mk_num("Combien font %d x %d ?" % [a, m], a * m, 1, 0, "%d x %d = %d." % [a, m, a * m])
	if mode == "div2":
		var a = (rnd(40) + 5) * 2
		return mk_num("Combien font %d / 2 ?" % [a], a / 2, 1, 0, "%d / 2 = %d." % [a, a / 2])
	if mode == "centaine":
		var n = rnd(899) + 100
		var c = n / 100
		return mk_num("Combien de centaines y a-t-il dans %d ?" % [n], c, 1, 0, "%d = %d centaines et %d." % [n, c, n % 100])
	var xs = []
	while xs.size() < 4:
		var v = rnd(900) + 10
		if xs.find(v) < 0:
			xs.append(v)
	var sorted = xs.duplicate()
	sorted.sort()
	var parts = []
	for v in sorted:
		parts.append(str(v))
	var good = " < ".join(parts)
	var rev = sorted.duplicate()
	rev.reverse()
	var bads = [
		" < ".join(rev.map(func(x): return str(x))),
		"%d < %d < %d < %d" % [sorted[1], sorted[0], sorted[2], sorted[3]],
		"%d < %d < %d < %d" % [sorted[0], sorted[2], sorted[1], sorted[3]]
	]
	var opts = [good]
	for b in bads:
		if opts.find(b) < 0:
			opts.append(b)
	return mk_list("Range ces nombres dans l'ordre croissant : %s" % ", ".join(parts), opts, good, "L'ordre croissant est %s." % good)

# ---------- mesures ----------

static func mesures(level: String) -> Dictionary:
	if level == "CP":
		var mode = pick(["heure_pile", "heure_demi", "longueur", "monnaie_euro", "monnaie_cent"])
		if mode == "heure_pile" or mode == "heure_demi":
			var h = rnd(12) + 1
			var next = 1 if h == 12 else h + 1
			var prev = 12 if h == 1 else h - 1
			if mode == "heure_pile":
				var opts = shuf(["%d h" % h, "%d h" % next, "%d h" % prev, "%d h 30" % h])
				return mk("Quelle heure est-il ? L'aiguille des heures est sur %d et l'aiguille des minutes est sur 12." % h, opts, opts.find("%d h" % h), "Il est %d heure%s." % [h, "s" if h > 1 else ""])
			var opts = shuf(["%d h 30" % h, "%d h" % next, "%d h" % h, "%d h 15" % h])
			return mk("Quelle heure est-il ? L'aiguille des minutes est sur 6.", opts, opts.find("%d h 30" % h), "Il est %d heures et demie." % h)
		if mode == "longueur":
			var a = rnd(90) + 10
			var b = rnd(90) + 10
			while a == b:
				b = rnd(90) + 10
			var correct = "%d cm est plus long que %d cm" % [a, b] if a > b else "%d cm est plus long que %d cm" % [b, a]
			var other = "%d cm est plus long que %d cm" % [b, a] if a > b else "%d cm est plus long que %d cm" % [a, b]
			var opts = [correct, other, "Les deux longueurs sont égales"]
			return mk_list("Quelle longueur est la plus longue : %d cm ou %d cm ?" % [a, b], opts, correct, "%d cm est plus long que %d cm." % [max(a, b), min(a, b)])
		if mode == "monnaie_euro":
			var a = rnd(4) + 1
			return mk_num("Combien de pièces de 1 € faut-il pour faire %d € ?" % a, a, 1, 0, "Il faut %d pièces de 1 €." % a)
		var a = rnd(8) + 1
		return mk_num("Combien de pièces de 10 centimes faut-il pour faire %d centimes ?" % (a * 10), a, 1, 0, "Il faut %d pièces de 10 centimes." % a)
	if level == "CE1":
		var mode = pick(["heure_quart", "monnaie_rendre", "cm_m", "unite_mass", "perimetre", "solide"])
		if mode == "heure_quart":
			var h = rnd(12) + 1
			var m = pick([0, 15, 30, 45])
			var label = "%d h" % h if m == 0 else "%d h %d" % [h, m]
			var opts = ["%d h" % h, "%d h 15" % h, "%d h 30" % h, "%d h 45" % h]
			var pos = 12 if m == 0 else m / 5
			return mk_list("Quelle heure est-il ? L'aiguille des minutes est sur %d." % pos, opts, label, "Il est %s." % label)
		if mode == "monnaie_rendre":
			var prix = rnd(6) + 2
			var rend = 10 - prix
			return mk_num("Un objet coûte %d €. Tu paies avec un billet de 10 €. Combien te rend-on ?" % prix, rend, 1, 0, "10 € - %d € = %d €." % [prix, rend])
		if mode == "cm_m":
			var n = rnd(4) + 1
			return mk_num("Combien de centimètres y a-t-il dans %d m ?" % n, n * 100, 100, 0, "1 m = 100 cm, donc %d m = %d cm." % [n, n * 100])
		if mode == "unite_mass":
			return mk_list("Quelle unité utilise-t-on pour peser une pomme ?", ["g", "kg", "L", "cm"], "g", "On pèse une pomme en grammes (g).")
		if mode == "perimetre":
			var a = rnd(6) + 1
			var b = rnd(6) + 1
			var c = rnd(6) + 1
			var p = a + b + c
			return mk_num("Un triangle a pour côtés %d cm, %d cm et %d cm. Quel est son périmètre ?" % [a, b, c], p, 1, 0, "Périmètre = %d + %d + %d = %d cm." % [a, b, c, p])
		return mk_from_pool("Quel solide a toutes ses faces carrées ?", "cube", ["pavé", "sphère", "cylindre", "pyramide"], "Le cube a 6 faces carrées.")
	# CE2
	var mode = pick(["heure_plus", "monnaie_centime", "unite_longueur", "perimetre_poly", "angle_droit", "symetrie", "solide2"])
	if mode == "heure_plus":
		var h = rnd(11) + 1
		var m = pick([0, 5, 10])
		var later = m + 15
		var label = "%d h %02d" % [h, later]
		var opts = ["%d h %02d" % [h, later], "%d h %d" % [h, later + 15], "%d h %d" % [h, later + 30], "%d h %02d" % [h, m + 5]]
		return mk_list("Il est %d h %02d. Quelle heure sera-t-il dans 15 minutes ?" % [h, m], opts, label, "Dans 15 minutes, il sera %s." % label)
	if mode == "monnaie_centime":
		var n = rnd(4) + 1
		var opts = [n * 100, n * 10, n * 1000, n]
		return mk_list("Combien de centimes y a-t-il dans %d € ?" % n, opts, n * 100, "1 € = 100 centimes, donc %d € = %d centimes." % [n, n * 100])
	if mode == "unite_longueur":
		return mk_list("Quelle unité utilise-t-on pour mesurer la longueur d'un crayon ?", ["cm", "km", "L", "kg"], "cm", "On mesure un crayon en centimètres (cm).")
	if mode == "perimetre_poly":
		var n = pick([4, 5, 6])
		var sides = []
		for i in range(n):
			sides.append(rnd(8) + 1)
		var p = 0
		for s in sides:
			p += s
		var parts = sides.map(func(x): return str(x))
		return mk_num("Un polygone a %d côtés qui mesurent %s cm. Quel est son périmètre ?" % [n, " cm, ".join(parts)], p, 1, 0, "Périmètre = %s = %d cm." % [" + ".join(parts), p])
	if mode == "angle_droit":
		var fig = pick([["un carré", 4], ["un rectangle", 4], ["un triangle rectangle", 1]])
		return mk_num("Combien d'angles droits a %s ?" % fig[0], fig[1], 1, 0, "%s a %d angle%s droit%s." % [fig[0], fig[1], "s" if fig[1] > 1 else "", "s" if fig[1] > 1 else ""])
	if mode == "symetrie":
		return mk_from_pool("Quelle lettre a un axe de symétrie vertical ?", "A", ["B", "C", "D", "E", "F", "G", "L", "P"], "La lettre A a un axe de symétrie vertical.")
	return mk_list("Un cube a 6 faces carrées. Vrai ou faux ?", ["Vrai", "Faux"], "Vrai", "Un cube a bien 6 faces carrées.")

# ---------- grammaire ----------

static func grammaire(level: String) -> Dictionary:
	if level == "CP":
		var mode = pick(["son", "syllabe", "pluriel", "genre", "phrase"])
		if mode == "son":
			var sounds = ["ou", "on", "in", "ch", "gn", "ill", "eau", "ph", "oi", "eu", "an"]
			var w = pick([["loup", "ou"], ["bonbon", "on"], ["lapin", "in"], ["chat", "ch"], ["montagne", "gn"], ["fille", "ill"], ["bateau", "eau"], ["photo", "ph"], ["poisson", "oi"], ["heureux", "eu"], ["enfant", "an"]])
			return mk_from_pool("Dans « %s », on entend le son..." % w[0], w[1], sounds, "Dans « %s », on entend le son [%s]." % [w[0], w[1]])
		if mode == "syllabe":
			var w = pick([["chocolat", 3], ["banane", 3], ["matin", 2], ["chat", 1], ["éléphant", 3], ["tortue", 2], ["lapin", 2], ["école", 2], ["maison", 2], ["soleil", 2], ["ordinateur", 4], ["stylo", 2]])
			return mk_num("Combien de syllabes y a-t-il dans « %s » ?" % w[0], w[1], 1, 1, "« %s » a %d syllabes." % [w[0], w[1]])
		if mode == "pluriel":
			var n = pick(["chat", "livre", "table", "fleur", "chien", "école"])
			var correct = "des %ss" % n
			var opts = [correct, "des %s" % n, "les %s" % n, "un %ss" % n]
			return mk_list("Quel est le pluriel de « un %s » ?" % n, opts, correct, "Le pluriel de « un %s » est « %s »." % [n, correct])
		if mode == "genre":
			var n = pick([["table", "féminin"], ["livre", "masculin"], ["chaise", "féminin"], ["arbre", "masculin"], ["fleur", "féminin"], ["chien", "masculin"], ["école", "féminin"], ["homme", "masculin"]])
			var opts = shuf(["masculin", "féminin"])
			return mk("Le nom « %s » est..." % n[0], opts, opts.find(n[1]), "« %s » est %s." % [n[0], n[1]])
		var q = pick(["Une phrase commence toujours par...", "Une phrase se termine toujours par..."])
		if q.find("commence") >= 0:
			var opts = shuf(["une majuscule.", "une minuscule.", "un chiffre.", "un point."])
			return mk(q, opts, opts.find("une majuscule."), "Une phrase commence par une majuscule.")
		var opts = shuf(["un point.", "une virgule.", "une majuscule.", "un chiffre."])
		return mk(q, opts, opts.find("un point."), "Une phrase se termine par un point.")
	if level == "CE1":
		var mode = pick(["nature", "article", "verbe", "adjectif", "accord_gn", "lettre_muette", "phrase2"])
		if mode == "nature":
			var natures = ["nom commun", "nom propre", "article", "verbe", "adjectif", "pronom"]
			var w = pick([["chat", "nom commun"], ["Paris", "nom propre"], ["le", "article"], ["manger", "verbe"], ["grand", "adjectif"], ["Marie", "nom propre"], ["table", "nom commun"], ["dort", "verbe"], ["joli", "adjectif"], ["une", "article"], ["elle", "pronom"], ["nous", "pronom"]])
			return mk_from_pool("Quelle est la nature du mot « %s » ?" % w[0], w[1], natures, "« %s » est un %s." % [w[0], w[1]])
		if mode == "article":
			var n = pick([["fleur", "la"], ["gâteau", "le"], ["livre", "le"], ["école", "la"], ["table", "la"], ["chat", "le"], ["lune", "la"], ["vélo", "le"]])
			return mk_from_pool("Quel article convient devant « %s » ?" % n[0], n[1], ["le", "la", "les", "un", "une", "des"], "On dit « %s %s »." % [n[1], n[0]])
		if mode == "verbe":
			var s = pick([["La maîtresse lit une histoire.", "lit", ["maîtresse", "histoire", "une"]], ["Le chat dort sur le canapé.", "dort", ["chat", "canapé", "le"]], ["Les enfants jouent dans la cour.", "jouent", ["enfants", "cour", "dans"]], ["Papa prépare le repas.", "prépare", ["Papa", "repas", "le"]]])
			return mk_list("Dans « %s », quel mot est le verbe ?" % s[0], [s[1]] + s[2], s[1], "Le verbe est « %s »." % s[1])
		if mode == "adjectif":
			var a = pick([["grand", "grande"], ["petit", "petite"], ["joli", "jolie"], ["beau", "belle"], ["blanc", "blanche"], ["heureux", "heureuse"], ["content", "contente"], ["noir", "noire"]])
			var opts = [a[1], a[0], a[1] + "s", a[0] + "s"]
			return mk_list("Quel est le féminin de « %s » ?" % a[0], opts, a[1], "Le féminin de « %s » est « %s »." % [a[0], a[1]])
		if mode == "accord_gn":
			var n = pick([["fleur", "féminin"], ["chat", "masculin"], ["table", "féminin"], ["livre", "masculin"], ["école", "féminin"], ["chien", "masculin"]])
			var det = "la" if n[1] == "féminin" else "le"
			var bad = "le" if n[1] == "féminin" else "la"
			var correct = "%s %s" % [det, n[0]]
			var opts = [correct, "%s %s" % [bad, n[0]], "les %s" % n[0], "%s %ss" % [det, n[0]]]
			return mk_list("Quel groupe nominal est correct ?", opts, correct, "On écrit « %s »." % correct)
		if mode == "lettre_muette":
			return mk_from_pool("Dans « chat », quelle lettre est muette ?", "t", ["c", "h", "a", "s", "e"], "Dans « chat », le « t » ne s'entend pas.")
		var q = pick(["Une phrase commence toujours par...", "Une phrase se termine toujours par..."])
		if q.find("commence") >= 0:
			var opts = shuf(["une majuscule.", "une minuscule.", "un chiffre.", "une virgule."])
			return mk(q, opts, opts.find("une majuscule."), "Une phrase commence par une majuscule.")
		var opts = shuf(["un point.", "une virgule.", "une majuscule.", "un chiffre."])
		return mk(q, opts, opts.find("un point."), "Une phrase se termine par un point.")
	# CE2
	var mode = pick(["sujet", "pronom", "complement", "homophone", "pluriel", "nasal"])
	if mode == "sujet":
		var s = pick([["Le chat dort.", "Le chat", ["dort", "chat", "Le"]], ["Les enfants jouent dans la cour.", "Les enfants", ["jouent", "cour", "dans"]], ["Papa prépare le repas.", "Papa", ["prépare", "repas", "le"]], ["La maîtresse lit une histoire.", "La maîtresse", ["lit", "histoire", "une"]]])
		return mk_list("Dans « %s », quel est le sujet ?" % s[0], [s[1]] + s[2], s[1], "Le sujet est « %s »." % s[1])
	if mode == "pronom":
		var f = pick([["Il", "est content."], ["Elle", "est contente."], ["Nous", "sommes contents."], ["Vous", "êtes contents."], ["Ils", "jouent au football."], ["Elles", "jouent au football."], ["Je", "mange une pomme."], ["Tu", "manges une pomme."], ["Il", "lit un livre."], ["Nous", "allons à l'école."], ["Ils", "finissent les devoirs."], ["Elle", "prépare le repas."], ["Je", "parle anglais."], ["Vous", "regardez un film."]])
		var pool = ["il", "elle", "nous", "vous", "ils", "elles", "je", "tu"]
		var others = []
		for p in pool:
			if p != str(f[0]).to_lower() and others.find(p) < 0:
				others.append(p)
		var opts = shuf([f[0]] + shuf(others).slice(0, 3))
		return mk("Dans « %s %s », quel est le pronom sujet ?" % [f[0], f[1]], opts, opts.find(f[0]), "Le pronom sujet est « %s »." % f[0])
	if mode == "complement":
		var s = pick([["Le chat attrape une souris.", "une souris", ["Le chat", "attrape", "une"]], ["Léa écrit une lettre.", "une lettre", ["Léa", "écrit", "une"]], ["Papa lave la voiture.", "la voiture", ["Papa", "lave", "la"]]])
		return mk_list("Dans « %s », quel est le complément ?" % s[0], [s[1]] + s[2], s[1], "Le complément est « %s »." % s[1])
	if mode == "homophone":
		var h = pick([["Il ... un vélo. (a / à)", "a"], ["Elle va ... Paris. (a / à)", "à"], ["Le chat ... noir. (et / est)", "est"], ["Papa ... Maman arrivent. (et / est)", "et"], ["Tous les matins, ... part à l'école. (on / ont)", "on"], ["Ils ... gagné. (on / ont)", "ont"]])
		var pair = ["a", "à"] if h[0].find("(a / à)") >= 0 else (["et", "est"] if h[0].find("(et / est)") >= 0 else ["on", "ont"])
		var opts = shuf(pair)
		return mk(h[0], opts, opts.find(h[1]), "Le bon mot est « %s »." % h[1])
	if mode == "pluriel":
		var p = pick([["cheval", "chevaux", ["chevals", "chevaus", "cheveaux"]], ["journal", "journaux", ["journals", "journaus", "journeaux"]], ["bijou", "bijoux", ["bijous", "bijouxs", "bijou"]], ["genou", "genoux", ["genous", "genouxs", "genou"]], ["hibou", "hiboux", ["hibous", "hibouxs", "hibou"]], ["chou", "choux", ["chous", "chouxs", "chou"]], ["trou", "trous", ["troux", "trouss", "trou"]], ["clou", "clous", ["cloux", "clouss", "clou"]]])
		var opts = shuf([p[1]] + p[2])
		return mk("Quel est le pluriel de « un %s » ?" % p[0], opts, opts.find(p[1]), "Le pluriel de « un %s » est « %s »." % [p[0], p[1]])
	var opts = shuf(["m", "b"])
	return mk("Je ... son tambour. (m / b)", opts, opts.find("m"), "On écrit « m » devant « b » : je mets.")

# ---------- conjugaison ----------

static func conjugaison(level: String) -> Dictionary:
	var t = {
		"être": {"present": ["suis", "es", "est", "sommes", "êtes", "sont"], "imparfait": ["étais", "étais", "était", "étions", "étiez", "étaient"], "futur": ["serai", "seras", "sera", "serons", "serez", "seront"]},
		"avoir": {"present": ["ai", "as", "a", "avons", "avez", "ont"], "imparfait": ["avais", "avais", "avait", "avions", "aviez", "avaient"], "futur": ["aurai", "auras", "aura", "aurons", "aurez", "auront"]},
		"chanter": {"present": ["chante", "chantes", "chante", "chantons", "chantez", "chantent"], "imparfait": ["chantais", "chantais", "chantait", "chantions", "chantiez", "chantaient"], "futur": ["chanterai", "chanteras", "chantera", "chanterons", "chanterez", "chanteront"]},
		"jouer": {"present": ["joue", "joues", "joue", "jouons", "jouez", "jouent"], "imparfait": ["jouais", "jouais", "jouait", "jouions", "jouiez", "jouaient"], "futur": ["jouerai", "joueras", "jouera", "jouerons", "jouerez", "joueront"]},
		"manger": {"present": ["mange", "manges", "mange", "mangeons", "mangez", "mangent"], "futur": ["mangerai", "mangeras", "mangera", "mangerons", "mangerez", "mangeront"]},
		"finir": {"present": ["finis", "finis", "finit", "finissons", "finissez", "finissent"], "imparfait": ["finissais", "finissais", "finissait", "finissions", "finissiez", "finissaient"], "futur": ["finirai", "finiras", "finira", "finirons", "finirez", "finiront"]},
		"aller": {"present": ["vais", "vas", "va", "allons", "allez", "vont"]},
		"faire": {"present": ["fais", "fais", "fait", "faisons", "faites", "font"]},
		"dire": {"present": ["dis", "dis", "dit", "disons", "dites", "disent"]},
		"venir": {"present": ["viens", "viens", "vient", "venons", "venez", "viennent"]},
		"pouvoir": {"present": ["peux", "peux", "peut", "pouvons", "pouvez", "peuvent"]},
		"voir": {"present": ["vois", "vois", "voit", "voyons", "voyez", "voient"]},
		"vouloir": {"present": ["veux", "veux", "veut", "voulons", "voulez", "veulent"]},
		"prendre": {"present": ["prends", "prends", "prend", "prenons", "prenez", "prennent"]}
	}
	if level == "CP":
		var verb = pick(["être", "avoir", "chanter"])
		var tense = pick(["present", "futur"])
		return _ask(t, verb, tense)
	if level == "CE1":
		var mode = pick(["present", "present", "imparfait", "futur"])
		if mode == "present":
			return _ask(t, pick(["chanter", "jouer", "manger", "finir"]), "present")
		if mode == "imparfait":
			return _ask(t, pick(["être", "avoir", "chanter"]), "imparfait")
		return _ask(t, pick(["chanter", "jouer", "finir"]), "futur")
	var mode = pick(["present", "present", "imparfait", "futur", "irregulier", "irregulier"])
	if mode == "present":
		return _ask(t, pick(["chanter", "jouer", "manger", "finir"]), "present")
	if mode == "imparfait":
		return _ask(t, pick(["chanter", "jouer", "être", "avoir"]), "imparfait")
	if mode == "futur":
		return _ask(t, pick(["chanter", "jouer", "finir", "être", "avoir"]), "futur")
	return _ask(t, pick(["aller", "faire", "dire", "venir", "pouvoir", "voir", "vouloir", "prendre"]), "present")

static func _ask(t: Dictionary, verb: String, tense: String) -> Dictionary:
	var label = "au présent" if tense == "present" else ("à l'imparfait" if tense == "imparfait" else "au futur")
	return conj_q(verb, t[verb][tense], label)

# ---------- sciences ----------

static func sciences(level: String) -> Dictionary:
	if level == "CP":
		var mode = pick(["vivant", "corps", "matiere", "eau", "animaux"])
		if mode == "vivant":
			var v = pick([["Le chien", true], ["L'arbre", true], ["La pierre", false], ["La voiture", false], ["La fleur", true], ["Le vélo", false]])
			var opts = shuf(["Oui", "Non"])
			return mk("Est-ce un être vivant : %s ?" % str(v[0]).to_lower(), opts, opts.find("Oui" if v[1] else "Non"), "%s est %s." % [v[0], "un être vivant" if v[1] else "un objet non vivant"])
		if mode == "corps":
			var c = pick([["Les yeux servent à", "voir"], ["Les oreilles servent à", "entendre"], ["Le nez sert à", "sentir"], ["Les jambes servent à", "marcher"], ["La bouche sert à", "manger"]])
			return mk_from_pool("%s..." % c[0], c[1], ["voir", "entendre", "sentir", "marcher", "manger", "toucher"], "%s %s." % [c[0], c[1]])
		if mode == "matiere":
			var m = pick([["Le bois est", "solide"], ["L'eau est", "liquide"], ["L'air est", "gazeux"]])
			var uniq = []
			for v in [m[1], "solide", "liquide", "gazeux"]:
				if uniq.find(v) < 0:
					uniq.append(v)
			var opts = shuf(uniq)
			return mk("%s..." % m[0], opts, opts.find(m[1]), "%s %s." % [m[0], m[1]])
		if mode == "eau":
			return mk_from_pool("Quand l'eau chauffe, elle...", "devient de la vapeur", ["devient de la vapeur", "devient de la glace", "reste liquide", "devient du sable"], "L'eau chaude se transforme en vapeur.")
		var a = pick([["Le lion", "dans la savane"], ["Le poisson", "dans l'eau"], ["L'aigle", "dans les airs"], ["La grenouille", "près de l'eau"]])
		return mk_from_pool("Où vit %s ?" % str(a[0]).to_lower(), a[1], ["dans la savane", "dans l'eau", "dans les airs", "près de l'eau", "dans le désert"], "%s %s." % [a[0], a[1]])
	if level == "CE1":
		var mode = pick(["vegetal", "animal", "corps", "matiere", "eau", "saison"])
		if mode == "vegetal":
			var v = pick([["La racine sert à", "absorber l'eau"], ["La feuille sert à", "fabriquer la nourriture"], ["La fleur sert à", "attirer les insectes"], ["La tige sert à", "transporter l'eau"]])
			return mk_from_pool("%s..." % v[0], v[1], ["absorber l'eau", "fabriquer la nourriture", "attirer les insectes", "transporter l'eau"], "%s %s." % [v[0], v[1]])
		if mode == "animal":
			var a = pick([["Le lion est un", "mammifère"], ["La pie est un", "oiseau"], ["Le requin est un", "poisson"], ["La grenouille est un", "amphibien"], ["Le serpent est un", "reptile"]])
			return mk_from_pool("%s..." % a[0], a[1], ["mammifère", "oiseau", "poisson", "amphibien", "reptile", "insecte"], "%s %s." % [a[0], a[1]])
		if mode == "corps":
			var c = pick([["Le cœur", "fait circuler le sang"], ["Les poumons", "permettent de respirer"], ["Le cerveau", "commande le corps"], ["L'estomac", "digère les aliments"]])
			return mk_from_pool("%s..." % c[0], c[1], ["fait circuler le sang", "permet de respirer", "commande le corps", "digère les aliments", "protège le corps"], "%s %s." % [c[0], c[1]])
		if mode == "matiere":
			var m = pick([["plastique", "isolant"], ["cuivre", "conducteur"], ["fer", "conducteur"], ["verre", "isolant"]])
			return mk_from_pool("Le %s est un..." % m[0], m[1], ["isolant", "conducteur", "aimant", "liquide"], "Le %s est un %s." % [m[0], m[1]])
		if mode == "eau":
			var q = pick([["L'eau qui gèle", "devient solide"], ["L'eau qui bout", "devient de la vapeur"]])
			return mk_from_pool("%s..." % q[0], q[1], ["devient solide", "devient de la vapeur", "reste liquide", "devient du sable"], "%s %s." % [q[0], q[1]])
		var s = pick([["En hiver, il fait", "froid"], ["En été, il fait", "chaud"], ["En automne, il fait", "doux"]])
		return mk_from_pool("%s..." % s[0], s[1], ["froid", "chaud", "doux", "très chaud"], "%s %s." % [s[0], s[1]])
	# CE2
	var mode = pick(["planetes", "etoiles", "corps", "matiere", "eau", "energie", "sexe"])
	if mode == "planetes":
		var p = pick([["La Terre tourne autour", "du Soleil"], ["La Lune tourne autour", "de la Terre"], ["Le Soleil est", "une étoile"]])
		return mk_from_pool("%s..." % p[0], p[1], ["du Soleil", "de la Terre", "de Mars", "une étoile", "une planète", "un satellite"], "%s %s." % [p[0], p[1]])
	if mode == "etoiles":
		return mk_from_pool("Le Soleil est...", "une étoile", ["une étoile", "une planète", "un satellite", "une comète"], "Le Soleil est une étoile.")
	if mode == "corps":
		var c = pick([["Le cœur", "pompe le sang"], ["Les poumons", "assurent la respiration"], ["Le cerveau", "commande le corps"], ["L'estomac", "digère les aliments"], ["La peau", "protège le corps"]])
		return mk_from_pool("%s..." % c[0], c[1], ["pompe le sang", "assure la respiration", "commande le corps", "digère les aliments", "protège le corps"], "%s %s." % [c[0], c[1]])
	if mode == "matiere":
		return mk_from_pool("Quel matériau conduit l'électricité ?", "le cuivre", ["le cuivre", "le plastique", "le bois", "le verre"], "Le cuivre conduit l'électricité.")
	if mode == "eau":
		var e = pick([["L'eau qui s'évapore devient", "de la vapeur d'eau"], ["La vapeur qui se condense forme", "des nuages"], ["La pluie qui tombe, c'est", "la précipitation"], ["La glace qui fond devient", "de l'eau liquide"]])
		return mk_from_pool("%s..." % e[0], e[1], ["de la vapeur d'eau", "des nuages", "la précipitation", "de l'eau liquide", "de la glace"], "%s %s." % [e[0], e[1]])
	if mode == "energie":
		var e = pick([["L'énergie du soleil", "renouvelable"], ["L'énergie du vent", "renouvelable"], ["L'énergie de l'eau", "renouvelable"], ["L'énergie du pétrole", "non renouvelable"], ["L'énergie du charbon", "non renouvelable"]])
		var opts = shuf(["renouvelable", "non renouvelable"])
		return mk("%s est..." % e[0], opts, opts.find(e[1]), "%s est %s." % [e[0], e[1]])
	var s = pick([["Le coq", "un mâle"], ["La poule", "une femelle"], ["Le lion", "un mâle"], ["La lionne", "une femelle"], ["Le taureau", "un mâle"], ["La vache", "une femelle"]])
	var opts = shuf(["un mâle", "une femelle"])
	return mk("%s est..." % s[0], opts, opts.find(s[1]), "%s est %s." % [s[0], s[1]])

# ---------- anglais ----------

static func anglais(level: String) -> Dictionary:
	if level == "CP":
		var mode = pick(["couleurs", "chiffres", "animaux1", "famille", "corps1"])
		if mode == "couleurs":
			return mk_from_pool("What colour is the sun?", "yellow", ["red", "blue", "green", "orange", "purple", "pink", "black", "white"], "The sun is yellow.")
		if mode == "chiffres":
			var n = pick([3, 5, 7, 9])
			return mk_from_pool("What number comes after %d?" % n, str(n + 1), [str(n), str(n + 2), str(n + 3), str(n - 1)], "%d." % (n + 1))
		if mode == "animaux1":
			return mk_from_pool("Which animal says \"meow\"?", "cat", ["dog", "bird", "fish", "rabbit", "cow", "pig", "sheep"], "A cat says meow.")
		if mode == "famille":
			return mk_from_pool("She looks after you. She is your...", "mother", ["father", "sister", "brother", "grandma", "grandpa", "baby"], "She is your mother.")
		return mk_from_pool("You use it to see. It is your...", "eye", ["ear", "nose", "mouth", "hand", "foot", "head"], "You see with your eye.")
	if level == "CE1":
		var mode = pick(["saluer", "compter", "animaux2", "corps2", "famille2", "manger"])
		if mode == "saluer":
			return mk_from_pool("When you meet a friend in the morning, you say...", "Hello", ["Goodbye", "Please", "Thank you", "Sorry", "See you", "Good night"], "You say hello.")
		if mode == "compter":
			var n = pick([12, 15, 18, 20])
			return mk_from_pool("What number comes after %d?" % n, str(n + 1), [str(n), str(n + 2), str(n + 3), str(n - 1)], "%d." % (n + 1))
		if mode == "animaux2":
			return mk_from_pool("It gives us milk. It is a...", "cow", ["duck", "horse", "sheep", "goat", "chicken", "pig"], "A cow gives us milk.")
		if mode == "corps2":
			return mk_from_pool("It is between your arm and your hand. It is the...", "elbow", ["shoulder", "knee", "toe", "wrist", "ankle", "finger"], "It is the elbow.")
		if mode == "famille2":
			return mk_from_pool("Your father's brother is your...", "uncle", ["aunt", "cousin", "nephew", "niece", "sister", "brother"], "He is your uncle.")
		return mk_from_pool("Je mange une pomme = ...", "I eat an apple", ["I have a cat", "I play with a ball", "I drink water", "I read a book"], "I eat an apple.")
	var mode = pick(["sentiments", "meteo", "aliments", "vetements", "corps3", "routines"])
	if mode == "sentiments":
		return mk_from_pool("I want to drink. I am...", "thirsty", ["happy", "sad", "hungry", "tired", "surprised", "scared", "angry", "cold", "hot"], "I am thirsty.")
	if mode == "meteo":
		return mk_from_pool("Il neige. = ...", "It is snowy", ["It is sunny", "It is rainy", "It is cloudy", "It is windy", "It is foggy", "It is hot"], "It is snowy.")
	if mode == "aliments":
		return mk_from_pool("A banana is a...", "fruit", ["vegetable", "drink", "meat", "cake", "bread", "cheese"], "A banana is a fruit.")
	if mode == "vetements":
		return mk_from_pool("You wear them on your feet. They are...", "shoes", ["gloves", "a hat", "a scarf", "socks", "a coat", "glasses"], "They are shoes.")
	if mode == "corps3":
		return mk_from_pool("It pumps blood around your body. It is the...", "heart", ["lungs", "brain", "stomach", "skin", "liver", "kidney"], "It is the heart.")
	return mk_from_pool("I ... at seven in the morning.", "wake up", ["go to bed", "have dinner", "go to school", "do my homework", "watch TV"], "I wake up at seven.")

# ---------- logique ----------

static func logique(level: String) -> Dictionary:
	if level == "CP":
		var mode = pick(["suite1", "suite2", "addition", "intrus", "regarde"])
		if mode == "suite1":
			var a = rnd(8) + 1
			return mk_from_pool("Quel nombre continue : %d, %d, ... ?" % [a, a + 1], a + 2, [a + 3, a + 4, a + 5, max(a - 1, 0)], "%d." % (a + 2))
		if mode == "suite2":
			var a = (rnd(5) + 1) * 10
			return mk_from_pool("Quel nombre continue : %d, %d, ... ?" % [a, a + 10], a + 20, [a + 30, a + 40, a - 10, a + 1], "%d." % (a + 20))
		if mode == "addition":
			var a = rnd(9) + 1
			var b = rnd(9) + 1
			return mk_from_pool("Combien font %d + %d ?" % [a, b], a + b, [a + b + 1, max(a + b - 1, 0), a + b + 2, a + b + 10], "%d + %d = %d." % [a, b, a + b])
		if mode == "intrus":
			var s = pick([["chat", "chien", "lion", "table"], ["pomme", "poire", "fraise", "chaise"], ["rouge", "bleu", "vert", "lundi"]])
			return mk_from_pool("Quel mot n'est pas de la même famille ?", s[3], [s[0], s[1], s[2]], "%s ne va pas avec les autres." % s[3])
		var s = pick([["un chat", "un chien", "un lapin", "un oiseau"], ["une pomme", "une poire", "une fraise", "une banane"], ["rouge", "bleu", "vert", "jaune"]])
		return mk_from_pool("Lequel continue la série ?", s[3], [s[0], s[1], s[2]], "%s continue la série." % s[3])
	if level == "CE1":
		var mode = pick(["suite3", "suiten", "syllabes", "intrus", "jour"])
		if mode == "suite3":
			var a = rnd(100) + 10
			return mk_from_pool("Quel nombre continue : %d, %d, ... ?" % [a, a + 1], a + 2, [a + 3, a + 4, a - 1, a + 5], "%d." % (a + 2))
		if mode == "suiten":
			var a = rnd(40) + 15
			return mk_from_pool("Quel nombre continue : %d, %d, %d, ... ?" % [a, a - 1, a - 2], a - 3, [a - 4, a - 5, a + 1, a - 6], "%d." % (a - 3))
		if mode == "syllabes":
			var p = pick([["chocolat", 3], ["éléphant", 3], ["camion", 2], ["garçon", 2], ["poubelle", 2], ["banane", 3], ["école", 2], ["maison", 2]])
			return mk_from_pool("Combien de syllabes dans \"%s\" ?" % p[0], p[1], [p[1] + 1, max(p[1] - 1, 0), p[1] + 2, p[1] + 3], "%s a %d syllabes." % [p[0], p[1]])
		if mode == "intrus":
			var s = pick([["lundi", "mardi", "mercredi", "janvier"], ["un", "une", "des", "et"], ["chien", "chat", "lapin", "carotte"]])
			return mk_from_pool("Quel mot n'est pas de la même famille ?", s[3], [s[0], s[1], s[2]], "%s ne va pas avec les autres." % s[3])
		var k = pick(["jour1", "jour2", "jour3"])
		if k == "jour1":
			return mk_from_pool("Le premier jour de la semaine est...", "lundi", ["mardi", "mercredi", "dimanche", "samedi"], "La semaine commence le lundi.")
		if k == "jour2":
			return mk_from_pool("Noël est en...", "décembre", ["novembre", "janvier", "octobre", "juin"], "Noël est en décembre.")
		return mk_from_pool("Le dernier jour de la semaine est...", "dimanche", ["lundi", "samedi", "vendredi", "mardi"], "La semaine finit le dimanche.")
	# CE2
	var mode = pick(["double", "moitie", "intrus", "vraifaux", "chrono"])
	if mode == "double":
		var a = rnd(100) + 50
		return mk_from_pool("Quel est le double de %d ?" % a, a * 2, [a * 2 + 1, max(a * 2 - 1, 0), a * 2 + 2, a * 2 + 10], "Le double de %d est %d." % [a, a * 2])
	if mode == "moitie":
		var n = pick([8, 10, 12, 16, 20, 24])
		return mk_from_pool("Quelle est la moitié de %d ?" % n, n / 2, [n / 2 + 1, max(n / 2 - 1, 0), n / 2 + 2, n / 2 + 3], "La moitié de %d est %d." % [n, n / 2])
	if mode == "intrus":
		var s = pick([["cube", "pavé", "pyramide", "cercle"], ["mètre", "litre", "gramme", "kilomètre"], ["nager", "courir", "sauter", "lire"]])
		return mk_from_pool("Quel mot n'est pas de la même famille ?", s[3], [s[0], s[1], s[2]], "%s ne va pas avec les autres." % s[3])
	if mode == "vraifaux":
		var q = pick([["Le cheval a 4 pattes.", "Vrai"], ["Le soleil est une planète.", "Faux"], ["Les oiseaux ont des poils.", "Faux"], ["La neige est froide.", "Vrai"]])
		var opts = ["Vrai", "Faux"]
		return mk(q[0] + " Vrai ou faux ?", opts, opts.find(q[1]), q[0] + " " + q[1] + ".")
	var q = pick([["Le matin, on prend le petit-déjeuner. Le midi, on prend le...", "déjeuner", ["dîner", "goûter", "petit-déjeuner"]], ["On va au lit le...", "soir", ["matin", "midi", "après-midi"]], ["On mange la soupe avec...", "une cuillère", ["une fourchette", "un couteau", "les doigts"]]])
	return mk_from_pool(q[0], q[1], q[2], "%s." % q[1])

# ---------- dispatch ----------

static func question(theme: String, level: String) -> Dictionary:
	match theme:
		"nombres": return nombres(level)
		"mesures": return mesures(level)
		"grammaire": return grammaire(level)
		"conjugaison": return conjugaison(level)
		"sciences": return sciences(level)
		"anglais": return anglais(level)
		"logique": return logique(level)
	return mk("Combien font 2 + 2 ?", ["4", "3", "5", "6"], 0, "2 + 2 = 4.")
