import 'report_category.dart';
import 'vital_row.dart';

/// Result of Groq analysis for an uploaded health document.
class DocumentAnalysis {
  const DocumentAnalysis({
    required this.isMedical,
    required this.category,
    required this.reportName,
    required this.labName,
    required this.cityName,
    required this.sampleType,
    required this.collectionDate,
    required this.testDate,
    required this.parameters,
    required this.vitals,
    required this.conclusion,
    required this.confidence,
    required this.fullReport,
    this.rejectionReason,
  });

  final bool isMedical;

  /// Report type: lab, prescription, imaging, clinical_report, other_medical
  final ReportCategory category;

  final String reportName;
  final String labName;
  final String cityName;
  final String sampleType;
  final String collectionDate;
  final String testDate;

  /// Short names of parameters / tests only.
  final List<String> parameters;

  /// Structured rows for the Vitals table.
  final List<VitalRow> vitals;
  final String conclusion;

  /// 0.0 – 1.0
  final double confidence;

  /// Complete structured extract for the details screen / Firestore.
  final Map<String, dynamic> fullReport;

  final String? rejectionReason;

  /// Backward-compatible alias.
  String get documentType => category.storageValue;

  factory DocumentAnalysis.fromJson(Map<String, dynamic> json) {
    final confidenceRaw = json['confidence'];
    final confidence = confidenceRaw is num
        ? confidenceRaw.toDouble().clamp(0.0, 1.0)
        : 0.0;

    final full = json['full_report'];
    final fullReport = <String, dynamic>{};
    if (full is Map) {
      full.forEach((key, value) {
        fullReport[key.toString()] = value;
      });
    }

    final params = <String>[];
    final paramsRaw = json['parameters'];
    if (paramsRaw is List) {
      for (final item in paramsRaw) {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) params.add(text);
      }
    }

    final vitals = <VitalRow>[];
    final vitalsRaw = json['vitals'];
    if (vitalsRaw is List) {
      for (final item in vitalsRaw) {
        if (item is Map) {
          final row = VitalRow.fromJson(Map<String, dynamic>.from(item));
          if (row.parameter.isNotEmpty) vitals.add(row);
        }
      }
    }

    if (params.isEmpty && vitals.isNotEmpty) {
      params.addAll(vitals.map((v) => v.parameter));
    }

    final categoryRaw = (json['category'] as String?)?.trim().isNotEmpty == true
        ? json['category'] as String
        : (json['document_type'] as String?) ?? 'other_medical';

    final testDate = _nonEmpty(json['test_date'], 'Unknown date');
    final collectionFromFull = (fullReport['collection_date'] as String?)?.trim();
    final sampleFromFull = (fullReport['sample_type'] as String?)?.trim();

    return DocumentAnalysis(
      isMedical: json['is_medical'] == true,
      category: ReportCategory.fromStorage(categoryRaw),
      reportName: _nonEmpty(json['report_name'], 'Medical report'),
      labName: (json['lab_name'] as String?)?.trim() ?? '',
      cityName: (json['city_name'] as String?)?.trim() ?? '',
      sampleType: _nonEmpty(
        json['sample_type'] ?? sampleFromFull,
        '',
      ),
      collectionDate: _nonEmpty(
        json['collection_date'] ?? collectionFromFull,
        testDate,
      ),
      testDate: testDate,
      parameters: params,
      vitals: vitals,
      conclusion: _nonEmpty(json['conclusion'], 'No conclusion available.'),
      confidence: confidence,
      fullReport: fullReport,
      rejectionReason: (json['rejection_reason'] as String?)?.trim(),
    );
  }

  static String _nonEmpty(Object? value, String fallback) {
    final text = (value as String?)?.trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }
}
