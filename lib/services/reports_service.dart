import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/finding.dart';
import '../models/insight.dart';
import '../models/medical_report.dart';
import '../models/report_category.dart';
import '../models/user_profile.dart';
import 'findings_service.dart';
import 'insights_service.dart';
import 'user_profile_service.dart';

class ReportsException implements Exception {
  ReportsException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Persists verified medical reports under the signed-in user.
///
/// Path shape (matches `user-data-structure.json`):
/// `USERS/{email}` document with nested maps:
///   `{reportName}` → `{testDate}` → report payload
///   `findings` → `{findingKey}` → finding payload
///   `insights` → `{ fingerprint, cards[] }`  (regenerated when findings change)
///
/// Example: `USERS/user@mail.com.cbc.2026-09-14`
class ReportsService {
  ReportsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    UserProfileService? profiles,
    FindingsService? findings,
    InsightsService? insights,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _profiles = profiles ?? UserProfileService(),
        _findings = findings ?? FindingsService(),
        _insights = insights ?? InsightsService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final UserProfileService _profiles;
  final FindingsService _findings;
  final InsightsService _insights;

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = _auth.currentUser?.email;
    if (email == null || email.trim().isEmpty) return null;
    return _firestore
        .collection(UserProfileService.collectionName)
        .doc(email.trim().toLowerCase());
  }

  Future<MedicalReport> saveReport(MedicalReport report) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.trim().isEmpty) {
      throw ReportsException(
        'Sign in with an email account to save reports.',
      );
    }

    await _profiles.ensureUserDocument(
      email: email,
      name: user.displayName,
      uid: user.uid,
    );

    final reportKey = report.storageKey;
    final dateKey = report.dateKey;
    final saved = report.copyWith(
      id: '$reportKey/$dateKey',
      docType: reportKey,
      testDate: dateKey,
    );
    final payload = saved.toUsersNestedPayload();

    final ref = _userRef();
    if (ref == null) {
      throw ReportsException('Sign in to save reports to your account.');
    }

    try {
      // Preserve star if this exact report+date already exists.
      final snap = await ref.get();
      final existingData = snap.data() ?? <String, dynamic>{};
      if (snap.exists) {
        final existingMap = existingData[reportKey];
        if (existingMap is Map && existingMap[dateKey] is Map) {
          final existing =
              Map<String, dynamic>.from(existingMap[dateKey] as Map);
          final wasStarred =
              existing['isStarred'] == true || existing['starred'] == true;
          payload['isStarred'] = wasStarred;
        }
      }

      // FieldPath merge keeps sibling dates under the same report name.
      await ref.update({
        FieldPath([reportKey, dateKey]): payload,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Recompute deterministic findings from the full user doc.
      await _recomputeAndWriteFindings(
        ref: ref,
        existingData: existingData,
        reportKey: reportKey,
        dateKey: dateKey,
        reportPayload: payload,
      );

      return saved.copyWith(isStarred: payload['isStarred'] == true);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw ReportsException(
          'Firestore permission denied. Allow writes on USERS/{email}.',
        );
      }
      throw ReportsException(
        e.message ?? 'Could not save report to your account.',
      );
    }
  }

  Future<void> _recomputeAndWriteFindings({
    required DocumentReference<Map<String, dynamic>> ref,
    required Map<String, dynamic> existingData,
    required String reportKey,
    required String dateKey,
    required Map<String, dynamic> reportPayload,
  }) async {
    try {
      // Build an in-memory view of the doc after this report write.
      final merged = Map<String, dynamic>.from(existingData);
      final reportMap = merged[reportKey] is Map
          ? Map<String, dynamic>.from(merged[reportKey] as Map)
          : <String, dynamic>{};
      reportMap[dateKey] = reportPayload;
      merged[reportKey] = reportMap;

      final existingFindings = merged['findings'] is Map
          ? Map<String, dynamic>.from(merged['findings'] as Map)
          : <String, dynamic>{};

      final computed = _findings.computeFindings(merged);
      final findingsMap = _findings.mergeFindingsMap(
        computed: computed,
        existing: existingFindings,
      );

      await ref.update({
        'findings': findingsMap,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Insights regenerate only when the active-findings fingerprint changes.
      // Non-blocking — report save already succeeded.
      merged['findings'] = findingsMap;
      // ignore: unawaited_futures
      _insights.refreshIfFindingsChanged(merged).catchError((Object e) async {
        debugPrint('Insights refresh failed: $e');
        // Drop stale cards so Insights never shows an older CBC's numbers.
        try {
          await ref.update({
            'insights': {
              'fingerprint': '',
              'cards': <Map<String, dynamic>>[],
              'generatedAt': DateTime.now().toIso8601String(),
              'stale': true,
            },
            'insights_meta': {
              'fingerprint': '',
              'stale': true,
              'error': e.toString(),
            },
            'updatedAt': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
        return const InsightsBundle(fingerprint: '', cards: []);
      });
    } catch (e) {
      // Findings must not block report save success.
      debugPrint('Findings recompute failed: $e');
    }
  }

  /// Active findings for the signed-in user (empty if none / not signed in).
  Future<List<Finding>> fetchActiveFindings() async {
    final ref = _userRef();
    if (ref == null) return [];
    try {
      final snap = await ref.get();
      if (!snap.exists) return [];
      final data = snap.data() ?? {};
      final raw = data['findings'];
      if (raw is! Map) return [];
      return _findings.parseFindingsMap(
        Map<String, dynamic>.from(raw),
        activeOnly: true,
      );
    } catch (_) {
      return [];
    }
  }

  Future<void> setStarred({
    required String reportId,
    required bool starred,
  }) async {
    final ref = _userRef();
    if (ref == null) {
      throw ReportsException('Sign in to update starred reports.');
    }

    final parts = reportId.split('/');
    if (parts.length < 2) {
      throw ReportsException('Invalid report id.');
    }
    final reportKey = parts[0];
    final dateKey = parts.sublist(1).join('/');

    try {
      await ref.update({
        FieldPath([reportKey, dateKey, 'isStarred']): starred,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } on FirebaseException catch (e) {
      throw ReportsException(
        e.message ?? 'Could not update star status.',
      );
    }
  }

  Future<List<MedicalReport>> fetchReports({ReportCategory? category}) async {
    final ref = _userRef();
    if (ref == null) return [];

    try {
      final snap = await ref.get();
      if (!snap.exists) return [];
      final data = snap.data() ?? {};
      final reports = <MedicalReport>[];

      data.forEach((key, value) {
        if (UserProfile.profileFieldKeys.contains(key)) return;
        if (value is! Map) return;

        final byDate = Map<String, dynamic>.from(value);
        byDate.forEach((dateKey, reportRaw) {
          if (reportRaw is! Map) return;
          final report = MedicalReport.fromUsersNested(
            reportKey: key,
            dateKey: dateKey.toString(),
            data: Map<String, dynamic>.from(reportRaw),
          );
          if (category == null || report.category == category) {
            reports.add(report);
          }
        });
      });

      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reports;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw ReportsException(
          'Firestore permission denied. Allow reads on USERS/{email}.',
        );
      }
      throw ReportsException(
        e.message ?? 'Could not load reports.',
      );
    }
  }

  Future<MedicalReport?> fetchLatestReport({ReportCategory? category}) async {
    final reports = await fetchReports(category: category);
    if (reports.isEmpty) return null;
    return reports.first;
  }
}
