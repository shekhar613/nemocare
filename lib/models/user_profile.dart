/// Profile fields stored on `USERS/{email}` (report maps live alongside these).
class UserProfile {
  const UserProfile({
    required this.email,
    required this.name,
    this.dob = '',
    this.gender = '',
    this.heightCm = '',
    this.weightKg = '',
    this.bmi = '',
    this.married = '',
    this.currentMedications = const [],
    this.allergies = const [],
  });

  final String email;
  final String name;
  final String dob;
  final String gender;
  final String heightCm;
  final String weightKg;
  final String bmi;
  final String married;

  /// Free-text / structured med names for insights safety filtering.
  final List<String> currentMedications;

  /// Known allergies for insights safety filtering.
  final List<String> allergies;

  /// Keys that are profile / meta fields — everything else on the doc may be a report map.
  static const profileFieldKeys = {
    'name',
    'dob',
    'gender',
    'height_cm',
    'weight_kg',
    'bmi',
    'married',
    'email',
    'uid',
    'createdAt',
    'updatedAt',
    'findings',
    'insights',
    'insights_meta',
    'currentMedications',
    'allergies',
  };

  Map<String, dynamic> toFirestoreCreate() {
    return {
      'email': email.trim().toLowerCase(),
      'name': name.trim(),
      'dob': dob,
      'gender': gender,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'bmi': bmi,
      'married': married,
      'currentMedications': currentMedications,
      'allergies': allergies,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory UserProfile.fromFirestore(String email, Map<String, dynamic> data) {
    return UserProfile(
      email: email,
      name: (data['name'] as String?)?.trim() ?? '',
      dob: '${data['dob'] ?? ''}',
      gender: '${data['gender'] ?? ''}',
      heightCm: '${data['height_cm'] ?? ''}',
      weightKg: '${data['weight_kg'] ?? ''}',
      bmi: '${data['bmi'] ?? ''}',
      married: '${data['married'] ?? ''}',
      currentMedications: _stringList(data['currentMedications']),
      allergies: _stringList(data['allergies']),
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
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
}
