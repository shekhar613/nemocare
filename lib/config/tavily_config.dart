import 'tavily_secrets.dart';

/// Tavily web-search settings for Insights grounding.
///
/// Priority:
/// 1. `--dart-define=TAVILY_API_KEY=...` at run/build time
/// 2. Local `tavily_secrets.dart` (gitignored — see `tavily_secrets.example.dart`)
///
/// Create keys at https://app.tavily.com
class TavilyConfig {
  TavilyConfig._();

  static const String apiKey = String.fromEnvironment(
    'TAVILY_API_KEY',
    defaultValue: tavilyApiKeyLocal,
  );

  static const String baseUrl = 'https://api.tavily.com/search';

  static bool get isConfigured => apiKey.isNotEmpty;
}
