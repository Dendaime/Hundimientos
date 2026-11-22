import 'package:flutter/material.dart';

import '../game/game_board.dart';
import '../game/models.dart';

class BoardWidget extends StatelessWidget {
  final GameBoard board;
  final bool showShips;
  final bool interactive;
  final void Function(int row, int col)? onCellTap;

  const BoardWidget({
    super.key,
    required this.board,
    required this.showShips,
    this.interactive = false,
    this.onCellTap,
  });

  static const _colLabels = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'];

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Column(
        children: [
          // Column headers (A-J)
          Row(
            children: [
              const SizedBox(width: 22),
              ...List.generate(kBoardSize, (c) {
                return Expanded(
                  child: Center(
                    child: Text(
                      _colLabels[c],
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white60,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 2),
          // Grid rows
          Expanded(
            child: Column(
              children: List.generate(kBoardSize, (r) {
                return Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        child: Center(
                          child: Text(
                            '${r + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white60,
                            ),
                          ),
                        ),
                      ),
                      ...List.generate(kBoardSize, (c) {
                        final cell = board.grid[r][c];
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(1),
                            child: GestureDetector(
                              onTap: interactive && onCellTap != null
                                  ? () => onCellTap!(r, c)
                                  : null,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                decoration: BoxDecoration(
                                  color: _cellColor(cell),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: Colors.white12,
                                    width: 0.7,
                                  ),
                                ),
                                child: Center(child: _cellIcon(cell)),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Color _cellColor(CellState state) {
    switch (state) {
      case CellState.empty:
        return const Color(0xFF0E2A47);
      case CellState.ship:
        return showShips ? const Color(0xFF4A6FA5) : const Color(0xFF0E2A47);
      case CellState.miss:
        return const Color(0xFF1A4369);
      case CellState.hit:
        return const Color(0xFFD9534F);
      case CellState.sunk:
        return const Color(0xFF8B1E24);
    }
  }

  Widget? _cellIcon(CellState state) {
    switch (state) {
      case CellState.miss:
        return Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.white70,
            shape: BoxShape.circle,
          ),
        );
      case CellState.hit:
        return const Icon(Icons.close, size: 14, color: Colors.white);
      case CellState.sunk:
        return const Icon(Icons.local_fire_department,
            size: 14, color: Colors.amberAccent);
      default:
        return null;
    }
  }
}
