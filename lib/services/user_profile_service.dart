import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import 'patient_context_service.dart';

class UserProfileException implements Exception {
  UserProfileException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Firestore profile docs at `USERS/{email}`.
class UserProfileService {
  UserProfileService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const collectionName = 'USERS';

  DocumentReference<Map<String, dynamic>> userDoc(String email) {
    return _firestore
        .collection(collectionName)
        .doc(email.trim().toLowerCase());
  }

  DocumentReference<Map<String, dynamic>>? currentUserDoc() {
    final email = _auth.currentUser?.email;
    if (email == null || email.trim().isEmpty) return null;
    return userDoc(email);
  }

  /// Creates the user document on first signup / first Google sign-in.
  /// Profile vitals fields start as empty strings per product schema.
  Future<void> ensureUserDocument({
    required String email,
    String? name,
    String? uid,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw UserProfileException('User email is required for profile storage.');
    }

    final ref = userDoc(normalized);
    try {
      final existing = await ref.get();
      if (existing.exists) {
        final data = existing.data() ?? {};
        final updates = <String, dynamic>{
          'updatedAt': DateTime.now().toIso8601String(),
        };
        if (uid != null && uid.isNotEmpty) updates['uid'] = uid;
        final display = name?.trim();
        if (display != null && display.isNotEmpty) {
          final currentName = (data['name'] as String?)?.trim();
          if (currentName == null || currentName.isEmpty) {
            updates['name'] = display;
          }
        }
        // Backfill safety-filter fields for older profiles.
        if (!data.containsKey('currentMedications')) {
          updates['currentMedications'] = <String>[];
        }
        if (!data.containsKey('allergies')) {
          updates['allergies'] = <String>[];
        }
        await ref.set(updates, SetOptions(merge: true));
        return;
      }

      final profile = UserProfile(
        email: normalized,
        name: name?.trim() ?? '',
        dob: '',
        gender: '',
        heightCm: '',
        weightKg: '',
        bmi: '',
        married: '',
        currentMedications: const [],
        allergies: const [],
      );
      final payload = profile.toFirestoreCreate();
      if (uid != null && uid.isNotEmpty) payload['uid'] = uid;
      await ref.set(payload);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw UserProfileException(
          'Firestore permission denied. Allow reads/writes on USERS/{email}.',
        );
      }
      throw UserProfileException(
        e.message ?? 'Could not create user profile.',
      );
    }
  }

  /// Ensures a profile exists for the currently signed-in Firebase user.
  Future<void> ensureCurrentUserDocument() async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.trim().isEmpty) return;
    await ensureUserDocument(
      email: email,
      name: user.displayName,
      uid: user.uid,
    );
  }

  /// Full `USERS/{email}` document for the signed-in user (or null).
  Future<Map<String, dynamic>?> fetchCurrentUserDoc() async {
    final ref = currentUserDoc();
    if (ref == null) return null;
    try {
      final snap = await ref.get();
      if (!snap.exists) return null;
      return snap.data();
    } on FirebaseException {
      return null;
    }
  }

  /// Assembles [PatientContext] for the signed-in user.
  Future<PatientContext?> fetchPatientContext() async {
    final doc = await fetchCurrentUserDoc();
    if (doc == null) return null;
    return PatientContextService().build(doc);
  }
}
