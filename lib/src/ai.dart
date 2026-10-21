import 'dart:math';

import 'package:tictactoe/src/game.dart';
import 'package:tictactoe/src/ollama.dart';

/// The outcome of asking the decision model for a move.
class MoveResult {
  /// Reports [cell] as the chosen cell index, with [warning] set when the model
  /// could not be used and a random move replaced it.
  const MoveResult(this.cell, {this.warning, this.probabilities});

  /// The chosen cell index, always one of the board's empty cells.
  final int cell;

  /// Why the model's answer was discarded, or `null` when the model chose
  /// [cell].
  final String? warning;

  /// The probability the model assigned every offered cell, keyed by 1-based
  /// cell number, or `null` when the model was not reached or reported none.
  final Map<String, double>? probabilities;
}

/// The question posed to the decision model for [symbol]'s turn.
///
/// [symbol] must be [Cell.x] or [Cell.o].
String moveInstructions(Cell symbol) =>
    'You play ${_symbolLabel(symbol)} in tic-tac-toe. Three matching symbols in a row, column, '
    'or diagonal win. Choose the empty cell where ${_symbolLabel(symbol)} should move.';

/// The model state of [board]: every 1-based cell number mapped to `X`, `O`, or
/// `empty`.
Map<String, String> boardState(Board board) => {
  for (var index = 0; index < Board.cellCount; index++) '${index + 1}': _cellLabel(board[index]),
};

/// The candidate moves on [board]: every empty cell's 1-based number mapped to
/// its position hint, such as `1` to `top-left cell`.
Map<String, String> moveCriteria(Board board) => {
  for (final index in board.emptyCells) '${index + 1}': _positionHints[index],
};

/// Returns a uniformly random empty cell index of [board].
///
/// Throws a [StateError] when [board] is full and no move is left.
int randomMove(Board board, Random random) {
  final candidates = board.emptyCells;
  if (candidates.isEmpty) {
    throw StateError('Cannot pick a move on a full board');
  }
  return candidates[random.nextInt(candidates.length)];
}

/// Asks [client] where [symbol] should move on [board].
///
/// The returned [MoveResult] holds the model's cell, or - when the client
/// throws an [OllamaException] or answers with an occupied or unknown cell - a
/// random empty cell plus a warning explaining the fallback.
///
/// [symbol] must be [Cell.x] or [Cell.o]. Throws a [StateError] when [board] is
/// full and no move is left. A board with a single empty cell is answered
/// directly, without consulting the model.
Future<MoveResult> modelMove(Board board, Cell symbol, DecisionClient client, Random random) async {
  final emptyCells = board.emptyCells;
  if (emptyCells.isEmpty) {
    throw StateError('Cannot pick a move on a full board');
  }
  if (emptyCells.length == 1) {
    // The decision API requires 2-26 candidates; a single cell is the answer.
    return MoveResult(emptyCells.single);
  }
  final DecisionChoice choice;
  try {
    choice = await client.choose(
      state: boardState(board),
      instructions: moveInstructions(symbol),
      criteria: moveCriteria(board),
    );
  } on OllamaException catch (error) {
    return MoveResult(
      randomMove(board, random),
      warning: 'Decision model failed (${error.message}); played a random move',
    );
  }
  final number = int.tryParse(choice.label);
  if (number == null || number < 1 || number > Board.cellCount) {
    return MoveResult(
      randomMove(board, random),
      warning: 'Decision model chose "${choice.label}", which is not a cell; played a random move',
      probabilities: choice.probabilities,
    );
  }
  final index = number - 1;
  final occupied = board[index];
  if (occupied != Cell.empty) {
    return MoveResult(
      randomMove(board, random),
      warning: 'Decision model chose cell $number, which holds ${_symbolLabel(occupied)}; played a random move',
      probabilities: choice.probabilities,
    );
  }
  return MoveResult(index, probabilities: choice.probabilities);
}

/// The model label of [cell].
String _cellLabel(Cell cell) => switch (cell) {
  Cell.empty => 'empty',
  Cell.x => 'X',
  Cell.o => 'O',
};

/// The board symbol of [cell], which must not be [Cell.empty].
String _symbolLabel(Cell cell) => switch (cell) {
  Cell.empty => throw ArgumentError.value(cell, 'cell', 'Must be Cell.x or Cell.o'),
  Cell.x => 'X',
  Cell.o => 'O',
};

/// The position hint of each cell index, in cell order `0`-`8`.
const List<String> _positionHints = [
  'top-left cell',
  'top-center cell',
  'top-right cell',
  'middle-left cell',
  'center cell',
  'middle-right cell',
  'bottom-left cell',
  'bottom-center cell',
  'bottom-right cell',
];
