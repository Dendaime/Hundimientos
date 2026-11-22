import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'
    hide CharacteristicProperties;
import 'package:permission_handler/permission_handler.dart';

import '../game/game_board.dart';
import '../game/models.dart';
import 'protocol.dart';

/// Custom 128-bit UUIDs for Hundimientos BLE GATT service.
/// Uppercase is required because iOS CoreBluetooth `CBUUID.uuidString` is uppercase
/// and `ble_peripheral` uses exact string comparison.
const String kGameServiceUuid = '7A1B0001-4C2D-4E3F-9A5B-6C7D8E9F0001';

/// Host -> Client (Notify)
const String kTxCharUuid = '7A1B0002-4C2D-4E3F-9A5B-6C7D8E9F0001';

/// Client -> Host (Write)
const String kRxCharUuid = '7A1B0003-4C2D-4E3F-9A5B-6C7D8E9F0001';

enum TransportStatus {
  idle,
  advertising,
  scanning,
  connecting,
  connected,
  disconnected,
  error,
}

abstract class GameTransport {
  bool get isHost;
  Stream<GameMessage> get incomingMessages;
  Stream<TransportStatus> get statusStream;
  TransportStatus get currentStatus;

  Future<void> send(GameMessage message);
  Future<void> dispose();
}

/// Requests runtime Bluetooth permissions on Android and iOS.
Future<bool> requestBlePermissions() async {
  if (Platform.isAndroid) {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();
    return statuses[Permission.bluetoothScan]?.isGranted == true ||
        statuses[Permission.bluetoothConnect]?.isGranted == true;
  } else if (Platform.isIOS) {
    final status = await Permission.bluetooth.request();
    return status.isGranted || status.isLimited;
  }
  return true;
}

/// BLE Peripheral (Host) implementation using `ble_peripheral`.
class BleHostTransport implements GameTransport {
  final _messageController = StreamController<GameMessage>.broadcast();
  final _statusController = StreamController<TransportStatus>.broadcast();
  TransportStatus _status = TransportStatus.idle;
  String? _connectedDeviceId;

  @override
  bool get isHost => true;

  @override
  Stream<GameMessage> get incomingMessages => _messageController.stream;

  @override
  Stream<TransportStatus> get statusStream => _statusController.stream;

  @override
  TransportStatus get currentStatus => _status;

  void _setStatus(TransportStatus status) {
    _status = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  Future<void> startHosting({String localName = 'Hundimientos'}) async {
    try {
      await BlePeripheral.initialize();
      await BlePeripheral.clearServices();

      BlePeripheral.setConnectionStateChangeCallback(
        (String deviceId, bool connected) {
          if (connected) {
            _connectedDeviceId = deviceId;
            _setStatus(TransportStatus.connected);
          } else {
            _connectedDeviceId = null;
            _setStatus(TransportStatus.disconnected);
          }
        },
      );

      BlePeripheral.setCharacteristicSubscriptionChangeCallback(
        (String deviceId, String characteristicId, bool isSubscribed,
            String? name) {
          if (isSubscribed) {
            _connectedDeviceId = deviceId;
            _setStatus(TransportStatus.connected);
          } else if (_connectedDeviceId == deviceId) {
            _connectedDeviceId = null;
            _setStatus(TransportStatus.disconnected);
          }
        },
      );

      BlePeripheral.setWriteRequestCallback(
        (String deviceId, String characteristicId, int offset, value) {
          if (value != null) {
            final msg = GameMessage.fromBytes(value);
            if (msg != null && !_messageController.isClosed) {
              _messageController.add(msg);
            }
          }
          return WriteRequestResult(status: 0);
        },
      );

      await BlePeripheral.addService(
        BleService(
          uuid: kGameServiceUuid,
          primary: true,
          characteristics: [
            BleCharacteristic(
              uuid: kTxCharUuid,
              properties: [
                CharacteristicProperties.notify.index,
                CharacteristicProperties.read.index,
              ],
              permissions: [
                AttributePermissions.readable.index,
              ],
            ),
            BleCharacteristic(
              uuid: kRxCharUuid,
              properties: [
                CharacteristicProperties.write.index,
                CharacteristicProperties.writeWithoutResponse.index,
              ],
              permissions: [
                AttributePermissions.writeable.index,
              ],
            ),
          ],
        ),
      );

      await BlePeripheral.startAdvertising(
        services: [kGameServiceUuid],
        localName: localName,
      );
      _setStatus(TransportStatus.advertising);
    } catch (_) {
      _setStatus(TransportStatus.error);
      rethrow;
    }
  }

  @override
  Future<void> send(GameMessage message) async {
    await BlePeripheral.updateCharacteristic(
      characteristicId: kTxCharUuid,
      value: message.toBytes(),
      deviceId: _connectedDeviceId,
    );
  }

  @override
  Future<void> dispose() async {
    try {
      await BlePeripheral.stopAdvertising();
      await BlePeripheral.clearServices();
    } catch (_) {}
    await _messageController.close();
    await _statusController.close();
  }
}

/// BLE Central (Client) implementation using `flutter_blue_plus`.
class BleClientTransport implements GameTransport {
  final _messageController = StreamController<GameMessage>.broadcast();
  final _statusController = StreamController<TransportStatus>.broadcast();
  TransportStatus _status = TransportStatus.idle;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxChar;
  StreamSubscription<List<int>>? _txSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  @override
  bool get isHost => false;

  @override
  Stream<GameMessage> get incomingMessages => _messageController.stream;

  @override
  Stream<TransportStatus> get statusStream => _statusController.stream;

  @override
  TransportStatus get currentStatus => _status;

  void _setStatus(TransportStatus status) {
    _status = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  Future<void> startScan() async {
    _setStatus(TransportStatus.scanning);
    await FlutterBluePlus.startScan(
      withServices: [Guid(kGameServiceUuid)],
      timeout: const Duration(seconds: 15),
    );
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<void> connectTo(BluetoothDevice device) async {
    try {
      _setStatus(TransportStatus.connecting);
      await FlutterBluePlus.stopScan();
      _device = device;

      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 12),
      );

      _connSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _setStatus(TransportStatus.disconnected);
        }
      });

      final services = await device.discoverServices();
      BluetoothCharacteristic? txChar;
      BluetoothCharacteristic? rxChar;

      for (final s in services) {
        if (s.uuid.str.toLowerCase() == kGameServiceUuid.toLowerCase()) {
          for (final c in s.characteristics) {
            final id = c.uuid.str.toLowerCase();
            if (id == kTxCharUuid.toLowerCase()) txChar = c;
            if (id == kRxCharUuid.toLowerCase()) rxChar = c;
          }
        }
      }

      if (txChar == null || rxChar == null) {
        throw StateError('Servicio GATT de Hundimientos no encontrado.');
      }

      _rxChar = rxChar;
      await txChar.setNotifyValue(true);
      _txSub = txChar.onValueReceived.listen((bytes) {
        final msg = GameMessage.fromBytes(bytes);
        if (msg != null && !_messageController.isClosed) {
          _messageController.add(msg);
        }
      });

      _setStatus(TransportStatus.connected);
    } catch (_) {
      _setStatus(TransportStatus.error);
      rethrow;
    }
  }

  @override
  Future<void> send(GameMessage message) async {
    final rx = _rxChar;
    if (rx == null) return;
    await rx.write(
      message.toBytes(),
      withoutResponse: rx.properties.writeWithoutResponse &&
          !rx.properties.write,
    );
  }

  @override
  Future<void> dispose() async {
    await _txSub?.cancel();
    await _connSub?.cancel();
    try {
      await FlutterBluePlus.stopScan();
      await _device?.disconnect();
    } catch (_) {}
    await _messageController.close();
    await _statusController.close();
  }
}

/// Local offline bot transport so the player can test/play solo without BLE.
class BotTransport implements GameTransport {
  final _messageController = StreamController<GameMessage>.broadcast();
  final _statusController = StreamController<TransportStatus>.broadcast();
  final _botBoard = GameBoard();
  final _rng = Random();
  final Set<String> _shotsFired = {};
  bool _disposed = false;

  BotTransport() {
    _botBoard.randomize(_rng);
  }

  @override
  bool get isHost => true;

  @override
  Stream<GameMessage> get incomingMessages => _messageController.stream;

  @override
  Stream<TransportStatus> get statusStream => _statusController.stream;

  @override
  TransportStatus get currentStatus => TransportStatus.connected;

  @override
  Future<void> send(GameMessage message) async {
    if (_disposed) return;

    if (message is ReadyMessage) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (!_disposed) _messageController.add(const ReadyMessage());
    } else if (message is ResetMessage) {
      _botBoard.randomize(_rng);
      _shotsFired.clear();
      await Future.delayed(const Duration(milliseconds: 200));
      if (!_disposed) _messageController.add(const ResetMessage());
    } else if (message is ShotMessage) {
      final result = _botBoard.receiveShot(message.row, message.col);
      await Future.delayed(const Duration(milliseconds: 300));
      if (_disposed) return;

      _messageController.add(
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

      // Bot fires back if the player didn't just win.
      if (result.outcome != ShotOutcome.win) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (_disposed) return;
        final (r, c) = _pickNextBotShot();
        _messageController.add(ShotMessage(row: r, col: c));
      }
    }
  }

  (int, int) _pickNextBotShot() {
    while (true) {
      final r = _rng.nextInt(kBoardSize);
      final c = _rng.nextInt(kBoardSize);
      final key = '$r,$c';
      if (_shotsFired.add(key)) return (r, c);
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _messageController.close();
    await _statusController.close();
  }
}
