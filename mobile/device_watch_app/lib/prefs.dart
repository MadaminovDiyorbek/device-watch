import 'package:shared_preferences/shared_preferences.dart';

const _kServer = 'dw_server_url';
const _kEnroll = 'dw_enrollment_key';
const _kName = 'dw_device_name';
const _kType = 'dw_device_type';
const _kToken = 'dw_device_token';

const _defaultServerUrl = String.fromEnvironment(
  'DW_SERVER_URL',
  defaultValue: 'http://10.0.2.2:5050',
);
const _defaultEnrollKey = String.fromEnvironment(
  'DW_ENROLLMENT_KEY',
  defaultValue: 'demo-enroll-secret',
);

class Prefs {
  Prefs({
    required this.serverUrl,
    required this.enrollmentKey,
    required this.deviceName,
    required this.deviceType,
    this.deviceToken,
  });

  final String serverUrl;
  final String enrollmentKey;
  final String deviceName;
  final String deviceType;
  final String? deviceToken;

  bool get hasToken => deviceToken != null && deviceToken!.isNotEmpty;

  static Future<Prefs> load() async {
    final sp = await SharedPreferences.getInstance();
    return Prefs(
      serverUrl: sp.getString(_kServer) ?? _defaultServerUrl,
      enrollmentKey: sp.getString(_kEnroll) ?? _defaultEnrollKey,
      deviceName: sp.getString(_kName) ?? '',
      deviceType: sp.getString(_kType) ?? 'phone',
      deviceToken: sp.getString(_kToken),
    );
  }

  static Future<void> saveSetup({
    required String serverUrl,
    required String enrollmentKey,
    required String deviceName,
    required String deviceType,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kServer, serverUrl.trim());
    await sp.setString(_kEnroll, enrollmentKey.trim());
    await sp.setString(_kName, deviceName.trim());
    await sp.setString(_kType, deviceType);
  }

  static Future<void> saveToken(String token) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kToken, token.trim());
  }

  static Future<void> clearToken() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kToken);
  }
}
