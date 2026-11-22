import 'dart:convert';
import 'dart:typed_data';

import '../game/models.dart';

/// Compact text protocol designed to fit within the default 20-byte BLE MTU.
///
/// Formats:
/// - Ready:       `RDY`
/// - Shot:        `S:r,c`
/// - Result:      `R:r,c,M` (Miss) | `R:r,c,H` (Hit)
/// - Sunk / Win:  `R:r,c,K,sr,sc,h,len` | `R:r,c,W,sr,sc,h,len`
/// - Reset:       `RST`
sealed class GameMessage {
  const GameMessage();

  String encode();

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(encode()));

  static GameMessage? decode(String raw) {
    final trimmed = raw.trim();
    if (trimmed == 'RDY') return const ReadyMessage();
    if (trimmed == 'RST') return const ResetMessage();

    if (trimmed.startsWith('S:')) {
      final parts = trimmed.substring(2).split(',');
      if (parts.length != 2) return null;
      final r = int.tryParse(parts[0]);
      final c = int.tryParse(parts[1]);
      if (r == null || c == null) return null;
      return ShotMessage(row: r, col: c);
    }

    if (trimmed.startsWith('R:')) {
      final parts = trimmed.substring(2).split(',');
      if (parts.length < 3) return null;
      final r = int.tryParse(parts[0]);
      final c = int.tryParse(parts[1]);
      final code = parts[2];
      if (r == null || c == null) return null;

      final outcome = switch (code) {
        'M' => ShotOutcome.miss,
        'H' => ShotOutcome.hit,
        'K' => ShotOutcome.sunk,
        'W' => ShotOutcome.win,
        _ => null,
      };
      if (outcome == null) return null;

      int? sr, sc, len;
      bool? horiz;
      if (parts.length >= 7) {
        sr = int.tryParse(parts[3]);
        sc = int.tryParse(parts[4]);
        horiz = parts[5] == '1';
        len = int.tryParse(parts[6]);
      }

      return ShotResultMessage(
        row: r,
        col: c,
        outcome: outcome,
        sunkRow: sr,
        sunkCol: sc,
        sunkHorizontal: horiz,
        sunkLength: len,
      );
    }

    return null;
  }

  static GameMessage? fromBytes(List<int> bytes) {
    try {
      return decode(utf8.decode(bytes));
    } catch (_) {
      return null;
    }
  }
}

class ReadyMessage extends GameMessage {
  const ReadyMessage();

  @override
  String encode() => 'RDY';
}

class ResetMessage extends GameMessage {
  const ResetMessage();

  @override
  String encode() => 'RST';
}

class ShotMessage extends GameMessage {
  final int row;
  final int col;

  const ShotMessage({required this.row, required this.col});

  @override
  String encode() => 'S:$row,$col';
}

class ShotResultMessage extends GameMessage {
  final int row;
  final int col;
  final ShotOutcome outcome;
  final int? sunkRow;
  final int? sunkCol;
  final bool? sunkHorizontal;
  final int? sunkLength;

  const ShotResultMessage({
    required this.row,
    required this.col,
    required this.outcome,
    this.sunkRow,
    this.sunkCol,
    this.sunkHorizontal,
    this.sunkLength,
  });

  @override
  String encode() {
    final code = switch (outcome) {
      ShotOutcome.miss => 'M',
      ShotOutcome.hit => 'H',
      ShotOutcome.sunk => 'K',
      ShotOutcome.win => 'W',
    };
    if ((outcome == ShotOutcome.sunk || outcome == ShotOutcome.win) &&
        sunkRow != null &&
        sunkCol != null &&
        sunkHorizontal != null &&
        sunkLength != null) {
      final h = sunkHorizontal! ? '1' : '0';
      return 'R:$row,$col,$code,$sunkRow,$sunkCol,$h,$sunkLength';
    }
    return 'R:$row,$col,$code';
  }
}
