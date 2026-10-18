import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/chat_message.dart';
import '../models/finding.dart';
import '../models/medical_report.dart';
import '../models/report_comparison.dart';

/// Result of a home-chat ask (plain reply + optional structured comparison).
class HealthAgentReply {
  const HealthAgentReply({
    required this.reply,
    this.comparison,
  });

  final String reply;
  final ReportComparison? comparison;
}

class HealthAgentException implements Exception {
  HealthAgentException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Home chat client — same architecture as Insights.
///
/// Flutter stays thin: POST /chat/ask → Express loads labs + MEDICAL_KB → NVIDIA.
/// Chat history remains on-device; the server does not persist turns.
class HealthAgentService {
  HealthAgentService({
    http.Client? client,
    FirebaseAuth? auth,
  })  : _client = client ?? http.Client(),
        _auth = auth ?? FirebaseAuth.instance;

  final http.Client _client;
  final FirebaseAuth _auth;
  bool _warmedUp = false;

  /// Best-effort ping of the Express health endpoint.
  Future<void> warmUp() async {
    if (_warmedUp || !BackendConfig.isConfigured) return;
    _warmedUp = true;
    try {
      await _client
          .get(Uri.parse(BackendConfig.healthUrl))
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      _warmedUp = false;
    }
  }

  /// Yields the assistant reply (chunked for progressive UI painting).
  ///
  /// [reports] / [findings] are accepted for API compatibility with HomeScreen;
  /// the backend reloads the authoritative user doc from Firestore.
  Stream<String> askStream({
    required String question,
    required List<MedicalReport> reports,
    List<ChatMessage> history = const [],
    List<Finding> findings = const [],
    ReportComparison? comparisonContext,
  }) async* {
    final result = await askDetailed(
      question: question,
      reports: reports,
      history: history,
      findings: findings,
      comparisonContext: comparisonContext,
    );
    const chunkSize = 24;
    final reply = result.reply;
    for (var i = 0; i < reply.length; i += chunkSize) {
      final end = (i + chunkSize < reply.length) ? i + chunkSize : reply.length;
      yield reply.substring(i, end);
      await Future<void>.delayed(const Duration(milliseconds: 12));
    }
  }

  /// One-shot ask via Express `/chat/ask` (plain string).
  Future<String> ask({
    required String question,
    required List<MedicalReport> reports,
    List<ChatMessage> history = const [],
    List<Finding> findings = const [],
    ReportComparison? comparisonContext,
  }) async {
    final result = await askDetailed(
      question: question,
      reports: reports,
      history: history,
      findings: findings,
      comparisonContext: comparisonContext,
    );
    return result.reply;
  }

  /// Full ask including optional structured comparison echo from the server.
  Future<HealthAgentReply> askDetailed({
    required String question,
    required List<MedicalReport> reports,
    List<ChatMessage> history = const [],
    List<Finding> findings = const [],
    ReportComparison? comparisonContext,
  }) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) {
      throw HealthAgentException('Please enter a question.');
    }
    if (!BackendConfig.isConfigured) {
      throw HealthAgentException('BACKEND_BASE_URL is not configured.');
    }

    final email = _auth.currentUser?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      throw HealthAgentException('Sign in to use health chat.');
    }

    unawaited(warmUp());

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = await _auth.currentUser?.getIdToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final recent = history.length > 4
        ? history.sublist(history.length - 4)
        : history;
    final historyPayload = recent
        .where((m) => m.content.trim().isNotEmpty)
        .map(
          (m) => {
            'role': m.isUser ? 'user' : 'assistant',
            'content': m.content.trim(),
          },
        )
        .toList();

    final body = <String, dynamic>{
      'email': email,
      'question': trimmed,
      'history': historyPayload,
      if (comparisonContext != null)
        'comparisonContext': comparisonContext.toJson(),
    };

    late final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(BackendConfig.chatAskUrl),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 90));
    } catch (e) {
      throw HealthAgentException(
        'Could not reach chat API at ${BackendConfig.baseUrl}. '
        'Is the Express server running?',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HealthAgentException(_friendlyHttpError(response));
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw HealthAgentException('Chat API returned unexpected JSON.');
      }
      final reply = (decoded['reply'] ?? '').toString().trim();
      if (reply.isEmpty) {
        throw HealthAgentException('Chat API returned an empty reply.');
      }
      ReportComparison? comparison;
      final rawCmp = decoded['comparison'];
      if (rawCmp is Map) {
        comparison =
            ReportComparison.fromJson(Map<String, dynamic>.from(rawCmp));
      }
      return HealthAgentReply(reply: reply, comparison: comparison);
    } catch (e) {
      if (e is HealthAgentException) rethrow;
      throw HealthAgentException('Chat API returned invalid JSON.');
    }
  }

  String _friendlyHttpError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] != null) {
        return body['error'].toString();
      }
    } catch (_) {}

    if (response.statusCode == 401 || response.statusCode == 403) {
      return 'Chat API auth failed. Sign in again and retry.';
    }
    if (response.statusCode == 429) {
      return 'Chat API rate limit reached. Please wait and try again.';
    }
    return 'Chat API failed (${response.statusCode}). Please try again.';
  }
}
