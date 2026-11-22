import 'dart:math';

import 'models.dart';

class GameBoard {
  final List<List<CellState>> grid;
  final List<PlacedShip> ships;

  GameBoard()
      : grid = List.generate(
          kBoardSize,
          (_) => List.filled(kBoardSize, CellState.empty),
        ),
        ships = [];

  bool get allShipsPlaced => ships.length == kFleetSpecs.length;

  bool get allShipsSunk =>
      ships.isNotEmpty && ships.every((ship) => ship.isSunk);

  int get hitSegmentsCount {
    int count = 0;
    for (int r = 0; r < kBoardSize; r++) {
      for (int c = 0; c < kBoardSize; c++) {
        if (grid[r][c] == CellState.hit || grid[r][c] == CellState.sunk) {
          count++;
        }
      }
    }
    return count;
  }

  int get remainingSegments =>
      (kTotalFleetSegments - hitSegmentsCount).clamp(0, kTotalFleetSegments);

  int get sunkShipsCount => ships.where((s) => s.isSunk).length;

  int get remainingShipsCount =>
      (kFleetSpecs.length - sunkShipsCount).clamp(0, kFleetSpecs.length);

  bool hasPlacedSpec(String specId) => ships.any((s) => s.spec.id == specId);

  void removeShip(String specId) {
    final idx = ships.indexWhere((s) => s.spec.id == specId);
    if (idx == -1) return;
    final ship = ships.removeAt(idx);
    for (final (r, c) in ship.cells) {
      grid[r][c] = CellState.empty;
    }
  }

  void clear() {
    for (int r = 0; r < kBoardSize; r++) {
      for (int c = 0; c < kBoardSize; c++) {
        grid[r][c] = CellState.empty;
      }
    }
    ships.clear();
  }

  bool canPlace(ShipSpec spec, int row, int col, bool horizontal) {
    for (int i = 0; i < spec.length; i++) {
      final r = horizontal ? row : row + i;
      final c = horizontal ? col + i : col;
      if (r < 0 || r >= kBoardSize || c < 0 || c >= kBoardSize) {
        return false;
      }
      if (grid[r][c] != CellState.empty) {
        return false;
      }
    }
    return true;
  }

  bool placeShip(ShipSpec spec, int row, int col, bool horizontal) {
    if (!canPlace(spec, row, col, horizontal)) return false;
    final ship = PlacedShip(
      spec: spec,
      row: row,
      col: col,
      horizontal: horizontal,
    );
    ships.add(ship);
    for (final (r, c) in ship.cells) {
      grid[r][c] = CellState.ship;
    }
    return true;
  }

  void randomize([Random? random]) {
    final rng = random ?? Random();
    clear();
    for (final spec in kFleetSpecs) {
      bool placed = false;
      int attempts = 0;
      while (!placed && attempts < 500) {
        attempts++;
        final horizontal = rng.nextBool();
        final row = rng.nextInt(kBoardSize);
        final col = rng.nextInt(kBoardSize);
        placed = placeShip(spec, row, col, horizontal);
      }
    }
  }

  /// Processes an incoming shot against this board.
  ShotResult receiveShot(int row, int col) {
    if (grid[row][col] == CellState.miss ||
        grid[row][col] == CellState.hit ||
        grid[row][col] == CellState.sunk) {
      return ShotResult(row: row, col: col, outcome: ShotOutcome.miss);
    }

    for (final ship in ships) {
      final idx = ship.indexOfCell(row, col);
      if (idx != null) {
        ship.hits.add(idx);
        if (ship.isSunk) {
          for (final (r, c) in ship.cells) {
            grid[r][c] = CellState.sunk;
          }
          final outcome = allShipsSunk ? ShotOutcome.win : ShotOutcome.sunk;
          return ShotResult(
            row: row,
            col: col,
            outcome: outcome,
            sunkShip: ship,
          );
        } else {
          grid[row][col] = CellState.hit;
          return ShotResult(row: row, col: col, outcome: ShotOutcome.hit);
        }
      }
    }

    grid[row][col] = CellState.miss;
    return ShotResult(row: row, col: col, outcome: ShotOutcome.miss);
  }

  /// Records the outcome of our own shot on the enemy tracking board.
  void recordTrackingResult(
    int row,
    int col,
    ShotOutcome outcome, {
    int? sunkRow,
    int? sunkCol,
    bool? sunkHorizontal,
    int? sunkLength,
  }) {
    if (outcome == ShotOutcome.miss) {
      grid[row][col] = CellState.miss;
    } else if (outcome == ShotOutcome.hit) {
      grid[row][col] = CellState.hit;
    } else {
      grid[row][col] = CellState.sunk;
      if (sunkRow != null &&
          sunkCol != null &&
          sunkHorizontal != null &&
          sunkLength != null) {
        for (int i = 0; i < sunkLength; i++) {
          final r = sunkHorizontal ? sunkRow : sunkRow + i;
          final c = sunkHorizontal ? sunkCol + i : sunkCol;
          if (r >= 0 && r < kBoardSize && c >= 0 && c < kBoardSize) {
            grid[r][c] = CellState.sunk;
          }
        }
        // Reveal the sunk enemy ship sprite on the tracking board.
        final alreadyTracked = ships.any(
          (s) => s.row == sunkRow && s.col == sunkCol && s.horizontal == sunkHorizontal,
        );
        if (!alreadyTracked) {
          final usedIds = ships.map((s) => s.spec.id).toSet();
          final spec = kFleetSpecs.firstWhere(
            (s) => s.length == sunkLength && !usedIds.contains(s.id),
            orElse: () => kFleetSpecs.firstWhere(
              (s) => s.length == sunkLength,
              orElse: () => kFleetSpecs.last,
            ),
          );
          ships.add(
            PlacedShip(
              spec: spec,
              row: sunkRow,
              col: sunkCol,
              horizontal: sunkHorizontal,
              hits: Set<int>.from(List.generate(spec.length, (i) => i)),
            ),
          );
        }
      }
    }
  }
}
