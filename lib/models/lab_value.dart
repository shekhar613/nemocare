/// One lab parameter row matching USERS report `values[]` entries.
class LabValue {
  const LabValue({
    required this.parameterKey,
    required this.rawLabel,
    required this.valueType,
    required this.value,
    required this.unit,
    this.refLow,
    this.refHigh,
    this.flag,
  });

  final String parameterKey;
  final String rawLabel;
  final String valueType; // numeric | text
  final dynamic value; // num or String
  final String unit;
  final num? refLow;
  final num? refHigh;
  final String? flag; // L | H | null

  Map<String, dynamic> toJson() {
    return {
      'parameterKey': parameterKey,
      'rawLabel': rawLabel,
      'valueType': valueType,
      'value': value,
      'unit': unit,
      'refLow': refLow,
      'refHigh': refHigh,
      'flag': flag,
    };
  }

  factory LabValue.fromJson(Map<String, dynamic> json) {
    return LabValue(
      parameterKey: (json['parameterKey'] ?? json['parameter_key'] ?? '')
          .toString()
          .trim(),
      rawLabel:
          (json['rawLabel'] ?? json['raw_label'] ?? '').toString().trim(),
      valueType:
          (json['valueType'] ?? json['value_type'] ?? 'numeric').toString(),
      value: json['value'],
      unit: (json['unit'] ?? '').toString().trim(),
      refLow: json['refLow'] is num
          ? json['refLow'] as num
          : num.tryParse('${json['refLow'] ?? ''}'),
      refHigh: json['refHigh'] is num
          ? json['refHigh'] as num
          : num.tryParse('${json['refHigh'] ?? ''}'),
      flag: () {
        final f = json['flag'];
        if (f == null) return null;
        final text = f.toString().trim();
        return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
      }(),
    );
  }

  String get referenceText {
    if (refLow != null && refHigh != null) return '$refLow - $refHigh';
    if (refHigh != null) return '≤ $refHigh';
    if (refLow != null) return '≥ $refLow';
    return '';
  }

  String get statusName {
    final f = flag?.toUpperCase();
    if (f == 'L' || f == 'LOW') return 'low';
    if (f == 'H' || f == 'HIGH') return 'high';
    if (value is num && refLow != null && refHigh != null) {
      final v = (value as num).toDouble();
      if (v < refLow!.toDouble()) return 'low';
      if (v > refHigh!.toDouble()) return 'high';
      return 'normal';
    }
    return 'unknown';
  }
}
