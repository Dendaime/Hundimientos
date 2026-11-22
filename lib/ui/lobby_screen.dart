import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../audio/sfx_service.dart';
import '../ble/transport.dart';
import 'game_screen.dart';
import 'tactical_widgets.dart';

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
        SfxService.instance.play(SfxType.place);
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
        _statusMessage = 'Transmitiendo señal de radar Bluetooth...\n'
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
        _statusMessage = 'Escaneando frecuencias Bluetooth cercanas...';
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

    SfxService.instance.play(SfxType.select);
    setState(() {
      _hasError = false;
      _statusMessage =
          'Enlazando con ${device.platformName.isNotEmpty ? device.platformName : device.remoteId}...';
    });

    try {
      await client.connectTo(device);
      if (!mounted || _navigatedToGame) return;
      _navigatedToGame = true;
      SfxService.instance.play(SfxType.place);
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
        title: Text(
          widget.asHost ? 'RADAR HOST BLE' : 'ESCANEAR FLOTAS BLE',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        actions: const [TacticalAudioActions()],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/ocean_bg.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
          ),
          Container(color: NavalPalette.deepOcean.withValues(alpha: 0.78)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: widget.asHost ? _buildHostView() : _buildClientView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostView() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1E30).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hasError ? NavalPalette.enemyRed : NavalPalette.radarGreen,
              width: 1.8,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _hasError ? Icons.error_outline : Icons.radar,
                size: 72,
                color:
                    _hasError ? NavalPalette.enemyRed : NavalPalette.radarGreen,
              ),
              const SizedBox(height: 18),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              if (!_hasError)
                const CircularProgressIndicator(color: NavalPalette.radarGreen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1E30).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hasError ? NavalPalette.enemyRed : NavalPalette.cyanAccent,
            ),
          ),
          child: Text(
            _statusMessage,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _hasError ? NavalPalette.enemyRed : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _results.isEmpty
              ? const Center(
                  child: Text(
                    'Aún no se detectan anfitriones cercanos.\nAsegúrate de que el otro dispositivo tenga Bluetooth encendido y esté en "Crear Partida".',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60),
                  ),
                )
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final r = _results[index];
                    final name = r.advertisementData.advName.isNotEmpty
                        ? r.advertisementData.advName
                        : (r.device.platformName.isNotEmpty
                            ? r.device.platformName
                            : 'Anfitrión Hundimientos');
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF10263C).withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: NavalPalette.cyanAccent.withValues(alpha: 0.7),
                        ),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.radar,
                          color: NavalPalette.radarGreen,
                          size: 28,
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          'Señal: ${r.rssi} dBm',
                          style: const TextStyle(color: Colors.white60),
                        ),
                        trailing: TacticalButton(
                          compact: true,
                          label: 'Conectar',
                          icon: Icons.link,
                          accentColor: NavalPalette.radarGreen,
                          onPressed: () => _connect(r.device),
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        TacticalButton(
          label: 'Volver a escanear',
          icon: Icons.refresh,
          accentColor: NavalPalette.cyanAccent,
          onPressed: _startClientScan,
        ),
      ],
    );
  }
}
