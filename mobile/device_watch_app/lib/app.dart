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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF185FA5)),
        useMaterial3: true,
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
