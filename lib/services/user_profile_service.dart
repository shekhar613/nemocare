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
        if (!data.containsKey('currentMedications')) {
          updates['currentMedications'] = <Map<String, String>>[];
        }
        if (!data.containsKey('allergies')) {
          updates['allergies'] = <String>[];
        }
        if (!data.containsKey('onboardingCompleted')) {
          updates['onboardingCompleted'] = false;
        }
        await ref.set(updates, SetOptions(merge: true));
        return;
      }

      final profile = UserProfile(
        email: normalized,
        name: name?.trim() ?? '',
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

  Future<UserProfile?> fetchCurrentProfile() async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.trim().isEmpty) return null;
    final data = await fetchCurrentUserDoc();
    if (data == null) return null;
    return UserProfile.fromFirestore(email, data);
  }

  /// True when the signed-in user still needs the onboarding wizard.
  Future<bool> needsOnboarding() async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.trim().isEmpty) return false;
    await ensureCurrentUserDocument();
    final data = await fetchCurrentUserDoc();
    if (data == null) return true;
    return data['onboardingCompleted'] != true;
  }

  /// Persists onboarding answers and marks the profile complete.
  Future<void> saveOnboarding(UserProfile profile) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.trim().isEmpty) {
      throw UserProfileException('Sign in to save your profile.');
    }

    final completed = profile.onboardingCompleted
        ? profile
        : UserProfile(
            email: email,
            name: profile.name,
            dob: profile.dob,
            ageRange: profile.ageRange,
            ageApproximate: profile.ageApproximate,
            sex: profile.sex,
            genderIdentity: profile.genderIdentity,
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            bmi: profile.bmi,
            heightApproximate: profile.heightApproximate,
            weightApproximate: profile.weightApproximate,
            married: profile.married,
            bloodGroup: profile.bloodGroup,
            knownConditions: profile.knownConditions,
            onDialysis: profile.onDialysis,
            eyeConditions: profile.eyeConditions,
            skinConditions: profile.skinConditions,
            foodIntolerances: profile.foodIntolerances,
            drugAllergies: profile.drugAllergies,
            otherAllergies: profile.otherAllergies,
            currentMedications: profile.currentMedications,
            smokingStatus: profile.smokingStatus,
            alcoholUse: profile.alcoholUse,
            dietPreference: profile.dietPreference,
            activityLevel: profile.activityLevel,
            pregnancyStatus: profile.pregnancyStatus,
            onboardingCompleted: true,
          );

    final ref = userDoc(email);
    try {
      await ensureUserDocument(
        email: email,
        name: completed.name,
        uid: user.uid,
      );
      final payload = completed.toFirestoreUpdate();
      payload['uid'] = user.uid;
      await ref.set(payload, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw UserProfileException(
        e.message ?? 'Could not save onboarding profile.',
      );
    }
  }

  Future<PatientContext?> fetchPatientContext() async {
    final doc = await fetchCurrentUserDoc();
    if (doc == null) return null;
    return PatientContextService().build(doc);
  }
}
