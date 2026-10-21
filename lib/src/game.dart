/// The symbol occupying a board cell, or [Cell.empty] for a free cell.
enum Cell { empty, x, o }

/// A tic-tac-toe board.
///
/// Cells are indexed `0`-`8`, left to right and top to bottom. Instances are
/// immutable: [applyMove] returns a new board and leaves the receiver
/// untouched.
class Board {
  /// Creates an empty board.
  Board() : _cells = List<Cell>.filled(cellCount, Cell.empty);

  Board._(this._cells);

  /// The number of cells on the board.
  static const int cellCount = 9;

  /// The index triples of the eight lines that win a game.
  static const List<List<int>> _winningLines = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];

  final List<Cell> _cells;

  /// The symbol in [index], which must be within `0`-`8`.
  Cell operator [](int index) {
    RangeError.checkValidIndex(index, _cells, 'index', cellCount);
    return _cells[index];
  }

  /// The indices of all [Cell.empty] cells, in ascending order.
  List<int> get emptyCells => [
    for (var index = 0; index < cellCount; index++)
      if (_cells[index] == Cell.empty) index,
  ];

  /// Whether every cell is occupied.
  bool get isFull => emptyCells.isEmpty;

  /// The symbol that owns a complete line, or [Cell.empty] when nobody has won.
  Cell winner() {
    for (final line in _winningLines) {
      final first = _cells[line[0]];
      if (first != Cell.empty && first == _cells[line[1]] && first == _cells[line[2]]) {
        return first;
      }
    }
    return Cell.empty;
  }

  /// Whether the board is full and nobody has won.
  bool get isDraw => isFull && winner() == Cell.empty;

  /// Returns a new board with [symbol] placed in [index].
  ///
  /// [index] must be within `0`-`8`, [symbol] must be [Cell.x] or [Cell.o], and
  /// the cell must still be empty; otherwise an [ArgumentError] (or its
  /// subclass [RangeError]) or a [StateError] is thrown.
  Board applyMove(int index, Cell symbol) {
    RangeError.checkValidIndex(index, _cells, 'index', cellCount);
    if (symbol == Cell.empty) {
      throw ArgumentError.value(symbol, 'symbol', 'Must be Cell.x or Cell.o');
    }
    final occupied = _cells[index];
    if (occupied != Cell.empty) {
      throw StateError('Cell $index is already occupied by $occupied');
    }
    final cells = List<Cell>.of(_cells)..[index] = symbol;
    return Board._(cells);
  }
}
