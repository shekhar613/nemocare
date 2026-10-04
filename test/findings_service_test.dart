import 'package:flutter_test/flutter_test.dart';
import 'package:nemo_care/services/findings_service.dart';

void main() {
  late FindingsService service;

  setUp(() {
    service = FindingsService();
  });

  Map<String, dynamic> cbcDoc({
    required String date,
    required List<Map<String, dynamic>> values,
  }) {
    return {
      'name': 'Test User',
      'cbc': {
        date: {
          'docType': 'cbc',
          'values': values,
        },
      },
    };
  }

  test('flags low hemoglobin from flag L', () {
    final findings = service.computeFindings(
      cbcDoc(
        date: '2026-09-14',
        values: [
          {
            'parameterKey': 'hemoglobin',
            'value': 10.5,
            'refLow': 12.0,
            'refHigh': 15.0,
            'flag': 'L',
          },
        ],
      ),
    );
    expect(findings.map((f) => f.key), contains('low_hemoglobin'));
    expect(findings.first.derivedFrom, ['cbc/2026-09-14/hemoglobin']);
  });

  test('detects microcytic pattern when MCV and MCH are both low', () {
    final findings = service.computeFindings(
      cbcDoc(
        date: '2026-09-14',
        values: [
          {
            'parameterKey': 'mcv',
            'value': 81.0,
            'refLow': 83.0,
            'refHigh': 101.0,
            'flag': 'L',
          },
          {
            'parameterKey': 'mch',
            'value': 26.4,
            'refLow': 27.0,
            'refHigh': 32.0,
            'flag': 'L',
          },
        ],
      ),
    );
    expect(findings.map((f) => f.key), contains('microcytic_pattern'));
    expect(
      findings.firstWhere((f) => f.key == 'microcytic_pattern').derivedFrom,
      ['cbc/2026-09-14/mcv', 'cbc/2026-09-14/mch'],
    );
  });

  test('flags high neutrophils', () {
    final findings = service.computeFindings(
      cbcDoc(
        date: '2026-09-14',
        values: [
          {
            'parameterKey': 'neutrophils_pct',
            'value': 65,
            'refLow': 50,
            'refHigh': 62,
            'flag': 'H',
          },
        ],
      ),
    );
    expect(findings.map((f) => f.key), contains('high_neutrophils'));
  });

  test('flags high blood sugar from renal panel using refHigh', () {
    final findings = service.computeFindings({
      'renal_infectious_metabolic_panel': {
        '2026-08-01': {
          'values': [
            {
              'parameterKey': 'random_blood_sugar',
              'value': 180,
              'refLow': 70,
              'refHigh': 140,
              'flag': null,
            },
          ],
        },
      },
    });
    expect(findings.map((f) => f.key), contains('high_blood_sugar'));
  });

  test('flags qualitative infectious markers when not matching ref', () {
    final findings = service.computeFindings({
      'renal_infectious_metabolic_panel': {
        '2026-08-01': {
          'values': [
            {
              'parameterKey': 'hiv_1_2',
              'qualitativeValue': 'Reactive',
              'refQualitative': 'Non Reactive',
            },
          ],
        },
      },
    });
    expect(findings.map((f) => f.key), contains('hiv_1_2_abnormal'));
  });

  test('uses latest CBC by date when multiple CBCs exist', () {
    final findings = service.computeFindings({
      'cbc': {
        '2026-06-08': {
          'collectedDate': '2026-06-08',
          'values': [
            {
              'parameterKey': 'hemoglobin',
              'value': 11.1,
              'refLow': 12.0,
              'refHigh': 15.0,
              'flag': 'L',
            },
            {
              'parameterKey': 'mcv',
              'value': 78.8,
              'refLow': 83.0,
              'refHigh': 101.0,
              'flag': 'L',
            },
            {
              'parameterKey': 'mch',
              'value': 25.1,
              'refLow': 27.0,
              'refHigh': 32.0,
              'flag': 'L',
            },
          ],
        },
        '2026-09-14': {
          'collectedDate': '2026-09-14',
          'values': [
            {
              'parameterKey': 'hemoglobin',
              'value': 12.2,
              'refLow': 12.0,
              'refHigh': 15.0,
              'flag': null,
            },
            {
              'parameterKey': 'mcv',
              'value': 81.0,
              'refLow': 83.0,
              'refHigh': 101.0,
              'flag': 'L',
            },
            {
              'parameterKey': 'mch',
              'value': 26.4,
              'refLow': 27.0,
              'refHigh': 32.0,
              'flag': 'L',
            },
            {
              'parameterKey': 'neutrophils',
              'value': 65,
              'refLow': 50,
              'refHigh': 62,
              'flag': 'H',
            },
          ],
        },
      },
    });

    final keys = findings.map((f) => f.key).toSet();
    // Latest CBC has normal hemoglobin — older low_hemoglobin must not apply.
    expect(keys.contains('low_hemoglobin'), isFalse);
    expect(keys, contains('microcytic_pattern'));
    expect(keys, contains('high_neutrophils'));

    final micro = findings.firstWhere((f) => f.key == 'microcytic_pattern');
    expect(micro.sinceDate, '2026-09-14');
    expect(micro.derivedFrom, ['cbc/2026-09-14/mcv', 'cbc/2026-09-14/mch']);
  });

  test('mergeFindingsMap deactivates findings that no longer apply', () {
    final computed = service.computeFindings(
      cbcDoc(
        date: '2026-09-14',
        values: [
          {
            'parameterKey': 'hemoglobin',
            'value': 13.0,
            'refLow': 12.0,
            'refHigh': 15.0,
            'flag': null,
          },
        ],
      ),
    );
    final merged = service.mergeFindingsMap(
      computed: computed,
      existing: {
        'low_hemoglobin': {
          'key': 'low_hemoglobin',
          'derivedFrom': ['cbc/2026-01-01/hemoglobin'],
          'sinceDate': '2026-01-01',
          'active': true,
        },
      },
    );
    expect(merged['low_hemoglobin']['active'], isFalse);
  });
}
