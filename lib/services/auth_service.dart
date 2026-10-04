import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_google_config.dart';
import '../firebase_options.dart';
import 'user_profile_service.dart';

/// Firebase Authentication helpers for email and Google sign-in.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    UserProfileService? profiles,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        _profiles = profiles ?? UserProfileService();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final UserProfileService _profiles;
  bool _googleInitialized = false;

  static const _scopes = <String>['email', 'profile'];

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;

    final iosClientId = DefaultFirebaseOptions.ios.iosClientId;
    final webClientId = FirebaseGoogleConfig.webClientId;

    if (webClientId.isEmpty) {
      throw StateError(
        'Google Sign-In is not configured yet. '
        'Add your Web client ID in FirebaseGoogleConfig.',
      );
    }

    await _googleSignIn.initialize(
      clientId:
          defaultTargetPlatform == TargetPlatform.iOS ? iosClientId : null,
      serverClientId: webClientId,
    );
    _googleInitialized = true;
  }

  /// Call once after [Firebase.initializeApp] so the first tap is faster.
  Future<void> initializeGoogleSignIn() async {
    try {
      await _ensureGoogleInitialized();
    } catch (e, st) {
      debugPrint('Google Sign-In init failed: $e\n$st');
    }
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _ensureProfile(credential);
    return credential;
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      await credential.user?.updateDisplayName(name);
      await credential.user?.reload();
    }
    await _ensureProfile(credential, displayName: name);
    return credential;
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      final credential = await _signInWithGoogleSdk();
      await _ensureProfile(credential);
      return credential;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        rethrow;
      }
      debugPrint('Google SDK sign-in failed (${e.code}): ${e.description}');
      final credential = await _signInWithGoogleProvider();
      await _ensureProfile(credential);
      return credential;
    } catch (e) {
      debugPrint('Google SDK sign-in failed: $e');
      final credential = await _signInWithGoogleProvider();
      await _ensureProfile(credential);
      return credential;
    }
  }

  Future<void> _ensureProfile(
    UserCredential credential, {
    String? displayName,
  }) async {
    final user = credential.user ?? _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.trim().isEmpty) return;
    try {
      await _profiles.ensureUserDocument(
        email: email,
        name: displayName ?? user.displayName,
        uid: user.uid,
      );
    } catch (e, st) {
      debugPrint('User profile ensure failed: $e\n$st');
    }
  }

  Future<UserCredential> _signInWithGoogleSdk() async {
    await _ensureGoogleInitialized();

    if (!_googleSignIn.supportsAuthenticate()) {
      return _signInWithGoogleProvider();
    }

    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    final account = await _googleSignIn.authenticate(scopeHint: _scopes);
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google Sign-In did not return an ID token. '
        'Enable Google in Firebase Authentication and verify SHA fingerprints.',
      );
    }

    String? accessToken;
    try {
      final authClient = _googleSignIn.authorizationClient;
      final authorization = await authClient.authorizationForScopes(_scopes) ??
          await authClient.authorizeScopes(_scopes);
      accessToken = authorization.accessToken;
    } catch (e) {
      debugPrint('Google access token unavailable, using idToken only: $e');
    }

    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: accessToken,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Browser / Custom-Tabs Google sign-in via Firebase Auth.
  Future<UserCredential> _signInWithGoogleProvider() async {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile')
      ..setCustomParameters({'prompt': 'select_account'});
    return _auth.signInWithProvider(provider);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (_googleInitialized) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Ignore Google sign-out errors if the session was email-only.
      }
    }
  }

  static String messageFor(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
          return 'No account found for that email.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        case 'weak-password':
          return 'Password should be at least 6 characters.';
        case 'operation-not-allowed':
          return 'Google sign-in is not enabled. Turn on the Google provider in Firebase Authentication.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with this email using a different sign-in method.';
        case 'network-request-failed':
          return 'Network error. Check your connection and try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'web-context-canceled':
          return 'Google sign-in was cancelled.';
        default:
          return error.message ?? 'Authentication failed. Please try again.';
      }
    }
    if (error is GoogleSignInException) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
          return 'Google sign-in was cancelled.';
        case GoogleSignInExceptionCode.interrupted:
          return 'Google sign-in was interrupted. Please try again.';
        case GoogleSignInExceptionCode.clientConfigurationError:
          return 'Google Sign-In is misconfigured. Check the Web client ID and Android SHA fingerprints in Firebase.';
        case GoogleSignInExceptionCode.providerConfigurationError:
          return 'Enable the Google provider in Firebase Authentication, then try again.';
        case GoogleSignInExceptionCode.uiUnavailable:
          return 'Google sign-in UI is unavailable right now. Try again.';
        case GoogleSignInExceptionCode.userMismatch:
          return 'Signed-in Google account does not match. Please try again.';
        case GoogleSignInExceptionCode.unknownError:
          return error.description ??
              'Google sign-in failed. Enable Google in Firebase Auth and verify SHA-1 is added.';
      }
    }
    final text = error.toString();
    if (text.contains('ApiException: 10') || text.contains('DEVELOPER_ERROR')) {
      return 'Google Sign-In setup incomplete. Add this device SHA-1 in Firebase Project Settings → Your apps.';
    }
    if (text.contains('network') || text.contains('Network')) {
      return 'Network error. Check your connection and try again.';
    }
    return text;
  }
}
