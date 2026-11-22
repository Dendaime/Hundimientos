import 'package:flutter/material.dart';

import 'ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HundimientosApp());
}

class HundimientosApp extends StatelessWidget {
  const HundimientosApp({super.key});

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
