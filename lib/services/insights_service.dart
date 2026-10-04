import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/finding.dart';
import '../models/insight.dart';
import 'patient_context_service.dart';
import 'user_profile_service.dart';

class InsightsException implements Exception {
  InsightsException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Insights client for Nemo Care.
///
/// **Generation** runs on the Express backend:
/// medical KB + Tavily + NVIDIA (LangChain) → critic → Firestore write.
///
/// **Reads** stay on-device via Firestore so [InsightsScreen] never burns API credits.
///
/// Call [refreshIfFindingsChanged] from report-save / findings recompute only.
class InsightsService {
  InsightsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    PatientContextService? patientContext,
    http.Client? httpClient,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _patientContext = patientContext ?? PatientContextService(),
        _http = httpClient ?? http.Client();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final PatientContextService _patientContext;
  final http.Client _http;

  /// Per-user in-memory lock (same app instance).
  static final Map<String, bool> _refreshInFlight = {};

  /// Latest userDoc requested while a refresh was already running.
  static final Map<String, Map<String, dynamic>> _pendingUserDoc = {};

  static final Map<String, bool> _pendingForce = {};

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = _auth.currentUser?.email;
    if (email == null || email.trim().isEmpty) return null;
    return _firestore
        .collection(UserProfileService.collectionName)
        .doc(email.trim().toLowerCase());
  }

  String? _currentEmail() {
    final email = _auth.currentUser?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return null;
    return email;
  }

  /// Evidence fingerprint: keys + rounded value + date per supporting lab row.
  ///
  /// Kept in sync with `backend/src/services/fingerprint.js` for local short-circuit.
  static String computeFingerprint(PatientContext ctx) {
    final findings = List<Finding>.from(ctx.activeFindings)
      ..sort((a, b) => a.key.compareTo(b.key));
    if (findings.isEmpty) return '';

    final parts = <String>[];
    for (final finding in findings) {
      final values = List<Map<String, dynamic>>.from(
        ctx.supportingValues[finding.key] ?? const [],
      )..sort((a, b) {
          final ak = '${a['parameterKey'] ?? ''}';
          final bk = '${b['parameterKey'] ?? ''}';
          final byKey = ak.compareTo(bk);
          if (byKey != 0) return byKey;
          return '${a['date'] ?? ''}'.compareTo('${b['date'] ?? ''}');
        });

      final valuePart = values.map((v) {
        final key = '${v['parameterKey'] ?? ''}'.trim();
        final date = '${v['date'] ?? ''}'.trim();
        final value = _fingerprintValue(v['value']);
        return '$key:$value:$date';
      }).join(',');

      parts.add('${finding.key}[$valuePart]');
    }
    return parts.join('|');
  }

  static String _fingerprintValue(dynamic raw) {
    if (raw == null) return '';
    if (raw is num) return raw.toStringAsFixed(2);
    final parsed = num.tryParse(raw.toString().trim());
    if (parsed != null) return parsed.toStringAsFixed(2);
    return raw.toString().trim();
  }

  /// Reads cached insights from Firestore (never calls the backend).
  Future<InsightsBundle> fetchCached() async {
    final ref = _userRef();
    if (ref == null) return const InsightsBundle(fingerprint: '', cards: []);
    try {
      final snap = await ref.get();
      final raw = snap.data()?['insights'];
      if (raw is! Map) {
        return const InsightsBundle(fingerprint: '', cards: []);
      }
      return InsightsBundle.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return const InsightsBundle(fingerprint: '', cards: []);
    }
  }

  /// Live cache stream for the Insights screen (read-only — no generation).
  Stream<InsightsBundle> watchCached() {
    final ref = _userRef();
    if (ref == null) {
      return Stream.value(const InsightsBundle(fingerprint: '', cards: []));
    }
    return ref.snapshots().map((snap) {
      final raw = snap.data()?['insights'];
      if (raw is! Map) {
        return const InsightsBundle(fingerprint: '', cards: []);
      }
      return InsightsBundle.fromJson(Map<String, dynamic>.from(raw));
    });
  }

  static InsightsBundle _bundleFromDoc(Map<String, dynamic> userDoc) {
    final existingRaw = userDoc['insights'];
    if (existingRaw is Map) {
      return InsightsBundle.fromJson(Map<String, dynamic>.from(existingRaw));
    }
    return const InsightsBundle(fingerprint: '', cards: []);
  }

  /// Loads the latest user doc and regenerates insights if the evidence
  /// fingerprint no longer matches (e.g. a newer CBC replaced older lab values).
  ///
  /// Safe to call from Insights screen open — short-circuits when already fresh.
  Future<InsightsBundle> ensureUpToDate({bool force = false}) async {
    final ref = _userRef();
    if (ref == null) {
      return const InsightsBundle(fingerprint: '', cards: []);
    }
    try {
      final snap = await ref.get();
      final userDoc = snap.data() ?? <String, dynamic>{};
      return refreshIfFindingsChanged(userDoc, force: force);
    } catch (e) {
      throw InsightsException('Could not refresh insights: $e');
    }
  }

  /// Asks the Express API to regenerate insights when the evidence fingerprint changes.
  ///
  /// Per-user in-flight guard: overlapping calls stash the latest userDoc and
  /// re-run once the current refresh finishes.
  Future<InsightsBundle> refreshIfFindingsChanged(
    Map<String, dynamic> userDoc, {
    bool force = false,
  }) async {
    final email = _currentEmail();
    if (email == null) {
      return const InsightsBundle(fingerprint: '', cards: []);
    }

    if (_refreshInFlight[email] == true) {
      _pendingUserDoc[email] = userDoc;
      if (force) _pendingForce[email] = true;
      return _bundleFromDoc(userDoc);
    }

    _refreshInFlight[email] = true;
    late InsightsBundle result;
    try {
      result = await _doRefresh(email, userDoc, force: force);
      while (_pendingUserDoc.containsKey(email)) {
        final pending = _pendingUserDoc.remove(email)!;
        final pendingForce = _pendingForce.remove(email) ?? false;
        result = await _doRefresh(email, pending, force: pendingForce);
      }
    } finally {
      _refreshInFlight[email] = false;
    }

    if (_pendingUserDoc.containsKey(email)) {
      final pending = _pendingUserDoc.remove(email)!;
      final pendingForce = _pendingForce.remove(email) ?? false;
      return refreshIfFindingsChanged(pending, force: pendingForce);
    }
    return result;
  }

  Future<InsightsBundle> _doRefresh(
    String email,
    Map<String, dynamic> userDoc, {
    required bool force,
  }) async {
    final context = _patientContext.build(userDoc);
    final fingerprint = computeFingerprint(context);
    final existing = _bundleFromDoc(userDoc);

    // Local short-circuit — avoid a network round-trip when nothing changed.
    if (!force && existing.fingerprint == fingerprint) {
      return existing;
    }

    return _callBackendRefresh(
      email: email,
      userDoc: userDoc,
      force: force,
    );
  }

  /// POST /insights/refresh — server runs KB + Tavily + NVIDIA and writes Firestore.
  Future<InsightsBundle> _callBackendRefresh({
    required String email,
    required Map<String, dynamic> userDoc,
    required bool force,
  }) async {
    if (!BackendConfig.isConfigured) {
      throw InsightsException('BACKEND_BASE_URL is not configured.');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = await _auth.currentUser?.getIdToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    late final http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse(BackendConfig.insightsRefreshUrl),
            headers: headers,
            body: jsonEncode({
              'email': email,
              'force': force,
              'persist': true,
              // Send the post-save doc so the API does not race a stale Firestore read.
              'userDoc': userDoc,
            }),
          )
          .timeout(const Duration(seconds: 120));
    } catch (e) {
      throw InsightsException(
        'Could not reach insights API at ${BackendConfig.baseUrl}. '
        'Is the Express server running? ($e)',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String detail = response.body;
      try {
        final map = jsonDecode(response.body);
        if (map is Map && map['error'] != null) {
          detail = map['error'].toString();
        }
      } catch (_) {}
      throw InsightsException(
        'Insights API failed (${response.statusCode}): $detail',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw InsightsException('Insights API returned unexpected JSON.');
      }
      final map = Map<String, dynamic>.from(decoded);
      // Response is { ok, email, fingerprint, cards, generatedAt, ... }
      return InsightsBundle.fromJson(map);
    } catch (e) {
      if (e is InsightsException) rethrow;
      throw InsightsException('Insights API returned invalid JSON.');
    }
  }
}
