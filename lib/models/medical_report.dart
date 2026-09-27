import 'report_category.dart';
import 'vital_row.dart';

/// Structured medical report extracted by Groq and stored in Firestore.
///
/// Firestore fields include:
/// - `report-name` — specific name (e.g. CBC, Lipid Profile)
/// - `category` — type bucket (lab, prescription, imaging, …)
/// - `isStarred` — timeline favorite flag
class MedicalReport {
  const MedicalReport({
    required this.id,
    required this.reportName,
    required this.category,
    required this.labName,
    required this.cityName,
    required this.sampleType,
    required this.collectionDate,
    required this.testDate,
    required this.parameters,
    required this.vitals,
    required this.conclusion,
    required this.fileName,
    required this.fullReport,
    required this.confidence,
    required this.createdAt,
    this.isStarred = false,
  });

  final String id;

  /// Specific report title, e.g. "CBC".
  final String reportName;

  /// Report type used to group different medical documents.
  final ReportCategory category;

  final String labName;
  final String cityName;
  final String sampleType;
  final String collectionDate;
  final String testDate;

  /// Short parameter / test names only (e.g. Hemoglobin, WBC).
  final List<String> parameters;

  /// Structured vitals rows for the Vitals screen.
  final List<VitalRow> vitals;
  final String conclusion;
  final String fileName;

  /// Complete extracted report payload shown on the details screen.
  final Map<String, dynamic> fullReport;
  final double confidence;
  final DateTime createdAt;
  final bool isStarred;

  /// Backward-compatible alias for older code paths.
  String get documentType => category.storageValue;

  /// e.g. "LAB Test - CBC"
  String get timelineTitle => '${category.label} - $reportName';

  /// e.g. "Sankar Eye Lab, Indore"
  String get labLocationLine {
    if (labName.isNotEmpty && cityName.isNotEmpty) {
      return '$labName, $cityName';
    }
    if (labName.isNotEmpty) return labName;
    if (cityName.isNotEmpty) return cityName;
    return 'Lab unknown';
  }

  String get parametersLine {
    if (parameters.isEmpty) return 'No parameters listed';
    return parameters.join(', ');
  }

  String get displayTitle {
    if (cityName.isEmpty) return reportName;
    return '$reportName, $cityName';
  }

  String get displaySampleType {
    final fromField = sampleType.trim();
    if (fromField.isNotEmpty) return fromField;
    final fromFull = (fullReport['sample_type'] ?? fullReport['sampleType'])
        ?.toString()
        .trim();
    if (fromFull != null && fromFull.isNotEmpty) return fromFull;
    return 'Not specified';
  }

  String get displayCollectionDate {
    final fromField = collectionDate.trim();
    if (fromField.isNotEmpty && fromField != 'Unknown date') return fromField;
    final fromFull =
        (fullReport['collection_date'] ?? fullReport['collectionDate'])
            ?.toString()
            .trim();
    if (fromFull != null && fromFull.isNotEmpty) return fromFull;
    if (testDate.trim().isNotEmpty) return testDate;
    return 'Unknown date';
  }

  /// Formatted lab results for the report details "Report data" section.
  String get reportDataText {
    final rows = displayVitals;
    if (rows.isNotEmpty) {
      return rows.map((row) {
        final unit = row.unit.trim().isEmpty ? '' : ' ${row.unit}';
        final ref =
            row.reference.trim().isEmpty ? '' : ' (Ref: ${row.reference})';
        return '${row.parameter}: ${row.value}$unit$ref';
      }).join('\n');
    }

    final findings = fullReport['key_findings'] ?? fullReport['keyFindings'];
    if (findings is List && findings.isNotEmpty) {
      return findings
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .join('\n');
    }

    final notes = (fullReport['notes'] ?? fullReport['raw_extract'])
        ?.toString()
        .trim();
    if (notes != null && notes.isNotEmpty) return notes;

    return 'No report data available.';
  }

  /// Vitals for UI: stored rows, or derived from last report payload.
  List<VitalRow> get displayVitals => VitalRow.resolveForDisplay(
        vitals: vitals,
        parameters: parameters,
        fullReport: fullReport,
      );

  MedicalReport copyWith({
    String? id,
    String? reportName,
    ReportCategory? category,
    String? labName,
    String? cityName,
    String? sampleType,
    String? collectionDate,
    String? testDate,
    List<String>? parameters,
    List<VitalRow>? vitals,
    String? conclusion,
    String? fileName,
    Map<String, dynamic>? fullReport,
    double? confidence,
    DateTime? createdAt,
    bool? isStarred,
  }) {
    return MedicalReport(
      id: id ?? this.id,
      reportName: reportName ?? this.reportName,
      category: category ?? this.category,
      labName: labName ?? this.labName,
      cityName: cityName ?? this.cityName,
      sampleType: sampleType ?? this.sampleType,
      collectionDate: collectionDate ?? this.collectionDate,
      testDate: testDate ?? this.testDate,
      parameters: parameters ?? this.parameters,
      vitals: vitals ?? this.vitals,
      conclusion: conclusion ?? this.conclusion,
      fileName: fileName ?? this.fileName,
      fullReport: fullReport ?? this.fullReport,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
      isStarred: isStarred ?? this.isStarred,
    );
  }

  /// Firestore document id: category_reportname+testdate (sanitized).
  static String buildDocumentId({
    required ReportCategory category,
    required String reportName,
    required String testDate,
  }) {
    final cat = _sanitizeIdPart(category.storageValue);
    final name = _sanitizeIdPart(reportName);
    final date = _sanitizeIdPart(testDate);
    return '${cat}_$name+$date';
  }

  static String _sanitizeIdPart(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'unknown';
    return trimmed
        .replaceAll(RegExp(r'[/\\#?\[\]]'), '-')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  Map<String, dynamic> toFirestore() {
    return {
      // Primary keys for filtering different report types.
      'report-name': reportName,
      'category': category.storageValue,

      // CamelCase mirrors for existing clients / console readability.
      'reportName': reportName,
      'documentType': category.storageValue,

      'labName': labName,
      'cityName': cityName,
      'sampleType': sampleType,
      'collectionDate': collectionDate,
      'testDate': testDate,
      'parameters': parameters,
      'vitals': vitals.map((v) => v.toJson()).toList(),
      'conclusion': conclusion,
      'fileName': fileName,
      'fullReport': fullReport,
      'confidence': confidence,
      'createdAt': createdAt.toIso8601String(),
      'isStarred': isStarred,
      'starred': isStarred,
    };
  }

  factory MedicalReport.fromFirestore({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdRaw = data['createdAt'];
    DateTime createdAt;
    if (createdRaw is String) {
      createdAt = DateTime.tryParse(createdRaw) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    final full = data['fullReport'];
    final fullReport = full is Map<String, dynamic>
        ? Map<String, dynamic>.from(full)
        : <String, dynamic>{};

    final paramsRaw = data['parameters'];
    final parameters = <String>[];
    if (paramsRaw is List) {
      for (final item in paramsRaw) {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) parameters.add(text);
      }
    }

    final vitals = <VitalRow>[];
    final vitalsRaw = data['vitals'];
    if (vitalsRaw is List) {
      for (final item in vitalsRaw) {
        if (item is Map) {
          final row = VitalRow.fromJson(Map<String, dynamic>.from(item));
          if (row.parameter.isNotEmpty) vitals.add(row);
        }
      }
    }

    final reportName = _readString(
      data,
      const ['report-name', 'reportName', 'report_name'],
      'Medical report',
    );
    final category = ReportCategory.fromStorage(
      _readString(
        data,
        const ['category', 'documentType', 'document_type'],
        'other_medical',
      ),
    );

    final starred = data['isStarred'] == true || data['starred'] == true;
    final testDate =
        _readString(data, const ['testDate', 'test_date'], 'Unknown date');
    final sampleFromFull =
        (fullReport['sample_type'] ?? fullReport['sampleType'])?.toString();
    final collectionFromFull =
        (fullReport['collection_date'] ?? fullReport['collectionDate'])
            ?.toString();

    return MedicalReport(
      id: id,
      reportName: reportName,
      category: category,
      labName: (data['labName'] as String?)?.trim() ?? '',
      cityName: (data['cityName'] as String?)?.trim() ?? '',
      sampleType: _readString(
        data,
        const ['sampleType', 'sample_type'],
        sampleFromFull?.trim().isNotEmpty == true
            ? sampleFromFull!.trim()
            : '',
      ),
      collectionDate: _readString(
        data,
        const ['collectionDate', 'collection_date'],
        collectionFromFull?.trim().isNotEmpty == true
            ? collectionFromFull!.trim()
            : testDate,
      ),
      testDate: testDate,
      parameters: parameters,
      vitals: vitals,
      conclusion: _readString(
        data,
        const ['conclusion'],
        'No conclusion available.',
      ),
      fileName: (data['fileName'] as String?)?.trim() ?? '',
      fullReport: fullReport,
      confidence: (data['confidence'] is num)
          ? (data['confidence'] as num).toDouble()
          : 0.0,
      createdAt: createdAt,
      isStarred: starred,
    );
  }

  static String _readString(
    Map<String, dynamic> data,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final value = (data[key] as String?)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return fallback;
  }
}
