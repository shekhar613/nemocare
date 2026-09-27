import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/medical_report.dart';
import '../models/report_category.dart';

class ReportsException implements Exception {
  ReportsException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Persists verified medical reports under the signed-in user.
///
/// Path: `users/{uid}/reports/{category_reportName+testDate}`
///
/// Each document stores:
/// - `report-name` — specific report title (CBC, Lipid Profile, …)
/// - `category` — type: lab | prescription | imaging | clinical_report | other_medical
class ReportsService {
  ReportsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _reportsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('reports');
  }

  Future<MedicalReport> saveReport(MedicalReport report) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw ReportsException('Sign in to save reports to your account.');
    }

    final docId = MedicalReport.buildDocumentId(
      category: report.category,
      reportName: report.reportName,
      testDate: report.testDate,
    );
    final saved = MedicalReport(
      id: docId,
      reportName: report.reportName,
      category: report.category,
      labName: report.labName,
      cityName: report.cityName,
      sampleType: report.sampleType,
      collectionDate: report.collectionDate,
      testDate: report.testDate,
      parameters: report.parameters,
      vitals: report.vitals,
      conclusion: report.conclusion,
      fileName: report.fileName,
      fullReport: report.fullReport,
      confidence: report.confidence,
      createdAt: report.createdAt,
      isStarred: report.isStarred,
    );

    try {
      final payload = saved.toFirestore();
      // Preserve an existing star when re-uploading the same document.
      final existing = await _reportsRef(user.uid).doc(docId).get();
      if (existing.exists) {
        final data = existing.data();
        final wasStarred =
            data?['isStarred'] == true || data?['starred'] == true;
        payload['isStarred'] = wasStarred;
        payload['starred'] = wasStarred;
      }

      await _reportsRef(user.uid).doc(docId).set(
            payload,
            SetOptions(merge: true),
          );
      return saved.copyWith(
        isStarred: payload['isStarred'] == true,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw ReportsException(
          'Firestore permission denied. Enable Cloud Firestore and allow '
          'users/{uid}/reports in your Firebase project.',
        );
      }
      throw ReportsException(
        e.message ?? 'Could not save report to your account.',
      );
    }
  }

  Future<void> setStarred({
    required String reportId,
    required bool starred,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw ReportsException('Sign in to update starred reports.');
    }

    try {
      await _reportsRef(user.uid).doc(reportId).set(
        {
          'isStarred': starred,
          'starred': starred,
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      throw ReportsException(
        e.message ?? 'Could not update star status.',
      );
    }
  }

  Future<List<MedicalReport>> fetchReports({ReportCategory? category}) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    List<MedicalReport> sortReports(List<MedicalReport> reports) {
      reports.sort((a, b) {
        if (a.isStarred != b.isStarred) {
          return a.isStarred ? -1 : 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
      return reports;
    }

    try {
      Query<Map<String, dynamic>> query = _reportsRef(user.uid);
      if (category != null) {
        query = query.where('category', isEqualTo: category.storageValue);
      }
      final snapshot = await query.orderBy('createdAt', descending: true).get();

      return sortReports(
        snapshot.docs
            .map(
              (doc) => MedicalReport.fromFirestore(
                id: doc.id,
                data: doc.data(),
              ),
            )
            .toList(),
      );
    } catch (_) {
      // Fallback if composite index is missing or field absent.
      final snapshot = await _reportsRef(user.uid).get();
      final reports = snapshot.docs
          .map(
            (doc) => MedicalReport.fromFirestore(
              id: doc.id,
              data: doc.data(),
            ),
          )
          .where((r) => category == null || r.category == category)
          .toList();
      return sortReports(reports);
    }
  }

  /// Most recently uploaded report (optionally within a category).
  Future<MedicalReport?> fetchLatestReport({ReportCategory? category}) async {
    final reports = await fetchReports(category: category);
    if (reports.isEmpty) return null;
    return reports.first;
  }
}
