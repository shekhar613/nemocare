import 'groq_secrets.dart';

/// GroqCloud API settings for medical document verification.
///
/// Priority:
/// 1. `--dart-define=GROQ_API_KEY=...` at run/build time
/// 2. Local `groq_secrets.dart` (gitignored — see `groq_secrets.example.dart`)
///
/// Create keys at https://console.groq.com/keys
class GroqConfig {
  GroqConfig._();

  static const String apiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: groqApiKeyLocal,
  );

  static const String baseUrl = 'https://api.groq.com/openai/v1';

  /// Vision-capable model used to read report images / PDF page renders.
  /// See https://console.groq.com/docs/vision
  static const String visionModel = 'qwen/qwen3.8-27b';

  static bool get isConfigured => apiKey.isNotEmpty;
}
