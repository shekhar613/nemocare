import 'lab_value.dart';
import 'report_category.dart';
import 'vital_row.dart';

/// Structured medical report for UI + nested Firestore storage under
/// `USERS/{email}/{reportName}/{testDate}`.
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
    this.docType = '',
    this.patientName = '',
    this.patientSex = '',
    this.patientAge,
    this.reportApprovedDate = '',
    this.regnNo = '',
    this.mrdNo = '',
    this.values = const [],
    this.isStarred = false,
  });

  final String id;

  /// Display title, e.g. "CBC".
  final String reportName;

  /// Storage map key under the user doc, e.g. "cbc".
  final String docType;

  final ReportCategory category;

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
  final String fileName;
  final Map<String, dynamic> fullReport;
  final double confidence;
  final DateTime createdAt;
  final bool isStarred;

  String get storageKey {
    final fromDoc = slugify(docType);
    if (fromDoc.isNotEmpty && fromDoc != 'unknown') return fromDoc;
    return slugify(reportName);
  }

  String get dateKey => normalizeDateKey(testDate.isNotEmpty
      ? testDate
      : (collectionDate.isNotEmpty ? collectionDate : reportApprovedDate));

  String get documentType =>
      docType.isNotEmpty ? docType : category.storageValue;

  String get timelineTitle {
    final label = reportName.isNotEmpty
        ? reportName
        : (docType.isNotEmpty ? docType.toUpperCase() : category.label);
    return '${category.label} - $label';
  }

  String get labLocationLine {
    if (labName.isNotEmpty && cityName.isNotEmpty) {
      return '$labName, $cityName';
    }
    if (labName.isNotEmpty) return labName;
    if (cityName.isNotEmpty) return cityName;
    return 'Lab unknown';
  }

  String get parametersLine {
    if (values.isNotEmpty) {
      return values.map((v) => v.rawLabel.isNotEmpty ? v.rawLabel : v.parameterKey).join(', ');
    }
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

  String get reportDataText {
    if (values.isNotEmpty) {
      return values.map((v) {
        final unit = v.unit.trim().isEmpty ? '' : ' ${v.unit}';
        final ref =
            v.referenceText.isEmpty ? '' : ' (Ref: ${v.referenceText})';
        final label = v.rawLabel.isNotEmpty ? v.rawLabel : v.parameterKey;
        return '$label: ${v.value}$unit$ref';
      }).join('\n');
    }

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

  List<VitalRow> get displayVitals {
    if (vitals.isNotEmpty) {
      return VitalRow.resolveForDisplay(
        vitals: vitals,
        parameters: parameters,
        fullReport: fullReport,
      );
    }
    if (values.isNotEmpty) {
      return values
          .map(
            (v) => VitalRow(
              parameter:
                  v.rawLabel.isNotEmpty ? v.rawLabel : v.parameterKey,
              value: '${v.value ?? ''}',
              unit: v.unit,
              reference: v.referenceText,
              status: switch (v.statusName) {
                'low' => VitalStatus.low,
                'high' => VitalStatus.high,
                'normal' => VitalStatus.normal,
                _ => VitalStatus.unknown,
              },
            ),
          )
          .toList();
    }
    return VitalRow.resolveForDisplay(
      vitals: vitals,
      parameters: parameters,
      fullReport: fullReport,
    );
  }

  MedicalReport copyWith({
    String? id,
    String? reportName,
    String? docType,
    ReportCategory? category,
    String? labName,
    String? cityName,
    String? sampleType,
    String? collectionDate,
    String? testDate,
    String? reportApprovedDate,
    String? patientName,
    String? patientSex,
    int? patientAge,
    bool clearPatientAge = false,
    String? regnNo,
    String? mrdNo,
    List<String>? parameters,
    List<VitalRow>? vitals,
    List<LabValue>? values,
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
      docType: docType ?? this.docType,
      category: category ?? this.category,
      labName: labName ?? this.labName,
      cityName: cityName ?? this.cityName,
      sampleType: sampleType ?? this.sampleType,
      collectionDate: collectionDate ?? this.collectionDate,
      testDate: testDate ?? this.testDate,
      reportApprovedDate: reportApprovedDate ?? this.reportApprovedDate,
      patientName: patientName ?? this.patientName,
      patientSex: patientSex ?? this.patientSex,
      patientAge: clearPatientAge ? null : (patientAge ?? this.patientAge),
      regnNo: regnNo ?? this.regnNo,
      mrdNo: mrdNo ?? this.mrdNo,
      parameters: parameters ?? this.parameters,
      vitals: vitals ?? this.vitals,
      values: values ?? this.values,
      conclusion: conclusion ?? this.conclusion,
      fileName: fileName ?? this.fileName,
      fullReport: fullReport ?? this.fullReport,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
      isStarred: isStarred ?? this.isStarred,
    );
  }

  /// Nested payload stored at `USERS/{email}.{storageKey}.{dateKey}`.
  Map<String, dynamic> toUsersNestedPayload() {
    final resolvedValues = values.isNotEmpty
        ? values
        : vitals.map(_labValueFromVital).toList();

    return {
      'docType': storageKey,
      'isMedical': true,
      'labName': labName,
      'patientName': patientName.isNotEmpty
          ? patientName
          : (fullReport['patient_name'] ?? fullReport['patientName'] ?? ''),
      'patientSex': patientSex,
      'patientAge': patientAge,
      'collectedDate': collectionDate.isNotEmpty ? collectionDate : testDate,
      'reportApprovedDate':
          reportApprovedDate.isNotEmpty ? reportApprovedDate : testDate,
      'regnNo': regnNo,
      'mrdNo': mrdNo,
      'values': resolvedValues.map((v) => v.toJson()).toList(),
      // UI / agent helpers kept alongside the schema.
      'reportName': reportName,
      'category': category.storageValue,
      'cityName': cityName,
      'sampleType': sampleType,
      'conclusion': conclusion,
      'fileName': fileName,
      'confidence': confidence,
      'fullReport': fullReport,
      'isStarred': isStarred,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MedicalReport.fromUsersNested({
    required String reportKey,
    required String dateKey,
    required Map<String, dynamic> data,
  }) {
    final values = <LabValue>[];
    final valuesRaw = data['values'];
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
    final vitalsRaw = data['vitals'];
    if (vitalsRaw is List) {
      for (final item in vitalsRaw) {
        if (item is Map) {
          final row = VitalRow.fromJson(Map<String, dynamic>.from(item));
          if (row.parameter.isNotEmpty) vitals.add(row);
        }
      }
    }

    final full = data['fullReport'];
    final fullReport = full is Map
        ? Map<String, dynamic>.from(full)
        : <String, dynamic>{};

    final docType = _readString(data, const ['docType', 'doc_type'], reportKey);
    final reportName = _readString(
      data,
      const ['reportName', 'report_name', 'report-name'],
      docType.toUpperCase(),
    );
    final collected = _readString(
      data,
      const ['collectedDate', 'collectionDate', 'collection_date'],
      dateKey,
    );
    final approved = _readString(
      data,
      const ['reportApprovedDate', 'testDate', 'test_date'],
      dateKey,
    );
    final createdRaw = data['createdAt'];
    final createdAt = createdRaw is String
        ? DateTime.tryParse(createdRaw) ?? DateTime.now()
        : DateTime.tryParse(dateKey) ?? DateTime.now();

    final ageRaw = data['patientAge'] ?? data['patient_age'];
    int? age;
    if (ageRaw is int) {
      age = ageRaw;
    } else if (ageRaw is num) {
      age = ageRaw.toInt();
    } else {
      age = int.tryParse('$ageRaw');
    }

    return MedicalReport(
      id: '$reportKey/$dateKey',
      reportName: reportName,
      docType: docType,
      category: ReportCategory.fromStorage(
        _readString(
          data,
          const ['category', 'documentType', 'document_type'],
          'lab',
        ),
      ),
      labName: _readString(data, const ['labName', 'lab_name'], ''),
      cityName: _readString(data, const ['cityName', 'city_name'], ''),
      sampleType: _readString(data, const ['sampleType', 'sample_type'], ''),
      collectionDate: collected,
      testDate: approved.isNotEmpty ? approved : dateKey,
      reportApprovedDate: approved,
      patientName: _readString(
        data,
        const ['patientName', 'patient_name'],
        '',
      ),
      patientSex: _readString(data, const ['patientSex', 'patient_sex'], ''),
      patientAge: age,
      regnNo: _readString(data, const ['regnNo', 'regn_no'], ''),
      mrdNo: _readString(data, const ['mrdNo', 'mrd_no'], ''),
      parameters: values
          .map((v) => v.rawLabel.isNotEmpty ? v.rawLabel : v.parameterKey)
          .where((e) => e.isNotEmpty)
          .toList(),
      vitals: vitals,
      values: values,
      conclusion: _readString(
        data,
        const ['conclusion'],
        'No conclusion available.',
      ),
      fileName: _readString(data, const ['fileName', 'file_name'], ''),
      fullReport: fullReport,
      confidence: (data['confidence'] is num)
          ? (data['confidence'] as num).toDouble()
          : 0.0,
      createdAt: createdAt,
      isStarred: data['isStarred'] == true || data['starred'] == true,
    );
  }

  static String buildDocumentId({
    required ReportCategory category,
    required String reportName,
    required String testDate,
    DateTime? createdAt,
  }) {
    final key = slugify(reportName);
    final date = normalizeDateKey(testDate);
    return '$key/$date';
  }

  static String slugify(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) return 'unknown';
    // Common panel aliases.
    if (trimmed == 'cbc' ||
        trimmed.contains('complete blood') ||
        trimmed == 'haemogram' ||
        trimmed == 'hemogram') {
      return 'cbc';
    }
    if (trimmed.contains('lipid')) return 'lipid_profile';
    if (trimmed.contains('liver') || trimmed == 'lft') return 'lft';
    if (trimmed.contains('kidney') ||
        trimmed.contains('renal') ||
        trimmed == 'kft' ||
        trimmed == 'rft') {
      return 'kft';
    }
    if (trimmed.contains('thyroid') || trimmed.contains('tsh')) {
      return 'thyroid_profile';
    }
    if (trimmed.contains('urine')) return 'urine_routine';
    if (trimmed.contains('vitamin')) return 'vitamin_panel';
    if (trimmed.contains('iron')) return 'iron_studies';
    if (trimmed.contains('sugar') ||
        trimmed.contains('glucose') ||
        trimmed.contains('diabetes') ||
        trimmed.contains('hba1c')) {
      return 'blood_sugar';
    }

    return trimmed
        .replaceAll(RegExp(r'[/\\#?\[\].]'), '-')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static String normalizeDateKey(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text == 'Unknown date') {
      return DateTime.now().toIso8601String().split('T').first;
    }
    final iso = DateTime.tryParse(text);
    if (iso != null) {
      return '${iso.year.toString().padLeft(4, '0')}-'
          '${iso.month.toString().padLeft(2, '0')}-'
          '${iso.day.toString().padLeft(2, '0')}';
    }
    // dd/mm/yyyy or dd-mm-yyyy
    final m = RegExp(r'^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})$')
        .firstMatch(text);
    if (m != null) {
      final d = int.tryParse(m.group(1)!);
      final mo = int.tryParse(m.group(2)!);
      var y = int.tryParse(m.group(3)!);
      if (d != null && mo != null && y != null) {
        if (y < 100) y += 2000;
        return '${y.toString().padLeft(4, '0')}-'
            '${mo.toString().padLeft(2, '0')}-'
            '${d.toString().padLeft(2, '0')}';
      }
    }
    return slugify(text);
  }

  static LabValue _labValueFromVital(VitalRow row) {
    num? low;
    num? high;
    final range = RegExp(
      r'(-?\d+(?:\.\d+)?)\s*[-–—to]+\s*(-?\d+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(row.reference);
    if (range != null) {
      low = num.tryParse(range.group(1)!);
      high = num.tryParse(range.group(2)!);
    }
    final numeric = num.tryParse(row.value.replaceAll(',', ''));
    return LabValue(
      parameterKey: slugify(row.parameter),
      rawLabel: row.parameter,
      valueType: numeric != null ? 'numeric' : 'text',
      value: numeric ?? row.value,
      unit: row.unit,
      refLow: low,
      refHigh: high,
      flag: switch (row.status) {
        VitalStatus.low => 'L',
        VitalStatus.high => 'H',
        _ => null,
      },
    );
  }

  static String _readString(
    Map<String, dynamic> data,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }
}
