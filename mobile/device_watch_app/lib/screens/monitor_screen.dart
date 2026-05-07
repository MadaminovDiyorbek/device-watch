import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

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
  int? _pingMs;

  int _nav = 0;

  // history (last ~30 points)
  final List<double> _cpuHist = [];
  final List<double> _upHist = [];
  final List<double> _downHist = [];

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

  void _pushHist({
    required List<double> list,
    required double value,
    int maxLen = 30,
  }) {
    list.add(value);
    if (list.length > maxLen) {
      list.removeRange(0, list.length - maxLen);
    }
  }

  Future<void> _tick() async {
    final tok = widget.prefs.deviceToken;
    if (tok == null || tok.isEmpty) return;
    try {
      final body = await _metrics.collect(heartbeatSec: _hbSec);
      final ping = await CloudService(widget.prefs.serverUrl).pingMs();
      await CloudService(widget.prefs.serverUrl).heartbeat(tok, body);
      if (!mounted) return;
      setState(() {
        _last = body;
        _pingMs = ping;
        _status = DateTime.now().toLocal().toString();

        _pushHist(list: _cpuHist, value: (body['cpuUsage'] ?? 0).toDouble());
        _pushHist(list: _upHist, value: (body['netUpMbps'] ?? 0).toDouble());
        _pushHist(list: _downHist, value: (body['netDownMbps'] ?? 0).toDouble());
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

  String _deviceName() => (_last['hostname'] ?? widget.prefs.deviceName).toString().trim().isEmpty
      ? 'Qurilma'
      : (_last['hostname'] ?? widget.prefs.deviceName).toString();

  String _osLine() => (_last['specs']?['os'] ?? _last['osString'] ?? '').toString();
  String _ipLine() => (_last['specs']?['ip'] ?? '').toString();

  Widget _pill(String text, {Color? bg, Color? fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? const Color(0xFF1D9E75).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: fg ?? const Color(0xFFBFF5E3),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(14),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF171A21),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF232736)),
      ),
      child: child,
    );
  }

  Widget _metricTile({
    required String label,
    required String value,
    String? sub,
    Color? accent,
  }) {
    final c = accent ?? const Color(0xFF2C7BE5);
    return _card(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF97A0B3))),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 12, color: Color(0xFFB8C0D6))),
          ],
        ],
      ),
    );
  }

  Widget _lineChart(List<double> data, {double maxY = 100, Color color = const Color(0xFFFFB020)}) {
    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i]));
    }
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            spots: spots,
            barWidth: 2,
            color: color,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Widget _header() {
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF232736),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.phone_android, color: Color(0xFFB8C0D6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _deviceName(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [_osLine(), _ipLine()].where((e) => e.trim().isNotEmpty).join(' • '),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF97A0B3)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              _pill('Jonli'),
              const SizedBox(height: 8),
              _pill('Online', bg: const Color(0xFF1D9E75).withValues(alpha: 0.16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pageMetrics() {
    final cpu = (_last['cpuUsage'] ?? 0).toDouble();
    final cpuModel = (_last['cpuModel'] ?? '—').toString();
    final ram = (_last['ramPercent'] ?? 0).toDouble();
    final ramUsed = (_last['ramUsedGb'] ?? 0).toDouble();
    final ramTotal = (_last['ramTotalGb'] ?? 0).toDouble();
    final disk = (_last['diskPercent'] ?? 0).toDouble();
    final diskUsed = (_last['diskUsedGb'] ?? 0).toDouble();
    final diskTotal = (_last['diskTotalGb'] ?? 0).toDouble();
    final bat = (_last['batteryPercent'] ?? 0).toDouble();
    final batState = (_last['batteryState'] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _header(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricTile(
                label: 'CPU',
                value: '${cpu.toStringAsFixed(0)}%',
                sub: cpuModel,
                accent: const Color(0xFFFFB020),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricTile(
                label: 'RAM',
                value: '${ram.toStringAsFixed(0)}%',
                sub: '${ramUsed.toStringAsFixed(1)} / ${ramTotal.toStringAsFixed(0)} GB',
                accent: const Color(0xFF4CE39A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _metricTile(
                label: 'XOTIRA',
                value: '${disk.toStringAsFixed(0)}%',
                sub: '${diskUsed.toStringAsFixed(0)} / ${diskTotal.toStringAsFixed(0)} GB',
                accent: const Color(0xFF2C7BE5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricTile(
                label: 'BATAREYA',
                value: '${bat.toStringAsFixed(0)}%',
                sub: batState,
                accent: const Color(0xFFB07CFF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CPU TARIXI (SO\'NGGI 30 SONIYA)',
                style: TextStyle(fontSize: 11, color: Color(0xFF97A0B3), fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              SizedBox(height: 140, child: _lineChart(_cpuHist, maxY: 100, color: const Color(0xFFFFB020))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          child: Row(
            children: [
              const Icon(Icons.cloud_done, color: Color(0xFFB8C0D6)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cloud serverga ulanish', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${Uri.tryParse(widget.prefs.serverUrl)?.host ?? widget.prefs.serverUrl} • ${_pingMs ?? '—'} ms',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF97A0B3)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _pill('Aktiv', bg: const Color(0xFF2C7BE5).withValues(alpha: 0.20), fg: const Color(0xFFBBD8FF)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pageNetwork() {
    final upNow = (_last['netUpMbps'] ?? 0).toDouble();
    final downNow = (_last['netDownMbps'] ?? 0).toDouble();
    final upTot = (_last['netTotalUpGb'] ?? 0).toDouble();
    final downTot = (_last['netTotalDownGb'] ?? 0).toDouble();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _header(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricTile(
                label: 'Yuklash',
                value: '${upNow.toStringAsFixed(1)} Mb/s',
                sub: 'Bugun: ${upTot.toStringAsFixed(1)} GB',
                accent: const Color(0xFF2C7BE5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricTile(
                label: 'Yuklab olish',
                value: '${downNow.toStringAsFixed(1)} Mb/s',
                sub: 'Bugun: ${downTot.toStringAsFixed(1)} GB',
                accent: const Color(0xFF4CE39A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TRAFIK GRAFIGI',
                style: TextStyle(fontSize: 11, color: Color(0xFF97A0B3), fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 140,
                child: Stack(
                  children: [
                    _lineChart(_downHist, maxY: math.max(10, _downHist.fold<double>(0, math.max)) + 2, color: const Color(0xFF4CE39A)),
                    _lineChart(_upHist, maxY: math.max(10, _upHist.fold<double>(0, math.max)) + 2, color: const Color(0xFF2C7BE5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          child: Row(
            children: [
              const Icon(Icons.cloud_sync, color: Color(0xFFB8C0D6)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cloud serverga ulanish', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${Uri.tryParse(widget.prefs.serverUrl)?.host ?? widget.prefs.serverUrl} • ${_pingMs ?? '—'} ms',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF97A0B3)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _pill('Aktiv', bg: const Color(0xFF2C7BE5).withValues(alpha: 0.20), fg: const Color(0xFFBBD8FF)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pageInfo() {
    final specs = (_last['specs'] as Map?)?.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')) ?? {};
    final rows = <MapEntry<String, String>>[
      MapEntry('Qurilma', _deviceName()),
      MapEntry('OS', (specs['os'] ?? _osLine()).toString()),
      MapEntry('Protsessor', (specs['cpu'] ?? (_last['cpuModel'] ?? '')).toString()),
      MapEntry('RAM', (specs['ram'] ?? '').toString()),
      MapEntry('Xotira', (specs['disk'] ?? '').toString()),
      MapEntry('IP manzil', (specs['ip'] ?? '').toString()),
      MapEntry('Tarmoq', (specs['tarmoq'] ?? '').toString()),
      MapEntry('Joylashuv', (specs['location'] ?? '').toString()),
      MapEntry('Oxirgi sinx.', _status),
    ].where((e) => e.value.trim().isNotEmpty && e.value != '—').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _header(),
        const SizedBox(height: 12),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ma\'lumot', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              for (final r in rows) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(r.key, style: const TextStyle(color: Color(0xFF97A0B3), fontSize: 12)),
                    ),
                    Expanded(
                      flex: 6,
                      child: Text(r.value, style: const TextStyle(color: Color(0xFFE6EAF4), fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: _logout,
          child: const Text('Tokenni o\'chirish'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _pageMetrics(),
      _pageNetwork(),
      _pageInfo(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('DeviceWatch'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _pill(
              'Jonli',
              bg: const Color(0xFF1D9E75).withValues(alpha: 0.18),
              fg: const Color(0xFFBFF5E3),
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: pages[_nav],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _nav,
        onDestinationSelected: (i) => setState(() => _nav = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Asosiy'),
          NavigationDestination(icon: Icon(Icons.public), label: 'Tarmoq'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Sozlamalar'),
        ],
      ),
    );
  }
}
