import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/tavily_config.dart';

class TavilyException implements Exception {
  TavilyException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thin client for Tavily search (Insights source grounding).
class TavilyClient {
  TavilyClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Map<String, dynamic>>> search(
    String query, {
    int maxResults = 5,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    if (!TavilyConfig.isConfigured) {
      throw TavilyException(
        'Tavily API key is missing. Run with '
        '--dart-define=TAVILY_API_KEY=your_key '
        'or add it to lib/config/tavily_secrets.dart.',
      );
    }

    late final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(TavilyConfig.baseUrl),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'api_key': TavilyConfig.apiKey,
              'query': trimmed,
              'max_results': maxResults,
              'search_depth': 'basic',
              'include_answer': false,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw TavilyException(
        'Could not reach Tavily. Check your connection and try again.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TavilyException(
        'Tavily request failed (${response.statusCode}).',
      );
    }

    try {
      final data = jsonDecode(response.body);
      if (data is! Map) return const [];
      final results = data['results'];
      if (results is! List) return const [];
      return results
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      throw TavilyException('Tavily returned an unexpected response.');
    }
  }
}
