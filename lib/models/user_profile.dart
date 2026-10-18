/// Profile fields stored on `USERS/{email}` (report maps live alongside these).
class UserProfile {
  const UserProfile({
    required this.email,
    required this.name,
    this.dob = '',
    this.ageRange = '',
    this.ageApproximate = false,
    this.sex = '',
    this.genderIdentity = '',
    this.heightCm = '',
    this.weightKg = '',
    this.bmi = '',
    this.heightApproximate = false,
    this.weightApproximate = false,
    this.married = '',
    this.bloodGroup = '',
    this.knownConditions = const [],
    this.onDialysis = false,
    this.eyeConditions = const [],
    this.skinConditions = const [],
    this.foodIntolerances = const [],
    this.drugAllergies = const [],
    this.otherAllergies = const [],
    this.currentMedications = const [],
    this.smokingStatus = '',
    this.alcoholUse = '',
    this.dietPreference = '',
    this.activityLevel = '',
    this.pregnancyStatus = '',
    this.onboardingCompleted = false,
  });

  final String email;
  final String name;
  final String dob;
  final String ageRange;
  final bool ageApproximate;

  /// Biological sex for lab reference ranges (`male` | `female` | `prefer_not_to_say`).
  final String sex;

  /// Optional identity label — kept separate from [sex].
  final String genderIdentity;

  final String heightCm;
  final String weightKg;
  final String bmi;
  final bool heightApproximate;
  final bool weightApproximate;
  final String married;
  final String bloodGroup;

  final List<String> knownConditions;
  final bool onDialysis;
  final List<String> eyeConditions;
  final List<String> skinConditions;
  final List<String> foodIntolerances;
  final List<String> drugAllergies;
  final List<String> otherAllergies;

  /// Each item: `{ "name": "...", "dosage": "..." }`.
  final List<Map<String, String>> currentMedications;

  final String smokingStatus;
  final String alcoholUse;
  final String dietPreference;
  final String activityLevel;
  final String pregnancyStatus;
  final bool onboardingCompleted;

  /// Keys that are profile / meta fields — everything else on the doc may be a report map.
  static const profileFieldKeys = {
    'name',
    'dob',
    'ageRange',
    'ageApproximate',
    'sex',
    'gender',
    'genderIdentity',
    'height_cm',
    'weight_kg',
    'bmi',
    'heightApproximate',
    'weightApproximate',
    'married',
    'bloodGroup',
    'knownConditions',
    'onDialysis',
    'eyeConditions',
    'skinConditions',
    'foodIntolerances',
    'drugAllergies',
    'otherAllergies',
    'currentMedications',
    'allergies',
    'smokingStatus',
    'alcoholUse',
    'dietPreference',
    'activityLevel',
    'pregnancyStatus',
    'onboardingCompleted',
    'onboardingCompletedAt',
    'email',
    'uid',
    'createdAt',
    'updatedAt',
    'findings',
    'insights',
    'insights_meta',
  };

  Map<String, dynamic> toFirestoreCreate() {
    return {
      ...toFirestoreUpdate(),
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestoreUpdate() {
    final medNames = currentMedications
        .map((m) => (m['name'] ?? '').trim())
        .where((n) => n.isNotEmpty)
        .toList();
    final allergyUnion = <String>{
      ...drugAllergies,
      ...otherAllergies,
      ...foodIntolerances.where((k) => k != 'none'),
    }.toList();

    return {
      'email': email.trim().toLowerCase(),
      'name': name.trim(),
      'dob': dob,
      'ageRange': ageRange,
      'ageApproximate': ageApproximate,
      'sex': sex,
      // Backward-compatible alias used by older chat / findings paths.
      'gender': sex,
      'genderIdentity': genderIdentity,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'bmi': bmi,
      'heightApproximate': heightApproximate,
      'weightApproximate': weightApproximate,
      'married': married,
      'bloodGroup': bloodGroup,
      'knownConditions': knownConditions,
      'onDialysis': onDialysis,
      'eyeConditions': eyeConditions,
      'skinConditions': skinConditions,
      'foodIntolerances': foodIntolerances,
      'drugAllergies': drugAllergies,
      'otherAllergies': otherAllergies,
      'currentMedications': currentMedications,
      // Flat list for existing safety filters.
      'allergies': allergyUnion,
      'medicationNames': medNames,
      'smokingStatus': smokingStatus,
      'alcoholUse': alcoholUse,
      'dietPreference': dietPreference,
      'activityLevel': activityLevel,
      'pregnancyStatus': pregnancyStatus,
      'onboardingCompleted': onboardingCompleted,
      if (onboardingCompleted)
        'onboardingCompletedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory UserProfile.fromFirestore(String email, Map<String, dynamic> data) {
    final sex = '${data['sex'] ?? data['gender'] ?? ''}'.trim();
    return UserProfile(
      email: email,
      name: (data['name'] as String?)?.trim() ?? '',
      dob: '${data['dob'] ?? ''}',
      ageRange: '${data['ageRange'] ?? ''}',
      ageApproximate: data['ageApproximate'] == true,
      sex: sex,
      genderIdentity: '${data['genderIdentity'] ?? ''}',
      heightCm: '${data['height_cm'] ?? ''}',
      weightKg: '${data['weight_kg'] ?? ''}',
      bmi: '${data['bmi'] ?? ''}',
      heightApproximate: data['heightApproximate'] == true,
      weightApproximate: data['weightApproximate'] == true,
      married: '${data['married'] ?? ''}',
      bloodGroup: '${data['bloodGroup'] ?? ''}',
      knownConditions: _stringList(data['knownConditions']),
      onDialysis: data['onDialysis'] == true,
      eyeConditions: _stringList(data['eyeConditions']),
      skinConditions: _stringList(data['skinConditions']),
      foodIntolerances: _stringList(data['foodIntolerances']),
      drugAllergies: _stringList(data['drugAllergies']),
      otherAllergies: _stringList(data['otherAllergies']),
      currentMedications: _medList(data['currentMedications']),
      smokingStatus: '${data['smokingStatus'] ?? ''}',
      alcoholUse: '${data['alcoholUse'] ?? ''}',
      dietPreference: '${data['dietPreference'] ?? ''}',
      activityLevel: '${data['activityLevel'] ?? ''}',
      pregnancyStatus: '${data['pregnancyStatus'] ?? ''}',
      onboardingCompleted: data['onboardingCompleted'] == true,
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static List<Map<String, String>> _medList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <Map<String, String>>[];
    for (final item in raw) {
      if (item is Map) {
        final name = '${item['name'] ?? ''}'.trim();
        if (name.isEmpty) continue;
        out.add({
          'name': name,
          'dosage': '${item['dosage'] ?? ''}'.trim(),
        });
      } else {
        final name = item?.toString().trim() ?? '';
        if (name.isNotEmpty) out.add({'name': name, 'dosage': ''});
      }
    }
    return out;
  }

  /// Best-effort age in years from `dob` (YYYY-MM-DD or parseable date).
  static int? ageFromDob(String dob, {DateTime? now}) {
    final text = dob.trim();
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    final today = now ?? DateTime.now();
    var age = today.year - parsed.year;
    final hadBirthday = today.month > parsed.month ||
        (today.month == parsed.month && today.day >= parsed.day);
    if (!hadBirthday) age -= 1;
    return age < 0 ? null : age;
  }

  static String? computeBmi(String heightCm, String weightKg) {
    final h = double.tryParse(heightCm.trim());
    final w = double.tryParse(weightKg.trim());
    if (h == null || w == null || h <= 0 || w <= 0) return null;
    final meters = h / 100.0;
    final bmi = w / (meters * meters);
    return bmi.toStringAsFixed(1);
  }
}
