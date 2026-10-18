/// Structured side-by-side lab comparison for rich chat cards.
enum ComparisonDirection { increased, decreased, unchanged }

class ComparisonMetric {
  const ComparisonMetric({
    required this.parameterKey,
    required this.label,
    required this.previousValue,
    required this.currentValue,
    required this.unit,
    required this.direction,
    required this.badgeText,
    this.previousRaw,
    this.currentRaw,
  });

  final String parameterKey;
  final String label;
  final double previousValue;
  final double currentValue;
  final String unit;
  final ComparisonDirection direction;
  final String badgeText;
  final String? previousRaw;
  final String? currentRaw;

  Map<String, dynamic> toJson() => {
        'parameterKey': parameterKey,
        'label': label,
        'previousValue': previousValue,
        'currentValue': currentValue,
        'unit': unit,
        'direction': direction.name,
        'badgeText': badgeText,
        if (previousRaw != null) 'previousRaw': previousRaw,
        if (currentRaw != null) 'currentRaw': currentRaw,
      };

  factory ComparisonMetric.fromJson(Map<String, dynamic> json) {
    final dirRaw = (json['direction'] as String?)?.toLowerCase() ?? 'unchanged';
    final direction = switch (dirRaw) {
      'increased' => ComparisonDirection.increased,
      'decreased' => ComparisonDirection.decreased,
      _ => ComparisonDirection.unchanged,
    };
    return ComparisonMetric(
      parameterKey: '${json['parameterKey'] ?? ''}',
      label: '${json['label'] ?? json['parameterKey'] ?? ''}',
      previousValue: (json['previousValue'] as num?)?.toDouble() ?? 0,
      currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0,
      unit: '${json['unit'] ?? ''}',
      direction: direction,
      badgeText: '${json['badgeText'] ?? ''}',
      previousRaw: json['previousRaw']?.toString(),
      currentRaw: json['currentRaw']?.toString(),
    );
  }
}

class ReportComparison {
  const ReportComparison({
    required this.reportType,
    required this.reportLabel,
    required this.previousDate,
    required this.currentDate,
    required this.increased,
    required this.decreased,
    required this.unchanged,
    this.intro = '',
    this.insight = '',
    this.disclaimer = 'This is a simple summary, not a diagnosis.',
  });

  final String reportType;
  final String reportLabel;
  final String previousDate;
  final String currentDate;
  final List<ComparisonMetric> increased;
  final List<ComparisonMetric> decreased;
  final List<ComparisonMetric> unchanged;
  final String intro;
  final String insight;
  final String disclaimer;

  bool get hasChanges => increased.isNotEmpty || decreased.isNotEmpty;

  String get dateRangeLabel {
    final a = _shortDate(previousDate);
    final b = _shortDate(currentDate);
    if (a.isEmpty && b.isEmpty) return '';
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return '$a → $b';
  }

  ReportComparison copyWith({
    String? intro,
    String? insight,
    String? disclaimer,
  }) {
    return ReportComparison(
      reportType: reportType,
      reportLabel: reportLabel,
      previousDate: previousDate,
      currentDate: currentDate,
      increased: increased,
      decreased: decreased,
      unchanged: unchanged,
      intro: intro ?? this.intro,
      insight: insight ?? this.insight,
      disclaimer: disclaimer ?? this.disclaimer,
    );
  }

  Map<String, dynamic> toJson() => {
        'reportType': reportType,
        'reportLabel': reportLabel,
        'previousDate': previousDate,
        'currentDate': currentDate,
        'increased': increased.map((e) => e.toJson()).toList(),
        'decreased': decreased.map((e) => e.toJson()).toList(),
        'unchanged': unchanged.map((e) => e.toJson()).toList(),
        'intro': intro,
        'insight': insight,
        'disclaimer': disclaimer,
      };

  factory ReportComparison.fromJson(Map<String, dynamic> json) {
    List<ComparisonMetric> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => ComparisonMetric.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return ReportComparison(
      reportType: '${json['reportType'] ?? ''}',
      reportLabel: '${json['reportLabel'] ?? 'Report'}',
      previousDate: '${json['previousDate'] ?? ''}',
      currentDate: '${json['currentDate'] ?? ''}',
      increased: parseList(json['increased']),
      decreased: parseList(json['decreased']),
      unchanged: parseList(json['unchanged']),
      intro: '${json['intro'] ?? ''}',
      insight: '${json['insight'] ?? ''}',
      disclaimer: '${json['disclaimer'] ?? 'This is a simple summary, not a diagnosis.'}',
    );
  }

  static String _shortDate(String raw) {
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) {
      final t = raw.trim();
      return t.length > 12 ? t.substring(0, 12) : t;
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }
}
