/// Deterministic clinical finding derived from report values (no LLM).
class Finding {
  const Finding({
    required this.key,
    required this.derivedFrom,
    required this.sinceDate,
    required this.active,
    this.updatedAt,
  });

  /// Stable id, e.g. `low_hemoglobin`, `microcytic_pattern`.
  final String key;

  /// Trace paths: `reportType/date/parameterKey`.
  final List<String> derivedFrom;

  /// Date of the report entry that produced this finding.
  final String sinceDate;

  final bool active;
  final String? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'derivedFrom': derivedFrom,
      'sinceDate': sinceDate,
      'active': active,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  factory Finding.fromJson(Map<String, dynamic> json) {
    final derived = <String>[];
    final raw = json['derivedFrom'];
    if (raw is List) {
      for (final item in raw) {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) derived.add(text);
      }
    }
    return Finding(
      key: (json['key'] ?? '').toString().trim(),
      derivedFrom: derived,
      sinceDate: (json['sinceDate'] ?? '').toString().trim(),
      active: json['active'] == true,
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  Finding copyWith({
    String? key,
    List<String>? derivedFrom,
    String? sinceDate,
    bool? active,
    String? updatedAt,
  }) {
    return Finding(
      key: key ?? this.key,
      derivedFrom: derivedFrom ?? this.derivedFrom,
      sinceDate: sinceDate ?? this.sinceDate,
      active: active ?? this.active,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Short label for UI chips.
  String get displayLabel {
    switch (key) {
      case 'low_hemoglobin':
        return 'Low hemoglobin';
      case 'microcytic_pattern':
        return 'Low MCV + MCH';
      case 'high_neutrophils':
        return 'High neutrophils';
      case 'high_blood_sugar':
        return 'High blood sugar';
      case 'hcv_antibody_abnormal':
        return 'HCV antibody abnormal';
      case 'hiv_1_2_abnormal':
        return 'HIV screen abnormal';
      case 'hbsag_abnormal':
        return 'HBsAg abnormal';
      default:
        return key.replaceAll('_', ' ');
    }
  }
}
