# tictactoe

A command-line tic-tac-toe game written in Dart. You play against a local
[Ollama](https://ollama.com) decision model: every AI turn asks the model which
empty cell to play. You choose X or O, X always moves first, and empty cells are
labelled with their number so you can pick a move by number.

```
Tic-tac-toe vs. the tev1:0.8b decision model. X goes first.
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

When Ollama cannot be reached, answers with an error, or names a cell that is
not empty, that turn warns and falls back to a random empty cell:

```
Warning: Decision model failed (Could not reach Ollama at http://localhost:11434: ...); played a random move.
```

## Requirements

- [Dart SDK](https://dart.dev/get-dart) `^3.12.2`
- [fvm](https://fvm.app) — the SDK version is pinned in `.fvmrc`, and the
  commands below use `fvm dart`
- [Ollama](https://ollama.com) v0.35.0 or newer, serving
  `http://localhost:11434`, with the decision model pulled
  (`ollama pull tev1:0.8b`)

## Setup

```sh
fvm install          # installs the pinned SDK
fvm dart pub get
ollama pull tev1:0.8b
```

The model name lives in `.env`, which is committed with
`DECISION_MODEL=tev1:0.8b`. Edit that line to play against a different decision
model; nothing else has to change.

`.env` also carries `DECISION_DEBUG=true`. Set it to `false` (or unset it)
to hide the probabilities; any of `true`, `1`, `yes`, `on` (case-insensitive)
turns the debug output on:

```
Model probabilities: 2: 21.5%, 1: 20.2%, 6: 19.5%, ...
```

## Run

```sh
make run
```

`make run` reads `.env` and exports `DECISION_MODEL` before starting the game.
Without `make`, export the variable yourself:

```sh
export DECISION_MODEL=tev1:0.8b
fvm dart run bin/tictactoe.dart
```

The program refuses to start without a model: when `DECISION_MODEL` is unset or
empty it prints an error to stderr and exits with status `2` before showing the
first prompt. `make` also stops with an error when `.env` itself is missing.

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

## AI behaviour

- **Model moves.** Each AI turn sends the board and the empty cells to
  `/v1/systemone` and plays the cell the model picks.
- **Warnings and fallback.** If the request fails (Ollama down, HTTP error,
  malformed answer) or the model picks an occupied or unknown cell, that turn
  prints a `Warning: ...` line and plays a random empty cell instead. The game
  always continues — there are no retries.

## Tests and checks

```sh
fvm dart test      # unit tests for the game engine, AI, and Ollama client
fvm dart analyze   # static analysis
make format        # dart format over bin/ and lib/
make test          # same tests, with DECISION_MODEL from .env
```

The tests never need a live Ollama server: the client is tested against a fake
`HttpServer` on loopback, and the AI against an in-memory `DecisionClient`.

## Project layout

| Path                    | Contents                                                      |
| ----------------------- | ------------------------------------------------------------- |
| `bin/tictactoe.dart`    | Entrypoint: starts the CLI game                               |
| `lib/src/game.dart`     | `Board` and `Cell` — board state, moves, win/draw logic       |
| `lib/src/ai.dart`       | `modelMove` — asks the model, falls back to a random cell     |
| `lib/src/ollama.dart`   | `DecisionClient`, `OllamaClient`, and `OllamaException`       |
| `lib/src/cli.dart`      | `TicTacToeCli` — startup check, prompts, board, game loop     |
| `.env`                  | `DECISION_MODEL` and `DECISION_DEBUG` — what `make run` exports |
| `test/game_test.dart`   | Unit tests for wins, draws, invalid moves, and move selection |
| `test/ollama_test.dart` | Unit tests for the System One client against a fake server    |

The game engine is pure logic with no I/O, which is why it is fully unit-tested;
the interactive CLI layer is exercised by playing the game.
