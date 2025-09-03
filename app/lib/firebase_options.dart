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

  // ⚡ If you add web later, update here
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'your-web-api-key',
    appId: 'your-web-app-id',
    messagingSenderId: 'your-sender-id',
    projectId: 'geoat-7',
    authDomain: 'geoat-7.firebaseapp.com',
    storageBucket: 'geoat-7.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAGHu0ZjZUJTi4lkKIj_U4li9T9czRylWQ',
    appId: '1:894800243617:android:fb06368151cd1d60b9f9e0',
    messagingSenderId: '894800243617',
    projectId: 'geoat-7',
    storageBucket: 'geoat-7.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'your-ios-api-key',
    appId: 'your-ios-app-id',
    messagingSenderId: '894800243617',
    projectId: 'geoat-7',
    storageBucket: 'geoat-7.appspot.com',
    iosBundleId: 'com.geoat.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'your-ios-api-key',
    appId: 'your-ios-app-id',
    messagingSenderId: '894800243617',
    projectId: 'geoat-7',
    storageBucket: 'geoat-7.appspot.com',
    iosBundleId: 'com.geoat.app',
  );
}
