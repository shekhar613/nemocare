import 'standard_lab_references.dart';

enum VitalStatus { low, normal, high, unknown }

/// One lab/vital row for the Vitals table.
class VitalRow {
  const VitalRow({
    required this.parameter,
    required this.value,
    required this.unit,
    required this.reference,
    required this.status,
  });

  final String parameter;
  final String value;
  final String unit;
  final String reference;
  final VitalStatus status;

  factory VitalRow.fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['status'] as String?)?.trim().toLowerCase() ?? '';
    var status = switch (statusRaw) {
      'low' => VitalStatus.low,
      'high' => VitalStatus.high,
      'normal' || 'ok' || 'within_range' => VitalStatus.normal,
      _ => VitalStatus.unknown,
    };

    final value = (json['value'] ?? json['report'] ?? '').toString().trim();
    final reference =
        (json['reference'] ?? json['ref_range'] ?? '').toString().trim();

    if (status == VitalStatus.unknown) {
      status = evaluateStatus(value, reference);
    }

    return VitalRow(
      parameter: (json['parameter'] ?? json['name'] ?? '').toString().trim(),
      value: value,
      unit: (json['unit'] ?? '').toString().trim(),
      reference: reference,
      status: status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'parameter': parameter,
      'value': value,
      'unit': unit,
      'reference': reference,
      'status': status.name,
    };
  }

  /// Best-effort compare of a numeric value against common reference formats:
  /// "12-15", "12.0 - 15.0", "< 200", "under 140", "above 40", "≤ 5", "≥ 3.5"
  static VitalStatus evaluateStatus(String valueText, String referenceText) {
    final value = _firstNumber(valueText);
    if (value == null || referenceText.trim().isEmpty) {
      return VitalStatus.unknown;
    }

    var ref = referenceText.trim().toLowerCase();
    ref = ref
        .replaceAll('under', '<')
        .replaceAll('below', '<')
        .replaceAll('above', '>')
        .replaceAll('over', '>');

    // Prefer the first numeric range when gender-specific text is present.
    final range = RegExp(
      r'(-?\d+(?:\.\d+)?)\s*[-–—to]+\s*(-?\d+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(ref);
    if (range != null) {
      final low = double.tryParse(range.group(1)!);
      final high = double.tryParse(range.group(2)!);
      if (low != null && high != null) {
        if (value < low) return VitalStatus.low;
        if (value > high) return VitalStatus.high;
        return VitalStatus.normal;
      }
    }

    final less = RegExp(
      r'(?:<|>|=|≤|≥|<=|>=)\s*(-?\d+(?:\.\d+)?)',
    ).firstMatch(ref);
    if (less != null) {
      final bound = double.tryParse(less.group(1)!);
      if (bound == null) return VitalStatus.unknown;
      final op = less.group(0)!.trim();
      if (op.startsWith('≤') || op.startsWith('<=')) {
        return value <= bound ? VitalStatus.normal : VitalStatus.high;
      }
      if (op.startsWith('<')) {
        return value < bound ? VitalStatus.normal : VitalStatus.high;
      }
      if (op.startsWith('≥') || op.startsWith('>=')) {
        return value >= bound ? VitalStatus.normal : VitalStatus.low;
      }
      if (op.startsWith('>')) {
        return value > bound ? VitalStatus.normal : VitalStatus.low;
      }
    }

    return VitalStatus.unknown;
  }

  static double? _firstNumber(String text) {
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(text.trim());
    if (match == null) return null;
    return double.tryParse(match.group(0)!);
  }

  /// Prefer stored vitals; otherwise derive from report payload.
  /// Shows complete report parameters (junk demographics filtered only).
  static List<VitalRow> resolveForDisplay({
    required List<VitalRow> vitals,
    required List<String> parameters,
    required Map<String, dynamic> fullReport,
  }) {
    final derived = <VitalRow>[];

    void addUnique(VitalRow row) {
      if (row.parameter.isEmpty) return;
      if (StandardLabReferences.isJunkParameter(row.parameter)) return;
      final exists = derived.any(
        (r) => r.parameter.toLowerCase() == row.parameter.toLowerCase(),
      );
      if (!exists) derived.add(row);
    }

    // Prefer the full extracted vitals list from the report.
    for (final row in vitals) {
      addUnique(row);
    }

    for (final key in ['vitals', 'results', 'lab_results', 'parameters_detail']) {
      final nested = fullReport[key];
      if (nested is List) {
        for (final item in nested) {
          if (item is Map) {
            addUnique(VitalRow.fromJson(Map<String, dynamic>.from(item)));
          } else if (item is String) {
            final parsed = tryParseFindingLine(item);
            if (parsed != null) addUnique(parsed);
          }
        }
      }
    }

    final findings = fullReport['key_findings'];
    if (findings is List) {
      for (final item in findings) {
        if (item is Map) {
          addUnique(VitalRow.fromJson(Map<String, dynamic>.from(item)));
        } else if (item is String) {
          final parsed = tryParseFindingLine(item);
          if (parsed != null) addUnique(parsed);
        }
      }
    }

    final raw = fullReport['raw_extract'];
    if (raw is String && raw.trim().isNotEmpty) {
      for (final line in raw.split(RegExp(r'[\n;|]'))) {
        final parsed = tryParseFindingLine(line.trim());
        if (parsed != null) addUnique(parsed);
      }
    }

    // Include any leftover parameter names that still have no row.
    for (final name in parameters) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) continue;
      if (StandardLabReferences.isJunkParameter(trimmed)) continue;
      final exists = derived.any(
        (r) => r.parameter.toLowerCase() == trimmed.toLowerCase(),
      );
      if (exists) continue;
      addUnique(
        VitalRow(
          parameter: trimmed,
          value: '—',
          unit: '',
          reference: StandardLabReferences.lookup(trimmed)?.reference ?? '—',
          status: VitalStatus.unknown,
        ),
      );
    }

    return StandardLabReferences.sanitize(derived);
  }

  /// Parses lines like:
  /// `Hemoglobin: 13.5 g/dL (12.0-15.0)`
  /// `WBC - 7200 /cumm [4000-11000]`
  static VitalRow? tryParseFindingLine(String line) {
    final cleaned = line.trim();
    if (cleaned.isEmpty || cleaned.length > 120) return null;

    final match = RegExp(
      r'^([A-Za-z][A-Za-z0-9 %/().+]{1,40}?)\s*[:=\-–—]\s*(.+)$',
    ).firstMatch(cleaned);
    if (match == null) return null;

    final parameter = match.group(1)!.trim();
    if (StandardLabReferences.isJunkParameter(parameter)) return null;

    var rest = match.group(2)!.trim();
    if (_firstNumber(rest) == null) return null;

    String reference = '';
    final paren = RegExp(r'[\(\[]([^)\]]+)[\)\]]\s*$').firstMatch(rest);
    if (paren != null) {
      reference = paren.group(1)!.trim();
      rest = rest.substring(0, paren.start).trim();
    }

    rest = rest.replaceFirst(RegExp(r'\s+[HL]\s*$', caseSensitive: false), '');

    final valueMatch = RegExp(r'(-?\d+(?:\.\d+)?)').firstMatch(rest);
    if (valueMatch == null) return null;
    final value = valueMatch.group(1)!;
    final unit = rest.substring(valueMatch.end).trim();

    final statusHint = cleaned.toUpperCase().endsWith(' H')
        ? VitalStatus.high
        : cleaned.toUpperCase().endsWith(' L')
            ? VitalStatus.low
            : evaluateStatus(value, reference);

    return VitalRow(
      parameter: parameter,
      value: value,
      unit: unit,
      reference: reference,
      status: statusHint,
    );
  }
}
