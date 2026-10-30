import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Configure your project credentials here, or run `flutterfire configure`.
class DefaultFirebaseOptions {
  /// Set to true once valid credentials are provided.
  static bool get isConfigured {
    // If the API key is set and not the placeholder, we consider it configured.
    return web.apiKey.isNotEmpty && !web.apiKey.startsWith('AIzaSy_REPLACE');
  }

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
        return windows;
      case TargetPlatform.linux:
        return web;
      default:
        return web;
    }
  }

  // Web configuration options
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSy_REPLACE_WITH_YOUR_FIREBASE_WEB_API_KEY',
    appId: '1:100000000000:web:0000000000000000000000',
    messagingSenderId: '100000000000',
    projectId: 'getplan-better',
    authDomain: 'getplan-better.firebaseapp.com',
    storageBucket: 'getplan-better.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSy_REPLACE_WITH_YOUR_FIREBASE_ANDROID_API_KEY',
    appId: '1:100000000000:android:0000000000000000000000',
    messagingSenderId: '100000000000',
    projectId: 'getplan-better',
    storageBucket: 'getplan-better.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSy_REPLACE_WITH_YOUR_FIREBASE_IOS_API_KEY',
    appId: '1:100000000000:ios:0000000000000000000000',
    messagingSenderId: '100000000000',
    projectId: 'getplan-better',
    storageBucket: 'getplan-better.appspot.com',
    iosBundleId: 'com.getplan.getplanBetter',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSy_REPLACE_WITH_YOUR_FIREBASE_IOS_API_KEY',
    appId: '1:100000000000:ios:0000000000000000000000',
    messagingSenderId: '100000000000',
    projectId: 'getplan-better',
    storageBucket: 'getplan-better.appspot.com',
    iosBundleId: 'com.getplan.getplanBetter',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSy_REPLACE_WITH_YOUR_FIREBASE_WEB_API_KEY',
    appId: '1:100000000000:web:0000000000000000000000',
    messagingSenderId: '100000000000',
    projectId: 'getplan-better',
    authDomain: 'getplan-better.firebaseapp.com',
    storageBucket: 'getplan-better.appspot.com',
  );
}

