# Banquise En Folie — portage Godot 4

Portage jouable du jeu web (`../index.html`) sous Godot 4.7. Tout est construit par code :
aucune ressource externe, aucun asset à importer.

## Lancer

```bash
# éditeur
"F:/Godot/Godot_v4.7.2-stable_win64.exe" --path godot

# partie directe
"F:/Godot/Godot_v4.7.2-stable_win64.exe" --path godot --quit-after 0
```

Le projet s'ouvre aussi depuis le gestionnaire de projets Godot (`godot/project.godot`).

## Contenu

- 7 thèmes × 3 niveaux (CP, CE1, CE2), générés proceduralement, sans banque de questions figée.
- Manche de 5 questions, écran de résultats, retour au menu.
- Modes : solo, sans fin, duo (les deux joueurs alternent à chaque manche).
- Trois personnages 3D basse-poly (Émilie, Night Squirrel, Monica) avec animation d'attente.
- Voix française (TTS système) sur les questions et au changement de personnage, bips WebAudio
  remplacés par des sons générés en PCM.
- Sauvegarde `user://banquise.cfg` : niveau, personnage, scores duo.

## Structure

```
project.godot          configuration (1280×720, rendu Compatibility)
main.tscn              scène racine, script main.gd
scripts/generators.gd  7 générateurs + helpers anti-doublons
scripts/main.gd        monde 3D, interface, boucle de jeu, audio, sauvegarde
tests/gen_test.gd      banc des générateurs (8 400 questions)
tests/play_test.gd     test headless de la boucle (solo, sans fin, duo)
```

## Tests

```bash
"F:/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --script res://tests/gen_test.gd
"F:/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --script res://tests/play_test.gd
```

Attendu : `ERREURS 0 / 8400 | DOUBLONS 0` et `PLAYTEST OK`.

## Captures de contrôle

```bash
"F:/Godot/Godot_v4.7.2-stable_win64_console.exe" --path godot -- --capture
```

Écrit `capture_menu.png`, `capture_play.png`, `capture_answer.png` et `capture_results.png`
à la racine du projet, puis quitte. Le TTS est désactivé pendant la capture.

## Écarts assumés avec la version web

- Les costumes de la garde-robe ne sont pas portés : seuls les trois personnages et leurs
  couleurs sont repris.
- Le décor est simplifié (banquise, eau, blocs de glace, étoiles) ; le toboggan et la garde-robe
  de la version three.js ne sont pas reproduits.
- Le duo alterne les manches comme sur le web, mais sans les scores persistants par joueur au-delà
  de la session de jeu.
