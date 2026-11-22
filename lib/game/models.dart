enum CellState {
  empty,
  ship,
  miss,
  hit,
  sunk,
}

class ShipSpec {
  final String id;
  final String name;
  final int length;

  const ShipSpec({
    required this.id,
    required this.name,
    required this.length,
  });

  String get spritePath => 'assets/images/ships/$id.png';
}

const List<ShipSpec> kFleetSpecs = [
  ShipSpec(id: 'carrier', name: 'Portaaviones', length: 5),
  ShipSpec(id: 'battleship', name: 'Acorazado', length: 4),
  ShipSpec(id: 'cruiser', name: 'Crucero', length: 3),
  ShipSpec(id: 'submarine', name: 'Submarino', length: 3),
  ShipSpec(id: 'destroyer', name: 'Destructor', length: 2),
];

const int kTotalFleetSegments = 17;
const int kBoardSize = 10;

class PlacedShip {
  final ShipSpec spec;
  final int row;
  final int col;
  final bool horizontal;
  final Set<int> hits;

  PlacedShip({
    required this.spec,
    required this.row,
    required this.col,
    required this.horizontal,
    Set<int>? hits,
  }) : hits = hits ?? <int>{};

  bool get isSunk => hits.length >= spec.length;

  List<(int, int)> get cells {
    return List.generate(spec.length, (i) {
      return horizontal ? (row, col + i) : (row + i, col);
    });
  }

  bool occupies(int r, int c) {
    if (horizontal) {
      return r == row && c >= col && c < col + spec.length;
    }
    return c == col && r >= row && r < row + spec.length;
  }

  int? indexOfCell(int r, int c) {
    if (!occupies(r, c)) return null;
    return horizontal ? (c - col) : (r - row);
  }
}

enum ShotOutcome {
  miss,
  hit,
  sunk,
  win,
}

class ShotResult {
  final int row;
  final int col;
  final ShotOutcome outcome;
  final PlacedShip? sunkShip;

  const ShotResult({
    required this.row,
    required this.col,
    required this.outcome,
    this.sunkShip,
  });
}
