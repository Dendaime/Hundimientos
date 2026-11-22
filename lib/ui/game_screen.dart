import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/sfx_service.dart';
import '../ble/protocol.dart';
import '../ble/transport.dart';
import '../game/game_board.dart';
import '../game/models.dart';
import 'board_widget.dart';
import 'tactical_widgets.dart';

enum _GamePhase {
  placing,
  waitingOpponentReady,
  battle,
  finished,
}

class _BannerData {
  final String title;
  final String subtitle;
  final BannerKind kind;

  const _BannerData(this.title, this.subtitle, this.kind);
}

class GameScreen extends StatefulWidget {
  final GameTransport transport;
  final String title;

  const GameScreen({
    super.key,
    required this.transport,
    required this.title,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _myBoard = GameBoard();
  final _enemyBoard = GameBoard();

  _GamePhase _phase = _GamePhase.placing;
  bool _horizontal = true;
  ShipSpec? _selectedSpec = kFleetSpecs.first;
  (int, int)? _previewAnchor;

  bool _myReady = false;
  bool _opponentReady = false;
  bool _isMyTurn = false;
  bool _awaitingResult = false;
  bool? _didWin;

  (int, int)? _targetedCell;
  (int, int)? _lastEnemyShotOnMe;
  (int, int)? _lastMyShotOnEnemy;

  String _statusText = 'Despliega tu flota en el tablero';
  _BannerData? _activeBanner;
  Timer? _bannerTimer;

  StreamSubscription<GameMessage>? _msgSub;
  StreamSubscription<TransportStatus>? _statusSub;

  @override
  void initState() {
    super.initState();
    _isMyTurn = widget.transport.isHost;
    _msgSub = widget.transport.incomingMessages.listen(_onMessage);
    _statusSub = widget.transport.statusStream.listen((status) {
      if (status == TransportStatus.disconnected && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: NavalPalette.enemyRed,
            content: Text('Conexión perdida: el otro jugador se desconectó.'),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _msgSub?.cancel();
    _statusSub?.cancel();
    widget.transport.dispose();
    super.dispose();
  }

  void _showBanner(String title, String subtitle, BannerKind kind) {
    _bannerTimer?.cancel();
    setState(() {
      _activeBanner = _BannerData(title, subtitle, kind);
    });
    _bannerTimer = Timer(const Duration(milliseconds: 1650), () {
      if (mounted) {
        setState(() => _activeBanner = null);
      }
    });
  }

  ShipSpec? _firstUnplacedSpec() {
    for (final spec in kFleetSpecs) {
      if (!_myBoard.hasPlacedSpec(spec.id)) return spec;
    }
    return null;
  }

  PlacementPreview? _buildCurrentPreview() {
    if (_phase != _GamePhase.placing ||
        _selectedSpec == null ||
        _previewAnchor == null) {
      return null;
    }
    final (r, c) = _previewAnchor!;
    final valid = _myBoard.canPlace(_selectedSpec!, r, c, _horizontal);
    return PlacementPreview(
      spec: _selectedSpec!,
      row: r,
      col: c,
      horizontal: _horizontal,
      isValid: valid,
    );
  }

  void _onMessage(GameMessage msg) {
    if (!mounted) return;
    setState(() {
      if (msg is ReadyMessage) {
        _opponentReady = true;
        _tryStartBattle();
      } else if (msg is ResetMessage) {
        _resetLocalState();
      } else if (msg is ShotMessage) {
        _lastEnemyShotOnMe = (msg.row, msg.col);
        final result = _myBoard.receiveShot(msg.row, msg.col);
        widget.transport.send(
          ShotResultMessage(
            row: result.row,
            col: result.col,
            outcome: result.outcome,
            sunkRow: result.sunkShip?.row,
            sunkCol: result.sunkShip?.col,
            sunkHorizontal: result.sunkShip?.horizontal,
            sunkLength: result.sunkShip?.spec.length,
          ),
        );

        switch (result.outcome) {
          case ShotOutcome.miss:
            SfxService.instance.play(SfxType.miss);
            _isMyTurn = true;
            _statusText = 'El enemigo falló. ¡Tu turno de fuego!';
            _showBanner('¡DISPARO FALLADO!', 'El enemigo dio en agua. ¡Tu turno!', BannerKind.miss);
          case ShotOutcome.hit:
            SfxService.instance.play(SfxType.hit);
            _isMyTurn = true;
            _statusText = '¡Nos han impactado! Tu turno.';
            _showBanner('¡NOS DIERON!', 'Impacto enemigo en tu flota', BannerKind.hit);
          case ShotOutcome.sunk:
            SfxService.instance.play(SfxType.sunk);
            _isMyTurn = true;
            final shipName = result.sunkShip?.spec.name ?? 'buque';
            _statusText = '¡Hundieron tu $shipName! Tu turno.';
            _showBanner('¡BUQUE PERDIDO!', 'Hundieron tu $shipName', BannerKind.sunk);
          case ShotOutcome.win:
            SfxService.instance.play(SfxType.defeat);
            _phase = _GamePhase.finished;
            _didWin = false;
            _statusText = 'Derrota: toda tu flota fue hundida.';
        }
      } else if (msg is ShotResultMessage) {
        _awaitingResult = false;
        _targetedCell = null;
        _lastMyShotOnEnemy = (msg.row, msg.col);
        _enemyBoard.recordTrackingResult(
          msg.row,
          msg.col,
          msg.outcome,
          sunkRow: msg.sunkRow,
          sunkCol: msg.sunkCol,
          sunkHorizontal: msg.sunkHorizontal,
          sunkLength: msg.sunkLength,
        );

        switch (msg.outcome) {
          case ShotOutcome.miss:
            SfxService.instance.play(SfxType.miss);
            _isMyTurn = false;
            _statusText = 'Agua. Esperando ataque enemigo...';
            _showBanner('¡AGUA!', 'Sin impacto en esas coordenadas', BannerKind.miss);
          case ShotOutcome.hit:
            SfxService.instance.play(SfxType.hit);
            _isMyTurn = false;
            _statusText = '¡Impacto confirmado! Turno enemigo...';
            _showBanner('¡IMPACTO!', 'Fuego directo sobre nave enemiga', BannerKind.hit);
          case ShotOutcome.sunk:
            SfxService.instance.play(SfxType.sunk);
            _isMyTurn = false;
            _statusText = '¡Barco enemigo hundido! Turno enemigo...';
            _showBanner('¡HUNDIDO!', 'Nave enemiga enviada al fondo', BannerKind.sunk);
          case ShotOutcome.win:
            SfxService.instance.play(SfxType.victory);
            _phase = _GamePhase.finished;
            _didWin = true;
            _statusText = '¡Victoria naval! Armada enemiga destruida.';
        }
      }
    });
  }

  void _tryStartBattle() {
    if (_myReady && _opponentReady) {
      _phase = _GamePhase.battle;
      _isMyTurn = widget.transport.isHost;
      _statusText = _isMyTurn
          ? '¡Tu turno! Selecciona coordenadas para disparar.'
          : 'Turno del comandante enemigo...';
      _showBanner(
        '¡COMBATE INICIADO!',
        _isMyTurn ? 'Tienes el primer disparo' : 'Prepárate para el ataque enemigo',
        BannerKind.info,
      );
    }
  }

  void _onPlacementCellTap(int row, int col) {
    final spec = _selectedSpec;
    if (spec == null) return;

    // If user taps an already valid preview anchor or taps a valid spot, place immediately
    // If invalid, show the red preview so the user clearly sees why it doesn't fit!
    if (_myBoard.canPlace(spec, row, col, _horizontal)) {
      SfxService.instance.play(SfxType.place);
      setState(() {
        _myBoard.placeShip(spec, row, col, _horizontal);
        _previewAnchor = null;
        _selectedSpec = _firstUnplacedSpec();
        if (_myBoard.allShipsPlaced) {
          _statusText = '¡Flota desplegada! Pulsa "A LA BATALLA".';
        } else {
          _statusText = 'Despliega: ${_selectedSpec!.name} (${_selectedSpec!.length} casillas)';
        }
      });
    } else {
      SfxService.instance.play(SfxType.select);
      setState(() {
        _previewAnchor = (row, col);
        _statusText = 'Posición inválida: fuera de límites o superpuesta';
      });
    }
  }

  void _onPlacementDrag(int row, int col) {
    if (_selectedSpec == null) return;
    if (_previewAnchor != (row, col)) {
      setState(() {
        _previewAnchor = (row, col);
      });
    }
  }

  void _onPlacementDragEnd() {
    final spec = _selectedSpec;
    final anchor = _previewAnchor;
    if (spec == null || anchor == null) return;
    if (_myBoard.canPlace(spec, anchor.$1, anchor.$2, _horizontal)) {
      _onPlacementCellTap(anchor.$1, anchor.$2);
    }
  }

  void _toggleOrientation() {
    SfxService.instance.play(SfxType.rotate);
    setState(() {
      _horizontal = !_horizontal;
    });
  }

  void _selectDockShip(ShipSpec spec) {
    SfxService.instance.play(SfxType.select);
    setState(() {
      if (_myBoard.hasPlacedSpec(spec.id)) {
        _myBoard.removeShip(spec.id);
      }
      _selectedSpec = spec;
      _previewAnchor = null;
      _statusText = 'Colocando ${spec.name} (${spec.length} casillas)';
    });
  }

  void _randomizeFleet() {
    SfxService.instance.play(SfxType.place);
    setState(() {
      _myBoard.randomize();
      _selectedSpec = null;
      _previewAnchor = null;
      _statusText = '¡Formación aleatoria lista! Pulsa "A LA BATALLA".';
    });
  }

  void _clearFleet() {
    SfxService.instance.play(SfxType.select);
    setState(() {
      _myBoard.clear();
      _selectedSpec = kFleetSpecs.first;
      _previewAnchor = null;
      _statusText = 'Despliega tu flota en el tablero';
    });
  }

  void _confirmReady() {
    if (!_myBoard.allShipsPlaced) return;
    setState(() {
      _myReady = true;
      _previewAnchor = null;
      _phase = _GamePhase.waitingOpponentReady;
      _statusText = 'Esperando confirmación del comandante enemigo...';
      _tryStartBattle();
    });
    widget.transport.send(const ReadyMessage());
  }

  void _onEnemyCellTap(int row, int col) {
    if (_phase != _GamePhase.battle || !_isMyTurn || _awaitingResult) return;
    if (_enemyBoard.grid[row][col] != CellState.empty) return;

    SfxService.instance.play(SfxType.fire);
    setState(() {
      _targetedCell = (row, col);
      _awaitingResult = true;
      _statusText = '¡Fuego en curso! Esperando impacto...';
    });
    widget.transport.send(ShotMessage(row: row, col: col));
  }

  void _requestRematch() {
    widget.transport.send(const ResetMessage());
    setState(_resetLocalState);
  }

  void _resetLocalState() {
    _myBoard.clear();
    _enemyBoard.clear();
    _phase = _GamePhase.placing;
    _selectedSpec = kFleetSpecs.first;
    _previewAnchor = null;
    _myReady = false;
    _opponentReady = false;
    _awaitingResult = false;
    _didWin = null;
    _targetedCell = null;
    _lastEnemyShotOnMe = null;
    _lastMyShotOnEnemy = null;
    _activeBanner = null;
    _isMyTurn = widget.transport.isHost;
    _statusText = 'Despliega tu flota en el tablero';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        actions: const [TacticalAudioActions()],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Atmospheric ocean backdrop
          Image.asset(
            'assets/images/ocean_bg.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
          ),
          Container(color: NavalPalette.deepOcean.withValues(alpha: 0.72)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                children: [
                  // Gameloft-style dual health HUD
                  TacticalHealthHud(
                    myRemainingSegments: _myBoard.remainingSegments,
                    enemyRemainingSegments: _enemyBoard.remainingSegments,
                    myRemainingShips: _myBoard.remainingShipsCount,
                    enemyRemainingShips: _enemyBoard.remainingShipsCount,
                    isMyTurn: _isMyTurn,
                    inBattle: _phase == _GamePhase.battle,
                  ),
                  const SizedBox(height: 8),
                  // Compact tactical status strip
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1A2B).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _phase == _GamePhase.battle && _isMyTurn
                            ? NavalPalette.radarGreen
                            : NavalPalette.steelBorder,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      _statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _phase == _GamePhase.battle && _isMyTurn
                            ? NavalPalette.radarGreen
                            : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _phase == _GamePhase.placing ||
                            _phase == _GamePhase.waitingOpponentReady
                        ? _buildPlacementView()
                        : _buildBattleView(),
                  ),
                ],
              ),
            ),
          ),
          // Pop-up event banner (IMPACTO / AGUA / HUNDIDO)
          if (_activeBanner != null)
            TacticalEventBanner(
              title: _activeBanner!.title,
              subtitle: _activeBanner!.subtitle,
              kind: _activeBanner!.kind,
            ),
          // Full Victory / Defeat overlay
          if (_phase == _GamePhase.finished && _didWin != null)
            MissionEndOverlay(
              didWin: _didWin!,
              myRemainingShips: _myBoard.remainingShipsCount,
              enemySunkShips: _enemyBoard.sunkShipsCount,
              onRematch: _requestRematch,
              onExit: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

  Widget _buildPlacementView() {
    return Column(
      children: [
        // Interactive ship dock with pixel-art thumbnails
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kFleetSpecs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final spec = kFleetSpecs[index];
              final isPlaced = _myBoard.hasPlacedSpec(spec.id);
              final isSelected = _selectedSpec?.id == spec.id;

              return GestureDetector(
                onTap: _phase == _GamePhase.placing
                    ? () => _selectDockShip(spec)
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 96,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? NavalPalette.steelMid
                        : const Color(0xFF0C1C2D).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? NavalPalette.tacticalAmber
                          : (isPlaced
                              ? NavalPalette.radarGreen.withValues(alpha: 0.65)
                              : NavalPalette.steelBorder),
                      width: isSelected ? 2 : 1.1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Opacity(
                          opacity: isPlaced ? 0.45 : 1.0,
                          child: Image.asset(
                            spec.spritePath,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isPlaced)
                            const Padding(
                              padding: EdgeInsets.only(right: 3),
                              child: Icon(
                                Icons.check_circle,
                                size: 11,
                                color: NavalPalette.radarGreen,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              '${spec.name} (${spec.length})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? NavalPalette.tacticalAmber
                                    : Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Placement board with green/red ghost preview & drag support
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: BoardWidget(
                board: _myBoard,
                showShips: true,
                interactive:
                    _phase == _GamePhase.placing && _selectedSpec != null,
                onCellTap: _onPlacementCellTap,
                onCellHoverOrDrag: _onPlacementDrag,
                onDragEnd: _onPlacementDragEnd,
                placementPreview: _buildCurrentPreview(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_phase == _GamePhase.placing) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              TacticalButton(
                compact: true,
                label: _horizontal ? 'Horizontal' : 'Vertical',
                icon: Icons.rotate_right,
                accentColor: NavalPalette.cyanAccent,
                onPressed: _toggleOrientation,
              ),
              TacticalButton(
                compact: true,
                label: 'Aleatorio',
                icon: Icons.shuffle,
                accentColor: NavalPalette.tacticalAmber,
                onPressed: _randomizeFleet,
              ),
              TacticalButton(
                compact: true,
                label: 'Limpiar',
                icon: Icons.delete_outline,
                accentColor: NavalPalette.enemyRed,
                onPressed: _clearFleet,
              ),
              TacticalButton(
                compact: true,
                label: '¡A la Batalla!',
                icon: Icons.check_circle_outline,
                accentColor: NavalPalette.radarGreen,
                onPressed: _myBoard.allShipsPlaced ? _confirmReady : null,
              ),
            ],
          ),
        ] else
          const Padding(
            padding: EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: NavalPalette.radarGreen,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'ESPERANDO AL OPONENTE...',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: NavalPalette.radarGreen,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBattleView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.gps_fixed,
                size: 14,
                color: _isMyTurn ? NavalPalette.tacticalAmber : Colors.white38,
              ),
              const SizedBox(width: 6),
              Text(
                _isMyTurn
                    ? 'RADAR ENEMIGO — TOCA PARA DISPARAR'
                    : 'RADAR ENEMIGO — ESPERANDO TURNO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: _isMyTurn ? NavalPalette.tacticalAmber : Colors.white54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: BoardWidget(
              board: _enemyBoard,
              showShips: false,
              interactive: _phase == _GamePhase.battle && _isMyTurn,
              onCellTap: _onEnemyCellTap,
              targetedCell: _targetedCell,
              lastShotCell: _lastMyShotOnEnemy,
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield, size: 13, color: NavalPalette.playerBlue),
              SizedBox(width: 6),
              Text(
                'TU FLOTA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: NavalPalette.playerBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 270),
            child: BoardWidget(
              board: _myBoard,
              showShips: true,
              interactive: false,
              lastShotCell: _lastEnemyShotOnMe,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
