import 'package:flutter_test/flutter_test.dart';
import 'package:hundimientos/ble/protocol.dart';
import 'package:hundimientos/game/game_board.dart';
import 'package:hundimientos/game/models.dart';

void main() {
  group('GameBoard', () {
    test('places ships and detects hit, sunk, and win', () {
      final board = GameBoard();
      const destroyer = ShipSpec(id: 'destroyer', name: 'Destructor', length: 2);

      expect(board.placeShip(destroyer, 0, 0, true), isTrue);
      // Overlapping placement must fail
      expect(board.placeShip(destroyer, 0, 1, false), isFalse);

      final miss = board.receiveShot(5, 5);
      expect(miss.outcome, ShotOutcome.miss);

      final hit = board.receiveShot(0, 0);
      expect(hit.outcome, ShotOutcome.hit);

      final win = board.receiveShot(0, 1);
      expect(win.outcome, ShotOutcome.win);
      expect(board.allShipsSunk, isTrue);
    });

    test('randomize places full fleet without overlaps', () {
      final board = GameBoard();
      board.randomize();
      expect(board.allShipsPlaced, isTrue);
      expect(board.ships.length, kFleetSpecs.length);
    });
  });

  group('BLE Protocol', () {
    test('encodes and decodes messages within 20 bytes', () {
      final messages = <GameMessage>[
        const ReadyMessage(),
        const ResetMessage(),
        const ShotMessage(row: 9, col: 9),
        const ShotResultMessage(row: 4, col: 7, outcome: ShotOutcome.hit),
        const ShotResultMessage(
          row: 9,
          col: 9,
          outcome: ShotOutcome.win,
          sunkRow: 9,
          sunkCol: 5,
          sunkHorizontal: true,
          sunkLength: 5,
        ),
      ];

      for (final msg in messages) {
        final bytes = msg.toBytes();
        expect(bytes.length, lessThanOrEqualTo(20));
        final decoded = GameMessage.fromBytes(bytes);
        expect(decoded, isNotNull);
        expect(decoded!.encode(), msg.encode());
      }
    });
  });
}
