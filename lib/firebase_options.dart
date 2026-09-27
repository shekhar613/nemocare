// File generated for NemoCare Firebase project (nemocare-2ce11).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBW49tos9LXVEMHLpkKQdlDtBmpCAb9IOg',
    appId: '1:380341028459:android:ce6810f5c0e438b642532e',
    messagingSenderId: '380341028459',
    projectId: 'nemocare-2ce11',
    storageBucket: 'nemocare-2ce11.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA1Qq07OuzKAQfZPizbKwYS4pxM989db0A',
    appId: '1:380341028459:ios:2514bd96229ce2be42532e',
    messagingSenderId: '380341028459',
    projectId: 'nemocare-2ce11',
    storageBucket: 'nemocare-2ce11.firebasestorage.app',
    iosClientId:
        '380341028459-mfsp8v36rjll9nl804m68u0dnmt4df9j.apps.googleusercontent.com',
    iosBundleId: 'com.nemocare.nemoCare',
  );
}
