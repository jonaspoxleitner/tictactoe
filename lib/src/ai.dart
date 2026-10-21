import 'dart:math';

import 'package:tictactoe/src/game.dart';

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
