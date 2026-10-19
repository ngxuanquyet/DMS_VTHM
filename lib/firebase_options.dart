// File generated for DMS VTHM Firebase configuration
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Cấu hình mặc định cho Firebase tùy theo nền tảng (Android / iOS)
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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform: $defaultTargetPlatform',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBwsXAjStjyMleOzAZzyzPv_iFKqGf_6dA',
    appId: '1:161319260292:android:532086b12798d6fa88b2d1',
    messagingSenderId: '161319260292',
    projectId: 'vthmgroup-app',
    storageBucket: 'vthmgroup-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCmIoChTXjavWZirSO9cxHeF8y33oeC_LE',
    appId: '1:161319260292:ios:6819075f275cbec388b2d1',
    messagingSenderId: '161319260292',
    projectId: 'vthmgroup-app',
    storageBucket: 'vthmgroup-app.firebasestorage.app',
    iosBundleId: 'vn.vthmgroup.dms',
  );
}
