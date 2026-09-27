import 'vital_row.dart';

/// Common adult lab reference ranges used for Vitals comparison.
///
/// These are typical textbook / common-lab intervals for orientation only —
/// not personalized medical advice. Prefer report-printed ranges when present
/// for status flags if they differ, but the UI Reference column shows these
/// standards so users can compare consistently.
class StandardLabReferences {
  StandardLabReferences._();

  static const Map<String, ({String reference, String unit, List<String> aliases})>
      _catalog = {
    'hemoglobin': (
      reference: '13.0 - 17.0 (M) / 12.0 - 15.0 (F)',
      unit: 'g/dL',
      aliases: ['hb', 'hgb', 'haemoglobin'],
    ),
    'rbc': (
      reference: '4.5 - 5.5 (M) / 3.8 - 4.8 (F)',
      unit: 'million/µL',
      aliases: ['red blood cell', 'red blood cells', 'rbc count'],
    ),
    'wbc': (
      reference: '4000 - 11000',
      unit: '/µL',
      aliases: [
        'total wbc',
        'wbc count',
        'tlc',
        'total leucocyte count',
        'leukocytes',
        'leucocytes',
      ],
    ),
    'platelets': (
      reference: '150000 - 450000',
      unit: '/µL',
      aliases: ['platelet', 'plt', 'platelet count'],
    ),
    'pcv': (
      reference: '40 - 50 (M) / 36 - 46 (F)',
      unit: '%',
      aliases: ['hematocrit', 'haematocrit', 'hct', 'packed cell volume'],
    ),
    'mcv': (
      reference: '83 - 101',
      unit: 'fL',
      aliases: ['mean corpuscular volume'],
    ),
    'mch': (
      reference: '27 - 32',
      unit: 'pg',
      aliases: ['mean corpuscular hemoglobin', 'mean corpuscular haemoglobin'],
    ),
    'mchc': (
      reference: '31.5 - 34.5',
      unit: 'g/dL',
      aliases: [
        'mean corpuscular hemoglobin concentration',
        'mean corpuscular haemoglobin concentration',
      ],
    ),
    'rdw': (
      reference: '11.6 - 14.0',
      unit: '%',
      aliases: ['rdw-cv', 'red cell distribution width'],
    ),
    'neutrophils': (
      reference: '40 - 80',
      unit: '%',
      aliases: ['neutrophil', 'abs neutrophils'],
    ),
    'lymphocytes': (
      reference: '20 - 40',
      unit: '%',
      aliases: ['lymphocyte', 'abs lymphocytes'],
    ),
    'monocytes': (
      reference: '2 - 10',
      unit: '%',
      aliases: ['monocyte'],
    ),
    'eosinophils': (
      reference: '1 - 6',
      unit: '%',
      aliases: ['eosinophil'],
    ),
    'basophils': (
      reference: '0 - 2',
      unit: '%',
      aliases: ['basophil'],
    ),
    'esr': (
      reference: '0 - 15 (M) / 0 - 20 (F)',
      unit: 'mm/hr',
      aliases: ['erythrocyte sedimentation rate'],
    ),
    'fasting blood sugar': (
      reference: '70 - 99',
      unit: 'mg/dL',
      aliases: ['fbs', 'fasting glucose', 'fasting blood glucose', 'glucose fasting'],
    ),
    'random blood sugar': (
      reference: '< 140',
      unit: 'mg/dL',
      aliases: ['rbs', 'random glucose', 'blood sugar'],
    ),
    'ppbs': (
      reference: '< 140',
      unit: 'mg/dL',
      aliases: ['postprandial blood sugar', 'post prandial glucose', 'pp blood sugar'],
    ),
    'hba1c': (
      reference: '< 5.7',
      unit: '%',
      aliases: ['glycated hemoglobin', 'a1c', 'hb a1c'],
    ),
    'total cholesterol': (
      reference: '< 200',
      unit: 'mg/dL',
      aliases: ['cholesterol', 'cholesterol total'],
    ),
    'hdl': (
      reference: '> 40 (M) / > 50 (F)',
      unit: 'mg/dL',
      aliases: ['hdl cholesterol', 'hdl-c'],
    ),
    'ldl': (
      reference: '< 100',
      unit: 'mg/dL',
      aliases: ['ldl cholesterol', 'ldl-c'],
    ),
    'triglycerides': (
      reference: '< 150',
      unit: 'mg/dL',
      aliases: ['tg', 'triglyceride'],
    ),
    'vldl': (
      reference: '5 - 40',
      unit: 'mg/dL',
      aliases: ['vldl cholesterol'],
    ),
    'sgot': (
      reference: '8 - 40',
      unit: 'U/L',
      aliases: ['ast', 'aspartate aminotransferase', 'sgot (ast)'],
    ),
    'sgpt': (
      reference: '7 - 56',
      unit: 'U/L',
      aliases: ['alt', 'alanine aminotransferase', 'sgpt (alt)'],
    ),
    'alkaline phosphatase': (
      reference: '44 - 147',
      unit: 'U/L',
      aliases: ['alp', 'alk phosphatase'],
    ),
    'total bilirubin': (
      reference: '0.1 - 1.2',
      unit: 'mg/dL',
      aliases: ['bilirubin', 'bilirubin total'],
    ),
    'direct bilirubin': (
      reference: '0.0 - 0.3',
      unit: 'mg/dL',
      aliases: ['bilirubin direct', 'conjugated bilirubin'],
    ),
    'indirect bilirubin': (
      reference: '0.2 - 0.8',
      unit: 'mg/dL',
      aliases: ['bilirubin indirect', 'unconjugated bilirubin'],
    ),
    'total protein': (
      reference: '6.0 - 8.3',
      unit: 'g/dL',
      aliases: ['protein total', 'serum protein'],
    ),
    'albumin': (
      reference: '3.5 - 5.0',
      unit: 'g/dL',
      aliases: ['serum albumin'],
    ),
    'globulin': (
      reference: '2.0 - 3.5',
      unit: 'g/dL',
      aliases: ['serum globulin'],
    ),
    'urea': (
      reference: '15 - 40',
      unit: 'mg/dL',
      aliases: ['blood urea', 'serum urea', 'bun'],
    ),
    'creatinine': (
      reference: '0.7 - 1.3 (M) / 0.6 - 1.1 (F)',
      unit: 'mg/dL',
      aliases: ['serum creatinine', 'creat'],
    ),
    'uric acid': (
      reference: '3.5 - 7.2 (M) / 2.6 - 6.0 (F)',
      unit: 'mg/dL',
      aliases: ['serum uric acid'],
    ),
    'sodium': (
      reference: '136 - 145',
      unit: 'mEq/L',
      aliases: ['na', 'serum sodium'],
    ),
    'potassium': (
      reference: '3.5 - 5.1',
      unit: 'mEq/L',
      aliases: ['k', 'serum potassium'],
    ),
    'chloride': (
      reference: '98 - 107',
      unit: 'mEq/L',
      aliases: ['cl', 'serum chloride'],
    ),
    'calcium': (
      reference: '8.6 - 10.2',
      unit: 'mg/dL',
      aliases: ['serum calcium', 'ca'],
    ),
    'tsh': (
      reference: '0.4 - 4.0',
      unit: 'µIU/mL',
      aliases: ['thyroid stimulating hormone'],
    ),
    't3': (
      reference: '80 - 200',
      unit: 'ng/dL',
      aliases: ['triiodothyronine', 'free t3'],
    ),
    't4': (
      reference: '5.0 - 12.0',
      unit: 'µg/dL',
      aliases: ['thyroxine', 'free t4'],
    ),
    'vitamin d': (
      reference: '30 - 100',
      unit: 'ng/mL',
      aliases: ['vit d', '25-oh vitamin d', 'vitamin d3', '25 hydroxy vitamin d'],
    ),
    'vitamin b12': (
      reference: '200 - 900',
      unit: 'pg/mL',
      aliases: ['b12', 'cobalamin', 'vit b12'],
    ),
    'crp': (
      reference: '< 5',
      unit: 'mg/L',
      aliases: ['c-reactive protein', 'c reactive protein'],
    ),
    'spo2': (
      reference: '95 - 100',
      unit: '%',
      aliases: ['oxygen saturation', 'o2 sat'],
    ),
    'blood pressure': (
      reference: '< 120/80',
      unit: 'mmHg',
      aliases: ['bp', 'systolic', 'diastolic'],
    ),
    'heart rate': (
      reference: '60 - 100',
      unit: 'bpm',
      aliases: ['pulse', 'pulse rate', 'hr'],
    ),
    'body temperature': (
      reference: '97.0 - 99.0',
      unit: '°F',
      aliases: ['temperature', 'temp'],
    ),
    'bmi': (
      reference: '18.5 - 24.9',
      unit: 'kg/m²',
      aliases: ['body mass index'],
    ),
  };

  static final Set<String> _junkTokens = {
    'patient',
    'name',
    'age',
    'sex',
    'gender',
    'date',
    'doctor',
    'address',
    'phone',
    'mobile',
    'email',
    'sample',
    'barcode',
    'page',
    'report',
    'lab',
    'hospital',
    'clinic',
    'registered',
    'collected',
    'received',
    'printed',
    'referred',
    'ref by',
    'mrn',
    'uhid',
    'id',
    'signature',
    'technician',
    'pathologist',
    'notes',
    'comment',
    'method',
    'instrument',
    'nabl',
    'accreditation',
  };

  /// Returns standard reference + default unit when parameter is recognized.
  static ({String reference, String unit, String canonical})? lookup(
    String parameter,
  ) {
    final key = _normalize(parameter);
    if (key.isEmpty) return null;

    for (final entry in _catalog.entries) {
      final names = [entry.key, ...entry.value.aliases];
      for (final name in names) {
        final n = _normalize(name);
        if (n.isEmpty) continue;

        // Short aliases (Na, K, Hb) must match exactly to avoid junk hits.
        if (n.length <= 3) {
          if (key == n) {
            return (
              reference: entry.value.reference,
              unit: entry.value.unit,
              canonical: _titleCase(entry.key),
            );
          }
          continue;
        }

        if (key == n || key.contains(n) || (n.contains(key) && key.length >= 4)) {
          return (
            reference: entry.value.reference,
            unit: entry.value.unit,
            canonical: _titleCase(entry.key),
          );
        }
      }
    }
    return null;
  }

  static bool isJunkParameter(String parameter) {
    final key = _normalize(parameter);
    if (key.isEmpty || key.length < 2) return true;
    if (_junkTokens.contains(key)) return true;
    for (final token in _junkTokens) {
      if (key == token || key.startsWith('$token ')) return true;
    }
    // Long prose / sentences are not parameter names.
    if (parameter.trim().split(RegExp(r'\s+')).length > 6) return true;
    if (parameter.contains('http')) return true;
    return false;
  }

  /// True if this looks like a medical lab parameter we should show.
  static bool isMedicalParameter(String parameter) {
    return !isJunkParameter(parameter);
  }

  /// Keep complete report parameter rows and attach standard refs when known.
  static List<VitalRow> sanitize(List<VitalRow> rows) {
    final out = <VitalRow>[];
    final seen = <String>{};

    for (final row in rows) {
      if (!isMedicalParameter(row.parameter)) continue;

      final value = row.value.trim();
      if (value.isEmpty) continue;

      final standard = lookup(row.parameter);
      final reference = (standard?.reference.isNotEmpty ?? false)
          ? standard!.reference
          : (row.reference.trim().isNotEmpty ? row.reference.trim() : '—');

      final unit = row.unit.trim().isNotEmpty
          ? row.unit.trim()
          : (standard?.unit ?? '');
      final displayName = standard?.canonical ?? row.parameter.trim();
      final dedupeKey = _normalize(displayName);
      if (seen.contains(dedupeKey)) continue;
      seen.add(dedupeKey);

      var status = row.status;
      if (status == VitalStatus.unknown && reference != '—') {
        status = VitalRow.evaluateStatus(value, reference);
      }

      out.add(
        VitalRow(
          parameter: displayName,
          value: value,
          unit: unit,
          reference: reference,
          status: status,
        ),
      );
    }

    return out;
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9%]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _titleCase(String value) {
    return value
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
