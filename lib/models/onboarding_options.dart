/// Stable keys + labels for onboarding multi-selects (map to findings / KB later).
class OnboardingOption {
  const OnboardingOption(this.key, this.label);
  final String key;
  final String label;
}

class OnboardingOptions {
  OnboardingOptions._();

  static const sexOptions = [
    OnboardingOption('male', 'Male'),
    OnboardingOption('female', 'Female'),
    OnboardingOption('prefer_not_to_say', 'Prefer not to say'),
  ];

  static const genderIdentityOptions = [
    OnboardingOption('man', 'Man'),
    OnboardingOption('woman', 'Woman'),
    OnboardingOption('non_binary', 'Non-binary'),
    OnboardingOption('prefer_not_to_say', 'Prefer not to say'),
  ];

  static const bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
    "Don't know",
  ];

  static const ageRanges = [
    OnboardingOption('under_18', 'Under 18'),
    OnboardingOption('18_24', '18–24'),
    OnboardingOption('25_29', '25–29'),
    OnboardingOption('30_34', '30–34'),
    OnboardingOption('35_39', '35–39'),
    OnboardingOption('40_44', '40–44'),
    OnboardingOption('45_49', '45–49'),
    OnboardingOption('50_54', '50–54'),
    OnboardingOption('55_59', '55–59'),
    OnboardingOption('60_64', '60–64'),
    OnboardingOption('65_plus', '65+'),
  ];

  static const heightRangesCm = [
    OnboardingOption('under_150', 'Under 150 cm'),
    OnboardingOption('150_160', '150–160 cm'),
    OnboardingOption('160_170', '160–170 cm'),
    OnboardingOption('170_180', '170–180 cm'),
    OnboardingOption('180_plus', '180+ cm'),
  ];

  /// Midpoints used when height is approximate.
  static const heightRangeMidpointsCm = {
    'under_150': 145.0,
    '150_160': 155.0,
    '160_170': 165.0,
    '170_180': 175.0,
    '180_plus': 185.0,
  };

  static const weightRangesKg = [
    OnboardingOption('under_50', 'Under 50 kg'),
    OnboardingOption('50_60', '50–60 kg'),
    OnboardingOption('60_70', '60–70 kg'),
    OnboardingOption('70_80', '70–80 kg'),
    OnboardingOption('80_90', '80–90 kg'),
    OnboardingOption('90_plus', '90+ kg'),
  ];

  static const weightRangeMidpointsKg = {
    'under_50': 45.0,
    '50_60': 55.0,
    '60_70': 65.0,
    '70_80': 75.0,
    '80_90': 85.0,
    '90_plus': 95.0,
  };

  static const longTermConditions = [
    OnboardingOption('diabetes_type1', 'Diabetes (Type 1)'),
    OnboardingOption('diabetes_type2', 'Diabetes (Type 2)'),
    OnboardingOption('hypertension', 'High blood pressure'),
    OnboardingOption('kidney_disease', 'Kidney disease'),
    OnboardingOption('dialysis', 'On dialysis'),
    OnboardingOption('heart_disease', 'Heart disease'),
    OnboardingOption('thyroid_disorder', 'Thyroid disorder (hyper/hypo)'),
    OnboardingOption('asthma', 'Asthma'),
    OnboardingOption('liver_disease', 'Liver disease'),
    OnboardingOption('arthritis', 'Arthritis'),
    OnboardingOption('epilepsy', 'Epilepsy'),
    OnboardingOption('autoimmune', 'Autoimmune condition'),
    OnboardingOption('none', 'None of these'),
  ];

  static const eyeConditions = [
    OnboardingOption('glaucoma', 'Glaucoma'),
    OnboardingOption('cataract', 'Cataract'),
    OnboardingOption('diabetic_retinopathy', 'Diabetic retinopathy'),
    OnboardingOption('vision_correction', 'Wears glasses/contacts'),
    OnboardingOption('color_blindness', 'Color blindness'),
    OnboardingOption('none', 'None'),
  ];

  static const skinConditions = [
    OnboardingOption('eczema', 'Eczema'),
    OnboardingOption('psoriasis', 'Psoriasis'),
    OnboardingOption('chronic_skin_allergy', 'Chronic skin allergy'),
    OnboardingOption('none', 'None'),
  ];

  static const foodIntolerances = [
    OnboardingOption('lactose', 'Lactose intolerance'),
    OnboardingOption('gluten', 'Gluten intolerance'),
    OnboardingOption('nut_allergy', 'Nut allergy'),
    OnboardingOption('shellfish_allergy', 'Shellfish allergy'),
    OnboardingOption('none', 'None'),
  ];

  static const commonDrugAllergies = [
    OnboardingOption('penicillin', 'Penicillin'),
    OnboardingOption('sulfa', 'Sulfa drugs'),
    OnboardingOption('aspirin_nsaids', 'Aspirin / NSAIDs'),
    OnboardingOption('iodine', 'Iodine'),
  ];

  static const smokingStatus = [
    OnboardingOption('never', 'Never'),
    OnboardingOption('former', 'Former smoker'),
    OnboardingOption('current', 'Current smoker'),
  ];

  static const alcoholUse = [
    OnboardingOption('never', 'Never'),
    OnboardingOption('occasionally', 'Occasionally'),
    OnboardingOption('regularly', 'Regularly'),
  ];

  static const dietPreference = [
    OnboardingOption('vegetarian', 'Vegetarian'),
    OnboardingOption('non_vegetarian', 'Non-vegetarian'),
    OnboardingOption('vegan', 'Vegan'),
    OnboardingOption('eggetarian', 'Eggetarian'),
  ];

  static const activityLevel = [
    OnboardingOption('sedentary', 'Sedentary'),
    OnboardingOption('lightly_active', 'Lightly active'),
    OnboardingOption('moderately_active', 'Moderately active'),
    OnboardingOption('very_active', 'Very active'),
  ];

  static const pregnancyStatus = [
    OnboardingOption('yes', 'Yes'),
    OnboardingOption('no', 'No'),
    OnboardingOption('prefer_not_to_say', 'Prefer not to say'),
  ];
}
