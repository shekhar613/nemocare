enum ChatRole { user, assistant }

/// One turn in the Nemo Care health agent conversation.
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final ChatRole role;
  final String content;
  final DateTime createdAt;

  bool get isUser => role == ChatRole.user;

  factory ChatMessage.user(String content) {
    return ChatMessage(
      role: ChatRole.user,
      content: content.trim(),
      createdAt: DateTime.now(),
    );
  }

  factory ChatMessage.assistant(String content) {
    return ChatMessage(
      role: ChatRole.assistant,
      content: content.trim(),
      createdAt: DateTime.now(),
    );
  }

  ChatMessage copyWith({String? content}) {
    return ChatMessage(
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role.name,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final roleRaw = (json['role'] as String?)?.trim().toLowerCase() ?? 'user';
    final role = roleRaw == 'assistant' ? ChatRole.assistant : ChatRole.user;
    final createdRaw = json['createdAt'];
    final createdAt = createdRaw is String
        ? DateTime.tryParse(createdRaw) ?? DateTime.now()
        : DateTime.now();
    return ChatMessage(
      role: role,
      content: (json['content'] as String?) ?? '',
      createdAt: createdAt,
    );
  }
}
