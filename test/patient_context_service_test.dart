import 'package:flutter_test/flutter_test.dart';
import 'package:nemo_care/services/patient_context_service.dart';

void main() {
  late PatientContextService service;

  setUp(() {
    service = PatientContextService();
  });

  test('build resolves supporting values from derivedFrom paths', () {
    final ctx = service.build({
      'name': 'Shekhar',
      'dob': '2002-01-01',
      'gender': 'male',
      'currentMedications': ['Metformin'],
      'allergies': ['Penicillin'],
      'cbc': {
        '2026-09-14': {
          'labName': 'Sankara Eye Centre',
          'reportName': 'CBC',
          'values': [
            {
              'parameterKey': 'hemoglobin',
              'rawLabel': 'Haemoglobin (Hb)',
              'value': 12.2,
              'unit': 'g/dL',
              'refLow': 12.0,
              'refHigh': 15.0,
              'flag': null,
            },
            {
              'parameterKey': 'mcv',
              'rawLabel': 'MCV',
              'value': 81.0,
              'unit': 'fL',
              'flag': 'L',
            },
            {
              'parameterKey': 'mch',
              'rawLabel': 'MCH',
              'value': 26.4,
              'unit': 'pg',
              'flag': 'L',
            },
          ],
        },
      },
      'findings': {
        'microcytic_pattern': {
          'key': 'microcytic_pattern',
          'derivedFrom': ['cbc/2026-09-14/mcv', 'cbc/2026-09-14/mch'],
          'sinceDate': '2026-09-14',
          'active': true,
        },
        'low_hemoglobin': {
          'key': 'low_hemoglobin',
          'derivedFrom': ['cbc/2026-09-14/hemoglobin'],
          'sinceDate': '2026-09-14',
          'active': false,
        },
      },
    });

    expect(ctx.activeFindings.length, 1);
    expect(ctx.activeFindings.first.key, 'microcytic_pattern');
    expect(ctx.profile['age'], isNotNull);
    expect(ctx.profile['sex'], 'male');
    expect(ctx.medications, ['Metformin']);
    expect(ctx.allergies, ['Penicillin']);

    final values = ctx.supportingValues['microcytic_pattern']!;
    expect(values.length, 2);
    expect(values[0]['parameterKey'], 'mcv');
    expect(values[0]['value'], 81.0);
    expect(values[0]['date'], '2026-09-14');
    expect(values[1]['parameterKey'], 'mch');
    expect(values[1]['value'], 26.4);
  });
}
