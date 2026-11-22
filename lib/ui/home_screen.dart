import 'package:flutter/material.dart';

import '../ble/transport.dart';
import 'game_screen.dart';
import 'lobby_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.directions_boat_filled,
                    size: 76,
                    color: Colors.lightBlueAccent,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'HUNDIMIENTOS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Batalla Naval local por Bluetooth (Android ↔ iOS)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 40),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LobbyScreen(asHost: true),
                        ),
                      );
                    },
                    icon: const Icon(Icons.bluetooth_audio),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Crear Partida (Host BLE)'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LobbyScreen(asHost: false),
                        ),
                      );
                    },
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Unirse a Partida (Cliente BLE)'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GameScreen(
                            transport: BotTransport(),
                            title: 'Hundimientos (vs Bot)',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.smart_toy_outlined),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Probar en solitario vs Bot'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
