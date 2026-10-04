import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/nvidia_config.dart';
import '../models/finding.dart';
import '../models/insight.dart';

class NemotronException implements Exception {
  NemotronException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Non-streaming Nemotron helpers for Insights (write + critique).
class NemotronClient {
  NemotronClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Drafts one educational insight grounded in finding + sources.
  Future<Insight> writeInsight({
    required Finding finding,
    required List<Map<String, dynamic>>? supportingValue,
    required Map<String, dynamic> profile,
    required List<Map<String, dynamic>> sources,
    String? critiqueFeedback,
  }) async {
    final sourceBlock = _formatSources(sources);
    final valueBlock = _formatSupportingValues(supportingValue);
    final profileBlock = jsonEncode({
      'age': profile['age'],
      'sex': profile['sex'] ?? profile['gender'],
      'medications': profile['medications'] ?? const [],
      'allergies': profile['allergies'] ?? const [],
    });

    final feedbackBlock = (critiqueFeedback == null || critiqueFeedback.isEmpty)
        ? ''
        : '''

CRITIC FEEDBACK FROM PREVIOUS DRAFT (must fix):
$critiqueFeedback
''';

    final content = await _chatJson(
      system: '''
You are Nemo Care's insight writer. Produce ONE educational insight as JSON only
(no markdown) with this schema:
{
  "title": "short plain title",
  "body": "2-4 short sentences. Cite the patient's actual lab values and dates when provided. No diagnosis or prescriptions. End with: This is not medical advice.",
  "category": "risk" | "remedy" | "explanation",
  "supportingFindingKeys": ["${finding.key}"],
  "sourceUrls": ["only URLs that appear in SOURCES"]
}

Rules:
- Only use facts from FINDING, SUPPORTING VALUES, and SOURCES.
- Do not invent symptoms, risks, or remedies that are not supported by sources.
- Avoid naming specific drugs as prescriptions; lifestyle / follow-up language only.
- Prefer category "explanation" or "risk"; use "remedy" only for general non-drug advice from sources.
''',
      user: '''
FINDING:
${jsonEncode(finding.toJson())}

SUPPORTING VALUES:
$valueBlock

PROFILE (for tone only — do not invent history):
$profileBlock

SOURCES:
$sourceBlock
$feedbackBlock
''',
      maxTokens: 500,
    );

    final insight = Insight.fromJson({
      ...content,
      'supportingFindingKeys': content['supportingFindingKeys'] ?? [finding.key],
      'sourceUrls': content['sourceUrls'] ?? _urlsFromSources(sources),
      'createdAt': DateTime.now().toIso8601String(),
    });

    if (insight.title.isEmpty || insight.body.isEmpty) {
      throw NemotronException('Insight writer returned empty content.');
    }
    return insight;
  }

  /// Critic: reject drafts that invent claims or ignore the finding/sources.
  Future<InsightCritique> critiqueInsight(
    Insight draft,
    Finding finding,
    List<Map<String, dynamic>> sources,
  ) async {
    final sourceBlock = _formatSources(sources);
    final content = await _chatJson(
      system: '''
You are a strict medical-content critic for Nemo Care. Decide if a drafted insight
is faithful to the finding and sources. Respond with JSON only:
{
  "passesCheck": boolean,
  "reason": "short reason",
  "title": "optional revised title if passesCheck and a small fix helps",
  "body": "optional revised body if passesCheck and a small fix helps",
  "category": "risk|remedy|explanation",
  "sourceUrls": ["urls that actually appear in SOURCES and support the body"]
}

Fail (passesCheck=false) if:
- claims risks/symptoms/remedies not supported by SOURCES or FINDING
- invents lab numbers not in FINDING context / draft wrongly
- diagnoses or prescribes medication
- cites URLs that are not in SOURCES

Pass only when the insight is conservative and grounded.
''',
      user: '''
FINDING:
${jsonEncode(finding.toJson())}

DRAFT INSIGHT:
${jsonEncode(draft.toJson())}

SOURCES:
$sourceBlock
''',
      maxTokens: 500,
    );

    final passes = content['passesCheck'] == true;
    final reason = (content['reason'] ?? '').toString().trim();

    if (!passes) {
      return InsightCritique(
        passesCheck: false,
        insight: draft,
        reason: reason.isEmpty ? 'Failed grounding check.' : reason,
      );
    }

    final revised = Insight(
      title: (content['title'] as String?)?.trim().isNotEmpty == true
          ? (content['title'] as String).trim()
          : draft.title,
      body: (content['body'] as String?)?.trim().isNotEmpty == true
          ? (content['body'] as String).trim()
          : draft.body,
      category: (content['category'] as String?)?.trim().isNotEmpty == true
          ? (content['category'] as String).trim().toLowerCase()
          : draft.category,
      supportingFindingKeys: draft.supportingFindingKeys.isNotEmpty
          ? draft.supportingFindingKeys
          : [finding.key],
      sourceUrls: () {
        final urls = content['sourceUrls'];
        if (urls is List && urls.isNotEmpty) {
          return urls
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
        return draft.sourceUrls;
      }(),
      createdAt: draft.createdAt,
    );

    return InsightCritique(
      passesCheck: true,
      insight: revised,
      reason: reason,
    );
  }

  Future<Map<String, dynamic>> _chatJson({
    required String system,
    required String user,
    int maxTokens = 400,
  }) async {
    if (!NvidiaConfig.isConfigured) {
      throw NemotronException(
        'NVIDIA API key is missing. Configure NVIDIA_API_KEY.',
      );
    }

    final uri = Uri.parse('${NvidiaConfig.baseUrl}/chat/completions');
    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer ${NvidiaConfig.apiKey}',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'model': NvidiaConfig.chatModel,
              'messages': [
                {'role': 'system', 'content': system},
                {'role': 'user', 'content': user},
              ],
              'temperature': 0.2,
              'top_p': 0.9,
              'max_tokens': maxTokens,
              'stream': false,
              'response_format': {'type': 'json_object'},
              'chat_template_kwargs': {'enable_thinking': false},
              'reasoning_budget': 0,
            }),
          )
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw NemotronException(
        'Could not reach NVIDIA. Check your connection and try again.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NemotronException(
        'NVIDIA request failed (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw NemotronException('Nemotron returned an empty response.');
    }
    final message = choices.first as Map<String, dynamic>;
    final content =
        (message['message'] as Map<String, dynamic>?)?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw NemotronException('Nemotron returned no content.');
    }

    try {
      final cleaned = _stripFences(content);
      final map = jsonDecode(cleaned);
      if (map is Map<String, dynamic>) return map;
      if (map is Map) return Map<String, dynamic>.from(map);
    } catch (_) {
      throw NemotronException('Nemotron returned invalid JSON.');
    }
    throw NemotronException('Nemotron returned invalid JSON.');
  }

  String _formatSources(List<Map<String, dynamic>> sources) {
    if (sources.isEmpty) return '(no sources)';
    final buf = StringBuffer();
    for (var i = 0; i < sources.length; i++) {
      final s = sources[i];
      final title = (s['title'] ?? '').toString().trim();
      final url = (s['url'] ?? '').toString().trim();
      final snippet = (s['content'] ?? s['snippet'] ?? '').toString().trim();
      buf.writeln('${i + 1}. $title');
      if (url.isNotEmpty) buf.writeln('   URL: $url');
      if (snippet.isNotEmpty) {
        buf.writeln(
          '   ${snippet.length > 400 ? '${snippet.substring(0, 400)}…' : snippet}',
        );
      }
    }
    return buf.toString().trim();
  }

  String _formatSupportingValues(List<Map<String, dynamic>>? values) {
    if (values == null || values.isEmpty) return '(none)';
    return const JsonEncoder.withIndent('  ').convert(values);
  }

  List<String> _urlsFromSources(List<Map<String, dynamic>> sources) {
    return sources
        .map((s) => (s['url'] ?? '').toString().trim())
        .where((u) => u.isNotEmpty)
        .toList();
  }

  String _stripFences(String content) {
    var text = content.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(
        RegExp(r'^```(?:json)?\s*', caseSensitive: false),
        '',
      );
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }
    return text.trim();
  }
}
