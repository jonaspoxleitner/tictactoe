# tictactoe

A command-line tic-tac-toe game written in Dart. You play against an AI that
picks a random empty cell. You choose X or O, X always moves first, and empty
cells are labelled with their number so you can pick a move by number.

```
Tic-tac-toe vs. a random AI. X goes first.
[X] X (goes first) / [O] O / [Q] Quit
Play as: X

 1 | 2 | 3
---+---+---
 4 | 5 | 6
---+---+---
 7 | 8 | 9

Your move — available: 1, 2, 3, 4, 5, 6, 7, 8, 9 / [Q] Quit
Cell: 5
```

## Requirements

- [Dart SDK](https://dart.dev/get-dart) `^3.12.2`
- [fvm](https://fvm.app) — the SDK version is pinned in `.fvmrc`, and the
  commands below use `fvm dart`

## Setup

```sh
fvm install   # installs the pinned SDK
fvm dart pub get
```

## Run

```sh
fvm dart run bin/tictactoe.dart
```

`make run` and `fvm dart run` (without arguments) start the same program.

## How to play

1. **Choose your symbol.** `X` goes first and moves before the AI; `O` lets the
   AI open the game. The AI always plays the opposite symbol.
2. **Pick a cell by number** when prompted. The board uses this layout, and
   empty cells keep showing their number:

   ```
    1 | 2 | 3
   ---+---+---
    4 | 5 | 6
   ---+---+---
    7 | 8 | 9
   ```

3. **Win or draw.** The first player to fill a row, a column, or a diagonal with
   their own symbol wins. A full board with no winner is a draw.
4. **Restart or quit.** After every finished game you are asked
   `[R] Restart / [Q] Quit`. `R` returns to symbol selection for a new game.

Every prompt lists its valid inputs and answers to a single keypress — there is
no need to hit Enter. Invalid input — a number outside `1`–`9`, an occupied
cell, or a key other than the ones offered — just shows a message and asks
again.

### Quitting

Pressing `Q` at any prompt (upper or lower case) ends the game immediately.
Closing standard input (`Ctrl-D`) quits gracefully as well.

## Tests and checks

```sh
fvm dart test      # unit tests for the game engine and AI
fvm dart analyze   # static analysis
make format        # dart format over bin/ and lib/
```

## Project layout

| Path                | Contents                                                  |
| ------------------- | --------------------------------------------------------- |
| `bin/tictactoe.dart`| Entrypoint: starts the CLI game                           |
| `lib/src/game.dart` | `Board` and `Cell` — board state, moves, win/draw logic   |
| `lib/src/ai.dart`   | `randomMove` — the AI's random empty-cell choice          |
| `lib/src/cli.dart`  | `TicTacToeCli` — prompts, board rendering, game loop      |
| `test/game_test.dart` | Unit tests for wins, draws, invalid moves, and the AI   |

The game engine is pure logic with no I/O, which is why it is fully unit-tested;
the interactive CLI layer is exercised by playing the game.
