import 'vital_row.dart';

/// One row in a standard vital/lab panel template.
class PanelParameter {
  const PanelParameter({
    required this.name,
    required this.unit,
    required this.normalRange,
    this.aliases = const [],
  });

  final String name;
  final String unit;
  final String normalRange;
  final List<String> aliases;
}

/// Fixed panel definition (CBC, Lipid Profile, …) used to render Vitals.
class VitalPanelTemplate {
  const VitalPanelTemplate({
    required this.id,
    required this.title,
    required this.order,
    required this.matchKeys,
    required this.parameters,
  });

  final String id;
  final String title;
  final int order;
  final List<String> matchKeys;
  final List<PanelParameter> parameters;
}

/// A template row filled with the patient's reported value (if available).
class PresentedPanelRow {
  const PresentedPanelRow({
    required this.parameter,
    required this.value,
    required this.unit,
    required this.normalRange,
    required this.status,
  });

  final String parameter;
  final String value;
  final String unit;
  final String normalRange;
  final VitalStatus status;
}

/// Catalog of standard report panels from the Nemo Care vitals templates.
class VitalPanelTemplates {
  VitalPanelTemplates._();

  static const List<VitalPanelTemplate> all = [
    VitalPanelTemplate(
      id: 'cbc',
      title: 'Complete Blood Count (CBC)',
      order: 1,
      matchKeys: [
        'cbc',
        'complete blood count',
        'blood count',
        'hemogram',
        'haemogram',
        'cbc report',
      ],
      parameters: [
        PanelParameter(
          name: 'Hemoglobin',
          unit: 'g/dL',
          normalRange: '13.0–17.0 (M) / 12.0–15.5 (F)',
          aliases: ['hb', 'hgb', 'haemoglobin'],
        ),
        PanelParameter(
          name: 'RBC Count',
          unit: 'million/µL',
          normalRange: '4.5–5.5 (M) / 3.8–4.8 (F)',
          aliases: ['rbc', 'red blood cell', 'red blood cells'],
        ),
        PanelParameter(
          name: 'Hematocrit (PCV)',
          unit: '%',
          normalRange: '40–50 (M) / 36–46 (F)',
          aliases: ['hematocrit', 'haematocrit', 'pcv', 'hct', 'packed cell volume'],
        ),
        PanelParameter(
          name: 'MCV',
          unit: 'fL',
          normalRange: '83–101',
          aliases: ['mean corpuscular volume'],
        ),
        PanelParameter(
          name: 'MCH',
          unit: 'pg',
          normalRange: '27–32',
          aliases: ['mean corpuscular hemoglobin', 'mean corpuscular haemoglobin'],
        ),
        PanelParameter(
          name: 'MCHC',
          unit: 'g/dL',
          normalRange: '31.5–34.5',
          aliases: [
            'mean corpuscular hemoglobin concentration',
            'mean corpuscular haemoglobin concentration',
          ],
        ),
        PanelParameter(
          name: 'RDW-CV',
          unit: '%',
          normalRange: '11.6–14.0',
          aliases: ['rdw', 'rdw cv', 'red cell distribution width'],
        ),
        PanelParameter(
          name: 'WBC Count',
          unit: '/µL',
          normalRange: '4000–11000',
          aliases: [
            'wbc',
            'tlc',
            'total wbc',
            'total leucocyte count',
            'leukocytes',
            'leucocytes',
          ],
        ),
        PanelParameter(
          name: 'Neutrophils',
          unit: '%',
          normalRange: '40–80',
          aliases: ['neutrophil'],
        ),
        PanelParameter(
          name: 'Lymphocytes',
          unit: '%',
          normalRange: '20–40',
          aliases: ['lymphocyte'],
        ),
        PanelParameter(
          name: 'Eosinophils',
          unit: '%',
          normalRange: '1–6',
          aliases: ['eosinophil'],
        ),
        PanelParameter(
          name: 'Monocytes',
          unit: '%',
          normalRange: '2–10',
          aliases: ['monocyte'],
        ),
        PanelParameter(
          name: 'Basophils',
          unit: '%',
          normalRange: '0–2',
          aliases: ['basophil'],
        ),
        PanelParameter(
          name: 'Platelet Count',
          unit: '/µL',
          normalRange: '150000–410000',
          aliases: ['platelet', 'platelets', 'plt'],
        ),
      ],
    ),
    VitalPanelTemplate(
      id: 'diabetes',
      title: 'Blood Sugar / Diabetes Panel',
      order: 2,
      matchKeys: [
        'blood sugar',
        'diabetes',
        'diabetes panel',
        'sugar',
        'glucose',
        'fbs',
        'hba1c',
        'ppbs',
        'rbs',
      ],
      parameters: [
        PanelParameter(
          name: 'Fasting Blood Sugar (FBS)',
          unit: 'mg/dL',
          normalRange: '70–99',
          aliases: ['fbs', 'fasting blood sugar', 'fasting glucose', 'fasting blood glucose'],
        ),
        PanelParameter(
          name: 'Postprandial Sugar (PPBS)',
          unit: 'mg/dL',
          normalRange: 'under 140',
          aliases: ['ppbs', 'postprandial', 'post prandial', 'pp blood sugar'],
        ),
        PanelParameter(
          name: 'Random Blood Sugar (RBS)',
          unit: 'mg/dL',
          normalRange: 'under 200',
          aliases: ['rbs', 'random blood sugar', 'random glucose'],
        ),
        PanelParameter(
          name: 'HbA1c',
          unit: '%',
          normalRange: 'under 5.7',
          aliases: ['hba1c', 'a1c', 'glycated hemoglobin', 'hb a1c'],
        ),
      ],
    ),
    VitalPanelTemplate(
      id: 'blood_pressure',
      title: 'Blood Pressure',
      order: 3,
      matchKeys: [
        'blood pressure',
        'bp',
        'vitals',
        'pulse',
      ],
      parameters: [
        PanelParameter(
          name: 'Systolic',
          unit: 'mmHg',
          normalRange: '90–120',
          aliases: ['systolic bp', 'sbp', 'systolic blood pressure'],
        ),
        PanelParameter(
          name: 'Diastolic',
          unit: 'mmHg',
          normalRange: '60–80',
          aliases: ['diastolic bp', 'dbp', 'diastolic blood pressure'],
        ),
        PanelParameter(
          name: 'Pulse Rate',
          unit: 'bpm',
          normalRange: '60–100',
          aliases: ['pulse', 'heart rate', 'hr', 'pulse rate'],
        ),
      ],
    ),
    VitalPanelTemplate(
      id: 'lipid',
      title: 'Lipid Profile',
      order: 4,
      matchKeys: [
        'lipid',
        'lipid profile',
        'cholesterol',
        'lipids',
      ],
      parameters: [
        PanelParameter(
          name: 'Total Cholesterol',
          unit: 'mg/dL',
          normalRange: 'under 200',
          aliases: ['cholesterol', 'cholesterol total', 'total chol'],
        ),
        PanelParameter(
          name: 'LDL',
          unit: 'mg/dL',
          normalRange: 'under 100',
          aliases: ['ldl cholesterol', 'ldl-c'],
        ),
        PanelParameter(
          name: 'HDL',
          unit: 'mg/dL',
          normalRange: 'above 40 (M) / above 50 (F)',
          aliases: ['hdl cholesterol', 'hdl-c'],
        ),
        PanelParameter(
          name: 'Triglycerides',
          unit: 'mg/dL',
          normalRange: 'under 150',
          aliases: ['tg', 'triglyceride'],
        ),
        PanelParameter(
          name: 'VLDL',
          unit: 'mg/dL',
          normalRange: '5–30',
          aliases: ['vldl cholesterol'],
        ),
      ],
    ),
    VitalPanelTemplate(
      id: 'lft',
      title: 'Liver Function Test (LFT)',
      order: 5,
      matchKeys: [
        'lft',
        'liver',
        'liver function',
        'liver function test',
        'hepatic',
      ],
      parameters: [
        PanelParameter(
          name: 'Bilirubin (Total)',
          unit: 'mg/dL',
          normalRange: '0.3–1.2',
          aliases: ['total bilirubin', 'bilirubin total', 'bilirubin'],
        ),
        PanelParameter(
          name: 'Bilirubin (Direct)',
          unit: 'mg/dL',
          normalRange: '0.0–0.3',
          aliases: ['direct bilirubin', 'bilirubin direct', 'conjugated bilirubin'],
        ),
        PanelParameter(
          name: 'SGPT (ALT)',
          unit: 'U/L',
          normalRange: '7–56',
          aliases: ['sgpt', 'alt', 'alanine aminotransferase'],
        ),
        PanelParameter(
          name: 'SGOT (AST)',
          unit: 'U/L',
          normalRange: '5–40',
          aliases: ['sgot', 'ast', 'aspartate aminotransferase'],
        ),
        PanelParameter(
          name: 'Alkaline Phosphatase',
          unit: 'U/L',
          normalRange: '44–147',
          aliases: ['alp', 'alk phosphatase', 'alkaline phosphatase'],
        ),
        PanelParameter(
          name: 'Total Protein',
          unit: 'g/dL',
          normalRange: '6.0–8.3',
          aliases: ['protein total', 'serum protein'],
        ),
        PanelParameter(
          name: 'Albumin',
          unit: 'g/dL',
          normalRange: '3.5–5.0',
          aliases: ['serum albumin'],
        ),
      ],
    ),
    VitalPanelTemplate(
      id: 'kidney_urine',
      title: 'Kidney & Urine Panel (KFT/RFT + Urine)',
      order: 6,
      matchKeys: [
        'kft',
        'rft',
        'kidney',
        'renal',
        'kidney function',
        'renal function',
        'urine',
        'urine routine',
        'urine analysis',
        'urinalysis',
        'urine re',
        'kidney urine',
        'kft urine',
      ],
      parameters: [
        // KFT / RFT
        PanelParameter(
          name: 'Blood Urea',
          unit: 'mg/dL',
          normalRange: '15–40',
          aliases: ['urea', 'blood urea', 'serum urea', 'bun'],
        ),
        PanelParameter(
          name: 'Serum Creatinine',
          unit: 'mg/dL',
          normalRange: '0.7–1.3 (M) / 0.6–1.1 (F)',
          aliases: ['creatinine', 'serum creatinine', 'creat'],
        ),
        PanelParameter(
          name: 'Uric Acid',
          unit: 'mg/dL',
          normalRange: '3.5–7.2 (M) / 2.6–6.0 (F)',
          aliases: ['uric acid', 'serum uric acid'],
        ),
        PanelParameter(
          name: 'eGFR',
          unit: 'mL/min/1.73m²',
          normalRange: 'above 90',
          aliases: ['egfr', 'gfr', 'estimated gfr'],
        ),
        PanelParameter(
          name: 'Sodium',
          unit: 'mEq/L',
          normalRange: '135–145',
          aliases: ['na', 'serum sodium'],
        ),
        PanelParameter(
          name: 'Potassium',
          unit: 'mEq/L',
          normalRange: '3.5–5.1',
          aliases: ['k', 'serum potassium'],
        ),
        // Urine Routine
        PanelParameter(
          name: 'Color',
          unit: '—',
          normalRange: 'Pale yellow',
          aliases: ['urine color', 'colour'],
        ),
        PanelParameter(
          name: 'pH',
          unit: '—',
          normalRange: '4.5–8.0',
          aliases: ['urine ph', 'ph value'],
        ),
        PanelParameter(
          name: 'Specific Gravity',
          unit: '—',
          normalRange: '1.005–1.030',
          aliases: ['sp gravity', 'sg', 'specific gravity'],
        ),
        PanelParameter(
          name: 'Protein',
          unit: '—',
          normalRange: 'Nil/Trace',
          aliases: ['urine protein', 'albumin urine'],
        ),
        PanelParameter(
          name: 'Glucose',
          unit: '—',
          normalRange: 'Nil',
          aliases: ['urine glucose', 'urine sugar'],
        ),
        PanelParameter(
          name: 'Ketones',
          unit: '—',
          normalRange: 'Nil',
          aliases: ['ketone', 'urine ketones'],
        ),
        PanelParameter(
          name: 'Pus Cells',
          unit: '/hpf',
          normalRange: '0–5',
          aliases: ['pus cell', 'leucocytes urine', 'wbc urine'],
        ),
        PanelParameter(
          name: 'RBC',
          unit: '/hpf',
          normalRange: '0–2',
          aliases: ['urine rbc', 'red blood cells urine'],
        ),
        PanelParameter(
          name: 'Epithelial Cells',
          unit: '/hpf',
          normalRange: 'Few',
          aliases: ['epithelial cell', 'epi cells'],
        ),
      ],
    ),
    VitalPanelTemplate(
      id: 'thyroid',
      title: 'Thyroid Profile',
      order: 7,
      matchKeys: [
        'thyroid',
        'thyroid profile',
        'tft',
        'tsh',
      ],
      parameters: [
        PanelParameter(
          name: 'TSH',
          unit: 'µIU/mL',
          normalRange: '0.4–4.0',
          aliases: ['thyroid stimulating hormone'],
        ),
        PanelParameter(
          name: 'T3 (Total)',
          unit: 'ng/dL',
          normalRange: '80–200',
          aliases: ['t3', 'total t3', 'triiodothyronine'],
        ),
        PanelParameter(
          name: 'T4 (Total)',
          unit: 'µg/dL',
          normalRange: '5.1–14.1',
          aliases: ['t4', 'total t4', 'thyroxine'],
        ),
      ],
    ),
    VitalPanelTemplate(
      id: 'vitamin',
      title: 'Vitamin Panel',
      order: 8,
      matchKeys: [
        'vitamin',
        'vitamin panel',
        'vitamins',
        'vitamin d',
        'vitamin b12',
        'folate',
      ],
      parameters: [
        PanelParameter(
          name: 'Vitamin D (25-OH)',
          unit: 'ng/mL',
          normalRange: '30–100',
          aliases: ['vitamin d', 'vit d', '25 oh vitamin d', '25-oh', 'vitamin d3'],
        ),
        PanelParameter(
          name: 'Vitamin B12',
          unit: 'pg/mL',
          normalRange: '200–900',
          aliases: ['b12', 'vit b12', 'cobalamin'],
        ),
        PanelParameter(
          name: 'Folate',
          unit: 'ng/mL',
          normalRange: '3.1–17.5',
          aliases: ['folic acid', 'serum folate'],
        ),
      ],
    ),
    VitalPanelTemplate(
      id: 'iron',
      title: 'Iron Studies',
      order: 9,
      matchKeys: [
        'iron',
        'iron studies',
        'ferritin',
        'tibc',
        'transferrin',
      ],
      parameters: [
        PanelParameter(
          name: 'Serum Iron',
          unit: 'µg/dL',
          normalRange: '60–170',
          aliases: ['iron', 'serum iron'],
        ),
        PanelParameter(
          name: 'Ferritin',
          unit: 'ng/mL',
          normalRange: '20–250 (M) / 10–120 (F)',
          aliases: ['serum ferritin'],
        ),
        PanelParameter(
          name: 'TIBC',
          unit: 'µg/dL',
          normalRange: '250–450',
          aliases: ['total iron binding capacity'],
        ),
        PanelParameter(
          name: 'Transferrin Saturation',
          unit: '%',
          normalRange: '20–50',
          aliases: ['transferrin sat', 'tsat', '% saturation'],
        ),
      ],
    ),
  ];

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Finds the best panel template for a report name.
  static VitalPanelTemplate? matchByReportName(String reportName) {
    final key = _normalize(reportName);
    if (key.isEmpty) return null;

    VitalPanelTemplate? best;
    var bestScore = 0;

    for (final panel in all) {
      for (final matchKey in panel.matchKeys) {
        final mk = _normalize(matchKey);
        var score = 0;
        if (key == mk) {
          score = 100;
        } else if (key.contains(mk) || mk.contains(key)) {
          score = mk.length;
        }
        if (score > bestScore) {
          bestScore = score;
          best = panel;
        }
      }
    }

    return bestScore > 0 ? best : null;
  }

  static bool _namesMatch(String a, String b) {
    final na = _normalize(a);
    final nb = _normalize(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    if (na.length <= 3 || nb.length <= 3) return na == nb;
    return na.contains(nb) || nb.contains(na);
  }

  static VitalRow? _findExtractedValue(
    List<VitalRow> extracted,
    PanelParameter parameter,
  ) {
    final names = [parameter.name, ...parameter.aliases];
    for (final row in extracted) {
      for (final name in names) {
        if (_namesMatch(row.parameter, name)) return row;
      }
    }
    return null;
  }

  /// Builds the full template table for a report, filling patient values.
  static List<PresentedPanelRow> presentReport({
    required VitalPanelTemplate panel,
    required List<VitalRow> extracted,
  }) {
    final rows = <PresentedPanelRow>[];
    for (final parameter in panel.parameters) {
      final found = _findExtractedValue(extracted, parameter);
      final value = (found?.value.trim().isNotEmpty ?? false)
          ? found!.value.trim()
          : '—';

      var status = VitalStatus.unknown;
      if (value != '—') {
        status = found?.status ?? VitalStatus.unknown;
        if (status == VitalStatus.unknown) {
          status = VitalRow.evaluateStatus(value, parameter.normalRange);
        }
      }

      rows.add(
        PresentedPanelRow(
          parameter: parameter.name,
          value: value,
          unit: parameter.unit,
          normalRange: parameter.normalRange,
          status: status,
        ),
      );
    }
    return rows;
  }
}
