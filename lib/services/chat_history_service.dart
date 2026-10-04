import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';

/// Persists health-agent chat history on the device (SharedPreferences).
///
/// Keys are scoped per Firebase user so accounts on the same phone stay separate.
class ChatHistoryService {
  ChatHistoryService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  static const _maxMessages = 100;
  static const _keyPrefix = 'nemo_care_chat_history_v1_';

  String? get _storageKey {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    return '$_keyPrefix$uid';
  }

  Future<List<ChatMessage>> load() async {
    final key = _storageKey;
    if (key == null) return [];

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
          .where((m) => m.content.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<ChatMessage> messages) async {
    final key = _storageKey;
    if (key == null) return;

    try {
      final trimmed = messages
          .where((m) => m.content.trim().isNotEmpty)
          .toList();
      final capped = trimmed.length > _maxMessages
          ? trimmed.sublist(trimmed.length - _maxMessages)
          : trimmed;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode(capped.map((m) => m.toJson()).toList()),
      );
    } catch (_) {
      // Local persistence failure should not break chat.
    }
  }

  Future<void> clear() async {
    final key = _storageKey;
    if (key == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {
      // Ignore.
    }
  }
}
