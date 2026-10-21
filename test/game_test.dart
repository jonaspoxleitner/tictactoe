import 'dart:math';

import 'package:test/test.dart';
import 'package:tictactoe/tictactoe.dart';

/// A full board with no winner, in cell order `0`-`8`.
const drawCells = [
  Cell.x, Cell.o, Cell.x, //
  Cell.x, Cell.o, Cell.o, //
  Cell.o, Cell.x, Cell.x, //
];

/// The eight lines that win the game, in cell order `0`-`8`.
const winLines = [
  [0, 1, 2],
  [3, 4, 5],
  [6, 7, 8],
  [0, 3, 6],
  [1, 4, 7],
  [2, 5, 8],
  [0, 4, 8],
  [2, 4, 6],
];

/// Builds a board from [cells], skipping [Cell.empty] entries.
Board boardFrom(List<Cell> cells) {
  var board = Board();
  for (var index = 0; index < cells.length; index++) {
    if (cells[index] != Cell.empty) {
      board = board.applyMove(index, cells[index]);
    }
  }
  return board;
}

void main() {
  group('Board', () {
    test('starts with nine empty cells', () {
      final board = Board();

      expect(board.emptyCells, [0, 1, 2, 3, 4, 5, 6, 7, 8]);
      for (var index = 0; index < Board.cellCount; index++) {
        expect(board[index], Cell.empty);
      }
      expect(board.isFull, isFalse);
      expect(board.isDraw, isFalse);
      expect(board.winner(), Cell.empty);
    });

    test('applyMove places the symbol without mutating the original board', () {
      final empty = Board();

      final board = empty.applyMove(4, Cell.x);

      expect(board[4], Cell.x);
      expect(board.emptyCells, [0, 1, 2, 3, 5, 6, 7, 8]);
      expect(empty[4], Cell.empty);
      expect(empty.emptyCells, [0, 1, 2, 3, 4, 5, 6, 7, 8]);
    });

    for (final line in winLines) {
      test('detects an X win on line $line', () {
        final board = boardFrom([
          for (var index = 0; index < Board.cellCount; index++) line.contains(index) ? Cell.x : Cell.empty,
        ]);

        expect(board.winner(), Cell.x);
        expect(board.isDraw, isFalse);
      });

      test('detects an O win on line $line', () {
        final board = boardFrom([
          for (var index = 0; index < Board.cellCount; index++) line.contains(index) ? Cell.o : Cell.empty,
        ]);

        expect(board.winner(), Cell.o);
        expect(board.isDraw, isFalse);
      });
    }

    test('reports no winner for a line broken by the other symbol', () {
      final board = boardFrom([
        Cell.x,
        Cell.o,
        Cell.x,
        Cell.empty,
        Cell.empty,
        Cell.empty,
        Cell.empty,
        Cell.empty,
        Cell.empty,
      ]);

      expect(board.winner(), Cell.empty);
    });

    test('detects a draw when the board is full without a winner', () {
      final board = boardFrom(drawCells);

      expect(board.isFull, isTrue);
      expect(board.winner(), Cell.empty);
      expect(board.isDraw, isTrue);
    });

    test('a full board with a winner is not a draw', () {
      final board = boardFrom([
        Cell.x, Cell.x, Cell.x, //
        Cell.o, Cell.o, Cell.empty, //
        Cell.empty, Cell.empty, Cell.empty, //
      ]);

      expect(board.isFull, isFalse);
      expect(board.winner(), Cell.x);

      final fullBoard = board.applyMove(5, Cell.x).applyMove(6, Cell.o).applyMove(7, Cell.x).applyMove(8, Cell.o);

      expect(fullBoard.isFull, isTrue);
      expect(fullBoard.winner(), Cell.x);
      expect(fullBoard.isDraw, isFalse);
    });

    for (final index in [-1, 9, 42]) {
      test('applyMove rejects out-of-range index $index', () {
        expect(() => Board().applyMove(index, Cell.x), throwsRangeError);
      });

      test('operator [] rejects out-of-range index $index', () {
        expect(() => Board()[index], throwsRangeError);
      });
    }

    test('applyMove rejects an occupied cell', () {
      final board = Board().applyMove(0, Cell.x);

      expect(() => board.applyMove(0, Cell.o), throwsStateError);
    });

    test('applyMove rejects Cell.empty as a symbol', () {
      expect(() => Board().applyMove(0, Cell.empty), throwsArgumentError);
    });
  });

  group('randomMove', () {
    test('returns the only empty cell', () {
      final board = boardFrom([
        Cell.x, Cell.o, Cell.x, //
        Cell.x, Cell.o, Cell.o, //
        Cell.o, Cell.x, Cell.empty, //
      ]);

      for (var seed = 0; seed < 20; seed++) {
        expect(randomMove(board, Random(seed)), 8);
      }
    });

    test('only picks empty cells', () {
      final board = boardFrom([
        Cell.x, Cell.o, Cell.empty, //
        Cell.empty, Cell.x, Cell.empty, //
        Cell.empty, Cell.o, Cell.empty, //
      ]);
      final random = Random(42);
      final moves = <int>{};

      for (var attempt = 0; attempt < 200; attempt++) {
        final move = randomMove(board, random);

        expect(move, inInclusiveRange(0, Board.cellCount - 1));
        expect(board[move], Cell.empty);
        moves.add(move);
      }

      expect(moves, unorderedEquals(board.emptyCells));
    });

    test('throws a StateError on a full board', () {
      final board = boardFrom(drawCells);

      expect(board.isFull, isTrue);
      expect(() => randomMove(board, Random(0)), throwsStateError);
    });
  });
}
