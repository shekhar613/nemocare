import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/onboarding_options.dart';
import '../../models/user_profile.dart';
import '../../services/user_profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../home_screen.dart';

/// Professional multi-step health profile onboarding.
/// Saves to Firestore and powers chat / insights patient context.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.isEditing = false});

  /// When true, prefill from Firestore and pop back after save (sidebar update).
  final bool isEditing;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _profiles = UserProfileService();
  final _pageController = PageController();

  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _conditionsOther = TextEditingController();
  final _eyeOther = TextEditingController();
  final _skinOther = TextEditingController();
  final _foodOther = TextEditingController();
  final _drugAllergyOther = TextEditingController();
  final _otherAllergyController = TextEditingController();

  int _page = 0;
  bool _saving = false;
  bool _loadingProfile = false;

  DateTime? _dob;
  bool _useAgeRange = false;
  String? _ageRangeKey;
  String? _sex;
  String? _genderIdentity;
  bool _heightImperial = false;
  bool _weightImperial = false;
  bool _heightNotSure = false;
  bool _weightNotSure = false;
  String? _heightRangeKey;
  String? _weightRangeKey;
  String? _bloodGroup;

  final Set<String> _conditions = {};
  final Set<String> _eye = {};
  final Set<String> _skin = {};
  final Set<String> _food = {};
  final Set<String> _drugAllergies = {};
  final List<_MedEntry> _meds = [_MedEntry()];
  final List<String> _otherAllergies = [];
  String? _smoking;
  String? _alcohol;
  String? _diet;
  String? _activity;
  String? _pregnancy;

  static const _steps = [
    (Icons.person_outline_rounded, 'About you'),
    (Icons.favorite_outline_rounded, 'Conditions'),
    (Icons.visibility_outlined, 'Systems'),
    (Icons.shield_outlined, 'Safety'),
    (Icons.directions_walk_rounded, 'Lifestyle'),
    (Icons.pregnant_woman_rounded, 'Optional'),
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text =
        FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '';
    if (widget.isEditing) {
      _loadingProfile = true;
      _loadExistingProfile();
    }
  }

  Future<void> _loadExistingProfile() async {
    try {
      final profile = await _profiles.fetchCurrentProfile();
      if (!mounted || profile == null) return;

      void applyKeyedList(
        List<String> stored,
        Set<String> target,
        Set<String> knownKeys,
        TextEditingController other, {
        required String noneKey,
      }) {
        final others = <String>[];
        for (final raw in stored) {
          final v = raw.trim();
          if (v.isEmpty) continue;
          if (v.startsWith('other:')) {
            others.add(v.substring(6).trim());
            continue;
          }
          if (knownKeys.contains(v)) {
            target.add(v);
          } else {
            others.add(v);
          }
        }
        if (target.isEmpty && others.isEmpty) {
          target.add(noneKey);
        }
        if (others.isNotEmpty) {
          other.text = others.join(', ');
        }
      }

      final conditionKeys =
          OnboardingOptions.longTermConditions.map((o) => o.key).toSet();
      final eyeKeys = OnboardingOptions.eyeConditions.map((o) => o.key).toSet();
      final skinKeys =
          OnboardingOptions.skinConditions.map((o) => o.key).toSet();
      final foodKeys =
          OnboardingOptions.foodIntolerances.map((o) => o.key).toSet();
      final drugKeys =
          OnboardingOptions.commonDrugAllergies.map((o) => o.key).toSet();

      applyKeyedList(
        profile.knownConditions,
        _conditions,
        conditionKeys,
        _conditionsOther,
        noneKey: 'none',
      );
      if (profile.onDialysis) _conditions.add('dialysis');

      applyKeyedList(
        profile.eyeConditions,
        _eye,
        eyeKeys,
        _eyeOther,
        noneKey: 'none',
      );
      applyKeyedList(
        profile.skinConditions,
        _skin,
        skinKeys,
        _skinOther,
        noneKey: 'none',
      );
      applyKeyedList(
        profile.foodIntolerances,
        _food,
        foodKeys,
        _foodOther,
        noneKey: 'none',
      );

      final customDrugs = <String>[];
      for (final d in profile.drugAllergies) {
        final v = d.trim();
        if (v.isEmpty) continue;
        if (drugKeys.contains(v)) {
          _drugAllergies.add(v);
        } else {
          customDrugs.add(v);
        }
      }
      if (customDrugs.isNotEmpty) {
        _drugAllergyOther.text = customDrugs.join(', ');
      }

      _otherAllergies
        ..clear()
        ..addAll(profile.otherAllergies);

      for (final m in _meds) {
        m.dispose();
      }
      _meds.clear();
      if (profile.currentMedications.isEmpty) {
        _meds.add(_MedEntry());
      } else {
        for (final med in profile.currentMedications) {
          final entry = _MedEntry();
          entry.nameController.text = med['name'] ?? '';
          entry.dosageController.text = med['dosage'] ?? '';
          _meds.add(entry);
        }
      }

      _nameController.text = profile.name.isNotEmpty
          ? profile.name
          : (FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '');

      _useAgeRange = profile.ageApproximate ||
          (profile.dob.trim().isEmpty && profile.ageRange.isNotEmpty);
      if (_useAgeRange) {
        _ageRangeKey =
            profile.ageRange.isNotEmpty ? profile.ageRange : null;
        _dob = null;
      } else if (profile.dob.trim().isNotEmpty) {
        _dob = DateTime.tryParse(profile.dob.trim());
      }

      _sex = profile.sex.isNotEmpty ? profile.sex : null;
      _genderIdentity =
          profile.genderIdentity.isNotEmpty ? profile.genderIdentity : null;
      _bloodGroup =
          profile.bloodGroup.isNotEmpty ? profile.bloodGroup : null;

      _heightNotSure = profile.heightApproximate;
      if (_heightNotSure) {
        _heightRangeKey = _rangeKeyForValue(
          double.tryParse(profile.heightCm),
          OnboardingOptions.heightRangeMidpointsCm,
        );
      } else if (profile.heightCm.isNotEmpty) {
        _heightController.text = profile.heightCm;
      }

      _weightNotSure = profile.weightApproximate;
      if (_weightNotSure) {
        _weightRangeKey = _rangeKeyForValue(
          double.tryParse(profile.weightKg),
          OnboardingOptions.weightRangeMidpointsKg,
        );
      } else if (profile.weightKg.isNotEmpty) {
        _weightController.text = profile.weightKg;
      }

      _smoking =
          profile.smokingStatus.isNotEmpty ? profile.smokingStatus : null;
      _alcohol = profile.alcoholUse.isNotEmpty ? profile.alcoholUse : null;
      _diet =
          profile.dietPreference.isNotEmpty ? profile.dietPreference : null;
      _activity =
          profile.activityLevel.isNotEmpty ? profile.activityLevel : null;
      _pregnancy = profile.pregnancyStatus.isNotEmpty
          ? profile.pregnancyStatus
          : null;

      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  String? _rangeKeyForValue(double? value, Map<String, double> midpoints) {
    if (value == null || midpoints.isEmpty) return null;
    String? best;
    var bestDelta = double.infinity;
    for (final entry in midpoints.entries) {
      final d = (entry.value - value).abs();
      if (d < bestDelta) {
        bestDelta = d;
        best = entry.key;
      }
    }
    return best;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _conditionsOther.dispose();
    _eyeOther.dispose();
    _skinOther.dispose();
    _foodOther.dispose();
    _drugAllergyOther.dispose();
    _otherAllergyController.dispose();
    for (final m in _meds) {
      m.dispose();
    }
    super.dispose();
  }

  bool get _showWomensHealth => _sex == 'female';
  int get _pageCount => _showWomensHealth ? 6 : 5;

  List<String> get _headlines => [
        'Tell us about you',
        'Long-term conditions',
        'Eyes, skin & food',
        'Allergies & medications',
        'Lifestyle basics',
        if (_showWomensHealth) "Women's health",
      ];

  List<String> get _subtitles => [
        'Used for personalization and accurate lab reference ranges.',
        'Helps insights and chat stay relevant to your history.',
        'Maps to the kinds of reports and risks we watch for.',
        'Critical for safe medication-related answers in chat.',
        'Shapes gentle lifestyle suggestions in Insights.',
        if (_showWomensHealth) 'Optional — skip with Prefer not to say.',
      ];

  Future<void> _next() async {
    if (!_validateCurrent()) return;
    if (_page < _pageCount - 1) {
      setState(() => _page += 1);
      await _pageController.animateToPage(
        _page,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _finish();
  }

  Future<void> _back() async {
    if (_page == 0) return;
    setState(() => _page -= 1);
    await _pageController.animateToPage(
      _page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  bool _validateCurrent() {
    String? error;
    switch (_page) {
      case 0:
        if (_nameController.text.trim().isEmpty) {
          error = 'Please enter your full name.';
        } else if (!_useAgeRange && _dob == null) {
          error = 'Pick your date of birth, or use approximate age.';
        } else if (_useAgeRange &&
            (_ageRangeKey == null || _ageRangeKey!.isEmpty)) {
          error = 'Select an age range.';
        } else if (_sex == null || _sex!.isEmpty) {
          error = 'Select biological sex (needed for lab reference ranges).';
        } else if (!_heightNotSure &&
            double.tryParse(_normalizedHeightCm() ?? '') == null) {
          error = 'Enter height, or choose “Not sure”.';
        } else if (_heightNotSure && _heightRangeKey == null) {
          error = 'Select a height range.';
        } else if (!_weightNotSure &&
            double.tryParse(_normalizedWeightKg() ?? '') == null) {
          error = 'Enter weight, or choose “Not sure”.';
        } else if (_weightNotSure && _weightRangeKey == null) {
          error = 'Select a weight range.';
        }
      case 1:
        if (_conditions.isEmpty) {
          error = 'Select at least one option (or “None of these”).';
        }
      case 2:
        if (_eye.isEmpty || _skin.isEmpty || _food.isEmpty) {
          error = 'Answer all three questions (choose None if not applicable).';
        }
      case 4:
        if (_smoking == null ||
            _alcohol == null ||
            _diet == null ||
            _activity == null) {
          error = 'Please complete lifestyle selections.';
        }
    }
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.coral,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(error, style: GoogleFonts.outfit(color: Colors.white)),
        ),
      );
      return false;
    }
    return true;
  }

  String? _normalizedHeightCm() {
    if (_heightNotSure) {
      return OnboardingOptions.heightRangeMidpointsCm[_heightRangeKey]
          ?.toStringAsFixed(0);
    }
    final raw = double.tryParse(_heightController.text.trim());
    if (raw == null) return null;
    if (_heightImperial) return (raw * 2.54).toStringAsFixed(1);
    return raw.toStringAsFixed(1);
  }

  String? _normalizedWeightKg() {
    if (_weightNotSure) {
      return OnboardingOptions.weightRangeMidpointsKg[_weightRangeKey]
          ?.toStringAsFixed(1);
    }
    final raw = double.tryParse(_weightController.text.trim());
    if (raw == null) return null;
    if (_weightImperial) return (raw * 0.453592).toStringAsFixed(1);
    return raw.toStringAsFixed(1);
  }

  Future<void> _finish() async {
    if (!_validateCurrent()) return;
    setState(() => _saving = true);
    try {
      final heightCm = _normalizedHeightCm() ?? '';
      final weightKg = _normalizedWeightKg() ?? '';
      final bmi = UserProfile.computeBmi(heightCm, weightKg) ?? '';

      final conditions = _conditions.where((k) => k != 'none').toList();
      if (_conditionsOther.text.trim().isNotEmpty) {
        conditions.add('other:${_conditionsOther.text.trim()}');
      }

      List<String> cleanMulti(Set<String> set, TextEditingController other) {
        final list = set.where((k) => k != 'none').toList();
        if (other.text.trim().isNotEmpty) {
          list.add('other:${other.text.trim()}');
        }
        return list;
      }

      final drugAllergies = [
        ..._drugAllergies,
        if (_drugAllergyOther.text.trim().isNotEmpty)
          _drugAllergyOther.text.trim(),
      ];

      final meds = _meds
          .map(
            (m) => {
              'name': m.nameController.text.trim(),
              'dosage': m.dosageController.text.trim(),
            },
          )
          .where((m) => (m['name'] ?? '').isNotEmpty)
          .toList();

      final email =
          FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase() ?? '';

      final profile = UserProfile(
        email: email,
        name: _nameController.text.trim(),
        dob: _useAgeRange
            ? ''
            : (_dob != null
                ? '${_dob!.year.toString().padLeft(4, '0')}-'
                    '${_dob!.month.toString().padLeft(2, '0')}-'
                    '${_dob!.day.toString().padLeft(2, '0')}'
                : ''),
        ageRange: _useAgeRange ? (_ageRangeKey ?? '') : '',
        ageApproximate: _useAgeRange,
        sex: _sex ?? '',
        genderIdentity: _genderIdentity ?? '',
        heightCm: heightCm,
        weightKg: weightKg,
        bmi: bmi,
        heightApproximate: _heightNotSure,
        weightApproximate: _weightNotSure,
        bloodGroup: _bloodGroup ?? '',
        knownConditions: conditions,
        onDialysis: _conditions.contains('dialysis'),
        eyeConditions: cleanMulti(_eye, _eyeOther),
        skinConditions: cleanMulti(_skin, _skinOther),
        foodIntolerances: cleanMulti(_food, _foodOther),
        drugAllergies: drugAllergies,
        otherAllergies: List<String>.from(_otherAllergies),
        currentMedications: meds,
        smokingStatus: _smoking ?? '',
        alcoholUse: _alcohol ?? '',
        dietPreference: _diet ?? '',
        activityLevel: _activity ?? '',
        pregnancyStatus: _showWomensHealth ? (_pregnancy ?? '') : '',
        onboardingCompleted: true,
      );

      await _profiles.saveOnboarding(profile);
      if (!mounted) return;
      if (widget.isEditing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.deepTeal,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Text(
              'Health profile updated',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        );
        Navigator.of(context).pop(true);
        return;
      }
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, animation, _) => const HomeScreen(),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.coral,
          content: Text(
            e.toString(),
            style: GoogleFonts.outfit(color: Colors.white),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleExclusive(
    Set<String> target,
    String key, {
    required String noneKey,
  }) {
    setState(() {
      if (key == noneKey) {
        target
          ..clear()
          ..add(noneKey);
        return;
      }
      target.remove(noneKey);
      if (target.contains(key)) {
        target.remove(key);
      } else {
        target.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final headlines = _headlines;
    final subtitles = _subtitles;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEFF8F7),
              AppColors.foam,
              Color(0xFFF7FBFA),
            ],
          ),
        ),
        child: SafeArea(
          child: _loadingProfile
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.teal),
                )
              : Column(
            children: [
              _Header(
                page: _page,
                pageCount: _pageCount,
                steps: _steps.take(_pageCount).toList(),
                isEditing: widget.isEditing,
                onClose: widget.isEditing
                    ? () => Navigator.of(context).maybePop()
                    : null,
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _SectionScaffold(
                      headline: headlines[0],
                      subtitle: subtitles[0],
                      child: _buildIdentity(),
                    ),
                    _SectionScaffold(
                      headline: headlines[1],
                      subtitle: subtitles[1],
                      child: _buildConditions(),
                    ),
                    _SectionScaffold(
                      headline: headlines[2],
                      subtitle: subtitles[2],
                      child: _buildOrgans(),
                    ),
                    _SectionScaffold(
                      headline: headlines[3],
                      subtitle: subtitles[3],
                      child: _buildAllergiesMeds(),
                    ),
                    _SectionScaffold(
                      headline: headlines[4],
                      subtitle: subtitles[4],
                      child: _buildLifestyle(),
                    ),
                    if (_showWomensHealth)
                      _SectionScaffold(
                        headline: headlines[5],
                        subtitle: subtitles[5],
                        child: _buildWomensHealth(),
                      ),
                  ],
                ),
              ),
              _Footer(
                page: _page,
                saving: _saving,
                isLast: _page == _pageCount - 1,
                isEditing: widget.isEditing,
                onBack: _back,
                onNext: _next,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Section builders ─────────────────────────────────────────────

  Widget _buildIdentity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Full name'),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: _input('Your full name'),
        ),
        const SizedBox(height: 20),
        _FieldLabel('Date of birth'),
        _SoftSwitch(
          value: _useAgeRange,
          label: 'I don’t know my exact DOB — use age range',
          onChanged: (v) => setState(() {
            _useAgeRange = v;
            if (v) _dob = null;
          }),
        ),
        const SizedBox(height: 8),
        if (!_useAgeRange)
          _DateTile(
            label: _dob == null
                ? 'Select date of birth'
                : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(now.year - 25),
                firstDate: DateTime(1920),
                lastDate: now,
              );
              if (picked != null) setState(() => _dob = picked);
            },
          )
        else
          _OptionChips(
            options: OnboardingOptions.ageRanges,
            selected: _ageRangeKey,
            onSelect: (k) => setState(() => _ageRangeKey = k),
          ),
        const SizedBox(height: 20),
        _FieldLabel('Sex (biological)'),
        Text(
          'Required for lab reference ranges such as hemoglobin and creatinine.',
          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        _OptionChips(
          options: OnboardingOptions.sexOptions,
          selected: _sex,
          onSelect: (k) => setState(() {
            _sex = k;
            if (k != 'female') _pregnancy = null;
          }),
        ),
        const SizedBox(height: 20),
        _FieldLabel('Gender identity (optional)'),
        _OptionChips(
          options: OnboardingOptions.genderIdentityOptions,
          selected: _genderIdentity,
          onSelect: (k) => setState(() => _genderIdentity = k),
        ),
        const SizedBox(height: 20),
        _FieldLabel('Height'),
        _UnitRow(
          unit: _heightImperial ? 'inches (total)' : 'cm',
          onToggle: () => setState(() => _heightImperial = !_heightImperial),
        ),
        _SoftSwitch(
          value: _heightNotSure,
          label: 'Not sure — pick a range',
          onChanged: (v) => setState(() => _heightNotSure = v),
        ),
        const SizedBox(height: 8),
        if (!_heightNotSure)
          TextField(
            controller: _heightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _input(_heightImperial ? 'e.g. 67' : 'e.g. 170'),
          )
        else
          _OptionChips(
            options: OnboardingOptions.heightRangesCm,
            selected: _heightRangeKey,
            onSelect: (k) => setState(() => _heightRangeKey = k),
          ),
        const SizedBox(height: 20),
        _FieldLabel('Weight'),
        _UnitRow(
          unit: _weightImperial ? 'lb' : 'kg',
          onToggle: () => setState(() => _weightImperial = !_weightImperial),
        ),
        _SoftSwitch(
          value: _weightNotSure,
          label: 'Not sure — pick a range',
          onChanged: (v) => setState(() => _weightNotSure = v),
        ),
        const SizedBox(height: 8),
        if (!_weightNotSure)
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _input(_weightImperial ? 'e.g. 154' : 'e.g. 70'),
          )
        else
          _OptionChips(
            options: OnboardingOptions.weightRangesKg,
            selected: _weightRangeKey,
            onSelect: (k) => setState(() => _weightRangeKey = k),
          ),
        const SizedBox(height: 20),
        _FieldLabel('Blood group'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: OnboardingOptions.bloodGroups.map((g) {
            final selected = _bloodGroup == g;
            return _PillChip(
              label: g,
              selected: selected,
              onTap: () => setState(() => _bloodGroup = g),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildConditions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Do you have any long-term health conditions?'),
        Text(
          'Select all that apply. Used by insights and chat safety.',
          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        ...OnboardingOptions.longTermConditions.map(
          (o) => _CheckTile(
            label: o.label,
            selected: _conditions.contains(o.key),
            onTap: () =>
                _toggleExclusive(_conditions, o.key, noneKey: 'none'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _conditionsOther,
          decoration: _input('Other (optional)'),
        ),
      ],
    );
  }

  Widget _buildOrgans() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Any eye-related conditions?'),
        ...OnboardingOptions.eyeConditions.map(
          (o) => _CheckTile(
            label: o.label,
            selected: _eye.contains(o.key),
            onTap: () => _toggleExclusive(_eye, o.key, noneKey: 'none'),
          ),
        ),
        TextField(controller: _eyeOther, decoration: _input('Other')),
        const SizedBox(height: 22),
        _FieldLabel('Any skin-related conditions?'),
        ...OnboardingOptions.skinConditions.map(
          (o) => _CheckTile(
            label: o.label,
            selected: _skin.contains(o.key),
            onTap: () => _toggleExclusive(_skin, o.key, noneKey: 'none'),
          ),
        ),
        TextField(controller: _skinOther, decoration: _input('Other')),
        const SizedBox(height: 22),
        _FieldLabel('Food intolerances / allergies?'),
        ...OnboardingOptions.foodIntolerances.map(
          (o) => _CheckTile(
            label: o.label,
            selected: _food.contains(o.key),
            onTap: () => _toggleExclusive(_food, o.key, noneKey: 'none'),
          ),
        ),
        TextField(controller: _foodOther, decoration: _input('Other')),
      ],
    );
  }

  Widget _buildAllergiesMeds() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Drug / medication allergies'),
        Text(
          'Safety-critical — chat will never suggest conflicting medicines.',
          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        ...OnboardingOptions.commonDrugAllergies.map(
          (o) => _CheckTile(
            label: o.label,
            selected: _drugAllergies.contains(o.key),
            onTap: () => setState(() {
              if (_drugAllergies.contains(o.key)) {
                _drugAllergies.remove(o.key);
              } else {
                _drugAllergies.add(o.key);
              }
            }),
          ),
        ),
        TextField(
          controller: _drugAllergyOther,
          decoration: _input('Add another drug allergy'),
        ),
        const SizedBox(height: 22),
        _FieldLabel('Current medications'),
        ...List.generate(_meds.length, (i) {
          final m = _meds[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: m.nameController,
                    decoration: _input('Name'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: m.dosageController,
                    decoration: _input('Dose (optional)'),
                  ),
                ),
                if (_meds.length > 1)
                  IconButton(
                    onPressed: () => setState(() {
                      _meds.removeAt(i).dispose();
                    }),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.muted),
                  ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => setState(() => _meds.add(_MedEntry())),
          icon: const Icon(Icons.add_rounded, color: AppColors.teal, size: 20),
          label: Text(
            'Add medication',
            style: GoogleFonts.outfit(
              color: AppColors.teal,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 18),
        _FieldLabel('Other allergies (pollen, latex, …)'),
        ..._otherAllergies.map(
          (a) => _CheckTile(
            label: a,
            selected: true,
            onTap: () => setState(() => _otherAllergies.remove(a)),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _otherAllergyController,
                decoration: _input('Add allergy'),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppColors.mist,
              borderRadius: BorderRadius.circular(14),
              child: IconButton(
                onPressed: () {
                  final t = _otherAllergyController.text.trim();
                  if (t.isEmpty) return;
                  setState(() {
                    _otherAllergies.add(t);
                    _otherAllergyController.clear();
                  });
                },
                icon: const Icon(Icons.add_rounded, color: AppColors.deepTeal),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLifestyle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Do you smoke?'),
        _OptionChips(
          options: OnboardingOptions.smokingStatus,
          selected: _smoking,
          onSelect: (k) => setState(() => _smoking = k),
        ),
        const SizedBox(height: 18),
        _FieldLabel('Do you consume alcohol?'),
        _OptionChips(
          options: OnboardingOptions.alcoholUse,
          selected: _alcohol,
          onSelect: (k) => setState(() => _alcohol = k),
        ),
        const SizedBox(height: 18),
        _FieldLabel('Diet preference'),
        _OptionChips(
          options: OnboardingOptions.dietPreference,
          selected: _diet,
          onSelect: (k) => setState(() => _diet = k),
        ),
        const SizedBox(height: 18),
        _FieldLabel('Activity level'),
        _OptionChips(
          options: OnboardingOptions.activityLevel,
          selected: _activity,
          onSelect: (k) => setState(() => _activity = k),
        ),
      ],
    );
  }

  Widget _buildWomensHealth() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Are you currently pregnant or breastfeeding?'),
        Text(
          'This step is optional and only shown when sex is Female.',
          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        _OptionChips(
          options: OnboardingOptions.pregnancyStatus,
          selected: _pregnancy,
          onSelect: (k) => setState(() => _pregnancy = k),
        ),
      ],
    );
  }

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(color: AppColors.muted.withValues(alpha: 0.7)),
        filled: true,
        fillColor: AppColors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
        ),
      );
}

// ─── Shared UI pieces ─────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.page,
    required this.pageCount,
    required this.steps,
    this.isEditing = false,
    this.onClose,
  });

  final int page;
  final int pageCount;
  final List<(IconData, String)> steps;
  final bool isEditing;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        children: [
          Row(
            children: [
              const AppLogoMark(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nemo Care',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      isEditing ? 'Update health profile' : 'Health profile setup',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.mist,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${page + 1} / $pageCount',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepTeal,
                  ),
                ),
              ),
              if (onClose != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.muted,
                  tooltip: 'Close',
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (page + 1) / pageCount,
              minHeight: 7,
              backgroundColor: AppColors.border,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: steps.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final active = i == page;
                final done = i < page;
                final (icon, label) = steps[i];
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.deepTeal
                        : done
                            ? AppColors.mist
                            : AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: active
                          ? AppColors.deepTeal
                          : done
                              ? AppColors.softAqua.withValues(alpha: 0.5)
                              : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        done && !active ? Icons.check_rounded : icon,
                        size: 16,
                        color: active
                            ? Colors.white
                            : done
                                ? AppColors.deepTeal
                                : AppColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? Colors.white
                              : done
                                  ? AppColors.deepTeal
                                  : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionScaffold extends StatelessWidget {
  const _SectionScaffold({
    required this.headline,
    required this.subtitle,
    required this.child,
  });

  final String headline;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      children: [
        Text(
          headline,
          style: GoogleFonts.sora(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            letterSpacing: -0.6,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.outfit(
            fontSize: 14.5,
            height: 1.4,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepTeal.withValues(alpha: 0.05),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.page,
    required this.saving,
    required this.isLast,
    required this.onBack,
    required this.onNext,
    this.isEditing = false,
  });

  final int page;
  final bool saving;
  final bool isLast;
  final bool isEditing;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.foam.withValues(alpha: 0.92),
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (page > 0)
            TextButton(
              onPressed: saving ? null : onBack,
              child: Text(
                'Back',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepTeal,
                ),
              ),
            )
          else
            const SizedBox(width: 64),
          const Spacer(),
          FilledButton(
            onPressed: saving ? null : onNext,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.deepTeal,
              disabledBackgroundColor: AppColors.deepTeal.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    isLast
                        ? (isEditing ? 'Save changes' : 'Save & continue')
                        : 'Continue',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

class _SoftSwitch extends StatelessWidget {
  const _SoftSwitch({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      activeTrackColor: AppColors.teal,
      title: Text(
        label,
        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.ink),
      ),
      onChanged: onChanged,
    );
  }
}

class _UnitRow extends StatelessWidget {
  const _UnitRow({required this.unit, required this.onToggle});
  final String unit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          unit,
          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.muted),
        ),
        const Spacer(),
        TextButton(
          onPressed: onToggle,
          child: Text(
            'Switch unit',
            style: GoogleFonts.outfit(
              color: AppColors.teal,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(color: AppColors.ink, fontSize: 15),
                ),
              ),
              const Icon(Icons.calendar_month_rounded, color: AppColors.teal),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionChips extends StatelessWidget {
  const _OptionChips({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<OnboardingOption> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (o) => _PillChip(
              label: o.label,
              selected: selected == o.key,
              onTap: () => onSelect(o.key),
            ),
          )
          .toList(),
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.mist : AppColors.foam,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.teal : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppColors.deepTeal : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.mist : AppColors.foam,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.teal : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 22,
                  color: selected ? AppColors.deepTeal : AppColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MedEntry {
  _MedEntry()
      : nameController = TextEditingController(),
        dosageController = TextEditingController();

  final TextEditingController nameController;
  final TextEditingController dosageController;

  void dispose() {
    nameController.dispose();
    dosageController.dispose();
  }
}
