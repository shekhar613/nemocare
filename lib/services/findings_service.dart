import '../models/finding.dart';
import '../models/user_profile.dart';

/// Derives stable, named findings from raw report values on `USERS/{email}`.
///
/// Pure Dart — no LLM. Run after each report save so chat / insights / UI
/// all share the same deterministic facts.
class FindingsService {
  /// Reads the full user document and derives findings from each report
  /// type's latest dated entry.
  List<Finding> computeFindings(Map<String, dynamic> userDoc) {
    final findings = <Finding>[];
    final now = DateTime.now().toIso8601String();

    void add(Finding f) {
      if (f.key.isEmpty) return;
      findings.add(f.copyWith(updatedAt: now));
    }

    // --- CBC ---
    final cbcLatest = _latestReportEntry(userDoc, 'cbc');
    if (cbcLatest != null) {
      final date = cbcLatest.date;
      final byKey = _valuesByKey(cbcLatest.data);

      if (_isLow(byKey['hemoglobin'])) {
        add(
          Finding(
            key: 'low_hemoglobin',
            derivedFrom: ['cbc/$date/hemoglobin'],
            sinceDate: date,
            active: true,
          ),
        );
      }

      if (_isLow(byKey['mcv']) && _isLow(byKey['mch'])) {
        add(
          Finding(
            key: 'microcytic_pattern',
            derivedFrom: ['cbc/$date/mcv', 'cbc/$date/mch'],
            sinceDate: date,
            active: true,
          ),
        );
      }

      if (_isHigh(byKey['neutrophils_pct']) ||
          _isHigh(byKey['neutrophils'])) {
        final param = byKey.containsKey('neutrophils_pct')
            ? 'neutrophils_pct'
            : 'neutrophils';
        add(
          Finding(
            key: 'high_neutrophils',
            derivedFrom: ['cbc/$date/$param'],
            sinceDate: date,
            active: true,
          ),
        );
      }
    }

    // --- Renal / infectious / metabolic panel ---
    final panelLatest =
        _latestReportEntry(userDoc, 'renal_infectious_metabolic_panel') ??
            _latestReportEntry(userDoc, 'blood_sugar') ??
            _latestReportEntry(userDoc, 'kft');
    if (panelLatest != null) {
      final date = panelLatest.date;
      final byKey = _valuesByKey(panelLatest.data);
      final reportType = panelLatest.reportKey;

      final rbs = byKey['random_blood_sugar'] ??
          byKey['blood_sugar'] ??
          byKey['glucose'] ??
          byKey['rbs'];
      if (_isHigh(rbs)) {
        final param = rbs?['parameterKey']?.toString() ?? 'random_blood_sugar';
        add(
          Finding(
            key: 'high_blood_sugar',
            derivedFrom: ['$reportType/$date/$param'],
            sinceDate: date,
            active: true,
          ),
        );
      }

      for (final key in ['hcv_antibody', 'hiv_1_2', 'hbsag']) {
        final v = byKey[key];
        if (_isQualitativeAbnormal(v)) {
          add(
            Finding(
              key: '${key}_abnormal',
              derivedFrom: ['$reportType/$date/$key'],
              sinceDate: date,
              active: true,
            ),
          );
        }
      }
    }

    // --- Urine routine ---
    final urineLatest = _latestReportEntry(userDoc, 'urine_routine');
    if (urineLatest != null) {
      final date = urineLatest.date;
      final byKey = _valuesByKey(urineLatest.data);
      for (final entry in byKey.entries) {
        final v = entry.value;
        if (_isQualitativeAbnormal(v) || _isHigh(v) || _isLow(v)) {
          final flag = (v['flag'] ?? '').toString().toUpperCase();
          final suffix = flag == 'L'
              ? 'low'
              : flag == 'H'
                  ? 'high'
                  : 'abnormal';
          add(
            Finding(
              key: 'urine_${entry.key}_$suffix',
              derivedFrom: ['urine_routine/$date/${entry.key}'],
              sinceDate: date,
              active: true,
            ),
          );
        }
      }
    }

    return findings;
  }

  /// Merges newly computed findings with any previously stored map.
  ///
  /// - New / still-present keys → `active: true`
  /// - Previously stored keys no longer computed → `active: false` (kept for history)
  Map<String, dynamic> mergeFindingsMap({
    required List<Finding> computed,
    Map<String, dynamic>? existing,
  }) {
    final now = DateTime.now().toIso8601String();
    final result = <String, dynamic>{};
    final activeKeys = <String>{};

    for (final f in computed) {
      activeKeys.add(f.key);
      result[f.key] = f.copyWith(active: true, updatedAt: now).toJson();
    }

    if (existing != null) {
      existing.forEach((key, value) {
        if (activeKeys.contains(key)) return;
        if (value is! Map) return;
        final prev = Finding.fromJson(Map<String, dynamic>.from(value));
        if (prev.key.isEmpty) return;
        result[key] = prev.copyWith(active: false, updatedAt: now).toJson();
      });
    }

    return result;
  }

  List<Finding> parseFindingsMap(Map<String, dynamic>? raw, {bool activeOnly = false}) {
    if (raw == null || raw.isEmpty) return [];
    final list = <Finding>[];
    raw.forEach((_, value) {
      if (value is! Map) return;
      final f = Finding.fromJson(Map<String, dynamic>.from(value));
      if (f.key.isEmpty) return;
      if (activeOnly && !f.active) return;
      list.add(f);
    });
    list.sort((a, b) => b.sinceDate.compareTo(a.sinceDate));
    return list;
  }

  /// Latest report for a type — prefers real collection/approved dates, not
  /// just lexicographic map keys (so Jun 8 vs Sep 14 always picks Sep 14).
  ({String reportKey, String date, Map<String, dynamic> data})?
      _latestReportEntry(Map<String, dynamic> userDoc, String reportKey) {
    final raw = userDoc[reportKey];
    if (raw is! Map) return null;
    final byDate = Map<String, dynamic>.from(raw);
    if (byDate.isEmpty) return null;

    String? bestDate;
    Map<String, dynamic>? bestData;
    DateTime? bestSort;

    byDate.forEach((dateKeyRaw, entryRaw) {
      if (entryRaw is! Map) return;
      final dateKey = dateKeyRaw.toString();
      final data = Map<String, dynamic>.from(entryRaw);
      final sortAt = _reportSortDate(dateKey, data);
      final previousBest = bestSort;
      if (previousBest == null || sortAt.isAfter(previousBest)) {
        bestSort = sortAt;
        bestDate = dateKey;
        bestData = data;
      }
    });

    if (bestDate == null || bestData == null) return null;
    return (reportKey: reportKey, date: bestDate!, data: bestData!);
  }

  /// Prefer collected/approved timestamps; fall back to the map date key.
  DateTime _reportSortDate(String dateKey, Map<String, dynamic> data) {
    for (final key in const [
      'collectedDate',
      'collectionDate',
      'reportApprovedDate',
      'testDate',
      'createdAt',
    ]) {
      final parsed = DateTime.tryParse('${data[key] ?? ''}');
      if (parsed != null) return parsed;
    }
    return DateTime.tryParse(dateKey) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  Map<String, Map<String, dynamic>> _valuesByKey(Map<String, dynamic> report) {
    final out = <String, Map<String, dynamic>>{};
    final valuesRaw = report['values'];
    if (valuesRaw is! List) return out;
    for (final item in valuesRaw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final key = (map['parameterKey'] ?? map['parameter_key'] ?? '')
          .toString()
          .trim();
      if (key.isEmpty) continue;
      out[key] = map;
    }
    return out;
  }

  bool _isLow(Map<String, dynamic>? v) {
    if (v == null) return false;
    final flag = (v['flag'] ?? '').toString().trim().toUpperCase();
    if (flag == 'L' || flag == 'LOW') return true;
    final value = _asNum(v['value']);
    final low = _asNum(v['refLow']);
    if (value != null && low != null && value < low) return true;
    return false;
  }

  bool _isHigh(Map<String, dynamic>? v) {
    if (v == null) return false;
    final flag = (v['flag'] ?? '').toString().trim().toUpperCase();
    if (flag == 'H' || flag == 'HIGH') return true;
    final value = _asNum(v['value']);
    final high = _asNum(v['refHigh']);
    if (value != null && high != null && value > high) return true;
    return false;
  }

  bool _isQualitativeAbnormal(Map<String, dynamic>? v) {
    if (v == null) return false;
    final flag = (v['flag'] ?? '').toString().trim().toUpperCase();
    if (flag == 'A' || flag == 'ABNORMAL' || flag == 'H' || flag == 'L') {
      return true;
    }
    final q = (v['qualitativeValue'] ?? v['value'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final ref = (v['refQualitative'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (q.isEmpty || ref.isEmpty) return false;
    if (q == ref) return false;
    // Common negative reference phrasing.
    const negatives = {
      'non reactive',
      'non-reactive',
      'negative',
      'not detected',
      'absent',
      'nil',
    };
    if (negatives.contains(ref) && !negatives.contains(q)) return true;
    return q != ref;
  }

  num? _asNum(dynamic value) {
    if (value is num) return value;
    if (value == null) return null;
    return num.tryParse(value.toString().replaceAll(',', '').trim());
  }

  /// Report-type keys that must never be scanned as lab panels.
  static bool isReservedUserDocKey(String key) =>
      UserProfile.profileFieldKeys.contains(key);
}
