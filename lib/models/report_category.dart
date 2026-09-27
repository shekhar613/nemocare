/// Medical report type used to group documents in Firestore.
enum ReportCategory {
  lab,
  prescription,
  imaging,
  clinicalReport,
  otherMedical;

  /// Firestore / API value (snake_case).
  String get storageValue {
    switch (this) {
      case ReportCategory.lab:
        return 'lab';
      case ReportCategory.prescription:
        return 'prescription';
      case ReportCategory.imaging:
        return 'imaging';
      case ReportCategory.clinicalReport:
        return 'clinical_report';
      case ReportCategory.otherMedical:
        return 'other_medical';
    }
  }

  /// Short label for UI (e.g. timeline title prefix).
  String get label {
    switch (this) {
      case ReportCategory.lab:
        return 'LAB Test';
      case ReportCategory.prescription:
        return 'Prescription';
      case ReportCategory.imaging:
        return 'Imaging';
      case ReportCategory.clinicalReport:
        return 'Clinical report';
      case ReportCategory.otherMedical:
        return 'Report';
    }
  }

  static ReportCategory fromStorage(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'lab':
      case 'laboratory':
      case 'blood_test':
        return ReportCategory.lab;
      case 'prescription':
      case 'rx':
      case 'medication':
        return ReportCategory.prescription;
      case 'imaging':
      case 'radiology':
      case 'xray':
      case 'scan':
        return ReportCategory.imaging;
      case 'clinical_report':
      case 'clinical':
      case 'discharge':
      case 'consultation':
        return ReportCategory.clinicalReport;
      case 'non_medical':
        return ReportCategory.otherMedical;
      default:
        return ReportCategory.otherMedical;
    }
  }

  static const allowedStorageValues = [
    'lab',
    'prescription',
    'imaging',
    'clinical_report',
    'other_medical',
  ];
}
