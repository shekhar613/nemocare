import 'package:flutter/foundation.dart';

/// Express API (insights + home chat) — medical KB + NVIDIA on the server.
///
/// Override at run time:
/// `flutter run --dart-define=BACKEND_BASE_URL=http://192.168.1.10:8080`
class BackendConfig {
  BackendConfig._();

  static const String _fromDefine = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: '',
  );

  /// Base URL without trailing slash.
  static String get baseUrl {
    final configured = _fromDefine.trim();
    if (configured.isNotEmpty) {
      return configured.replaceAll(RegExp(r'/+$'), '');
    }
    // Android emulator → host machine loopback.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  static String get insightsRefreshUrl => '$baseUrl/insights/refresh';

  static String get chatAskUrl => '$baseUrl/chat/ask';

  static String get healthUrl => '$baseUrl/health';

  static bool get isConfigured => baseUrl.isNotEmpty;
}
