import 'dart:convert';

import 'package:http/http.dart' as http;

class CloudService {
  CloudService(this.baseUrl);

  final String baseUrl;

  String get _root {
    final t = baseUrl.trim();
    return t.endsWith('/') ? t.substring(0, t.length - 1) : t;
  }

  Future<String> enroll({
    required String enrollmentKey,
    required String name,
    required String type,
    required String hostname,
  }) async {
    final r = await http.post(
      Uri.parse('$_root/api/devices/enroll'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'enrollmentKey': enrollmentKey,
        'name': name,
        'type': type,
        'hostname': hostname,
      }),
    );
    if (r.statusCode != 200) {
      throw Exception('Enroll ${r.statusCode}: ${r.body}');
    }
    final m = jsonDecode(r.body) as Map<String, dynamic>;
    final t = m['deviceToken'] as String?;
    if (t == null || t.isEmpty) {
      throw Exception('deviceToken yoq');
    }
    return t;
  }

  Future<void> heartbeat(String token, Map<String, dynamic> body) async {
    final r = await http.post(
      Uri.parse('$_root/api/devices/heartbeat'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) {
      throw Exception('Heartbeat ${r.statusCode}: ${r.body}');
    }
  }
}
