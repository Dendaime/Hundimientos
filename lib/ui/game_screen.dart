import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/bgm_service.dart';
import '../ble/protocol.dart';
import '../ble/transport.dart';
import '../game/game_board.dart';
import '../game/models.dart';
import 'board_widget.dart';

enum _GamePhase {
  placing,
  waitingOpponentReady,
  battle,
  finished,
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
  int _nextShipIndex = 0;

  bool _myReady = false;
  bool _opponentReady = false;
  bool _isMyTurn = false;
  bool _awaitingResult = false;
  bool? _didWin;
  String _statusText = 'Coloca tu flota en el tablero';

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
          const SnackBar(content: Text('El otro jugador se desconectó.')),
        );
      }
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _statusSub?.cancel();
    widget.transport.dispose();
    super.dispose();
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
        if (result.outcome == ShotOutcome.win) {
          _phase = _GamePhase.finished;
          _didWin = false;
          _statusText = '¡Derrota! Hundieron toda tu flota.';
        } else {
          _isMyTurn = true;
          _statusText = switch (result.outcome) {
            ShotOutcome.miss => 'El enemigo falló. ¡Tu turno!',
            ShotOutcome.hit => '¡Te dieron! Tu turno.',
            ShotOutcome.sunk =>
              '¡Hundieron tu ${result.sunkShip?.spec.name ?? "barco"}! Tu turno.',
            ShotOutcome.win => 'Derrota',
          };
        }
      } else if (msg is ShotResultMessage) {
        _awaitingResult = false;
        _enemyBoard.recordTrackingResult(
          msg.row,
          msg.col,
          msg.outcome,
          sunkRow: msg.sunkRow,
          sunkCol: msg.sunkCol,
          sunkHorizontal: msg.sunkHorizontal,
          sunkLength: msg.sunkLength,
        );
        if (msg.outcome == ShotOutcome.win) {
          _phase = _GamePhase.finished;
          _didWin = true;
          _statusText = '¡Victoria! Hundiste toda la flota enemiga.';
        } else {
          _isMyTurn = false;
          _statusText = switch (msg.outcome) {
            ShotOutcome.miss => 'Agua. Turno del oponente...',
            ShotOutcome.hit => '¡Tocado! Turno del oponente...',
            ShotOutcome.sunk => '¡Hundido! Turno del oponente...',
            ShotOutcome.win => '¡Victoria!',
          };
        }
      }
    });
  }

  void _tryStartBattle() {
    if (_myReady && _opponentReady) {
      _phase = _GamePhase.battle;
      _isMyTurn = widget.transport.isHost;
      _statusText =
          _isMyTurn ? '¡Tu turno! Dispara al tablero enemigo.' : 'Turno del oponente...';
    }
  }

  void _onPlacementTap(int row, int col) {
    if (_nextShipIndex >= kFleetSpecs.length) return;
    final spec = kFleetSpecs[_nextShipIndex];
    if (_myBoard.placeShip(spec, row, col, _horizontal)) {
      setState(() {
        _nextShipIndex++;
        if (_nextShipIndex >= kFleetSpecs.length) {
          _statusText = 'Flota lista. Pulsa "¡Listo!" para comenzar.';
        }
      });
    }
  }

  void _randomizeFleet() {
    setState(() {
      _myBoard.randomize();
      _nextShipIndex = kFleetSpecs.length;
      _statusText = 'Flota aleatoria lista. Pulsa "¡Listo!" para comenzar.';
    });
  }

  void _clearFleet() {
    setState(() {
      _myBoard.clear();
      _nextShipIndex = 0;
      _statusText = 'Coloca tu flota en el tablero';
    });
  }

  void _confirmReady() {
    if (!_myBoard.allShipsPlaced) return;
    setState(() {
      _myReady = true;
      _phase = _GamePhase.waitingOpponentReady;
      _statusText = 'Esperando a que el otro jugador esté listo...';
      _tryStartBattle();
    });
    widget.transport.send(const ReadyMessage());
  }

  void _onEnemyCellTap(int row, int col) {
    if (_phase != _GamePhase.battle || !_isMyTurn || _awaitingResult) return;
    if (_enemyBoard.grid[row][col] != CellState.empty) return;

    setState(() {
      _awaitingResult = true;
      _statusText = 'Disparando...';
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
    _nextShipIndex = 0;
    _myReady = false;
    _opponentReady = false;
    _awaitingResult = false;
    _didWin = null;
    _isMyTurn = widget.transport.isHost;
    _statusText = 'Coloca tu flota en el tablero';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: BgmService.instance.isMuted,
            builder: (context, muted, _) {
              return IconButton(
                tooltip: muted ? 'Activar música' : 'Silenciar música',
                icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
                onPressed: BgmService.instance.toggleMute,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              // Status banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _bannerColor(),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
    );
  }

  Color _bannerColor() {
    if (_phase == _GamePhase.finished) {
      return _didWin == true ? Colors.green.shade800 : Colors.red.shade900;
    }
    if (_phase == _GamePhase.battle && _isMyTurn) {
      return Colors.teal.shade800;
    }
    return const Color(0xFF16324F);
  }

  Widget _buildPlacementView() {
    final currentSpec = _nextShipIndex < kFleetSpecs.length
        ? kFleetSpecs[_nextShipIndex]
        : null;

    return Column(
      children: [
        if (currentSpec != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Colocando: ${currentSpec.name} (${currentSpec.length} casillas) — ${_horizontal ? "Horizontal" : "Vertical"}',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: BoardWidget(
                board: _myBoard,
                showShips: true,
                interactive: _phase == _GamePhase.placing && currentSpec != null,
                onCellTap: _onPlacementTap,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_phase == _GamePhase.placing)
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _horizontal = !_horizontal),
                icon: const Icon(Icons.rotate_right),
                label: Text(_horizontal ? 'Horizontal' : 'Vertical'),
              ),
              OutlinedButton.icon(
                onPressed: _randomizeFleet,
                icon: const Icon(Icons.shuffle),
                label: const Text('Aleatorio'),
              ),
              OutlinedButton.icon(
                onPressed: _clearFleet,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Limpiar'),
              ),
              FilledButton.icon(
                onPressed: _myBoard.allShipsPlaced ? _confirmReady : null,
                icon: const Icon(Icons.check),
                label: const Text('¡Listo!'),
              ),
            ],
          )
        else
          const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildBattleView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const Text(
            'TABLERO ENEMIGO (Toca para disparar)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: Colors.amberAccent,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: BoardWidget(
              board: _enemyBoard,
              showShips: false,
              interactive: _phase == _GamePhase.battle && _isMyTurn,
              onCellTap: _onEnemyCellTap,
            ),
          ),
          const SizedBox(height: 16),
          if (_phase == _GamePhase.finished) ...[
            FilledButton.icon(
              onPressed: _requestRematch,
              icon: const Icon(Icons.replay),
              label: const Text('Revancha'),
            ),
            const SizedBox(height: 16),
          ],
          const Text(
            'TU FLOTA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: BoardWidget(
              board: _myBoard,
              showShips: true,
              interactive: false,
            ),
          ),
        ],
      ),
    );
  }
}
