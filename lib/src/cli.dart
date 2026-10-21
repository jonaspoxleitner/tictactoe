import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:tictactoe/src/ai.dart';
import 'package:tictactoe/src/game.dart';
import 'package:tictactoe/src/ollama.dart';

/// Interactive command-line tic-tac-toe against an Ollama decision model.
///
/// Every prompt lists its valid inputs and accepts a single keypress —
/// no Enter needed. `Q` at any prompt, Ctrl+C, or EOF ends the app.
class TicTacToeCli {
  /// The environment variable that names the decision model to play against.
  static const String decisionModelVariable = 'DECISION_MODEL';

  /// The environment variable that enables debug output (model probabilities)
  /// when set to `true`, `1`, `yes`, or `on` (case-insensitive).
  static const String decisionDebugVariable = 'DECISION_DEBUG';

  final Random _random = Random();
  bool _debug = false;
  StreamSubscription<ProcessSignal>? _interruptSubscription;

  /// Plays games until the user quits.
  ///
  /// Reads the model from [decisionModelVariable] and exits with code `2`,
  /// after an error on stderr, when it is unset or empty.
  Future<void> run() async {
    final model = _decisionModel();
    _debug = _debugEnabled();
    final client = OllamaClient(model: model);
    final interactive = stdin.hasTerminal;
    if (interactive) {
      stdin.echoMode = false;
      stdin.lineMode = false;
      _interruptSubscription = ProcessSignal.sigint.watch().listen((_) {
        _restoreTerminal();
        exit(130);
      });
    }
    try {
      stdout.writeln('Tic-tac-toe vs. the $model decision model. X goes first.');
      while (true) {
        final human = _askSymbol();
        if (human == null) {
          break;
        }
        if (!await _playGame(human, client)) {
          break;
        }
        if (!_askRestart()) {
          break;
        }
      }
      stdout.writeln('Goodbye.');
    } finally {
      if (interactive) {
        _restoreTerminal();
        unawaited(_interruptSubscription?.cancel());
      }
    }
  }

  /// The model named by [decisionModelVariable].
  ///
  /// Reports to stderr and exits with code `2` when the variable is unset or
  /// empty, before any prompt is shown.
  String _decisionModel() {
    final model = Platform.environment[decisionModelVariable]?.trim();
    if (model == null || model.isEmpty) {
      stderr.writeln(
        'Error: $decisionModelVariable is not set. '
        'Add $decisionModelVariable=<model> to .env, or export it before running.',
      );
      exit(2);
    }
    return model;
  }

  /// Whether [decisionDebugVariable] enables debug output.
  bool _debugEnabled() => switch (Platform.environment[decisionDebugVariable]?.trim().toLowerCase()) {
    'true' || '1' || 'yes' || 'on' => true,
    _ => false,
  };

  /// Asks which symbol the human plays; returns `null` when the user quits.
  Cell? _askSymbol() {
    while (true) {
      stdout.writeln('[X] X (goes first) / [O] O / [Q] Quit');
      stdout.write('Play as: ');
      final input = _readKey();
      if (input == null || input == 'Q') {
        return null;
      }
      if (input == 'X') {
        return Cell.x;
      }
      if (input == 'O') {
        return Cell.o;
      }
      _reportInvalid(input);
    }
  }

  /// Plays one game with [human] as the human symbol, asking [client] for every
  /// AI move.
  ///
  /// Returns `false` when the user quits before the game ends. A model failure
  /// prints [MoveResult.warning] and the turn falls back to a random move.
  Future<bool> _playGame(Cell human, DecisionClient client) async {
    final ai = _opponent(human);
    var board = Board();
    var turn = Cell.x;
    while (true) {
      _drawBoard(board);
      if (turn == human) {
        final move = _askMove(board);
        if (move == null) {
          return false;
        }
        board = board.applyMove(move, human);
      } else {
        final result = await modelMove(board, ai, client, _random);
        final warning = result.warning;
        if (warning != null) {
          stdout.writeln('Warning: $warning.');
        }
        if (_debug) {
          _reportProbabilities(result.probabilities);
        }
        board = board.applyMove(result.cell, ai);
      }

      final winner = board.winner();
      if (winner != Cell.empty) {
        _drawBoard(board);
        stdout.writeln('\n${winner == human ? 'You win!' : 'The AI wins.'}');
        return true;
      }
      if (board.isDraw) {
        _drawBoard(board);
        stdout.writeln('\nDraw.');
        return true;
      }
      turn = _opponent(turn);
    }
  }

  /// Asks for a cell to play; returns its index, or `null` when the user quits.
  int? _askMove(Board board) {
    final available = [for (final index in board.emptyCells) index + 1].join(', ');
    while (true) {
      stdout.writeln('Your move — available: $available / [Q] Quit');
      stdout.write('Cell: ');
      final input = _readKey();
      if (input == null || input == 'Q') {
        return null;
      }
      final number = int.tryParse(input);
      if (number == null || number < 1 || number > Board.cellCount) {
        _reportInvalid(input);
        continue;
      }
      if (board[number - 1] != Cell.empty) {
        stdout.writeln('Cell $number is already taken.');
        continue;
      }
      return number - 1;
    }
  }

  /// Asks whether to play another game; returns `false` when the user quits.
  bool _askRestart() {
    while (true) {
      stdout.writeln('[R] Restart / [Q] Quit');
      stdout.write('Choice: ');
      final input = _readKey();
      if (input == null || input == 'Q') {
        return false;
      }
      if (input == 'R') {
        return true;
      }
      _reportInvalid(input);
    }
  }

  /// Prints [board]; empty cells show their 1-based number.
  void _drawBoard(Board board) {
    final rows = [
      for (var row = 0; row < 3; row++)
        [for (var column = 0; column < 3; column++) ' ${_cellLabel(board, row * 3 + column)} '].join('|'),
    ];
    stdout.writeln('\n${rows.join('\n---+---+---\n')}');
  }

  /// The rendering of the cell at [index]: `X`, `O`, or its 1-based number.
  String _cellLabel(Board board, int index) => switch (board[index]) {
    Cell.x => 'X',
    Cell.o => 'O',
    Cell.empty => '${index + 1}',
  };

  /// In debug mode, prints the model's [probabilities], most likely first.
  void _reportProbabilities(Map<String, double>? probabilities) {
    if (probabilities == null) {
      return;
    }
    final ranked = probabilities.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final listing = ranked.map((entry) => '${entry.key}: ${(entry.value * 100).toStringAsFixed(1)}%').join(', ');
    stdout.writeln('Model probabilities: $listing');
  }

  Cell _opponent(Cell symbol) => symbol == Cell.x ? Cell.o : Cell.x;

  /// Waits for one key and returns it upper-cased; `null` at end of input.
  ///
  /// In a real terminal, stdin is in raw mode, so a single keypress is
  /// enough and the accepted key is echoed here. With piped input, the
  /// first character of each line is used instead.
  String? _readKey() {
    if (stdin.hasTerminal) {
      while (true) {
        int byte;
        try {
          byte = stdin.readByteSync();
        } catch (_) {
          return null;
        }
        if (byte < 0) {
          return null;
        }
        final key = String.fromCharCode(byte);
        if (key.trim().isEmpty) {
          continue;
        }
        stdout.writeln(key.toUpperCase());
        return key.toUpperCase();
      }
    }
    final line = stdin.readLineSync();
    if (line == null) {
      return null;
    }
    final trimmed = line.trim();
    return trimmed.isEmpty ? '' : trimmed[0].toUpperCase();
  }

  /// Restores normal terminal input handling after raw mode.
  void _restoreTerminal() {
    stdin.echoMode = true;
    stdin.lineMode = true;
  }

  void _reportInvalid(String input) => stdout.writeln('Invalid input: "$input".');
}
