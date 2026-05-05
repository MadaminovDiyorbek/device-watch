import 'dart:async';

import 'package:flutter/material.dart';

import '../prefs.dart';
import '../services/cloud_service.dart';
import '../services/metrics_service.dart';
import 'setup_screen.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key, required this.prefs});

  final Prefs prefs;

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  static const _hbSec = 5;
  Timer? _timer;
  late final MetricsService _metrics;
  Map<String, dynamic> _last = {};
  String _status = '—';

  @override
  void initState() {
    super.initState();
    _metrics = MetricsService(widget.prefs.deviceName);
    _tick();
    _timer = Timer.periodic(const Duration(seconds: _hbSec), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    final tok = widget.prefs.deviceToken;
    if (tok == null || tok.isEmpty) return;
    try {
      final body = await _metrics.collect(heartbeatSec: _hbSec);
      await CloudService(widget.prefs.serverUrl).heartbeat(tok, body);
      if (!mounted) return;
      setState(() {
        _last = body;
        _status = DateTime.now().toLocal().toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Xato: $e');
    }
  }

  Future<void> _logout() async {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    await Prefs.clearToken();
    if (!mounted) return;
    final p = await Prefs.load();
    if (!mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => SetupScreen(initial: p)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('DeviceWatch'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ko\'rsatkichlar'),
              Tab(text: 'Ma\'lumot'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(12),
              children: [
                ListTile(
                  title: const Text('Oxirgi yuborish'),
                  subtitle: Text(_status),
                ),
                ListTile(
                  title: const Text('CPU'),
                  subtitle: Text(
                    '${_last['cpuUsage'] ?? 0}% — ${_last['cpuModel'] ?? '—'}',
                  ),
                ),
                ListTile(
                  title: const Text('RAM'),
                  subtitle: Text(
                    '${_last['ramUsedGb'] ?? '—'} / ${_last['ramTotalGb'] ?? '—'} GB',
                  ),
                ),
                ListTile(
                  title: const Text('Disk'),
                  subtitle: Text(
                    '${_last['diskUsedGb'] ?? '—'} / ${_last['diskTotalGb'] ?? '—'} GB',
                  ),
                ),
                ListTile(
                  title: const Text('Batareya'),
                  subtitle: Text(
                    '${_last['batteryPercent'] ?? '—'}% ${_last['batteryState'] ?? ''}',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: _logout,
                  child: const Text('Tokenni o\'chirish'),
                ),
              ],
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(_last['specs']?.toString() ?? '{}'),
            ),
          ],
        ),
      ),
    );
  }
}
