import 'report_comparison.dart';

enum ChatRole { user, assistant }

/// One turn in the Nemo Care health agent conversation.
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    required this.createdAt,
    this.comparison,
  });

  final ChatRole role;
  final String content;
  final DateTime createdAt;

  /// When set, the UI renders a rich report-comparison card instead of plain text.
  final ReportComparison? comparison;

  bool get isUser => role == ChatRole.user;

  bool get hasRichComparison => comparison != null;

  /// Persistable / non-empty for history (comparison cards may use intro as content).
  bool get isPersistable =>
      content.trim().isNotEmpty || comparison != null;

  factory ChatMessage.user(String content) {
    return ChatMessage(
      role: ChatRole.user,
      content: content.trim(),
      createdAt: DateTime.now(),
    );
  }

  factory ChatMessage.assistant(
    String content, {
    ReportComparison? comparison,
  }) {
    return ChatMessage(
      role: ChatRole.assistant,
      content: content.trim(),
      createdAt: DateTime.now(),
      comparison: comparison,
    );
  }

  ChatMessage copyWith({
    String? content,
    ReportComparison? comparison,
    bool clearComparison = false,
  }) {
    return ChatMessage(
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      comparison: clearComparison ? null : (comparison ?? this.comparison),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role.name,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      if (comparison != null) 'comparison': comparison!.toJson(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final roleRaw = (json['role'] as String?)?.trim().toLowerCase() ?? 'user';
    final role = roleRaw == 'assistant' ? ChatRole.assistant : ChatRole.user;
    final createdRaw = json['createdAt'];
    final createdAt = createdRaw is String
        ? DateTime.tryParse(createdRaw) ?? DateTime.now()
        : DateTime.now();
    ReportComparison? comparison;
    final rawCmp = json['comparison'];
    if (rawCmp is Map) {
      comparison =
          ReportComparison.fromJson(Map<String, dynamic>.from(rawCmp));
    }
    return ChatMessage(
      role: role,
      content: (json['content'] as String?) ?? '',
      createdAt: createdAt,
      comparison: comparison,
    );
  }
}
