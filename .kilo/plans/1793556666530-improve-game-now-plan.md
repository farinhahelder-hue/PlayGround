# Plan: Improve Banquise En Folie (arena + quiz)

## Goal
Improve gameplay polish, balance, and UX without breaking existing tests.

## Context
- Godot 4.7 project at `godot/`, web at `index.html`.
- Quiz: 7 themes x 3 levels, 5 questions/turn, solo/nonstop/duo.
- Arena: WASD move, type answer, click targets/hazards, 3 hearts, combo, 25s timer, 7 weapons.
- Tests: gen_test (8400 questions), play_test pass.

## Proposed improvements
1. Arena balance
   - Reduce hazard chase speed to 1.8-2.6.
   - Increase spawn interval to 9s; cap hazards at 4.
   - Add 2s grace after question start.

2. Weapon feedback
   - Visible gun mesh attached to player.
   - Distinct muzzle flash per weapon type.
   - Hit marker UI with damage numbers.

3. Enemy variety
   - Add 2 enemy types: follower (10 pts) and roamer (20 pts).
   - Different colors/speeds.

4. UI/UX
   - Show weapon description on switch.
   - Show best score on game-over screen.
   - Add instructions overlay on first arena entry.

5. Validation
   - Run gen_test, play_test, rebuild exe, push source (no exe).

## Risks
- Arena changes must not break quiz tests.
- Keep changes minimal and reversible.

## Open questions
- Preferred difficulty curve?
- Should high scores be per-level or global?
