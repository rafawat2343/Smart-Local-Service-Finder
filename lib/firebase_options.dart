import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDemoKey123456789',
    appId: '1:000000000000:android:abcdefghijklmnop',
    messagingSenderId: '000000000000',
    projectId: 'smart-local-service-finder',
    storageBucket: 'smart-local-service-finder.appspot.com',
  );
}
