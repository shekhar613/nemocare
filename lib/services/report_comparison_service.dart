import '../models/lab_value.dart';
import '../models/medical_report.dart';
import '../models/report_comparison.dart';

/// Builds Increased / Decreased / Unchanged comparison between two reports.
class ReportComparisonService {
  static const _priorityKeys = [
    'hemoglobin',
    'platelet_count',
    'platelets',
    'wbc',
    'rbc',
    'mcv',
    'mch',
    'mchc',
    'hematocrit',
    'neutrophils_pct',
    'neutrophils',
    'lymphocytes_pct',
    'lymphocytes',
    'glucose',
    'fasting_blood_sugar',
    'creatinine',
    'urea',
    'alt',
    'ast',
    'tsh',
  ];

  static const _displayNames = {
    'hemoglobin': 'Hemoglobin',
    'platelet_count': 'Platelets',
    'platelets': 'Platelets',
    'wbc': 'WBC',
    'rbc': 'RBC',
    'mcv': 'MCV',
    'mch': 'MCH',
    'mchc': 'MCHC',
    'hematocrit': 'Hematocrit',
    'neutrophils_pct': 'Neutrophils',
    'neutrophils': 'Neutrophils',
    'lymphocytes_pct': 'Lymphocytes',
    'lymphocytes': 'Lymphocytes',
    'glucose': 'Glucose',
    'fasting_blood_sugar': 'Fasting glucose',
    'creatinine': 'Creatinine',
    'urea': 'Urea',
    'alt': 'ALT',
    'ast': 'AST',
    'tsh': 'TSH',
  };

  /// Heuristic: user is asking to compare / see changes across reports.
  static bool isComparisonIntent(String question) {
    final q = question.toLowerCase().trim();
    if (q.isEmpty) return false;
    const needles = [
      'compar',
      'vs',
      'versus',
      'difference',
      'differ',
      'change',
      'changed',
      'trend',
      'progress',
      'previous',
      'earlier',
      'last two',
      'two report',
      'between report',
      'how am i doing',
      'improved',
      'worsen',
      'delta',
      'before and after',
      'old report',
      'new report',
      'latest report',
      'my reports',
    ];
    return needles.any(q.contains);
  }

  /// Compare the two most recent reports of the same type (prefers CBC).
  ReportComparison? compareLatestPair(
    List<MedicalReport> reports, {
    String? preferredType,
  }) {
    if (reports.length < 2) return null;

    final type = preferredType?.trim().isNotEmpty == true
        ? preferredType!.trim().toLowerCase()
        : _pickDominantType(reports);
    if (type == null) return null;

    final same = reports.where((r) => r.storageKey == type).toList()
      ..sort((a, b) => _sortMs(b).compareTo(_sortMs(a)));
    if (same.length < 2) return null;

    return compareReports(same[1], same[0]);
  }

  ReportComparison compareReports(
    MedicalReport previous,
    MedicalReport current,
  ) {
    final prevMap = _indexNumeric(previous);
    final currMap = _indexNumeric(current);
    final keys = <String>{...prevMap.keys, ...currMap.keys};

    final increased = <ComparisonMetric>[];
    final decreased = <ComparisonMetric>[];
    final unchanged = <ComparisonMetric>[];

    for (final key in _orderedKeys(keys)) {
      final a = prevMap[key];
      final b = currMap[key];
      if (a == null || b == null) continue;
      final metric = _metricFor(key, a, b);
      if (metric == null) continue;
      switch (metric.direction) {
        case ComparisonDirection.increased:
          increased.add(metric);
        case ComparisonDirection.decreased:
          decreased.add(metric);
        case ComparisonDirection.unchanged:
          unchanged.add(metric);
      }
    }

    // Cap each group for readable cards.
    final inc = increased.take(5).toList();
    final dec = decreased.take(5).toList();
    final unc = unchanged.take(4).toList();

    final label = current.reportName.isNotEmpty
        ? current.reportName
        : current.storageKey.toUpperCase();

    final intro = _intro(inc, dec, unc, label);
    final insight = _defaultInsight(inc, dec, unc);

    return ReportComparison(
      reportType: current.storageKey,
      reportLabel: label,
      previousDate: previous.dateKey.isNotEmpty
          ? previous.dateKey
          : previous.displayCollectionDate,
      currentDate: current.dateKey.isNotEmpty
          ? current.dateKey
          : current.displayCollectionDate,
      increased: inc,
      decreased: dec,
      unchanged: unc,
      intro: intro,
      insight: insight,
    );
  }

  String? _pickDominantType(List<MedicalReport> reports) {
    final counts = <String, int>{};
    for (final r in reports) {
      final k = r.storageKey;
      if (k.isEmpty) continue;
      counts[k] = (counts[k] ?? 0) + 1;
    }
    // Prefer CBC when at least two exist.
    if ((counts['cbc'] ?? 0) >= 2) return 'cbc';
    String? best;
    var bestN = 0;
    for (final e in counts.entries) {
      if (e.value >= 2 && e.value > bestN) {
        best = e.key;
        bestN = e.value;
      }
    }
    return best;
  }

  int _sortMs(MedicalReport r) {
    for (final raw in [
      r.collectionDate,
      r.testDate,
      r.reportApprovedDate,
      r.dateKey,
    ]) {
      final parsed = DateTime.tryParse(raw.trim());
      if (parsed != null) return parsed.millisecondsSinceEpoch;
    }
    return r.createdAt.millisecondsSinceEpoch;
  }

  Map<String, LabValue> _indexNumeric(MedicalReport report) {
    final out = <String, LabValue>{};
    final source = report.values.isNotEmpty
        ? report.values
        : report.displayVitals.map(
            (v) => LabValue(
              parameterKey: _slug(v.parameter),
              rawLabel: v.parameter,
              valueType: 'numeric',
              value: num.tryParse(v.value.replaceAll(',', '')) ?? v.value,
              unit: v.unit,
            ),
          );

    for (final v in source) {
      final key = _normalizeKey(v.parameterKey.isNotEmpty
          ? v.parameterKey
          : _slug(v.rawLabel));
      if (key.isEmpty) continue;
      final n = _asNum(v.value);
      if (n == null) continue;
      // Prefer *_pct when both exist.
      if (out.containsKey(key) && key.endsWith('_pct') == false) {
        continue;
      }
      out[key] = LabValue(
        parameterKey: key,
        rawLabel: v.rawLabel,
        valueType: 'numeric',
        value: n,
        unit: v.unit,
        refLow: v.refLow,
        refHigh: v.refHigh,
        flag: v.flag,
      );
    }
    return out;
  }

  ComparisonMetric? _metricFor(String key, LabValue prev, LabValue curr) {
    final a = _asNum(prev.value);
    final b = _asNum(curr.value);
    if (a == null || b == null) return null;

    final unit = curr.unit.isNotEmpty ? curr.unit : prev.unit;
    final absDelta = b - a;
    final pct = a.abs() < 1e-9 ? null : (absDelta / a.abs()) * 100.0;

    // Unchanged when relative move is tiny (or absolute for small labs).
    final unchanged = (pct != null && pct.abs() < 1.0) ||
        (pct == null && absDelta.abs() < 0.05);

    final direction = unchanged
        ? ComparisonDirection.unchanged
        : (absDelta > 0
            ? ComparisonDirection.increased
            : ComparisonDirection.decreased);

    final badge = unchanged
        ? '—'
        : _badgeText(
            absDelta: absDelta,
            pct: pct,
            unit: unit,
            direction: direction,
          );

    return ComparisonMetric(
      parameterKey: key,
      label: _labelFor(key, curr.rawLabel.isNotEmpty ? curr.rawLabel : prev.rawLabel),
      previousValue: a,
      currentValue: b,
      unit: unit,
      direction: direction,
      badgeText: badge,
      previousRaw: _formatNumber(a),
      currentRaw: _formatNumber(b),
    );
  }

  String _badgeText({
    required double absDelta,
    required double? pct,
    required String unit,
    required ComparisonDirection direction,
  }) {
    final sign = direction == ComparisonDirection.increased ? '+' : '';
    // Prefer % when change is meaningful in relative terms.
    if (pct != null && pct.abs() >= 5) {
      return '$sign${pct.toStringAsFixed(1)}%';
    }
    final absStr = _formatNumber(absDelta.abs());
    final u = unit.trim();
    if (u.isEmpty) return '$sign$absStr';
    return '$sign$absStr $u';
  }

  String _intro(
    List<ComparisonMetric> inc,
    List<ComparisonMetric> dec,
    List<ComparisonMetric> unc,
    String label,
  ) {
    if (inc.isEmpty && dec.isEmpty) {
      return 'Your latest $label looks stable versus the previous one.';
    }
    if (inc.isNotEmpty && dec.isNotEmpty) {
      return 'Your latest $label shows a few changes.';
    }
    if (inc.isNotEmpty) {
      return 'Your latest $label shows some increases.';
    }
    return 'Your latest $label shows some decreases.';
  }

  String _defaultInsight(
    List<ComparisonMetric> inc,
    List<ComparisonMetric> dec,
    List<ComparisonMetric> unc,
  ) {
    final parts = <String>[];
    if (inc.isNotEmpty) {
      parts.add(
        '${inc.first.label} rose from ${inc.first.previousRaw} to ${inc.first.currentRaw}'
        '${inc.first.unit.isEmpty ? '' : ' ${inc.first.unit}'}.',
      );
    }
    if (dec.isNotEmpty) {
      final names = dec.take(2).map((e) => e.label).join(' and ');
      parts.add('$names moved lower on the newer report.');
    }
    if (parts.isEmpty && unc.isNotEmpty) {
      parts.add(
        '${unc.first.label} stayed at ${unc.first.currentRaw}'
        '${unc.first.unit.isEmpty ? '' : ' ${unc.first.unit}'}.',
      );
    }
    parts.add('Consider discussing notable shifts with your clinician.');
    return parts.join(' ');
  }

  List<String> _orderedKeys(Set<String> keys) {
    final ordered = <String>[];
    for (final p in _priorityKeys) {
      if (keys.contains(p)) ordered.add(p);
    }
    final rest = keys.where((k) => !ordered.contains(k)).toList()..sort();
    ordered.addAll(rest);
    return ordered;
  }

  String _labelFor(String key, String fallback) {
    final mapped = _displayNames[key];
    if (mapped != null) return mapped;
    if (fallback.trim().isNotEmpty) return fallback.trim();
    return key
        .split('_')
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  String _normalizeKey(String raw) {
    var k = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');
    if (k == 'platelet' || k == 'plt') k = 'platelet_count';
    if (k == 'hb' || k == 'hgb') k = 'hemoglobin';
    if (k == 'hct') k = 'hematocrit';
    return k;
  }

  String _slug(String raw) =>
      raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  double? _asNum(dynamic value) {
    if (value is num) return value.toDouble();
    final t = value?.toString().replaceAll(',', '').trim() ?? '';
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  String _formatNumber(double n) {
    if (n == n.roundToDouble() && n.abs() >= 1000) {
      final digits = n.round().abs().toString();
      final buf = StringBuffer();
      for (var i = 0; i < digits.length; i++) {
        if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
        buf.write(digits[i]);
      }
      return n < 0 ? '-$buf' : buf.toString();
    }
    if (n == n.roundToDouble()) return n.round().toString();
    final fixed = n.abs() >= 10 ? n.toStringAsFixed(1) : n.toStringAsFixed(2);
    return fixed.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
}
