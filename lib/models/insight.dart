/// One educational insight grounded in a finding + web sources.
class Insight {
  const Insight({
    required this.title,
    required this.body,
    required this.category,
    required this.supportingFindingKeys,
    required this.sourceUrls,
    required this.createdAt,
    this.id = '',
  });

  final String id;
  final String title;
  final String body;

  /// `risk` | `remedy` | `explanation`
  final String category;

  final List<String> supportingFindingKeys;
  final List<String> sourceUrls;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'title': title,
      'body': body,
      'category': category,
      'supportingFindingKeys': supportingFindingKeys,
      'sourceUrls': sourceUrls,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Insight.fromJson(Map<String, dynamic> json) {
    DateTime createdAt;
    final raw = json['createdAt'];
    if (raw is String) {
      createdAt = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    return Insight(
      id: (json['id'] ?? '').toString().trim(),
      title: (json['title'] ?? '').toString().trim(),
      body: (json['body'] ?? '').toString().trim(),
      category: _normalizeCategory(json['category']),
      supportingFindingKeys: _stringList(json['supportingFindingKeys']),
      sourceUrls: _stringList(json['sourceUrls']),
      createdAt: createdAt,
    );
  }

  Insight copyWith({
    String? id,
    String? title,
    String? body,
    String? category,
    List<String>? supportingFindingKeys,
    List<String>? sourceUrls,
    DateTime? createdAt,
  }) {
    return Insight(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      supportingFindingKeys:
          supportingFindingKeys ?? this.supportingFindingKeys,
      sourceUrls: sourceUrls ?? this.sourceUrls,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static String _normalizeCategory(dynamic raw) {
    final text = (raw ?? 'explanation').toString().trim().toLowerCase();
    switch (text) {
      case 'risk':
      case 'remedy':
      case 'explanation':
        return text;
      default:
        return 'explanation';
    }
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

/// Result of the critic pass over a drafted insight.
class InsightCritique {
  const InsightCritique({
    required this.passesCheck,
    required this.insight,
    this.reason = '',
  });

  final bool passesCheck;
  final Insight insight;
  final String reason;
}

/// Stored insights bundle on `USERS/{email}.insights`.
class InsightsBundle {
  const InsightsBundle({
    required this.fingerprint,
    required this.cards,
    this.generatedAt,
  });

  /// Evidence fingerprint: finding keys + supporting value/date pairs.
  /// Changes when a finding appears/disappears or its lab evidence changes.
  final String fingerprint;
  final List<Insight> cards;
  final DateTime? generatedAt;

  bool get isEmpty => cards.isEmpty;

  Map<String, dynamic> toJson() {
    return {
      'fingerprint': fingerprint,
      'generatedAt': (generatedAt ?? DateTime.now()).toIso8601String(),
      'cards': cards.map((c) => c.toJson()).toList(),
    };
  }

  factory InsightsBundle.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const InsightsBundle(fingerprint: '', cards: []);
    }
    final cardsRaw = json['cards'];
    final cards = <Insight>[];
    if (cardsRaw is List) {
      for (final item in cardsRaw) {
        if (item is Map) {
          cards.add(Insight.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    DateTime? generatedAt;
    final g = json['generatedAt'];
    if (g is String) generatedAt = DateTime.tryParse(g);

    return InsightsBundle(
      fingerprint: (json['fingerprint'] ?? '').toString(),
      cards: cards,
      generatedAt: generatedAt,
    );
  }
}
