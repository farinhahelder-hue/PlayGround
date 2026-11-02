# Banquise En Folie — portage Godot 4

Portage jouable du jeu web (`../index.html`) sous Godot 4.7, enrichi d'un mode action.
Tout est construit par code : aucune ressource externe, aucun asset à importer.

## Lancer

```bash
# éditeur
"F:/Godot/Godot_v4.7.2-stable_win64.exe" --path godot

# partie directe
"F:/Godot/Godot_v4.7.2-stable_win64.exe" --path godot --quit-after 0

# version compilée
build/banquise.exe
```

Le projet s'ouvre aussi depuis le gestionnaire de projets Godot (`godot/project.godot`).

Modes directs (utile pour tester sans passer par le menu) :

```bash
build/banquise.exe -- --arene       # démarre dans l'Arène
build/banquise.exe -- --toboggan    # démarre sur la piste de Toboggan
build/banquise.exe -- --quake2      # démarre dans Quake 2
```

## Contenu

### Mode quiz

- 7 thèmes × 3 niveaux (CP, CE1, CE2), générés procéduralement, sans banque de questions figée.
- Manche de 5 questions, écran de résultats, retour au menu.
- Modes : solo, sans fin, duo (les deux joueurs alternent à chaque manche).
- Trois personnages 3D basse-poly (Émilie, Night Squirrel, Monica) avec animation d'attente.
- Voix française (TTS système) sur les questions et au changement de personnage, bips WebAudio
  remplacés par des sons générés en PCM.
- Sauvegarde `user://banquise.cfg` : niveau, personnage, scores duo.

### Mode Arène (action)

Bouton **Arène** du menu. On se déplace sur la banquise, on lit la question, puis on tire sur la
bonne cible en glace — ou on écrit la réponse pour un tir guidé.

- **Déplacement** : ZQSD / flèches, `Maj` pour sprinter.
- **Viser / tirer** : souris + clic gauche, ou `Espace`.
- **Écrire** : `T` ou `Tab`, taper la réponse, `Entrée` = tir dirigé (bonus de points).
- **Armes** : `1` à `6` ou molette. Six armes, du plus simple au plus puissant :
  Arc Givré, Pistolet Polaire, Fusil à Pompe Blizzard, Mitrailleuse Tempête,
  Fusil Sniper Arctique, Lance-Roquettes Cryo. Chaque bonne réponse fait progresser
  l'arsenal (Gun Game).
- **Vue** : `V` bascule 3e personne / FPS.
- **Vies** : 3 cœurs. Mauvaise réponse, temps écoulé ou bourrasque de neige = 1 cœur.
- **Score** : points par bonne réponse × série (combo), record sauvegardé dans
  `user://banquise_action.cfg`.
- **Bourrasques** : des blocs de neige piquants approchent ; on les esquive ou on les
  détruit au tir (elles rapportent des points et font monter l'arme).
- `Échap` : quitte l'arène (en FPS, un premier `Échap` libère la souris).

### Mode Toboggan

Bouton **Toboggan** du menu. La luge descend toute seule une piste de glace à quatre couloirs ;
il faut traverser la bonne porte-réponse, ou la détruire au tir, tout en évitant les blocs de glace.

- **Diriger** : `Q`/`D` (ou `A`/`D`, ou flèches gauche/droite). Direction continue, sans
  verrouillage de couloir.
- **Tirer** : clic gauche ou `Espace` sur un bloc de glace pour le détruire, ou sur une porte
  pour répondre. Les touches `1` à `4` tirent directement sur la porte correspondante.
- **Écrire** : `T` ou `Tab`, taper la réponse, `Entrée` = tir guidé (bonus de points).
- **Portes-réponses** : chaque porte affiche un grand numéro ; le texte complet des options
  reste affiché dans le bandeau du HUD. La couleur du couloir est rappelée par le cadre lumineux
  de la porte.
- **Vies** : 3 cœurs. Une mauvaise porte, une mauvaise réponse écrite ou un bloc percuté
  coûte 1 cœur ; manquer toutes les portes ne coûte rien mais casse la série.
- **Score** : points × série (combo), bonus pour les tirs et les réponses écrites. La vitesse
  augmente à chaque bonne réponse (de 8 à 15 unités). Record sauvegardé dans
  `user://banquise_toboggan.cfg`.
- **Blocs de glace** : ils apparaissent devant la luge et défilent plus vite que la piste ;
  on les esquive ou on les détruit au tir (points + compteur).
- `Échap` : quitte la descente et revient au menu.

### Mode Quake 2 (survie en arène)

Bouton **Quake 2** du menu, ou lancement direct avec `-- --quake2`. Une arène de survie
infinie avec des vagues d'ennemis qui poursuivent le joueur.

- **Déplacement** : `WASD`.
- **Tirer** : maintenir le clic gauche ; les projectiles visent l'ennemi le plus proche.
- **Santé** : les ennemis infligent des dégâts au contact ; chaque nouvelle vague restaure un peu de santé.
- **Score** : points par ennemi éliminé et bonus de vague.
- `Échap` : quitte le mode et revient au menu.

## Structure

```
project.godot          configuration (1280×720, rendu Compatibility)
main.tscn              scène racine, script main.gd
scripts/generators.gd  7 générateurs + helpers anti-doublons
scripts/main.gd        monde 3D, interface, boucle de jeu, audio, sauvegarde
scripts/action.gd      mode Arène : déplacement, cibles, armes, bourrasques, HUD
scripts/toboggan.gd    mode Toboggan : piste, portes-réponses, tirs, blocs, vies, record
tests/gen_test.gd      banc des générateurs (8 400 questions)
tests/play_test.gd     test headless de la boucle quiz (solo, sans fin, duo)
tests/action_test.gd   test headless de l'arène (tir, écriture, armes, dégâts, fin)
tests/fps_arsenal_test.gd test headless FPS + arsenal Gun Game (6 armes)
tests/toboggan_test.gd test headless du Toboggan (descente, portes, tirs, blocs, vies, fin)
tests/capture_arena.gd captures de contrôle du mode Arène
tests/capture_toboggan.gd captures de contrôle du mode Toboggan
```

## Tests

```bash
"F:/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --script res://tests/gen_test.gd
"F:/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --script res://tests/play_test.gd
"F:/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --script res://tests/action_test.gd
"F:/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --script res://tests/fps_arsenal_test.gd
"F:/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --script res://tests/toboggan_test.gd
```

Attendu : `ERREURS 0 / 8400 | DOUBLONS 0`, `PLAYTEST OK`, `ARENE OK`,
`FPS & ARSENAL GUN GAME OK`, `TOBOGGAN OK`.
Les tests Arène, FPS/arsenal et Toboggan utilisent une sauvegarde temporaire et ne touchent pas
aux records du joueur.

## Captures de contrôle

```bash
# quiz
"F:/Godot/Godot_v4.7.2-stable_win64_console.exe" --path godot -- --capture

# arène
"F:/Godot/Godot_v4.7.2-stable_win64_console.exe" --path godot --script res://tests/capture_arena.gd

# toboggan
"F:/Godot/Godot_v4.7.2-stable_win64_console.exe" --path godot --script res://tests/capture_toboggan.gd
```

Écrit `capture_menu.png`, `capture_play.png`, `capture_answer.png`, `capture_results.png`,
puis `capture_arena.png`, `capture_arena_hazard.png`, `capture_arena_fps.png`,
`capture_arena_hit.png` et `capture_arena_over.png`, puis `capture_toboggan.png`,
`capture_toboggan_obstacles.png`, `capture_toboggan_hit.png` et
`capture_toboggan_over.png` à la racine du projet.
Le TTS est désactivé pendant les captures.

## Export

```bash
"F:/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path godot \
  --export-release "Windows Desktop" build/banquise.exe
```

## Écarts assumés avec la version web

- Les costumes de la garde-robe ne sont pas portés : seuls les trois personnages et leurs
  couleurs sont repris.
- Le décor est simplifié (banquise, eau, blocs de glace, étoiles).
- Le duo alterne les manches comme sur le web, mais sans les scores persistants par joueur au-delà
  de la session de jeu.
- L'Arène et le Toboggan sont des ajouts propres au portage Godot (absents de la version web).
