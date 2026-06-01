// File generated manually based on Firebase project me-lembra-ai-bf0f0
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAqSnE4HWAyMigWCuGuPMEwCXE1oZmmL1o',
    appId: '1:1029231065071:web:451846d418a5600db8a81a',
    messagingSenderId: '1029231065071',
    projectId: 'me-lembra-ai-bf0f0',
    authDomain: 'me-lembra-ai-bf0f0.firebaseapp.com',
    storageBucket: 'me-lembra-ai-bf0f0.firebasestorage.app',
    measurementId: 'G-23FELCQFRE',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAqSnE4HWAyMigWCuGuPMEwCXE1oZmmL1o',
    appId: '1:1029231065071:android:e3e10d91aeda4951b8a81a',
    messagingSenderId: '1029231065071',
    projectId: 'me-lembra-ai-bf0f0',
    storageBucket: 'me-lembra-ai-bf0f0.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAqSnE4HWAyMigWCuGuPMEwCXE1oZmmL1o',
    appId: '1:1029231065071:ios:a243c827828118ceb8a81a',
    messagingSenderId: '1029231065071',
    projectId: 'me-lembra-ai-bf0f0',
    storageBucket: 'me-lembra-ai-bf0f0.firebasestorage.app',
    iosBundleId: 'com.melembra.ai',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAqSnE4HWAyMigWCuGuPMEwCXE1oZmmL1o',
    appId: '1:1029231065071:ios:a243c827828118ceb8a81a',
    messagingSenderId: '1029231065071',
    projectId: 'me-lembra-ai-bf0f0',
    storageBucket: 'me-lembra-ai-bf0f0.firebasestorage.app',
    iosBundleId: 'com.melembra.ai',
  );
}