import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:system_info2/system_info2.dart';

/// Node agent bilan bir xil heartbeat JSON.
class MetricsService {
  MetricsService(this.displayName);

  final String displayName;
  double _sessionUpGb = 0;
  double _sessionDownGb = 0;

  Future<Map<String, dynamic>> collect({required int heartbeatSec}) async {
    final di = DeviceInfoPlugin();
    var hostname = displayName;
    var osLabel = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    var cpuModel = '—';
    var modelLine = '—';

    if (Platform.isAndroid) {
      final a = await di.androidInfo;
      hostname = displayName.isNotEmpty ? displayName : a.model;
      osLabel = 'Android ${a.version.release}';
      cpuModel = '${a.manufacturer} ${a.model}'.trim();
      modelLine = '$cpuModel / Android ${a.version.release}';
    } else if (Platform.isIOS) {
      final i = await di.iosInfo;
      hostname = displayName.isNotEmpty ? displayName : i.name;
      osLabel = '${i.systemName} ${i.systemVersion}';
      cpuModel = i.utsname.machine;
      modelLine = '${i.model} / $osLabel';
    }

    var totalMem = 0;
    var freeMem = 0;
    try {
      totalMem = SysInfo.getTotalPhysicalMemory();
      freeMem = SysInfo.getFreePhysicalMemory();
    } catch (_) {}

    var totalStorage = 0;
    var freeStorage = 0;
    try {
      totalStorage = SysInfo.getTotalStorage();
      freeStorage = SysInfo.getFreeStorage();
    } catch (_) {}

    final ramUsedGb = totalMem > 0 ? (totalMem - freeMem) / 1e9 : 0.0;
    final ramTotalGb = totalMem > 0 ? totalMem / 1e9 : 0.0;
    final ramPercent = totalMem > 0 ? ((totalMem - freeMem) / totalMem) * 100.0 : 0.0;

    final diskUsedGb = totalStorage > 0 ? (totalStorage - freeStorage) / 1e9 : 0.0;
    final diskTotalGb = totalStorage > 0 ? totalStorage / 1e9 : 0.0;
    final diskPercent =
        totalStorage > 0 ? ((totalStorage - freeStorage) / totalStorage) * 100.0 : 0.0;

    final bat = Battery();
    final batLevel = await bat.batteryLevel;
    final batState = await bat.batteryState;

    final conn = await Connectivity().checkConnectivity();
    final connLabel = conn.isEmpty ? 'none' : conn.map((e) => e.name).join(', ');

    var ip = '—';
    try {
      ip = await NetworkInfo().getWifiIP() ?? '—';
    } catch (_) {}

    const netUp = 0.0;
    const netDown = 0.0;
    final upMb = (netUp * heartbeatSec) / 8;
    final downMb = (netDown * heartbeatSec) / 8;
    _sessionUpGb += upMb / 1024;
    _sessionDownGb += downMb / 1024;

    return {
      'hostname': hostname,
      'cpuUsage': 0.0,
      'cpuModel': cpuModel,
      'ramUsedGb': double.parse(ramUsedGb.toStringAsFixed(2)),
      'ramTotalGb': double.parse(ramTotalGb.toStringAsFixed(2)),
      'ramPercent': ramPercent,
      'diskUsedGb': double.parse(diskUsedGb.toStringAsFixed(1)),
      'diskTotalGb': double.parse(diskTotalGb.toStringAsFixed(1)),
      'diskPercent': diskPercent,
      'netUpMbps': netUp,
      'netDownMbps': netDown,
      'netTotalUpGb': double.parse(_sessionUpGb.toStringAsFixed(3)),
      'netTotalDownGb': double.parse(_sessionDownGb.toStringAsFixed(3)),
      'osString': '$hostname / $osLabel',
      'temperatureCpu': null,
      'batteryPercent': batLevel.toDouble(),
      'batteryState': batState.name,
      'specs': {
        'cpu': cpuModel,
        'ram': '${ramTotalGb.round()} GB',
        'disk': '${diskTotalGb.round()} GB',
        'os': osLabel,
        'ip': ip,
        'location': 'Mobil',
        'tarmoq': connLabel,
      },
      'model': modelLine,
    };
  }
}
