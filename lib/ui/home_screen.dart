import 'package:flutter/material.dart';

import '../ble/transport.dart';
import 'game_screen.dart';
import 'lobby_screen.dart';
import 'tactical_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [TacticalAudioActions()],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Generated pixel-art naval warfare harbor background
          Image.asset(
            'assets/images/home_bg.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
          ),
          // Gradient overlay to keep menu razor-sharp and legible
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  NavalPalette.deepOcean.withValues(alpha: 0.30),
                  NavalPalette.deepOcean.withValues(alpha: 0.65),
                  NavalPalette.deepOcean.withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),
                      // Pixel-art warship showcase emblem
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: NavalPalette.deepOcean.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: NavalPalette.radarGreen.withValues(alpha: 0.7),
                              width: 1.6,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: NavalPalette.radarGreen
                                    .withValues(alpha: 0.25),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 52,
                                child: Image.asset(
                                  'assets/images/ships/battleship.png',
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.none,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'HUNDIMIENTOS',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3.2,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: NavalPalette.radarGreen,
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'COMANDO NAVAL BLUETOOTH • ANDROID ↔ iOS',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                  color: NavalPalette.radarGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(flex: 2),
                      TacticalButton(
                        label: 'Crear Partida',
                        subtitle: 'Anunciar sala como Host Bluetooth (BLE)',
                        icon: Icons.bluetooth_audio,
                        accentColor: NavalPalette.radarGreen,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LobbyScreen(asHost: true),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TacticalButton(
                        label: 'Unirse a Partida',
                        subtitle: 'Escanear y conectar como Cliente BLE',
                        icon: Icons.bluetooth_searching,
                        accentColor: NavalPalette.cyanAccent,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LobbyScreen(asHost: false),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TacticalButton(
                        label: 'Entrenamiento vs Bot',
                        subtitle: 'Combate offline contra la IA naval',
                        icon: Icons.smart_toy_outlined,
                        accentColor: NavalPalette.tacticalAmber,
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
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
