import 'package:flutter/material.dart';

import '../game/game_board.dart';
import '../game/models.dart';
import 'tactical_widgets.dart';

class PlacementPreview {
  final ShipSpec spec;
  final int row;
  final int col;
  final bool horizontal;
  final bool isValid;

  const PlacementPreview({
    required this.spec,
    required this.row,
    required this.col,
    required this.horizontal,
    required this.isValid,
  });

  List<(int, int)> get cells => List.generate(spec.length, (i) {
        return horizontal ? (row, col + i) : (row + i, col);
      });
}

class BoardWidget extends StatelessWidget {
  final GameBoard board;
  final bool showShips;
  final bool interactive;
  final void Function(int row, int col)? onCellTap;
  final void Function(int row, int col)? onCellHoverOrDrag;
  final VoidCallback? onDragEnd;
  final PlacementPreview? placementPreview;
  final (int, int)? targetedCell;
  final (int, int)? lastShotCell;

  const BoardWidget({
    super.key,
    required this.board,
    required this.showShips,
    this.interactive = false,
    this.onCellTap,
    this.onCellHoverOrDrag,
    this.onDragEnd,
    this.placementPreview,
    this.targetedCell,
    this.lastShotCell,
  });

  static const _colLabels = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 8, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D354D), Color(0xFF0A1826)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NavalPalette.steelBorder, width: 1.8),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: Column(
          children: [
            // Column headers A-J
            SizedBox(
              height: 18,
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  ...List.generate(kBoardSize, (c) {
                    final isHighlighted = targetedCell?.$2 == c ||
                        (placementPreview != null &&
                            placementPreview!.cells.any((p) => p.$2 == c));
                    return Expanded(
                      child: Center(
                        child: Text(
                          _colLabels[c],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: isHighlighted
                                ? NavalPalette.tacticalAmber
                                : Colors.white70,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            // Row numbers + 10x10 ocean grid
            Expanded(
              child: Row(
                children: [
                  // Row headers 1-10
                  SizedBox(
                    width: 20,
                    child: Column(
                      children: List.generate(kBoardSize, (r) {
                        final isHighlighted = targetedCell?.$1 == r ||
                            (placementPreview != null &&
                                placementPreview!.cells.any((p) => p.$1 == r));
                        return Expanded(
                          child: Center(
                            child: Text(
                              '${r + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: isHighlighted
                                    ? NavalPalette.tacticalAmber
                                    : Colors.white70,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // Actual 10x10 tactical ocean battlefield
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final cellW = constraints.maxWidth / kBoardSize;
                          final cellH = constraints.maxHeight / kBoardSize;

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: interactive && onCellTap != null
                                ? (details) {
                                    final c = (details.localPosition.dx / cellW)
                                        .floor()
                                        .clamp(0, kBoardSize - 1);
                                    final r = (details.localPosition.dy / cellH)
                                        .floor()
                                        .clamp(0, kBoardSize - 1);
                                    onCellTap!(r, c);
                                  }
                                : null,
                            onPanStart: interactive && onCellHoverOrDrag != null
                                ? (details) {
                                    final c = (details.localPosition.dx / cellW)
                                        .floor()
                                        .clamp(0, kBoardSize - 1);
                                    final r = (details.localPosition.dy / cellH)
                                        .floor()
                                        .clamp(0, kBoardSize - 1);
                                    onCellHoverOrDrag!(r, c);
                                  }
                                : null,
                            onPanUpdate:
                                interactive && onCellHoverOrDrag != null
                                    ? (details) {
                                        final c =
                                            (details.localPosition.dx / cellW)
                                                .floor()
                                                .clamp(0, kBoardSize - 1);
                                        final r =
                                            (details.localPosition.dy / cellH)
                                                .floor()
                                                .clamp(0, kBoardSize - 1);
                                        onCellHoverOrDrag!(r, c);
                                      }
                                    : null,
                            onPanEnd: interactive && onDragEnd != null
                                ? (_) => onDragEnd!()
                                : null,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // 1. Pixel-art Ocean Texture
                                Image.asset(
                                  'assets/images/ocean_bg.png',
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.none,
                                ),
                                // Subtle dark tactical tint for crisp grid contrast
                                Container(
                                  color: const Color(0xFF041423)
                                      .withValues(alpha: 0.25),
                                ),
                                // 2. Tactical Grid Lines & Cell Highlights
                                _buildGridOverlay(cellW, cellH),
                                // 3. Ship Sprites (all player ships, or sunk enemy ships)
                                ..._buildShipSprites(cellW, cellH),
                                // 4. Live Placement Ghost Preview
                                if (placementPreview != null)
                                  ..._buildPlacementPreview(cellW, cellH),
                                // 5. FX Layer (Water Splashes, Fire Explosions, Crosshair)
                                ..._buildFxLayer(cellW, cellH),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridOverlay(double cellW, double cellH) {
    final previewCells = placementPreview?.cells.toSet() ?? const <(int, int)>{};
    final previewValid = placementPreview?.isValid ?? false;

    return Column(
      children: List.generate(kBoardSize, (r) {
        return Expanded(
          child: Row(
            children: List.generate(kBoardSize, (c) {
              final isPreview = previewCells.contains((r, c));
              final isTargeted = targetedCell == (r, c);
              final isLastShot = lastShotCell == (r, c);
              final state = board.grid[r][c];

              Color? fill;
              if (isPreview) {
                fill = (previewValid
                        ? NavalPalette.radarGreen
                        : NavalPalette.enemyRed)
                    .withValues(alpha: 0.36);
              } else if (isTargeted) {
                fill = NavalPalette.tacticalAmber.withValues(alpha: 0.55);
              } else if (state == CellState.sunk) {
                fill = NavalPalette.enemyRed.withValues(alpha: 0.30);
              } else if (state == CellState.hit) {
                fill = NavalPalette.tacticalAmber.withValues(alpha: 0.22);
              }

              return Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: fill,
                    border: Border.all(
                      color: isTargeted
                          ? NavalPalette.tacticalAmber
                          : (isLastShot
                              ? Colors.white70
                              : Colors.lightBlueAccent.withValues(alpha: 0.32)),
                      width: isTargeted ? 1.8 : (isLastShot ? 1.3 : 0.65),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  List<Widget> _buildShipSprites(double cellW, double cellH) {
    final visibleShips = showShips
        ? board.ships
        : board.ships.where((s) => s.isSunk).toList();

    return visibleShips.map((ship) {
      final left = ship.col * cellW;
      final top = ship.row * cellH;
      final width = (ship.horizontal ? ship.spec.length : 1) * cellW;
      final height = (ship.horizontal ? 1 : ship.spec.length) * cellH;

      Widget sprite = Image.asset(
        ship.spec.spritePath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
      );

      if (!ship.horizontal) {
        sprite = RotatedBox(quarterTurns: 1, child: sprite);
      }

      if (ship.isSunk) {
        sprite = ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Color(0xAA4A0C0C),
            BlendMode.srcATop,
          ),
          child: sprite,
        );
      }

      return Positioned(
        left: left + 1,
        top: top + 1,
        width: width - 2,
        height: height - 2,
        child: IgnorePointer(child: sprite),
      );
    }).toList();
  }

  List<Widget> _buildPlacementPreview(double cellW, double cellH) {
    final p = placementPreview!;
    final left = p.col * cellW;
    final top = p.row * cellH;
    final width = (p.horizontal ? p.spec.length : 1) * cellW;
    final height = (p.horizontal ? 1 : p.spec.length) * cellH;

    Widget ghost = Image.asset(
      p.spec.spritePath,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      color: (p.isValid ? NavalPalette.radarGreen : NavalPalette.enemyRed)
          .withValues(alpha: 0.72),
      colorBlendMode: BlendMode.modulate,
    );

    if (!p.horizontal) {
      ghost = RotatedBox(quarterTurns: 1, child: ghost);
    }

    return [
      Positioned(
        left: left + 1,
        top: top + 1,
        width: width - 2,
        height: height - 2,
        child: IgnorePointer(
          child: Opacity(opacity: 0.85, child: ghost),
        ),
      ),
    ];
  }

  List<Widget> _buildFxLayer(double cellW, double cellH) {
    final widgets = <Widget>[];

    for (int r = 0; r < kBoardSize; r++) {
      for (int c = 0; c < kBoardSize; c++) {
        final state = board.grid[r][c];
        if (state == CellState.miss) {
          widgets.add(
            Positioned(
              left: c * cellW,
              top: r * cellH,
              width: cellW,
              height: cellH,
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Image.asset(
                    'assets/images/fx/splash.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                  ),
                ),
              ),
            ),
          );
        } else if (state == CellState.hit || state == CellState.sunk) {
          widgets.add(
            Positioned(
              left: c * cellW,
              top: r * cellH,
              width: cellW,
              height: cellH,
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: Image.asset(
                    'assets/images/fx/explosion.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    if (targetedCell != null) {
      final (tr, tc) = targetedCell!;
      widgets.add(
        Positioned(
          left: tc * cellW,
          top: tr * cellH,
          width: cellW,
          height: cellH,
          child: const IgnorePointer(
            child: Center(
              child: Icon(
                Icons.gps_fixed,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}
