import 'lab_value.dart';
import 'report_category.dart';
import 'vital_row.dart';

/// Result of Groq analysis for an uploaded health document.
class DocumentAnalysis {
  const DocumentAnalysis({
    required this.isMedical,
    required this.category,
    required this.reportName,
    required this.docType,
    required this.labName,
    required this.cityName,
    required this.sampleType,
    required this.collectionDate,
    required this.testDate,
    required this.reportApprovedDate,
    required this.patientName,
    required this.patientSex,
    required this.parameters,
    required this.vitals,
    required this.values,
    required this.conclusion,
    required this.confidence,
    required this.fullReport,
    this.patientAge,
    this.regnNo = '',
    this.mrdNo = '',
    this.rejectionReason,
  });

  final bool isMedical;
  final ReportCategory category;

  /// Display name e.g. "CBC".
  final String reportName;

  /// Storage key e.g. "cbc".
  final String docType;

  final String labName;
  final String cityName;
  final String sampleType;
  final String collectionDate;
  final String testDate;
  final String reportApprovedDate;

  final String patientName;
  final String patientSex;
  final int? patientAge;
  final String regnNo;
  final String mrdNo;

  final List<String> parameters;
  final List<VitalRow> vitals;
  final List<LabValue> values;
  final String conclusion;
  final double confidence;
  final Map<String, dynamic> fullReport;
  final String? rejectionReason;

  String get documentType => docType.isNotEmpty ? docType : category.storageValue;

  factory DocumentAnalysis.fromJson(Map<String, dynamic> json) {
    final confidenceRaw = json['confidence'];
    final confidence = confidenceRaw is num
        ? confidenceRaw.toDouble().clamp(0.0, 1.0)
        : 0.0;

    final full = json['full_report'] ?? json['fullReport'];
    final fullReport = <String, dynamic>{};
    if (full is Map) {
      full.forEach((key, value) {
        fullReport[key.toString()] = value;
      });
    }

    final values = <LabValue>[];
    final valuesRaw = json['values'];
    if (valuesRaw is List) {
      for (final item in valuesRaw) {
        if (item is Map) {
          final row = LabValue.fromJson(Map<String, dynamic>.from(item));
          if (row.parameterKey.isNotEmpty || row.rawLabel.isNotEmpty) {
            values.add(row);
          }
        }
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

    // Prefer structured values; fall back to vitals → LabValue shape.
    if (values.isEmpty && vitals.isNotEmpty) {
      for (final v in vitals) {
        num? low;
        num? high;
        final range = RegExp(
          r'(-?\d+(?:\.\d+)?)\s*[-–—to]+\s*(-?\d+(?:\.\d+)?)',
          caseSensitive: false,
        ).firstMatch(v.reference);
        if (range != null) {
          low = num.tryParse(range.group(1)!);
          high = num.tryParse(range.group(2)!);
        }
        final numeric = num.tryParse(v.value.replaceAll(',', ''));
        values.add(
          LabValue(
            parameterKey: v.parameter
                .trim()
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                .replaceAll(RegExp(r'_+'), '_')
                .replaceAll(RegExp(r'^_+|_+$'), ''),
            rawLabel: v.parameter,
            valueType: numeric != null ? 'numeric' : 'text',
            value: numeric ?? v.value,
            unit: v.unit,
            refLow: low,
            refHigh: high,
            flag: switch (v.status) {
              VitalStatus.low => 'L',
              VitalStatus.high => 'H',
              _ => null,
            },
          ),
        );
      }
    }

    final params = <String>[];
    final paramsRaw = json['parameters'];
    if (paramsRaw is List) {
      for (final item in paramsRaw) {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) params.add(text);
      }
    }
    if (params.isEmpty && values.isNotEmpty) {
      params.addAll(
        values.map((v) => v.rawLabel.isNotEmpty ? v.rawLabel : v.parameterKey),
      );
    } else if (params.isEmpty && vitals.isNotEmpty) {
      params.addAll(vitals.map((v) => v.parameter));
    }

    final categoryRaw = (json['category'] as String?)?.trim().isNotEmpty == true
        ? json['category'] as String
        : (json['document_type'] as String?) ?? 'other_medical';

    final reportName = _nonEmpty(json['report_name'], 'Medical report');
    final docType = _nonEmpty(
      json['doc_type'] ?? json['docType'],
      reportName,
    );

    final testDate = _nonEmpty(json['test_date'] ?? json['report_approved_date'],
        'Unknown date');
    final collectionDate = _nonEmpty(
      json['collection_date'] ??
          json['collected_date'] ??
          fullReport['collection_date'],
      testDate,
    );
    final approved = _nonEmpty(
      json['report_approved_date'] ?? json['test_date'],
      testDate,
    );

    final ageRaw = json['patient_age'] ?? json['patientAge'];
    int? age;
    if (ageRaw is int) {
      age = ageRaw;
    } else if (ageRaw is num) {
      age = ageRaw.toInt();
    } else {
      age = int.tryParse('$ageRaw');
    }

    return DocumentAnalysis(
      isMedical: json['is_medical'] == true || json['isMedical'] == true,
      category: ReportCategory.fromStorage(categoryRaw),
      reportName: reportName,
      docType: docType,
      labName: (json['lab_name'] as String?)?.trim() ??
          (json['labName'] as String?)?.trim() ??
          '',
      cityName: (json['city_name'] as String?)?.trim() ?? '',
      sampleType: _nonEmpty(json['sample_type'], ''),
      collectionDate: collectionDate,
      testDate: testDate,
      reportApprovedDate: approved,
      patientName: _nonEmpty(
        json['patient_name'] ??
            json['patientName'] ??
            fullReport['patient_name'],
        '',
      ),
      patientSex: _nonEmpty(
        json['patient_sex'] ?? json['patientSex'] ?? fullReport['patient_sex'],
        '',
      ),
      patientAge: age,
      regnNo: _nonEmpty(json['regn_no'] ?? json['regnNo'], ''),
      mrdNo: _nonEmpty(json['mrd_no'] ?? json['mrdNo'], ''),
      parameters: params,
      vitals: vitals,
      values: values,
      conclusion: _nonEmpty(json['conclusion'], 'No conclusion available.'),
      confidence: confidence,
      fullReport: fullReport,
      rejectionReason: (json['rejection_reason'] as String?)?.trim(),
    );
  }

  static String _nonEmpty(Object? value, String fallback) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return fallback;
    }
    return text;
  }
}
