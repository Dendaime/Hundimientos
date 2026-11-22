import 'package:flutter/material.dart';

import 'audio/bgm_service.dart';
import 'ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HundimientosApp());
}

class HundimientosApp extends StatefulWidget {
  const HundimientosApp({super.key});

  @override
  State<HundimientosApp> createState() => _HundimientosAppState();
}

class _HundimientosAppState extends State<HundimientosApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BgmService.instance.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      BgmService.instance.pause();
    } else if (state == AppLifecycleState.resumed) {
      BgmService.instance.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hundimientos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.lightBlue,
        scaffoldBackgroundColor: const Color(0xFF081B2E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0C243D),
          centerTitle: true,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
