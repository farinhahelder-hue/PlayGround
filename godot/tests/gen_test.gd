extends SceneTree

const Gen = preload("res://scripts/generators.gd")

func _initialize() -> void:
	seed(1234567)
	var themes = ["nombres", "mesures", "grammaire", "conjugaison", "sciences", "anglais", "logique"]
	var levels = ["CP", "CE1", "CE2"]
	var bad = 0
	var dup = 0
	var total = 0
	var per = {}
	var samples = []
	for level in levels:
		for theme in themes:
			for i in range(400):
				var r = Gen.question(theme, level)
				total += 1
				var problems = []
				var q = str(r.get("q", ""))
				var opts = r.get("opts", [])
				var ans = r.get("ans", -1)
				var expl = str(r.get("expl", ""))
				if q.strip_edges() == "":
					problems.append("question vide")
				if q.find("${") >= 0:
					problems.append("dollar litteral")
				if q.find("null") >= 0 or q.find("NaN") >= 0:
					problems.append("question invalide")
				if opts.size() < 2:
					problems.append("moins de 2 options")
				var strs = []
				for o in opts:
					var s = str(o)
					strs.append(s)
					if s.strip_edges() == "" or s.find("${") >= 0 or s.find("null") >= 0 or s.find("NaN") >= 0:
						problems.append("option invalide")
				if typeof(ans) != TYPE_INT or ans < 0 or ans >= opts.size():
					problems.append("index invalide")
				if expl.strip_edges() == "":
					problems.append("explication vide")
				if expl.find("${") >= 0 or expl.find("null") >= 0 or expl.find("NaN") >= 0:
					problems.append("explication invalide")
				if _unique_count(strs) != strs.size():
					dup += 1
					problems.append("doublon")
				if problems.size() > 0:
					bad += 1
					var key = level + "/" + theme
					per[key] = per.get(key, 0) + 1
					if samples.size() < 25:
						samples.append("%s/%s :: %s :: %s :: %s" % [level, theme, "|".join(problems), q, " / ".join(strs)])
	print("ERREURS ", bad, " / ", total, " | DOUBLONS ", dup)
	print(per)
	for s in samples:
		print(s)
	quit(1 if bad > 0 else 0)

func _unique_count(strs: Array) -> int:
	var seen = {}
	for s in strs:
		seen[s] = true
	return seen.size()
