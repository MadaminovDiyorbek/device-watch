import 'package:flutter/material.dart';

import 'prefs.dart';
import 'screens/monitor_screen.dart';
import 'screens/setup_screen.dart';

class DeviceWatchApp extends StatelessWidget {
  const DeviceWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeviceWatch',
      themeMode: ThemeMode.dark,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C7BE5),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F1115),
        cardColor: const Color(0xFF171A21),
      ),
      home: FutureBuilder<Prefs>(
        future: Prefs.load(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return Scaffold(
              body: Center(child: Text('Xato: ${snap.error}')),
            );
          }
          final p = snap.data!;
          return p.hasToken ? MonitorScreen(prefs: p) : SetupScreen(initial: p);
        },
      ),
    );
  }
}
