import '../models/finding.dart';
import '../models/user_profile.dart';

/// Shared assembly of profile + active findings + supporting lab values.
///
/// Used by Insights (and eventually chat) so both layers cite the same
/// numbers and apply the same safety context (meds / allergies).
class PatientContext {
  const PatientContext({
    required this.profile,
    required this.activeFindings,
    required this.supportingValues,
  });

  /// Lightweight profile slice for prompts / safety filters.
  final Map<String, dynamic> profile;

  final List<Finding> activeFindings;

  /// `findingKey` → list of resolved value maps (one per `derivedFrom` path).
  final Map<String, List<Map<String, dynamic>>> supportingValues;

  bool get hasActiveFindings => activeFindings.isNotEmpty;

  List<String> get medications =>
      (profile['medications'] as List?)?.map((e) => e.toString()).toList() ??
      const [];

  List<String> get allergies =>
      (profile['allergies'] as List?)?.map((e) => e.toString()).toList() ??
      const [];
}

class PatientContextService {
  /// Builds context from a full `USERS/{email}` Firestore document.
  PatientContext build(Map<String, dynamic> userDoc) {
    final findingsRaw = userDoc['findings'];
    final findingsMap = findingsRaw is Map
        ? Map<String, dynamic>.from(findingsRaw)
        : <String, dynamic>{};

    final activeFindings = <Finding>[];
    findingsMap.forEach((_, value) {
      if (value is! Map) return;
      final finding = Finding.fromJson(Map<String, dynamic>.from(value));
      if (finding.key.isEmpty || !finding.active) return;
      activeFindings.add(finding);
    });
    activeFindings.sort((a, b) => b.sinceDate.compareTo(a.sinceDate));

    final supporting = <String, List<Map<String, dynamic>>>{};
    for (final finding in activeFindings) {
      supporting[finding.key] = finding.derivedFrom
          .map((path) => _resolvePath(userDoc, path))
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    final dob = '${userDoc['dob'] ?? ''}';

    return PatientContext(
      profile: {
        'name': '${userDoc['name'] ?? ''}',
        'dob': dob,
        'age': UserProfile.ageFromDob(dob),
        'sex': '${userDoc['gender'] ?? ''}',
        'gender': '${userDoc['gender'] ?? ''}',
        'height_cm': '${userDoc['height_cm'] ?? ''}',
        'weight_kg': '${userDoc['weight_kg'] ?? ''}',
        'bmi': '${userDoc['bmi'] ?? ''}',
        'married': '${userDoc['married'] ?? ''}',
        'medications': _stringList(userDoc['currentMedications']),
        'allergies': _stringList(userDoc['allergies']),
      },
      activeFindings: activeFindings,
      supportingValues: supporting,
    );
  }

  /// Resolves `cbc/2026-09-14/mcv` → the matching `values[]` entry (plus path meta).
  Map<String, dynamic>? _resolvePath(Map<String, dynamic> userDoc, String path) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length < 3) return null;

    final reportKey = parts[0];
    final dateKey = parts[1];
    final parameterKey = parts[2];

    final reportType = userDoc[reportKey];
    if (reportType is! Map) return null;
    final report = reportType[dateKey];
    if (report is! Map) return null;

    final valuesRaw = report['values'];
    if (valuesRaw is! List) {
      return {
        'path': path,
        'reportType': reportKey,
        'date': dateKey,
        'parameterKey': parameterKey,
      };
    }

    Map<String, dynamic>? match;
    for (final item in valuesRaw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final key = (map['parameterKey'] ?? map['parameter_key'] ?? '')
          .toString()
          .trim();
      if (key == parameterKey) {
        match = map;
        break;
      }
    }

    if (match == null) return null;

    return {
      ...match,
      'path': path,
      'reportType': reportKey,
      'date': dateKey,
      'labName': report['labName'],
      'reportName': report['reportName'] ?? report['docType'] ?? reportKey,
    };
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }
}
