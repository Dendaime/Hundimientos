import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble/transport.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  final bool asHost;

  const LobbyScreen({super.key, required this.asHost});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  BleHostTransport? _hostTransport;
  BleClientTransport? _clientTransport;

  StreamSubscription<TransportStatus>? _statusSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  List<ScanResult> _results = [];

  String _statusMessage = 'Solicitando permisos de Bluetooth...';
  bool _hasError = false;
  bool _navigatedToGame = false;

  @override
  void initState() {
    super.initState();
    _initBle();
  }

  Future<void> _initBle() async {
    final granted = await requestBlePermissions();
    if (!mounted) return;
    if (!granted) {
      setState(() {
        _hasError = true;
        _statusMessage =
            'Permisos de Bluetooth denegados. Actívalos en Ajustes para jugar.';
      });
      return;
    }

    if (widget.asHost) {
      await _startHost();
    } else {
      await _startClientScan();
    }
  }

  Future<void> _startHost() async {
    final host = BleHostTransport();
    _hostTransport = host;
    _statusSub = host.statusStream.listen((status) {
      if (!mounted) return;
      if (status == TransportStatus.connected && !_navigatedToGame) {
        _navigatedToGame = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GameScreen(
              transport: host,
              title: 'Hundimientos (Host BLE)',
            ),
          ),
        );
      }
    });

    try {
      setState(() {
        _statusMessage = 'Anunciando partida por Bluetooth...\n'
            'Abre "Unirse a Partida" en el otro dispositivo.';
      });
      await host.startHosting();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _statusMessage = 'Error al iniciar Bluetooth Host: $e';
      });
    }
  }

  Future<void> _startClientScan() async {
    final client = BleClientTransport();
    _clientTransport = client;

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() => _results = results);
    });

    try {
      setState(() {
        _hasError = false;
        _statusMessage = 'Buscando partidas cercanas de Hundimientos...';
      });
      await client.startScan();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _statusMessage = 'Error al escanear Bluetooth: $e';
      });
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    final client = _clientTransport;
    if (client == null) return;

    setState(() {
      _hasError = false;
      _statusMessage = 'Conectando con ${device.platformName.isNotEmpty ? device.platformName : device.remoteId}...';
    });

    try {
      await client.connectTo(device);
      if (!mounted || _navigatedToGame) return;
      _navigatedToGame = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            transport: client,
            title: 'Hundimientos (Cliente BLE)',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _statusMessage = 'No se pudo conectar: $e';
      });
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _scanSub?.cancel();
    if (!_navigatedToGame) {
      _hostTransport?.dispose();
      _clientTransport?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.asHost ? 'Crear Partida BLE' : 'Unirse a Partida BLE'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: widget.asHost ? _buildHostView() : _buildClientView(),
        ),
      ),
    );
  }

  Widget _buildHostView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _hasError ? Icons.error_outline : Icons.bluetooth_searching,
            size: 72,
            color: _hasError ? Colors.redAccent : Colors.lightBlueAccent,
          ),
          const SizedBox(height: 20),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          if (!_hasError) const CircularProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildClientView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _statusMessage,
          style: TextStyle(
            fontSize: 15,
            color: _hasError ? Colors.redAccent : Colors.white70,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _results.isEmpty
              ? const Center(
                  child: Text(
                    'Aún no se detectan anfitriones cercanos.\nAsegúrate de que el otro dispositivo tenga Bluetooth encendido y esté en "Crear Partida".',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final r = _results[index];
                    final name = r.advertisementData.advName.isNotEmpty
                        ? r.advertisementData.advName
                        : (r.device.platformName.isNotEmpty
                            ? r.device.platformName
                            : 'Anfitrión Hundimientos');
                    return Card(
                      color: const Color(0xFF16324F),
                      child: ListTile(
                        leading: const Icon(Icons.bluetooth,
                            color: Colors.lightBlueAccent),
                        title: Text(name),
                        subtitle: Text('RSSI: ${r.rssi} dBm'),
                        trailing: FilledButton(
                          onPressed: () => _connect(r.device),
                          child: const Text('Conectar'),
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _startClientScan,
          icon: const Icon(Icons.refresh),
          label: const Text('Volver a escanear'),
        ),
      ],
    );
  }
}
